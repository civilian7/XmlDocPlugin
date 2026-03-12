unit TestDocModel;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.JSON,
  XmlDoc.Consts,
  XmlDoc.Model;

type
  [TestFixture]
  TTestXmlDocModel = class
  private
    FModel: TXmlDocModel;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestCreateEmpty;

    [Test]
    procedure TestLoadFromXml_Summary;

    [Test]
    procedure TestLoadFromXml_FullMethod;

    [Test]
    procedure TestLoadFromXml_WithDocWrapper;

    [Test]
    procedure TestLoadFromXml_EmptyString;

    [Test]
    procedure TestToXml_Summary;

    [Test]
    procedure TestToXml_FullMethod;

    [Test]
    procedure TestToJson_Summary;

    [Test]
    procedure TestToJson_FullMethod;

    [Test]
    procedure TestFromJson_Summary;

    [Test]
    procedure TestFromJson_FullMethod;

    [Test]
    procedure TestRoundTrip_XmlToJsonToXml;

    [Test]
    procedure TestRoundTrip_JsonToXmlToJson;

    [Test]
    procedure TestIsModified_OnSummaryChange;

    [Test]
    procedure TestIsModified_LoadFromXmlResetsFlag;

    [Test]
    procedure TestOnChanged_Fires;

    [Test]
    procedure TestAssign;

    [Test]
    procedure TestClear;

    [Test]
    procedure TestIsEmpty;

    [Test]
    procedure TestLoadFromXml_Exception;

    [Test]
    procedure TestLoadFromXml_Example;

    [Test]
    procedure TestLoadFromXml_SeeAlso;

    [Test]
    procedure TestLoadFromXml_TypeParam;
  end;

implementation

procedure TTestXmlDocModel.Setup;
begin
  FModel := TXmlDocModel.Create;
end;

procedure TTestXmlDocModel.TearDown;
begin
  FModel.Free;
end;

procedure TTestXmlDocModel.TestCreateEmpty;
begin
  Assert.IsTrue(FModel.IsEmpty);
  Assert.AreEqual('', FModel.Summary);
  Assert.AreEqual('', FModel.Remarks);
  Assert.AreEqual('', FModel.Returns);
  Assert.AreEqual(0, FModel.Params.Count);
end;

procedure TTestXmlDocModel.TestLoadFromXml_Summary;
begin
  FModel.LoadFromXml('<summary>테스트 요약입니다.</summary>');
  Assert.AreEqual('테스트 요약입니다.', FModel.Summary);
  Assert.IsFalse(FModel.IsEmpty);
end;

procedure TTestXmlDocModel.TestLoadFromXml_FullMethod;
const
  CXml =
    '<doc>' +
    '<summary>사용자 정보를 업데이트합니다.</summary>' +
    '<param name="AUserId">대상 사용자 ID</param>' +
    '<param name="ANewName">새로운 이름</param>' +
    '<returns>업데이트 성공 여부</returns>' +
    '<exception cref="EUserNotFoundException">사용자를 찾을 수 없을 때 발생</exception>' +
    '</doc>';
begin
  FModel.LoadFromXml(CXml);

  Assert.AreEqual('사용자 정보를 업데이트합니다.', FModel.Summary);
  Assert.AreEqual(2, FModel.Params.Count);
  Assert.AreEqual('AUserId', FModel.Params[0].Name);
  Assert.AreEqual('대상 사용자 ID', FModel.Params[0].Description);
  Assert.AreEqual('ANewName', FModel.Params[1].Name);
  Assert.AreEqual('새로운 이름', FModel.Params[1].Description);
  Assert.AreEqual('업데이트 성공 여부', FModel.Returns);
  Assert.AreEqual(1, FModel.Exceptions.Count);
  Assert.AreEqual('EUserNotFoundException', FModel.Exceptions[0].TypeRef);
  Assert.AreEqual('사용자를 찾을 수 없을 때 발생', FModel.Exceptions[0].Description);
end;

procedure TTestXmlDocModel.TestLoadFromXml_WithDocWrapper;
begin
  FModel.LoadFromXml('<doc><summary>래핑된 문서</summary></doc>');
  Assert.AreEqual('래핑된 문서', FModel.Summary);
end;

procedure TTestXmlDocModel.TestLoadFromXml_EmptyString;
begin
  FModel.LoadFromXml('');
  Assert.IsTrue(FModel.IsEmpty);
end;

procedure TTestXmlDocModel.TestToXml_Summary;
begin
  FModel.Summary := '간단한 설명';
  Assert.IsTrue(FModel.ToXml.Contains('<summary>'));
  Assert.IsTrue(FModel.ToXml.Contains('간단한 설명'));
  Assert.IsTrue(FModel.ToXml.Contains('</summary>'));
