unit XmlDoc.Plugin.DocInspector;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.Win.Registry,
  Winapi.Messages,
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
  XmlDoc.CodeGen,
  XmlDoc.CodeGen.OTA,
  XmlDoc.ParamDict,
  XmlDoc.StubGen;

type
  /// <summary>WebView2 기반 XML 문서 편집기를 호스팅하는 Dockable 패널</summary>
  TDocInspectorForm = class(TDockableForm)
  private
    FBrowser: TEdgeBrowser;
    FBrowserReady: Boolean;
    FCursorPollTimer: TTimer;
    FCurrentElement: TCodeElementInfo;
    FDocModel: TXmlDocModel;
    FDocParser: TDocParser;
    FInitTimer: TTimer;
    FLastElementLine: Integer;
    FLastElementName: string;
    FLastFileName: string;
    FLastPolledLine: Integer;
    FPendingLoad: Boolean;
    FUpdatingSource: Boolean;
    FParamDictLoaded: Boolean;

    procedure BrowserCreateWebViewCompleted(Sender: TCustomEdgeBrowser; AResult: HRESULT);
    procedure BrowserNavigationCompleted(Sender: TCustomEdgeBrowser; IsSuccess: Boolean; WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS);
    procedure BrowserWebMessageReceived(Sender: TCustomEdgeBrowser; Args: TWebMessageReceivedEventArgs);
    function BuildElementJson: string;
    function BuildLoadDocScript: string;
    procedure CaptureParamDescriptions;
    procedure CursorPollTimerFired(Sender: TObject);
    procedure EnsureParamDictLoaded;
    function GetParamDictPath: string;
    procedure HandleDocUpdated(const AJsonStr: string);
    procedure InitTimerFired(Sender: TObject);
    function IsSameElement(const AElement: TCodeElementInfo): Boolean;
    procedure LoadBounds;
    procedure SaveBounds;
    procedure SendToEditor(const AMessageType, APayload: string);
    procedure UpdateFromCursor;
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>에디터 노티파이어에서 커서 변경 시 호출합니다.</summary>
    /// <param name="ALine">현재 커서 행 (1-based)</param>
    /// <param name="ASource">에디터 전체 소스</param>
    /// <param name="AFileName">현재 파일 이름</param>
    procedure HandleCursorChanged(ALine: Integer; const ASource, AFileName: string);

    /// <summary>현재 에디터의 커서 위치에서 즉시 새로고침합니다.</summary>
    procedure RefreshFromCurrentEditor;
  end;

implementation

{$R XmlDocEditor.res}

const
  CEditorResourceName = 'XMLDOC_EDITOR_HTML';

{ TDocInspectorForm }

constructor TDocInspectorForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Caption := 'Doc Inspector';
  DeskSection := 'XmlDocPlugin';
  AutoSave := True;
  KeyPreview := True;

  FDocModel := TXmlDocModel.Create;
  FDocParser := TDocParser.Create;
  FBrowserReady := False;
  FParamDictLoaded := False;
  FPendingLoad := False;
  FUpdatingSource := False;
  FLastFileName := '';
  FLastElementName := '';
  FLastElementLine := -1;
  FLastPolledLine := -1;

  LoadBounds;

  // TTimer로 브라우저 생성 지연 — 폼이 완전히 표시된 후 실행
  FInitTimer := TTimer.Create(Self);
  FInitTimer.Interval := 300;
  FInitTimer.Enabled := True;
  FInitTimer.OnTimer := InitTimerFired;

  // 커서 위치 폴링 타이머 — EditorViewModified가 순수 커서 이동을 감지하지 못하므로
  FCursorPollTimer := TTimer.Create(Self);
  FCursorPollTimer.Interval := 500;
  FCursorPollTimer.Enabled := True;
  FCursorPollTimer.OnTimer := CursorPollTimerFired;
end;

destructor TDocInspectorForm.Destroy;
begin
  TParamDictionary.Instance.SaveToFile;
  SaveBounds;
  FDocParser.Free;
  FDocModel.Free;

  inherited;
end;

procedure TDocInspectorForm.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    Key := 0;
    Hide;
    Exit;
  end;

  inherited KeyDown(Key, Shift);
end;

procedure TDocInspectorForm.CursorPollTimerFired(Sender: TObject);
var
  LServices: IOTAEditorServices;
  LEditView: IOTAEditView;
  LLine: Integer;
  LFileName: string;
