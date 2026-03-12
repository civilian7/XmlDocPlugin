unit XmlDoc.HelpGen.Renderer.CHM;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.CrossRef,
  XmlDoc.HelpGen.Renderer,
  XmlDoc.HelpGen.Renderer.HTML;

type
  /// <summary>HTML Help Workshop (.chm) 파일을 생성합니다.</summary>
  TCHMDocRenderer = class(TInterfacedObject, IDocRenderer)
  private
    FHTMLRenderer: THTMLDocRenderer;
    FOptions: TRenderOptions;
    FUnits: TObjectList<TUnitDocInfo>;

    function CompileCHM(const AHHPPath: string): Boolean;
    procedure GenerateHHC(const APath: string);
    procedure GenerateHHK(const APath: string);
    procedure GenerateHHP(const APath: string);
  public
    procedure Render(
      const AUnits: TObjectList<TUnitDocInfo>;
      const AResolver: TCrossRefResolver;
      const AOptions: TRenderOptions
    );
  end;

implementation

uses
  System.Win.Registry,
  Winapi.ShellAPI,
  Winapi.Windows,
  XmlDoc.Logger;

{ TCHMDocRenderer }

procedure TCHMDocRenderer.Render(
  const AUnits: TObjectList<TUnitDocInfo>;
  const AResolver: TCrossRefResolver;
  const AOptions: TRenderOptions);
var
  LHtmlDir: string;
  LHtmlOptions: TRenderOptions;
  LHHPPath: string;
begin
  FUnits := AUnits;
  FOptions := AOptions;

  // 먼저 HTML 렌더링
  LHtmlDir := TPath.Combine(AOptions.OutputDir, '_chm_html');
  LHtmlOptions := AOptions;
  LHtmlOptions.OutputDir := LHtmlDir;
  LHtmlOptions.IncludeSearchIndex := False;

  FHTMLRenderer := THTMLDocRenderer.Create;
  try
    FHTMLRenderer.Render(AUnits, AResolver, LHtmlOptions);
  finally
    FHTMLRenderer := nil;
  end;

  // HHP, HHC, HHK 파일 생성
  LHHPPath := TPath.Combine(AOptions.OutputDir, 'XmlDoc.hhp');
  GenerateHHP(LHHPPath);
  GenerateHHC(TPath.Combine(AOptions.OutputDir, 'XmlDoc.hhc'));
  GenerateHHK(TPath.Combine(AOptions.OutputDir, 'XmlDoc.hhk'));

  // CHM 컴파일
  if not CompileCHM(LHHPPath) then
    TLogger.Instance.Warn('hhc.exe not found. CHM compilation skipped. HTML output preserved.',
      'TCHMDocRenderer.Render');
end;

procedure TCHMDocRenderer.GenerateHHP(const APath: string);
var
  LSB: TStringBuilder;
  LHtmlDir: string;
  I, J: Integer;
