unit XmlDoc.Logger;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.SyncObjs;

type
  /// <summary>로그 수준</summary>
  TLogLevel = (llDebug, llInfo, llWarn, llError, llFatal);

  /// <summary>싱글톤 로거. 파일 로테이션과 스레드 안전을 지원합니다.</summary>
  TLogger = class
  strict private
    class var FInstance: TLogger;
  private
    FLevel: TLogLevel;
    FLock: TCriticalSection;
    FLogPath: string;
    FMaxFileSize: Int64;
    FMaxFiles: Integer;
    FWriter: TStreamWriter;

    procedure EnsureWriter;
    function FormatEntry(ALevel: TLogLevel; const AMsg, AContext: string): string;
    function LevelToString(ALevel: TLogLevel): string;
    procedure RotateIfNeeded;
    procedure WriteEntry(ALevel: TLogLevel; const AMsg, AContext: string);

  public
    constructor Create;
    destructor Destroy; override;

    class function Instance: TLogger;
    class procedure ReleaseInstance;

    procedure Debug(const AMsg: string; const AContext: string = '');
    procedure Error(const AMsg: string; const AContext: string = ''); overload;
    procedure Error(E: Exception; const AContext: string = ''); overload;
    procedure Fatal(const AMsg: string; const AContext: string = '');
    procedure Info(const AMsg: string; const AContext: string = '');
    procedure Warn(const AMsg: string; const AContext: string = '');

    property Level: TLogLevel read FLevel write FLevel;
    property LogPath: string read FLogPath write FLogPath;
  end;

implementation

const
  CDefaultMaxFileSize = 5 * 1024 * 1024;  // 5 MB
  CDefaultMaxFiles = 3;

{ TLogger }

constructor TLogger.Create;
var
  LAppData: string;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FLevel := llInfo;
  FMaxFileSize := CDefaultMaxFileSize;
  FMaxFiles := CDefaultMaxFiles;

  LAppData := TPath.Combine(TPath.GetHomePath, 'XmlDocPlugin');
  if not TDirectory.Exists(LAppData) then
    TDirectory.CreateDirectory(LAppData);

  FLogPath := TPath.Combine(LAppData, 'xmldocplugin.log');
end;

destructor TLogger.Destroy;
begin
  FWriter.Free;
  FLock.Free;
  inherited;
end;

class function TLogger.Instance: TLogger;
begin
  if not Assigned(FInstance) then
    FInstance := TLogger.Create;
  Result := FInstance;
end;

class procedure TLogger.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

procedure TLogger.EnsureWriter;
begin
  if not Assigned(FWriter) then
  begin
    FWriter := TStreamWriter.Create(
      TFileStream.Create(FLogPath, fmOpenWrite or fmShareDenyNone), TEncoding.UTF8
    );
    FWriter.OwnStream;
    FWriter.AutoFlush := True;
    FWriter.BaseStream.Seek(0, soEnd);
  end;
end;

function TLogger.FormatEntry(ALevel: TLogLevel;
  const AMsg, AContext: string): string;
begin
  if AContext <> '' then
    Result := Format('%s [%s] [%s] %s',
      [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now),
       LevelToString(ALevel), AContext, AMsg])
  else
    Result := Format('%s [%s] %s',
      [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now),
       LevelToString(ALevel), AMsg]);
end;

function TLogger.LevelToString(ALevel: TLogLevel): string;
begin
  case ALevel of
    llDebug: Result := 'DEBUG';
    llInfo:  Result := 'INFO';
    llWarn:  Result := 'WARN';
    llError: Result := 'ERROR';
    llFatal: Result := 'FATAL';
  else
    Result := '?';
  end;
end;

procedure TLogger.RotateIfNeeded;
var
  I: Integer;
  LSrc: string;
  LDst: string;
begin
  if not TFile.Exists(FLogPath) then
    Exit;

  if TFile.GetSize(FLogPath) < FMaxFileSize then
    Exit;

  FreeAndNil(FWriter);

  // 로그 파일 회전: .log.3 → 삭제, .log.2 → .log.3, .log.1 → .log.2, .log → .log.1
  for I := FMaxFiles downto 1 do
  begin
    LSrc := FLogPath + '.' + IntToStr(I);
    LDst := FLogPath + '.' + IntToStr(I + 1);
    if I = FMaxFiles then
    begin
      if TFile.Exists(LSrc) then
        TFile.Delete(LSrc);
    end
    else
    begin
      if TFile.Exists(LSrc) then
        TFile.Move(LSrc, LDst);
    end;
  end;

  if TFile.Exists(FLogPath) then
    TFile.Move(FLogPath, FLogPath + '.1');
end;

procedure TLogger.WriteEntry(ALevel: TLogLevel; const AMsg, AContext: string);
begin
  if Ord(ALevel) < Ord(FLevel) then
    Exit;

  FLock.Enter;
  try
    try
      RotateIfNeeded;
      EnsureWriter;
      FWriter.WriteLine(FormatEntry(ALevel, AMsg, AContext));
    except
      // 로그 실패는 무시
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLogger.Debug(const AMsg, AContext: string);
begin
  WriteEntry(llDebug, AMsg, AContext);
end;

procedure TLogger.Info(const AMsg, AContext: string);
begin
  WriteEntry(llInfo, AMsg, AContext);
end;

procedure TLogger.Warn(const AMsg, AContext: string);
begin
  WriteEntry(llWarn, AMsg, AContext);
end;

procedure TLogger.Error(const AMsg, AContext: string);
begin
  WriteEntry(llError, AMsg, AContext);
end;

procedure TLogger.Error(E: Exception; const AContext: string);
begin
  WriteEntry(llError, Format('%s: %s', [E.ClassName, E.Message]), AContext);
end;

procedure TLogger.Fatal(const AMsg, AContext: string);
begin
  WriteEntry(llFatal, AMsg, AContext);
end;

initialization

finalization
  TLogger.ReleaseInstance;

end.
