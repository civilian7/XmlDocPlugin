unit XmlDoc.Plugin.SettingsDialog;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Menus,
  XmlDoc.Plugin.Settings,
  XmlDoc.Logger, Vcl.Samples.Spin;

type
  /// <summary>플러그인 설정 다이얼로그</summary>
  TSettingsDialog = class(TForm)
    btnCancel: TButton;
    btnOK: TButton;
    chkAutoGenerate: TCheckBox;
    chkAutoShowOnCursor: TCheckBox;
    chkBlankLineAfter: TCheckBox;
    chkBlankLineBefore: TCheckBox;
    chkCheckUpdates: TCheckBox;
    chkCollapseEmptySections: TCheckBox;
    chkOmitEmptyTags: TCheckBox;
    chkShowSignatureHeader: TCheckBox;
    cmbIndentStyle: TComboBox;
    cmbLanguage: TComboBox;
    cmbLogLevel: TComboBox;
    cmbTheme: TComboBox;
    edtPlaceholderPrefix: TEdit;
    hotCoverageReport: THotKey;
    hotGenerateHelp: THotKey;
    hotGenerateStub: THotKey;
    hotNextUndocumented: THotKey;
    hotPreviousUndocumented: THotKey;
    hotToggleInspector: THotKey;
    PageControl: TPageControl;
    spnDebounceMs: TSpinEdit;
    spnFontSize: TSpinEdit;
    spnIndentSize: TSpinEdit;
    spnSaveDebounceMs: TSpinEdit;
    tsAdvanced: TTabSheet;
    tsCodeGen: TTabSheet;
    tsGeneral: TTabSheet;
    tsShortcuts: TTabSheet;

    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);

  private
    FShortcutsChanged: Boolean;

    procedure LoadSettings;
    procedure SaveSettings;

  public
    property ShortcutsChanged: Boolean read FShortcutsChanged;
  end;

/// <summary>설정 다이얼로그를 표시합니다.</summary>
/// <returns>True면 설정이 변경됨</returns>
function ShowSettingsDialog: Boolean;

implementation

{$R *.dfm}

function ShowSettingsDialog: Boolean;
var
  LDialog: TSettingsDialog;
begin
  Result := False;
  LDialog := TSettingsDialog.Create(Application);
  try
    if LDialog.ShowModal = mrOk then
      Result := True;
  finally
    LDialog.Free;
  end;
end;

{ TSettingsDialog }

procedure TSettingsDialog.FormCreate(Sender: TObject);
begin
  FShortcutsChanged := False;
  LoadSettings;
end;

procedure TSettingsDialog.btnOKClick(Sender: TObject);
begin
  SaveSettings;
end;

procedure TSettingsDialog.LoadSettings;
var
  LSettings: TGlobalSettings;
begin
  LSettings := TPluginSettings.Instance.Global;

  // General
  cmbTheme.ItemIndex := cmbTheme.Items.IndexOf(LSettings.Editor.Theme);
  if cmbTheme.ItemIndex < 0 then
    cmbTheme.ItemIndex := 0;

  spnFontSize.Value := LSettings.Editor.FontSize;

  cmbLanguage.ItemIndex := cmbLanguage.Items.IndexOf(LSettings.General.Language);
  if cmbLanguage.ItemIndex < 0 then
    cmbLanguage.ItemIndex := 0;

  chkAutoShowOnCursor.Checked := LSettings.Editor.AutoShowOnCursor;
  chkCollapseEmptySections.Checked := LSettings.Editor.CollapseEmptySections;
  chkShowSignatureHeader.Checked := LSettings.Editor.ShowSignatureHeader;
  chkCheckUpdates.Checked := LSettings.General.CheckUpdates;

  // Code Generation
  cmbIndentStyle.ItemIndex := Ord(LSettings.CodeGen.IndentStyle);
  spnIndentSize.Value := LSettings.CodeGen.IndentSize;
  chkBlankLineBefore.Checked := LSettings.CodeGen.BlankLineBefore;
  chkBlankLineAfter.Checked := LSettings.CodeGen.BlankLineAfter;
  chkOmitEmptyTags.Checked := LSettings.CodeGen.OmitEmptyTags;
  chkAutoGenerate.Checked := LSettings.Stub.AutoGenerate;
  edtPlaceholderPrefix.Text := LSettings.Stub.PlaceholderPrefix;

  // Shortcuts
  hotToggleInspector.HotKey := LSettings.Shortcuts.ToggleInspector;
  hotGenerateStub.HotKey := LSettings.Shortcuts.GenerateStub;
  hotGenerateHelp.HotKey := LSettings.Shortcuts.GenerateHelp;
  hotCoverageReport.HotKey := LSettings.Shortcuts.CoverageReport;
  hotNextUndocumented.HotKey := LSettings.Shortcuts.NextUndocumented;
  hotPreviousUndocumented.HotKey := LSettings.Shortcuts.PreviousUndocumented;

  // Advanced
  spnDebounceMs.Value := LSettings.Editor.DebounceMs;
  spnSaveDebounceMs.Value := LSettings.Editor.SaveDebounceMs;
  cmbLogLevel.ItemIndex := Ord(LSettings.General.LogLevel);
