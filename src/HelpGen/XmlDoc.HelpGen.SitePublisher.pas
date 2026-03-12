unit XmlDoc.HelpGen.SitePublisher;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.CrossRef,
  XmlDoc.HelpGen.Renderer,
  XmlDoc.HelpGen.Renderer.MD;

type
  /// <summary>정적 사이트 생성기 종류</summary>
  TSiteGenerator = (sgMkDocs, sgDocusaurus, sgVitePress);

  /// <summary>사이트 퍼블리시 옵션</summary>
  TSitePublishOptions = record
    AutoBuild: Boolean;
    BaseURL: string;
    Generator: TSiteGenerator;
    RepoURL: string;
    SiteName: string;
  end;

  /// <summary>MkDocs / Docusaurus / VitePress 프로젝트 구성을 자동 생성합니다.</summary>
  TSitePublisher = class
  private
    procedure GenerateDocusaurus(const AOutputDir: string; const AOpts: TSitePublishOptions; const AUnits: TObjectList<TUnitDocInfo>);
    procedure GenerateMkDocs(const AOutputDir: string; const AOpts: TSitePublishOptions; const AUnits: TObjectList<TUnitDocInfo>);
    procedure GenerateVitePress(const AOutputDir: string; const AOpts: TSitePublishOptions; const AUnits: TObjectList<TUnitDocInfo>);
  public
    /// <summary>Markdown 렌더링 후 사이트 프레임워크 설정 파일을 생성합니다.</summary>
    /// <param name="AUnits">유닛 목록</param>
    /// <param name="AResolver">교차 참조 해석기</param>
    /// <param name="AOpts">사이트 퍼블리시 옵션</param>
    /// <param name="ARenderOpts">렌더링 옵션</param>
    procedure Publish(const AUnits: TObjectList<TUnitDocInfo>; const AResolver: TCrossRefResolver; const AOpts: TSitePublishOptions; const ARenderOpts: TRenderOptions);
  end;

implementation

{ TSitePublisher }

procedure TSitePublisher.Publish(
  const AUnits: TObjectList<TUnitDocInfo>;
  const AResolver: TCrossRefResolver;
  const AOpts: TSitePublishOptions;
  const ARenderOpts: TRenderOptions);
var
  LOutputDir: string;
  LMDRenderer: TMarkdownDocRenderer;
  LMDOpts: TRenderOptions;
begin
  case AOpts.Generator of
    sgMkDocs:     LOutputDir := TPath.Combine(ARenderOpts.OutputDir, 'site-mkdocs');
    sgDocusaurus: LOutputDir := TPath.Combine(ARenderOpts.OutputDir, 'site-docusaurus');
    sgVitePress:  LOutputDir := TPath.Combine(ARenderOpts.OutputDir, 'site-vitepress');
  end;

  TDirectory.CreateDirectory(LOutputDir);

  // Markdown 렌더링
  LMDOpts := ARenderOpts;
  LMDOpts.OutputDir := TPath.Combine(LOutputDir, 'docs');
  LMDRenderer := TMarkdownDocRenderer.Create;
  try
    IDocRenderer(LMDRenderer).Render(AUnits, AResolver, LMDOpts);
  finally
    LMDRenderer := nil;
  end;

  // 프레임워크별 설정 파일 생성
  case AOpts.Generator of
    sgMkDocs:     GenerateMkDocs(LOutputDir, AOpts, AUnits);
    sgDocusaurus: GenerateDocusaurus(LOutputDir, AOpts, AUnits);
    sgVitePress:  GenerateVitePress(LOutputDir, AOpts, AUnits);
  end;
end;

procedure TSitePublisher.GenerateMkDocs(const AOutputDir: string;
  const AOpts: TSitePublishOptions; const AUnits: TObjectList<TUnitDocInfo>);
