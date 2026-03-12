unit XmlDoc.I18n;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Generics.Collections;

type
  /// <summary>국제화(i18n) 싱글톤. JSON 언어 파일에서 번역 문자열을 로드합니다.</summary>
  TI18n = class
  strict private
    class var FInstance: TI18n;
  private
    FCurrentLanguage: string;
    FLocalesDir: string;
    FStrings: TDictionary<string, string>;

    procedure LoadDefaults;
    procedure LoadLanguage(const ALang: string);
    procedure ParseJsonObject(const AObj: TJSONObject; const APrefix: string);

  public
    constructor Create;
    destructor Destroy; override;

    class function Instance: TI18n;
    class procedure ReleaseInstance;

    /// <summary>번역 문자열을 조회합니다. 키가 없으면 키 자체를 반환합니다.</summary>
    /// <param name="AKey">dot-separated 키 (예: 'menu.generate_help')</param>
    /// <returns>번역된 문자열</returns>
    function T(const AKey: string): string; overload;

    /// <summary>포맷 인자를 포함하는 번역 문자열을 조회합니다.</summary>
    /// <param name="AKey">dot-separated 키</param>
    /// <param name="AArgs">포맷 인자 배열</param>
    /// <returns>포맷된 번역 문자열</returns>
    function T(const AKey: string; const AArgs: array of const): string; overload;

    /// <summary>언어를 변경합니다. 'auto'이면 시스템 언어를 감지합니다.</summary>
    /// <param name="ALang">언어 코드 (예: 'ko', 'en', 'ja', 'auto')</param>
    procedure SetLanguage(const ALang: string);

    /// <summary>로케일 파일이 있는 디렉토리를 설정합니다.</summary>
    /// <param name="ADir">디렉토리 경로</param>
    procedure SetLocalesDir(const ADir: string);

    property CurrentLanguage: string read FCurrentLanguage;
  end;

implementation

uses
  Winapi.Windows;

{ TI18n }

constructor TI18n.Create;
begin
  inherited Create;
  FStrings := TDictionary<string, string>.Create;
  FLocalesDir := TPath.Combine(
    TPath.Combine(GetEnvironmentVariable('APPDATA'), 'XmlDocPlugin'), 'locales');
  FCurrentLanguage := 'en';
  LoadDefaults;
end;

destructor TI18n.Destroy;
begin
  FStrings.Free;
  inherited;
end;

class function TI18n.Instance: TI18n;
begin
  if not Assigned(FInstance) then
    FInstance := TI18n.Create;
  Result := FInstance;
end;

class procedure TI18n.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

procedure TI18n.LoadDefaults;
begin
  FStrings.Clear;

  // Menu
  FStrings.AddOrSetValue('menu.toggle_inspector', 'Toggle Doc Inspector');
  FStrings.AddOrSetValue('menu.generate_stub', 'Generate Doc Stub');
  FStrings.AddOrSetValue('menu.generate_help', 'Generate Help...');
  FStrings.AddOrSetValue('menu.coverage_report', 'Coverage Report...');
  FStrings.AddOrSetValue('menu.settings', 'Settings...');

  // Inspector
  FStrings.AddOrSetValue('inspector.summary', 'Summary');
  FStrings.AddOrSetValue('inspector.parameters', 'Parameters');
  FStrings.AddOrSetValue('inspector.returns', 'Returns');
  FStrings.AddOrSetValue('inspector.remarks', 'Remarks');
  FStrings.AddOrSetValue('inspector.exceptions', 'Exceptions');
  FStrings.AddOrSetValue('inspector.examples', 'Examples');
  FStrings.AddOrSetValue('inspector.see_also', 'See Also');
  FStrings.AddOrSetValue('inspector.no_element', 'Place cursor on a code element.');

  // HelpGen
  FStrings.AddOrSetValue('helpgen.title', 'Generate API Documentation');
  FStrings.AddOrSetValue('helpgen.source', 'Source');
  FStrings.AddOrSetValue('helpgen.output_format', 'Output Format');
  FStrings.AddOrSetValue('helpgen.generating', 'Generating documentation...');
  FStrings.AddOrSetValue('helpgen.complete', 'Generation complete: {0} pages');

  // Coverage
  FStrings.AddOrSetValue('coverage.title', 'Documentation Coverage Report');
  FStrings.AddOrSetValue('coverage.overall', 'Overall: {0}/{1} ({2}%)');
  FStrings.AddOrSetValue('coverage.undocumented', 'Undocumented Items');

  // Errors
  FStrings.AddOrSetValue('errors.ast_parse_fail', 'Source parsing failed: {0}');
  FStrings.AddOrSetValue('errors.webview_missing', 'WebView2 runtime is not installed.');
  FStrings.AddOrSetValue('errors.hhc_not_found',
    'HTML Help Workshop is not installed. CHM generation skipped.');
