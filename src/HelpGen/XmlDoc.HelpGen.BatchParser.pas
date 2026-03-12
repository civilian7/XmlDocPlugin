unit XmlDoc.HelpGen.BatchParser;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.Parser,
  XmlDoc.HelpGen.Types;

type
  /// <summary>다수의 .pas 파일을 배치 파싱하여 유닛/타입/멤버 문서 계층을 구축합니다.</summary>
  TBatchParser = class
  private
    FSymbolIndex: TDictionary<string, TElementDocInfo>;
    FUnits: TObjectList<TUnitDocInfo>;

    FOnProgress: TProgressCallback;

    procedure BuildSymbolIndex;
    procedure ParseUnit(const AFilePath: string);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>파일 목록을 모두 파싱합니다.</summary>
    /// <param name="AFiles">절대 경로 .pas 파일 배열</param>
    procedure ParseAll(const AFiles: TArray<string>);

    property SymbolIndex: TDictionary<string, TElementDocInfo> read FSymbolIndex;
    property Units: TObjectList<TUnitDocInfo> read FUnits;

    property OnProgress: TProgressCallback read FOnProgress write FOnProgress;
  end;

implementation

uses
  System.IOUtils;

{ TBatchParser }

constructor TBatchParser.Create;
begin
  inherited Create;

  FUnits := TObjectList<TUnitDocInfo>.Create(True);
  FSymbolIndex := TDictionary<string, TElementDocInfo>.Create;
end;

destructor TBatchParser.Destroy;
begin
  FSymbolIndex.Free;
  FUnits.Free;

  inherited;
end;

procedure TBatchParser.BuildSymbolIndex;
var
  LUnit: TUnitDocInfo;
  LType: TTypeDocInfo;
  LElem: TElementDocInfo;
  I, J, K: Integer;
begin
  FSymbolIndex.Clear;

  for I := 0 to FUnits.Count - 1 do
  begin
    LUnit := FUnits[I];

    for J := 0 to LUnit.StandaloneMethods.Count - 1 do
    begin
      LElem := LUnit.StandaloneMethods[J];
      if LElem.FullName <> '' then
        FSymbolIndex.AddOrSetValue(LElem.FullName, LElem);
    end;

    for J := 0 to LUnit.Constants.Count - 1 do
    begin
      LElem := LUnit.Constants[J];
      if LElem.FullName <> '' then
        FSymbolIndex.AddOrSetValue(LElem.FullName, LElem);
    end;

    for J := 0 to LUnit.Types.Count - 1 do
    begin
      LType := LUnit.Types[J];

      for K := 0 to LType.Members.Count - 1 do
      begin
        LElem := LType.Members[K];
        if LElem.FullName <> '' then
          FSymbolIndex.AddOrSetValue(LElem.FullName, LElem);
      end;
    end;
  end;
end;

procedure TBatchParser.ParseUnit(const AFilePath: string);
var
  LDocParser: TDocParser;
  LSource: string;
  LElements: TArray<TCodeElementInfo>;
  LUnitDoc: TUnitDocInfo;
  LTypeDoc: TTypeDocInfo;
  LElem: TElementDocInfo;
  LTypeMap: TDictionary<string, TTypeDocInfo>;
  LImplLine: Integer;
  LLines: TArray<string>;
  I: Integer;
  LCodeElem: TCodeElementInfo;
  LLine: string;
