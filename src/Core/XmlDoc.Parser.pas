unit XmlDoc.Parser;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Hash,
  DelphiAST,
  DelphiAST.Classes,
  DelphiAST.Consts,
  XmlDoc.Consts;

type
  /// <summary>DelphiAST 기반 소스 파서. 커서 위치에서 문서화 대상 코드 요소를 식별합니다.</summary>
  TDocParser = class
  private
    FBuilder: TPasSyntaxTreeBuilder;
    FCachedHash: string;
    FCachedSource: string;
    FFlatIndex: TList<TSyntaxNode>;
    FLastCommentStart: Integer;
    FRootNode: TSyntaxNode;
    FSourceLines: TArray<string>;

    function BuildParentPath(ANode: TSyntaxNode): string;
    procedure BuildFlatIndex;
    procedure CollectDocTargets(ANode: TSyntaxNode);
    function ExtractDocComment(ANode: TSyntaxNode): string;
    function ExtractGenericParams(ANode: TSyntaxNode): TArray<string>;
    function ExtractParams(AMethodNode: TSyntaxNode): TArray<TParamInfo>;
    function ExtractReturnType(AMethodNode: TSyntaxNode): string;
    function FindNearestDocTarget(ALine: Integer): TSyntaxNode;
    function FindNextElementAtOrBelow(ALine: Integer): TSyntaxNode;
    function HashSource(const ASource: string): string;
    function IsDocTargetNode(ANode: TSyntaxNode): Boolean;
    function NodeToElementInfo(ANode: TSyntaxNode): TCodeElementInfo;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>소스 텍스트를 받아 AST를 (재)구축합니다.</summary>
    /// <param name="ASource">파싱할 소스 코드 전체</param>
    procedure ParseSource(const ASource: string);

    /// <summary>지정 행에서 문서화 대상 요소 정보를 반환합니다.</summary>
    /// <param name="ALine">커서 행 번호 (1-based)</param>
    /// <returns>코드 요소 정보. 대상이 없으면 Name이 빈 문자열</returns>
    function GetElementAtLine(ALine: Integer): TCodeElementInfo;

    /// <summary>파싱된 모든 문서화 대상 요소를 반환합니다.</summary>
    /// <returns>코드 요소 정보 배열</returns>
    function GetAllElements: TArray<TCodeElementInfo>;

    /// <summary>AST가 최신 상태인지 확인합니다 (소스 변경 감지).</summary>
    /// <param name="ASource">비교할 소스 코드</param>
    /// <returns>변경 없으면 True</returns>
    function IsUpToDate(const ASource: string): Boolean;

    /// <summary>파싱된 AST 루트 노드</summary>
    property RootNode: TSyntaxNode read FRootNode;

    /// <summary>마지막으로 파싱한 소스 텍스트</summary>
    property SourceText: string read FCachedSource;
  end;

implementation

{ TDocParser }

constructor TDocParser.Create;
begin
  inherited Create;

  FFlatIndex := TList<TSyntaxNode>.Create;
end;

destructor TDocParser.Destroy;
begin
  FFlatIndex.Free;
  FRootNode.Free;

  inherited;
end;

procedure TDocParser.BuildFlatIndex;
begin
  FFlatIndex.Clear;
  if not Assigned(FRootNode) then
    Exit;

  CollectDocTargets(FRootNode);

  // Line 기준 정렬
  FFlatIndex.Sort(TComparer<TSyntaxNode>.Construct(
    function(const ALeft, ARight: TSyntaxNode): Integer
    begin
      Result := ALeft.Line - ARight.Line;
    end
  ));
end;

function TDocParser.BuildParentPath(ANode: TSyntaxNode): string;
var
  LCurrent: TSyntaxNode;
  LName: string;
begin
  Result := '';
  LCurrent := ANode.ParentNode;
  while Assigned(LCurrent) do
  begin
    if LCurrent.Typ = ntTypeDecl then
    begin
      LName := LCurrent.GetAttribute(anName);
      if LName <> '' then
      begin
        if Result = '' then
          Result := LName
        else
          Result := LName + '.' + Result;
      end;
    end;
    LCurrent := LCurrent.ParentNode;
  end;
end;

procedure TDocParser.CollectDocTargets(ANode: TSyntaxNode);
var
  I: Integer;
  LChild: TSyntaxNode;
begin
  if IsDocTargetNode(ANode) then
    FFlatIndex.Add(ANode);

  for I := 0 to Length(ANode.ChildNodes) - 1 do
  begin
    LChild := ANode.ChildNodes[I];
    CollectDocTargets(LChild);
  end;
end;

function TDocParser.ExtractDocComment(ANode: TSyntaxNode): string;
var
  LTargetLine: Integer;
  LComments: TStringList;
  I: Integer;
  LLine: string;
