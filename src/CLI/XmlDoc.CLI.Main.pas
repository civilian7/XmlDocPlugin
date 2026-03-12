unit XmlDoc.CLI.Main;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.Scanner,
  XmlDoc.HelpGen.BatchParser,
  XmlDoc.HelpGen.CrossRef,
  XmlDoc.HelpGen.Renderer,
  XmlDoc.HelpGen.Renderer.HTML,
  XmlDoc.HelpGen.Renderer.MD,
  XmlDoc.HelpGen.Renderer.CHM,
  XmlDoc.HelpGen.Renderer.JSON,
  XmlDoc.HelpGen.SitePublisher,
  XmlDoc.HelpGen.Coverage;

type
  /// <summary>CLI 옵션</summary>
  TCLIOptions = record
    CoverageEnabled: Boolean;
    CoverageMinPercent: Integer;
    Directory: string;
    ExcludePatterns: TArray<string>;
    Formats: TArray<string>;
    IncludePrivate: Boolean;
    InterfaceOnly: Boolean;
    OutputDir: string;
    ProjectPath: string;
    Quiet: Boolean;
    SiteName: string;
    Theme: string;
    Title: string;
    Verbose: Boolean;
  end;

  /// <summary>커맨드라인 문서 생성기 메인 클래스</summary>
  TCLIMain = class
  private
    FOptions: TCLIOptions;

    function ParseArgs: Boolean;
    procedure PrintHelp;
    procedure PrintProgress(ACurrent, ATotal: Integer; const AMessage: string);
    procedure RenderSite(const AFormat: string;
      const AUnits: TObjectList<TUnitDocInfo>;
      const AResolver: TCrossRefResolver;
      const ARenderOpts: TRenderOptions);

  public
    /// <summary>CLI 실행. 종료 코드를 반환합니다.</summary>
    /// <returns>0: 성공, 1: 커버리지 미달, 2: 에러</returns>
    function Run: Integer;
  end;

implementation

uses
  System.IOUtils;

{ TCLIMain }

function TCLIMain.ParseArgs: Boolean;
var
  I: Integer;
  LArg: string;
  LFormats: string;
begin
  Result := False;

  // 기본값
  FOptions.OutputDir := 'docs';
  FOptions.Title := 'API Reference';
  FOptions.InterfaceOnly := True;
  FOptions.Theme := 'default';
  FOptions.SiteName := 'Documentation';

  I := 1;
  while I <= ParamCount do
  begin
    LArg := ParamStr(I);

    if (LArg = '-h') or (LArg = '--help') then
    begin
      PrintHelp;
      Exit;
    end
    else if (LArg = '-p') or (LArg = '--project') then
    begin
      Inc(I);
      if I <= ParamCount then
        FOptions.ProjectPath := ParamStr(I);
    end
    else if (LArg = '-d') or (LArg = '--directory') then
    begin
      Inc(I);
      if I <= ParamCount then
        FOptions.Directory := ParamStr(I);
    end
    else if (LArg = '-o') or (LArg = '--output') then
    begin
      Inc(I);
      if I <= ParamCount then
        FOptions.OutputDir := ParamStr(I);
    end
    else if (LArg = '-f') or (LArg = '--format') then
    begin
      Inc(I);
      if I <= ParamCount then
      begin
        LFormats := ParamStr(I);
        FOptions.Formats := LFormats.Split([',']);
      end;
    end
    else if (LArg = '-t') or (LArg = '--title') then
    begin
      Inc(I);
      if I <= ParamCount then
        FOptions.Title := ParamStr(I);
    end
    else if LArg = '--exclude' then
    begin
      Inc(I);
      if I <= ParamCount then
        FOptions.ExcludePatterns := ParamStr(I).Split([';']);
    end
    else if LArg = '--include-private' then
      FOptions.IncludePrivate := True
    else if LArg = '--interface-only' then
      FOptions.InterfaceOnly := True
    else if LArg = '--coverage' then
      FOptions.CoverageEnabled := True
    else if LArg = '--coverage-min' then
    begin
      Inc(I);
      if I <= ParamCount then
        FOptions.CoverageMinPercent := StrToIntDef(ParamStr(I), 0);
    end
    else if LArg = '--theme' then
    begin
      Inc(I);
      if I <= ParamCount then
        FOptions.Theme := ParamStr(I);
    end
    else if LArg = '--site-name' then
    begin
      Inc(I);
      if I <= ParamCount then
        FOptions.SiteName := ParamStr(I);
    end
    else if LArg = '--quiet' then
      FOptions.Quiet := True
    else if LArg = '--verbose' then
      FOptions.Verbose := True;

    Inc(I);
  end;

  if (FOptions.ProjectPath = '') and (FOptions.Directory = '') then
  begin
    WriteLn('Error: --project or --directory is required.');
    WriteLn;
    PrintHelp;
    Exit;
  end;

  if Length(FOptions.Formats) = 0 then
    FOptions.Formats := TArray<string>.Create('html');

  Result := True;
