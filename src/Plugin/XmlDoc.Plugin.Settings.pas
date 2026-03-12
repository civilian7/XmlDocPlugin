unit XmlDoc.Plugin.Settings;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Win.Registry,
  Winapi.Windows,
  Vcl.Menus,
  XmlDoc.Logger;

type
  TIndentStyle = (isSpaces, isTabs);

  /// <summary>에디터 설정</summary>
  TEditorSettings = record
    AutoShowOnCursor: Boolean;
    CollapseEmptySections: Boolean;
    DebounceMs: Integer;
    FontSize: Integer;
    SaveDebounceMs: Integer;
    ShowSignatureHeader: Boolean;
    Theme: string;
  end;

  /// <summary>코드 생성 설정</summary>
  TCodeGenSettings = record
    BlankLineAfter: Boolean;
    BlankLineBefore: Boolean;
    IndentSize: Integer;
    IndentStyle: TIndentStyle;
    OmitEmptyTags: Boolean;
    TagOrder: TArray<string>;
  end;

  /// <summary>스텁 생성 설정</summary>
  TStubSettings = record
    AutoGenerate: Boolean;
    IncludePlaceholders: Boolean;
    PlaceholderPrefix: string;
  end;

  /// <summary>단축키 설정</summary>
  TShortcutSettings = record
    CoverageReport: TShortCut;
    GenerateHelp: TShortCut;
    GenerateStub: TShortCut;
    NextUndocumented: TShortCut;
    PreviousUndocumented: TShortCut;
    ToggleInspector: TShortCut;
  end;

  /// <summary>일반 설정</summary>
  TGeneralSettings = record
    CheckUpdates: Boolean;
    Language: string;
    LogLevel: TLogLevel;
    LogPath: string;
  end;

  /// <summary>전역 설정 (레지스트리)</summary>
  TGlobalSettings = record
    CodeGen: TCodeGenSettings;
    Editor: TEditorSettings;
    General: TGeneralSettings;
    Shortcuts: TShortcutSettings;
    Stub: TStubSettings;
  end;

  /// <summary>Help 생성 설정</summary>
  THelpGenSettings = record
    CoverageMinPercent: Integer;
    DefaultFormats: TArray<string>;
    ExcludePatterns: TArray<string>;
    HTMLTheme: string;
    IncludePrivate: Boolean;
    InterfaceOnly: Boolean;
    OutputDir: string;
    Title: string;
  end;

  /// <summary>프로젝트 설정 (.xmldocplugin.json)</summary>
  TProjectSettings = record
    HelpGen: THelpGenSettings;
  end;

  /// <summary>플러그인 설정 관리자. 레지스트리(글로벌) + JSON(프로젝트) 이중 저장.</summary>
  TPluginSettings = class
  strict private
    class var FInstance: TPluginSettings;
  private
    FGlobal: TGlobalSettings;
    FProject: TProjectSettings;
    FProjectDir: string;

    procedure LoadFromRegistry;
    procedure LoadProjectSettings(const AProjectDir: string);
    procedure SaveToRegistry;

  public
    constructor Create;

    class function Instance: TPluginSettings;
    class procedure ReleaseInstance;

    /// <summary>전역 설정을 초기화합니다.</summary>
    procedure LoadDefaults;

    /// <summary>레지스트리에서 전역 설정을 로드합니다.</summary>
    procedure Load;

    /// <summary>전역 설정을 레지스트리에 저장합니다.</summary>
    procedure Save;

    /// <summary>프로젝트 디렉토리의 설정을 로드합니다.</summary>
    /// <param name="AProjectDir">프로젝트 루트 디렉토리</param>
    procedure LoadProject(const AProjectDir: string);

    /// <summary>프로젝트 설정을 JSON 파일로 저장합니다.</summary>
    procedure SaveProject;

    property Global: TGlobalSettings read FGlobal write FGlobal;
    property Project: TProjectSettings read FProject write FProject;
    property ProjectDir: string read FProjectDir;
  end;

implementation

const
  CRegistryRoot = 'Software\XmlDocPlugin';
  CProjectFileName = '.xmldocplugin.json';

