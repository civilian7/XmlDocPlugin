unit XmlDoc.Plugin.DocExplorer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.JSON,
  System.Win.Registry,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Edge,
  WebView2,
  DockForm,
  ToolsAPI,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.Parser,
  XmlDoc.CodeGen.OTA,
  XmlDoc.StubGen;

type
  /// <summary>유닛 전체의 XML 문서를 탐색·편집할 수 있는 도킹 패널 (전체 브라우저 기반)</summary>
  TDocExplorerForm = class(TDockableForm)
  private
    FBrowser: TEdgeBrowser;
    FBrowserReady: Boolean;
    FCurrentFileName: string;
    FDocParser: TDocParser;
    FElements: TArray<TCodeElementInfo>;
    FFilePollTimer: TTimer;
    FInitTimer: TTimer;
    FLastSource: string;
    FPendingLoad: Boolean;
    FUpdatingSource: Boolean;

    procedure BrowserCreateWebViewCompleted(Sender: TCustomEdgeBrowser; AResult: HRESULT);
    procedure BrowserNavigationCompleted(Sender: TCustomEdgeBrowser; IsSuccess: Boolean; WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS);
    procedure BrowserWebMessageReceived(Sender: TCustomEdgeBrowser; Args: TWebMessageReceivedEventArgs);
    function BuildElementJson(const AElement: TCodeElementInfo): string;
    function BuildDocJson(const AElement: TCodeElementInfo): string;
    function BuildLoadTreeScript: string;
    procedure FilePollTimerFired(Sender: TObject);
    function FindElementByFullName(const AFullName: string): TCodeElementInfo;
    procedure HandleDocUpdated(const AJsonStr, AFullName: string);
    procedure HandleJumpToLine(ALine: Integer);
    procedure InitTimerFired(Sender: TObject);
    procedure LoadBounds;
    function ReadEditorSource(const AEditor: IOTASourceEditor): string;
    procedure SaveBounds;
    procedure SendTreeToEditor;
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>에디터 노티파이어에서 파일/소스 변경 시 호출합니다.</summary>
    /// <param name="AFileName">현재 파일 이름</param>
    /// <param name="ASource">에디터 전체 소스</param>
    procedure HandleFileChanged(const AFileName, ASource: string);

    /// <summary>현재 에디터에서 즉시 새로고침합니다.</summary>
    procedure RefreshFromCurrentEditor;
  end;

implementation

uses
  XmlDoc.Plugin.DocInspector;

const
  CExplorerResourceName = 'XMLDOC_EXPLORER_HTML';

{ TDocExplorerForm }

constructor TDocExplorerForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Caption := 'Documentation Explorer';
  DeskSection := 'XmlDocPlugin';
  AutoSave := True;
  KeyPreview := True;

  FDocParser := TDocParser.Create;
  FBrowserReady := False;
  FPendingLoad := False;
  FUpdatingSource := False;
  FCurrentFileName := '';
  FLastSource := '';

  LoadBounds;

  // 브라우저 지연 생성
  FInitTimer := TTimer.Create(Self);
  FInitTimer.Interval := 300;
  FInitTimer.Enabled := True;
  FInitTimer.OnTimer := InitTimerFired;

  // 파일 변경 감지 폴링
  FFilePollTimer := TTimer.Create(Self);
  FFilePollTimer.Interval := 1000;
  FFilePollTimer.Enabled := True;
  FFilePollTimer.OnTimer := FilePollTimerFired;
end;

destructor TDocExplorerForm.Destroy;
begin
  SaveBounds;
  FDocParser.Free;

  inherited;
end;

procedure TDocExplorerForm.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    Key := 0;
    Hide;
    Exit;
  end;

  inherited KeyDown(Key, Shift);
end;

procedure TDocExplorerForm.InitTimerFired(Sender: TObject);
var
  LDataDir: string;