end;

procedure TCLIMain.PrintHelp;
begin
  WriteLn('XmlDocGen - Delphi XML Documentation Generator');
  WriteLn;
  WriteLn('Usage: XmlDocGen [options]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -p, --project <path>       .dpr/.dpk project file');
  WriteLn('  -d, --directory <path>     Source directory');
  WriteLn('  -o, --output <path>        Output directory (default: docs)');
  WriteLn('  -f, --format <list>        Output formats: html,chm,md,json,mkdocs,docusaurus,vitepress');
  WriteLn('  -t, --title <title>        Documentation title');
  WriteLn('  --exclude <patterns>       Semicolon-separated exclude patterns');
  WriteLn('  --include-private          Include private members');
  WriteLn('  --interface-only           Interface section only');
  WriteLn('  --coverage                 Generate coverage report');
  WriteLn('  --coverage-min <percent>   Minimum coverage (exit code 1 if below)');
  WriteLn('  --theme <name>             CSS theme name');
  WriteLn('  --site-name <name>         Site name for static site generators');
  WriteLn('  --quiet                    Suppress progress output');
  WriteLn('  --verbose                  Verbose output');
  WriteLn('  -h, --help                 Show this help');
end;

procedure TCLIMain.PrintProgress(ACurrent, ATotal: Integer; const AMessage: string);
begin
  if not FOptions.Quiet then
    WriteLn(Format('[%d/%d] %s', [ACurrent, ATotal, AMessage]));
end;

procedure TCLIMain.RenderSite(const AFormat: string;
  const AUnits: TObjectList<TUnitDocInfo>;
  const AResolver: TCrossRefResolver;
  const ARenderOpts: TRenderOptions);
var
  LPublisher: TSitePublisher;
  LSiteOpts: TSitePublishOptions;
begin
  LSiteOpts.SiteName := FOptions.SiteName;
  if AFormat = 'mkdocs' then
    LSiteOpts.Generator := sgMkDocs
  else if AFormat = 'docusaurus' then
    LSiteOpts.Generator := sgDocusaurus
  else
    LSiteOpts.Generator := sgVitePress;

  LPublisher := TSitePublisher.Create;
  try
    LPublisher.Publish(AUnits, AResolver, LSiteOpts, ARenderOpts);
  finally
    LPublisher.Free;
  end;
end;

function TCLIMain.Run: Integer;
var
  LScanner: TProjectScanner;
  LParser: TBatchParser;
  LResolver: TCrossRefResolver;
  LScanOpts: TScanOptions;
  LFiles: TArray<string>;
  LRenderOpts: TRenderOptions;
  LFormat: string;
  LCoverage: TDocCoverageReport;
  LStats: TCoverageStats;
  LItems: TArray<TCoverageItem>;