begin
  LSource := TFile.ReadAllText(AFilePath, TEncoding.UTF8);

  // implementation 섹션 시작 행 찾기 (interface 요소만 처리하기 위함)
  LLines := LSource.Split([#10]);
  LImplLine := MaxInt;
  for I := 0 to Length(LLines) - 1 do
  begin
    LLine := Trim(LLines[I]);
    if SameText(LLine, 'implementation') or LLine.StartsWith('implementation ') then
    begin
      LImplLine := I + 1;  // 1-based
      Break;
    end;
  end;

  // TDocParser로 소스 파싱
  LDocParser := TDocParser.Create;
  try
    try
      LDocParser.ParseSource(LSource);
    except
      Exit;
    end;

    if not Assigned(LDocParser.RootNode) then
      Exit;

    LElements := LDocParser.GetAllElements;

    LUnitDoc := TUnitDocInfo.Create;
    LUnitDoc.FilePath := AFilePath;
    LUnitDoc.UnitName := TPath.GetFileNameWithoutExtension(AFilePath);

    // 타입 맵: 타입 이름 → TTypeDocInfo (멤버 연결용)
    LTypeMap := TDictionary<string, TTypeDocInfo>.Create;
    try
      for I := 0 to Length(LElements) - 1 do
      begin
        LCodeElem := LElements[I];

        // implementation 섹션 이후 요소는 스킵
        if LCodeElem.LineNumber >= LImplLine then
          Continue;

        // 이름이 없는 요소는 스킵
        if LCodeElem.Name = '' then
          Continue;

        case LCodeElem.Kind of
          dekClass, dekRecord, dekInterface:
          begin
            LTypeDoc := TTypeDocInfo.Create;
            LTypeDoc.Name := LCodeElem.Name;
            LTypeDoc.FullName := LUnitDoc.UnitName + '.' + LCodeElem.Name;
            LTypeDoc.Kind := LCodeElem.Kind;

            if LCodeElem.ExistingDocXml <> '' then
              LTypeDoc.Doc.LoadFromXml(LCodeElem.ExistingDocXml);

            LUnitDoc.Types.Add(LTypeDoc);
            LTypeMap.AddOrSetValue(LCodeElem.Name, LTypeDoc);
          end;

          dekMethod, dekProperty, dekField:
          begin
            LElem := TElementDocInfo.Create;
            LElem.Name := LCodeElem.Name;
            LElem.Kind := LCodeElem.Kind;
            LElem.Visibility := LCodeElem.Visibility;
            LElem.CodeElement := LCodeElem;

            if LCodeElem.ExistingDocXml <> '' then
              LElem.Doc.LoadFromXml(LCodeElem.ExistingDocXml);

            // QualifiedParent가 있으면 해당 타입의 멤버
            if (LCodeElem.QualifiedParent <> '') and
               LTypeMap.ContainsKey(LCodeElem.QualifiedParent) then
            begin
              LElem.FullName := LUnitDoc.UnitName + '.' +
                LCodeElem.QualifiedParent + '.' + LCodeElem.Name;
              LTypeMap[LCodeElem.QualifiedParent].Members.Add(LElem);
            end
            else
            begin
              LElem.FullName := LUnitDoc.UnitName + '.' + LCodeElem.Name;
              LUnitDoc.StandaloneMethods.Add(LElem);
            end;
          end;

          dekConstant:
          begin
            LElem := TElementDocInfo.Create;
            LElem.Name := LCodeElem.Name;
            LElem.Kind := dekConstant;
            LElem.Visibility := LCodeElem.Visibility;
            LElem.CodeElement := LCodeElem;

            if LCodeElem.ExistingDocXml <> '' then
              LElem.Doc.LoadFromXml(LCodeElem.ExistingDocXml);

            if (LCodeElem.QualifiedParent <> '') and
               LTypeMap.ContainsKey(LCodeElem.QualifiedParent) then
            begin
              LElem.FullName := LUnitDoc.UnitName + '.' +
                LCodeElem.QualifiedParent + '.' + LCodeElem.Name;
              LTypeMap[LCodeElem.QualifiedParent].Members.Add(LElem);
            end
            else
            begin
              LElem.FullName := LUnitDoc.UnitName + '.' + LCodeElem.Name;
              LUnitDoc.Constants.Add(LElem);
            end;
          end;
        end;
      end;
    finally
      LTypeMap.Free;
    end;

    FUnits.Add(LUnitDoc);
  finally
    LDocParser.Free;
  end;
end;

procedure TBatchParser.ParseAll(const AFiles: TArray<string>);
var
  I: Integer;
begin
  FUnits.Clear;
  FSymbolIndex.Clear;

  for I := 0 to Length(AFiles) - 1 do
  begin
    if Assigned(FOnProgress) then
      FOnProgress(I + 1, Length(AFiles), ExtractFileName(AFiles[I]));

    ParseUnit(AFiles[I]);
  end;

  BuildSymbolIndex;
end;

end.
