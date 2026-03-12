unit XmlDoc.HelpGen.Coverage;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.HelpGen.Types;

type
  /// <summary>문서화 수준</summary>
  TCoverageLevel = (
    clNone,
    clSummaryOnly,
    clPartial,
    clComplete
  );

  /// <summary>개별 요소 커버리지 정보</summary>
  TCoverageItem = record
    ElementFullName: string;
    Kind: TDocElementKind;
    Level: TCoverageLevel;
    MissingTags: TArray<string>;
    Visibility: string;
  end;

  /// <summary>커버리지 통계</summary>
  TCoverageStats = record
    ByKind: TDictionary<TDocElementKind, Integer>;
    ByUnit: TDictionary<string, Double>;
    ByVisibility: TDictionary<string, Integer>;
    Complete: Integer;
    CompletePercent: Double;
    CoveragePercent: Double;
    Documented: Integer;
    TotalElements: Integer;
  end;

  /// <summary>프로젝트 전체의 XML 문서 커버리지를 분석하고 리포트를 생성합니다.</summary>
  TDocCoverageReport = class
  private
    function AnalyzeElement(const AElem: TElementDocInfo): TCoverageItem;
    function AnalyzeType(const AType: TTypeDocInfo): TCoverageItem;
    function CoverageLevelToString(ALevel: TCoverageLevel): string;
  public
    /// <summary>유닛 목록의 문서 커버리지를 분석합니다.</summary>
    /// <param name="AUnits">분석 대상 유닛 목록</param>
    /// <returns>커버리지 통계</returns>
    function Analyze(const AUnits: TObjectList<TUnitDocInfo>): TCoverageStats;

    /// <summary>문서화되지 않은 요소 목록을 반환합니다.</summary>
    /// <param name="AUnits">대상 유닛 목록</param>
    /// <param name="AMinVisibility">최소 가시성 필터 (기본: public)</param>
    /// <returns>미문서화 요소 배열</returns>
    function GetUndocumented(const AUnits: TObjectList<TUnitDocInfo>; const AMinVisibility: string = 'public'): TArray<TCoverageItem>;

    /// <summary>콘솔 리포트를 출력합니다.</summary>
    /// <param name="AStats">커버리지 통계</param>
    procedure RenderConsoleReport(const AStats: TCoverageStats);

    /// <summary>HTML 리포트를 생성합니다.</summary>
    /// <param name="AStats">커버리지 통계</param>
    /// <param name="AItems">커버리지 항목 배열</param>
    /// <param name="AOutputPath">출력 파일 경로</param>
    procedure RenderHTMLReport(const AStats: TCoverageStats; const AItems: TArray<TCoverageItem>; const AOutputPath: string);
  end;

implementation