end;

procedure TTestXmlDocModel.TestToXml_FullMethod;
var
  LParam: TParamDoc;
  LException: TExceptionDoc;
  LXml: string;
begin
  FModel.Summary := '사용자를 업데이트합니다.';
  FModel.Returns := '성공 여부';

  LParam.Name := 'AUserId';
  LParam.Description := '사용자 ID';
  FModel.Params.Add(LParam);

  LException.TypeRef := 'ENotFoundException';
  LException.Description := '찾을 수 없음';
  FModel.Exceptions.Add(LException);

  LXml := FModel.ToXml;

  Assert.IsTrue(LXml.Contains('<summary>'));
  Assert.IsTrue(LXml.Contains('<param name="AUserId">사용자 ID</param>'));
  Assert.IsTrue(LXml.Contains('<returns>성공 여부</returns>'));
  Assert.IsTrue(LXml.Contains('<exception cref="ENotFoundException">'));
end;

procedure TTestXmlDocModel.TestToJson_Summary;
var
  LJson: string;
  LObj: TJSONObject;
begin
  FModel.Summary := 'JSON 테스트';
  LJson := FModel.ToJson;
  LObj := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
  try
    Assert.IsNotNull(LObj);
    Assert.AreEqual('JSON 테스트', LObj.GetValue<string>('summary'));
  finally
    LObj.Free;
  end;
end;

procedure TTestXmlDocModel.TestToJson_FullMethod;
var
  LParam: TParamDoc;
  LJson: string;
  LObj: TJSONObject;
  LArr: TJSONArray;
begin
  FModel.Summary := '메서드 설명';
  FModel.Returns := '결과';

  LParam.Name := 'AName';
  LParam.Description := '이름';
  FModel.Params.Add(LParam);

  LJson := FModel.ToJson;
  LObj := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
  try
    Assert.AreEqual('메서드 설명', LObj.GetValue<string>('summary'));
    Assert.AreEqual('결과', LObj.GetValue<string>('returns'));
    LArr := LObj.GetValue<TJSONArray>('params');
    Assert.AreEqual(1, LArr.Count);
    Assert.AreEqual('AName', (LArr.Items[0] as TJSONObject).GetValue<string>('name'));
  finally
    LObj.Free;
  end;
end;

procedure TTestXmlDocModel.TestFromJson_Summary;
begin
  FModel.FromJson('{"summary":"JSON에서 로드"}');
  Assert.AreEqual('JSON에서 로드', FModel.Summary);
end;

procedure TTestXmlDocModel.TestFromJson_FullMethod;
const
  CJson =
    '{' +
    '"summary":"업데이트 메서드",' +
    '"returns":"성공 여부",' +
    '"params":[' +
    '  {"name":"AId","description":"ID 값"},' +
    '  {"name":"AName","description":"이름"}' +
    '],' +
    '"exceptions":[' +
    '  {"typeRef":"ENotFound","description":"없음"}' +
    ']' +
    '}';
begin
  FModel.FromJson(CJson);

  Assert.AreEqual('업데이트 메서드', FModel.Summary);
  Assert.AreEqual('성공 여부', FModel.Returns);
  Assert.AreEqual(2, FModel.Params.Count);
  Assert.AreEqual('AId', FModel.Params[0].Name);
  Assert.AreEqual('AName', FModel.Params[1].Name);
  Assert.AreEqual(1, FModel.Exceptions.Count);
  Assert.AreEqual('ENotFound', FModel.Exceptions[0].TypeRef);
end;

procedure TTestXmlDocModel.TestRoundTrip_XmlToJsonToXml;
const
  CXml =
    '<doc>' +
    '<summary>라운드트립 테스트</summary>' +
    '<param name="AValue">값</param>' +
    '<returns>결과</returns>' +
    '</doc>';
var
  LModel2: TXmlDocModel;
  LJson: string;
begin
  FModel.LoadFromXml(CXml);
  LJson := FModel.ToJson;

  LModel2 := TXmlDocModel.Create;
  try
    LModel2.FromJson(LJson);
    Assert.AreEqual(FModel.Summary, LModel2.Summary);
    Assert.AreEqual(FModel.Returns, LModel2.Returns);
    Assert.AreEqual(FModel.Params.Count, LModel2.Params.Count);
    Assert.AreEqual(FModel.Params[0].Name, LModel2.Params[0].Name);
  finally
    LModel2.Free;
  end;
end;

procedure TTestXmlDocModel.TestRoundTrip_JsonToXmlToJson;
const
  CJson = '{"summary":"왕복 테스트","returns":"결과값","params":[{"name":"AX","description":"X좌표"}]}';