end;

procedure TSettingsDialog.SaveSettings;
var
  LSettings: TGlobalSettings;
begin
  LSettings := TPluginSettings.Instance.Global;

  // General
  LSettings.Editor.Theme := cmbTheme.Text;
  LSettings.Editor.FontSize := spnFontSize.Value;
  LSettings.General.Language := cmbLanguage.Text;
  LSettings.Editor.AutoShowOnCursor := chkAutoShowOnCursor.Checked;
  LSettings.Editor.CollapseEmptySections := chkCollapseEmptySections.Checked;
  LSettings.Editor.ShowSignatureHeader := chkShowSignatureHeader.Checked;
  LSettings.General.CheckUpdates := chkCheckUpdates.Checked;

  // Code Generation
  LSettings.CodeGen.IndentStyle := TIndentStyle(cmbIndentStyle.ItemIndex);
  LSettings.CodeGen.IndentSize := spnIndentSize.Value;
  LSettings.CodeGen.BlankLineBefore := chkBlankLineBefore.Checked;
  LSettings.CodeGen.BlankLineAfter := chkBlankLineAfter.Checked;
  LSettings.CodeGen.OmitEmptyTags := chkOmitEmptyTags.Checked;
  LSettings.Stub.AutoGenerate := chkAutoGenerate.Checked;
  LSettings.Stub.PlaceholderPrefix := edtPlaceholderPrefix.Text;

  // Shortcuts
  FShortcutsChanged :=
    (LSettings.Shortcuts.ToggleInspector <> hotToggleInspector.HotKey) or
    (LSettings.Shortcuts.GenerateStub <> hotGenerateStub.HotKey) or
    (LSettings.Shortcuts.GenerateHelp <> hotGenerateHelp.HotKey) or
    (LSettings.Shortcuts.CoverageReport <> hotCoverageReport.HotKey) or
    (LSettings.Shortcuts.NextUndocumented <> hotNextUndocumented.HotKey) or
    (LSettings.Shortcuts.PreviousUndocumented <> hotPreviousUndocumented.HotKey);

  LSettings.Shortcuts.ToggleInspector := hotToggleInspector.HotKey;
  LSettings.Shortcuts.GenerateStub := hotGenerateStub.HotKey;
  LSettings.Shortcuts.GenerateHelp := hotGenerateHelp.HotKey;
  LSettings.Shortcuts.CoverageReport := hotCoverageReport.HotKey;
  LSettings.Shortcuts.NextUndocumented := hotNextUndocumented.HotKey;
  LSettings.Shortcuts.PreviousUndocumented := hotPreviousUndocumented.HotKey;

  // Advanced
  LSettings.Editor.DebounceMs := spnDebounceMs.Value;
  LSettings.Editor.SaveDebounceMs := spnSaveDebounceMs.Value;
  LSettings.General.LogLevel := TLogLevel(cmbLogLevel.ItemIndex);

  TPluginSettings.Instance.Global := LSettings;
  TPluginSettings.Instance.Save;
end;

end.
