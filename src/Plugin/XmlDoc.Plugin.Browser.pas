unit XmlDoc.Plugin.Browser;

interface

uses
  System.Classes, System.SysUtils, Vcl.Edge, Vcl.ExtCtrls;

type
  // Navigation must run after TEdgeBrowser finishes restoring its previous URI.
  TXmlDocBrowser = class(TEdgeBrowser)
  private
    FLoadTimer: TTimer;
    FHtml: string;
    FResourceName: string;
    procedure LoadTimer(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadEditorResource(AInstance: THandle; const AName: string);
    procedure RestoreSections;
    procedure SaveSections(const AJson: string);
    procedure ApplySettings;
  end;

procedure ConfigureWebViewLoader;

implementation

uses
  System.IOUtils, System.JSON, System.Win.Registry, Winapi.Windows, Winapi.EdgeUtils,
  XmlDoc.Plugin.Settings;

procedure ConfigureWebViewLoader;
var
  LPath: string;
begin
  LPath := TPath.Combine(ExtractFilePath(GetModuleName(HInstance)), 'WebView2Loader.dll');
  if TFile.Exists(LPath) then
    SetWebView2Path(LPath);
end;

constructor TXmlDocBrowser.Create(AOwner: TComponent);
begin
  ConfigureWebViewLoader;
  inherited;
  FLoadTimer := TTimer.Create(Self);
  FLoadTimer.Enabled := False;
  FLoadTimer.Interval := 1;
  FLoadTimer.OnTimer := LoadTimer;
end;

procedure TXmlDocBrowser.LoadEditorResource(AInstance: THandle; const AName: string);
var
  LStream: TResourceStream;
  LBytes: TBytes;
begin
  FResourceName := AName;
  LStream := TResourceStream.Create(AInstance, AName, RT_RCDATA);
  try
    SetLength(LBytes, LStream.Size);
    LStream.ReadBuffer(LBytes, Length(LBytes));
    FHtml := TEncoding.UTF8.GetString(LBytes);
  finally
    LStream.Free;
  end;
  FLoadTimer.Enabled := True;
end;

procedure TXmlDocBrowser.RestoreSections;
var
  LReg: TRegistry;
begin
  LReg := TRegistry.Create(KEY_READ);
  try
    if LReg.OpenKeyReadOnly('Software\XmlDocPlugin\EditorSections') and
       LReg.ValueExists(FResourceName) then
      ExecuteScript('window.xmlDocSections?.restore(' + LReg.ReadString(FResourceName) + ');');
  finally
    LReg.Free;
  end;
end;

procedure TXmlDocBrowser.SaveSections(const AJson: string);
var
  LReg: TRegistry;
begin
  LReg := TRegistry.Create(KEY_WRITE);
  try
    if LReg.OpenKey('Software\XmlDocPlugin\EditorSections', True) then
      LReg.WriteString(FResourceName, AJson);
  finally
    LReg.Free;
  end;
end;

procedure TXmlDocBrowser.ApplySettings;
var
  LJson: TJSONObject;
  LSettings: TEditorSettings;
begin
  LSettings := TPluginSettings.Instance.Global.Editor;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('theme', LSettings.Theme);
    LJson.AddPair('fontSize', TJSONNumber.Create(LSettings.FontSize));
    LJson.AddPair('showSignatureHeader', TJSONBool.Create(LSettings.ShowSignatureHeader));
    ExecuteScript('window.xmlDocSettings?.apply(' + LJson.ToJSON + ');');
  finally
    LJson.Free;
  end;
end;

procedure TXmlDocBrowser.LoadTimer(Sender: TObject);
begin
  FLoadTimer.Enabled := False;
  NavigateToString(FHtml);
end;

end.
