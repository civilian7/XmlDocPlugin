unit XmlDoc.Plugin.Main;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Menus,
  Vcl.Dialogs,
  ToolsAPI,
  XmlDoc.Plugin.DocExplorer,
  XmlDoc.Plugin.DocInspector,
  XmlDoc.Plugin.Shortcuts,
  XmlDoc.Plugin.UndocNavigator;

type
  /// <summary>XmlDoc 플러그인 메인 위저드. IDE 등록/해제 및 메뉴 통합을 담당합니다.</summary>
  TXmlDocWizard = class(TNotifierObject, IOTAWizard, IOTAMenuWizard)
  private
    FDocExplorer: TDocExplorerForm;
    FDocInspector: TDocInspectorForm;
    FEditorNotifierIndex: Integer;
    FKeyBindingIndex: Integer;
    FMenuIntegration: TXmlDocMenuIntegration;
    FUndocNavigator: TUndocNavigator;

    procedure CreateDocExplorer;
    procedure CreateDocInspector;
    procedure DestroyDocExplorer;
    procedure DestroyDocInspector;
    procedure GenerateStubForCurrentElement;
    procedure SetupCallbacks;

  public
    constructor Create;
    destructor Destroy; override;

    { IOTAWizard }
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Execute;
    procedure Modified;

    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;

    { IOTAMenuWizard }
    function GetMenuText: string;

    property DocExplorer: TDocExplorerForm read FDocExplorer;
    property DocInspector: TDocInspectorForm read FDocInspector;
  end;

procedure Register;

implementation

uses
  XmlDoc.Plugin.EditorNotifier,
  XmlDoc.Plugin.BatchGenDialog,
  XmlDoc.Plugin.CoverageDialog,
  XmlDoc.Plugin.Settings,
  XmlDoc.Plugin.SettingsDialog,
  XmlDoc.Parser,
  XmlDoc.StubGen,
  XmlDoc.CodeGen.OTA,
  XmlDoc.Consts,
  XmlDoc.Model;

var
  GWizardIndex: Integer = -1;
  GWizard: TXmlDocWizard = nil;

procedure Register;
begin
  GWizard := TXmlDocWizard.Create;
  GWizardIndex := (BorlandIDEServices as IOTAWizardServices).AddWizard(GWizard);
end;

{ TXmlDocWizard }

constructor TXmlDocWizard.Create;
var
  LEditorServices: IOTAEditorServices;
  LKeyServices: IOTAKeyboardServices;
begin
  inherited Create;
  FEditorNotifierIndex := -1;
  FKeyBindingIndex := -1;

  // 에디터 노티파이어 등록
  if Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
  begin
    FEditorNotifierIndex := LEditorServices.AddNotifier(
      TXmlDocEditorNotifier.Create(
        procedure(ALine: Integer; const ASource, AFileName: string)
        begin
          if Assigned(FDocInspector) then
            FDocInspector.HandleCursorChanged(ALine, ASource, AFileName);
          if Assigned(FDocExplorer) then
            FDocExplorer.HandleFileChanged(AFileName, ASource);
        end
      )
    );
  end;

  // 키보드 바인딩 등록
  if Supports(BorlandIDEServices, IOTAKeyboardServices, LKeyServices) then
    FKeyBindingIndex := LKeyServices.AddKeyboardBinding(TXmlDocKeyBinding.Create);

  // 미문서화 네비게이터
  FUndocNavigator := TUndocNavigator.Create;

  // 콜백 설정
  SetupCallbacks;

  // IDE 메뉴 통합
  FMenuIntegration := TXmlDocMenuIntegration.Create;
  FMenuIntegration.InstallMenu;
end;

destructor TXmlDocWizard.Destroy;
var
  LEditorServices: IOTAEditorServices;
  LKeyServices: IOTAKeyboardServices;
begin
  FreeAndNil(FMenuIntegration);

  // 키보드 바인딩 해제
  if (FKeyBindingIndex >= 0) and
     Supports(BorlandIDEServices, IOTAKeyboardServices, LKeyServices) then
  begin
    LKeyServices.RemoveKeyboardBinding(FKeyBindingIndex);
  end;

  // 에디터 노티파이어 해제
  if (FEditorNotifierIndex >= 0) and
     Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
  begin
    LEditorServices.RemoveNotifier(FEditorNotifierIndex);
  end;

  FreeAndNil(FUndocNavigator);
  DestroyDocExplorer;
  DestroyDocInspector;
  inherited;
end;

procedure TXmlDocWizard.AfterSave;
begin
  // not used
end;

procedure TXmlDocWizard.BeforeSave;
begin
  // not used
end;

procedure TXmlDocWizard.CreateDocExplorer;
begin
  if not Assigned(FDocExplorer) then
  begin
    FDocExplorer := TDocExplorerForm.Create(nil);
    FDocExplorer.Show;
    FDocExplorer.RefreshFromCurrentEditor;
  end
  else
  begin
    if FDocExplorer.Visible then
      FDocExplorer.Hide
    else
    begin
      FDocExplorer.Show;
      FDocExplorer.RefreshFromCurrentEditor;
    end;
  end;
end;