{ TPluginSettings }

constructor TPluginSettings.Create;
begin
  inherited Create;
  LoadDefaults;
end;

class function TPluginSettings.Instance: TPluginSettings;
begin
  if not Assigned(FInstance) then
    FInstance := TPluginSettings.Create;
  Result := FInstance;
end;

class procedure TPluginSettings.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

procedure TPluginSettings.LoadDefaults;
begin
  // Editor
  FGlobal.Editor.AutoShowOnCursor := True;
  FGlobal.Editor.DebounceMs := 300;
  FGlobal.Editor.SaveDebounceMs := 500;
  FGlobal.Editor.FontSize := 13;
  FGlobal.Editor.Theme := 'light';
  FGlobal.Editor.CollapseEmptySections := True;
  FGlobal.Editor.ShowSignatureHeader := True;

  // CodeGen
  FGlobal.CodeGen.IndentStyle := isSpaces;
  FGlobal.CodeGen.IndentSize := 2;
  FGlobal.CodeGen.BlankLineBefore := True;
  FGlobal.CodeGen.BlankLineAfter := False;
  FGlobal.CodeGen.OmitEmptyTags := True;
  FGlobal.CodeGen.TagOrder := TArray<string>.Create(
    'summary', 'remarks', 'param', 'typeparam', 'returns',
    'value', 'exception', 'example', 'seealso', 'permission'
  );

  // Stub
  FGlobal.Stub.AutoGenerate := False;
  FGlobal.Stub.IncludePlaceholders := True;
  FGlobal.Stub.PlaceholderPrefix := 'TODO: ';

  // Shortcuts
  FGlobal.Shortcuts.ToggleInspector := Vcl.Menus.ShortCut(Ord('D'), [ssCtrl, ssShift]);
  FGlobal.Shortcuts.GenerateStub := Vcl.Menus.ShortCut(Ord('G'), [ssCtrl, ssShift]);
  FGlobal.Shortcuts.GenerateHelp := Vcl.Menus.ShortCut(Ord('H'), [ssCtrl, ssShift]);
  FGlobal.Shortcuts.CoverageReport := Vcl.Menus.ShortCut(Ord('R'), [ssCtrl, ssShift]);
  FGlobal.Shortcuts.NextUndocumented := Vcl.Menus.ShortCut(Ord('N'), [ssCtrl, ssAlt]);
  FGlobal.Shortcuts.PreviousUndocumented := Vcl.Menus.ShortCut(Ord('P'), [ssCtrl, ssAlt]);

  // General
  FGlobal.General.Language := 'auto';
  FGlobal.General.CheckUpdates := True;
  FGlobal.General.LogLevel := llInfo;
  FGlobal.General.LogPath := '';

  // Project defaults
  FProject.HelpGen.DefaultFormats := TArray<string>.Create('html', 'md');
  FProject.HelpGen.OutputDir := 'docs';
  FProject.HelpGen.Title := '';
  FProject.HelpGen.ExcludePatterns := nil;
  FProject.HelpGen.IncludePrivate := False;
  FProject.HelpGen.InterfaceOnly := True;
  FProject.HelpGen.HTMLTheme := 'default';
  FProject.HelpGen.CoverageMinPercent := 0;
end;

procedure TPluginSettings.Load;
begin
  LoadFromRegistry;
end;

procedure TPluginSettings.Save;
begin
  SaveToRegistry;
end;

procedure TPluginSettings.LoadFromRegistry;
var
  LReg: TRegistry;