end;

procedure TI18n.LoadLanguage(const ALang: string);
var
  LFilePath: string;
  LJson: string;
  LObj: TJSONObject;
begin
  FCurrentLanguage := ALang;
  LoadDefaults;

  if SameText(ALang, 'en') then
    Exit;

  LFilePath := TPath.Combine(FLocalesDir, ALang + '.json');
  if not TFile.Exists(LFilePath) then
    Exit;

  try
    LJson := TFile.ReadAllText(LFilePath, TEncoding.UTF8);
    LObj := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
    if Assigned(LObj) then
    begin
      try
        ParseJsonObject(LObj, '');
      finally
        LObj.Free;
      end;
    end;
  except
    // 언어 파일 로드 실패 시 기본 영어 유지
  end;
end;

procedure TI18n.ParseJsonObject(const AObj: TJSONObject; const APrefix: string);
var
  I: Integer;
  LPair: TJSONPair;
  LKey: string;
begin
  for I := 0 to AObj.Count - 1 do
  begin
    LPair := AObj.Pairs[I];
    if APrefix <> '' then
      LKey := APrefix + '.' + LPair.JsonString.Value
    else
      LKey := LPair.JsonString.Value;

    if LPair.JsonValue is TJSONObject then
      ParseJsonObject(TJSONObject(LPair.JsonValue), LKey)
    else if LPair.JsonValue is TJSONString then
      FStrings.AddOrSetValue(LKey, LPair.JsonValue.Value);
  end;
end;

procedure TI18n.SetLanguage(const ALang: string);
var
  LLang: string;
  LLocaleId: LCID;
  LBuf: array[0..4] of Char;
begin
  LLang := ALang;

  if SameText(LLang, 'auto') then
  begin
    LLocaleId := GetUserDefaultLCID;
    GetLocaleInfo(LLocaleId, LOCALE_SISO639LANGNAME, @LBuf[0], Length(LBuf));
    LLang := string(LBuf);
  end;

  if not SameText(LLang, FCurrentLanguage) then
    LoadLanguage(LLang);
end;

procedure TI18n.SetLocalesDir(const ADir: string);
begin
  FLocalesDir := ADir;
end;

function TI18n.T(const AKey: string): string;
begin
  if not FStrings.TryGetValue(AKey, Result) then
    Result := AKey;
end;

function TI18n.T(const AKey: string; const AArgs: array of const): string;
var
  LTemplate: string;
  I: Integer;
begin
  LTemplate := T(AKey);

  for I := 0 to High(AArgs) do
  begin
    case AArgs[I].VType of
      vtInteger:
        LTemplate := StringReplace(LTemplate, '{' + IntToStr(I) + '}',
          IntToStr(AArgs[I].VInteger), []);
      vtExtended:
        LTemplate := StringReplace(LTemplate, '{' + IntToStr(I) + '}',
          FormatFloat('0.#', AArgs[I].VExtended^), []);
      vtString:
        LTemplate := StringReplace(LTemplate, '{' + IntToStr(I) + '}',
          string(AArgs[I].VString^), []);
      vtAnsiString:
        LTemplate := StringReplace(LTemplate, '{' + IntToStr(I) + '}',
          string(AnsiString(AArgs[I].VAnsiString)), []);
      vtUnicodeString:
        LTemplate := StringReplace(LTemplate, '{' + IntToStr(I) + '}',
          string(AArgs[I].VUnicodeString), []);
      vtWideString:
        LTemplate := StringReplace(LTemplate, '{' + IntToStr(I) + '}',
          string(WideString(AArgs[I].VWideString)), []);
    end;
  end;

  Result := LTemplate;
end;

initialization

finalization
  TI18n.ReleaseInstance;

end.