begin
  // 폼이 보이지 않거나 업데이트 중이면 무시
  if not Visible then
    Exit;

  if FUpdatingSource then
    Exit;

  if not Supports(BorlandIDEServices, IOTAEditorServices, LServices) then
    Exit;

  LEditView := LServices.TopView;
  if not Assigned(LEditView) then
    Exit;

  if not Assigned(LEditView.Buffer) then
    Exit;

  LFileName := LEditView.Buffer.FileName;
  if not LFileName.EndsWith('.pas', True) then
    Exit;

  LLine := LEditView.CursorPos.Line;

  // 행이 바뀌지 않았으면 무시
  if (LLine = FLastPolledLine) and (LFileName = FLastFileName) then
    Exit;

  FLastPolledLine := LLine;
  RefreshFromCurrentEditor;
end;

procedure TDocInspectorForm.InitTimerFired(Sender: TObject);
var
  LDataDir: string;
begin
  FInitTimer.Enabled := False;

  // 이미 브라우저가 생성되었으면 스킵
  if Assigned(FBrowser) then
    Exit;

  // 윈도우 핸들이 없으면 다음 틱에 재시도
  if not HandleAllocated then
  begin
    FInitTimer.Enabled := True;
    Exit;
  end;

  // WebView2 UserDataFolder — IDE 프로세스와 분리된 고유 경로
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

  // TDockableForm에서 Parent 설정만으로 자동 초기화되지 않는 경우 명시적 호출
  if not FBrowser.WebViewCreated then
    FBrowser.ReinitializeWebView;
end;

procedure TDocInspectorForm.BrowserCreateWebViewCompleted(Sender: TCustomEdgeBrowser; AResult: HRESULT);
var
  LStream: TResourceStream;
  LBytes: TBytes;
  LHtml: string;
begin
  if AResult <> S_OK then
    Exit;

  // 리소스에서 HTML 로드
  try
    LStream := TResourceStream.Create(
      FindClassHInstance(TDocInspectorForm), CEditorResourceName, RT_RCDATA);
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

procedure TDocInspectorForm.BrowserNavigationCompleted(Sender: TCustomEdgeBrowser; IsSuccess: Boolean; WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS);
begin
  if not IsSuccess then
    Exit;

  FBrowserReady := True;

  // 보류 중인 로드가 있으면 실행
  if FPendingLoad then
  begin
    FPendingLoad := False;
    UpdateFromCursor;
  end;
end;

procedure TDocInspectorForm.BrowserWebMessageReceived(Sender: TCustomEdgeBrowser; Args: TWebMessageReceivedEventArgs);
var
  LJson: PWideChar;
  LMsg: TJSONObject;
  LMsgType: string;
  LDocObj: TJSONObject;
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
      if Assigned(LDocObj) then
        HandleDocUpdated(LDocObj.ToJSON);
    end;
  finally
    LMsg.Free;
  end;
end;

procedure TDocInspectorForm.HandleDocUpdated(const AJsonStr: string);
var
  LEditor: IOTASourceEditor;
  LView: IOTAEditView;
  LReader: IOTAEditReader;
  LStream: TMemoryStream;
  LBuffer: TBytes;
  LBytesRead: Integer;
  LPos: Integer;
  LChunkSize: Integer;
  LSource: string;
  LElement: TCodeElementInfo;
begin
  // 자체 업데이트 중이면 무시 (순환 방지)
  if FUpdatingSource then
    Exit;

  FDocModel.FromJson(AJsonStr);
  CaptureParamDescriptions;

  // 현재 요소가 없으면 쓰기 불가
  if FCurrentElement.Name = '' then
    Exit;

  LEditor := TDocOTAWriter.GetCurrentSourceEditor;
  if not Assigned(LEditor) then
    Exit;

  FUpdatingSource := True;
  try
    TDocOTAWriter.ApplyToEditor(LEditor, FCurrentElement, FDocModel);

    // 쓰기 후 소스를 다시 읽어 AST 재구축 및 FCurrentElement 위치 갱신
    // (주석 삽입/수정으로 줄 번호가 바뀌므로 반드시 갱신 필요)
    LView := LEditor.GetEditView(0);
    if Assigned(LView) then
    begin
      LReader := LEditor.CreateReader;
      if Assigned(LReader) then
      begin
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
            LSource := TEncoding.UTF8.GetString(LBuffer, 3, Length(LBuffer) - 3)
          else
            LSource := TEncoding.UTF8.GetString(LBuffer);
        finally
          LStream.Free;
        end;

        FDocParser.ParseSource(LSource);

        LElement := FDocParser.GetElementAtLine(LView.CursorPos.Line);
        if LElement.Name <> '' then
        begin
          FCurrentElement := LElement;
          FLastElementName := LElement.Name;
          FLastElementLine := LElement.LineNumber;
        end;
      end;
    end;
  finally
    FUpdatingSource := False;
  end;