begin
  LReg := TRegistry.Create(KEY_READ);
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if not LReg.OpenKey(CRegistryRoot + '\Editor', False) then
      Exit;

    if LReg.ValueExists('DebounceMs') then
      FGlobal.Editor.DebounceMs := LReg.ReadInteger('DebounceMs');
    if LReg.ValueExists('FontSize') then
      FGlobal.Editor.FontSize := LReg.ReadInteger('FontSize');
    if LReg.ValueExists('Theme') then
      FGlobal.Editor.Theme := LReg.ReadString('Theme');
    if LReg.ValueExists('AutoShowOnCursor') then
      FGlobal.Editor.AutoShowOnCursor := LReg.ReadBool('AutoShowOnCursor');
    if LReg.ValueExists('CollapseEmptySections') then
      FGlobal.Editor.CollapseEmptySections := LReg.ReadBool('CollapseEmptySections');
    if LReg.ValueExists('ShowSignatureHeader') then
      FGlobal.Editor.ShowSignatureHeader := LReg.ReadBool('ShowSignatureHeader');
    if LReg.ValueExists('SaveDebounceMs') then
      FGlobal.Editor.SaveDebounceMs := LReg.ReadInteger('SaveDebounceMs');

    LReg.CloseKey;

    if LReg.OpenKey(CRegistryRoot + '\CodeGen', False) then
    begin
      if LReg.ValueExists('IndentStyle') then
        FGlobal.CodeGen.IndentStyle := TIndentStyle(LReg.ReadInteger('IndentStyle'));
      if LReg.ValueExists('IndentSize') then
        FGlobal.CodeGen.IndentSize := LReg.ReadInteger('IndentSize');
      if LReg.ValueExists('BlankLineBefore') then
        FGlobal.CodeGen.BlankLineBefore := LReg.ReadBool('BlankLineBefore');
      if LReg.ValueExists('BlankLineAfter') then
        FGlobal.CodeGen.BlankLineAfter := LReg.ReadBool('BlankLineAfter');
      if LReg.ValueExists('OmitEmptyTags') then
        FGlobal.CodeGen.OmitEmptyTags := LReg.ReadBool('OmitEmptyTags');
      LReg.CloseKey;
    end;

    if LReg.OpenKey(CRegistryRoot + '\Stub', False) then
    begin
      if LReg.ValueExists('AutoGenerate') then
        FGlobal.Stub.AutoGenerate := LReg.ReadBool('AutoGenerate');
      if LReg.ValueExists('IncludePlaceholders') then
        FGlobal.Stub.IncludePlaceholders := LReg.ReadBool('IncludePlaceholders');
      if LReg.ValueExists('PlaceholderPrefix') then
        FGlobal.Stub.PlaceholderPrefix := LReg.ReadString('PlaceholderPrefix');
      LReg.CloseKey;
    end;

    if LReg.OpenKey(CRegistryRoot + '\Shortcuts', False) then
    begin
      if LReg.ValueExists('ToggleInspector') then
        FGlobal.Shortcuts.ToggleInspector := LReg.ReadInteger('ToggleInspector');
      if LReg.ValueExists('GenerateStub') then
        FGlobal.Shortcuts.GenerateStub := LReg.ReadInteger('GenerateStub');
      if LReg.ValueExists('GenerateHelp') then
        FGlobal.Shortcuts.GenerateHelp := LReg.ReadInteger('GenerateHelp');
      if LReg.ValueExists('CoverageReport') then
        FGlobal.Shortcuts.CoverageReport := LReg.ReadInteger('CoverageReport');
      if LReg.ValueExists('NextUndocumented') then
        FGlobal.Shortcuts.NextUndocumented := LReg.ReadInteger('NextUndocumented');
      if LReg.ValueExists('PreviousUndocumented') then
        FGlobal.Shortcuts.PreviousUndocumented := LReg.ReadInteger('PreviousUndocumented');
      LReg.CloseKey;
    end;

    if LReg.OpenKey(CRegistryRoot + '\General', False) then
    begin
      if LReg.ValueExists('Language') then
        FGlobal.General.Language := LReg.ReadString('Language');
      if LReg.ValueExists('CheckUpdates') then
        FGlobal.General.CheckUpdates := LReg.ReadBool('CheckUpdates');
      if LReg.ValueExists('LogLevel') then
        FGlobal.General.LogLevel := TLogLevel(LReg.ReadInteger('LogLevel'));
      if LReg.ValueExists('LogPath') then
        FGlobal.General.LogPath := LReg.ReadString('LogPath');
      LReg.CloseKey;
    end;
  finally
    LReg.Free;
  end;
