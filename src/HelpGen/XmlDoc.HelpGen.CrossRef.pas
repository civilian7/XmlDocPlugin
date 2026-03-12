unit XmlDoc.HelpGen.CrossRef;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.HelpGen.Types;

type
  /// <summary>미해결 참조 정보</summary>
  TUnresolvedRef = record
    Cref: string;
    SourceElement: string;
    SourceFile: string;
    Line: Integer;
  end;

  /// <summary>see/seealso/exception cref 속성을 실제 심볼 위치로 해석합니다.</summary>
  TCrossRefResolver = class
  private
    FSymbolIndex: TDictionary<string, TElementDocInfo>;
    FUnresolved: TList<TUnresolvedRef>;

    function TryResolve(const ACref, AContextUnit: string): string;
  public
    constructor Create(ASymbolIndex: TDictionary<string, TElementDocInfo>);
    destructor Destroy; override;

    /// <summary>cref 문자열을 심볼 풀네임으로 해석합니다.</summary>
    /// <param name="ACref">원본 cref 값</param>
    /// <param name="AContext">참조가 포함된 요소</param>
    /// <returns>해석된 풀네임. 실패 시 원본 cref</returns>
    function ResolveCref(const ACref: string; const AContext: TElementDocInfo): string;

    /// <summary>모든 유닛의 문서 모델에서 cref 참조를 일괄 해석합니다.</summary>
    /// <param name="AUnits">대상 유닛 목록</param>
    procedure ResolveAllRefs(const AUnits: TObjectList<TUnitDocInfo>);

    property Unresolved: TList<TUnresolvedRef> read FUnresolved;
  end;

implementation

{ TCrossRefResolver }

constructor TCrossRefResolver.Create(ASymbolIndex: TDictionary<string, TElementDocInfo>);
begin
  inherited Create;

  FSymbolIndex := ASymbolIndex;
  FUnresolved := TList<TUnresolvedRef>.Create;
end;

destructor TCrossRefResolver.Destroy;
begin
  FUnresolved.Free;

  inherited;
end;

function TCrossRefResolver.TryResolve(const ACref, AContextUnit: string): string;
var
  LKey: string;
  LPair: TPair<string, TElementDocInfo>;
begin
  Result := '';

  // 1. 정확한 매치
  if FSymbolIndex.ContainsKey(ACref) then
  begin
    Result := ACref;
    Exit;
  end;

  // 2. 같은 유닛 내 검색
  LKey := AContextUnit + '.' + ACref;
  if FSymbolIndex.ContainsKey(LKey) then
  begin
    Result := LKey;
    Exit;
  end;

  // 3. 부분 매치 (*.ACref)
  for LPair in FSymbolIndex do
  begin
    if LPair.Key.EndsWith('.' + ACref) then
    begin
      Result := LPair.Key;
      Exit;
    end;
  end;
end;

function TCrossRefResolver.ResolveCref(const ACref: string; const AContext: TElementDocInfo): string;
var
  LContextUnit: string;
  LDotPos: Integer;
begin
  if ACref = '' then
  begin
    Result := '';
    Exit;
  end;

  // 컨텍스트에서 유닛 이름 추출
  LContextUnit := '';
  if Assigned(AContext) and (AContext.FullName <> '') then
  begin
    LDotPos := Pos('.', AContext.FullName);
    if LDotPos > 0 then
      LContextUnit := Copy(AContext.FullName, 1, LDotPos - 1);
  end;

  Result := TryResolve(ACref, LContextUnit);
  if Result = '' then
    Result := ACref;  // 해석 실패 시 원본 반환
end;

procedure TCrossRefResolver.ResolveAllRefs(const AUnits: TObjectList<TUnitDocInfo>);

  procedure ResolveModelRefs(const ADoc: TXmlDocModel; const AElem: TElementDocInfo; const AUnitName, AFilePath: string);
  var
    I: Integer;
    LResolved: string;
    LRef: TUnresolvedRef;
    LSeeAlso: TSeeAlsoDoc;
    LException: TExceptionDoc;
  begin
    // SeeAlso cref 해석
    for I := 0 to ADoc.SeeAlso.Count - 1 do
    begin
      LSeeAlso := ADoc.SeeAlso[I];
      LResolved := TryResolve(LSeeAlso.Cref, AUnitName);
      if LResolved <> '' then
      begin
        LSeeAlso.Cref := LResolved;
        ADoc.SeeAlso[I] := LSeeAlso;
      end
      else
      begin
        LRef.Cref := LSeeAlso.Cref;
        LRef.SourceElement := AElem.FullName;
        LRef.SourceFile := AFilePath;
        LRef.Line := 0;
        FUnresolved.Add(LRef);
      end;
    end;

    // Exception cref 해석
    for I := 0 to ADoc.Exceptions.Count - 1 do
    begin
      LException := ADoc.Exceptions[I];
      LResolved := TryResolve(LException.TypeRef, AUnitName);
      if LResolved <> '' then
      begin
        LException.TypeRef := LResolved;
        ADoc.Exceptions[I] := LException;
      end;
    end;
  end;

  procedure ResolveTypeRefs(const AType: TTypeDocInfo; const AUnitName, AFilePath: string);
  var
    I: Integer;
    LDummy: TElementDocInfo;
  begin
    LDummy := TElementDocInfo.Create;
    try
      LDummy.FullName := AType.FullName;
      ResolveModelRefs(AType.Doc, LDummy, AUnitName, AFilePath);
    finally
      LDummy.Free;
    end;

    for I := 0 to AType.Members.Count - 1 do
      ResolveModelRefs(AType.Members[I].Doc, AType.Members[I], AUnitName, AFilePath);
  end;

var
  I, J: Integer;
  LUnit: TUnitDocInfo;
begin
  FUnresolved.Clear;

  for I := 0 to AUnits.Count - 1 do
  begin
    LUnit := AUnits[I];

    for J := 0 to LUnit.Types.Count - 1 do
      ResolveTypeRefs(LUnit.Types[J], LUnit.UnitName, LUnit.FilePath);

    for J := 0 to LUnit.StandaloneMethods.Count - 1 do
      ResolveModelRefs(LUnit.StandaloneMethods[J].Doc,
        LUnit.StandaloneMethods[J], LUnit.UnitName, LUnit.FilePath);

    for J := 0 to LUnit.Constants.Count - 1 do
      ResolveModelRefs(LUnit.Constants[J].Doc,
        LUnit.Constants[J], LUnit.UnitName, LUnit.FilePath);
  end;
end;

end.
