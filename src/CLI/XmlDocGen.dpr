program XmlDocGen;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  XmlDoc.CLI.Main;

var
  LCLI: TCLIMain;
  LExitCode: Integer;
begin
  try
    LCLI := TCLIMain.Create;
    try
      LExitCode := LCLI.Run;
    finally
      LCLI.Free;
    end;
    ExitCode := LExitCode;
  except
    on E: Exception do
    begin
      WriteLn('Fatal error: ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