var
  LModel2: TXmlDocModel;
  LXml: string;
begin
  FModel.FromJson(CJson);
  LXml := FModel.ToXml;

  LModel2 := TXmlDocModel.Create;
  try
    LModel2.LoadFromXml(LXml);
    Assert.AreEqual(FModel.Summary, LModel2.Summary);
    Assert.AreEqual(FModel.Returns, LModel2.Returns);
    Assert.AreEqual(FModel.Params.Count, LModel2.Params.Count);
  finally
    LModel2.Free;
  end;
end;

procedure TTestXmlDocModel.TestIsModified_OnSummaryChange;
begin
  Assert.IsFalse(FModel.IsModified);
  FModel.Summary := '변경됨';
  Assert.IsTrue(FModel.IsModified);
end;

procedure TTestXmlDocModel.TestIsModified_LoadFromXmlResetsFlag;
begin
  FModel.Summary := '변경';
  Assert.IsTrue(FModel.IsModified);
  FModel.LoadFromXml('<summary>리셋</summary>');
  Assert.IsFalse(FModel.IsModified);
end;

procedure TTestXmlDocModel.TestOnChanged_Fires;
var
  LFired: Boolean;
begin
  LFired := False;
  FModel.OnChanged := procedure(Sender: TObject)
    begin
      LFired := True;
    end;
  FModel.Summary := '이벤트 테스트';
  Assert.IsTrue(LFired);
end;

procedure TTestXmlDocModel.TestAssign;
var
  LParam: TParamDoc;
  LTarget: TXmlDocModel;
begin
  FModel.Summary := '원본';
  FModel.Returns := '반환값';
  LParam.Name := 'ATest';
  LParam.Description := '테스트';
  FModel.Params.Add(LParam);

  LTarget := TXmlDocModel.Create;
  try
    LTarget.Assign(FModel);
    Assert.AreEqual('원본', LTarget.Summary);
    Assert.AreEqual('반환값', LTarget.Returns);
    Assert.AreEqual(1, LTarget.Params.Count);
    Assert.AreEqual('ATest', LTarget.Params[0].Name);
  finally
    LTarget.Free;
  end;
end;

procedure TTestXmlDocModel.TestClear;
begin
  FModel.Summary := '내용 있음';
  FModel.Clear;
  Assert.IsTrue(FModel.IsEmpty);
  Assert.AreEqual('', FModel.Summary);
end;

procedure TTestXmlDocModel.TestIsEmpty;
var
  LParam: TParamDoc;
begin
  Assert.IsTrue(FModel.IsEmpty);

  FModel.Summary := '비어있지 않음';
  Assert.IsFalse(FModel.IsEmpty);

  FModel.Clear;
  LParam.Name := 'A';
  LParam.Description := '';
  FModel.Params.Add(LParam);
  Assert.IsFalse(FModel.IsEmpty);
end;

procedure TTestXmlDocModel.TestLoadFromXml_Exception;
const
  CXml = '<exception cref="EInvalidOp">잘못된 연산</exception>';
begin
  FModel.LoadFromXml(CXml);
  Assert.AreEqual(1, FModel.Exceptions.Count);
  Assert.AreEqual('EInvalidOp', FModel.Exceptions[0].TypeRef);
  Assert.AreEqual('잘못된 연산', FModel.Exceptions[0].Description);
end;

procedure TTestXmlDocModel.TestLoadFromXml_Example;
const
  CXml = '<example title="사용 예시"><code>DoSomething;</code></example>';
begin
  FModel.LoadFromXml(CXml);
  Assert.AreEqual(1, FModel.Examples.Count);
  Assert.AreEqual('사용 예시', FModel.Examples[0].Title);
  Assert.AreEqual('DoSomething;', FModel.Examples[0].Code);
end;

procedure TTestXmlDocModel.TestLoadFromXml_SeeAlso;
const
  CXml = '<seealso cref="TMyClass.DoOther"/>';
begin
  FModel.LoadFromXml(CXml);
  Assert.AreEqual(1, FModel.SeeAlso.Count);
  Assert.AreEqual('TMyClass.DoOther', FModel.SeeAlso[0].Cref);
end;

procedure TTestXmlDocModel.TestLoadFromXml_TypeParam;
const
  CXml = '<typeparam name="T">요소 타입</typeparam>';
begin
  FModel.LoadFromXml(CXml);
  Assert.AreEqual(1, FModel.TypeParams.Count);
  Assert.AreEqual('T', FModel.TypeParams[0].Name);
  Assert.AreEqual('요소 타입', FModel.TypeParams[0].Description);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestXmlDocModel);

end.
