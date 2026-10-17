program XmlDocTests;

{$APPTYPE CONSOLE}
uses
  System.SysUtils,
  Winapi.ActiveX,
  DUnitX.TestFramework, DUnitX.Loggers.Console,
  TestDocModel, TestDocParser, TestDocCodeGen, TestDocStubGen;
var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  CoInitialize(nil);
  try
  Runner := TDUnitX.CreateRunner;
  Runner.UseRTTI := True;
  Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
  Results := Runner.Execute;
  if not Results.AllPassed then ExitCode := 1;
  finally
    CoUninitialize;
  end;
end.