begin
  Result := '';
  FLastCommentStart := -1;
  LTargetLine := ANode.Line;

  if Length(FSourceLines) = 0 then
    Exit;

  LComments := TStringList.Create;
  try
    // 코드 요소 바로 윗줄부터 역순 탐색 (0-based index)
    for I := LTargetLine - 2 downto 0 do
    begin
      LLine := Trim(FSourceLines[I]);
      if LLine.StartsWith('///') then
        LComments.Insert(0, Copy(LLine, 4, MaxInt))
      else
        Break;
    end;

    if LComments.Count > 0 then
    begin
      FLastCommentStart := LTargetLine - LComments.Count;  // 1-based
      Result := '<doc>' + LComments.Text + '</doc>';
    end;
  finally
    LComments.Free;
  end;
end;

function TDocParser.ExtractGenericParams(ANode: TSyntaxNode): TArray<string>;
var
  LTypeParams: TSyntaxNode;
  I: Integer;
  LChild: TSyntaxNode;
  LName: string;
  LList: TList<string>;
begin
  LTypeParams := ANode.FindNode(ntTypeParams);
  if not Assigned(LTypeParams) then
  begin
    Result := nil;
    Exit;
  end;

  LList := TList<string>.Create;
  try
    for I := 0 to Length(LTypeParams.ChildNodes) - 1 do
    begin
      LChild := LTypeParams.ChildNodes[I];
      if LChild.Typ = ntTypeParam then
      begin
        LName := LChild.GetAttribute(anName);
        if LName <> '' then
          LList.Add(LName);
      end;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TDocParser.ExtractParams(AMethodNode: TSyntaxNode): TArray<TParamInfo>;
var
  LParamsNode: TSyntaxNode;
  LNameNode: TSyntaxNode;
  LTypeNode: TSyntaxNode;
  LExprNode: TSyntaxNode;
  I: Integer;
  LChild: TSyntaxNode;
  LParam: TParamInfo;
  LList: TList<TParamInfo>;
  LKind: string;
begin
  LParamsNode := AMethodNode.FindNode(ntParameters);
  if not Assigned(LParamsNode) then
  begin
    Result := nil;
    Exit;
  end;

  LList := TList<TParamInfo>.Create;
  try
    for I := 0 to Length(LParamsNode.ChildNodes) - 1 do
    begin
      LChild := LParamsNode.ChildNodes[I];
      if LChild.Typ = ntParameter then
      begin
        LParam := Default(TParamInfo);

        // 파라미터 이름: ntName 자식 노드(TValuedSyntaxNode)에서 추출
        LNameNode := LChild.FindNode(ntName);
        if Assigned(LNameNode) and (LNameNode is TValuedSyntaxNode) then
          LParam.Name := TValuedSyntaxNode(LNameNode).Value;

        // 타입: ntType 자식 노드에서 추출
        LTypeNode := LChild.FindNode(ntType);
        if Assigned(LTypeNode) then
          LParam.TypeName := LTypeNode.GetAttribute(anName);

        // const/var/out
        LKind := LowerCase(LChild.GetAttribute(anKind));
        LParam.IsConst := LKind = 'const';
        LParam.IsVar := LKind = 'var';
        LParam.IsOut := LKind = 'out';

        LList.Add(LParam);
      end;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TDocParser.ExtractReturnType(AMethodNode: TSyntaxNode): string;
var
  LRetNode: TSyntaxNode;
  LTypeNode: TSyntaxNode;
begin
  Result := '';
  LRetNode := AMethodNode.FindNode(ntReturnType);
  if not Assigned(LRetNode) then
    Exit;

  // ntReturnType의 자식 ntType에서 타입 이름 추출
  LTypeNode := LRetNode.FindNode(ntType);
  if Assigned(LTypeNode) then
    Result := LTypeNode.GetAttribute(anName)
  else
    Result := LRetNode.GetAttribute(anName);
end;

function TDocParser.FindNearestDocTarget(ALine: Integer): TSyntaxNode;
var
  LLow, LHigh, LMid: Integer;
  LNode: TSyntaxNode;
  LNextNode: TSyntaxNode;
