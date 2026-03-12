unit TestDocCodeGen;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.CodeGen;

type
  [TestFixture]
  TTestDocCodeGenerator = class
  private
    FModel: TXmlDocModel;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestEmptyModel_ReturnsEmpty;

    [Test]
    procedure TestSummaryOnly;

    [Test]
    procedure TestSummaryWithIndent;

    [Test]
    procedure TestFullMethodComment;

    [Test]
    procedure TestWithException;

    [Test]
    procedure TestWithSeeAlso;

    [Test]
    procedure TestWithExample;

    [Test]
    procedure TestApplyToSource_NewComment;

    [Test]
    procedure TestApplyToSource_ReplaceExisting;

    [Test]
    procedure TestApplyToSource_EmptyModelRemovesComment;

    [Test]
    procedure TestIndentLevel_Zero;

    [Test]
    procedure TestIndentLevel_Four;

    [Test]
    procedure TestCommentBlockFormat;
  end;

implementation

procedure TTestDocCodeGenerator.Setup;
begin
  FModel := TXmlDocModel.Create;
end;

procedure TTestDocCodeGenerator.TearDown;
begin
  FModel.Free;
end;

procedure TTestDocCodeGenerator.TestEmptyModel_ReturnsEmpty;
begin
  Assert.AreEqual('', TDocCodeGenerator.ModelToCommentBlock(FModel));
end;

procedure TTestDocCodeGenerator.TestSummaryOnly;
var
  LResult: string;
begin
  FModel.Summary := '간단한 설명';
  LResult := TDocCodeGenerator.ModelToCommentBlock(FModel);

  Assert.IsTrue(LResult.Contains('/// <summary>'));
  Assert.IsTrue(LResult.Contains('/// 간단한 설명'));
  Assert.IsTrue(LResult.Contains('/// </summary>'));
end;

procedure TTestDocCodeGenerator.TestSummaryWithIndent;
var
  LResult: string;
begin
  FModel.Summary := '들여쓰기 테스트';
  LResult := TDocCodeGenerator.ModelToCommentBlock(FModel, 4);

  Assert.IsTrue(LResult.Contains('    /// <summary>'));
  Assert.IsTrue(LResult.Contains('    /// 들여쓰기 테스트'));
end;

procedure TTestDocCodeGenerator.TestFullMethodComment;
var
  LParam: TParamDoc;
  LResult: string;
begin
  FModel.Summary := '사용자 정보를 업데이트합니다.';
  FModel.Returns := '업데이트 성공 여부';

  LParam.Name := 'AUserId';
  LParam.Description := '대상 사용자 ID';
  FModel.Params.Add(LParam);

  LParam.Name := 'ANewName';
  LParam.Description := '새로운 이름';
  FModel.Params.Add(LParam);

  LResult := TDocCodeGenerator.ModelToCommentBlock(FModel);

  Assert.IsTrue(LResult.Contains('/// <summary>'));
  Assert.IsTrue(LResult.Contains('/// <param name="AUserId">대상 사용자 ID</param>'));
  Assert.IsTrue(LResult.Contains('/// <param name="ANewName">새로운 이름</param>'));
  Assert.IsTrue(LResult.Contains('/// <returns>업데이트 성공 여부</returns>'));
end;

procedure TTestDocCodeGenerator.TestWithException;
var
  LException: TExceptionDoc;
  LResult: string;
begin
  FModel.Summary := '메서드';
  LException.TypeRef := 'ENotFoundException';
  LException.Description := '찾을 수 없음';
  FModel.Exceptions.Add(LException);

  LResult := TDocCodeGenerator.ModelToCommentBlock(FModel);

  Assert.IsTrue(LResult.Contains('/// <exception cref="ENotFoundException">'));
  Assert.IsTrue(LResult.Contains('/// 찾을 수 없음'));
  Assert.IsTrue(LResult.Contains('/// </exception>'));
end;

procedure TTestDocCodeGenerator.TestWithSeeAlso;
var
  LSeeAlso: TSeeAlsoDoc;
  LResult: string;
begin
  FModel.Summary := '메서드';
  LSeeAlso.Cref := 'TMyClass.OtherMethod';
  LSeeAlso.Description := '';
  FModel.SeeAlso.Add(LSeeAlso);

  LResult := TDocCodeGenerator.ModelToCommentBlock(FModel);

  Assert.IsTrue(LResult.Contains('/// <seealso cref="TMyClass.OtherMethod"/>'));
end;

procedure TTestDocCodeGenerator.TestWithExample;
var
  LExample: TExampleDoc;
  LResult: string;
begin
  FModel.Summary := '메서드';
  LExample.Title := '사용 예시';
  LExample.Code := 'DoSomething;';
  LExample.Description := '기본 사용법';
  FModel.Examples.Add(LExample);

  LResult := TDocCodeGenerator.ModelToCommentBlock(FModel);

  Assert.IsTrue(LResult.Contains('/// <example title="사용 예시">'));
  Assert.IsTrue(LResult.Contains('/// 기본 사용법'));
  Assert.IsTrue(LResult.Contains('/// <code>'));
  Assert.IsTrue(LResult.Contains('/// DoSomething;'));
  Assert.IsTrue(LResult.Contains('/// </code>'));
  Assert.IsTrue(LResult.Contains('/// </example>'));