end;

function TDocInspectorForm.BuildElementJson: string;
var
  LObj: TJSONObject;
  LParams: TJSONArray;
  LParam: TJSONObject;
  LGenericParams: TJSONArray;
  I: Integer;
begin
  LObj := TJSONObject.Create;
  try
    LObj.AddPair('kind', FCurrentElement.Kind.ToString);
    LObj.AddPair('name', FCurrentElement.Name);
    LObj.AddPair('fullName', FCurrentElement.FullName);
    LObj.AddPair('qualifiedParent', FCurrentElement.QualifiedParent);
    LObj.AddPair('returnType', FCurrentElement.ReturnType);
    LObj.AddPair('visibility', FCurrentElement.Visibility);
    LObj.AddPair('lineNumber', TJSONNumber.Create(FCurrentElement.LineNumber));
    LObj.AddPair('fileName', ExtractFileName(FLastFileName));

    if FCurrentElement.MethodKind <> '' then
      LObj.AddPair('methodKind', FCurrentElement.MethodKind);

    LParams := TJSONArray.Create;
    for I := 0 to Length(FCurrentElement.Params) - 1 do
    begin
      LParam := TJSONObject.Create;
      LParam.AddPair('name', FCurrentElement.Params[I].Name);
      LParam.AddPair('type', FCurrentElement.Params[I].TypeName);
      if FCurrentElement.Params[I].IsConst then
        LParam.AddPair('isConst', TJSONBool.Create(True));
      if FCurrentElement.Params[I].IsVar then
        LParam.AddPair('isVar', TJSONBool.Create(True));
      if FCurrentElement.Params[I].IsOut then
        LParam.AddPair('isOut', TJSONBool.Create(True));
      if FCurrentElement.Params[I].DefaultValue <> '' then
        LParam.AddPair('defaultValue', FCurrentElement.Params[I].DefaultValue);
      LParams.AddElement(LParam);
    end;
    LObj.AddPair('params', LParams);

    if Length(FCurrentElement.GenericParams) > 0 then
    begin
      LGenericParams := TJSONArray.Create;
      for I := 0 to Length(FCurrentElement.GenericParams) - 1 do
        LGenericParams.Add(FCurrentElement.GenericParams[I]);
      LObj.AddPair('genericParams', LGenericParams);
    end;

    Result := LObj.ToJSON;
  finally
    LObj.Free;
  end;
end;

function TDocInspectorForm.BuildLoadDocScript: string;
var
  LElementJson: string;
  LDocJson: string;
begin
  LElementJson := BuildElementJson;
  LDocJson := FDocModel.ToJson;

  Result := Format(
    'window.bridge.receive({"type":"loadDoc","data":{"element":%s,"doc":%s}});',
    [LElementJson, LDocJson]
  );
end;

function TDocInspectorForm.IsSameElement(const AElement: TCodeElementInfo): Boolean;
begin
  Result := (AElement.Name = FLastElementName) and
            (AElement.LineNumber = FLastElementLine) and
            (AElement.Kind = FCurrentElement.Kind);
end;

procedure TDocInspectorForm.SendToEditor(const AMessageType, APayload: string);
var
  LScript: string;
begin
  if not FBrowserReady then
    Exit;

  LScript := Format(
    'window.bridge.receive({"type":"%s","data":%s});',
    [AMessageType, APayload]
  );
  FBrowser.ExecuteScript(LScript);
end;

procedure TDocInspectorForm.HandleCursorChanged(ALine: Integer;
  const ASource, AFileName: string);
var
  LElement: TCodeElementInfo;
