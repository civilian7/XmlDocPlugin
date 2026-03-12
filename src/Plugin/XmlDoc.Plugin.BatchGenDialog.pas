unit XmlDoc.Plugin.BatchGenDialog;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.Threading,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Dialogs,
  Vcl.FileCtrl,
  ToolsAPI,
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
  XmlDoc.HelpGen.Coverage,
  XmlDoc.Plugin.Settings,
  XmlDoc.Logger;

type
  /// <summary>일괄 문서 생성 다이얼로그</summary>
  TBatchGenDialog = class(TForm)
  private
    FBtnBrowseDir: TButton;
    FBtnBrowseOutput: TButton;
    FBtnCancel: TButton;
    FBtnGenerate: TButton;
    FCancelled: Boolean;
    FChkCHM: TCheckBox;
    FChkCoverage: TCheckBox;
    FChkDocusaurus: TCheckBox;
    FChkHTML: TCheckBox;
    FChkIncludePrivate: TCheckBox;
    FChkInterfaceOnly: TCheckBox;
    FChkJSON: TCheckBox;
    FChkMarkdown: TCheckBox;
    FChkMkDocs: TCheckBox;
    FChkSearchIndex: TCheckBox;
    FChkVitePress: TCheckBox;
    FEdtDirectory: TEdit;
    FEdtExclude: TEdit;
    FEdtOutputDir: TEdit;
    FEdtTitle: TEdit;
    FLblPhase: TLabel;
    FLblProgress: TLabel;
    FLblStats: TLabel;
    FProgress: TProgressBar;
    FRbDirectory: TRadioButton;
    FRbProject: TRadioButton;

    procedure BuildUI;
    procedure DoGenerate;
    function  GetSelectedFormats: TArray<string>;
    procedure OnBrowseDirClick(Sender: TObject);
    procedure OnBrowseOutputClick(Sender: TObject);
    procedure OnCancelClick(Sender: TObject);
    procedure OnGenerateClick(Sender: TObject);
    procedure RenderFormat(const AFormat: string; const AUnits: TObjectList<TUnitDocInfo>; const AResolver: TCrossRefResolver; const ARenderOpts: TRenderOptions);
    procedure SetControlsEnabled(AEnabled: Boolean);
    procedure UpdateProgress(ACurrent, ATotal: Integer; const AMessage: string);

  public
    constructor Create(AOwner: TComponent); override;
  end;

/// <summary>일괄 생성 다이얼로그를 표시합니다.</summary>
procedure ShowBatchGenDialog;

implementation

procedure ShowBatchGenDialog;
var
  LDialog: TBatchGenDialog;
begin
  LDialog := TBatchGenDialog.Create(Application);
  try
    LDialog.ShowModal;
  finally
    LDialog.Free;
  end;
end;

{ TBatchGenDialog }

constructor TBatchGenDialog.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);

  Caption := 'Generate API Documentation';
  Width := 520;
  Height := 620;
  Position := poMainFormCenter;
  BorderStyle := bsDialog;
  FCancelled := False;

  BuildUI;
end;

procedure TBatchGenDialog.BuildUI;
var
  LPanel: TPanel;
  LLabel: TLabel;
  LTop: Integer;
  LProjectPath: string;
  LSettings: TPluginSettings;
