unit XmlDoc.ErrorHandler;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  ToolsAPI,
  XmlDoc.Logger;

type
  /// <summary>에러 심각도</summary>
  TErrorSeverity = (
    esRecoverable,
    esElementSkip,
    esUnitSkip,
    esFatal
  );

  /// <summary>플러그인 에러 정보</summary>
  TPluginError = record
    Context: string;
    ExceptionClass: string;
    FileName: string;
    Line: Integer;
    Message: string;
    Severity: TErrorSeverity;
    Timestamp: TDateTime;
  end;

  TErrorCallback = reference to procedure(const AError: TPluginError);

  /// <summary>플러그인 전역 에러 핸들러. IDE 메시지 패널 통합을 지원합니다.</summary>
  TErrorHandler = class
  strict private
    class var FInstance: TErrorHandler;
  private
    FErrors: TList<TPluginError>;
    FOnError: TErrorCallback;
  public
    constructor Create;
    destructor Destroy; override;

    class function Instance: TErrorHandler;
    class procedure ReleaseInstance;

    /// <summary>예외를 처리하고 로그에 기록합니다.</summary>
    /// <param name="E">발생한 예외</param>
    /// <param name="ASeverity">에러 심각도</param>
    /// <param name="AContext">발생 모듈/메서드 컨텍스트</param>
    procedure HandleException(E: Exception; ASeverity: TErrorSeverity; const AContext: string);

    /// <summary>IDE 메시지 패널에 메시지를 출력합니다.</summary>
    /// <param name="AMsg">출력할 메시지</param>
    /// <param name="AFileName">관련 파일 이름 (선택)</param>
    /// <param name="ALine">관련 행 번호 (선택)</param>
    procedure ReportToIDE(const AMsg: string; const AFileName: string = ''; ALine: Integer = 0);

    /// <summary>에러를 직접 추가합니다.</summary>
    /// <param name="ASeverity">심각도</param>
    /// <param name="AMessage">메시지</param>
    /// <param name="AContext">컨텍스트</param>
    procedure AddError(ASeverity: TErrorSeverity; const AMessage, AContext: string);

    /// <summary>에러 목록을 초기화합니다.</summary>
    procedure ClearErrors;

    property Errors: TList<TPluginError> read FErrors;
    property OnError: TErrorCallback read FOnError write FOnError;
  end;

implementation

{ TErrorHandler }

constructor TErrorHandler.Create;
begin
  inherited Create;
  FErrors := TList<TPluginError>.Create;
end;

destructor TErrorHandler.Destroy;
begin
  FErrors.Free;
  inherited;
end;

class function TErrorHandler.Instance: TErrorHandler;
begin
  if not Assigned(FInstance) then
    FInstance := TErrorHandler.Create;
  Result := FInstance;
end;

class procedure TErrorHandler.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

procedure TErrorHandler.HandleException(E: Exception; ASeverity: TErrorSeverity; const AContext: string);
var
  LError: TPluginError;
begin
  LError.Timestamp := Now;
  LError.Severity := ASeverity;
  LError.Message := E.Message;
  LError.Context := AContext;
  LError.ExceptionClass := E.ClassName;
  LError.FileName := '';
  LError.Line := -1;
  FErrors.Add(LError);

  // 로깅
  case ASeverity of
    esRecoverable:
      TLogger.Instance.Warn(Format('%s: %s', [E.ClassName, E.Message]), AContext);
    esElementSkip, esUnitSkip:
      TLogger.Instance.Error(E, AContext);
    esFatal:
      TLogger.Instance.Fatal(Format('%s: %s', [E.ClassName, E.Message]), AContext);
  end;

  // 콜백
  if Assigned(FOnError) then
    FOnError(LError);

  // IDE 메시지 패널 출력
  ReportToIDE(Format('[XmlDoc] %s — %s: %s', [AContext, E.ClassName, E.Message]));
end;

procedure TErrorHandler.ReportToIDE(const AMsg: string; const AFileName: string; ALine: Integer);
var
  LMsgServices: IOTAMessageServices;
begin
  if Supports(BorlandIDEServices, IOTAMessageServices, LMsgServices) then
  begin
    LMsgServices.AddToolMessage(AFileName, AMsg, 'XmlDoc', ALine, 0);
    LMsgServices.ShowMessageView(nil);
  end;
end;

procedure TErrorHandler.AddError(ASeverity: TErrorSeverity; const AMessage, AContext: string);
var
  LError: TPluginError;
begin
  LError.Timestamp := Now;
  LError.Severity := ASeverity;
  LError.Message := AMessage;
  LError.Context := AContext;
  LError.ExceptionClass := '';
  LError.FileName := '';
  LError.Line := -1;
  FErrors.Add(LError);

  if Assigned(FOnError) then
    FOnError(LError);
end;

procedure TErrorHandler.ClearErrors;
begin
  FErrors.Clear;
end;

initialization

finalization
  TErrorHandler.ReleaseInstance;

end.
