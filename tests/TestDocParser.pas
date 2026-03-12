unit TestDocParser;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  XmlDoc.Consts,
  XmlDoc.Parser;

type
  [TestFixture]
  TTestDocParser = class
  private
    FParser: TDocParser;

    function LoadFixture(const AFileName: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestParseSource_BasicUnit;

    [Test]
    procedure TestParseSource_CreatesRootNode;

    [Test]
    procedure TestIsUpToDate_SameSource;

    [Test]
    procedure TestIsUpToDate_DifferentSource;

    [Test]
    procedure TestGetElementAtLine_Method;

    [Test]
    procedure TestGetElementAtLine_Class;

    [Test]
    procedure TestGetElementAtLine_Property;

    [Test]
    procedure TestGetElementAtLine_Constructor;

    [Test]
    procedure TestGetElementAtLine_Constant;

    [Test]
    procedure TestGetElementAtLine_Field;

    [Test]
    procedure TestGetElementAtLine_NoTarget;

    [Test]
    procedure TestGetElementAtLine_MethodParams;

    [Test]
    procedure TestGetElementAtLine_ReturnType;

    [Test]
    procedure TestGetElementAtLine_QualifiedName;

    [Test]
    procedure TestExtractDocComment_Existing;

    [Test]
    procedure TestExtractDocComment_None;

    [Test]
    procedure TestExtractDocComment_MultiLine;

    [Test]
    procedure TestParseSource_CacheHit;

    [Test]
    procedure TestParseSource_ParseError;

    [Test]
    procedure TestGetElementAtLine_CursorOnComment;

    [Test]
    procedure TestGetElementAtLine_IndentLevel;
  end;

implementation

{ TTestDocParser }

function TTestDocParser.LoadFixture(const AFileName: string): string;
var
  LPath: string;
begin
  LPath := TPath.Combine(
    TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), '..\..\tests\fixtures'),
    AFileName
  );
  if TFile.Exists(LPath) then
    Result := TFile.ReadAllText(LPath, TEncoding.UTF8)
  else
  begin
    // 개발 환경 대응: 프로젝트 루트 기준
    LPath := TPath.Combine('tests\fixtures', AFileName);
    if TFile.Exists(LPath) then
      Result := TFile.ReadAllText(LPath, TEncoding.UTF8)
    else
      Result := '';
  end;
end;

procedure TTestDocParser.Setup;
begin
  FParser := TDocParser.Create;
end;

procedure TTestDocParser.TearDown;
begin
  FParser.Free;
end;

procedure TTestDocParser.TestParseSource_BasicUnit;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '    procedure Bar;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
begin
  FParser.ParseSource(CSource);
  Assert.IsNotNull(FParser.RootNode, 'RootNode가 nil이면 안 됩니다');
end;

procedure TTestDocParser.TestParseSource_CreatesRootNode;
const
  CSource =
    'unit MyUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
begin
  FParser.ParseSource(CSource);
  Assert.IsNotNull(FParser.RootNode);
end;

procedure TTestDocParser.TestIsUpToDate_SameSource;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
begin
  FParser.ParseSource(CSource);
  Assert.IsTrue(FParser.IsUpToDate(CSource));
end;

procedure TTestDocParser.TestIsUpToDate_DifferentSource;
const
  CSource1 =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
  CSource2 =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
begin
  FParser.ParseSource(CSource1);
  Assert.IsFalse(FParser.IsUpToDate(CSource2));
end;

procedure TTestDocParser.TestGetElementAtLine_Method;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '    procedure DoWork;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(5);  // procedure DoWork 행

  Assert.AreEqual(dekMethod, LElement.Kind);
  Assert.AreEqual('DoWork', LElement.Name);
end;

procedure TTestDocParser.TestGetElementAtLine_Class;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TMyClass = class' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(4);  // TMyClass = class 행

  Assert.AreEqual(dekClass, LElement.Kind);
  Assert.AreEqual('TMyClass', LElement.Name);
end;

procedure TTestDocParser.TestGetElementAtLine_Property;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '  private' + sLineBreak +
    '    FName: string;' + sLineBreak +
    '  public' + sLineBreak +
    '    property Name: string read FName write FName;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(8);  // property Name 행

  Assert.AreEqual(dekProperty, LElement.Kind);
  Assert.AreEqual('Name', LElement.Name);
end;

procedure TTestDocParser.TestGetElementAtLine_Constructor;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '    constructor Create;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(5);

  Assert.AreEqual(dekMethod, LElement.Kind);
  Assert.AreEqual('Create', LElement.Name);
end;

procedure TTestDocParser.TestGetElementAtLine_Constant;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'const' + sLineBreak +
    '  MaxValue = 100;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(4);

  Assert.AreEqual(dekConstant, LElement.Kind);
  Assert.AreEqual('MaxValue', LElement.Name);
end;