begin
  LSettings := TPluginSettings.Instance;

  // 현재 프로젝트 경로 가져오기
  LProjectPath := '';
  if Assigned(BorlandIDEServices) then
  begin
    try
      LProjectPath := (BorlandIDEServices as IOTAModuleServices).MainProjectGroup
        .ActiveProject.FileName;
    except
      LProjectPath := '';
    end;
  end;

  LTop := 16;

  // Source 섹션
  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.Left := 16;
  LLabel.Top := LTop;
  LLabel.Caption := 'Source:';
  LLabel.Font.Style := [fsBold];
  Inc(LTop, 22);

  FRbProject := TRadioButton.Create(Self);
  FRbProject.Parent := Self;
  FRbProject.Left := 24;
  FRbProject.Top := LTop;
  FRbProject.Width := 460;
  if LProjectPath <> '' then
    FRbProject.Caption := 'Current Project (' + ExtractFileName(LProjectPath) + ')'
  else
    FRbProject.Caption := 'Current Project (none)';
  FRbProject.Checked := LProjectPath <> '';
  FRbProject.Enabled := LProjectPath <> '';
  Inc(LTop, 24);

  FRbDirectory := TRadioButton.Create(Self);
  FRbDirectory.Parent := Self;
  FRbDirectory.Left := 24;
  FRbDirectory.Top := LTop;
  FRbDirectory.Width := 80;
  FRbDirectory.Caption := 'Directory:';
  FRbDirectory.Checked := LProjectPath = '';
  Inc(LTop, 1);

  FEdtDirectory := TEdit.Create(Self);
  FEdtDirectory.Parent := Self;
  FEdtDirectory.Left := 110;
  FEdtDirectory.Top := LTop - 3;
  FEdtDirectory.Width := 340;

  FBtnBrowseDir := TButton.Create(Self);
  FBtnBrowseDir.Parent := Self;
  FBtnBrowseDir.Left := 456;
  FBtnBrowseDir.Top := LTop - 4;
  FBtnBrowseDir.Width := 30;
  FBtnBrowseDir.Caption := '...';
  FBtnBrowseDir.OnClick := OnBrowseDirClick;
  Inc(LTop, 30);

  // Exclude
  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.Left := 24;
  LLabel.Top := LTop;
  LLabel.Caption := 'Exclude:';
  Inc(LTop, 18);

  FEdtExclude := TEdit.Create(Self);
  FEdtExclude.Parent := Self;
  FEdtExclude.Left := 24;
  FEdtExclude.Top := LTop;
  FEdtExclude.Width := 462;
  FEdtExclude.Text := String.Join(';', LSettings.Project.HelpGen.ExcludePatterns);
  Inc(LTop, 36);

  // Output Format 섹션
  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.Left := 16;
  LLabel.Top := LTop;
  LLabel.Caption := 'Output Format:';
  LLabel.Font.Style := [fsBold];
  Inc(LTop, 22);

  FChkHTML := TCheckBox.Create(Self);
  FChkHTML.Parent := Self;
  FChkHTML.Left := 24;
  FChkHTML.Top := LTop;
  FChkHTML.Width := 220;
  FChkHTML.Caption := 'HTML (Multi-page website)';
  FChkHTML.Checked := True;

  FChkCHM := TCheckBox.Create(Self);
  FChkCHM.Parent := Self;
  FChkCHM.Left := 260;
  FChkCHM.Top := LTop;
  FChkCHM.Width := 220;
  FChkCHM.Caption := 'CHM (Windows Help)';
  Inc(LTop, 24);

  FChkMarkdown := TCheckBox.Create(Self);
  FChkMarkdown.Parent := Self;
  FChkMarkdown.Left := 24;
  FChkMarkdown.Top := LTop;
  FChkMarkdown.Width := 220;
  FChkMarkdown.Caption := 'Markdown (GitHub Wiki)';

  FChkJSON := TCheckBox.Create(Self);
  FChkJSON.Parent := Self;
  FChkJSON.Left := 260;
  FChkJSON.Top := LTop;
  FChkJSON.Width := 220;
  FChkJSON.Caption := 'JSON (Machine-readable)';
  Inc(LTop, 28);

  // Static Site
  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.Left := 24;
  LLabel.Top := LTop;
  LLabel.Caption := '── Static Site ──';
  LLabel.Font.Color := clGray;
  Inc(LTop, 20);

  FChkMkDocs := TCheckBox.Create(Self);
  FChkMkDocs.Parent := Self;
  FChkMkDocs.Left := 24;
  FChkMkDocs.Top := LTop;
  FChkMkDocs.Width := 220;
  FChkMkDocs.Caption := 'MkDocs (Material theme)';

  FChkDocusaurus := TCheckBox.Create(Self);
  FChkDocusaurus.Parent := Self;
  FChkDocusaurus.Left := 260;
  FChkDocusaurus.Top := LTop;
  FChkDocusaurus.Width := 220;
  FChkDocusaurus.Caption := 'Docusaurus (React-based)';
  Inc(LTop, 24);

  FChkVitePress := TCheckBox.Create(Self);
  FChkVitePress.Parent := Self;
  FChkVitePress.Left := 24;
  FChkVitePress.Top := LTop;
  FChkVitePress.Width := 220;
  FChkVitePress.Caption := 'VitePress (Vue-based)';
  Inc(LTop, 36);

  // Output Directory
  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.Left := 16;
  LLabel.Top := LTop;
  LLabel.Caption := 'Output Directory:';
  LLabel.Font.Style := [fsBold];
  Inc(LTop, 20);

  FEdtOutputDir := TEdit.Create(Self);
  FEdtOutputDir.Parent := Self;
  FEdtOutputDir.Left := 24;
  FEdtOutputDir.Top := LTop;
  FEdtOutputDir.Width := 426;
  FEdtOutputDir.Text := LSettings.Project.HelpGen.OutputDir;

  FBtnBrowseOutput := TButton.Create(Self);
  FBtnBrowseOutput.Parent := Self;
  FBtnBrowseOutput.Left := 456;
  FBtnBrowseOutput.Top := LTop - 1;
  FBtnBrowseOutput.Width := 30;
  FBtnBrowseOutput.Caption := '...';
  FBtnBrowseOutput.OnClick := OnBrowseOutputClick;
  Inc(LTop, 34);

  // Options
  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.Left := 16;
  LLabel.Top := LTop;
  LLabel.Caption := 'Options:';
  LLabel.Font.Style := [fsBold];
  Inc(LTop, 22);

  FChkIncludePrivate := TCheckBox.Create(Self);
  FChkIncludePrivate.Parent := Self;
  FChkIncludePrivate.Left := 24;
  FChkIncludePrivate.Top := LTop;
  FChkIncludePrivate.Width := 220;
  FChkIncludePrivate.Caption := 'Include private members';
  FChkIncludePrivate.Checked := LSettings.Project.HelpGen.IncludePrivate;

  FChkSearchIndex := TCheckBox.Create(Self);
  FChkSearchIndex.Parent := Self;
  FChkSearchIndex.Left := 260;
  FChkSearchIndex.Top := LTop;
  FChkSearchIndex.Width := 220;
  FChkSearchIndex.Caption := 'Generate search index';
  FChkSearchIndex.Checked := True;
  Inc(LTop, 24);

  FChkInterfaceOnly := TCheckBox.Create(Self);
  FChkInterfaceOnly.Parent := Self;
  FChkInterfaceOnly.Left := 24;
  FChkInterfaceOnly.Top := LTop;
  FChkInterfaceOnly.Width := 220;
  FChkInterfaceOnly.Caption := 'Interface section only';
  FChkInterfaceOnly.Checked := LSettings.Project.HelpGen.InterfaceOnly;

  FChkCoverage := TCheckBox.Create(Self);
  FChkCoverage.Parent := Self;
  FChkCoverage.Left := 260;
  FChkCoverage.Top := LTop;
  FChkCoverage.Width := 220;
  FChkCoverage.Caption := 'Generate coverage report';
  Inc(LTop, 28);

  // Title
  LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.Left := 24;
  LLabel.Top := LTop;
  LLabel.Caption := 'Title:';

  FEdtTitle := TEdit.Create(Self);
  FEdtTitle.Parent := Self;
  FEdtTitle.Left := 70;
  FEdtTitle.Top := LTop - 2;
  FEdtTitle.Width := 416;
  FEdtTitle.Text := LSettings.Project.HelpGen.Title;
  if FEdtTitle.Text = '' then
    FEdtTitle.Text := 'API Reference';
  Inc(LTop, 38);

  // Progress 영역
  LPanel := TPanel.Create(Self);
  LPanel.Parent := Self;
  LPanel.Left := 16;
  LPanel.Top := LTop;
  LPanel.Width := 472;
  LPanel.Height := 60;
  LPanel.BevelOuter := bvLowered;

  FProgress := TProgressBar.Create(Self);
  FProgress.Parent := LPanel;
  FProgress.Left := 8;
  FProgress.Top := 8;
  FProgress.Width := 456;
  FProgress.Height := 16;

  FLblPhase := TLabel.Create(Self);
  FLblPhase.Parent := LPanel;
  FLblPhase.Left := 8;
  FLblPhase.Top := 28;
  FLblPhase.Width := 300;
  FLblPhase.Caption := '';

  FLblStats := TLabel.Create(Self);
  FLblStats.Parent := LPanel;
  FLblStats.Left := 8;
  FLblStats.Top := 42;
  FLblStats.Width := 300;
  FLblStats.Caption := '';

  FLblProgress := TLabel.Create(Self);
  FLblProgress.Parent := LPanel;
  FLblProgress.Left := 420;
  FLblProgress.Top := 28;
  FLblProgress.Alignment := taRightJustify;
  FLblProgress.Caption := '';
  Inc(LTop, 72);

  // 버튼
  FBtnGenerate := TButton.Create(Self);
  FBtnGenerate.Parent := Self;
  FBtnGenerate.Left := 300;
  FBtnGenerate.Top := LTop;
  FBtnGenerate.Width := 90;
  FBtnGenerate.Height := 28;
  FBtnGenerate.Caption := 'Generate';
  FBtnGenerate.Default := True;
  FBtnGenerate.OnClick := OnGenerateClick;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := Self;
  FBtnCancel.Left := 396;
  FBtnCancel.Top := LTop;
  FBtnCancel.Width := 90;
  FBtnCancel.Height := 28;
  FBtnCancel.Caption := 'Close';
  FBtnCancel.Cancel := True;
  FBtnCancel.OnClick := OnCancelClick;