end;

procedure TPluginSettings.SaveToRegistry;
var
  LReg: TRegistry;
begin
  LReg := TRegistry.Create(KEY_WRITE);
  try
    LReg.RootKey := HKEY_CURRENT_USER;

    if LReg.OpenKey(CRegistryRoot + '\Editor', True) then
    begin
      LReg.WriteInteger('DebounceMs', FGlobal.Editor.DebounceMs);
      LReg.WriteInteger('FontSize', FGlobal.Editor.FontSize);
      LReg.WriteString('Theme', FGlobal.Editor.Theme);
      LReg.WriteBool('AutoShowOnCursor', FGlobal.Editor.AutoShowOnCursor);
      LReg.WriteBool('CollapseEmptySections', FGlobal.Editor.CollapseEmptySections);
      LReg.WriteBool('ShowSignatureHeader', FGlobal.Editor.ShowSignatureHeader);
      LReg.WriteInteger('SaveDebounceMs', FGlobal.Editor.SaveDebounceMs);
      LReg.CloseKey;
    end;

    if LReg.OpenKey(CRegistryRoot + '\CodeGen', True) then
    begin
      LReg.WriteInteger('IndentStyle', Ord(FGlobal.CodeGen.IndentStyle));
      LReg.WriteInteger('IndentSize', FGlobal.CodeGen.IndentSize);
      LReg.WriteBool('BlankLineBefore', FGlobal.CodeGen.BlankLineBefore);
      LReg.WriteBool('BlankLineAfter', FGlobal.CodeGen.BlankLineAfter);
      LReg.WriteBool('OmitEmptyTags', FGlobal.CodeGen.OmitEmptyTags);
      LReg.CloseKey;
    end;

    if LReg.OpenKey(CRegistryRoot + '\Stub', True) then
    begin
      LReg.WriteBool('AutoGenerate', FGlobal.Stub.AutoGenerate);
      LReg.WriteBool('IncludePlaceholders', FGlobal.Stub.IncludePlaceholders);
      LReg.WriteString('PlaceholderPrefix', FGlobal.Stub.PlaceholderPrefix);
      LReg.CloseKey;
    end;

    if LReg.OpenKey(CRegistryRoot + '\Shortcuts', True) then
    begin
      LReg.WriteInteger('ToggleInspector', FGlobal.Shortcuts.ToggleInspector);
      LReg.WriteInteger('GenerateStub', FGlobal.Shortcuts.GenerateStub);
      LReg.WriteInteger('GenerateHelp', FGlobal.Shortcuts.GenerateHelp);
      LReg.WriteInteger('CoverageReport', FGlobal.Shortcuts.CoverageReport);
      LReg.WriteInteger('NextUndocumented', FGlobal.Shortcuts.NextUndocumented);
      LReg.WriteInteger('PreviousUndocumented', FGlobal.Shortcuts.PreviousUndocumented);
      LReg.CloseKey;
    end;

    if LReg.OpenKey(CRegistryRoot + '\General', True) then
    begin
      LReg.WriteString('Language', FGlobal.General.Language);
      LReg.WriteBool('CheckUpdates', FGlobal.General.CheckUpdates);
      LReg.WriteInteger('LogLevel', Ord(FGlobal.General.LogLevel));
      LReg.WriteString('LogPath', FGlobal.General.LogPath);
      LReg.CloseKey;
    end;
  finally
    LReg.Free;
  end;
end;

procedure TPluginSettings.LoadProject(const AProjectDir: string);
begin
  FProjectDir := AProjectDir;
  LoadProjectSettings(AProjectDir);
end;

procedure TPluginSettings.LoadProjectSettings(const AProjectDir: string);
var
  LPath: string;
  LJson: string;
  LObj: TJSONObject;
  LHelpGen: TJSONObject;
  LArr: TJSONArray;
  I: Integer;