begin
  FInitTimer.Enabled := False;

  if Assigned(FBrowser) then
    Exit;

  if not HandleAllocated then
  begin
    FInitTimer.Enabled := True;
    Exit;
  end;

  LDataDir := TPath.Combine(
    TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'), 'XmlDocPlugin'), 'WebView2');
  ForceDirectories(LDataDir);

  FBrowser := TEdgeBrowser.Create(Self);
  FBrowser.UserDataFolder := LDataDir;
  FBrowser.OnCreateWebViewCompleted := BrowserCreateWebViewCompleted;
  FBrowser.OnNavigationCompleted := BrowserNavigationCompleted;
  FBrowser.OnWebMessageReceived := BrowserWebMessageReceived;
  FBrowser.Parent := Self;
  FBrowser.Align := alClient;

  if not FBrowser.WebViewCreated then
    FBrowser.ReinitializeWebView;
end;

procedure TDocExplorerForm.BrowserCreateWebViewCompleted(Sender: TCustomEdgeBrowser; AResult: HRESULT);
var
  LStream: TResourceStream;
  LBytes: TBytes;
  LHtml: string;
begin
  if AResult <> S_OK then
    Exit;

  try
    LStream := TResourceStream.Create(
      FindClassHInstance(TDocInspectorForm), CExplorerResourceName, RT_RCDATA);
    try
      SetLength(LBytes, LStream.Size);
      LStream.ReadBuffer(LBytes, Length(LBytes));
    finally
      LStream.Free;
    end;
  except
    on E: Exception do
      Exit;
  end;

  LHtml := TEncoding.UTF8.GetString(LBytes);
  FBrowser.NavigateToString(LHtml);
end;

procedure TDocExplorerForm.BrowserNavigationCompleted(Sender: TCustomEdgeBrowser;
  IsSuccess: Boolean; WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS);
begin
  if not IsSuccess then
    Exit;

  FBrowserReady := True;

  if FPendingLoad then
  begin
    FPendingLoad := False;
    SendTreeToEditor;
  end;
end;

procedure TDocExplorerForm.BrowserWebMessageReceived(Sender: TCustomEdgeBrowser;
  Args: TWebMessageReceivedEventArgs);
var
  LJson: PWideChar;
  LMsg: TJSONObject;
  LMsgType: string;
  LDocObj: TJSONObject;
  LFullName: string;
  LLine: Integer;
begin
  Args.ArgsInterface.TryGetWebMessageAsString(LJson);
  if LJson = nil then
    Exit;

  LMsg := TJSONObject.ParseJSONValue(string(LJson)) as TJSONObject;
  if LMsg = nil then
    Exit;

  try
    LMsgType := LMsg.GetValue<string>('type');

    if LMsgType = 'docUpdated' then
    begin
      LDocObj := LMsg.GetValue<TJSONObject>('doc');
      LFullName := LMsg.GetValue<string>('elementFullName', '');
      if Assigned(LDocObj) and (LFullName <> '') then
        HandleDocUpdated(LDocObj.ToJSON, LFullName);
    end
    else if LMsgType = 'jumpToLine' then
    begin
      LLine := LMsg.GetValue<Integer>('line', 0);
      if LLine > 0 then
        HandleJumpToLine(LLine);
    end;
  finally
    LMsg.Free;
  end;
end;

function TDocExplorerForm.BuildElementJson(const AElement: TCodeElementInfo): string;
var
  LObj: TJSONObject;
  LParams: TJSONArray;
  LParam: TJSONObject;
  LGenericParams: TJSONArray;
  I: Integer;
begin
  LObj := TJSONObject.Create;
  try
    LObj.AddPair('kind', AElement.Kind.ToString);
    LObj.AddPair('name', AElement.Name);
    LObj.AddPair('fullName', AElement.FullName);
    LObj.AddPair('qualifiedParent', AElement.QualifiedParent);
    LObj.AddPair('returnType', AElement.ReturnType);
    LObj.AddPair('visibility', AElement.Visibility);
    LObj.AddPair('lineNumber', TJSONNumber.Create(AElement.LineNumber));
    LObj.AddPair('fileName', ExtractFileName(FCurrentFileName));

    if AElement.MethodKind <> '' then
      LObj.AddPair('methodKind', AElement.MethodKind);

    LParams := TJSONArray.Create;
    for I := 0 to Length(AElement.Params) - 1 do
    begin
      LParam := TJSONObject.Create;
      LParam.AddPair('name', AElement.Params[I].Name);
      LParam.AddPair('type', AElement.Params[I].TypeName);
      if AElement.Params[I].IsConst then
        LParam.AddPair('isConst', TJSONBool.Create(True));
      if AElement.Params[I].IsVar then
        LParam.AddPair('isVar', TJSONBool.Create(True));
      if AElement.Params[I].IsOut then
        LParam.AddPair('isOut', TJSONBool.Create(True));
      if AElement.Params[I].DefaultValue <> '' then
        LParam.AddPair('defaultValue', AElement.Params[I].DefaultValue);
      LParams.AddElement(LParam);
    end;
    LObj.AddPair('params', LParams);

    if Length(AElement.GenericParams) > 0 then
    begin
      LGenericParams := TJSONArray.Create;
      for I := 0 to Length(AElement.GenericParams) - 1 do
        LGenericParams.Add(AElement.GenericParams[I]);
      LObj.AddPair('genericParams', LGenericParams);
    end;

    Result := LObj.ToJSON;
  finally
    LObj.Free;
  end;
end;

function TDocExplorerForm.BuildDocJson(const AElement: TCodeElementInfo): string;
var
  LModel: TXmlDocModel;
begin
  if AElement.ExistingDocXml <> '' then
  begin
    LModel := TXmlDocModel.Create;
    try
      LModel.LoadFromXml(AElement.ExistingDocXml);
      Result := LModel.ToJson;
    finally
      LModel.Free;
    end;
  end
  else
  begin
    LModel := TDocStubGenerator.GenerateStub(AElement);
    try
      Result := LModel.ToJson;
    finally
      LModel.Free;
    end;
  end;
end;

function TDocExplorerForm.BuildLoadTreeScript: string;
var
  LArr: TJSONArray;
  LObj: TJSONObject;
  LDocJson: string;
  LSeen: TDictionary<string, Boolean>;
  I: Integer;
begin
  LArr := TJSONArray.Create;
  LSeen := TDictionary<string, Boolean>.Create;
  try
    for I := 0 to Length(FElements) - 1 do
    begin
      // 이름이 없는 요소는 건너뛰기
      if FElements[I].Name = '' then
        Continue;

      // FullName 기준 중복 제거 (interface 선언이 implementation보다 먼저 나옴)
      if LSeen.ContainsKey(FElements[I].FullName) then
        Continue;

      LSeen.Add(FElements[I].FullName, True);

      // 요소 JSON 파싱 후 doc 필드 추가
      LObj := TJSONObject.ParseJSONValue(BuildElementJson(FElements[I])) as TJSONObject;
      if Assigned(LObj) then
      begin
        LDocJson := BuildDocJson(FElements[I]);
        LObj.AddPair('doc', TJSONObject.ParseJSONValue(LDocJson));
        LArr.AddElement(LObj);
      end;
    end;

    Result := Format(
      'window.bridge.receive({"type":"loadTree","data":{"fileName":"%s","elements":%s}});',
      [TJSONString.Create(ExtractFileName(FCurrentFileName)).Value, LArr.ToJSON]
    );
  finally
    LSeen.Free;
    LArr.Free;
  end;
end;

procedure TDocExplorerForm.SendTreeToEditor;
var
  LScript: string;
begin
  if not FBrowserReady then
  begin
    FPendingLoad := True;
    Exit;
  end;

  LScript := BuildLoadTreeScript;
  FBrowser.ExecuteScript(LScript);
end;

function TDocExplorerForm.FindElementByFullName(const AFullName: string): TCodeElementInfo;
var
  I: Integer;
begin
  Result := Default(TCodeElementInfo);

  for I := 0 to Length(FElements) - 1 do
  begin
    if FElements[I].FullName = AFullName then
    begin
      Result := FElements[I];
      Exit;
    end;
  end;
end;

procedure TDocExplorerForm.HandleDocUpdated(const AJsonStr, AFullName: string);
var
  LEditor: IOTASourceEditor;
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
  LSource: string;
begin
  if FUpdatingSource then
    Exit;

  LElement := FindElementByFullName(AFullName);
  if LElement.Name = '' then
    Exit;

  LEditor := TDocOTAWriter.GetCurrentSourceEditor;
  if not Assigned(LEditor) then
    Exit;

  LModel := TXmlDocModel.Create;
  try
    LModel.FromJson(AJsonStr);

    FUpdatingSource := True;
    try
      TDocOTAWriter.ApplyToEditor(LEditor, LElement, LModel);

      // 소스 재파싱 + 트리 재전송
      LSource := ReadEditorSource(LEditor);
      if LSource <> '' then
      begin
        FLastSource := LSource;
        FDocParser.ParseSource(LSource);
        FElements := FDocParser.GetAllElements;
        SendTreeToEditor;
      end;
    finally
      FUpdatingSource := False;
    end;
  finally
    LModel.Free;
  end;
end;

procedure TDocExplorerForm.HandleJumpToLine(ALine: Integer);
var
  LActionServices: IOTAActionServices;
  LEditorServices: IOTAEditorServices;
  LEditView: IOTAEditView;
  LPos: TOTAEditPos;
begin
  if Supports(BorlandIDEServices, IOTAActionServices, LActionServices) then
    LActionServices.OpenFile(FCurrentFileName);

  if Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
  begin
    LEditView := LEditorServices.TopView;
    if Assigned(LEditView) then
    begin
      LPos.Line := ALine;
      LPos.Col := 1;
      LEditView.SetCursorPos(LPos);
      LEditView.MoveViewToCursor;
      LEditView.Paint;
    end;
  end;
end;

procedure TDocExplorerForm.HandleFileChanged(const AFileName, ASource: string);
begin
  if FUpdatingSource then
    Exit;

  if not Visible then
    Exit;

  // 소스가 동일하면 무시
  if SameText(AFileName, FCurrentFileName) and (FLastSource = ASource) then
    Exit;

  FCurrentFileName := AFileName;
  FLastSource := ASource;
  FDocParser.ParseSource(ASource);
  FElements := FDocParser.GetAllElements;
  SendTreeToEditor;
end;

procedure TDocExplorerForm.RefreshFromCurrentEditor;
var
  LEditor: IOTASourceEditor;
  LSource: string;
  LFileName: string;
begin
  LEditor := TDocOTAWriter.GetCurrentSourceEditor;
  if not Assigned(LEditor) then
    Exit;

  LFileName := LEditor.FileName;
  if not LFileName.EndsWith('.pas', True) then
    Exit;

  LSource := ReadEditorSource(LEditor);
  if LSource = '' then
    Exit;

  FCurrentFileName := LFileName;
  FLastSource := LSource;
  FDocParser.ParseSource(LSource);
  FElements := FDocParser.GetAllElements;
  SendTreeToEditor;
end;

function TDocExplorerForm.ReadEditorSource(const AEditor: IOTASourceEditor): string;
var
  LReader: IOTAEditReader;
  LStream: TMemoryStream;
  LBuffer: TBytes;
  LBytesRead: Integer;
  LPos: Integer;
  LChunkSize: Integer;
begin
  Result := '';

  LReader := AEditor.CreateReader;
  if not Assigned(LReader) then
    Exit;

  LStream := TMemoryStream.Create;
  try
    LPos := 0;
    LChunkSize := 32768;
    repeat
      SetLength(LBuffer, LChunkSize);
      LBytesRead := LReader.GetText(LPos, PAnsiChar(LBuffer), LChunkSize);
      if LBytesRead > 0 then
      begin
        LStream.WriteBuffer(LBuffer, LBytesRead);
        Inc(LPos, LBytesRead);
      end;
    until LBytesRead < LChunkSize;

    SetLength(LBuffer, LStream.Size);
    LStream.Position := 0;
    LStream.ReadBuffer(LBuffer, Length(LBuffer));

    if (Length(LBuffer) >= 3) and
       (LBuffer[0] = $EF) and (LBuffer[1] = $BB) and (LBuffer[2] = $BF) then
      Result := TEncoding.UTF8.GetString(LBuffer, 3, Length(LBuffer) - 3)
    else
      Result := TEncoding.UTF8.GetString(LBuffer);
  finally
    LStream.Free;
  end;
end;

procedure TDocExplorerForm.FilePollTimerFired(Sender: TObject);
var
  LEditor: IOTASourceEditor;
  LFileName: string;
  LSource: string;
begin
  if not Visible then
    Exit;

  if FUpdatingSource then
    Exit;

  LEditor := TDocOTAWriter.GetCurrentSourceEditor;
  if not Assigned(LEditor) then
    Exit;

  LFileName := LEditor.FileName;
  if not LFileName.EndsWith('.pas', True) then
    Exit;

  if not SameText(LFileName, FCurrentFileName) then
  begin
    LSource := ReadEditorSource(LEditor);
    if LSource <> '' then
      HandleFileChanged(LFileName, LSource);
  end;
end;

procedure TDocExplorerForm.LoadBounds;
const
  CRegKey = 'Software\XmlDocPlugin\DocExplorer';
var
  LReg: TRegistry;
begin
  Width := 800;
  Height := 600;

  LReg := TRegistry.Create(KEY_READ);
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if LReg.OpenKeyReadOnly(CRegKey) then
    begin
      if LReg.ValueExists('Left') then
        Left := LReg.ReadInteger('Left');
      if LReg.ValueExists('Top') then
        Top := LReg.ReadInteger('Top');
      if LReg.ValueExists('Width') then
        Width := LReg.ReadInteger('Width');
      if LReg.ValueExists('Height') then
        Height := LReg.ReadInteger('Height');
      LReg.CloseKey;
    end;
  finally
    LReg.Free;
  end;
end;

procedure TDocExplorerForm.SaveBounds;
const
  CRegKey = 'Software\XmlDocPlugin\DocExplorer';
var
  LReg: TRegistry;
begin
  LReg := TRegistry.Create(KEY_WRITE);
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if LReg.OpenKey(CRegKey, True) then
    begin
      LReg.WriteInteger('Left', Left);
      LReg.WriteInteger('Top', Top);
      LReg.WriteInteger('Width', Width);
      LReg.WriteInteger('Height', Height);
      LReg.CloseKey;
    end;
  finally
    LReg.Free;
  end;
end;

end.