end;

procedure TBatchGenDialog.OnBrowseDirClick(Sender: TObject);
var
  LDir: string;
begin
  LDir := FEdtDirectory.Text;
  if SelectDirectory('Select source directory', '', LDir) then
    FEdtDirectory.Text := LDir;
end;

procedure TBatchGenDialog.OnBrowseOutputClick(Sender: TObject);
var
  LDir: string;
begin
  LDir := FEdtOutputDir.Text;
  if SelectDirectory('Select output directory', '', LDir) then
    FEdtOutputDir.Text := LDir;
end;

procedure TBatchGenDialog.OnCancelClick(Sender: TObject);
begin
  FCancelled := True;
  ModalResult := mrCancel;
end;

procedure TBatchGenDialog.OnGenerateClick(Sender: TObject);
begin
  DoGenerate;
end;

function TBatchGenDialog.GetSelectedFormats: TArray<string>;
var
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    if FChkHTML.Checked then
      LList.Add('html');
    if FChkCHM.Checked then
      LList.Add('chm');
    if FChkMarkdown.Checked then
      LList.Add('md');
    if FChkJSON.Checked then
      LList.Add('json');
    if FChkMkDocs.Checked then
      LList.Add('mkdocs');
    if FChkDocusaurus.Checked then
      LList.Add('docusaurus');
    if FChkVitePress.Checked then
      LList.Add('vitepress');
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TBatchGenDialog.SetControlsEnabled(AEnabled: Boolean);
begin
  FBtnGenerate.Enabled := AEnabled;
  FRbProject.Enabled := AEnabled;
  FRbDirectory.Enabled := AEnabled;
  FEdtDirectory.Enabled := AEnabled;
  FEdtOutputDir.Enabled := AEnabled;
  FEdtTitle.Enabled := AEnabled;
  FEdtExclude.Enabled := AEnabled;
  FChkHTML.Enabled := AEnabled;
  FChkCHM.Enabled := AEnabled;
  FChkMarkdown.Enabled := AEnabled;
  FChkJSON.Enabled := AEnabled;
  FChkMkDocs.Enabled := AEnabled;
  FChkDocusaurus.Enabled := AEnabled;
  FChkVitePress.Enabled := AEnabled;
  FChkIncludePrivate.Enabled := AEnabled;
  FChkInterfaceOnly.Enabled := AEnabled;
  FChkSearchIndex.Enabled := AEnabled;
  FChkCoverage.Enabled := AEnabled;

  if AEnabled then
    FBtnCancel.Caption := 'Close'
  else
    FBtnCancel.Caption := 'Cancel';