var
  LSB: TStringBuilder;
  I, J: Integer;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('site_name: ' + AOpts.SiteName);
    if AOpts.BaseURL <> '' then
      LSB.AppendLine('site_url: ' + AOpts.BaseURL);
    if AOpts.RepoURL <> '' then
      LSB.AppendLine('repo_url: ' + AOpts.RepoURL);

    LSB.AppendLine('theme:');
    LSB.AppendLine('  name: material');
    LSB.AppendLine('  language: ko');
    LSB.AppendLine;
    LSB.AppendLine('nav:');
    LSB.AppendLine('  - Home: index.md');
    LSB.AppendLine('  - API Reference:');

    for I := 0 to AUnits.Count - 1 do
    begin
      LSB.AppendFormat('    - %s:', [AUnits[I].UnitName]);
      LSB.AppendLine;
      LSB.AppendFormat('      - Overview: units/%s.md', [AUnits[I].UnitName]);
      LSB.AppendLine;

      for J := 0 to AUnits[I].Types.Count - 1 do
      begin
        LSB.AppendFormat('      - %s: units/%s.%s.md',
          [AUnits[I].Types[J].Name, AUnits[I].UnitName, AUnits[I].Types[J].Name]);
        LSB.AppendLine;
      end;
    end;

    LSB.AppendLine;
    LSB.AppendLine('markdown_extensions:');
    LSB.AppendLine('  - toc:');
    LSB.AppendLine('      permalink: true');
    LSB.AppendLine('  - tables');
    LSB.AppendLine('  - fenced_code');

    TFile.WriteAllText(TPath.Combine(AOutputDir, 'mkdocs.yml'), LSB.ToString, TEncoding.UTF8);

    // docs/index.md 복사 (README.md → index.md)
    TFile.Copy(
      TPath.Combine(AOutputDir, 'docs', 'README.md'),
      TPath.Combine(AOutputDir, 'docs', 'index.md'),
      True
    );
  finally
    LSB.Free;
  end;
end;

procedure TSitePublisher.GenerateDocusaurus(const AOutputDir: string;
  const AOpts: TSitePublishOptions; const AUnits: TObjectList<TUnitDocInfo>);
var
  LSB: TStringBuilder;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('// @ts-check');
    LSB.AppendLine('/** @type {import(''@docusaurus/types'').Config} */');
    LSB.AppendLine('const config = {');
    LSB.AppendFormat('  title: ''%s'',', [AOpts.SiteName]);
    LSB.AppendLine;
    if AOpts.BaseURL <> '' then
    begin
      LSB.AppendFormat('  url: ''%s'',', [AOpts.BaseURL]);
      LSB.AppendLine;
    end;
    LSB.AppendLine('  baseUrl: ''/'',');
    LSB.AppendLine('  onBrokenLinks: ''warn'',');
    LSB.AppendLine('  themeConfig: {');
    LSB.AppendLine('    navbar: {');
    LSB.AppendFormat('      title: ''%s'',', [AOpts.SiteName]);
    LSB.AppendLine;
    LSB.AppendLine('    },');
    LSB.AppendLine('  },');
    LSB.AppendLine('  presets: [');
    LSB.AppendLine('    [''classic'', { docs: { routeBasePath: ''/'' } }],');
    LSB.AppendLine('  ],');
    LSB.AppendLine('};');
    LSB.AppendLine('module.exports = config;');

    TFile.WriteAllText(
      TPath.Combine(AOutputDir, 'docusaurus.config.js'), LSB.ToString, TEncoding.UTF8);
  finally
    LSB.Free;
  end;
end;

procedure TSitePublisher.GenerateVitePress(const AOutputDir: string;
  const AOpts: TSitePublishOptions; const AUnits: TObjectList<TUnitDocInfo>);
var
  LSB: TStringBuilder;
  LConfigDir: string;
  I, J: Integer;
begin
  LConfigDir := TPath.Combine(AOutputDir, 'docs', '.vitepress');
  TDirectory.CreateDirectory(LConfigDir);

  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('import { defineConfig } from ''vitepress''');
    LSB.AppendLine;
    LSB.AppendLine('export default defineConfig({');
    LSB.AppendFormat('  title: ''%s'',', [AOpts.SiteName]);
    LSB.AppendLine;
    LSB.AppendLine('  themeConfig: {');
    LSB.AppendLine('    sidebar: [');
    LSB.AppendLine('      {');
    LSB.AppendLine('        text: ''API Reference'',');
    LSB.AppendLine('        items: [');

    for I := 0 to AUnits.Count - 1 do
    begin
      LSB.AppendFormat('          { text: ''%s'', link: ''/units/%s'' },',
        [AUnits[I].UnitName, AUnits[I].UnitName]);
      LSB.AppendLine;
    end;

    LSB.AppendLine('        ]');
    LSB.AppendLine('      }');
    LSB.AppendLine('    ]');
    LSB.AppendLine('  }');
    LSB.AppendLine('})');

    TFile.WriteAllText(
      TPath.Combine(LConfigDir, 'config.mts'), LSB.ToString, TEncoding.UTF8);
  finally
    LSB.Free;
  end;
end;

end.
