unit XmlDoc.StubGen;

interface

uses
  System.SysUtils,
  System.Classes,
  XmlDoc.Consts,
  XmlDoc.Model;

type
  /// <summary>코드 요소 시그니처를 분석해 문서 스텁을 자동 생성합니다.</summary>
  TDocStubGenerator = class
  private
    class function ExtractParamHint(const AParamName, ATypeName: string): string;
    class function GenerateReturnHint(const AReturnType: string): string;
    class function GenerateSummaryHint(const AElement: TCodeElementInfo): string;
  public
    /// <summary>코드 요소에 대한 문서 스텁 모델을 생성합니다.</summary>
    /// <param name="AElement">대상 코드 요소 정보</param>
    /// <returns>스텁이 채워진 TXmlDocModel (호출자가 Free해야 함)</returns>
    class function GenerateStub(const AElement: TCodeElementInfo): TXmlDocModel;
  end;

implementation

uses
  System.StrUtils,
  XmlDoc.ParamDict;

const
  CPlaceholderPrefix = 'TODO: ';

{ TDocStubGenerator }

class function TDocStubGenerator.ExtractParamHint(const AParamName, ATypeName: string): string;
var
  LName: string;
begin
  // A 접두어 제거
  if (Length(AParamName) > 1) and (AParamName[1] = 'A') and
     (AParamName[2] >= 'A') and (AParamName[2] <= 'Z') then
    LName := Copy(AParamName, 2, MaxInt)
  else
    LName := AParamName;

  LName := LowerCase(LName);

  // 이름 기반 힌트
  if LName = 'filename' then
    Result := '파일 이름'
  else if LName = 'filepath' then
    Result := '파일 경로'
  else if LName = 'dirname' then
    Result := '디렉토리 이름'
  else if LName = 'dirpath' then
    Result := '디렉토리 경로'
  else if LName = 'count' then
    Result := '개수'
  else if LName = 'index' then
    Result := '인덱스 (0-based)'
  else if LName = 'name' then
    Result := '이름'
  else if LName = 'text' then
    Result := '텍스트'
  else if LName = 'value' then
    Result := '값'
  else if LName = 'source' then
    Result := '원본'
  else if LName = 'target' then
    Result := '대상'
  else if LName = 'stream' then
    Result := '스트림'
  else if LName = 'format' then
    Result := '형식'
  else if LName = 'owner' then
    Result := '소유자'
  else if LName = 'parent' then
    Result := '부모'
  else if LName = 'key' then
    Result := '키'
  else if LName = 'msg' then
    Result := '메시지'
  else if LName = 'message' then
    Result := '메시지'
  else if LName = 'result' then
    Result := '결과'
  else if LName = 'enabled' then
    Result := '활성화 여부'
  else if LName = 'visible' then
    Result := '표시 여부'
  else if LName = 'width' then
    Result := '너비'
  else if LName = 'height' then
    Result := '높이'
  else if LName = 'size' then
    Result := '크기'
  else if LName = 'timeout' then
    Result := '타임아웃 (밀리초)'
  else if LName = 'callback' then
    Result := '콜백'
  else if LName = 'handler' then
    Result := '핸들러'
  else if LName = 'sender' then
    Result := '이벤트 발생 객체'
  else if LName = 'args' then
    Result := '인수'
  else
    Result := '';
end;

class function TDocStubGenerator.GenerateReturnHint(const AReturnType: string): string;
var
  LType: string;
begin
  LType := LowerCase(AReturnType);

  if LType = 'boolean' then
    Result := 'True이면 성공'
  else if LType = 'string' then
    Result := CPlaceholderPrefix + '반환 문자열 설명'
  else if (LType = 'integer') or (LType = 'int64') or (LType = 'cardinal') then
    Result := CPlaceholderPrefix + '반환 값 설명'
  else if LType <> '' then
    Result := CPlaceholderPrefix + AReturnType + ' 설명'
  else
    Result := '';
end;

class function TDocStubGenerator.GenerateSummaryHint(const AElement: TCodeElementInfo): string;
var
  LMethodKind: string;
begin
  LMethodKind := LowerCase(AElement.MethodKind);

  case AElement.Kind of
  dekMethod:
    begin
      if LMethodKind = 'constructor' then
        Result := '새 인스턴스를 생성합니다.'
      else
      if LMethodKind = 'destructor' then
        Result := '인스턴스를 해제합니다.'
      else
        Result := CPlaceholderPrefix + AElement.Name + ' 설명';
    end;
  dekClass:
    Result := CPlaceholderPrefix + AElement.Name + ' 클래스 설명';
  dekRecord:
    Result := CPlaceholderPrefix + AElement.Name + ' 레코드 설명';
  dekInterface:
    Result := CPlaceholderPrefix + AElement.Name + ' 인터페이스 설명';
  dekProperty:
    Result := CPlaceholderPrefix + AElement.Name + ' 설명';
  dekField:
    Result := CPlaceholderPrefix + AElement.Name + ' 설명';
  dekConstant:
    Result := CPlaceholderPrefix + AElement.Name + ' 설명';
  dekType:
    Result := CPlaceholderPrefix + AElement.Name + ' 타입 설명';
  else
    Result := CPlaceholderPrefix + '설명';
  end;
end;

class function TDocStubGenerator.GenerateStub(const AElement: TCodeElementInfo): TXmlDocModel;
var
  LParamDoc: TParamDoc;
  LTypeParamDoc: TTypeParamDoc;
  I: Integer;
  LHint: string;
begin
  Result := TXmlDocModel.Create;

  // 빈 요소면 빈 모델 반환
  if AElement.Name = '' then
    Exit;

  // Summary
  Result.Summary := GenerateSummaryHint(AElement);

  // Params
  for I := 0 to Length(AElement.Params) - 1 do
  begin
    LParamDoc.Name := AElement.Params[I].Name;
    LHint := ExtractParamHint(AElement.Params[I].Name, AElement.Params[I].TypeName);
    if LHint = '' then
      TParamDictionary.Instance.TryGet(AElement.Params[I].Name, LHint);

    if LHint <> '' then
      LParamDoc.Description := LHint
    else
      LParamDoc.Description := CPlaceholderPrefix + AElement.Params[I].Name + ' 설명';
    Result.Params.Add(LParamDoc);
  end;

  // TypeParams (제네릭)
  for I := 0 to Length(AElement.GenericParams) - 1 do
  begin
    LTypeParamDoc.Name := AElement.GenericParams[I];
    LTypeParamDoc.Description := CPlaceholderPrefix + AElement.GenericParams[I] + ' 타입 설명';
    Result.TypeParams.Add(LTypeParamDoc);
  end;

  // Returns
  if (AElement.Kind = dekMethod) and (AElement.ReturnType <> '') then
    Result.Returns := GenerateReturnHint(AElement.ReturnType);
end;

end.
