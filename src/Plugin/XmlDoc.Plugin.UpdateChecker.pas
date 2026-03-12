unit XmlDoc.Plugin.UpdateChecker;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Win.Registry,
  Winapi.Windows,
  XmlDoc.Logger;

type
  /// <summary>업데이트 정보</summary>
  TUpdateInfo = record
    DownloadURL: string;
    LatestVersion: string;
    ReleaseNotes: string;
  end;

  /// <summary>업데이트 가용 이벤트</summary>
  TUpdateAvailableEvent = procedure(const AInfo: TUpdateInfo) of object;

  /// <summary>비동기 업데이트 확인기. IDE 시작 시 24시간 간격으로 최신 버전을 확인합니다.</summary>
  TUpdateChecker = class
  private
    FCheckURL: string;
    FCurrentVersion: string;
    FOnUpdateAvailable: TUpdateAvailableEvent;

    function GetLastCheckTime: TDateTime;
    function IsNewerVersion(const ALatest, ACurrent: string): Boolean;
    procedure SetLastCheckTime(ATime: TDateTime);
  public
    constructor Create(const ACurrentVersion: string);

    /// <summary>비동기로 업데이트를 확인합니다. 24시간 이내 확인 이력이 있으면 건너뜁니다.</summary>
    procedure CheckAsync;

    /// <summary>즉시 업데이트를 확인합니다 (타이머 무시).</summary>
    procedure CheckNow;

    property CheckURL: string read FCheckURL write FCheckURL;
    property CurrentVersion: string read FCurrentVersion;
    property OnUpdateAvailable: TUpdateAvailableEvent read FOnUpdateAvailable write FOnUpdateAvailable;
  end;

implementation

const
  CDefaultCheckURL = 'https://xmldocplugin.dev/api/v1/latest';
  CRegistryRoot = 'Software\XmlDocPlugin';

{ TUpdateChecker }

constructor TUpdateChecker.Create(const ACurrentVersion: string);
begin
  inherited Create;

  FCurrentVersion := ACurrentVersion;
  FCheckURL := CDefaultCheckURL;
end;

procedure TUpdateChecker.CheckAsync;
var
  LLastCheck: TDateTime;
begin
  LLastCheck := GetLastCheckTime;

  // 24시간 이내 확인했으면 건너뜀
  if (LLastCheck > 0) and (Now - LLastCheck < 1.0) then
    Exit;

  TThread.CreateAnonymousThread(
    procedure
    begin
      CheckNow;
    end
  ).Start;
end;

procedure TUpdateChecker.CheckNow;
var
  LHttp: THTTPClient;
  LResponse: IHTTPResponse;
  LURL: string;
  LJson: TJSONObject;
  LInfo: TUpdateInfo;
begin
  LHttp := THTTPClient.Create;
  try
    LHttp.ConnectionTimeout := 5000;
    LHttp.ResponseTimeout := 10000;

    LURL := FCheckURL + '?current=' + FCurrentVersion;

    try
      LResponse := LHttp.Get(LURL);
      if LResponse.StatusCode <> 200 then
        Exit;

      LJson := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      if not Assigned(LJson) then
        Exit;

      try
        LInfo.LatestVersion := LJson.GetValue<string>('version');
        LJson.TryGetValue<string>('releaseNotes', LInfo.ReleaseNotes);
        LJson.TryGetValue<string>('downloadUrl', LInfo.DownloadURL);

        SetLastCheckTime(Now);

        if IsNewerVersion(LInfo.LatestVersion, FCurrentVersion) then
        begin
          if Assigned(FOnUpdateAvailable) then
          begin
            TThread.Synchronize(nil,
              procedure
              begin
                FOnUpdateAvailable(LInfo);
              end
            );
          end;
        end;
      finally
        LJson.Free;
      end;
    except
      on E: Exception do
        TLogger.Instance.Debug('Update check failed: ' + E.Message,
          'TUpdateChecker.CheckNow');
    end;
  finally
    LHttp.Free;
  end;
end;

function TUpdateChecker.IsNewerVersion(const ALatest, ACurrent: string): Boolean;
var
  LLatestParts: TArray<string>;
  LCurrentParts: TArray<string>;
  I: Integer;
  LLatestNum: Integer;
  LCurrentNum: Integer;
begin
  Result := False;
  LLatestParts := ALatest.Split(['.']);
  LCurrentParts := ACurrent.Split(['.']);

  for I := 0 to 2 do
  begin
    if I < Length(LLatestParts) then
      LLatestNum := StrToIntDef(LLatestParts[I], 0)
    else
      LLatestNum := 0;

    if I < Length(LCurrentParts) then
      LCurrentNum := StrToIntDef(LCurrentParts[I], 0)
    else
      LCurrentNum := 0;

    if LLatestNum > LCurrentNum then
    begin
      Result := True;
      Exit;
    end;

    if LLatestNum < LCurrentNum then
      Exit;
  end;
end;

function TUpdateChecker.GetLastCheckTime: TDateTime;
var
  LReg: TRegistry;
  LStr: string;
begin
  Result := 0;
  LReg := TRegistry.Create(KEY_READ);
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if LReg.OpenKey(CRegistryRoot, False) then
    begin
      if LReg.ValueExists('LastUpdateCheck') then
      begin
        LStr := LReg.ReadString('LastUpdateCheck');
        Result := StrToFloatDef(LStr, 0);
      end;
      LReg.CloseKey;
    end;
  finally
    LReg.Free;
  end;
end;

procedure TUpdateChecker.SetLastCheckTime(ATime: TDateTime);
var
  LReg: TRegistry;
begin
  LReg := TRegistry.Create(KEY_WRITE);
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if LReg.OpenKey(CRegistryRoot, True) then
    begin
      LReg.WriteString('LastUpdateCheck', FloatToStr(ATime));
      LReg.CloseKey;
    end;
  finally
    LReg.Free;
  end;
end;

end.
