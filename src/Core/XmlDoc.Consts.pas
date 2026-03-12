unit XmlDoc.Consts;

interface

uses
  System.SysUtils;

type
  /// <summary>문서화 대상 코드 요소의 종류</summary>
  TDocElementKind = (
    dekUnit,
    dekClass,
    dekRecord,
    dekInterface,
    dekMethod,
    dekProperty,
    dekField,
    dekType,
    dekConstant
  );

  /// <summary>파라미터 문서 정보</summary>
  TParamDoc = record
    Name: string;
    Description: string;
  end;

  /// <summary>제네릭 타입 파라미터 문서 정보</summary>
  TTypeParamDoc = record
    Name: string;
    Description: string;
  end;

  /// <summary>예외 문서 정보</summary>
  TExceptionDoc = record
    TypeRef: string;
    Description: string;
  end;

  /// <summary>예제 문서 정보</summary>
  TExampleDoc = record
    Title: string;
    Code: string;
    Description: string;
  end;

  /// <summary>See Also 문서 정보</summary>
  TSeeAlsoDoc = record
    Cref: string;
    Description: string;
  end;

  /// <summary>파라미터 시그니처 정보 (파서에서 추출)</summary>
  TParamInfo = record
    Name: string;
    TypeName: string;
    DefaultValue: string;
    IsConst: Boolean;
    IsVar: Boolean;
    IsOut: Boolean;
  end;

  /// <summary>코드 요소 정보 (파서에서 추출)</summary>
  TCodeElementInfo = record
    Kind: TDocElementKind;
    Name: string;
    FullName: string;
    QualifiedParent: string;
    Visibility: string;
    Params: TArray<TParamInfo>;
    ReturnType: string;
    GenericParams: TArray<string>;
    MethodKind: string;
    LineNumber: Integer;
    EndLineNumber: Integer;
    IndentLevel: Integer;
    CommentStartLine: Integer;
    CommentEndLine: Integer;
    ExistingDocXml: string;
  end;

  /// <summary>TDocElementKind 유틸리티</summary>
  TDocElementKindHelper = record helper for TDocElementKind
    function ToString: string;
    class function FromString(const AValue: string): TDocElementKind; static;
  end;

implementation

{ TDocElementKindHelper }

class function TDocElementKindHelper.FromString(const AValue: string): TDocElementKind;
var
  LValue: string;
begin
  LValue := LowerCase(AValue);
  if LValue = 'unit' then
    Result := dekUnit
  else if LValue = 'class' then
    Result := dekClass
  else if LValue = 'record' then
    Result := dekRecord
  else if LValue = 'interface' then
    Result := dekInterface
  else if LValue = 'method' then
    Result := dekMethod
  else if LValue = 'property' then
    Result := dekProperty
  else if LValue = 'field' then
    Result := dekField
  else if LValue = 'type' then
    Result := dekType
  else if LValue = 'constant' then
    Result := dekConstant
  else
    Result := dekType;
end;

function TDocElementKindHelper.ToString: string;
begin
  case Self of
    dekUnit:      Result := 'unit';
    dekClass:     Result := 'class';
    dekRecord:    Result := 'record';
    dekInterface: Result := 'interface';
    dekMethod:    Result := 'method';
    dekProperty:  Result := 'property';
    dekField:     Result := 'field';
    dekType:      Result := 'type';
    dekConstant:  Result := 'constant';
  else
    Result := 'unknown';
  end;
end;

end.
