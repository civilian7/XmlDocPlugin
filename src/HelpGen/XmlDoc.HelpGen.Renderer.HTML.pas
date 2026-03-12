unit XmlDoc.HelpGen.Renderer.HTML;

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
  /// <summary>다중 페이지 정적 HTML 사이트를 생성합니다.</summary>
  THTMLDocRenderer = class(TInterfacedObject, IDocRenderer)
  private
    FOptions: TRenderOptions;
    FResolver: TCrossRefResolver;
    FUnits: TObjectList<TUnitDocInfo>;

    procedure CopyStaticAssets;
    function EscapeHtml(const AText: string): string;
    function FormatDocToHtml(const ADoc: TXmlDocModel; const AUnitName: string): string;
    function GenerateNav(const APrefix: string = ''): string;
    function MakeCrefLink(const ACref, AUnitName: string): string;
    procedure RenderIndex;
    procedure RenderMemberSection(const ABuilder: TStringBuilder; const AElem: TElementDocInfo; const AUnitName: string);
    procedure RenderSearchIndex;
    procedure RenderTypePage(const AType: TTypeDocInfo; const AUnitName: string);
    procedure RenderUnitPage(const AUnit: TUnitDocInfo);
    function WrapPage(const ATitle, ABody, ANav: string): string;
    procedure WriteFile(const ARelPath, AContent: string);
  public
    procedure Render(const AUnits: TObjectList<TUnitDocInfo>; const AResolver: TCrossRefResolver; const AOptions: TRenderOptions);
  end;

implementation

uses
  System.JSON;

{ THTMLDocRenderer }

