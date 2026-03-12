unit XmlDoc.Plugin.CoverageDialog;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Dialogs,
  Vcl.FileCtrl,
  ToolsAPI,
  XmlDoc.Consts,
  XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.Scanner,
  XmlDoc.HelpGen.BatchParser,
  XmlDoc.HelpGen.Coverage;

type
  /// <summary>ListView 항목에 연결할 파일/라인 정보</summary>
  PCoverageListItem = ^TCoverageListItem;
  TCoverageListItem = record
    FilePath: string;
    LineNumber: Integer;
  end;

  /// <summary>Coverage Report 다이얼로그. 프로젝트의 문서 커버리지를 분석하고 표시합니다.</summary>
  TCoverageDialog = class(TForm)
    btnAnalyze: TButton;
    btnBrowse: TButton;
    btnClose: TButton;
    btnExportHTML: TButton;
    edtDirectory: TEdit;
    lblComplete: TLabel;
    lblDocumented: TLabel;
    lblPercent: TLabel;
    lblPhase: TLabel;
    lblSource: TLabel;
    lblTotal: TLabel;
    lvItems: TListView;
    pbCoverage: TProgressBar;
    pbProgress: TProgressBar;
    pnlStats: TPanel;
    rbDirectory: TRadioButton;
    rbProject: TRadioButton;

    procedure btnAnalyzeClick(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnExportHTMLClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure lvItemsDblClick(Sender: TObject);
  private
    FCancelled: Boolean;
    FItems: TList<PCoverageListItem>;

    procedure ClearItems;
    procedure DoAnalyze;
    procedure JumpToFile(const AFilePath: string; ALineNumber: Integer);
    procedure SetControlsEnabled(AEnabled: Boolean);
    procedure UpdateProgress(ACurrent, ATotal: Integer; const AMessage: string);
  public
    destructor Destroy; override;
  end;

/// <summary>Coverage Report 다이얼로그를 표시합니다.</summary>
procedure ShowCoverageDialog;

implementation

{$R *.dfm}

function CoverageLevelToStr(ALevel: TCoverageLevel): string; forward;
procedure FindLocation(const AUnits: TObjectList<TUnitDocInfo>; const AFullName: string; ALocItem: PCoverageListItem); forward;
function GetScanOptions(ARbProject: TRadioButton; const ADirectory: string): TScanOptions; forward;

procedure ShowCoverageDialog;
var
  LDialog: TCoverageDialog;
begin
  LDialog := TCoverageDialog.Create(Application);
  try
    LDialog.ShowModal;
  finally
    LDialog.Free;
  end;
end;

{ Helper functions }

function CoverageLevelToStr(ALevel: TCoverageLevel): string;
begin
  case ALevel of
    clNone:        Result := 'None';
    clSummaryOnly: Result := 'Summary Only';
    clPartial:     Result := 'Partial';
    clComplete:    Result := 'Complete';
  else
    Result := 'Unknown';
  end;
end;

procedure FindLocation(const AUnits: TObjectList<TUnitDocInfo>; const AFullName: string; ALocItem: PCoverageListItem);
var
  I, J, K: Integer;
  LUnit: TUnitDocInfo;
  LType: TTypeDocInfo;
  LElem: TElementDocInfo;
begin
  for I := 0 to AUnits.Count - 1 do
  begin
    LUnit := AUnits[I];

    for J := 0 to LUnit.Types.Count - 1 do
    begin
      LType := LUnit.Types[J];

      if LType.FullName = AFullName then
      begin
        ALocItem^.FilePath := LUnit.FilePath;
        ALocItem^.LineNumber := 1;
        Exit;
      end;

      for K := 0 to LType.Members.Count - 1 do
      begin
        LElem := LType.Members[K];
        if LElem.FullName = AFullName then
        begin
          ALocItem^.FilePath := LUnit.FilePath;
          ALocItem^.LineNumber := LElem.CodeElement.LineNumber;
          Exit;
        end;
      end;
    end;

    for J := 0 to LUnit.StandaloneMethods.Count - 1 do
    begin
      LElem := LUnit.StandaloneMethods[J];
      if LElem.FullName = AFullName then
      begin
        ALocItem^.FilePath := LUnit.FilePath;
        ALocItem^.LineNumber := LElem.CodeElement.LineNumber;
        Exit;
      end;
    end;

    for J := 0 to LUnit.Constants.Count - 1 do
    begin
      LElem := LUnit.Constants[J];
      if LElem.FullName = AFullName then
      begin
        ALocItem^.FilePath := LUnit.FilePath;
        ALocItem^.LineNumber := LElem.CodeElement.LineNumber;
        Exit;
      end;
    end;
  end;
end;

function GetScanOptions(ARbProject: TRadioButton; const ADirectory: string): TScanOptions;
var
  LProjectPath: string;
begin
  Result := Default(TScanOptions);

  if ARbProject.Checked then
  begin
    LProjectPath := (BorlandIDEServices as IOTAModuleServices).MainProjectGroup.ActiveProject.FileName;
    Result.Source := ssProjectFile;
    Result.ProjectPath := LProjectPath;
  end
  else
  begin
    Result.Source := ssDirectory;
    Result.ProjectPath := ADirectory;
  end;
end;

{ TCoverageDialog }

destructor TCoverageDialog.Destroy;
begin
  ClearItems;
  FItems.Free;

  inherited;
end;

procedure TCoverageDialog.btnAnalyzeClick(Sender: TObject);
begin
  DoAnalyze;
end;

procedure TCoverageDialog.btnBrowseClick(Sender: TObject);
var
  LDir: string;
begin
  LDir := edtDirectory.Text;
  if SelectDirectory('Select source directory', '', LDir) then
    edtDirectory.Text := LDir;
end;

procedure TCoverageDialog.btnCloseClick(Sender: TObject);
begin
  FCancelled := True;
  ModalResult := mrCancel;
end;

procedure TCoverageDialog.btnExportHTMLClick(Sender: TObject);
var
  LCoverage: TDocCoverageReport;
  LFiles: TArray<string>;
  LOutputPath: string;
  LParser: TBatchParser;
  LSaveDlg: TSaveDialog;
  LScanner: TProjectScanner;
  LScanOpts: TScanOptions;
  LStats: TCoverageStats;
  LUndocItems: TArray<TCoverageItem>;
begin
  LSaveDlg := TSaveDialog.Create(Self);
  try
    LSaveDlg.Title := 'Export Coverage Report';
    LSaveDlg.Filter := 'HTML files (*.html)|*.html';
    LSaveDlg.DefaultExt := 'html';
    LSaveDlg.FileName := 'coverage.html';

    if not LSaveDlg.Execute then
      Exit;

    LOutputPath := LSaveDlg.FileName;
  finally
    LSaveDlg.Free;
  end;

  SetControlsEnabled(False);
  try
    lblPhase.Caption := 'Generating HTML report...';
    Application.ProcessMessages;

    try
      LScanOpts := GetScanOptions(rbProject, edtDirectory.Text);
    except
      MessageDlg('No active project found.', mtError, [mbOK], 0);
      Exit;
    end;

    LScanner := TProjectScanner.Create;
    try
      LFiles := LScanner.Scan(LScanOpts);
    finally
      LScanner.Free;
    end;

    LParser := TBatchParser.Create;
    try
      LParser.OnProgress := UpdateProgress;
      LParser.ParseAll(LFiles);

      LCoverage := TDocCoverageReport.Create;
      try
        LStats := LCoverage.Analyze(LParser.Units);
        try
          LUndocItems := LCoverage.GetUndocumented(LParser.Units);
          LCoverage.RenderHTMLReport(LStats, LUndocItems, LOutputPath);
        finally
          LStats.ByKind.Free;
          LStats.ByVisibility.Free;
          LStats.ByUnit.Free;
        end;
      finally
        LCoverage.Free;
      end;
    finally
      LParser.Free;
    end;

    lblPhase.Caption := 'HTML report exported.';
    MessageDlg(Format('Report saved to: %s', [LOutputPath]), mtInformation, [mbOK], 0);
  except
    on E: Exception do
      MessageDlg('Error: ' + E.Message, mtError, [mbOK], 0);
  end;

  SetControlsEnabled(True);
end;

procedure TCoverageDialog.FormCreate(Sender: TObject);
var
  LProjectPath: string;
begin
  FItems := TList<PCoverageListItem>.Create;
  FCancelled := False;

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

  if LProjectPath <> '' then
  begin
    rbProject.Caption := 'Current Project (' + ExtractFileName(LProjectPath) + ')';
    rbProject.Checked := True;
    rbProject.Enabled := True;
  end
  else
  begin
    rbProject.Caption := 'Current Project (none)';
    rbProject.Checked := False;
    rbProject.Enabled := False;
    rbDirectory.Checked := True;
  end;
end;

procedure TCoverageDialog.lvItemsDblClick(Sender: TObject);
var
  LLocItem: PCoverageListItem;
begin
  if not Assigned(lvItems.Selected) then
    Exit;

  LLocItem := PCoverageListItem(lvItems.Selected.Data);
  if not Assigned(LLocItem) then
    Exit;

  if (LLocItem^.FilePath = '') or (LLocItem^.LineNumber = 0) then
    Exit;

  JumpToFile(LLocItem^.FilePath, LLocItem^.LineNumber);
end;

procedure TCoverageDialog.ClearItems;
var
  I: Integer;
begin
  if not Assigned(FItems) then
    Exit;

  for I := 0 to FItems.Count - 1 do
    Dispose(FItems[I]);

  FItems.Clear;
end;

procedure TCoverageDialog.DoAnalyze;
var
  LCoverage: TDocCoverageReport;
  LFiles: TArray<string>;
  LItem: TCoverageItem;
  LListItem: TListItem;
  LLocItem: PCoverageListItem;
  LParser: TBatchParser;
  LScanner: TProjectScanner;
  LScanOpts: TScanOptions;
  LStats: TCoverageStats;
  LUndocItems: TArray<TCoverageItem>;
  I: Integer;
begin
  FCancelled := False;
  SetControlsEnabled(False);
  lvItems.Items.BeginUpdate;
  try
    lvItems.Items.Clear;
    ClearItems;

    lblPhase.Caption := 'Scanning source files...';
    Application.ProcessMessages;

    try
      LScanOpts := GetScanOptions(rbProject, edtDirectory.Text);
    except
      MessageDlg('No active project found.', mtError, [mbOK], 0);
      Exit;
    end;

    LScanner := TProjectScanner.Create;
    try
      LFiles := LScanner.Scan(LScanOpts);
    finally
      LScanner.Free;
    end;

    if Length(LFiles) = 0 then
    begin
      MessageDlg('No source files found.', mtWarning, [mbOK], 0);
      Exit;
    end;

    lblPhase.Caption := Format('Parsing %d files...', [Length(LFiles)]);
    Application.ProcessMessages;

    LParser := TBatchParser.Create;
    try
      LParser.OnProgress := UpdateProgress;
      LParser.ParseAll(LFiles);

      if FCancelled then
        Exit;

      lblPhase.Caption := 'Analyzing coverage...';
      Application.ProcessMessages;

      LCoverage := TDocCoverageReport.Create;
      try
        LStats := LCoverage.Analyze(LParser.Units);
        try
          lblTotal.Caption := Format('Total: %d', [LStats.TotalElements]);
          lblDocumented.Caption := Format('Documented: %d (%.1f%%)', [LStats.Documented, LStats.CoveragePercent]);
          lblComplete.Caption := Format('Complete: %d (%.1f%%)', [LStats.Complete, LStats.CompletePercent]);
          pbCoverage.Position := Round(LStats.CoveragePercent);
          lblPercent.Caption := Format('%.1f%%', [LStats.CoveragePercent]);

          LUndocItems := LCoverage.GetUndocumented(LParser.Units);

          for I := 0 to Length(LUndocItems) - 1 do
          begin
            LItem := LUndocItems[I];

            New(LLocItem);
            LLocItem^.FilePath := '';
            LLocItem^.LineNumber := 0;
            FindLocation(LParser.Units, LItem.ElementFullName, LLocItem);
            FItems.Add(LLocItem);

            LListItem := lvItems.Items.Add;
            LListItem.Caption := LItem.ElementFullName;
            LListItem.SubItems.Add(LItem.Kind.ToString);
            LListItem.SubItems.Add(CoverageLevelToStr(LItem.Level));
            LListItem.SubItems.Add(string.Join(', ', LItem.MissingTags));
            LListItem.Data := LLocItem;
          end;
        finally
          LStats.ByKind.Free;
          LStats.ByVisibility.Free;
          LStats.ByUnit.Free;
        end;
      finally
        LCoverage.Free;
      end;
    finally
      LParser.Free;
    end;

    pbProgress.Position := pbProgress.Max;
    lblPhase.Caption := Format('Done - %d undocumented items found.', [Length(LUndocItems)]);
    btnExportHTML.Enabled := True;
  except
    on E: Exception do
      MessageDlg('Error: ' + E.Message, mtError, [mbOK], 0);
  end;

  lvItems.Items.EndUpdate;
  SetControlsEnabled(True);
end;

procedure TCoverageDialog.JumpToFile(const AFilePath: string; ALineNumber: Integer);
var
  LActionServices: IOTAActionServices;
  LModuleServices: IOTAModuleServices;
  LEditor: IOTASourceEditor;
  LModule: IOTAModule;
  LPos: TOTAEditPos;
  LView: IOTAEditView;
  I: Integer;
begin
  if not Supports(BorlandIDEServices, IOTAActionServices, LActionServices) then
    Exit;

  if not Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
    Exit;

  LActionServices.OpenFile(AFilePath);

  // OpenFile 직후 CurrentModule로 가져오기 (FindModule보다 안정적)
  LModule := LModuleServices.CurrentModule;
  if not Assigned(LModule) then
    Exit;

  LEditor := nil;
  for I := 0 to LModule.GetModuleFileCount - 1 do
  begin
    if Supports(LModule.GetModuleFileEditor(I), IOTASourceEditor, LEditor) then
      Break;
  end;

  if not Assigned(LEditor) then
    Exit;

  LView := LEditor.GetEditView(0);
  if not Assigned(LView) then
    Exit;

  LPos.Line := ALineNumber;
  LPos.Col := 1;
  LView.CursorPos := LPos;
  LView.MoveViewToCursor;
  LView.Paint;
end;

procedure TCoverageDialog.SetControlsEnabled(AEnabled: Boolean);
begin
  btnAnalyze.Enabled := AEnabled;
  rbProject.Enabled := AEnabled and (rbProject.Caption <> 'Current Project (none)');
  rbDirectory.Enabled := AEnabled;
  edtDirectory.Enabled := AEnabled;
  btnBrowse.Enabled := AEnabled;

  if AEnabled then
    btnClose.Caption := 'Close'
  else
    btnClose.Caption := 'Cancel';
end;

procedure TCoverageDialog.UpdateProgress(ACurrent, ATotal: Integer; const AMessage: string);
begin
  pbProgress.Max := ATotal;
  pbProgress.Position := ACurrent;
  lblPhase.Caption := AMessage;
  Application.ProcessMessages;
end;

end.
