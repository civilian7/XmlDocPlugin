unit XmlDoc.Plugin.Shortcuts;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Menus,
  ToolsAPI,
  XmlDoc.Plugin.Settings;

type
  /// <summary>IDE 단축키 바인딩. IOTAKeyboardBinding을 구현하여 단축키를 등록합니다.</summary>
  TXmlDocKeyBinding = class(TNotifierObject, IOTAKeyboardBinding)
  private
    procedure DoGenerateHelp(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
    procedure DoGenerateStub(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
    procedure DoToggleInspector(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
  public
    { IOTAKeyboardBinding }
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
  end;

  /// <summary>IDE 메인 메뉴에 XmlDoc 서브메뉴를 추가합니다.</summary>
  TXmlDocMenuIntegration = class
  private
    FMiCoverageReport: TMenuItem;
    FMiGenerateHelp: TMenuItem;
    FMiGenerateStub: TMenuItem;
    FMenuItems: TList;
    FMiNextUndocumented: TMenuItem;
    FMiPreviousUndocumented: TMenuItem;
    FMiToggleInspector: TMenuItem;

    procedure OnCoverageReportClick(Sender: TObject);
    procedure OnGenerateHelpClick(Sender: TObject);
    procedure OnGenerateStubClick(Sender: TObject);
    procedure OnNextUndocumentedClick(Sender: TObject);
    procedure OnPreviousUndocumentedClick(Sender: TObject);
    procedure OnSettingsClick(Sender: TObject);
    procedure OnToggleInspectorClick(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>IDE 메뉴에 XmlDoc 항목을 추가합니다.</summary>
    procedure InstallMenu;
    /// <summary>기존 메뉴 아이템의 ShortCut을 현재 설정값으로 갱신합니다.</summary>
    procedure RefreshShortcuts;
    /// <summary>IDE 메뉴에서 XmlDoc 항목을 제거합니다.</summary>
    procedure UninstallMenu;
  end;

/// <summary>Doc Inspector 토글 콜백을 설정합니다.</summary>
/// <param name="ACallback">토글 시 호출할 콜백</param>
procedure SetToggleInspectorCallback(ACallback: TProc);

/// <summary>Doc Stub 생성 콜백을 설정합니다.</summary>
/// <param name="ACallback">생성 시 호출할 콜백</param>
procedure SetGenerateStubCallback(ACallback: TProc);

/// <summary>Help 생성 다이얼로그 콜백을 설정합니다.</summary>
/// <param name="ACallback">다이얼로그 표시 시 호출할 콜백</param>
procedure SetGenerateHelpCallback(ACallback: TProc);

/// <summary>Coverage Report 콜백을 설정합니다.</summary>
/// <param name="ACallback">리포트 표시 시 호출할 콜백</param>
procedure SetCoverageReportCallback(ACallback: TProc);

/// <summary>다음 미문서화 요소 이동 콜백을 설정합니다.</summary>
/// <param name="ACallback">이동 시 호출할 콜백</param>
procedure SetNextUndocumentedCallback(ACallback: TProc);

/// <summary>이전 미문서화 요소 이동 콜백을 설정합니다.</summary>
/// <param name="ACallback">이동 시 호출할 콜백</param>
procedure SetPreviousUndocumentedCallback(ACallback: TProc);

/// <summary>Settings 다이얼로그 콜백을 설정합니다.</summary>
/// <param name="ACallback">다이얼로그 표시 시 호출할 콜백</param>
procedure SetSettingsCallback(ACallback: TProc);

implementation

uses
  Vcl.ActnList;

var
  GToggleInspectorCallback: TProc;
  GGenerateStubCallback: TProc;
  GGenerateHelpCallback: TProc;
  GCoverageReportCallback: TProc;
  GNextUndocumentedCallback: TProc;
  GPreviousUndocumentedCallback: TProc;
  GSettingsCallback: TProc;

procedure SetToggleInspectorCallback(ACallback: TProc);
begin
  GToggleInspectorCallback := ACallback;
end;

procedure SetGenerateStubCallback(ACallback: TProc);
begin
  GGenerateStubCallback := ACallback;
end;

procedure SetGenerateHelpCallback(ACallback: TProc);
begin
  GGenerateHelpCallback := ACallback;
end;

procedure SetCoverageReportCallback(ACallback: TProc);
begin
  GCoverageReportCallback := ACallback;
end;

procedure SetNextUndocumentedCallback(ACallback: TProc);
begin
  GNextUndocumentedCallback := ACallback;
end;

procedure SetPreviousUndocumentedCallback(ACallback: TProc);
begin
  GPreviousUndocumentedCallback := ACallback;
end;

procedure SetSettingsCallback(ACallback: TProc);
begin
  GSettingsCallback := ACallback;
end;

{ TXmlDocKeyBinding }

procedure TXmlDocKeyBinding.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
var
  LSettings: TPluginSettings;
begin
  LSettings := TPluginSettings.Instance;

  BindingServices.AddKeyBinding(
    [LSettings.Global.Shortcuts.ToggleInspector],
    DoToggleInspector, nil);

  BindingServices.AddKeyBinding(
    [LSettings.Global.Shortcuts.GenerateStub],
    DoGenerateStub, nil);

  BindingServices.AddKeyBinding(
    [LSettings.Global.Shortcuts.GenerateHelp],
    DoGenerateHelp, nil);
end;

function TXmlDocKeyBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TXmlDocKeyBinding.GetDisplayName: string;
begin
  Result := 'XmlDoc Plugin Shortcuts';
end;

function TXmlDocKeyBinding.GetName: string;
begin
  Result := 'XmlDocPlugin.KeyBinding';
end;

procedure TXmlDocKeyBinding.DoGenerateHelp(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
begin
  BindingResult := krHandled;
  if Assigned(GGenerateHelpCallback) then
    GGenerateHelpCallback;
end;

procedure TXmlDocKeyBinding.DoGenerateStub(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
begin
  BindingResult := krHandled;
  if Assigned(GGenerateStubCallback) then
    GGenerateStubCallback;
end;

procedure TXmlDocKeyBinding.DoToggleInspector(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
begin
  BindingResult := krHandled;
  if Assigned(GToggleInspectorCallback) then
    GToggleInspectorCallback;
end;

{ TXmlDocMenuIntegration }

constructor TXmlDocMenuIntegration.Create;
begin
  inherited Create;

  FMenuItems := TList.Create;
end;

destructor TXmlDocMenuIntegration.Destroy;
begin
  UninstallMenu;
  FMenuItems.Free;

  inherited;
end;

procedure TXmlDocMenuIntegration.InstallMenu;
var
  LNTAServices: INTAServices;
  LMainMenu: TMainMenu;
  LToolsMenu: TMenuItem;
  LXmlDocMenu: TMenuItem;
  LItem: TMenuItem;
  I: Integer;
begin
  if not Supports(BorlandIDEServices, INTAServices, LNTAServices) then
    Exit;

  LMainMenu := LNTAServices.MainMenu;
  if not Assigned(LMainMenu) then
    Exit;

  // Tools 메뉴 찾기
  LToolsMenu := nil;
  for I := 0 to LMainMenu.Items.Count - 1 do
  begin
    if SameText(LMainMenu.Items[I].Name, 'ToolsMenu') then
    begin
      LToolsMenu := LMainMenu.Items[I];
      Break;
    end;
  end;

  if not Assigned(LToolsMenu) then
    Exit;

  // XmlDoc Plugin 서브메뉴 생성
  LXmlDocMenu := TMenuItem.Create(LMainMenu);
  LXmlDocMenu.Caption := 'XmlDoc Plugin';
  LXmlDocMenu.Name := 'XmlDocPluginMenu';
  FMenuItems.Add(LXmlDocMenu);

  // Toggle Doc Inspector
  LItem := TMenuItem.Create(LXmlDocMenu);
  LItem.Caption := 'Toggle Doc Inspector';
  LItem.ShortCut := TPluginSettings.Instance.Global.Shortcuts.ToggleInspector;
  LItem.OnClick := OnToggleInspectorClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiToggleInspector := LItem;

  // Generate Doc Stub
  LItem := TMenuItem.Create(LXmlDocMenu);
  LItem.Caption := 'Generate Doc Stub';
  LItem.ShortCut := TPluginSettings.Instance.Global.Shortcuts.GenerateStub;
  LItem.OnClick := OnGenerateStubClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiGenerateStub := LItem;

  // Separator
  LItem := TMenuItem.Create(LXmlDocMenu);
  LItem.Caption := '-';
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);

  // Generate Help...
  LItem := TMenuItem.Create(LXmlDocMenu);
  LItem.Caption := 'Generate Help...';
  LItem.ShortCut := TPluginSettings.Instance.Global.Shortcuts.GenerateHelp;
  LItem.OnClick := OnGenerateHelpClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiGenerateHelp := LItem;

  // Coverage Report...
  LItem := TMenuItem.Create(LXmlDocMenu);
  LItem.Caption := 'Coverage Report...';
  LItem.ShortCut := TPluginSettings.Instance.Global.Shortcuts.CoverageReport;
  LItem.OnClick := OnCoverageReportClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiCoverageReport := LItem;

  // Separator
  LItem := TMenuItem.Create(LXmlDocMenu);
  LItem.Caption := '-';
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);

  // Next Undocumented
  LItem := TMenuItem.Create(LXmlDocMenu);
  LItem.Caption := 'Next Undocumented';
  LItem.ShortCut := TPluginSettings.Instance.Global.Shortcuts.NextUndocumented;
  LItem.OnClick := OnNextUndocumentedClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiNextUndocumented := LItem;

  // Previous Undocumented
  LItem := TMenuItem.Create(LXmlDocMenu);
  LItem.Caption := 'Previous Undocumented';
  LItem.ShortCut := TPluginSettings.Instance.Global.Shortcuts.PreviousUndocumented;
  LItem.OnClick := OnPreviousUndocumentedClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);
  FMiPreviousUndocumented := LItem;

  // Separator
  LItem := TMenuItem.Create(LXmlDocMenu);
  LItem.Caption := '-';
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);

  // Settings...
  LItem := TMenuItem.Create(LXmlDocMenu);
  LItem.Caption := 'Settings...';
  LItem.OnClick := OnSettingsClick;
  LXmlDocMenu.Add(LItem);
  FMenuItems.Add(LItem);

  LToolsMenu.Add(LXmlDocMenu);
end;

procedure TXmlDocMenuIntegration.RefreshShortcuts;
var
  LShortcuts: TShortcutSettings;
begin
  LShortcuts := TPluginSettings.Instance.Global.Shortcuts;

  if Assigned(FMiToggleInspector) then
    FMiToggleInspector.ShortCut := LShortcuts.ToggleInspector;
  if Assigned(FMiGenerateStub) then
    FMiGenerateStub.ShortCut := LShortcuts.GenerateStub;
  if Assigned(FMiGenerateHelp) then
    FMiGenerateHelp.ShortCut := LShortcuts.GenerateHelp;
  if Assigned(FMiCoverageReport) then
    FMiCoverageReport.ShortCut := LShortcuts.CoverageReport;
  if Assigned(FMiNextUndocumented) then
    FMiNextUndocumented.ShortCut := LShortcuts.NextUndocumented;
  if Assigned(FMiPreviousUndocumented) then
    FMiPreviousUndocumented.ShortCut := LShortcuts.PreviousUndocumented;
end;

procedure TXmlDocMenuIntegration.UninstallMenu;
var
  I: Integer;
begin
  // 역순으로 제거 (자식 먼저, 부모 나중에)
  for I := FMenuItems.Count - 1 downto 0 do
    TMenuItem(FMenuItems[I]).Free;

  FMenuItems.Clear;
end;

procedure TXmlDocMenuIntegration.OnCoverageReportClick(Sender: TObject);
begin
  if Assigned(GCoverageReportCallback) then
    GCoverageReportCallback;
end;

procedure TXmlDocMenuIntegration.OnGenerateHelpClick(Sender: TObject);
begin
  if Assigned(GGenerateHelpCallback) then
    GGenerateHelpCallback;
end;

procedure TXmlDocMenuIntegration.OnGenerateStubClick(Sender: TObject);
begin
  if Assigned(GGenerateStubCallback) then
    GGenerateStubCallback;
end;

procedure TXmlDocMenuIntegration.OnNextUndocumentedClick(Sender: TObject);
begin
  if Assigned(GNextUndocumentedCallback) then
    GNextUndocumentedCallback;
end;

procedure TXmlDocMenuIntegration.OnPreviousUndocumentedClick(Sender: TObject);
begin
  if Assigned(GPreviousUndocumentedCallback) then
    GPreviousUndocumentedCallback;
end;

procedure TXmlDocMenuIntegration.OnSettingsClick(Sender: TObject);
begin
  if Assigned(GSettingsCallback) then
    GSettingsCallback;
end;

procedure TXmlDocMenuIntegration.OnToggleInspectorClick(Sender: TObject);
begin
  if Assigned(GToggleInspectorCallback) then
    GToggleInspectorCallback;
end;

end.
