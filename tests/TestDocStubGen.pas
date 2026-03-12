unit TestDocStubGen;

interface

uses
  DUnitX.TestFramework,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.StubGen;

type
  [TestFixture]
  TTestDocStubGenerator = class
  private
    function MakeElement(AKind: TDocElementKind; const AName: string;
      const AMethodKind: string = ''): TCodeElementInfo;

  public
    [Test]
    procedure EmptyElement_ReturnsEmptyModel;

    [Test]
    procedure Constructor_GeneratesAutoSummary;

    [Test]
    procedure Destructor_GeneratesAutoSummary;

    [Test]
    procedure Function_GeneratesReturns;

    [Test]
    procedure BooleanReturn_SpecificHint;

    [Test]
    procedure Procedure_NoReturns;

    [Test]
    procedure ParamHint_FileName;

    [Test]
    procedure ParamHint_Index;

    [Test]
    procedure ParamHint_Count;

    [Test]
    procedure ParamHint_Unknown_UsesTodoPrefix;

    [Test]
    procedure ParamWithoutAPrefix_NoHint;

    [Test]
    procedure ClassElement_SummaryHint;

    [Test]
    procedure RecordElement_SummaryHint;

    [Test]
    procedure InterfaceElement_SummaryHint;

    [Test]
    procedure PropertyElement_SummaryHint;

    [Test]
    procedure ConstantElement_SummaryHint;

    [Test]
    procedure GenericParams_TypeParamDocs;

    [Test]
    procedure MultipleParams_AllDocumented;

    [Test]
    procedure StringReturn_TodoHint;
  end;

implementation

{ TTestDocStubGenerator }

function TTestDocStubGenerator.MakeElement(AKind: TDocElementKind;
  const AName, AMethodKind: string): TCodeElementInfo;
begin
  Result := Default(TCodeElementInfo);
  Result.Kind := AKind;
  Result.Name := AName;
  Result.MethodKind := AMethodKind;
  Result.LineNumber := 10;
  Result.EndLineNumber := 10;
  Result.CommentStartLine := -1;
  Result.CommentEndLine := -1;
  Result.IndentLevel := 2;
end;

procedure TTestDocStubGenerator.EmptyElement_ReturnsEmptyModel;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := Default(TCodeElementInfo);
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.IsTrue(LModel.IsEmpty);
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.Constructor_GeneratesAutoSummary;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekMethod, 'Create', 'constructor');
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.AreEqual('새 인스턴스를 생성합니다.', LModel.Summary);
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.Destructor_GeneratesAutoSummary;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekMethod, 'Destroy', 'destructor');
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.AreEqual('인스턴스를 해제합니다.', LModel.Summary);
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.Function_GeneratesReturns;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekMethod, 'GetCount', 'function');
  LElement.ReturnType := 'Integer';
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.IsNotEmpty(LModel.Returns);
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.BooleanReturn_SpecificHint;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekMethod, 'IsValid', 'function');
  LElement.ReturnType := 'Boolean';
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.AreEqual('True이면 성공', LModel.Returns);
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.Procedure_NoReturns;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekMethod, 'DoWork', 'procedure');
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.IsEmpty(LModel.Returns);
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.ParamHint_FileName;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekMethod, 'LoadFile', 'procedure');
  SetLength(LElement.Params, 1);
  LElement.Params[0].Name := 'AFileName';
  LElement.Params[0].TypeName := 'string';
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.AreEqual(1, LModel.Params.Count);
    Assert.AreEqual('AFileName', LModel.Params[0].Name);
    Assert.AreEqual('파일 이름', LModel.Params[0].Description);
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.ParamHint_Index;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekMethod, 'GetItem', 'function');
  SetLength(LElement.Params, 1);
  LElement.Params[0].Name := 'AIndex';
  LElement.Params[0].TypeName := 'Integer';
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.AreEqual('인덱스 (0-based)', LModel.Params[0].Description);
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.ParamHint_Count;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekMethod, 'SetCount', 'procedure');
  SetLength(LElement.Params, 1);
  LElement.Params[0].Name := 'ACount';
  LElement.Params[0].TypeName := 'Integer';
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.AreEqual('개수', LModel.Params[0].Description);
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.ParamHint_Unknown_UsesTodoPrefix;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekMethod, 'DoWork', 'procedure');
  SetLength(LElement.Params, 1);
  LElement.Params[0].Name := 'ACustomThing';
  LElement.Params[0].TypeName := 'TObject';
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.StartsWith('TODO: ', LModel.Params[0].Description);
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.ParamWithoutAPrefix_NoHint;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekMethod, 'DoWork', 'procedure');
  SetLength(LElement.Params, 1);
  LElement.Params[0].Name := 'Sender';
  LElement.Params[0].TypeName := 'TObject';
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.AreEqual(1, LModel.Params.Count);
    Assert.AreEqual('이벤트 발생 객체', LModel.Params[0].Description);
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.ClassElement_SummaryHint;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekClass, 'TMyClass');
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.Contains(LModel.Summary, 'TMyClass');
    Assert.Contains(LModel.Summary, '클래스');
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.RecordElement_SummaryHint;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekRecord, 'TMyRecord');
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.Contains(LModel.Summary, 'TMyRecord');
    Assert.Contains(LModel.Summary, '레코드');
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.InterfaceElement_SummaryHint;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekInterface, 'IMyInterface');
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.Contains(LModel.Summary, 'IMyInterface');
    Assert.Contains(LModel.Summary, '인터페이스');
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.PropertyElement_SummaryHint;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekProperty, 'Name');
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.Contains(LModel.Summary, 'Name');
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.ConstantElement_SummaryHint;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekConstant, 'CMaxRetries');
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.Contains(LModel.Summary, 'CMaxRetries');
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.GenericParams_TypeParamDocs;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekClass, 'TContainer');
  SetLength(LElement.GenericParams, 2);
  LElement.GenericParams[0] := 'TKey';
  LElement.GenericParams[1] := 'TValue';
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.AreEqual(2, LModel.TypeParams.Count);
    Assert.AreEqual('TKey', LModel.TypeParams[0].Name);
    Assert.AreEqual('TValue', LModel.TypeParams[1].Name);
    Assert.Contains(LModel.TypeParams[0].Description, 'TKey');
    Assert.Contains(LModel.TypeParams[1].Description, 'TValue');
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.MultipleParams_AllDocumented;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekMethod, 'CopyFile', 'procedure');
  SetLength(LElement.Params, 3);
  LElement.Params[0].Name := 'ASource';
  LElement.Params[0].TypeName := 'string';
  LElement.Params[1].Name := 'ATarget';
  LElement.Params[1].TypeName := 'string';
  LElement.Params[2].Name := 'ACount';
  LElement.Params[2].TypeName := 'Integer';
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.AreEqual(3, LModel.Params.Count);
    Assert.AreEqual('원본', LModel.Params[0].Description);
    Assert.AreEqual('대상', LModel.Params[1].Description);
    Assert.AreEqual('개수', LModel.Params[2].Description);
  finally
    LModel.Free;
  end;
end;

procedure TTestDocStubGenerator.StringReturn_TodoHint;
var
  LElement: TCodeElementInfo;
  LModel: TXmlDocModel;
begin
  LElement := MakeElement(dekMethod, 'GetName', 'function');
  LElement.ReturnType := 'string';
  LModel := TDocStubGenerator.GenerateStub(LElement);
  try
    Assert.StartsWith('TODO: ', LModel.Returns);
  finally
    LModel.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDocStubGenerator);

end.