begin
  // 자체 업데이트 중이면 무시 (순환 방지)
  if FUpdatingSource then
    Exit;

  // 소스 변경 시 재파싱
  if not FDocParser.IsUpToDate(ASource) then
    FDocParser.ParseSource(ASource);

  FLastFileName := AFileName;
  //Caption := Format('Doc Inspector - %s / %d', [ExtractFileName(AFileName), ALine]);
  LElement := FDocParser.GetElementAtLine(ALine);

  // 유효한 코드 요소가 없으면 무시
  if LElement.Name = '' then
    Exit;

  // 동일 요소이면 WebView 갱신 불필요
  if IsSameElement(LElement) then
    Exit;

  FCurrentElement := LElement;
  FLastElementName := LElement.Name;
  FLastElementLine := LElement.LineNumber;

  // 기존 XML 문서 로드 또는 스텁 생성
  if FCurrentElement.ExistingDocXml <> '' then
  begin
    FDocModel.Clear;
    FDocModel.LoadFromXml(FCurrentElement.ExistingDocXml);
  end
  else
  begin
    FDocModel.Free;
    FDocModel := TDocStubGenerator.GenerateStub(FCurrentElement);
  end;

  FDocModel.IsModified := False;

  if FBrowserReady then
    UpdateFromCursor
  else
    FPendingLoad := True;
end;

procedure TDocInspectorForm.RefreshFromCurrentEditor;
var
  LEditor: IOTASourceEditor;
  LView: IOTAEditView;
  LReader: IOTAEditReader;
  LStream: TMemoryStream;
  LBuffer: TBytes;
  LBytesRead: Integer;
  LPos: Integer;
  LChunkSize: Integer;
  LSource: string;
  LLine: Integer;
  LFileName: string;
begin
  LEditor := TDocOTAWriter.GetCurrentSourceEditor;
  if not Assigned(LEditor) then
    Exit;

  LView := LEditor.GetEditView(0);
  if not Assigned(LView) then
    Exit;

  LFileName := LEditor.FileName;
  if not LFileName.EndsWith('.pas', True) then
    Exit;

  LLine := LView.CursorPos.Line;

  // 소스 읽기 (UTF-8 BOM 처리)
  LReader := LEditor.CreateReader;
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
      LSource := TEncoding.UTF8.GetString(LBuffer, 3, Length(LBuffer) - 3)
    else
      LSource := TEncoding.UTF8.GetString(LBuffer);
  finally
    LStream.Free;
  end;

  // 이전 요소 캐시 무효화하여 강제 갱신
  FLastElementName := '';
  FLastElementLine := -1;

  HandleCursorChanged(LLine, LSource, LFileName);
end;

procedure TDocInspectorForm.LoadBounds;
const
  CRegKey = 'Software\XmlDocPlugin\DocInspector';
var
  LReg: TRegistry;
begin
  // 기본 크기
  Width := 420;
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

procedure TDocInspectorForm.SaveBounds;
const
  CRegKey = 'Software\XmlDocPlugin\DocInspector';
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

procedure TDocInspectorForm.CaptureParamDescriptions;
var
  I: Integer;
  LParam: TParamDoc;
begin
  EnsureParamDictLoaded;

  for I := 0 to FDocModel.Params.Count - 1 do
  begin
    LParam := FDocModel.Params[I];
    TParamDictionary.Instance.Register(LParam.Name, LParam.Description);
  end;
end;

procedure TDocInspectorForm.EnsureParamDictLoaded;
var
  LPath: string;
begin
  if FParamDictLoaded then
    Exit;

  LPath := GetParamDictPath;
  if LPath <> '' then
  begin
    TParamDictionary.Instance.LoadFromFile(LPath);
    FParamDictLoaded := True;
  end;
end;

function TDocInspectorForm.GetParamDictPath: string;
var
  LModuleServices: IOTAModuleServices;
  LProject: IOTAProject;
  LProjectDir: string;
begin
  Result := '';

  if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
  begin
    LProject := LModuleServices.GetActiveProject;
    if Assigned(LProject) then
    begin
      LProjectDir := ExtractFilePath(LProject.FileName);
      if LProjectDir <> '' then
      begin
        Result := TPath.Combine(LProjectDir, '.xmldoc-params.json');
        Exit;
      end;
    end;
  end;

  // 프로젝트 없으면 사용자 홈 디렉토리 폴백
  Result := TPath.Combine(TPath.GetHomePath, '.xmldoc-params.json');
end;

procedure TDocInspectorForm.UpdateFromCursor;
var
  LScript: string;
begin
  if not FBrowserReady then
    Exit;

  LScript := BuildLoadDocScript;
  FBrowser.ExecuteScript(LScript);
end;

end.