end;

procedure TBatchGenDialog.UpdateProgress(ACurrent, ATotal: Integer;
  const AMessage: string);
begin
  FProgress.Max := ATotal;
  FProgress.Position := ACurrent;
  FLblPhase.Caption := AMessage;
  FLblProgress.Caption := Format('%d%%', [Round(ACurrent / ATotal * 100)]);
  Application.ProcessMessages;
end;

procedure TBatchGenDialog.DoGenerate;
var
  LFormats: TArray<string>;
  LScanner: TProjectScanner;
  LParser: TBatchParser;
  LResolver: TCrossRefResolver;
  LScanOpts: TScanOptions;
  LFiles: TArray<string>;
  LRenderOpts: TRenderOptions;
  LFormat: string;
  LProjectPath: string;
  LCoverage: TDocCoverageReport;
  LStats: TCoverageStats;
  LItems: TArray<TCoverageItem>;
  I: Integer;
begin
  LFormats := GetSelectedFormats;
  if Length(LFormats) = 0 then
  begin
    MessageDlg('Please select at least one output format.', mtWarning, [mbOK], 0);
    Exit;
  end;

  FCancelled := False;
  SetControlsEnabled(False);
  try
    // 소스 경로 결정
    LProjectPath := '';
    if FRbProject.Checked then
    begin
      try
        LProjectPath := (BorlandIDEServices as IOTAModuleServices).MainProjectGroup
          .ActiveProject.FileName;
      except
        MessageDlg('No active project found.', mtError, [mbOK], 0);
        Exit;
      end;
    end;

    FLblPhase.Caption := 'Scanning source files...';
    FLblStats.Caption := '';
    Application.ProcessMessages;

    // 스캔
    LScanner := TProjectScanner.Create;
    try
      if LProjectPath <> '' then
      begin
        LScanOpts.Source := ssProjectFile;
        LScanOpts.ProjectPath := LProjectPath;
      end
      else
      begin
        LScanOpts.Source := ssDirectory;
        LScanOpts.ProjectPath := FEdtDirectory.Text;
      end;

      if FEdtExclude.Text <> '' then
        LScanOpts.ExcludePatterns := String(FEdtExclude.Text).Split([';']);

      LFiles := LScanner.Scan(LScanOpts);
    finally
      LScanner.Free;
    end;

    if Length(LFiles) = 0 then
    begin
      MessageDlg('No source files found.', mtWarning, [mbOK], 0);
      Exit;
    end;

    FLblStats.Caption := Format('Found %d source files.', [Length(LFiles)]);
    Application.ProcessMessages;

    if FCancelled then
      Exit;

    // 파싱
    LParser := TBatchParser.Create;
    try
      LParser.OnProgress := UpdateProgress;
      LParser.ParseAll(LFiles);

      if FCancelled then
        Exit;

      // 교차 참조
      FLblPhase.Caption := 'Resolving cross-references...';
      Application.ProcessMessages;

      LResolver := TCrossRefResolver.Create(LParser.SymbolIndex);
      try
        LResolver.ResolveAllRefs(LParser.Units);

        if LResolver.Unresolved.Count > 0 then
          FLblStats.Caption := FLblStats.Caption +
            Format(' | %d unresolved refs', [LResolver.Unresolved.Count]);

        // 렌더링 옵션
        LRenderOpts.OutputDir := FEdtOutputDir.Text;
        LRenderOpts.Title := FEdtTitle.Text;
        LRenderOpts.IncludePrivate := FChkIncludePrivate.Checked;
        LRenderOpts.IncludeSearchIndex := FChkSearchIndex.Checked;
        LRenderOpts.CSSTheme := TPluginSettings.Instance.Project.HelpGen.HTMLTheme;

        // 형식별 렌더링
        for I := 0 to Length(LFormats) - 1 do
        begin
          LFormat := LFormats[I];
          if FCancelled then
            Exit;

          FLblPhase.Caption := 'Rendering: ' + LFormat;
          FProgress.Position := 0;
          Application.ProcessMessages;

          RenderFormat(LFormat, LParser.Units, LResolver, LRenderOpts);
        end;

        // 커버리지
        if FChkCoverage.Checked then
        begin
          FLblPhase.Caption := 'Analyzing coverage...';
          Application.ProcessMessages;

          LCoverage := TDocCoverageReport.Create;
          try
            LStats := LCoverage.Analyze(LParser.Units);

            LItems := LCoverage.GetUndocumented(LParser.Units);
            LCoverage.RenderHTMLReport(LStats, LItems,
              TPath.Combine(FEdtOutputDir.Text, 'coverage.html'));

            FLblStats.Caption := FLblStats.Caption +
              Format(' | Coverage: %.1f%%', [LStats.CoveragePercent]);
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

    FProgress.Position := FProgress.Max;
    FLblPhase.Caption := 'Done!';
    FLblProgress.Caption := '100%';

    MessageDlg(Format('Documentation generated successfully in: %s',
      [FEdtOutputDir.Text]), mtInformation, [mbOK], 0);
  except
    on E: Exception do
    begin
      TLogger.Instance.Error('Batch generation failed: ' + E.Message,
        'TBatchGenDialog.DoGenerate');
      MessageDlg('Error: ' + E.Message, mtError, [mbOK], 0);
    end;
  end;

  SetControlsEnabled(True);
end;

procedure TBatchGenDialog.RenderFormat(const AFormat: string;
  const AUnits: TObjectList<TUnitDocInfo>;
  const AResolver: TCrossRefResolver;
  const ARenderOpts: TRenderOptions);
var
  LPublisher: TSitePublisher;
  LSiteOpts: TSitePublishOptions;
begin
  if AFormat = 'html' then
    THTMLDocRenderer.Create.Render(AUnits, AResolver, ARenderOpts)
  else if AFormat = 'md' then
    TMarkdownDocRenderer.Create.Render(AUnits, AResolver, ARenderOpts)
  else if AFormat = 'chm' then
    TCHMDocRenderer.Create.Render(AUnits, AResolver, ARenderOpts)
  else if AFormat = 'json' then
    TJSONDocRenderer.Create.Render(AUnits, AResolver, ARenderOpts)
  else if (AFormat = 'mkdocs') or (AFormat = 'docusaurus') or (AFormat = 'vitepress') then
  begin
    LSiteOpts.SiteName := TPluginSettings.Instance.Project.HelpGen.Title;
    if LSiteOpts.SiteName = '' then
      LSiteOpts.SiteName := 'Documentation';

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
end;

end.