begin
  LHtmlDir := '_chm_html';
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('[OPTIONS]');
    LSB.AppendLine('Compatibility=1.1 or later');
    LSB.AppendLine('Compiled file=' + TPath.Combine(FOptions.OutputDir, 'XmlDoc.chm'));
    LSB.AppendLine('Contents file=XmlDoc.hhc');
    LSB.AppendLine('Default topic=' + LHtmlDir + '\index.html');
    LSB.AppendLine('Display compile progress=No');
    LSB.AppendLine('Full-text search=Yes');
    LSB.AppendLine('Index file=XmlDoc.hhk');
    LSB.AppendLine('Language=0x0412 Korean');
    LSB.AppendLine('Title=' + FOptions.Title);
    LSB.AppendLine;
    LSB.AppendLine('[FILES]');
    LSB.AppendLine(LHtmlDir + '\index.html');
    LSB.AppendLine(LHtmlDir + '\assets\style.css');

    for I := 0 to FUnits.Count - 1 do
    begin
      LSB.AppendLine(LHtmlDir + '\units\' + FUnits[I].UnitName + '.html');
      for J := 0 to FUnits[I].Types.Count - 1 do
        LSB.AppendLine(LHtmlDir + '\units\' + FUnits[I].UnitName + '.' +
          FUnits[I].Types[J].Name + '.html');
    end;

    TFile.WriteAllText(APath, LSB.ToString, TEncoding.Default);
  finally
    LSB.Free;
  end;
end;

procedure TCHMDocRenderer.GenerateHHC(const APath: string);
var
  LSB: TStringBuilder;
  LHtmlDir: string;
  I, J: Integer;
begin
  LHtmlDir := '_chm_html';
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">');
    LSB.AppendLine('<HTML><HEAD></HEAD><BODY>');
    LSB.AppendLine('<OBJECT type="text/site properties"><param name="ImageType" value="Folder"></OBJECT>');
    LSB.AppendLine('<UL>');

    for I := 0 to FUnits.Count - 1 do
    begin
      LSB.AppendLine('<LI><OBJECT type="text/sitemap">');
      LSB.AppendFormat('<param name="Name" value="%s">', [FUnits[I].UnitName]);
      LSB.AppendFormat('<param name="Local" value="%s\units\%s.html">',
        [LHtmlDir, FUnits[I].UnitName]);
      LSB.AppendLine('</OBJECT>');

      if FUnits[I].Types.Count > 0 then
      begin
        LSB.AppendLine('<UL>');
        for J := 0 to FUnits[I].Types.Count - 1 do
        begin
          LSB.AppendLine('<LI><OBJECT type="text/sitemap">');
          LSB.AppendFormat('<param name="Name" value="%s">', [FUnits[I].Types[J].Name]);
          LSB.AppendFormat('<param name="Local" value="%s\units\%s.%s.html">',
            [LHtmlDir, FUnits[I].UnitName, FUnits[I].Types[J].Name]);
          LSB.AppendLine('</OBJECT>');
        end;
        LSB.AppendLine('</UL>');
      end;
    end;

    LSB.AppendLine('</UL></BODY></HTML>');
    TFile.WriteAllText(APath, LSB.ToString, TEncoding.Default);
  finally
    LSB.Free;
  end;
end;

procedure TCHMDocRenderer.GenerateHHK(const APath: string);
var
  LSB: TStringBuilder;
  LHtmlDir: string;
  I, J, K: Integer;
begin
  LHtmlDir := '_chm_html';
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">');
    LSB.AppendLine('<HTML><HEAD></HEAD><BODY>');
    LSB.AppendLine('<UL>');

    for I := 0 to FUnits.Count - 1 do
    begin
      // 유닛
      LSB.AppendLine('<LI><OBJECT type="text/sitemap">');
      LSB.AppendFormat('<param name="Name" value="%s">', [FUnits[I].UnitName]);
      LSB.AppendFormat('<param name="Local" value="%s\units\%s.html">',
        [LHtmlDir, FUnits[I].UnitName]);
      LSB.AppendLine('</OBJECT>');

      // 타입 + 멤버
      for J := 0 to FUnits[I].Types.Count - 1 do
      begin
        LSB.AppendLine('<LI><OBJECT type="text/sitemap">');
        LSB.AppendFormat('<param name="Name" value="%s">', [FUnits[I].Types[J].FullName]);
        LSB.AppendFormat('<param name="Local" value="%s\units\%s.%s.html">',
          [LHtmlDir, FUnits[I].UnitName, FUnits[I].Types[J].Name]);
        LSB.AppendLine('</OBJECT>');

        for K := 0 to FUnits[I].Types[J].Members.Count - 1 do
        begin
          LSB.AppendLine('<LI><OBJECT type="text/sitemap">');
          LSB.AppendFormat('<param name="Name" value="%s">',
            [FUnits[I].Types[J].Members[K].FullName]);
          LSB.AppendFormat('<param name="Local" value="%s\units\%s.%s.html#%s">',
            [LHtmlDir, FUnits[I].UnitName, FUnits[I].Types[J].Name,
             FUnits[I].Types[J].Members[K].Name]);
          LSB.AppendLine('</OBJECT>');
        end;
      end;
    end;

    LSB.AppendLine('</UL></BODY></HTML>');
    TFile.WriteAllText(APath, LSB.ToString, TEncoding.Default);
  finally
    LSB.Free;
  end;
end;

function TCHMDocRenderer.CompileCHM(const AHHPPath: string): Boolean;
var
  LReg: TRegistry;
  LHHCPath: string;
  LExitCode: Cardinal;
  LSI: TStartupInfo;
  LPI: TProcessInformation;
  LCmdLine: string;
begin
  Result := False;

  // hhc.exe 경로 찾기
  LHHCPath := '';
  LReg := TRegistry.Create(KEY_READ);
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    if LReg.OpenKey('Software\Microsoft\HTML Help Workshop', False) then
    begin
      if LReg.ValueExists('InstallDir') then
        LHHCPath := TPath.Combine(LReg.ReadString('InstallDir'), 'hhc.exe');
      LReg.CloseKey;
    end;
  finally
    LReg.Free;
  end;

  // 기본 경로 시도
  if (LHHCPath = '') or not TFile.Exists(LHHCPath) then
    LHHCPath := 'C:\Program Files (x86)\HTML Help Workshop\hhc.exe';

  if not TFile.Exists(LHHCPath) then
    Exit;

  LCmdLine := '"' + LHHCPath + '" "' + AHHPPath + '"';

  FillChar(LSI, SizeOf(LSI), 0);
  LSI.cb := SizeOf(LSI);
  LSI.dwFlags := STARTF_USESHOWWINDOW;
  LSI.wShowWindow := SW_HIDE;

  if CreateProcess(nil, PChar(LCmdLine), nil, nil, False,
    CREATE_NO_WINDOW, nil, PChar(ExtractFilePath(AHHPPath)), LSI, LPI) then
  begin
    WaitForSingleObject(LPI.hProcess, 60000);
    GetExitCodeProcess(LPI.hProcess, LExitCode);
    CloseHandle(LPI.hProcess);
    CloseHandle(LPI.hThread);
    // hhc.exe는 성공 시 1을 반환
    Result := LExitCode = 1;
  end;
end;

end.