procedure THTMLDocRenderer.Render(
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
  TDirectory.CreateDirectory(TPath.Combine(FOptions.OutputDir, 'assets'));

  CopyStaticAssets;
  RenderIndex;

  for I := 0 to AUnits.Count - 1 do
  begin
    RenderUnitPage(AUnits[I]);

    for J := 0 to AUnits[I].Types.Count - 1 do
      RenderTypePage(AUnits[I].Types[J], AUnits[I].UnitName);
  end;

  if FOptions.IncludeSearchIndex then
    RenderSearchIndex;
end;

procedure THTMLDocRenderer.CopyStaticAssets;
var
  LCSS: string;
begin
  LCSS :=
    ':root{--bg:#fff;--text:#212529;--accent:#0d6efd;--border:#dee2e6;' +
    '--code-bg:#f1f3f5;--font:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;' +
    '--mono:"Cascadia Code",Consolas,monospace}' +
    '*{margin:0;padding:0;box-sizing:border-box}' +
    'body{font-family:var(--font);font-size:14px;color:var(--text);line-height:1.6;display:flex}' +
    'nav{width:260px;min-height:100vh;background:#f8f9fa;border-right:1px solid var(--border);' +
    'padding:16px;overflow-y:auto;position:sticky;top:0}' +
    'nav h2{font-size:14px;margin-bottom:12px}' +
    'nav ul{list-style:none}nav li{margin:2px 0}' +
    'nav a{color:var(--text);text-decoration:none;font-size:13px}' +
    'nav a:hover{color:var(--accent)}' +
    'main{flex:1;padding:24px 32px;max-width:900px}' +
    'h1{font-size:24px;margin-bottom:8px}' +
    'h2{font-size:18px;margin:24px 0 8px;border-bottom:1px solid var(--border);padding-bottom:4px}' +
    'h3{font-size:15px;margin:16px 0 4px}' +
    'table{border-collapse:collapse;width:100%;margin:8px 0}' +
    'th,td{border:1px solid var(--border);padding:6px 10px;text-align:left;font-size:13px}' +
    'th{background:#f8f9fa;font-weight:600}' +
    'code{font-family:var(--mono);font-size:0.9em;background:var(--code-bg);padding:1px 4px;border-radius:3px}' +
    'pre{background:var(--code-bg);padding:12px;border-radius:6px;overflow-x:auto;margin:8px 0}' +
    'pre code{background:none;padding:0}' +
    '.badge{display:inline-block;padding:2px 6px;border-radius:3px;font-size:11px;font-weight:600;' +
    'background:var(--accent);color:#fff;margin-right:4px}' +
    '.member-card{margin:12px 0;padding:12px;border:1px solid var(--border);border-radius:6px}' +
    '.member-sig{font-family:var(--mono);font-size:13px;font-weight:600;margin-bottom:8px}' +
    '.param-table td:first-child{font-family:var(--mono);font-weight:600;white-space:nowrap;width:140px}' +
    '.footer{margin-top:40px;padding-top:12px;border-top:1px solid var(--border);' +
    'font-size:11px;color:#6c757d}';

  WriteFile('assets/style.css', LCSS);
end;

function THTMLDocRenderer.EscapeHtml(const AText: string): string;
begin
  Result := AText;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function THTMLDocRenderer.FormatDocToHtml(const ADoc: TXmlDocModel;
  const AUnitName: string): string;
var
  LSB: TStringBuilder;
  I: Integer;
begin
  LSB := TStringBuilder.Create;
  try
    if ADoc.Summary <> '' then
      LSB.AppendLine('<p>' + EscapeHtml(ADoc.Summary) + '</p>');

    if ADoc.Remarks <> '' then
    begin
      LSB.AppendLine('<h3>Remarks</h3>');
      LSB.AppendLine('<p>' + EscapeHtml(ADoc.Remarks) + '</p>');
    end;

    if ADoc.Params.Count > 0 then
    begin
      LSB.AppendLine('<h3>Parameters</h3>');
      LSB.AppendLine('<table class="param-table"><tr><th>Name</th><th>Description</th></tr>');
      for I := 0 to ADoc.Params.Count - 1 do
      begin
        LSB.AppendFormat('<tr><td><code>%s</code></td><td>%s</td></tr>',
          [EscapeHtml(ADoc.Params[I].Name), EscapeHtml(ADoc.Params[I].Description)]);
        LSB.AppendLine;
      end;
      LSB.AppendLine('</table>');
    end;

    if ADoc.Returns <> '' then
    begin
      LSB.AppendLine('<h3>Returns</h3>');
      LSB.AppendLine('<p>' + EscapeHtml(ADoc.Returns) + '</p>');
    end;

    if ADoc.Exceptions.Count > 0 then
    begin
      LSB.AppendLine('<h3>Exceptions</h3>');
      LSB.AppendLine('<table><tr><th>Exception</th><th>Description</th></tr>');
      for I := 0 to ADoc.Exceptions.Count - 1 do
      begin
        LSB.AppendFormat('<tr><td><code>%s</code></td><td>%s</td></tr>',
          [MakeCrefLink(ADoc.Exceptions[I].TypeRef, AUnitName),
           EscapeHtml(ADoc.Exceptions[I].Description)]);
        LSB.AppendLine;
      end;
      LSB.AppendLine('</table>');
    end;

    if ADoc.SeeAlso.Count > 0 then
    begin
      LSB.AppendLine('<h3>See Also</h3>');
      LSB.Append('<ul>');
      for I := 0 to ADoc.SeeAlso.Count - 1 do
        LSB.AppendFormat('<li>%s</li>', [MakeCrefLink(ADoc.SeeAlso[I].Cref, AUnitName)]);
      LSB.AppendLine('</ul>');
    end;

    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function THTMLDocRenderer.MakeCrefLink(const ACref, AUnitName: string): string;
var
  LParts: TArray<string>;
  LHref: string;
begin
  // FullName → 링크 생성 (Unit.Type.Member → Unit.Type.html#Member)
  LParts := ACref.Split(['.']);
  if Length(LParts) >= 2 then
    LHref := LParts[0] + '.' + LParts[1] + '.html'
  else
    LHref := '#';

  Result := Format('<a href="units/%s"><code>%s</code></a>', [LHref, EscapeHtml(ACref)]);
end;

function THTMLDocRenderer.GenerateNav(const APrefix: string): string;
var
  LSB: TStringBuilder;
  LIndexHref: string;
  I, J: Integer;
  LUnit: TUnitDocInfo;
begin
  // APrefix: units/ 폴더 내 페이지에서는 '' (기본), index.html에서는 'units/'
  if APrefix <> '' then
    LIndexHref := 'index.html'
  else
    LIndexHref := '../index.html';

  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('<h2>' + EscapeHtml(FOptions.Title) + '</h2>');
    LSB.AppendLine('<ul>');
    LSB.AppendFormat('<li><a href="%s">Index</a></li>', [LIndexHref]);
    LSB.AppendLine;

    for I := 0 to FUnits.Count - 1 do
    begin
      LUnit := FUnits[I];
      LSB.AppendFormat('<li><a href="%s%s.html">%s</a>',
        [APrefix, LUnit.UnitName, EscapeHtml(LUnit.UnitName)]);

      if LUnit.Types.Count > 0 then
      begin
        LSB.AppendLine('<ul>');
        for J := 0 to LUnit.Types.Count - 1 do
        begin
          LSB.AppendFormat('<li><a href="%s%s.%s.html">%s</a></li>',
            [APrefix, LUnit.UnitName, LUnit.Types[J].Name,
             EscapeHtml(LUnit.Types[J].Name)]);
          LSB.AppendLine;
        end;
        LSB.AppendLine('</ul>');
      end;

      LSB.AppendLine('</li>');
    end;

    LSB.AppendLine('</ul>');
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function THTMLDocRenderer.WrapPage(const ATitle, ABody, ANav: string): string;
var
  LFooter: string;
begin
  LFooter := FOptions.FooterText;
  if LFooter = '' then
    LFooter := 'Generated by XmlDoc Plugin';

  Result :=
    '<!DOCTYPE html><html lang="ko"><head>' +
    '<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>' + EscapeHtml(ATitle) + '</title>' +
    '<link rel="stylesheet" href="../assets/style.css">' +
    '</head><body>' +
    '<nav>' + ANav + '</nav>' +
    '<main>' + ABody + '</main>' +
    '<footer class="footer">' + EscapeHtml(LFooter) + '</footer>' +
    '</body></html>';
end;

procedure THTMLDocRenderer.WriteFile(const ARelPath, AContent: string);
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

procedure THTMLDocRenderer.RenderIndex;
var
  LSB: TStringBuilder;
  I: Integer;
  LUnit: TUnitDocInfo;
  LNav: string;
begin
  LNav := GenerateNav;
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('<h1>' + EscapeHtml(FOptions.Title) + '</h1>');
    LSB.AppendLine('<h2>Units</h2>');
    LSB.AppendLine('<table><tr><th>Unit</th><th>Description</th></tr>');

    for I := 0 to FUnits.Count - 1 do
    begin
      LUnit := FUnits[I];
      LSB.AppendFormat('<tr><td><a href="units/%s.html">%s</a></td><td>%s</td></tr>',
        [LUnit.UnitName, EscapeHtml(LUnit.UnitName),
         EscapeHtml(LUnit.UnitDoc.Summary)]);
      LSB.AppendLine;
    end;

    LSB.AppendLine('</table>');
    WriteFile('index.html',
      StringReplace(WrapPage(FOptions.Title, LSB.ToString,
        GenerateNav('units/')),
        '../assets/', 'assets/', [rfReplaceAll]));
  finally
    LSB.Free;
  end;
end;

procedure THTMLDocRenderer.RenderUnitPage(const AUnit: TUnitDocInfo);
var
  LSB: TStringBuilder;
  I: Integer;
  LNav: string;
begin
  LNav := GenerateNav;
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('<h1>' + EscapeHtml(AUnit.UnitName) + '</h1>');
    LSB.Append(FormatDocToHtml(AUnit.UnitDoc, AUnit.UnitName));

    // Types
    if AUnit.Types.Count > 0 then
    begin
      LSB.AppendLine('<h2>Types</h2>');
      LSB.AppendLine('<table><tr><th>Type</th><th>Kind</th><th>Description</th></tr>');
      for I := 0 to AUnit.Types.Count - 1 do
      begin
        LSB.AppendFormat('<tr><td><a href="%s.%s.html">%s</a></td><td>%s</td><td>%s</td></tr>',
          [AUnit.UnitName, AUnit.Types[I].Name,
           EscapeHtml(AUnit.Types[I].Name),
           EscapeHtml(AUnit.Types[I].Kind.ToString),
           EscapeHtml(AUnit.Types[I].Doc.Summary)]);
        LSB.AppendLine;
      end;
      LSB.AppendLine('</table>');
    end;

    // Standalone methods
    if AUnit.StandaloneMethods.Count > 0 then
    begin
      LSB.AppendLine('<h2>Functions &amp; Procedures</h2>');
      for I := 0 to AUnit.StandaloneMethods.Count - 1 do
        RenderMemberSection(LSB, AUnit.StandaloneMethods[I], AUnit.UnitName);
    end;

    // Constants
    if AUnit.Constants.Count > 0 then
    begin
      LSB.AppendLine('<h2>Constants</h2>');
      for I := 0 to AUnit.Constants.Count - 1 do
        RenderMemberSection(LSB, AUnit.Constants[I], AUnit.UnitName);
    end;

    WriteFile('units/' + AUnit.UnitName + '.html',
      WrapPage(AUnit.UnitName, LSB.ToString, LNav));
  finally
    LSB.Free;
  end;
end;

procedure THTMLDocRenderer.RenderTypePage(const AType: TTypeDocInfo;
  const AUnitName: string);
var
  LSB: TStringBuilder;
  I: Integer;
  LNav: string;
begin
  LNav := GenerateNav;
  LSB := TStringBuilder.Create;
  try
    LSB.AppendFormat('<h1><span class="badge">%s</span> %s</h1>',
      [EscapeHtml(AType.Kind.ToString), EscapeHtml(AType.Name)]);
    LSB.AppendLine;

    if AType.Ancestor <> '' then
      LSB.AppendLine('<p>Inherits from <code>' + EscapeHtml(AType.Ancestor) + '</code></p>');

    LSB.Append(FormatDocToHtml(AType.Doc, AUnitName));

    // Members
    if AType.Members.Count > 0 then
    begin
      LSB.AppendLine('<h2>Members</h2>');

      // Members table
      LSB.AppendLine('<table><tr><th>Name</th><th>Kind</th><th>Visibility</th><th>Description</th></tr>');
      for I := 0 to AType.Members.Count - 1 do
      begin
        LSB.AppendFormat('<tr><td><a href="#%s"><code>%s</code></a></td><td>%s</td><td>%s</td><td>%s</td></tr>',
          [EscapeHtml(AType.Members[I].Name),
           EscapeHtml(AType.Members[I].Name),
           EscapeHtml(AType.Members[I].Kind.ToString),
           EscapeHtml(AType.Members[I].Visibility),
           EscapeHtml(AType.Members[I].Doc.Summary)]);
        LSB.AppendLine;
      end;
      LSB.AppendLine('</table>');

      // Detailed member sections
      for I := 0 to AType.Members.Count - 1 do
        RenderMemberSection(LSB, AType.Members[I], AUnitName);
    end;

    WriteFile('units/' + AUnitName + '.' + AType.Name + '.html',
      WrapPage(AType.FullName, LSB.ToString, LNav));
  finally
    LSB.Free;
  end;
end;

procedure THTMLDocRenderer.RenderMemberSection(const ABuilder: TStringBuilder;
  const AElem: TElementDocInfo; const AUnitName: string);
begin
  ABuilder.AppendFormat('<div class="member-card" id="%s">',
    [EscapeHtml(AElem.Name)]);
  ABuilder.AppendLine;
  ABuilder.AppendFormat('<div class="member-sig"><span class="badge">%s</span> %s</div>',
    [EscapeHtml(AElem.Kind.ToString), EscapeHtml(AElem.Name)]);
  ABuilder.AppendLine;
  ABuilder.Append(FormatDocToHtml(AElem.Doc, AUnitName));
  ABuilder.AppendLine('</div>');
end;

procedure THTMLDocRenderer.RenderSearchIndex;
var
  LArr: TJSONArray;
  LObj: TJSONObject;
  I, J: Integer;
  LUnit: TUnitDocInfo;
begin
  LArr := TJSONArray.Create;
  try
    for I := 0 to FUnits.Count - 1 do
    begin
      LUnit := FUnits[I];

      LObj := TJSONObject.Create;
      LObj.AddPair('name', LUnit.UnitName);
      LObj.AddPair('type', 'unit');
      LObj.AddPair('url', 'units/' + LUnit.UnitName + '.html');
      LObj.AddPair('summary', LUnit.UnitDoc.Summary);
      LArr.AddElement(LObj);

      for J := 0 to LUnit.Types.Count - 1 do
      begin
        LObj := TJSONObject.Create;
        LObj.AddPair('name', LUnit.Types[J].FullName);
        LObj.AddPair('type', LUnit.Types[J].Kind.ToString);
        LObj.AddPair('url', 'units/' + LUnit.UnitName + '.' + LUnit.Types[J].Name + '.html');
        LObj.AddPair('summary', LUnit.Types[J].Doc.Summary);
        LArr.AddElement(LObj);
      end;
    end;

    WriteFile('assets/search-index.json', LArr.ToJSON);
  finally
    LArr.Free;
  end;
end;

end.