begin
  Result := nil;
  if FFlatIndex.Count = 0 then
    Exit;

  // 이진 탐색: ALine 이하인 가장 가까운 노드
  LLow := 0;
  LHigh := FFlatIndex.Count - 1;

  // ALine이 첫 노드보다 앞이면 첫 노드 범위 확인
  if ALine < FFlatIndex[0].Line then
  begin
    // 주석 영역 체크: 첫 노드 위의 /// 주석 범위에 커서가 있을 수 있음
    LNode := FFlatIndex[0];
    ExtractDocComment(LNode);
    if (FLastCommentStart > 0) and (ALine >= FLastCommentStart) then
      Result := LNode;
    Exit;
  end;

  while LLow <= LHigh do
  begin
    LMid := (LLow + LHigh) div 2;
    if FFlatIndex[LMid].Line <= ALine then
      LLow := LMid + 1
    else
      LHigh := LMid - 1;
  end;

  // LHigh가 ALine 이하인 마지막 인덱스
  if LHigh >= 0 then
  begin
    LNode := FFlatIndex[LHigh];

    // 정확히 일치
    if ALine = LNode.Line then
    begin
      Result := LNode;
      Exit;
    end;

    // 다음 노드의 주석 범위에 포함되는지 체크
    if LHigh + 1 < FFlatIndex.Count then
    begin
      LNextNode := FFlatIndex[LHigh + 1];
      ExtractDocComment(LNextNode);
      if (FLastCommentStart > 0) and (ALine >= FLastCommentStart) then
      begin
        Result := LNextNode;
        Exit;
      end;
    end;

    // 현재 노드의 주석 범위에 포함되는지 체크
    ExtractDocComment(LNode);
    if (FLastCommentStart > 0) and (ALine >= FLastCommentStart) and (ALine < LNode.Line) then
    begin
      Result := LNode;
      Exit;
    end;

    // ntMethod의 본문 내부 (begin..end 사이) → 해당 메서드 반환
    if (LNode is TCompoundSyntaxNode) and
       (LNode.Typ = ntMethod) and
       (ALine <= TCompoundSyntaxNode(LNode).EndLine) then
    begin
      Result := LNode;
      Exit;
    end;

    // 두 요소 사이의 공백 영역: nil 반환 → GetElementAtLine에서 다음 요소 탐색
  end;
end;

function TDocParser.GetAllElements: TArray<TCodeElementInfo>;
var
  I: Integer;
begin
  SetLength(Result, FFlatIndex.Count);
  for I := 0 to FFlatIndex.Count - 1 do
    Result[I] := NodeToElementInfo(FFlatIndex[I]);
end;

function TDocParser.FindNextElementAtOrBelow(ALine: Integer): TSyntaxNode;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FFlatIndex.Count - 1 do
  begin
    if FFlatIndex[I].Line >= ALine then
    begin
      Result := FFlatIndex[I];
      Exit;
    end;
  end;
end;

function TDocParser.GetElementAtLine(ALine: Integer): TCodeElementInfo;
var
  LNode: TSyntaxNode;
  LNextNode: TSyntaxNode;
begin
  Result := Default(TCodeElementInfo);
  Result.CommentStartLine := -1;
  Result.CommentEndLine := -1;

  LNode := FindNearestDocTarget(ALine);

  if Assigned(LNode) then
  begin
    // 커서가 노드 선언행에 정확히 위치
    if ALine = LNode.Line then
    begin
      Result := NodeToElementInfo(LNode);
      Exit;
    end;

    // 노드의 주석 범위 내 (/// 주석 블록 안)
    ExtractDocComment(LNode);
    if (FLastCommentStart > 0) and (ALine >= FLastCommentStart) and (ALine < LNode.Line) then
    begin
      Result := NodeToElementInfo(LNode);
      Exit;
    end;

    // ntMethod 본문 내부 (implementation의 begin..end 사이)
    // ntTypeDecl(class/record/interface)은 제외: 내부 빈 줄에서는 다음 멤버를 찾아야 함
    if (LNode is TCompoundSyntaxNode) and
       (LNode.Typ = ntMethod) and
       (ALine <= TCompoundSyntaxNode(LNode).EndLine) then
    begin
      Result := NodeToElementInfo(LNode);
      Exit;
    end;

    // 위 조건에 해당하지 않으면 → 아래쪽 요소 탐색
    LNextNode := FindNextElementAtOrBelow(ALine);
    if Assigned(LNextNode) then
      LNode := LNextNode;
  end
  else
  begin
    LNode := FindNextElementAtOrBelow(ALine);
  end;

  if Assigned(LNode) then
    Result := NodeToElementInfo(LNode);
end;

function TDocParser.HashSource(const ASource: string): string;
begin
  Result := THashMD5.GetHashString(ASource);
end;

function TDocParser.IsDocTargetNode(ANode: TSyntaxNode): Boolean;
var
  LTypeNode: TSyntaxNode;
  LTypeAttr: string;
begin
  case ANode.Typ of
    ntMethod,
    ntProperty,
    ntField,
    ntConstant:
      Result := True;
    ntTypeDecl:
    begin
      LTypeNode := ANode.FindNode(ntType);
      if Assigned(LTypeNode) then
      begin
        LTypeAttr := LTypeNode.GetAttribute(anType);
        Result := SameText(LTypeAttr, 'class') or
                  SameText(LTypeAttr, 'record') or
                  SameText(LTypeAttr, 'interface') or
                  SameText(LTypeAttr, 'dispinterface') or
                  SameText(LTypeAttr, 'enum');
      end
      else
        Result := True;
    end;
  else
    Result := False;
  end;
