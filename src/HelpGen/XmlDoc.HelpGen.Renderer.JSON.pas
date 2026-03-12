unit XmlDoc.HelpGen.Renderer.JSON;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Generics.Collections,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.CrossRef,
  XmlDoc.HelpGen.Renderer;

type
  /// <summary>기계 판독용 JSON 스키마를 생성합니다.</summary>
  TJSONDocRenderer = class(TInterfacedObject, IDocRenderer)
  private
    function DocModelToJson(const ADoc: TXmlDocModel): TJSONObject;
    function ElementToJson(const AElem: TElementDocInfo): TJSONObject;
    function TypeToJson(const AType: TTypeDocInfo): TJSONObject;
    function UnitToJson(const AUnit: TUnitDocInfo): TJSONObject;

  public
    procedure Render(
      const AUnits: TObjectList<TUnitDocInfo>;
      const AResolver: TCrossRefResolver;
      const AOptions: TRenderOptions
    );
  end;

implementation

{ TJSONDocRenderer }

procedure TJSONDocRenderer.Render(
  const AUnits: TObjectList<TUnitDocInfo>;
  const AResolver: TCrossRefResolver;
  const AOptions: TRenderOptions);
var
  LRoot: TJSONObject;
  LUnitsArr: TJSONArray;
  I: Integer;
  LOutputPath: string;
begin
  TDirectory.CreateDirectory(AOptions.OutputDir);

  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('project', AOptions.Title);
    LRoot.AddPair('generated', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now));
    LRoot.AddPair('generator', 'XmlDoc Plugin');

    LUnitsArr := TJSONArray.Create;
    for I := 0 to AUnits.Count - 1 do
      LUnitsArr.AddElement(UnitToJson(AUnits[I]));

    LRoot.AddPair('units', LUnitsArr);

    LOutputPath := TPath.Combine(AOptions.OutputDir, 'api.json');
    TFile.WriteAllText(LOutputPath, LRoot.Format(2), TEncoding.UTF8);
  finally
    LRoot.Free;
  end;
end;

function TJSONDocRenderer.DocModelToJson(const ADoc: TXmlDocModel): TJSONObject;
var
  I: Integer;
  LParams: TJSONArray;
  LParam: TJSONObject;
  LExceptions: TJSONArray;
  LExc: TJSONObject;
  LSeeAlso: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('summary', ADoc.Summary);

  if ADoc.Remarks <> '' then
    Result.AddPair('remarks', ADoc.Remarks);

  if ADoc.Returns <> '' then
    Result.AddPair('returns', ADoc.Returns);

  if ADoc.Params.Count > 0 then
  begin
    LParams := TJSONArray.Create;
    for I := 0 to ADoc.Params.Count - 1 do
    begin
      LParam := TJSONObject.Create;
      LParam.AddPair('name', ADoc.Params[I].Name);
      LParam.AddPair('description', ADoc.Params[I].Description);
      LParams.AddElement(LParam);
    end;
    Result.AddPair('params', LParams);
  end;

  if ADoc.Exceptions.Count > 0 then
  begin
    LExceptions := TJSONArray.Create;
    for I := 0 to ADoc.Exceptions.Count - 1 do
    begin
      LExc := TJSONObject.Create;
      LExc.AddPair('typeRef', ADoc.Exceptions[I].TypeRef);
      LExc.AddPair('description', ADoc.Exceptions[I].Description);
      LExceptions.AddElement(LExc);
    end;
    Result.AddPair('exceptions', LExceptions);
  end;

  if ADoc.SeeAlso.Count > 0 then
  begin
    LSeeAlso := TJSONArray.Create;
    for I := 0 to ADoc.SeeAlso.Count - 1 do
      LSeeAlso.Add(ADoc.SeeAlso[I].Cref);
    Result.AddPair('seeAlso', LSeeAlso);
  end;
end;

function TJSONDocRenderer.ElementToJson(const AElem: TElementDocInfo): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', AElem.Name);
  Result.AddPair('fullName', AElem.FullName);
  Result.AddPair('kind', AElem.Kind.ToString);
  Result.AddPair('visibility', AElem.Visibility);
  if AElem.Signature <> '' then
    Result.AddPair('signature', AElem.Signature);
  Result.AddPair('doc', DocModelToJson(AElem.Doc));
end;

function TJSONDocRenderer.TypeToJson(const AType: TTypeDocInfo): TJSONObject;
var
  LMembers: TJSONArray;
  I: Integer;
  LImpl: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', AType.Name);
  Result.AddPair('fullName', AType.FullName);
  Result.AddPair('kind', AType.Kind.ToString);

  if AType.Ancestor <> '' then
    Result.AddPair('ancestor', AType.Ancestor);

  if Length(AType.Implements) > 0 then
  begin
    LImpl := TJSONArray.Create;
    for I := 0 to Length(AType.Implements) - 1 do
      LImpl.Add(AType.Implements[I]);
    Result.AddPair('implements', LImpl);
  end;

  Result.AddPair('doc', DocModelToJson(AType.Doc));

  LMembers := TJSONArray.Create;
  for I := 0 to AType.Members.Count - 1 do
    LMembers.AddElement(ElementToJson(AType.Members[I]));
  Result.AddPair('members', LMembers);
end;

function TJSONDocRenderer.UnitToJson(const AUnit: TUnitDocInfo): TJSONObject;
var
  LTypes: TJSONArray;
  LMethods: TJSONArray;
  LConsts: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', AUnit.UnitName);
  Result.AddPair('path', AUnit.FilePath);
  Result.AddPair('doc', DocModelToJson(AUnit.UnitDoc));

  LTypes := TJSONArray.Create;
  for I := 0 to AUnit.Types.Count - 1 do
    LTypes.AddElement(TypeToJson(AUnit.Types[I]));
  Result.AddPair('types', LTypes);

  if AUnit.StandaloneMethods.Count > 0 then
  begin
    LMethods := TJSONArray.Create;
    for I := 0 to AUnit.StandaloneMethods.Count - 1 do
      LMethods.AddElement(ElementToJson(AUnit.StandaloneMethods[I]));
    Result.AddPair('methods', LMethods);
  end;

  if AUnit.Constants.Count > 0 then
  begin
    LConsts := TJSONArray.Create;
    for I := 0 to AUnit.Constants.Count - 1 do
      LConsts.AddElement(ElementToJson(AUnit.Constants[I]));
    Result.AddPair('constants', LConsts);
  end;
end;

end.
