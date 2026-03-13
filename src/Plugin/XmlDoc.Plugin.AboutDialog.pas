unit XmlDoc.Plugin.AboutDialog;

interface

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  XmlDoc.Plugin.Utils;

type
  TAboutDialog = class(TForm)
    btnOK: TButton;
    bvlSeparator: TBevel;
    lblCopyright: TLabel;
    lblDescription: TLabel;
    lblLib1Name: TLabel;
    lblLib2Name: TLabel;
    lblLib3Name: TLabel;
    lblLib4Name: TLabel;
    lblLib5Name: TLabel;
    lblOSSHeader: TLabel;
    lblTitle: TLabel;
    lblVersion: TLabel;
    lnkContact: TLinkLabel;
    lnkLib1: TLinkLabel;
    lnkLib2: TLinkLabel;
    lnkLib3: TLinkLabel;
    lnkLib4: TLinkLabel;
    lnkLib5: TLinkLabel;
    pnlBottom: TPanel;
    scrlContent: TScrollBox;

    procedure FormCreate(Sender: TObject);
    procedure OnLinkClick(Sender: TObject; const Link: string; LinkType: TSysLinkType);
  end;

procedure ShowAboutDialog;

implementation

{$R *.dfm}

{ TAboutDialog }

procedure TAboutDialog.FormCreate(Sender: TObject);
var
  LVersion: string;
begin
  LVersion := GetModuleVersion;
  if LVersion = '' then
    LVersion := '0.5.0';

  lblVersion.Caption := 'Version ' + LVersion;
end;

procedure TAboutDialog.OnLinkClick(Sender: TObject; const Link: string; LinkType: TSysLinkType);
begin
  ShellExecute(0, 'open', PChar(Link), nil, nil, SW_SHOWNORMAL);
end;

procedure ShowAboutDialog;
var
  LDialog: TAboutDialog;
begin
  LDialog := TAboutDialog.Create(Application);
  try
    LDialog.ShowModal;
  finally
    LDialog.Free;
  end;
end;

end.