end;

function TDocParser.IsUpToDate(const ASource: string): Boolean;
begin
  Result := (FCachedHash <> '') and (FCachedHash = HashSource(ASource));
end;

function TDocParser.NodeToElementInfo(ANode: TSyntaxNode): TCodeElementInfo;
var
  LTypeNode: TSyntaxNode;
  LTypeAttr: string;
begin
  Result := Default(TCodeElementInfo);
  Result.LineNumber := ANode.Line;
  Result.CommentStartLine := -1;
  Result.CommentEndLine := -1;

  case ANode.Typ of
    ntMethod:
    begin
      Result.Kind := dekMethod;
      Result.Name := ANode.GetAttribute(anName);
      Result.MethodKind := ANode.GetAttribute(anKind);
      Result.Params := ExtractParams(ANode);
      Result.ReturnType := ExtractReturnType(ANode);
      Result.GenericParams := ExtractGenericParams(ANode);
      Result.Visibility := ANode.GetAttribute(anVisibility);
    end;

    ntProperty:
    begin
      Result.Kind := dekProperty;
      Result.Name := ANode.GetAttribute(anName);
      Result.Visibility := ANode.GetAttribute(anVisibility);
    end;

    ntTypeDecl:
    begin
      Result.Name := ANode.GetAttribute(anName);
      LTypeNode := ANode.FindNode(ntType);
      if Assigned(LTypeNode) then
      begin
        LTypeAttr := LTypeNode.GetAttribute(anType);
        if SameText(LTypeAttr, 'class') then
          Result.Kind := dekClass
        else if SameText(LTypeAttr, 'record') then
          Result.Kind := dekRecord
        else if SameText(LTypeAttr, 'interface') or SameText(LTypeAttr, 'dispinterface') then
          Result.Kind := dekInterface
        else if SameText(LTypeAttr, 'enum') then
          Result.Kind := dekType
        else
          Result.Kind := dekType;
      end
      else
        Result.Kind := dekType;

      Result.GenericParams := ExtractGenericParams(ANode);
    end;

    ntConstant:
    begin
      Result.Kind := dekConstant;
      Result.Name := ANode.GetAttribute(anName);
    end;

    ntField:
    begin
      Result.Kind := dekField;
      Result.Name := ANode.GetAttribute(anName);
      Result.Visibility := ANode.GetAttribute(anVisibility);
    end;
  end;

  // 부모 경로
  Result.QualifiedParent := BuildParentPath(ANode);
  if Result.QualifiedParent <> '' then
    Result.FullName := Result.QualifiedParent + '.' + Result.Name
  else
    Result.FullName := Result.Name;

  // 들여쓰기
  Result.IndentLevel := ANode.Col - 1;

  // EndLine (TCompoundSyntaxNode인 경우)
  if ANode is TCompoundSyntaxNode then
    Result.EndLineNumber := TCompoundSyntaxNode(ANode).EndLine
  else
    Result.EndLineNumber := ANode.Line;

  // 기존 주석 추출
  Result.ExistingDocXml := ExtractDocComment(ANode);
  if Result.ExistingDocXml <> '' then
  begin
    Result.CommentStartLine := FLastCommentStart;
    Result.CommentEndLine := ANode.Line - 1;
  end;
end;

procedure TDocParser.ParseSource(const ASource: string);
var
  LStream: TStringStream;
  LHash: string;
begin
  LHash := HashSource(ASource);
  if LHash = FCachedHash then
    Exit;

  // 이전 AST 해제
  FreeAndNil(FRootNode);
  FFlatIndex.Clear;

  FCachedSource := ASource;
  FCachedHash := LHash;
  FSourceLines := ASource.Split([#10]);

  // 줄 끝의 #13 제거
  // Split([#10])은 #13#10에서 #13을 남김
  // 별도 정리 불필요: Trim으로 처리됨 (ExtractDocComment에서)

  LStream := TStringStream.Create(ASource, TEncoding.UTF8);
  try
    FBuilder := TPasSyntaxTreeBuilder.Create;
    try
      try
        FRootNode := FBuilder.Run(LStream);
      except
        // 파싱 실패 시 이전 캐시 무효화
        FCachedHash := '';
        FRootNode := nil;
      end;
    finally
      FBuilder.Free;
      FBuilder := nil;
    end;
  finally
    LStream.Free;
  end;

  if Assigned(FRootNode) then
    BuildFlatIndex;
end;

end.