end;

procedure TTestDocCodeGenerator.TestApplyToSource_NewComment;
const
  CSource =
    'type' + sLineBreak +
    '  TMyClass = class' + sLineBreak +
    '    procedure DoSomething;' + sLineBreak +
    '  end;' + sLineBreak;
var
  LElement: TCodeElementInfo;
  LResult: string;
begin
  FModel.Summary := '무언가를 수행합니다.';

  LElement := Default(TCodeElementInfo);
  LElement.Kind := dekMethod;
  LElement.Name := 'DoSomething';
  LElement.LineNumber := 3;  // procedure DoSomething 행
  LElement.IndentLevel := 4;
  LElement.CommentStartLine := -1;
  LElement.CommentEndLine := -1;

  LResult := TDocCodeGenerator.ApplyToSourceText(CSource, LElement, FModel);

  Assert.IsTrue(LResult.Contains('    /// <summary>'));
  Assert.IsTrue(LResult.Contains('    /// 무언가를 수행합니다.'));
  Assert.IsTrue(LResult.Contains('    procedure DoSomething;'));
end;

procedure TTestDocCodeGenerator.TestApplyToSource_ReplaceExisting;
const
  CSource =
    'type' + sLineBreak +
    '  TMyClass = class' + sLineBreak +
    '    /// <summary>이전 설명</summary>' + sLineBreak +
    '    procedure DoSomething;' + sLineBreak +
    '  end;' + sLineBreak;
var
  LElement: TCodeElementInfo;
  LResult: string;
begin
  FModel.Summary := '새로운 설명';

  LElement := Default(TCodeElementInfo);
  LElement.Kind := dekMethod;
  LElement.Name := 'DoSomething';
  LElement.LineNumber := 4;
  LElement.IndentLevel := 4;
  LElement.CommentStartLine := 3;
  LElement.CommentEndLine := 3;

  LResult := TDocCodeGenerator.ApplyToSourceText(CSource, LElement, FModel);

  Assert.IsFalse(LResult.Contains('이전 설명'));
  Assert.IsTrue(LResult.Contains('새로운 설명'));
  Assert.IsTrue(LResult.Contains('    procedure DoSomething;'));
end;

procedure TTestDocCodeGenerator.TestApplyToSource_EmptyModelRemovesComment;
const
  CSource =
    'type' + sLineBreak +
    '  TMyClass = class' + sLineBreak +
    '    /// <summary>제거될 주석</summary>' + sLineBreak +
    '    procedure DoSomething;' + sLineBreak +
    '  end;' + sLineBreak;
var
  LElement: TCodeElementInfo;
  LResult: string;
begin
  // FModel is empty

  LElement := Default(TCodeElementInfo);
  LElement.Kind := dekMethod;
  LElement.Name := 'DoSomething';
  LElement.LineNumber := 4;
  LElement.IndentLevel := 4;
  LElement.CommentStartLine := 3;
  LElement.CommentEndLine := 3;

  LResult := TDocCodeGenerator.ApplyToSourceText(CSource, LElement, FModel);

  Assert.IsFalse(LResult.Contains('제거될 주석'));
  Assert.IsTrue(LResult.Contains('    procedure DoSomething;'));
end;

procedure TTestDocCodeGenerator.TestIndentLevel_Zero;
var
  LResult: string;
begin
  FModel.Summary := '최상위 레벨';
  LResult := TDocCodeGenerator.ModelToCommentBlock(FModel, 0);

  Assert.IsTrue(LResult.StartsWith('/// '));
end;

procedure TTestDocCodeGenerator.TestIndentLevel_Four;
var
  LResult: string;
begin
  FModel.Summary := '4칸 들여쓰기';
  LResult := TDocCodeGenerator.ModelToCommentBlock(FModel, 4);

  Assert.IsTrue(LResult.Contains('    /// '));
end;

procedure TTestDocCodeGenerator.TestCommentBlockFormat;
var
  LParam: TParamDoc;
  LResult: string;
  LLines: TArray<string>;
  LLine: string;
begin
  FModel.Summary := '포맷 테스트';
  LParam.Name := 'AValue';
  LParam.Description := '값';
  FModel.Params.Add(LParam);
  FModel.Returns := '결과';

  LResult := TDocCodeGenerator.ModelToCommentBlock(FModel, 2);
  LLines := LResult.Split([sLineBreak]);

  // 모든 비어있지 않은 줄이 '  /// '로 시작해야 함
  for LLine in LLines do
  begin
    if Trim(LLine) <> '' then
      Assert.IsTrue(LLine.StartsWith('  /// '),
        Format('줄이 올바른 접두사로 시작하지 않습니다: "%s"', [LLine]));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDocCodeGenerator);

end.