begin
  LPath := TPath.Combine(AProjectDir, CProjectFileName);
  if not TFile.Exists(LPath) then
    Exit;

  try
    LJson := TFile.ReadAllText(LPath, TEncoding.UTF8);
    LObj := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
    if not Assigned(LObj) then
      Exit;

    try
      LHelpGen := LObj.GetValue<TJSONObject>('helpGen');
      if Assigned(LHelpGen) then
      begin
        if LHelpGen.TryGetValue<string>('outputDir', LPath) then
          FProject.HelpGen.OutputDir := LPath;
        if LHelpGen.TryGetValue<string>('title', LPath) then
          FProject.HelpGen.Title := LPath;
        if LHelpGen.TryGetValue<string>('htmlTheme', LPath) then
          FProject.HelpGen.HTMLTheme := LPath;
        if LHelpGen.TryGetValue<Boolean>('includePrivate', FProject.HelpGen.IncludePrivate) then;
        if LHelpGen.TryGetValue<Boolean>('interfaceOnly', FProject.HelpGen.InterfaceOnly) then;
        if LHelpGen.TryGetValue<Integer>('coverageMinPercent', FProject.HelpGen.CoverageMinPercent) then;

        LArr := LHelpGen.GetValue<TJSONArray>('defaultFormats');
        if Assigned(LArr) then
        begin
          SetLength(FProject.HelpGen.DefaultFormats, LArr.Count);
          for I := 0 to LArr.Count - 1 do
            FProject.HelpGen.DefaultFormats[I] := LArr.Items[I].Value;
        end;

        LArr := LHelpGen.GetValue<TJSONArray>('excludePatterns');
        if Assigned(LArr) then
        begin
          SetLength(FProject.HelpGen.ExcludePatterns, LArr.Count);
          for I := 0 to LArr.Count - 1 do
            FProject.HelpGen.ExcludePatterns[I] := LArr.Items[I].Value;
        end;
      end;
    finally
      LObj.Free;
    end;
  except
    on E: Exception do
      TLogger.Instance.Warn('Failed to load project settings: ' + E.Message,
        'TPluginSettings.LoadProjectSettings');
  end;
end;

procedure TPluginSettings.SaveProject;
var
  LObj: TJSONObject;
  LHelpGen: TJSONObject;
  LArr: TJSONArray;
  LPath: string;
  I: Integer;
begin
  if FProjectDir = '' then
    Exit;

  LObj := TJSONObject.Create;
  try
    LObj.AddPair('$schema', 'https://xmldocplugin.dev/schema/v1/project-settings.json');
    LObj.AddPair('version', TJSONNumber.Create(1));

    LHelpGen := TJSONObject.Create;
    LHelpGen.AddPair('outputDir', FProject.HelpGen.OutputDir);
    LHelpGen.AddPair('title', FProject.HelpGen.Title);
    LHelpGen.AddPair('htmlTheme', FProject.HelpGen.HTMLTheme);
    LHelpGen.AddPair('includePrivate', TJSONBool.Create(FProject.HelpGen.IncludePrivate));
    LHelpGen.AddPair('interfaceOnly', TJSONBool.Create(FProject.HelpGen.InterfaceOnly));
    LHelpGen.AddPair('coverageMinPercent', TJSONNumber.Create(FProject.HelpGen.CoverageMinPercent));

    LArr := TJSONArray.Create;
    for I := 0 to Length(FProject.HelpGen.DefaultFormats) - 1 do
      LArr.Add(FProject.HelpGen.DefaultFormats[I]);
    LHelpGen.AddPair('defaultFormats', LArr);

    if Length(FProject.HelpGen.ExcludePatterns) > 0 then
    begin
      LArr := TJSONArray.Create;
      for I := 0 to Length(FProject.HelpGen.ExcludePatterns) - 1 do
        LArr.Add(FProject.HelpGen.ExcludePatterns[I]);
      LHelpGen.AddPair('excludePatterns', LArr);
    end;

    LObj.AddPair('helpGen', LHelpGen);

    LPath := TPath.Combine(FProjectDir, CProjectFileName);
    TFile.WriteAllText(LPath, LObj.Format(2), TEncoding.UTF8);
  finally
    LObj.Free;
  end;
end;

initialization

finalization
  TPluginSettings.ReleaseInstance;

end.