procedure TXmlDocWizard.CreateDocInspector;
begin
  if not Assigned(FDocInspector) then
  begin
    FDocInspector := TDocInspectorForm.Create(nil);
    FDocInspector.Show;
    FDocInspector.RefreshFromCurrentEditor;
  end
  else
  begin
    if FDocInspector.Visible then
      FDocInspector.Hide
    else
    begin
      FDocInspector.Show;
      FDocInspector.RefreshFromCurrentEditor;
    end;
  end;
end;

procedure TXmlDocWizard.Destroyed;
begin
  // not used
end;

procedure TXmlDocWizard.DestroyDocExplorer;
begin
  FreeAndNil(FDocExplorer);
end;

procedure TXmlDocWizard.DestroyDocInspector;
begin
  FreeAndNil(FDocInspector);
end;

procedure TXmlDocWizard.Execute;
begin
  CreateDocInspector;
end;

procedure TXmlDocWizard.GenerateStubForCurrentElement;
var
  LEditor: IOTASourceEditor;
  LParser: XmlDoc.Parser.TDocParser;
  LElement: TCodeElementInfo;
  LStub: TXmlDocModel;
  LView: IOTAEditView;
  LSource: string;
  LReader: IOTAEditReader;
  LBuf: TBytes;
  LBufLen: Integer;
begin
  LEditor := TDocOTAWriter.GetCurrentSourceEditor;
  if not Assigned(LEditor) then
    Exit;

  // 소스 읽기 (UTF-8 BOM 처리)
  LReader := LEditor.CreateReader;
  SetLength(LBuf, LEditor.GetLinesInBuffer * 256);
  LBufLen := LReader.GetText(0, PAnsiChar(LBuf), Length(LBuf));
  if (LBufLen >= 3) and (LBuf[0] = $EF) and (LBuf[1] = $BB) and (LBuf[2] = $BF) then
    LSource := TEncoding.UTF8.GetString(LBuf, 3, LBufLen - 3)
  else
    LSource := TEncoding.UTF8.GetString(LBuf, 0, LBufLen);

  // 현재 커서 위치의 요소 찾기
  LParser := XmlDoc.Parser.TDocParser.Create;
  try
    LParser.ParseSource(LSource);
    LView := LEditor.GetEditView(0);
    if not Assigned(LView) then
      Exit;

    LElement := LParser.GetElementAtLine(LView.CursorPos.Line);
    if LElement.Name = '' then
      Exit;

    // 이미 문서가 있으면 무시
    if LElement.ExistingDocXml <> '' then
      Exit;

    LStub := TDocStubGenerator.GenerateStub(LElement);
    try
      TDocOTAWriter.ApplyToEditor(LEditor, LElement, LStub);
    finally
      LStub.Free;
    end;
  finally
    LParser.Free;
  end;
end;

function TXmlDocWizard.GetIDString: string;
begin
  Result := 'XmlDocPlugin.Wizard';
end;

function TXmlDocWizard.GetMenuText: string;
begin
  Result := 'Toggle Doc Inspector';
end;

function TXmlDocWizard.GetName: string;
begin
  Result := 'XmlDoc Plugin';
end;

function TXmlDocWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TXmlDocWizard.Modified;
begin
  // not used
end;

procedure TXmlDocWizard.SetupCallbacks;
begin
  SetToggleInspectorCallback(
    function: Boolean
    begin
      CreateDocInspector;
      Result := Assigned(FDocInspector) and FDocInspector.Visible;
    end
  );

  SetToggleDocExplorerCallback(
    function: Boolean
    begin
      CreateDocExplorer;
      Result := Assigned(FDocExplorer) and FDocExplorer.Visible;
    end
  );

  SetIsInspectorVisibleFunc(
    function: Boolean
    begin
      Result := Assigned(FDocInspector) and FDocInspector.Visible;
    end
  );

  SetIsDocExplorerVisibleFunc(
    function: Boolean
    begin
      Result := Assigned(FDocExplorer) and FDocExplorer.Visible;
    end
  );

  SetGenerateStubCallback(
    procedure
    begin
      GenerateStubForCurrentElement;
    end
  );

  SetGenerateHelpCallback(
    procedure
    begin
      ShowBatchGenDialog;
    end
  );

  SetCoverageReportCallback(
    procedure
    begin
      ShowCoverageDialog;
    end
  );

  SetNextUndocumentedCallback(
    procedure
    begin
      FUndocNavigator.JumpToNext;
    end
  );

  SetPreviousUndocumentedCallback(
    procedure
    begin
      FUndocNavigator.JumpToPrevious;
    end
  );

  SetSettingsCallback(
    procedure
    var
      LKeyServices: IOTAKeyboardServices;
    begin
      if ShowSettingsDialog then
      begin
        FMenuIntegration.RefreshShortcuts;

        if Supports(BorlandIDEServices, IOTAKeyboardServices, LKeyServices) then
        begin
          if FKeyBindingIndex >= 0 then
            LKeyServices.RemoveKeyboardBinding(FKeyBindingIndex);

          FKeyBindingIndex := LKeyServices.AddKeyboardBinding(TXmlDocKeyBinding.Create);
        end;
      end;
    end
  );
end;

initialization

finalization
  if GWizardIndex >= 0 then
  begin
    (BorlandIDEServices as IOTAWizardServices).RemoveWizard(GWizardIndex);
    GWizardIndex := -1;
  end;

end.
