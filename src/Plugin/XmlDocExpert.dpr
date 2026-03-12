library XmlDocExpert;

{ Expert DLL - IDE의 Known Experts 레지스트리에 등록하여 사용
  ──────────────────────────────────────────────────────
  BPL(XmlDocPlugin.dpk)과 동일한 소스를 공유합니다.
  TDockableForm(designide.bpl)을 사용하므로 런타임 패키지 링크가 필수입니다.

  빌드 설정 (Project Options):
    - Packages > Runtime packages: Link with runtime packages = ON
        rtl;vcl;designide;xmlrtl;vclwinx;vcledge;VclSmp
    - Delphi Compiler > Search path:
        vendor\DelphiAST\Source;vendor\DelphiAST\Source\SimpleParser
    - Delphi Compiler > Unit scope names:
        Winapi;System.Win;Data.Win;Vcl;Vcl.Imaging;System;Data;Xml

  IDE 등록 (레지스트리):
    HKCU\Software\Embarcadero\BDS\37.0\Experts
      XmlDocPlugin = <path>\XmlDocExpert.dll

  IDE 등록 해제:
    위 레지스트리 키 삭제 후 IDE 재시작
}

{$R *.res}

uses
  System.SysUtils,
  Vcl.Forms,
  ToolsAPI,
  DockForm,
  // Core
  XmlDoc.Consts in '..\Core\XmlDoc.Consts.pas',
  XmlDoc.Model in '..\Core\XmlDoc.Model.pas',
  XmlDoc.CodeGen in '..\Core\XmlDoc.CodeGen.pas',
  XmlDoc.CodeGen.OTA in '..\Core\XmlDoc.CodeGen.OTA.pas',
  XmlDoc.Parser in '..\Core\XmlDoc.Parser.pas',
  XmlDoc.StubGen in '..\Core\XmlDoc.StubGen.pas',
  XmlDoc.I18n in '..\Core\XmlDoc.I18n.pas',
  XmlDoc.Logger in '..\Core\XmlDoc.Logger.pas',
  XmlDoc.ErrorHandler in '..\Core\XmlDoc.ErrorHandler.pas',
  XmlDoc.ParamDict in '..\Core\XmlDoc.ParamDict.pas',
  // HelpGen
  XmlDoc.HelpGen.Types in '..\HelpGen\XmlDoc.HelpGen.Types.pas',
  XmlDoc.HelpGen.Scanner in '..\HelpGen\XmlDoc.HelpGen.Scanner.pas',
  XmlDoc.HelpGen.BatchParser in '..\HelpGen\XmlDoc.HelpGen.BatchParser.pas',
  XmlDoc.HelpGen.CrossRef in '..\HelpGen\XmlDoc.HelpGen.CrossRef.pas',
  XmlDoc.HelpGen.Renderer in '..\HelpGen\XmlDoc.HelpGen.Renderer.pas',
  XmlDoc.HelpGen.Renderer.HTML in '..\HelpGen\XmlDoc.HelpGen.Renderer.HTML.pas',
  XmlDoc.HelpGen.Renderer.MD in '..\HelpGen\XmlDoc.HelpGen.Renderer.MD.pas',
  XmlDoc.HelpGen.Renderer.CHM in '..\HelpGen\XmlDoc.HelpGen.Renderer.CHM.pas',
  XmlDoc.HelpGen.Renderer.JSON in '..\HelpGen\XmlDoc.HelpGen.Renderer.JSON.pas',
  XmlDoc.HelpGen.SitePublisher in '..\HelpGen\XmlDoc.HelpGen.SitePublisher.pas',
  XmlDoc.HelpGen.Coverage in '..\HelpGen\XmlDoc.HelpGen.Coverage.pas',
  XmlDoc.HelpGen.ThemeEngine in '..\HelpGen\XmlDoc.HelpGen.ThemeEngine.pas',
  // Plugin
  XmlDoc.Plugin.Main in 'XmlDoc.Plugin.Main.pas',
  XmlDoc.Plugin.EditorNotifier in 'XmlDoc.Plugin.EditorNotifier.pas',
  XmlDoc.Plugin.DocInspector in 'XmlDoc.Plugin.DocInspector.pas',
  XmlDoc.Plugin.Settings in 'XmlDoc.Plugin.Settings.pas',
  XmlDoc.Plugin.SettingsDialog in 'XmlDoc.Plugin.SettingsDialog.pas',
  XmlDoc.Plugin.Shortcuts in 'XmlDoc.Plugin.Shortcuts.pas',
  XmlDoc.Plugin.BatchGenDialog in 'XmlDoc.Plugin.BatchGenDialog.pas',
  XmlDoc.Plugin.CoverageDialog in 'XmlDoc.Plugin.CoverageDialog.pas',
  XmlDoc.Plugin.QuickDocPreview in 'XmlDoc.Plugin.QuickDocPreview.pas',
  XmlDoc.Plugin.UndocNavigator in 'XmlDoc.Plugin.UndocNavigator.pas',
  XmlDoc.Plugin.UpdateChecker in 'XmlDoc.Plugin.UpdateChecker.pas';

procedure FinalizeWizard;
begin
  // 위저드 수명은 IDE가 인터페이스 참조로 관리
end;

function InitWizard(const BorlandIDEServices: IBorlandIDEServices;
  RegisterProc: TWizardRegisterProc;
  var Terminate: TWizardTerminateProc): Boolean; stdcall;
begin
  Result := Assigned(BorlandIDEServices);
  if not Result then
    Exit;

  // DLL은 자체 ToolsAPI.BorlandIDEServices가 비어 있으므로 직접 설정
  ToolsAPI.BorlandIDEServices := BorlandIDEServices;

  // VCL 다이얼로그가 IDE 메인 윈도우에 올바르게 표시되도록 설정
  Application.Handle := (BorlandIDEServices as IOTAServices).GetParentHandle;

  RegisterProc(TXmlDocWizard.Create);
  Terminate := FinalizeWizard;
end;

exports
  InitWizard name WizardEntryPoint;

begin
end.
