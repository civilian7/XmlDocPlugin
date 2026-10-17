program BrowserSmoke;

{$APPTYPE CONSOLE}
{$R BrowserSmoke.res}

uses
  System.SysUtils, System.Classes, System.JSON, Winapi.Windows, Winapi.Messages,
  Winapi.ActiveX, Winapi.WebView2, Vcl.Forms, Vcl.Controls, Vcl.Edge,
  XmlDoc.Plugin.Browser in '..\src\Plugin\XmlDoc.Plugin.Browser.pas',
  XmlDoc.Plugin.Settings in '..\src\Plugin\XmlDoc.Plugin.Settings.pas',
  XmlDoc.Logger in '..\src\Core\XmlDoc.Logger.pas';

type
  TProbe = class(TForm)
  public
    Browser: TXmlDocBrowser;
    Phase: Integer;
    Done, PendingRecreate, Passed: Boolean;
    procedure Created(Sender: TCustomEdgeBrowser; Status: HRESULT);
    procedure Navigated(Sender: TCustomEdgeBrowser; Success: Boolean;
      Status: COREWEBVIEW2_WEB_ERROR_STATUS);
    procedure MessageReceived(Sender: TCustomEdgeBrowser; Args: TWebMessageReceivedEventArgs);
  end;

procedure TProbe.Created(Sender: TCustomEdgeBrowser; Status: HRESULT);
begin
  if Status <> S_OK then
    raise Exception.Create('WebView2 creation failed: ' + IntToHex(Status, 8));
  Browser.LoadEditorResource(HInstance, 'XMLDOC_SMOKE_HTML');
end;

procedure TProbe.Navigated(Sender: TCustomEdgeBrowser; Success: Boolean;
  Status: COREWEBVIEW2_WEB_ERROR_STATUS);
begin
  if not Success then
    raise Exception.Create('Navigation failed');
  Browser.RestoreSections;
  Browser.ExecuteScript(
    'setTimeout(() => { if (!window.xmlDocSections) return;' +
    'if (' + IntToStr(Phase) + '===0) window.xmlDocSections.restore({"remarks-section":false});' +
    'window.bridge.receive({type:"loadDoc",data:{element:{kind:"method",name:"Probe",params:[]},doc:{summary:"Runtime probe"}}});' +
    'window.xmlDocSettings.apply({theme:"light",fontSize:13,showSignatureHeader:true});' +
    'const light=getComputedStyle(document.body).backgroundColor==="rgb(255, 255, 255)";' +
    'window.xmlDocSettings.apply({theme:"auto",fontSize:13,showSignatureHeader:true});' +
    'const auto=document.documentElement.dataset.theme===(matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light");' +
    'window.xmlDocSettings.apply({theme:"dark",fontSize:16,showSignatureHeader:true});' +
    'const s=document.querySelector("#remarks-section");' +
    'const restored=s.classList.contains("collapsed");' +
    'if (' + IntToStr(Phase) + '===0) s.querySelector(".doc-heading").click();' +
    'const ok=light && auto && document.querySelector(".tiptap")?.textContent.includes("Runtime probe") &&' +
    'getComputedStyle(document.body).backgroundColor==="rgb(30, 30, 30)" &&' +
    '(' + IntToStr(Phase) + '===0 || restored);' +
    'window.chrome.webview.postMessage(ok?"SMOKE:PASS":"SMOKE:FAIL");},100);');
end;

procedure TProbe.MessageReceived(Sender: TCustomEdgeBrowser; Args: TWebMessageReceivedEventArgs);
var
  Text: PWideChar;
  Msg: string;
  Json: TJSONObject;
begin
  Text := nil;
  if Args.ArgsInterface.TryGetWebMessageAsString(Text) <> S_OK then Exit;
  try
    Msg := string(Text);
  finally
    CoTaskMemFree(Text);
  end;
  if Msg.StartsWith('SMOKE:') then
  begin
    Writeln('phase ', Phase, ': ', Msg);
    if Msg <> 'SMOKE:PASS' then begin Done := True; Exit; end;
    if Phase = 3 then begin Passed := True; Done := True; end
    else PendingRecreate := True;
  end
  else
  begin
    Json := TJSONObject.ParseJSONValue(Msg) as TJSONObject;
    try
      if Assigned(Json) and (Json.GetValue<string>('type', '') = 'sectionStateChanged') then
        Browser.SaveSections(Json.GetValue<TJSONObject>('sections').ToJSON);
    finally
      Json.Free;
    end;
  end;
end;

var
  Probe: TProbe;
  Started: UInt64;
begin
  Application.Initialize;
  Probe := TProbe.CreateNew(nil);
  try
    Probe.SetBounds(100, 100, 600, 600);
    Probe.Browser := TXmlDocBrowser.Create(Probe);
    Probe.Browser.Parent := Probe;
    Probe.Browser.Align := alClient;
    Probe.Browser.UserDataFolder := GetEnvironmentVariable('LOCALAPPDATA') + '\XmlDocPlugin\BrowserSmoke';
    Probe.Browser.OnCreateWebViewCompleted := Probe.Created;
    Probe.Browser.OnNavigationCompleted := Probe.Navigated;
    Probe.Browser.OnWebMessageReceived := Probe.MessageReceived;
    Probe.Show;
    Probe.Browser.CreateWebView;
    Started := GetTickCount64;
    while not Probe.Done and (GetTickCount64 - Started < 20000) do
    begin
      Application.ProcessMessages;
      if Probe.PendingRecreate then
      begin
        Probe.PendingRecreate := False;
        Inc(Probe.Phase);
        Probe.Browser.Perform(CM_RECREATEWND, 0, 0);
      end;
      Sleep(10);
    end;
    if not Probe.Passed then Halt(1);
  finally
    Probe.Free;
  end;
end.
