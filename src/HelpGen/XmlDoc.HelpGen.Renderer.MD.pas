unit XmlDoc.HelpGen.Renderer.MD;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.CrossRef,
  XmlDoc.HelpGen.Renderer;

type
  /// <summary>GitHub Wiki / GitBook 호환 Markdown 문서를 생성합니다.</summary>
  TMarkdownDocRenderer = class(TInterfacedObject, IDocRenderer)
  private
    FOptions: TRenderOptions;
    FResolver: TCrossRefResolver;
    FUnits: TObjectList<TUnitDocInfo>;

    function FormatDocToMD(const ADoc: TXmlDocModel; const AUnitName: string): string;
    function MakeMDLink(const ACref, AUnitName: string): string;
    procedure RenderReadme;
    procedure RenderSidebar;
    procedure RenderSummary;
    procedure RenderTypeMD(const AType: TTypeDocInfo; const AUnitName: string);
    procedure RenderUnitMD(const AUnit: TUnitDocInfo);
    procedure WriteFile(const ARelPath, AContent: string);

  public
    procedure Render(
      const AUnits: TObjectList<TUnitDocInfo>;
      const AResolver: TCrossRefResolver;
      const AOptions: TRenderOptions
    );
  end;

implementation

{ TMarkdownDocRenderer }

procedure TMarkdownDocRenderer.Render(
  const AUnits: TObjectList<TUnitDocInfo>;
  const AResolver: TCrossRefResolver;
  const AOptions: TRenderOptions);
var
  I, J: Integer;
begin
  FUnits := AUnits;
  FResolver := AResolver;
  FOptions := AOptions;

  TDirectory.CreateDirectory(FOptions.OutputDir);
  TDirectory.CreateDirectory(TPath.Combine(FOptions.OutputDir, 'units'));

  RenderReadme;
  RenderSummary;
  RenderSidebar;

  for I := 0 to AUnits.Count - 1 do
  begin
    RenderUnitMD(AUnits[I]);

    for J := 0 to AUnits[I].Types.Count - 1 do
      RenderTypeMD(AUnits[I].Types[J], AUnits[I].UnitName);
  end;
end;

function TMarkdownDocRenderer.FormatDocToMD(const ADoc: TXmlDocModel;
  const AUnitName: string): string;
var
  LSB: TStringBuilder;
  I: Integer;
begin
  LSB := TStringBuilder.Create;
  try
    if ADoc.Summary <> '' then
    begin
      LSB.AppendLine(ADoc.Summary);
      LSB.AppendLine;
    end;

    if ADoc.Remarks <> '' then
    begin
      LSB.AppendLine('## Remarks');
      LSB.AppendLine;
      LSB.AppendLine(ADoc.Remarks);
      LSB.AppendLine;
    end;

    if ADoc.Params.Count > 0 then
    begin
      LSB.AppendLine('**Parameters:**');
      LSB.AppendLine;
      for I := 0 to ADoc.Params.Count - 1 do
        LSB.AppendLine('- **' + ADoc.Params[I].Name + '** — ' + ADoc.Params[I].Description);
      LSB.AppendLine;
    end;

    if ADoc.Returns <> '' then
    begin
      LSB.AppendLine('**Returns:** ' + ADoc.Returns);
      LSB.AppendLine;
    end;

    if ADoc.Exceptions.Count > 0 then
    begin
      LSB.AppendLine('**Raises:**');
      LSB.AppendLine;
      for I := 0 to ADoc.Exceptions.Count - 1 do
      begin
        LSB.AppendLine('- `' + ADoc.Exceptions[I].TypeRef + '` — ' +
          ADoc.Exceptions[I].Description);
      end;
      LSB.AppendLine;
    end;

    if ADoc.SeeAlso.Count > 0 then
    begin
      LSB.AppendLine('**See Also:**');
      LSB.AppendLine;
      for I := 0 to ADoc.SeeAlso.Count - 1 do
        LSB.AppendLine('- ' + MakeMDLink(ADoc.SeeAlso[I].Cref, AUnitName));
      LSB.AppendLine;
    end;

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TMarkdownDocRenderer.MakeMDLink(const ACref, AUnitName: string): string;
var
  LParts: TArray<string>;
  LFile: string;
begin
  LParts := ACref.Split(['.']);
  if Length(LParts) >= 2 then
    LFile := LParts[0] + '.' + LParts[1] + '.md'
  else
    LFile := ACref + '.md';

  Result := Format('[`%s`](units/%s)', [ACref, LFile]);
end;

procedure TMarkdownDocRenderer.WriteFile(const ARelPath, AContent: string);
var
  LFullPath: string;
  LDir: string;
begin
  LFullPath := TPath.Combine(FOptions.OutputDir, ARelPath);
  LDir := ExtractFilePath(LFullPath);
  if not TDirectory.Exists(LDir) then
    TDirectory.CreateDirectory(LDir);

  TFile.WriteAllText(LFullPath, AContent, TEncoding.UTF8);
end;

procedure TMarkdownDocRenderer.RenderReadme;
var
  LSB: TStringBuilder;
  I: Integer;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('# ' + FOptions.Title);
    LSB.AppendLine;
    LSB.AppendLine('## Units');
    LSB.AppendLine;
    LSB.AppendLine('| Unit | Description |');
    LSB.AppendLine('|------|-------------|');

    for I := 0 to FUnits.Count - 1 do
    begin
      LSB.AppendFormat('| [%s](units/%s.md) | %s |',
        [FUnits[I].UnitName, FUnits[I].UnitName, FUnits[I].UnitDoc.Summary]);
      LSB.AppendLine;
    end;

    WriteFile('README.md', LSB.ToString);
  finally
    LSB.Free;
  end;
