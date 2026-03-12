unit XmlDoc.Plugin.EditorNotifier;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.ExtCtrls,
  ToolsAPI,
  DockForm;

type
  /// <summary>커서 변경 콜백 시그니처</summary>
  /// <param name="ALine">현재 커서 행 (1-based)</param>
  /// <param name="ASource">현재 에디터 소스 전체</param>
  /// <param name="AFileName">현재 파일 이름</param>
  TCursorChangedProc = reference to procedure(ALine: Integer; const ASource, AFileName: string);

  /// <summary>에디터 이벤트 감시. 커서 이동 시 디바운싱 적용 후 콜백을 호출합니다.</summary>
  TXmlDocEditorNotifier = class(TNotifierObject, INTAEditServicesNotifier)
  private
    FDebounceTimer: TTimer;
    FLastNotifiedLine: Integer;
    FLastNotifiedFileName: string;
    FPendingFileName: string;
    FPendingLine: Integer;
    FPendingSource: string;

    FOnCursorChanged: TCursorChangedProc;

    procedure DebounceTimerFired(Sender: TObject);
    function GetCurrentSource(const AView: IOTAEditView): string;
    procedure ScheduleNotify(ALine: Integer; const ASource, AFileName: string);
  public
    constructor Create(AOnCursorChanged: TCursorChangedProc);
    destructor Destroy; override;

    { INTAEditServicesNotifier }
    procedure DockFormRefresh(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
    procedure DockFormUpdated(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
    procedure DockFormVisibleChanged(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
    procedure EditorViewActivated(const EditWindow: INTAEditWindow; const EditView: IOTAEditView);
    procedure EditorViewModified(const EditWindow: INTAEditWindow; const EditView: IOTAEditView);
    procedure WindowActivated(const EditWindow: INTAEditWindow);
    procedure WindowCommand(const EditWindow: INTAEditWindow; Command, Param: Integer; var Handled: Boolean);
    procedure WindowNotification(const EditWindow: INTAEditWindow; Operation: TOperation);
    procedure WindowShow(const EditWindow: INTAEditWindow; Show, LoadedFromDesktop: Boolean);
  end;

implementation

const
  CDebounceMs = 300;

{ TXmlDocEditorNotifier }

constructor TXmlDocEditorNotifier.Create(AOnCursorChanged: TCursorChangedProc);
begin
  inherited Create;

  FOnCursorChanged := AOnCursorChanged;
  FLastNotifiedLine := -1;
  FLastNotifiedFileName := '';
  FPendingLine := -1;

  FDebounceTimer := TTimer.Create(nil);
  FDebounceTimer.Interval := CDebounceMs;
  FDebounceTimer.Enabled := False;
  FDebounceTimer.OnTimer := DebounceTimerFired;
end;

destructor TXmlDocEditorNotifier.Destroy;
begin
  FDebounceTimer.Free;

  inherited;
end;

procedure TXmlDocEditorNotifier.ScheduleNotify(ALine: Integer; const ASource, AFileName: string);
begin
  // 같은 행/파일이면 무시
  if (ALine = FLastNotifiedLine) and (AFileName = FLastNotifiedFileName) then
    Exit;

  // 보류 데이터 저장 후 타이머 리셋
  FPendingLine := ALine;
  FPendingSource := ASource;
  FPendingFileName := AFileName;

  FDebounceTimer.Enabled := False;
  FDebounceTimer.Enabled := True;
end;

procedure TXmlDocEditorNotifier.DebounceTimerFired(Sender: TObject);
begin
  FDebounceTimer.Enabled := False;

  if FPendingLine < 0 then
    Exit;

  FLastNotifiedLine := FPendingLine;
  FLastNotifiedFileName := FPendingFileName;

  if Assigned(FOnCursorChanged) then
    FOnCursorChanged(FPendingLine, FPendingSource, FPendingFileName);

  FPendingLine := -1;
  FPendingSource := '';
  FPendingFileName := '';
end;

function TXmlDocEditorNotifier.GetCurrentSource(const AView: IOTAEditView): string;
var
  LEditor: IOTASourceEditor;
  LReader: IOTAEditReader;
  LBuffer: TBytes;
  LBytesRead: Integer;
  LPos: Integer;
  LChunkSize: Integer;
  LStream: TMemoryStream;
begin
  Result := '';
  if not Assigned(AView) then
    Exit;

  LEditor := AView.Buffer;
  if not Assigned(LEditor) then
    Exit;

  LReader := LEditor.CreateReader;
  if not Assigned(LReader) then
    Exit;

  // IOTAEditReader.GetText는 raw bytes를 반환 — UTF-8 BOM 파일이면 UTF-8 바이트
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

    // UTF-8 BOM(EF BB BF) 감지 후 적절한 인코딩으로 디코딩
    if (Length(LBuffer) >= 3) and
       (LBuffer[0] = $EF) and (LBuffer[1] = $BB) and (LBuffer[2] = $BF) then
      Result := TEncoding.UTF8.GetString(LBuffer, 3, Length(LBuffer) - 3)
    else
      Result := TEncoding.UTF8.GetString(LBuffer);
  finally
    LStream.Free;
  end;
end;

procedure TXmlDocEditorNotifier.DockFormRefresh(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
begin
  // not used
end;

procedure TXmlDocEditorNotifier.DockFormUpdated(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
begin
  // not used
end;

procedure TXmlDocEditorNotifier.DockFormVisibleChanged(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
begin
  // not used
end;

procedure TXmlDocEditorNotifier.EditorViewActivated(const EditWindow: INTAEditWindow; const EditView: IOTAEditView);
var
  LLine: Integer;
  LSource: string;
  LFileName: string;
begin
  if not Assigned(EditView) then
    Exit;

  LLine := EditView.CursorPos.Line;
  LSource := GetCurrentSource(EditView);

  if Assigned(EditView.Buffer) then
    LFileName := EditView.Buffer.FileName
  else
    LFileName := '';

  // .pas 파일만 처리
  if not LFileName.EndsWith('.pas', True) then
    Exit;

  ScheduleNotify(LLine, LSource, LFileName);
end;

procedure TXmlDocEditorNotifier.EditorViewModified(const EditWindow: INTAEditWindow; const EditView: IOTAEditView);
begin
  // 편집 시에도 커서 위치 기반으로 다시 파싱
  EditorViewActivated(EditWindow, EditView);
end;

procedure TXmlDocEditorNotifier.WindowActivated(const EditWindow: INTAEditWindow);
begin
  // not used
end;

procedure TXmlDocEditorNotifier.WindowCommand(const EditWindow: INTAEditWindow; Command, Param: Integer; var Handled: Boolean);
begin
  // not used
end;

procedure TXmlDocEditorNotifier.WindowNotification(const EditWindow: INTAEditWindow; Operation: TOperation);
begin
  // not used
end;

procedure TXmlDocEditorNotifier.WindowShow(const EditWindow: INTAEditWindow; Show, LoadedFromDesktop: Boolean);
begin
  // not used
end;

end.
