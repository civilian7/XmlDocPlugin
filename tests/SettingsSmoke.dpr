program SettingsSmoke;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  XmlDoc.Plugin.Settings in '..\src\Plugin\XmlDoc.Plugin.Settings.pas',
  XmlDoc.Logger in '..\src\Core\XmlDoc.Logger.pas';

var
  Original, Writer, Reader: TPluginSettings;
  Changed: TGlobalSettings;
begin
  Original := TPluginSettings.Create;
  Writer := TPluginSettings.Create;
  try
    Changed := Writer.Global;
    Changed.Editor.Theme := 'dark';
    Changed.Editor.FontSize := 17;
    Changed.Editor.DebounceMs := 123;
    Changed.Editor.SaveDebounceMs := 456;
    Changed.Editor.ShowSignatureHeader := False;
    Changed.CodeGen.IndentSize := 4;
    Changed.Stub.PlaceholderPrefix := 'SMOKE: ';
    Changed.Shortcuts.ToggleInspector := 12345;
    Changed.General.Language := 'en';
    Writer.Global := Changed;
    Writer.Save;
    Reader := TPluginSettings.Create;
    try
      if (Reader.Global.Editor.Theme <> 'dark') or
         (Reader.Global.Editor.FontSize <> 17) or
         (Reader.Global.Editor.DebounceMs <> 123) or
         (Reader.Global.Editor.SaveDebounceMs <> 456) or
         Reader.Global.Editor.ShowSignatureHeader or
         (Reader.Global.CodeGen.IndentSize <> 4) or
         (Reader.Global.Stub.PlaceholderPrefix <> 'SMOKE: ') or
         (Reader.Global.Shortcuts.ToggleInspector <> 12345) or
         (Reader.Global.General.Language <> 'en') then
        raise Exception.Create('Settings were not loaded by a fresh settings instance');
      Writeln('PASS: editor, code generation, stub, shortcut, and general settings survive recreation');
    finally
      Reader.Free;
    end;
  finally
    Original.Save;
    Original.Free;
    Writer.Free;
  end;
end.