end;

procedure TMarkdownDocRenderer.RenderSummary;
var
  LSB: TStringBuilder;
  I, J: Integer;
  LUnit: TUnitDocInfo;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('# Summary');
    LSB.AppendLine;

    for I := 0 to FUnits.Count - 1 do
    begin
      LUnit := FUnits[I];
      LSB.AppendFormat('* [%s](units/%s.md)', [LUnit.UnitName, LUnit.UnitName]);
      LSB.AppendLine;

      for J := 0 to LUnit.Types.Count - 1 do
      begin
        LSB.AppendFormat('  * [%s](units/%s.%s.md)',
          [LUnit.Types[J].Name, LUnit.UnitName, LUnit.Types[J].Name]);
        LSB.AppendLine;
      end;
    end;

    WriteFile('SUMMARY.md', LSB.ToString);
  finally
    LSB.Free;
  end;
end;

procedure TMarkdownDocRenderer.RenderSidebar;
var
  LSB: TStringBuilder;
  I, J: Integer;
  LUnit: TUnitDocInfo;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('**' + FOptions.Title + '**');
    LSB.AppendLine;

    for I := 0 to FUnits.Count - 1 do
    begin
      LUnit := FUnits[I];
      LSB.AppendFormat('- [%s](units/%s)', [LUnit.UnitName, LUnit.UnitName]);
      LSB.AppendLine;

      for J := 0 to LUnit.Types.Count - 1 do
      begin
        LSB.AppendFormat('  - [%s](units/%s.%s)',
          [LUnit.Types[J].Name, LUnit.UnitName, LUnit.Types[J].Name]);
        LSB.AppendLine;
      end;
    end;

    WriteFile('_sidebar.md', LSB.ToString);
  finally
    LSB.Free;
  end;
end;

procedure TMarkdownDocRenderer.RenderUnitMD(const AUnit: TUnitDocInfo);
var
  LSB: TStringBuilder;
  I: Integer;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('# ' + AUnit.UnitName);
    LSB.AppendLine;
    LSB.Append(FormatDocToMD(AUnit.UnitDoc, AUnit.UnitName));

    // Types
    if AUnit.Types.Count > 0 then
    begin
      LSB.AppendLine('## Types');
      LSB.AppendLine;
      LSB.AppendLine('| Type | Kind | Description |');
      LSB.AppendLine('|------|------|-------------|');

      for I := 0 to AUnit.Types.Count - 1 do
      begin
        LSB.AppendFormat('| [`%s`](%s.%s.md) | %s | %s |',
          [AUnit.Types[I].Name,
           AUnit.UnitName, AUnit.Types[I].Name,
           AUnit.Types[I].Kind.ToString,
           AUnit.Types[I].Doc.Summary]);
        LSB.AppendLine;
      end;

      LSB.AppendLine;
    end;

    // Standalone methods
    if AUnit.StandaloneMethods.Count > 0 then
    begin
      LSB.AppendLine('## Functions & Procedures');
      LSB.AppendLine;
      for I := 0 to AUnit.StandaloneMethods.Count - 1 do
      begin
        LSB.AppendLine('### ' + AUnit.StandaloneMethods[I].Name);
        LSB.AppendLine;
        LSB.Append(FormatDocToMD(AUnit.StandaloneMethods[I].Doc, AUnit.UnitName));
      end;
    end;

    // Constants
    if AUnit.Constants.Count > 0 then
    begin
      LSB.AppendLine('## Constants');
      LSB.AppendLine;
      for I := 0 to AUnit.Constants.Count - 1 do
      begin
        LSB.AppendLine('### `' + AUnit.Constants[I].Name + '`');
        LSB.AppendLine;
        LSB.Append(FormatDocToMD(AUnit.Constants[I].Doc, AUnit.UnitName));
      end;
    end;

    WriteFile('units/' + AUnit.UnitName + '.md', LSB.ToString);
  finally
    LSB.Free;
  end;
end;

procedure TMarkdownDocRenderer.RenderTypeMD(const AType: TTypeDocInfo; const AUnitName: string);
var
  LSB: TStringBuilder;
  I: Integer;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendFormat('# %s `%s`', [AType.Kind.ToString, AType.Name]);
    LSB.AppendLine;
    LSB.AppendLine;

    if AType.Ancestor <> '' then
    begin
      LSB.AppendLine('Inherits from `' + AType.Ancestor + '`');
      LSB.AppendLine;
    end;

    LSB.Append(FormatDocToMD(AType.Doc, AUnitName));

    // Members
    if AType.Members.Count > 0 then
    begin
      LSB.AppendLine('## Members');
      LSB.AppendLine;
      LSB.AppendLine('| Name | Kind | Visibility | Description |');
      LSB.AppendLine('|------|------|------------|-------------|');

      for I := 0 to AType.Members.Count - 1 do
      begin
        LSB.AppendFormat('| `%s` | %s | %s | %s |',
          [AType.Members[I].Name,
           AType.Members[I].Kind.ToString,
           AType.Members[I].Visibility,
           AType.Members[I].Doc.Summary]);
        LSB.AppendLine;
      end;

      LSB.AppendLine;

      // Detailed member sections
      for I := 0 to AType.Members.Count - 1 do
      begin
        LSB.AppendLine('### ' + AType.Members[I].Name);
        LSB.AppendLine;
        LSB.Append(FormatDocToMD(AType.Members[I].Doc, AUnitName));
      end;
    end;

    WriteFile('units/' + AUnitName + '.' + AType.Name + '.md', LSB.ToString);
  finally
    LSB.Free;
  end;
end;

end.