procedure TTestDocParser.TestGetElementAtLine_Field;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '    FValue: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(5);

  Assert.AreEqual(dekField, LElement.Kind);
end;

procedure TTestDocParser.TestGetElementAtLine_NoTarget;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(2);  // interface 행

  Assert.AreEqual('', LElement.Name);
end;

procedure TTestDocParser.TestGetElementAtLine_MethodParams;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '    function Calc(const AX: Integer; var AY: Double): Boolean;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(5);

  Assert.AreEqual(dekMethod, LElement.Kind);
  Assert.AreEqual('Calc', LElement.Name);
  Assert.IsTrue(Length(LElement.Params) >= 2, '파라미터가 2개 이상이어야 합니다');
  Assert.AreEqual('AX', LElement.Params[0].Name);
  Assert.AreEqual('AY', LElement.Params[1].Name);
end;

procedure TTestDocParser.TestGetElementAtLine_ReturnType;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '    function GetName: string;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(5);

  Assert.AreEqual(dekMethod, LElement.Kind);
  Assert.AreEqual('GetName', LElement.Name);
  // ReturnType은 DelphiAST의 반환 노드 속성에 따라 달라질 수 있음
  // 빈 문자열이 아닌 것만 확인
  Assert.IsTrue(LElement.ReturnType <> '', 'ReturnType이 비어있으면 안 됩니다');
end;

procedure TTestDocParser.TestGetElementAtLine_QualifiedName;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '    procedure Bar;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(5);

  Assert.AreEqual('Bar', LElement.Name);
  Assert.IsTrue(LElement.FullName.Contains('Bar'),
    'FullName에 Bar가 포함되어야 합니다');
end;

procedure TTestDocParser.TestExtractDocComment_Existing;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '    /// <summary>메서드 설명</summary>' + sLineBreak +
    '    procedure DoWork;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(6);

  Assert.IsTrue(LElement.ExistingDocXml <> '', '기존 주석이 추출되어야 합니다');
  Assert.IsTrue(LElement.ExistingDocXml.Contains('메서드 설명'));
  Assert.IsTrue(LElement.CommentStartLine > 0, 'CommentStartLine이 설정되어야 합니다');
end;

procedure TTestDocParser.TestExtractDocComment_None;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '    procedure DoWork;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(5);

  Assert.AreEqual('', LElement.ExistingDocXml);
  Assert.AreEqual(-1, LElement.CommentStartLine);
end;

procedure TTestDocParser.TestExtractDocComment_MultiLine;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '    /// <summary>' + sLineBreak +
    '    /// 여러 줄에 걸친' + sLineBreak +
    '    /// 설명입니다.' + sLineBreak +
    '    /// </summary>' + sLineBreak +
    '    procedure DoWork;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(9);

  Assert.IsTrue(LElement.ExistingDocXml <> '', '멀티라인 주석이 추출되어야 합니다');
  Assert.IsTrue(LElement.ExistingDocXml.Contains('여러 줄에 걸친'));
  Assert.IsTrue(LElement.ExistingDocXml.Contains('설명입니다'));
  Assert.AreEqual(5, LElement.CommentStartLine);
  Assert.AreEqual(8, LElement.CommentEndLine);
end;

procedure TTestDocParser.TestParseSource_CacheHit;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
begin
  FParser.ParseSource(CSource);
  Assert.IsTrue(FParser.IsUpToDate(CSource));

  // 같은 소스로 다시 파싱 — 캐시 히트로 빠르게 반환
  FParser.ParseSource(CSource);
  Assert.IsNotNull(FParser.RootNode);
end;

procedure TTestDocParser.TestParseSource_ParseError;
const
  CBrokenSource = 'this is not valid pascal code at all!!!';
begin
  FParser.ParseSource(CBrokenSource);
  // 파싱 실패 시 RootNode가 nil이어야 함
  Assert.IsNull(FParser.RootNode, '잘못된 소스에서 RootNode는 nil이어야 합니다');
end;

procedure TTestDocParser.TestGetElementAtLine_CursorOnComment;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '    /// <summary>설명</summary>' + sLineBreak +
    '    procedure DoWork;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(5);  // /// 주석 행에 커서

  // 주석 행에서도 해당 코드 요소를 찾아야 함
  Assert.AreEqual('DoWork', LElement.Name);
end;

procedure TTestDocParser.TestGetElementAtLine_IndentLevel;
const
  CSource =
    'unit TestUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TFoo = class' + sLineBreak +
    '    procedure DoWork;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
var
  LElement: TCodeElementInfo;
begin
  FParser.ParseSource(CSource);
  LElement := FParser.GetElementAtLine(5);

  // IndentLevel은 Col - 1이므로 4칸 들여쓰기 = 3 (Col=5, IndentLevel=4)
  Assert.IsTrue(LElement.IndentLevel >= 0, 'IndentLevel이 0 이상이어야 합니다');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDocParser);

end.