begin
  Result := 0;

  if not ParseArgs then
  begin
    Result := 2;
    Exit;
  end;

  // 스캔
  LScanner := TProjectScanner.Create;
  try
    if FOptions.ProjectPath <> '' then
    begin
      LScanOpts.Source := ssProjectFile;
      LScanOpts.ProjectPath := FOptions.ProjectPath;
    end
    else
    begin
      LScanOpts.Source := ssDirectory;
      LScanOpts.ProjectPath := FOptions.Directory;
    end;

    LScanOpts.ExcludePatterns := FOptions.ExcludePatterns;
    LFiles := LScanner.Scan(LScanOpts);
  finally
    LScanner.Free;
  end;

  if not FOptions.Quiet then
    WriteLn(Format('Found %d source files.', [Length(LFiles)]));

  if Length(LFiles) = 0 then
  begin
    WriteLn('No source files found.');
    Result := 2;
    Exit;
  end;

  // 파싱
  LParser := TBatchParser.Create;
  try
    LParser.OnProgress := PrintProgress;
    LParser.ParseAll(LFiles);

    // 교차 참조 해석
    LResolver := TCrossRefResolver.Create(LParser.SymbolIndex);
    try
      LResolver.ResolveAllRefs(LParser.Units);

      if (LResolver.Unresolved.Count > 0) and FOptions.Verbose then
        WriteLn(Format('Warning: %d unresolved cross-references.',
          [LResolver.Unresolved.Count]));

      // 렌더링 옵션
      LRenderOpts.OutputDir := FOptions.OutputDir;
      LRenderOpts.Title := FOptions.Title;
      LRenderOpts.IncludePrivate := FOptions.IncludePrivate;
      LRenderOpts.IncludeSearchIndex := True;
      LRenderOpts.CSSTheme := FOptions.Theme;

      // 형식별 렌더링
      for LFormat in FOptions.Formats do
      begin
        if not FOptions.Quiet then
          WriteLn('Rendering: ' + LFormat);

        if LFormat = 'html' then
          THTMLDocRenderer.Create.Render(LParser.Units, LResolver, LRenderOpts)
        else if LFormat = 'md' then
          TMarkdownDocRenderer.Create.Render(LParser.Units, LResolver, LRenderOpts)
        else if LFormat = 'chm' then
          TCHMDocRenderer.Create.Render(LParser.Units, LResolver, LRenderOpts)
        else if LFormat = 'json' then
          TJSONDocRenderer.Create.Render(LParser.Units, LResolver, LRenderOpts)
        else if (LFormat = 'mkdocs') or (LFormat = 'docusaurus') or (LFormat = 'vitepress') then
        begin
          RenderSite(LFormat, LParser.Units, LResolver, LRenderOpts);
        end;
      end;

      // 커버리지
      if FOptions.CoverageEnabled then
      begin
        LCoverage := TDocCoverageReport.Create;
        try
          LStats := LCoverage.Analyze(LParser.Units);
          LCoverage.RenderConsoleReport(LStats);

          LItems := LCoverage.GetUndocumented(LParser.Units);
          LCoverage.RenderHTMLReport(LStats, LItems,
            TPath.Combine(FOptions.OutputDir, 'coverage.html'));

          if (FOptions.CoverageMinPercent > 0) and
             (LStats.CoveragePercent < FOptions.CoverageMinPercent) then
          begin
            WriteLn(Format('Coverage %.1f%% is below minimum %d%%.',
              [LStats.CoveragePercent, FOptions.CoverageMinPercent]));
            Result := 1;
          end;
        finally
          LStats.ByKind.Free;
          LStats.ByVisibility.Free;
          LStats.ByUnit.Free;
          LCoverage.Free;
        end;
      end;

    finally
      LResolver.Free;
    end;
  finally
    LParser.Free;
  end;

  if not FOptions.Quiet then
    WriteLn('Done.');
end;

end.