function HasParamDoc(const ADoc: TXmlDocModel; const AParamName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to ADoc.Params.Count - 1 do
  begin
    if SameText(ADoc.Params[I].Name, AParamName) then
    begin
      Result := ADoc.Params[I].Description <> '';
      Exit;
    end;
  end;
end;

{ TDocCoverageReport }

function TDocCoverageReport.AnalyzeElement(const AElem: TElementDocInfo): TCoverageItem;
var
  LMissing: TList<string>;
  I: Integer;
begin
  Result.ElementFullName := AElem.FullName;
  Result.Kind := AElem.Kind;
  Result.Visibility := AElem.Visibility;

  if AElem.Doc.IsEmpty then
  begin
    Result.Level := clNone;
    Result.MissingTags := ['summary'];
    Exit;
  end;

  LMissing := TList<string>.Create;
  try
    if AElem.Doc.Summary = '' then
      LMissing.Add('summary');

    // 메서드: 파라미터와 리턴값 체크
    if AElem.Kind = dekMethod then
    begin
      for I := 0 to Length(AElem.CodeElement.Params) - 1 do
      begin
        if not HasParamDoc(AElem.Doc, AElem.CodeElement.Params[I].Name) then
          LMissing.Add('param:' + AElem.CodeElement.Params[I].Name);
      end;

      if (AElem.CodeElement.ReturnType <> '') and (AElem.Doc.Returns = '') then
        LMissing.Add('returns');
    end;

    Result.MissingTags := LMissing.ToArray;

    if LMissing.Count = 0 then
      Result.Level := clComplete
    else
    if AElem.Doc.Summary <> '' then
      Result.Level := clPartial
    else
      Result.Level := clSummaryOnly;
  finally
    LMissing.Free;
  end;
end;

function TDocCoverageReport.AnalyzeType(const AType: TTypeDocInfo): TCoverageItem;
begin
  Result.ElementFullName := AType.FullName;
  Result.Kind := AType.Kind;
  Result.Visibility := AType.Visibility;

  if AType.Doc.IsEmpty then
  begin
    Result.Level := clNone;
    Result.MissingTags := ['summary'];
    Exit;
  end;

  if AType.Doc.Summary <> '' then
    Result.Level := clComplete
  else
  begin
    Result.Level := clSummaryOnly;
    Result.MissingTags := ['summary'];
  end;
end;

function TDocCoverageReport.CoverageLevelToString(ALevel: TCoverageLevel): string;
begin
  case ALevel of
    clNone:        Result := 'None';
    clSummaryOnly: Result := 'Summary Only';
    clPartial:     Result := 'Partial';
    clComplete:    Result := 'Complete';
  else
    Result := 'Unknown';
  end;
end;

function TDocCoverageReport.Analyze(const AUnits: TObjectList<TUnitDocInfo>): TCoverageStats;
var
  I, J, K: Integer;
  LUnit: TUnitDocInfo;
  LType: TTypeDocInfo;
  LElem: TElementDocInfo;
  LItem: TCoverageItem;
  LUnitTotal: Integer;
  LUnitDoc: Integer;
begin
  Result.TotalElements := 0;
  Result.Documented := 0;
  Result.Complete := 0;
  Result.ByKind := TDictionary<TDocElementKind, Integer>.Create;
  Result.ByVisibility := TDictionary<string, Integer>.Create;
  Result.ByUnit := TDictionary<string, Double>.Create;

  for I := 0 to AUnits.Count - 1 do
  begin
    LUnit := AUnits[I];
    LUnitTotal := 0;
    LUnitDoc := 0;

    // Types
    for J := 0 to LUnit.Types.Count - 1 do
    begin
      LType := LUnit.Types[J];
      LItem := AnalyzeType(LType);
      Inc(Result.TotalElements);
      Inc(LUnitTotal);
      if LItem.Level <> clNone then
      begin
        Inc(Result.Documented);
        Inc(LUnitDoc);
      end;

      if LItem.Level = clComplete then
        Inc(Result.Complete);

      // Members
      for K := 0 to LType.Members.Count - 1 do
      begin
        LElem := LType.Members[K];
        LItem := AnalyzeElement(LElem);
        Inc(Result.TotalElements);
        Inc(LUnitTotal);
        if LItem.Level <> clNone then
        begin
          Inc(Result.Documented);
          Inc(LUnitDoc);
        end;

        if LItem.Level = clComplete then
          Inc(Result.Complete);
      end;
    end;

    // Standalone methods
    for J := 0 to LUnit.StandaloneMethods.Count - 1 do
    begin
      LElem := LUnit.StandaloneMethods[J];
      LItem := AnalyzeElement(LElem);
      Inc(Result.TotalElements);
      Inc(LUnitTotal);
      if LItem.Level <> clNone then
      begin
        Inc(Result.Documented);
        Inc(LUnitDoc);
      end;

      if LItem.Level = clComplete then
        Inc(Result.Complete);
    end;

    // Constants
    for J := 0 to LUnit.Constants.Count - 1 do
    begin
      LElem := LUnit.Constants[J];
      LItem := AnalyzeElement(LElem);
      Inc(Result.TotalElements);
      Inc(LUnitTotal);
      if LItem.Level <> clNone then
      begin
        Inc(Result.Documented);
        Inc(LUnitDoc);
      end;

      if LItem.Level = clComplete then
        Inc(Result.Complete);
    end;

    if LUnitTotal > 0 then
      Result.ByUnit.AddOrSetValue(LUnit.UnitName, (LUnitDoc / LUnitTotal) * 100)
    else
      Result.ByUnit.AddOrSetValue(LUnit.UnitName, 0);
  end;

  if Result.TotalElements > 0 then
  begin
    Result.CoveragePercent := (Result.Documented / Result.TotalElements) * 100;
    Result.CompletePercent := (Result.Complete / Result.TotalElements) * 100;
  end
  else
  begin
    Result.CoveragePercent := 0;
    Result.CompletePercent := 0;
  end;
end;

function TDocCoverageReport.GetUndocumented(const AUnits: TObjectList<TUnitDocInfo>; const AMinVisibility: string): TArray<TCoverageItem>;
var
  LResults: TList<TCoverageItem>;
  I, J, K: Integer;
  LUnit: TUnitDocInfo;
  LType: TTypeDocInfo;
  LItem: TCoverageItem;

  function PassesVisibility(const AVis: string): Boolean;
  begin
    if AMinVisibility = '' then
    begin
      Result := True;
      Exit;
    end;

    if SameText(AMinVisibility, 'public') then
      Result := SameText(AVis, 'public') or SameText(AVis, 'published') or (AVis = '')
    else
    if SameText(AMinVisibility, 'protected') then
      Result := SameText(AVis, 'public') or SameText(AVis, 'published') or
                SameText(AVis, 'protected') or (AVis = '')
    else
      Result := True;
  end;

begin
  LResults := TList<TCoverageItem>.Create;
  try
    for I := 0 to AUnits.Count - 1 do
    begin
      LUnit := AUnits[I];

      for J := 0 to LUnit.Types.Count - 1 do
      begin
        LType := LUnit.Types[J];
        LItem := AnalyzeType(LType);
        if (LItem.Level = clNone) and PassesVisibility(LItem.Visibility) then
          LResults.Add(LItem);

        for K := 0 to LType.Members.Count - 1 do
        begin
          LItem := AnalyzeElement(LType.Members[K]);
          if (LItem.Level = clNone) and PassesVisibility(LItem.Visibility) then
            LResults.Add(LItem);
        end;
      end;

      for J := 0 to LUnit.StandaloneMethods.Count - 1 do
      begin
        LItem := AnalyzeElement(LUnit.StandaloneMethods[J]);
        if (LItem.Level = clNone) and PassesVisibility(LItem.Visibility) then
          LResults.Add(LItem);
      end;
    end;

    Result := LResults.ToArray;
  finally
    LResults.Free;
  end;
end;

procedure TDocCoverageReport.RenderConsoleReport(const AStats: TCoverageStats);
begin
  WriteLn('=== Documentation Coverage Report ===');
  WriteLn(Format('Total elements: %d', [AStats.TotalElements]));
  WriteLn(Format('Documented:     %d (%.1f%%)', [AStats.Documented, AStats.CoveragePercent]));
  WriteLn(Format('Complete:       %d (%.1f%%)', [AStats.Complete, AStats.CompletePercent]));
  WriteLn;
end;

procedure TDocCoverageReport.RenderHTMLReport(
  const AStats: TCoverageStats;
  const AItems: TArray<TCoverageItem>;
  const AOutputPath: string);
var
  LSB: TStringBuilder;
  I: Integer;
  LItem: TCoverageItem;
  LBarColor: string;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('<!DOCTYPE html><html lang="ko"><head>');
    LSB.AppendLine('<meta charset="UTF-8"><title>Documentation Coverage Report</title>');
    LSB.AppendLine('<style>');
    LSB.AppendLine('body{font-family:-apple-system,sans-serif;max-width:900px;margin:40px auto;padding:0 20px}');
    LSB.AppendLine('h1{margin-bottom:20px}');
    LSB.AppendLine('.stat{display:inline-block;margin:0 20px 20px 0;padding:16px;border:1px solid #dee2e6;border-radius:8px;text-align:center}');
    LSB.AppendLine('.stat-val{font-size:32px;font-weight:700;color:#0d6efd}');
    LSB.AppendLine('.stat-label{font-size:12px;color:#6c757d;margin-top:4px}');
    LSB.AppendLine('.bar{width:100%;height:24px;background:#e9ecef;border-radius:4px;margin:16px 0;overflow:hidden}');
    LSB.AppendLine('.bar-fill{height:100%;border-radius:4px;transition:width 0.3s}');
    LSB.AppendLine('table{border-collapse:collapse;width:100%;margin:16px 0}');
    LSB.AppendLine('th,td{border:1px solid #dee2e6;padding:6px 10px;text-align:left;font-size:13px}');
    LSB.AppendLine('th{background:#f8f9fa}.none{color:#dc3545}.partial{color:#ffc107}.complete{color:#198754}');
    LSB.AppendLine('</style></head><body>');

    LSB.AppendLine('<h1>Documentation Coverage Report</h1>');

    // Stats cards
    LSB.AppendLine('<div>');
    LSB.AppendFormat('<div class="stat"><div class="stat-val">%d</div><div class="stat-label">Total</div></div>',
      [AStats.TotalElements]);
    LSB.AppendFormat('<div class="stat"><div class="stat-val">%.1f%%</div><div class="stat-label">Documented</div></div>',
      [AStats.CoveragePercent]);
    LSB.AppendFormat('<div class="stat"><div class="stat-val">%.1f%%</div><div class="stat-label">Complete</div></div>',
      [AStats.CompletePercent]);
    LSB.AppendLine('</div>');

    // Progress bar
    if AStats.CoveragePercent >= 80 then
      LBarColor := '#198754'
    else
    if AStats.CoveragePercent >= 50 then
      LBarColor := '#ffc107'
    else
      LBarColor := '#dc3545';

    LSB.AppendFormat('<div class="bar"><div class="bar-fill" style="width:%.1f%%;background:%s"></div></div>',
      [AStats.CoveragePercent, LBarColor]);

    // Undocumented items table
    if Length(AItems) > 0 then
    begin
      LSB.AppendLine('<h2>Undocumented Elements</h2>');
      LSB.AppendLine('<table><tr><th>Element</th><th>Kind</th><th>Level</th><th>Missing</th></tr>');

      for I := 0 to Length(AItems) - 1 do
      begin
        LItem := AItems[I];
        LSB.AppendFormat('<tr><td><code>%s</code></td><td>%s</td><td class="%s">%s</td><td>%s</td></tr>',
          [LItem.ElementFullName,
           LItem.Kind.ToString,
           LowerCase(CoverageLevelToString(LItem.Level)),
           CoverageLevelToString(LItem.Level),
           string.Join(', ', LItem.MissingTags)]);
        LSB.AppendLine;
      end;

      LSB.AppendLine('</table>');
    end;

    LSB.AppendLine('</body></html>');

    TFile.WriteAllText(AOutputPath, LSB.ToString, TEncoding.UTF8);
  finally
    LSB.Free;
  end;
end;

end.
