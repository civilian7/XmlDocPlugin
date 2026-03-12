# Delphi XML Documentation WYSIWYG Plugin 설계서

## Context

Delphi의 XML Documentation Comments(삼중주석 `///`)는 수작업으로 XML 태그를 입력해야 하는 불편함이 있다. DocInsight 같은 상용 제품이 존재하지만 고가이며, 오픈소스 대안이 없다. IDE에 통합된 WYSIWYG 에디터 플러그인을 설계하여 XML 문서화를 직관적으로 할 수 있게 한다.

## 요구사항

- **최소 지원 버전**: Delphi 11 Alexandria 이상 (TEdgeBrowser 필수)
- **AST 파서**: [DelphiAST](https://github.com/RomanYankovsky/DelphiAST) (MPL 2.0)
- **WYSIWYG 렌더링**: TEdgeBrowser (WebView2) 내 TipTap 에디터
- **플러그인 형태**: OTA 네이티브 BPL 패키지

## 아키텍처 개요

```
┌──────────────────────────────────────────────────────┐
│                  Delphi IDE (RAD Studio 11+)          │
│                                                      │
│  ┌───────────────┐     ┌───────────────────────────┐ │
│  │  Source Editor │◄───►│     OTA Plugin (BPL)      │ │
│  │  (코드 편집기) │     │                           │ │
│  │               │     │  ┌─────────────────────┐  │ │
│  │  /// <summary>│     │  │  DelphiAST Engine    │  │ │
│  │  /// 설명...  │     │  │  TPasSyntaxTree-     │  │ │
│  │  /// </summary│     │  │  Builder.Run()       │  │ │
│  │  procedure Foo│     │  └──────────┬──────────┘  │ │
│  └───────────────┘     │             │              │ │
│                        │  ┌──────────▼──────────┐  │ │
│                        │  │  AST→Element Mapper  │  │ │
│                        │  │  (TSyntaxNode 탐색)  │  │ │
│                        │  └──────────┬──────────┘  │ │
│  ┌───────────────┐     │             │              │ │
│  │ Doc Inspector │     │  ┌──────────▼──────────┐  │ │
│  │ (도킹 패널)   │     │  │     Doc Model        │  │ │
│  │               │     │  │  (XML ↔ JSON 변환)   │  │ │
│  │ ┌───────────┐ │     │  └──────────┬──────────┘  │ │
│  │ │TEdgeBrowser│◄├─────┤             │              │ │
│  │ │(WebView2)  │ │     │  ┌──────────▼──────────┐  │ │
│  │ │ TipTap     │ │     │  │   Code Generator     │  │ │
│  │ │ WYSIWYG    │ │     │  │  (/// 주석 생성)     │  │ │
│  │ └───────────┘ │     │  └─────────────────────┘  │ │
│  └───────────────┘     └───────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

---

## 핵심 모듈 구성

### 1. OTA Plugin Host (`XmlDocPlugin.dpr` → BPL)

IDE와의 진입점. Open Tools API를 사용하여 다음을 등록한다:

- **IOTAWizard** - 플러그인 등록/해제
- **IOTAEditorNotifier** - 소스 에디터 커서 변경 감지
- **INTACustomDockableForm** - 도킹 패널 생성 (Doc Inspector)
- **IOTAKeyboardBinding** - 단축키 바인딩 (Ctrl+Shift+D 등)

```pascal
TXmlDocPlugin = class(TNotifierObject, IOTAWizard, IOTAMenuWizard)
  procedure Execute;
  function GetIDString: string;
  function GetName: string;
end;

TEditorNotifier = class(TNotifierObject, IOTAEditorNotifier)
  procedure ViewActivated(const View: IOTAEditView);
  procedure ViewNotification(const View: IOTAEditView; Operation: TOperation);
end;
```

---

### 2. Source Parser — DelphiAST 기반 (`uDocParser.pas`)

#### 2-1. DelphiAST 핵심 API

DelphiAST는 Delphi 소스를 파싱하여 `TSyntaxNode` 트리를 반환한다.

```pascal
uses
  DelphiAST, DelphiAST.Classes, DelphiAST.Consts;

// 파일에서 AST 생성
RootNode := TPasSyntaxTreeBuilder.Run('MyUnit.pas');

// 스트림에서 AST 생성 (IDE 에디터 버퍼용)
Builder := TPasSyntaxTreeBuilder.Create;
try
  RootNode := Builder.Run(SourceStream);
finally
  Builder.Free;
end;
```

**TSyntaxNode 주요 속성/메서드:**

| 속성/메서드 | 설명 |
|---|---|
| `Typ: TSyntaxNodeType` | 노드 유형 (ntMethod, ntProperty, ntClass 등) |
| `GetAttribute(anName)` | 이름, 종류 등 속성값 조회 |
| `FindNode(ntXxx)` | 자식 노드 중 특정 타입 검색 |
| `ChildNodes` | 자식 노드 목록 |
| `Line, Col` | 소스 위치 (행, 열) |
| `ParentNode` | 부모 노드 |

**TSyntaxNodeType 중 문서화 대상:**

| 노드 타입 | 대응 코드 요소 |
|---|---|
| `ntUnit` | unit 선언 |
| `ntMethod` | procedure, function, constructor, destructor |
| `ntProperty` | property |
| `ntTypeDecl` + `ntClass` | class 선언 |
| `ntTypeDecl` + `ntRecord` | record 선언 |
| `ntTypeDecl` + `ntInterface` | interface 선언 |
| `ntField` | 필드 |
| `ntConstant` | const |
| `ntParameter` | 메서드 파라미터 |
| `ntGeneric` / `ntTypeParams` | 제네릭 파라미터 |
| `ntSlashesComment` / `TCommentNode` | `///` 주석 |

#### 2-2. AST→Element 매핑 전략

커서 위치(Line, Col)에서 가장 가까운 문서화 대상 요소를 찾는 과정:

```pascal
TDocParser = class
private
  FRootNode: TSyntaxNode;
  FCachedSource: string;
  FCachedHash: Cardinal;     // 소스 변경 감지용

  // AST 트리에서 Line 기준으로 가장 근접한 문서화 대상 노드를 찾음
  function FindNearestDocTarget(ALine: Integer): TSyntaxNode;

  // TSyntaxNode → TCodeElementInfo 변환
  function NodeToElementInfo(ANode: TSyntaxNode): TCodeElementInfo;

  // 메서드 노드에서 파라미터 목록 추출
  function ExtractParams(AMethodNode: TSyntaxNode): TArray<TParamInfo>;

  // 메서드 노드에서 반환타입 추출
  function ExtractReturnType(AMethodNode: TSyntaxNode): string;

  // 제네릭 타입 파라미터 추출
  function ExtractGenericParams(ANode: TSyntaxNode): TArray<string>;

  // 해당 노드 직전의 /// 주석 블록 추출
  function ExtractDocComment(ANode: TSyntaxNode): string;

public
  // 소스 텍스트를 받아 AST를 (재)구축
  procedure ParseSource(const ASource: string);

  // 지정 행에서 문서화 대상 요소 정보 반환
  function GetElementAtLine(ALine: Integer): TCodeElementInfo;

  // AST가 최신 상태인지 (소스 변경 감지)
  function IsUpToDate(const ASource: string): Boolean;
end;
```

#### 2-3. 커서 → 코드 요소 식별 알고리즘

```
입력: CursorLine (현재 커서 행 번호)

1. AST 루트에서 INTERFACE/IMPLEMENTATION 섹션 선택
2. 모든 문서화 대상 노드를 Line 기준 정렬하여 플랫 리스트 구축:
   - ntMethod, ntProperty, ntTypeDecl(class/record/interface),
     ntField, ntConstant
3. 이진 탐색으로 CursorLine 이하인 가장 가까운 노드 찾기:
   - 노드의 Line ≤ CursorLine 이고
   - 다음 노드의 Line > CursorLine
4. 해당 노드가 TCompoundSyntaxNode이면 EndLine 범위 체크
5. 주석이 있으면 CommentStartLine 포함하여 범위 확장
```

#### 2-4. `///` 주석 추출

DelphiAST는 `ntSlashesComment` 타입의 `TCommentNode`를 생성한다. 하지만 주석과 코드 요소의 연결은 직접 구현해야 한다:

```pascal
function TDocParser.ExtractDocComment(ANode: TSyntaxNode): string;
var
  TargetLine: Integer;
  Comments: TStringList;
  I: Integer;
  Lines: TArray<string>;
  Line: string;
begin
  // 코드 요소 직전 행부터 위로 올라가며 연속된 /// 행 수집
  TargetLine := ANode.Line;
  Lines := FCachedSource.Split([#10]);
  Comments := TStringList.Create;
  try
    // 코드 요소 바로 윗줄부터 역순 탐색
    for I := TargetLine - 2 downto 0 do  // 0-based index
    begin
      Line := Lines[I].Trim;
      if Line.StartsWith('///') then
        Comments.Insert(0, Line.Substring(3).Trim)  // /// 프리픽스 제거
      else
        Break;  // 연속되지 않으면 중단
    end;

    // 수집된 줄들을 하나의 XML 문자열로 합침
    if Comments.Count > 0 then
      Result := '<doc>' + Comments.Text + '</doc>'
    else
      Result := '';
  finally
    Comments.Free;
  end;
end;
```

#### 2-5. AST 캐싱 & 증분 업데이트 전략

매번 전체 파싱은 비용이 크므로 캐싱을 적용한다:

```
┌─────────────────────────────────────────┐
│           AST Cache Manager             │
│                                         │
│  소스 해시 비교 ──► 변경 없음 → 캐시 반환│
│       │                                 │
│       ▼ 변경됨                          │
│  전체 재파싱 (TPasSyntaxTreeBuilder)    │
│       │                                 │
│       ▼                                 │
│  플랫 노드 인덱스 재구축 (Line 정렬)   │
│       │                                 │
│       ▼                                 │
│  캐시 저장 (RootNode + FlatIndex)       │
└─────────────────────────────────────────┘
```

**최적화 포인트:**
- `InterfaceOnly := True` 옵션으로 interface 섹션만 파싱 (implementation이 필요 없을 때)
- 해시 비교로 불필요한 재파싱 방지
- 디바운싱(300ms)으로 빠른 타이핑 중 파싱 억제
- 파싱 실패 시 이전 캐시 유지 (타이핑 중 구문 오류 대응)

#### 2-6. 핵심 데이터 구조

```pascal
TDocElementKind = (
  dekUnit,         // unit
  dekClass,        // class
  dekRecord,       // record
  dekInterface,    // interface
  dekMethod,       // procedure, function, constructor, destructor
  dekProperty,     // property
  dekField,        // 필드
  dekType,         // type 선언
  dekConstant      // const
);

TParamInfo = record
  Name: string;       // 파라미터 이름
  TypeName: string;   // 타입명
  DefaultValue: string; // 기본값 (있을 경우)
  IsConst: Boolean;   // const 파라미터 여부
  IsVar: Boolean;     // var 파라미터 여부
  IsOut: Boolean;     // out 파라미터 여부
end;

TCodeElementInfo = record
  Kind: TDocElementKind;
  Name: string;           // 요소 이름
  FullName: string;       // Unit.ClassName.MethodName 전체 경로
  QualifiedParent: string; // 소속 클래스/레코드명
  Visibility: string;     // public, private, protected, published
  Params: TArray<TParamInfo>;
  ReturnType: string;
  GenericParams: TArray<string>;
  MethodKind: string;     // procedure, function, constructor, destructor
  LineNumber: Integer;    // 코드 요소의 시작 행
  EndLineNumber: Integer; // 코드 요소의 종료 행
  IndentLevel: Integer;   // 들여쓰기 수준 (칸 수)
  CommentStartLine: Integer;  // -1 if no existing comment
  CommentEndLine: Integer;
  ExistingDocXml: string;     // 기존 /// 주석 XML (없으면 빈 문자열)
end;
```

#### 2-7. NodeToElementInfo 변환 예시

```pascal
function TDocParser.NodeToElementInfo(ANode: TSyntaxNode): TCodeElementInfo;
var
  TypeNode, ParamsNode, RetNode, GenericNode: TSyntaxNode;
begin
  Result := Default(TCodeElementInfo);
  Result.LineNumber := ANode.Line;

  case ANode.Typ of
    ntMethod:
    begin
      Result.Kind := dekMethod;
      Result.Name := ANode.GetAttribute(anName);
      Result.MethodKind := ANode.GetAttribute(anKind); // 'procedure','function' 등

      // 파라미터 추출
      ParamsNode := ANode.FindNode(ntParameters);
      if Assigned(ParamsNode) then
        Result.Params := ExtractParams(ParamsNode);

      // 반환 타입
      RetNode := ANode.FindNode(ntReturnType);
      if Assigned(RetNode) then
        Result.ReturnType := ExtractReturnType(RetNode);

      // 제네릭
      GenericNode := ANode.FindNode(ntTypeParams);
      if Assigned(GenericNode) then
        Result.GenericParams := ExtractGenericParams(GenericNode);

      // Visibility
      Result.Visibility := ANode.GetAttribute(anVisibility);
    end;

    ntProperty:
    begin
      Result.Kind := dekProperty;
      Result.Name := ANode.GetAttribute(anName);
      // property의 타입, read/write 등은 자식 노드에서 추출
    end;

    ntTypeDecl:
    begin
      Result.Name := ANode.GetAttribute(anName);
      // 하위 타입 노드로 kind 결정
      if Assigned(ANode.FindNode(ntClass)) then
        Result.Kind := dekClass
      else if Assigned(ANode.FindNode(ntRecord)) then
        Result.Kind := dekRecord
      else if Assigned(ANode.FindNode(ntInterface)) then
        Result.Kind := dekInterface
      else
        Result.Kind := dekType;
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
    end;
  end;

  // 부모 추적 (FullName 구성)
  Result.QualifiedParent := BuildParentPath(ANode);
  Result.FullName := Result.QualifiedParent + '.' + Result.Name;

  // 들여쓰기 계산
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
    // CommentStartLine/EndLine은 ExtractDocComment에서 설정
    Result.CommentStartLine := FLastCommentStart;
    Result.CommentEndLine := ANode.Line - 1;
  end
  else
  begin
    Result.CommentStartLine := -1;
    Result.CommentEndLine := -1;
  end;
end;
```

---

### 3. Document Model (`uDocModel.pas`)

XML 주석 내용을 구조화된 객체 모델로 관리한다.

```pascal
TXmlDocModel = class
  Summary: string;
  Remarks: string;
  Returns: string;
  Value: string;
  Params: TList<TParamDoc>;
  TypeParams: TList<TTypeParamDoc>;
  Exceptions: TList<TExceptionDoc>;
  Examples: TList<TExampleDoc>;
  SeeAlso: TList<TSeeAlsoDoc>;

  procedure LoadFromXml(const AXml: string);
  function ToXml: string;
  function ToJson: string;     // WebView 전달용
  procedure FromJson(const AJson: string); // WebView 수신용

  property IsModified: Boolean;
  property OnChanged: TNotifyEvent;
end;

TParamDoc = record
  Name: string;
  Description: string;
end;

TExceptionDoc = record
  TypeRef: string;     // cref 값
  Description: string;
end;

TExampleDoc = record
  Title: string;       // 예제 제목
  Code: string;        // <code> 블록 내용
  Description: string; // 설명 텍스트
end;
```

---

### 4. WYSIWYG Editor (TEdgeBrowser + TipTap)

#### 4-1. 호스트 측 (`uDocInspector.pas`)

도킹 패널에 TEdgeBrowser(WebView2)를 배치한다.

```pascal
TDocInspectorForm = class(TDockableForm)  // INTACustomDockableForm
private
  FBrowser: TEdgeBrowser;
  FDocModel: TXmlDocModel;
  FCurrentElement: TCodeElementInfo;

  procedure BrowserWebMessageReceived(Sender: TCustomEdgeBrowser;
    Args: TWebMessageReceivedEventArgs);
  procedure SendToEditor(const AMessageType, APayload: string);
public
  procedure UpdateFromCursor;   // 커서 이동 시 호출
  procedure SendModelToEditor;  // Delphi → WebView
end;
```

#### 4-2. Delphi ↔ WebView2 통신

```pascal
// Delphi → WebView: ExecuteScript
procedure TDocInspectorForm.SendToEditor(const AMessageType, APayload: string);
var
  Script: string;
begin
  Script := Format('window.bridge.receive(%s)',
    [TJsonObject.Create
       .AddPair('type', AMessageType)
       .AddPair('data', APayload)
       .ToJSON]);
  FBrowser.ExecuteScript(Script);
end;

// WebView → Delphi: PostWebMessageAsJson
procedure TDocInspectorForm.BrowserWebMessageReceived(
  Sender: TCustomEdgeBrowser; Args: TWebMessageReceivedEventArgs);
var
  Json: string;
  Msg: TJsonObject;
begin
  Json := Args.WebMessageAsJson;
  Msg := TJsonObject.ParseJSONValue(Json) as TJsonObject;
  try
    case Msg.GetValue<string>('type') of
      'docUpdated':
      begin
        FDocModel.FromJson(Msg.GetValue<string>('doc'));
        TDocCodeGenerator.ApplyToSource(GetCurrentEditor, FCurrentElement, FDocModel);
      end;
      'requestAutoComplete':
        HandleAutoComplete(Msg);
    end;
  finally
    Msg.Free;
  end;
end;
```

**통신 프로토콜:**
```json
// Delphi → WebView (문서 로드)
{ "type": "loadDoc",
  "data": {
    "element": {
      "kind": "method", "name": "UpdateUser",
      "params": [{"name":"AUserId","type":"Integer"}, ...],
      "returnType": "Boolean"
    },
    "doc": {
      "summary": "사용자 정보를 업데이트합니다.",
      "params": [{"name":"AUserId","description":"대상 사용자 ID"}],
      "returns": "성공 여부"
    }
  }
}

// WebView → Delphi (편집 완료)
{ "type": "docUpdated",
  "doc": { "summary": "...", "params": [...], ... }
}

// WebView → Delphi (자동완성 요청)
{ "type": "requestAutoComplete",
  "prefix": "TMyC",
  "context": "cref"
}
```

#### 4-3. 웹 에디터 (`editor.html` — 단일 파일 번들)

**UI 레이아웃:**
```
┌──────────────────────────────────────┐
│ [procedure DoSomething]  Class: TFoo │  ← 헤더: 현재 코드 요소 정보
├──────────────────────────────────────┤
│ Summary                              │
│ ┌──────────────────────────────────┐ │
│ │ 이 메서드는 무언가를 수행합니다. │ │  ← TipTap 리치 텍스트 에디터
│ │ [B] [I] [Code] [Link] 도구모음  │ │
│ └──────────────────────────────────┘ │
├──────────────────────────────────────┤
│ Parameters                           │
│ ┌─────────┬────────────────────────┐ │
│ │ AName   │ 사용자 이름 [편집]    │ │  ← 코드 시그니처에서 자동 생성
│ │ AValue  │ 설정할 값   [편집]    │ │
│ └─────────┴────────────────────────┘ │
├──────────────────────────────────────┤
│ Returns                              │
│ ┌──────────────────────────────────┐ │
│ │ 성공 여부를 반환합니다.          │ │
│ └──────────────────────────────────┘ │
├──────────────────────────────────────┤
│ ▶ Remarks  ▶ Exceptions  ▶ Examples │  ← 접이식 섹션
│ ▶ See Also                           │
└──────────────────────────────────────┘
```

**기술 스택:**
- 리치 텍스트: **TipTap** (ProseMirror 기반, 커스텀 노드 확장 용이)
- 스타일링: 인라인 CSS (외부 CDN 미사용, 완전 오프라인)
- 번들: Vite `vite-plugin-singlefile`로 단일 HTML 인라인 빌드

**TipTap 커스텀 노드/마크:**

| 커스텀 노드 | XML 태그 | 용도 |
|---|---|---|
| `CodeInline` | `<c>` | 인라인 코드 |
| `CodeBlock` | `<code>` | 코드 블록 |
| `SeeRef` | `<see cref="...">` | 타입/멤버 참조 (자동완성) |
| `ParamRef` | `<paramref name="...">` | 파라미터 참조 |
| `TypeParamRef` | `<typeparamref name="...">` | 제네릭 파라미터 참조 |
| `NoteBlock` | `<note>` | 주의사항 블록 |
| `XmlList` | `<list type="...">` | 목록 (bullet/number/table) |

**bridge.ts — Delphi 통신 레이어:**
```typescript
class DelphiBridge {
  receive(message: { type: string; data: any }) {
    switch (message.type) {
      case 'loadDoc':
        this.loadDocument(message.data.element, message.data.doc);
        break;
      case 'elementChanged':
        this.updateElementHeader(message.data.element);
        break;
    }
  }

  sendToHost(type: string, payload: any) {
    // WebView2 → Delphi
    window.chrome.webview.postMessage(
      JSON.stringify({ type, ...payload })
    );
  }

  private onDocChanged = debounce((doc: DocModel) => {
    this.sendToHost('docUpdated', { doc });
  }, 500);
}

window.bridge = new DelphiBridge();
```

---

### 5. Code Generator (`uDocCodeGen.pas`)

DocModel을 `///` 주석 문자열로 변환하여 소스에 삽입한다.

```pascal
TDocCodeGenerator = class
  class function ModelToCommentBlock(
    const AModel: TXmlDocModel;
    AIndent: Integer = 2
  ): string;

  class procedure ApplyToSource(
    const AEditor: IOTASourceEditor;
    const AElement: TCodeElementInfo;
    const AModel: TXmlDocModel
  );
end;
```

**생성 규칙:**
- 들여쓰기는 `TCodeElementInfo.IndentLevel` 을 따름
- 각 줄은 `/// ` 프리픽스 (공백 1칸 포함)
- 빈 태그는 생략
- 기존 주석 블록이 있으면 `CommentStartLine ~ CommentEndLine` 범위를 교체
- 없으면 `LineNumber` 직전에 새로 삽입

**출력 예시:**
```pascal
  /// <summary>
  /// 지정된 사용자의 정보를 업데이트합니다.
  /// </summary>
  /// <param name="AUserId">대상 사용자 ID</param>
  /// <param name="ANewName">새로운 이름</param>
  /// <returns>업데이트 성공 여부</returns>
  /// <exception cref="EUserNotFoundException">
  /// 사용자를 찾을 수 없을 때 발생
  /// </exception>
  function UpdateUser(AUserId: Integer; const ANewName: string): Boolean;
```

**소스 적용 (OTA 사용):**
```pascal
class procedure TDocCodeGenerator.ApplyToSource(
  const AEditor: IOTASourceEditor;
  const AElement: TCodeElementInfo;
  const AModel: TXmlDocModel);
var
  Writer: IOTAEditWriter;
  CommentBlock: string;
  StartPos, EndPos: Integer;
begin
  CommentBlock := ModelToCommentBlock(AModel, AElement.IndentLevel);
  Writer := AEditor.CreateUndoableWriter;
  try
    if AElement.CommentStartLine >= 0 then
    begin
      // 기존 주석 교체
      StartPos := LineColToPos(AEditor, AElement.CommentStartLine, 1);
      EndPos := LineColToPos(AEditor, AElement.CommentEndLine + 1, 1);
      Writer.CopyTo(StartPos);
      Writer.DeleteTo(EndPos);
      Writer.Insert(PAnsiChar(AnsiString(CommentBlock)));
    end
    else
    begin
      // 새 주석 삽입 (코드 요소 직전)
      StartPos := LineColToPos(AEditor, AElement.LineNumber, 1);
      Writer.CopyTo(StartPos);
      Writer.Insert(PAnsiChar(AnsiString(CommentBlock)));
    end;
  finally
    Writer := nil;
  end;
end;
```

---

### 6. Auto-Stub Generator (`uDocStubGen.pas`)

코드 시그니처에서 빈 문서 템플릿을 자동 생성한다.

```pascal
TDocStubGenerator = class
  class function GenerateStub(
    const AElement: TCodeElementInfo
  ): TXmlDocModel;
end;
```

**동작:**
- 코드 요소에 기존 주석이 없을 때, 시그니처 분석 후 빈 섹션을 가진 DocModel 생성
- 파라미터 이름 규칙에서 힌트 추출:
  - `AFileName` → placeholder "파일 이름"
  - `ACount` → "개수"
  - `AIndex` → "인덱스 (0-based)"
- function이면 `Returns` 섹션 자동 추가
- Boolean 반환 → "True이면 성공" placeholder
- constructor → "새 인스턴스를 생성합니다." 자동 제안

---

## 커서 동기화 워크플로우

```
1. 사용자가 소스 에디터에서 커서 이동
   │
2. IOTAEditorNotifier가 커서 변경 감지
   │ (디바운싱: 300ms)
   │
3. DocParser.IsUpToDate() 확인
   ├─ 소스 변경됨 → ParseSource() 호출 (DelphiAST 재파싱)
   └─ 변경 없음 → 캐시된 AST 사용
   │
4. DocParser.GetElementAtLine(CursorLine)
   │ (이진 탐색으로 가장 가까운 문서화 대상 노드 찾기)
   │
5. 코드 요소가 이전과 동일한가?
   ├─ Yes → 무시 (불필요한 WebView 갱신 방지)
   │
   ├─ No, ExistingDocXml 있음
   │   └→ DocModel.LoadFromXml() → SendModelToEditor()
   │
   └─ No, 주석 없음
       └→ StubGenerator.GenerateStub() → SendModelToEditor()

6. 사용자가 WYSIWYG 에디터에서 편집
   │
7. WebView가 변경된 JSON을 Delphi에 PostMessage
   │ (디바운싱: 500ms)
   │
8. DocModel.FromJson() → CodeGenerator.ApplyToSource()
   └→ IOTAEditWriter로 소스 에디터 주석 블록 교체 (Undo 지원)
```

---

## Part 2 — 일괄 문서 생성 (Help Generator)

프로젝트 전체의 `///` 주석을 수집하여 HTML, CHM, Markdown 등의 도움말 문서로 일괄 변환하는 기능.

### 아키텍처 개요

```
┌───────────────────────────────────────────────────────────┐
│                   Help Generator Pipeline                  │
│                                                           │
│  ┌─────────────┐    ┌─────────────┐    ┌──────────────┐  │
│  │ Project      │    │ Batch       │    │ Doc Symbol   │  │
│  │ Scanner      │───►│ AST Parser  │───►│ Table        │  │
│  │              │    │ (DelphiAST) │    │ (전체 심볼)  │  │
│  │ .dpr/.dpk    │    │             │    │              │  │
│  │ → .pas 목록  │    │ 유닛별 AST  │    │ 유닛/클래스/ │  │
│  │              │    │ + /// 추출  │    │ 메서드/속성  │  │
│  └─────────────┘    └─────────────┘    └──────┬───────┘  │
│                                                │          │
│                                    ┌───────────▼────────┐ │
│                                    │  Cross-Reference   │ │
│                                    │  Resolver           │ │
│                                    │  (<see cref> 링크  │ │
│                                    │   해석 및 연결)     │ │
│                                    └───────────┬────────┘ │
│                                                │          │
│       ┌────────────────────────────────────────┼────┐     │
│       │           Output Renderers             │    │     │
│       │  ┌──────┐  ┌──────┐  ┌──────┐  ┌─────┐│    │     │
│       │  │ HTML │  │ CHM  │  │  MD  │  │JSON ││    │     │
│       │  │멀티  │  │(MS   │  │(GitHub│  │(API ││    │     │
│       │  │페이지│  │ Help)│  │ Wiki)│  │스키마│    │     │
│       │  └──────┘  └──────┘  └──────┘  └─────┘│    │     │
│       └─────────────────────────────────────────────┘     │
└───────────────────────────────────────────────────────────┘
```

### 7. Project Scanner (`uProjectScanner.pas`)

Delphi 프로젝트(.dpr/.dpk) 또는 지정 폴더를 스캔하여 대상 .pas 파일 목록을 수집한다.

```pascal
TScanSource = (
  ssProjectFile,    // .dpr/.dpk 파일의 uses 절에서 추출
  ssDirectory,      // 지정 폴더의 모든 .pas 파일 재귀 탐색
  ssFileList        // 직접 지정한 파일 목록
);

TScanOptions = record
  Source: TScanSource;
  ProjectPath: string;          // .dpr/.dpk 경로 또는 폴더 경로
  FileList: TArray<string>;     // ssFileList 용
  ExcludePatterns: TArray<string>; // 제외 패턴 (예: '*Test*', 'vendor\*')
  IncludePrivate: Boolean;      // private 멤버 포함 여부
  IncludeImplementation: Boolean; // implementation 섹션 포함 여부
  InterfaceOnly: Boolean;       // interface 섹션만 (기본: True)
end;

TProjectScanner = class
  function Scan(const AOptions: TScanOptions): TArray<string>;
private
  // .dpr/.dpk 파일을 파싱하여 uses 절의 유닛 경로 추출
  function ParseProjectUses(const AProjectPath: string): TArray<string>;
  // 검색 경로에서 .pas 파일의 실제 경로를 찾음
  function ResolveUnitPath(const AUnitName: string;
    const ASearchPaths: TArray<string>): string;
end;
```

**프로젝트 파일 파싱:**
```
┌─────────────────────────────┐
│  MyProject.dpr               │
│                              │
│  uses                        │
│    uMainForm in 'src\...',  │ ──► 직접 경로
│    uDataModule,              │ ──► 검색 경로에서 찾기
│    uUtils;                   │ ──► 검색 경로에서 찾기
└─────────────────────────────┘
         │
         ▼
  검색 경로 (프로젝트 설정 또는 수동 지정):
  ① 프로젝트 폴더
  ② $(DCC_UnitSearchPath) 에서 추출
  ③ 사용자 추가 경로
```

### 8. Batch AST Parser (`uBatchParser.pas`)

수집된 .pas 파일 전체를 DelphiAST로 파싱하여 통합 심볼 테이블을 구축한다.

```pascal
TUnitDocInfo = class
  UnitName: string;
  FilePath: string;
  UnitDoc: TXmlDocModel;          // unit 자체의 /// 주석
  Types: TObjectList<TTypeDocInfo>;
  StandaloneMethods: TObjectList<TElementDocInfo>; // 유닛 레벨 함수
  Constants: TObjectList<TElementDocInfo>;
  Variables: TObjectList<TElementDocInfo>;
end;

TTypeDocInfo = class
  Name: string;
  FullName: string;               // UnitName.TypeName
  Kind: TDocElementKind;          // class, record, interface
  Visibility: string;
  Doc: TXmlDocModel;
  Ancestor: string;               // 부모 클래스/인터페이스
  Implements: TArray<string>;     // 구현 인터페이스 목록
  Members: TObjectList<TElementDocInfo>;  // 메서드, 속성, 필드
  NestedTypes: TObjectList<TTypeDocInfo>; // 중첩 타입
end;

TElementDocInfo = class
  Name: string;
  FullName: string;               // UnitName.TypeName.MemberName
  Kind: TDocElementKind;
  Visibility: string;
  Signature: string;              // 원본 선언 텍스트 (function Foo(...): Bar;)
  Doc: TXmlDocModel;
  CodeElement: TCodeElementInfo;  // 상세 시그니처 정보
end;

TBatchParser = class
private
  FParser: TDocParser;
  FUnits: TObjectList<TUnitDocInfo>;
  FSymbolIndex: TDictionary<string, TElementDocInfo>; // FullName → Element
  FProgress: TProgressCallback;

  procedure ParseUnit(const AFilePath: string);
  procedure BuildSymbolIndex;

public
  procedure ParseAll(const AFiles: TArray<string>);

  property Units: TObjectList<TUnitDocInfo>;
  property SymbolIndex: TDictionary<string, TElementDocInfo>;
  property OnProgress: TProgressCallback;
end;
```

**일괄 파싱 워크플로우:**
```
입력: .pas 파일 목록 (N개)

For Each .pas file:
  │
  1. TPasSyntaxTreeBuilder.Run(FilePath) → AST
  │
  2. AST에서 INTERFACE 섹션의 모든 문서화 대상 노드 수집:
  │   - ntTypeDecl (class, record, interface)
  │   - ntMethod (유닛 레벨 함수)
  │   - ntConstant, ntVariable
  │
  3. 각 노드에 대해:
  │   ├─ TCodeElementInfo 추출 (NodeToElementInfo)
  │   ├─ 기존 /// 주석 추출 (ExtractDocComment)
  │   └─ TXmlDocModel 생성 (LoadFromXml 또는 빈 모델)
  │
  4. TTypeDocInfo에서 멤버 노드 재귀 탐색:
  │   ├─ ntMethod → 메서드
  │   ├─ ntProperty → 속성
  │   ├─ ntField → 필드
  │   └─ 중첩 ntTypeDecl → 재귀
  │
  5. UnitDocInfo에 취합
  │
  6. OnProgress 콜백 (진행률 보고)

완료 후:
  BuildSymbolIndex() → FullName 기반 전역 심볼 딕셔너리 구축
```

### 9. Cross-Reference Resolver (`uCrossRefResolver.pas`)

`<see cref="TMyClass.DoSomething">` 같은 참조를 실제 심볼 위치로 연결한다.

```pascal
TCrossRefResolver = class
private
  FSymbolIndex: TDictionary<string, TElementDocInfo>;
  FUnresolved: TList<TUnresolvedRef>;

public
  constructor Create(ASymbolIndex: TDictionary<string, TElementDocInfo>);

  // cref 문자열 → 대상 심볼의 FullName 해석
  // 예: "TMyClass.DoSomething" → "MyUnit.TMyClass.DoSomething"
  function ResolveCref(const ACref: string;
    const AContext: TElementDocInfo): string;

  // 전체 문서 모델에서 <see>, <seealso>, <exception> 의 cref를 일괄 해석
  procedure ResolveAllRefs(const AUnits: TObjectList<TUnitDocInfo>);

  // 해석 실패한 참조 목록
  property Unresolved: TList<TUnresolvedRef>;
end;

TUnresolvedRef = record
  Cref: string;           // 원본 cref 값
  SourceElement: string;  // 참조가 위치한 요소의 FullName
  SourceFile: string;     // 소스 파일 경로
  Line: Integer;          // 소스 행 번호
end;
```

**cref 해석 규칙:**
```
입력: cref="TMyClass.DoSomething", 컨텍스트: MyUnit.TFoo.Bar

탐색 순서:
  1. 정확히 일치: SymbolIndex["TMyClass.DoSomething"]
  2. 같은 유닛 내: SymbolIndex["MyUnit.TMyClass.DoSomething"]
  3. uses 절 유닛에서: SymbolIndex["OtherUnit.TMyClass.DoSomething"]
  4. 부분 매칭: "*.TMyClass.DoSomething"
  5. 해석 불가 → Unresolved에 추가 (경고 출력)
```

### 10. Output Renderers (`uDocRenderer*.pas`)

통합된 심볼 테이블을 다양한 출력 형식으로 렌더링한다.

#### 10-1. 공통 렌더러 인터페이스

```pascal
TRenderOptions = record
  OutputDir: string;            // 출력 폴더
  Title: string;                // 프로젝트/문서 제목
  IncludePrivate: Boolean;      // private 멤버 포함
  IncludeSource: Boolean;       // 소스 코드 스니펫 포함
  IncludeInheritanceTree: Boolean; // 상속 트리 표시
  IncludeSearchIndex: Boolean;  // 검색용 인덱스 생성 (HTML용)
  CSSTheme: string;             // CSS 테마 이름 (HTML용)
  LogoPath: string;             // 커스텀 로고 (HTML용)
  FooterText: string;           // 하단 텍스트
end;

IDocRenderer = interface
  procedure Render(
    const AUnits: TObjectList<TUnitDocInfo>;
    const AResolver: TCrossRefResolver;
    const AOptions: TRenderOptions
  );
end;
```

#### 10-2. HTML Renderer (`uDocRendererHTML.pas`)

멀티 페이지 정적 HTML 사이트를 생성한다.

```pascal
THTMLDocRenderer = class(TInterfacedObject, IDocRenderer)
  procedure Render(...);
private
  procedure RenderIndex(const AUnits: ...);       // index.html (전체 목록)
  procedure RenderUnitPage(const AUnit: ...);     // UnitName.html
  procedure RenderTypePage(const AType: ...);     // UnitName.TypeName.html
  procedure RenderMemberSection(const AElem: ...);// 페이지 내 멤버 섹션
  procedure RenderNavSidebar;                      // 좌측 네비게이션
  procedure RenderSearchIndex;                     // search-index.json
  procedure CopyStaticAssets;                      // CSS, JS, 아이콘
end;
```

**생성되는 HTML 구조:**
```
output/
├── index.html                    // 프로젝트 개요 + 유닛 목록
├── toc.html                      // 전체 목차 (트리 뷰)
├── search.html                   // 클라이언트 사이드 검색
├── units/
│   ├── MyUnit.html               // 유닛 페이지
│   ├── MyUnit.TMyClass.html      // 클래스 상세 페이지
│   ├── MyUnit.TMyRecord.html
│   └── ...
├── assets/
│   ├── style.css                 // 테마 CSS
│   ├── script.js                 // 네비게이션, 검색, 토글
│   ├── highlight.js              // 코드 구문 강조
│   └── search-index.json         // 검색 인덱스
└── inheritance/
    └── tree.html                 // 클래스 상속 트리 시각화
```

**HTML 페이지 레이아웃:**
```
┌─────────────────────────────────────────────────────────┐
│  [로고] MyProject API Reference          [검색 🔍]     │
├──────────┬──────────────────────────────────────────────┤
│ 네비게이션│  TMyClass                       MyUnit.pas  │
│          │                                              │
│ ▼ MyUnit │  상속: TObject → TComponent → TMyClass       │
│   TMyClass│  구현: ISerializable, ICloneable             │
│   TFoo   │                                              │
│   TBar   │  Summary                                     │
│ ▼ Utils  │  ───────────────────────────────              │
│   THelper│  이 클래스는 사용자 데이터를 관리합니다.     │
│          │                                              │
│          │  Remarks                                      │
│          │  ───────────────────────────────              │
│          │  스레드 세이프하며, 내부적으로 잠금을...      │
│          │                                              │
│          │  Public Methods                               │
│          │  ┌──────────────┬─────────────────────┐      │
│          │  │ UpdateUser   │ 사용자 정보 업데이트│      │
│          │  │ DeleteUser   │ 사용자 삭제         │      │
│          │  │ FindUser     │ 사용자 검색         │      │
│          │  └──────────────┴─────────────────────┘      │
│          │                                              │
│          │  ━━ UpdateUser ━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│          │  function UpdateUser(AUserId: Integer;        │
│          │    const ANewName: string): Boolean;          │
│          │                                              │
│          │  사용자 정보를 업데이트합니다.                │
│          │                                              │
│          │  Parameters:                                  │
│          │  • AUserId — 대상 사용자 ID                  │
│          │  • ANewName — 새로운 이름                    │
│          │                                              │
│          │  Returns: 업데이트 성공 여부                  │
│          │                                              │
│          │  Exceptions:                                  │
│          │  • EUserNotFoundException — 사용자를 찾을...  │
│          │                                              │
│          │  See Also: FindUser, DeleteUser               │
├──────────┴──────────────────────────────────────────────┤
│  Generated by XmlDocPlugin — 2026-03-03                 │
└─────────────────────────────────────────────────────────┘
```

#### 10-3. Markdown Renderer (`uDocRendererMD.pas`)

GitHub Wiki / GitBook 호환 마크다운을 생성한다.

```pascal
TMarkdownDocRenderer = class(TInterfacedObject, IDocRenderer)
  procedure Render(...);
private
  procedure RenderUnitMD(const AUnit: TUnitDocInfo);
  procedure RenderTypeMD(const AType: TTypeDocInfo);
  function XmlTagToMarkdown(const AXml: string): string; // XML → MD 변환
end;
```

**생성 구조:**
```
docs/
├── README.md                    // 프로젝트 개요
├── SUMMARY.md                   // GitBook 목차
├── units/
│   ├── MyUnit.md
│   ├── MyUnit.TMyClass.md
│   └── ...
└── _sidebar.md                  // GitHub Wiki 사이드바
```

**Markdown 변환 규칙:**

| XML 태그 | Markdown 변환 |
|---|---|
| `<summary>` | 최상단 설명 단락 |
| `<remarks>` | `## Remarks` 섹션 |
| `<param name="X">desc</param>` | `- **X** — desc` |
| `<returns>` | `**Returns:** desc` |
| `<exception cref="E">` | `**Raises** `E` — desc` |
| `<example><code>...</code></example>` | ````pascal ... ``` 코드 블록 |
| `<c>text</c>` | `` `text` `` |
| `<see cref="T">` | `[T](./UnitName.T.md)` 링크 |
| `<seealso cref="T">` | **See Also** 섹션에 링크 목록 |
| `<note>` | `> **Note:** ...` 블록쿼트 |
| `<list type="bullet">` | `- item` 불릿 리스트 |
| `<list type="number">` | `1. item` 번호 리스트 |
| `<para>` | 빈 줄 (단락 구분) |

#### 10-3-1. 정적 사이트 퍼블리싱 (`uSitePublisher.pas`)

Markdown Renderer의 출력을 MkDocs, Docusaurus, VitePress 등의 정적 사이트 생성기 구조에 맞춰 퍼블리싱 가능한 프로젝트로 변환한다.

```pascal
TSiteGenerator = (
  sgMkDocs,         // Python 기반, Material 테마
  sgDocusaurus,     // React 기반, Meta 주도
  sgVitePress,      // Vue 기반, 빠른 빌드
  sgGitBookV2       // GitBook v2 (오픈소스 클래식)
);

TSitePublishOptions = record
  Generator: TSiteGenerator;
  SiteName: string;           // 사이트 제목
  BaseURL: string;            // 배포 URL (예: /docs/)
  RepoURL: string;            // GitHub 레포 URL (선택)
  LogoPath: string;           // 사이트 로고
  ExtraNavItems: TArray<TNavItem>; // 추가 네비게이션 (가이드, 변경이력 등)
  AutoBuild: Boolean;         // 생성 후 빌드까지 자동 실행
end;

TSitePublisher = class
  procedure Publish(
    const AUnits: TObjectList<TUnitDocInfo>;
    const AResolver: TCrossRefResolver;
    const AOptions: TSitePublishOptions;
    const ARenderOptions: TRenderOptions
  );
private
  FMDRenderer: TMarkdownDocRenderer;

  procedure GenerateMkDocs(const AOutputDir: string; const AOpts: TSitePublishOptions);
  procedure GenerateDocusaurus(const AOutputDir: string; const AOpts: TSitePublishOptions);
  procedure GenerateVitePress(const AOutputDir: string; const AOpts: TSitePublishOptions);
end;
```

**MkDocs 출력 구조:**
```
site-mkdocs/
├── mkdocs.yml                         // MkDocs 설정
├── docs/
│   ├── index.md                       // 홈
│   ├── api/
│   │   ├── index.md                   // API 개요 + 유닛 목록
│   │   ├── MyUnit.md                  // 유닛 페이지
│   │   ├── MyUnit.TMyClass.md         // 클래스 페이지
│   │   └── ...
│   └── coverage.md                    // 커버리지 리포트 (선택)
└── overrides/                         // Material 테마 커스터마이징
```

**mkdocs.yml 자동 생성:**
```yaml
site_name: MyProject API Reference
site_url: https://myproject.github.io/docs/
repo_url: https://github.com/myorg/myproject
theme:
  name: material
  language: ko
  palette:
    - scheme: default
      primary: indigo
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - scheme: slate
      primary: indigo
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.instant
    - navigation.sections
    - navigation.expand
    - search.suggest
    - content.code.copy
plugins:
  - search
  - minify:
      minify_html: true
markdown_extensions:
  - admonition
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.superfences
  - pymdownx.details
  - toc:
      permalink: true
nav:
  - Home: index.md
  - API Reference:
    - Overview: api/index.md
    - MyUnit:
      - MyUnit: api/MyUnit.md
      - TMyClass: api/MyUnit.TMyClass.md
      - TFoo: api/MyUnit.TFoo.md
    - Utils:
      - Utils: api/Utils.md
      - THelper: api/Utils.THelper.md
  - Coverage: coverage.md
```

**Docusaurus 출력 구조:**
```
site-docusaurus/
├── docusaurus.config.js              // Docusaurus 설정
├── sidebars.js                        // 사이드바 구조
├── docs/
│   ├── intro.md                       // 홈
│   ├── api/
│   │   ├── _category_.json            // 카테고리 메타
│   │   ├── MyUnit.md
│   │   ├── MyUnit.TMyClass.md
│   │   └── ...
│   └── coverage.md
├── src/
│   └── css/
│       └── custom.css                 // 커스텀 스타일
├── static/
│   └── img/
│       └── logo.svg
└── package.json
```

**VitePress 출력 구조:**
```
site-vitepress/
├── .vitepress/
│   └── config.mts                    // VitePress 설정
├── api/
│   ├── index.md
│   ├── MyUnit.md
│   ├── MyUnit.TMyClass.md
│   └── ...
├── index.md                           // 홈
└── package.json
```

**MkDocs Admonition 활용 — XML 태그 매핑:**

| XML 태그 | MkDocs Admonition |
|---|---|
| `<note>` | `!!! note "참고"` |
| `<note type="warning">` | `!!! warning "주의"` |
| `<note type="caution">` | `!!! danger "위험"` |
| `<note type="tip">` | `!!! tip "팁"` |
| `<example>` | `!!! example "예제"` |
| `<exception>` | `!!! failure "예외"` |
| `<permission>` | `!!! info "권한"` |

**CLI 연동:**
```
XmlDocGen.exe -p MyProject.dpr -o site -f mkdocs --site-name "My API"
XmlDocGen.exe -p MyProject.dpr -o site -f docusaurus --base-url /docs/
XmlDocGen.exe -p MyProject.dpr -o site -f vitepress --repo-url https://github.com/...
```

**CI/CD 배포 파이프라인 예시:**
```yaml
# GitHub Actions: MkDocs → GitHub Pages
name: Deploy API Docs
on:
  push:
    branches: [main]
    paths: ['src/**/*.pas']

jobs:
  deploy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate Markdown
        run: XmlDocGen.exe -p MyProject.dpr -o site -f mkdocs --coverage

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.x'

      - name: Install MkDocs
        run: pip install mkdocs-material mkdocs-minify-plugin

      - name: Build & Deploy
        run: cd site && mkdocs gh-deploy --force
```

```yaml
# Vercel 배포: Docusaurus
name: Deploy API Docs (Vercel)
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Generate Docusaurus
        run: XmlDocGen.exe -p MyProject.dpr -o site -f docusaurus
      - name: Build
        run: cd site && npm install && npm run build
      - uses: amondnet/vercel-action@v25
        with:
          working-directory: site
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
```

---

#### 10-4. CHM Renderer (`uDocRendererCHM.pas`)

Windows 도움말(CHM) 형식을 생성한다. 내부적으로 HTML을 먼저 생성한 뒤 HTML Help Workshop의 `hhc.exe` 컴파일러를 호출한다.

```pascal
TCHMDocRenderer = class(TInterfacedObject, IDocRenderer)
  procedure Render(...);
private
  FHTMLRenderer: THTMLDocRenderer;  // HTML 먼저 생성

  // HTML Help 프로젝트 파일 생성
  procedure GenerateHHP(const AOptions: TRenderOptions);  // .hhp 프로젝트
  procedure GenerateHHC(const AUnits: ...);               // .hhc 목차
  procedure GenerateHHK(const AUnits: ...);               // .hhk 인덱스

  // hhc.exe 호출하여 CHM 컴파일
  procedure CompileCHM(const AHHPPath: string);
end;
```

**CHM 파일 생성 과정:**
```
1. HTML Renderer로 기본 HTML 페이지 생성
   │
2. .hhp (프로젝트 파일) 생성
   │  - 포함할 HTML 파일 목록
   │  - 기본 페이지, 제목, 압축 설정
   │
3. .hhc (목차 파일) 생성
   │  - 유닛 → 타입 → 멤버 계층 구조
   │  - SITEMAP 형식의 XML
   │
4. .hhk (인덱스 파일) 생성
   │  - 모든 심볼의 알파벳 인덱스
   │  - 검색용 키워드
   │
5. hhc.exe 실행 → .chm 출력
   │  (HTML Help Workshop 필요 — 없으면 경고 후 HTML만 출력)
```

#### 10-5. JSON Schema Renderer (`uDocRendererJSON.pas`)

기계 판독 가능한 JSON 형식으로 전체 API 문서를 출력한다. 외부 도구 연동이나 커스텀 렌더러 구축에 활용.

```pascal
TJSONDocRenderer = class(TInterfacedObject, IDocRenderer)
  procedure Render(...);
end;
```

**출력 JSON 구조:**
```json
{
  "project": "MyProject",
  "generated": "2026-03-03T10:00:00Z",
  "units": [
    {
      "name": "MyUnit",
      "path": "src/MyUnit.pas",
      "doc": { "summary": "유틸리티 유닛" },
      "types": [
        {
          "name": "TMyClass",
          "fullName": "MyUnit.TMyClass",
          "kind": "class",
          "ancestor": "TComponent",
          "implements": ["ISerializable"],
          "doc": {
            "summary": "사용자 데이터를 관리하는 클래스",
            "remarks": "스레드 세이프하며..."
          },
          "members": [
            {
              "name": "UpdateUser",
              "kind": "method",
              "visibility": "public",
              "signature": "function UpdateUser(AUserId: Integer; const ANewName: string): Boolean;",
              "doc": {
                "summary": "사용자 정보를 업데이트합니다.",
                "params": [
                  { "name": "AUserId", "description": "대상 사용자 ID" }
                ],
                "returns": "업데이트 성공 여부",
                "exceptions": [
                  { "type": "EUserNotFoundException", "description": "..." }
                ],
                "seeAlso": ["FindUser", "DeleteUser"]
              }
            }
          ]
        }
      ]
    }
  ]
}
```

### 11. 문서화 커버리지 리포트 (`uDocCoverageReport.pas`)

프로젝트의 문서화 완성도를 측정하고 리포트를 생성한다.

```pascal
TCoverageLevel = (
  clNone,         // 주석 없음
  clSummaryOnly,  // summary만 있음
  clPartial,      // summary + 일부 param/returns
  clComplete      // 모든 관련 태그 작성됨
);

TCoverageItem = record
  ElementFullName: string;
  Kind: TDocElementKind;
  Visibility: string;
  Level: TCoverageLevel;
  MissingTags: TArray<string>;  // 누락된 태그 목록 (예: 'param:AName', 'returns')
end;

TCoverageStats = record
  TotalElements: Integer;       // 전체 문서화 대상
  Documented: Integer;          // summary 이상 있는 요소
  Complete: Integer;            // 완전히 문서화된 요소
  CoveragePercent: Double;      // (Documented / Total) * 100
  CompletePercent: Double;      // (Complete / Total) * 100

  ByKind: TDictionary<TDocElementKind, Integer>;  // 종류별 통계
  ByVisibility: TDictionary<string, Integer>;     // 가시성별 통계
  ByUnit: TDictionary<string, Double>;            // 유닛별 커버리지
end;

TDocCoverageReport = class
  function Analyze(
    const AUnits: TObjectList<TUnitDocInfo>
  ): TCoverageStats;

  function GetUndocumented(
    const AUnits: TObjectList<TUnitDocInfo>;
    AMinVisibility: string = 'public'
  ): TArray<TCoverageItem>;

  // 리포트 출력
  procedure RenderConsoleReport(const AStats: TCoverageStats);
  procedure RenderHTMLReport(const AStats: TCoverageStats;
    const AItems: TArray<TCoverageItem>;
    const AOutputPath: string);
end;
```

**커버리지 측정 기준:**

| 코드 요소 | Complete 조건 |
|---|---|
| class/record/interface | summary 필수, remarks 권장 |
| method (procedure) | summary + 모든 param |
| method (function) | summary + 모든 param + returns |
| property | summary (또는 value) |
| 제네릭 타입 | summary + 모든 typeparam |
| public exception 발생 메서드 | exception 태그 권장 |

**리포트 출력 예시:**
```
╔══════════════════════════════════════════════════╗
║          Documentation Coverage Report           ║
╠══════════════════════════════════════════════════╣
║  Overall:  142/198 public elements (71.7%)       ║
║  Complete: 89/198 (44.9%)                        ║
╠──────────────────────────────────────────────────╣
║  By Type:                                        ║
║    Classes:     12/15 (80.0%)                    ║
║    Methods:     98/145 (67.6%)                   ║
║    Properties:  25/30 (83.3%)                    ║
║    Constants:   7/8 (87.5%)                      ║
╠──────────────────────────────────────────────────╣
║  By Unit:                                        ║
║    MyUnit.pas          95.0%  ████████████████░  ║
║    DataModule.pas      62.3%  ██████████░░░░░░░  ║
║    Utils.pas           45.0%  ███████░░░░░░░░░░  ║
║    Legacy.pas          12.5%  ██░░░░░░░░░░░░░░░  ║
╠──────────────────────────────────────────────────╣
║  Undocumented (public):                          ║
║    ✗ Utils.TStringHelper.SplitEx                 ║
║    ✗ DataModule.TDM.OnConnect (missing: param)   ║
║    ✗ Legacy.TParser (missing: summary)           ║
║    ... 53 more                                   ║
╚══════════════════════════════════════════════════╝
```

### 12. IDE 통합 — 일괄 생성 UI

#### 12-1. 메뉴 통합

```
Tools (IDE 메뉴)
  └── XmlDoc Plugin
       ├── Toggle Doc Inspector     (Ctrl+Shift+D)
       ├── Generate Doc Stub        (Ctrl+Shift+G)  ← 현재 요소에 빈 주석 생성
       ├── ────────────────
       ├── Generate Help...          → 일괄 생성 다이얼로그
       ├── Coverage Report...        → 커버리지 리포트
       └── Settings...               → 설정 다이얼로그
```

#### 12-2. 일괄 생성 다이얼로그 (`uBatchGenDialog.pas`)

```
┌─────────────────────────────────────────────────┐
│  Generate API Documentation                      │
├─────────────────────────────────────────────────┤
│                                                  │
│  Source:                                         │
│  ○ Current Project (MyProject.dpr)               │
│  ○ Directory: [C:\MyProject\src        ] [...]  │
│  ○ File List: [편집...]                          │
│                                                  │
│  Exclude: [*Test*; vendor\*          ]           │
│                                                  │
│  Output Format:                                  │
│  ☑ HTML (Multi-page website)                     │
│  ☐ CHM (Windows Help)                            │
│  ☑ Markdown (GitHub Wiki)                        │
│  ☐ JSON (Machine-readable)                       │
│  ── Static Site ──                               │
│  ☐ MkDocs (Material theme)                       │
│  ☐ Docusaurus (React-based)                      │
│  ☐ VitePress (Vue-based)                         │
│                                                  │
│  Output Directory:                               │
│  [C:\MyProject\docs                    ] [...]  │
│                                                  │
│  Options:                                        │
│  ☑ Include private members                       │
│  ☑ Include source code snippets                  │
│  ☑ Include inheritance tree                      │
│  ☑ Generate search index                         │
│  ☐ Interface section only                        │
│                                                  │
│  Title: [MyProject API Reference     ]           │
│  Theme: [Default        ▼]                       │
│                                                  │
│  ☑ Generate coverage report                      │
│  ☑ Warn on unresolved cross-references           │
│                                                  │
│        [Generate]  [Preview]  [Cancel]           │
└─────────────────────────────────────────────────┘
```

#### 12-3. 진행 표시 다이얼로그

```
┌─────────────────────────────────────────────────┐
│  Generating Documentation...                     │
├─────────────────────────────────────────────────┤
│                                                  │
│  ████████████████████░░░░░░░░░  65%              │
│                                                  │
│  Phase: Rendering HTML pages                     │
│  Current: MyUnit.TMyClass (42/65 types)          │
│                                                  │
│  Parsed: 23 units, 198 elements                  │
│  Warnings: 3 unresolved references               │
│  Elapsed: 00:12                                  │
│                                                  │
│              [Cancel]                             │
└─────────────────────────────────────────────────┘
```

#### 12-4. 커맨드라인 모드 (`XmlDocGen.exe`)

CI/CD 통합을 위한 별도 커맨드라인 도구. BPL과 코어 모듈을 공유한다.

```
XmlDocGen.exe [options]

옵션:
  -p, --project <path>      .dpr/.dpk 프로젝트 파일
  -d, --directory <path>    소스 디렉토리 (프로젝트 대신)
  -o, --output <path>       출력 디렉토리
  -f, --format <formats>    출력 형식 (html,chm,md,json,mkdocs,docusaurus,vitepress) 쉼표 구분
  -t, --title <title>       문서 제목
  --base-url <url>          사이트 기본 URL (정적 사이트용)
  --repo-url <url>          GitHub 레포 URL (정적 사이트용)
  --site-name <name>        사이트 이름 (정적 사이트용, 기본: --title)
  --auto-build              정적 사이트 생성 후 빌드까지 실행
  --exclude <patterns>      제외 패턴 (세미콜론 구분)
  --include-private         private 멤버 포함
  --interface-only          interface 섹션만
  --coverage                커버리지 리포트 생성
  --coverage-min <percent>  최소 커버리지 (미달 시 exit code 1)
  --theme <name>            CSS 테마
  --quiet                   진행 출력 없음
  --verbose                 상세 출력

예시:
  XmlDocGen.exe -p MyProject.dpr -o docs -f html,md --coverage
  XmlDocGen.exe -d src -o docs -f json --interface-only --quiet
  XmlDocGen.exe -p MyProject.dpr --coverage --coverage-min 80
  XmlDocGen.exe -p MyProject.dpr -o site -f mkdocs --site-name "My API"
  XmlDocGen.exe -p MyProject.dpr -o site -f docusaurus --base-url /docs/ --auto-build
```

**CI 연동 예시 (GitHub Actions):**
```yaml
- name: Generate API Docs
  run: |
    XmlDocGen.exe -p MyProject.dpr -o docs -f html,md --coverage --coverage-min 70
- name: Deploy to Pages
  uses: peaceiris/actions-gh-pages@v4
  with:
    publish_dir: ./docs/html
```

---

### 일괄 생성 파이프라인 전체 플로우

```
┌──────────────────────────────────────────────────────────┐
│                  Generate Help Pipeline                    │
│                                                          │
│  1. Project Scanner                                      │
│     .dpr/.dpk 파싱 또는 디렉토리 스캔                    │
│     → .pas 파일 목록 수집                                │
│     │                                                    │
│  2. Batch AST Parser                                     │
│     각 .pas에 DelphiAST 실행                             │
│     → UnitDocInfo 목록 + SymbolIndex 구축                │
│     │                                                    │
│  3. Cross-Reference Resolver                             │
│     <see cref>, <seealso cref>, <exception cref> 해석   │
│     → 링크 대상 FullName 확정, 미해석 목록 수집         │
│     │                                                    │
│  4. Coverage Analysis (선택)                              │
│     문서화 완성도 측정                                   │
│     → 커버리지 리포트 생성                               │
│     │                                                    │
│  5. Output Rendering                                     │
│     선택된 형식별 렌더러 실행                            │
│     ├─ HTML: 멀티페이지 + 검색 + 네비게이션             │
│     ├─ CHM: HTML 생성 → hhc.exe 컴파일                   │
│     ├─ Markdown: GitHub Wiki / GitBook 호환              │
│     └─ JSON: 기계 판독용 스키마                          │
│     │                                                    │
│  6. Post-processing                                      │
│     경고/에러 요약 출력                                  │
│     미해석 cref 목록 출력                                │
│     생성 통계 출력                                       │
└──────────────────────────────────────────────────────────┘
```

---

## 프로젝트 구조

```
XmlDocPlugin/
├── src/
│   ├── Core/                          // ═══ 코어 모듈 (BPL + CLI 공유) ═══
│   │   ├── uDocParser.pas             // DelphiAST 기반 소스 파서
│   │   ├── uDocModel.pas              // 문서 모델 (XML ↔ JSON)
│   │   ├── uDocCodeGen.pas            // /// 주석 코드 생성기
│   │   ├── uDocStubGen.pas            // 스텁 생성기
│   │   └── uConsts.pas                // 상수, 유틸
│   │
│   ├── Plugin/                        // ═══ IDE 플러그인 (BPL) ═══
│   │   ├── XmlDocPlugin.dpr           // BPL 패키지 프로젝트
│   │   ├── XmlDocPlugin.dpk           // 패키지 소스
│   │   ├── uPluginMain.pas            // OTA 등록/해제
│   │   ├── uEditorNotifier.pas        // 에디터 이벤트 감시
│   │   ├── uDocInspector.pas          // TEdgeBrowser 도킹 패널
│   │   └── uBatchGenDialog.pas        // 일괄 생성 다이얼로그 (VCL)
│   │
│   ├── HelpGen/                       // ═══ 일괄 문서 생성 엔진 ═══
│   │   ├── uProjectScanner.pas        // 프로젝트/폴더 스캐너
│   │   ├── uBatchParser.pas           // 전체 AST 파싱 + 심볼 테이블
│   │   ├── uCrossRefResolver.pas      // <see cref> 상호참조 해석
│   │   ├── uDocCoverageReport.pas     // 문서화 커버리지 리포트
│   │   ├── uDocRenderer.pas           // IDocRenderer 인터페이스
│   │   ├── uDocRendererHTML.pas       // HTML 멀티페이지 렌더러
│   │   ├── uDocRendererMD.pas         // Markdown 렌더러
│   │   ├── uDocRendererCHM.pas        // CHM 렌더러
│   │   └── uDocRendererJSON.pas       // JSON 스키마 렌더러
│   │
│   └── CLI/                           // ═══ 커맨드라인 도구 ═══
│       ├── XmlDocGen.dpr              // CLI 실행 파일 프로젝트
│       └── uCLIMain.pas               // 커맨드라인 파서 + 실행
│
├── vendor/
│   └── DelphiAST/                     // Git submodule
│       ├── Source/
│       │   ├── DelphiAST.pas
│       │   ├── DelphiAST.Classes.pas
│       │   ├── DelphiAST.Consts.pas
│       │   └── ...
│       └── LICENSE
│
├── web/
│   ├── src/
│   │   ├── editor.ts                  // TipTap 에디터 메인
│   │   ├── bridge.ts                  // Delphi ↔ WebView2 통신
│   │   ├── nodes/                     // 커스텀 TipTap 노드
│   │   │   ├── codeInline.ts
│   │   │   ├── seeRef.ts
│   │   │   ├── paramRef.ts
│   │   │   └── noteBlock.ts
│   │   ├── sections/                  // UI 섹션 컴포넌트
│   │   │   ├── summary.ts
│   │   │   ├── params.ts
│   │   │   ├── returns.ts
│   │   │   └── collapsible.ts
│   │   └── styles.css
│   ├── vite.config.ts
│   └── package.json
│
├── templates/                         // ═══ HTML 도움말 템플릿 ═══
│   ├── html/
│   │   ├── page.html                  // 기본 페이지 템플릿
│   │   ├── index.html                 // 인덱스 템플릿
│   │   ├── search.html                // 검색 페이지
│   │   └── assets/
│   │       ├── style.css              // 기본 테마
│   │       ├── dark.css               // 다크 테마
│   │       ├── script.js              // 네비게이션, 검색
│   │       └── highlight.min.js       // 코드 구문 강조
│   └── chm/
│       └── template.hhp              // CHM 프로젝트 템플릿
│
├── resources/
│   └── editor.html                    // 빌드된 WYSIWYG 에디터 (BPL 임베드)
│
└── tests/
    ├── TestDocParser.pas
    ├── TestDocModel.pas
    ├── TestDocCodeGen.pas
    ├── TestBatchParser.pas            // 일괄 파싱 테스트
    ├── TestCrossRefResolver.pas       // 상호참조 해석 테스트
    ├── TestRendererHTML.pas           // HTML 렌더러 테스트
    ├── TestRendererMD.pas             // Markdown 렌더러 테스트
    ├── TestCoverage.pas               // 커버리지 측정 테스트
    └── fixtures/
        ├── SampleClass.pas
        ├── SampleGeneric.pas
        ├── SampleWithDocs.pas
        ├── SampleNested.pas
        ├── SampleInheritance.pas      // 상속 체인 테스트
        └── SampleProject/             // 통합 테스트용 미니 프로젝트
            ├── SampleProject.dpr
            ├── Unit1.pas
            ├── Unit2.pas
            └── SubDir/
                └── Unit3.pas
```

---

## 구현 순서 (권장)

### Phase 1 — 코어 + WYSIWYG (인터랙티브 편집)

1. **DocModel + CodeGenerator** — XML ↔ JSON ↔ /// 주석 변환 핵심 로직 (DUnit 테스트)
2. **DocParser (DelphiAST)** — AST 파싱 + 커서→코드요소 매핑 + /// 주석 추출
3. **Web Editor** — TipTap 기반 WYSIWYG (독립 브라우저에서 먼저 개발/테스트)
4. **OTA Plugin Shell** — IDE 등록, 도킹 패널, 에디터 노티파이어
5. **TEdgeBrowser 통합** — WebView2 로드, PostMessage 양방향 통신
6. **동기화 연결** — 커서↔파서↔모델↔에디터↔코드생성 전체 파이프라인
7. **Stub Generator** — 자동 템플릿 생성 + 파라미터 힌트

### Phase 2 — 일괄 문서 생성

8. **Project Scanner** — .dpr/.dpk 파싱 + 디렉토리 스캔
9. **Batch Parser** — 전체 유닛 AST 파싱 + 심볼 테이블 구축
10. **Cross-Reference Resolver** — `<see cref>` 링크 해석
11. **HTML Renderer** — 멀티페이지 정적 사이트 생성 (핵심 렌더러)
12. **Markdown Renderer** — GitHub Wiki / GitBook 호환 출력
13. **Coverage Report** — 문서화 완성도 측정 + 리포트

### Phase 3 — 확장 + 폴리싱

14. **CHM Renderer** — Windows 도움말 파일 생성
15. **JSON Renderer** — 기계 판독용 API 스키마
16. **CLI 도구** — CI/CD용 커맨드라인 생성기 (XmlDocGen.exe)
17. **IDE 통합 UI** — 일괄 생성 다이얼로그, 진행 표시, 메뉴 통합
18. **설정 시스템** — 플러그인 전역 설정 관리
19. **HTML 테마 엔진** — 도움말 출력 테마 시스템
20. **에러 처리 + 로깅** — 전역 에러 처리 및 진단 로그
21. **패키지/설치** — 설치 프로그램, 업데이트 시스템
22. **접근성 + 국제화** — 다국어 UI, 접근성 지원

---

## Part 3 — 확장 + 폴리싱 상세 설계

### 13. 설정 시스템 (`uPluginSettings.pas`)

플러그인 전체의 설정을 관리한다. 설정은 레지스트리와 프로젝트별 JSON 파일 이중 저장 구조를 사용한다.

#### 13-1. 설정 저장소

```pascal
TSettingsScope = (
  ssGlobal,    // 레지스트리: HKCU\Software\XmlDocPlugin
  ssProject    // 프로젝트 폴더: .xmldocplugin.json
);

TPluginSettings = class
private
  FGlobal: TGlobalSettings;
  FProject: TProjectSettings;
  FSettingsPath: string;

  procedure LoadFromRegistry;
  procedure SaveToRegistry;
  procedure LoadProjectSettings(const AProjectDir: string);
  procedure SaveProjectSettings(const AProjectDir: string);

public
  // 유효값 = Project 우선, 없으면 Global fallback
  function GetEffective<T>(const AKey: string): T;

  property Global: TGlobalSettings;
  property Project: TProjectSettings;
end;
```

#### 13-2. 설정 항목

```pascal
TGlobalSettings = record
  // ── WYSIWYG 에디터 ──
  Editor: record
    AutoShowOnCursor: Boolean;       // 커서 이동 시 자동 표시 (기본: True)
    DebounceMs: Integer;             // 커서 디바운싱 ms (기본: 300)
    SaveDebounceMs: Integer;         // 편집→소스 반영 ms (기본: 500)
    FontSize: Integer;               // 에디터 폰트 크기 (기본: 13)
    Theme: string;                   // 에디터 테마 (light/dark/auto)
    CollapseEmptySections: Boolean;  // 빈 섹션 자동 접기 (기본: True)
    ShowSignatureHeader: Boolean;    // 상단 시그니처 표시 (기본: True)
  end;

  // ── 코드 생성 ──
  CodeGen: record
    IndentStyle: TIndentStyle;       // isSpaces, isTabs
    IndentSize: Integer;             // 기본: 2
    BlankLineBefore: Boolean;        // /// 블록 앞 빈 줄 (기본: True)
    BlankLineAfter: Boolean;         // /// 블록 뒤 빈 줄 (기본: False)
    OmitEmptyTags: Boolean;          // 빈 태그 생략 (기본: True)
    TagOrder: TArray<string>;        // 태그 출력 순서
    // 기본: ['summary','remarks','param','typeparam','returns',
    //        'value','exception','example','seealso','permission']
  end;

  // ── 스텁 생성 ──
  Stub: record
    AutoGenerate: Boolean;           // 주석 없는 요소에 자동 스텁 (기본: False)
    IncludePlaceholders: Boolean;    // placeholder 텍스트 포함 (기본: True)
    PlaceholderPrefix: string;       // placeholder 접두사 (기본: 'TODO: ')
  end;

  // ── 단축키 ──
  Shortcuts: record
    ToggleInspector: TShortCut;      // 기본: Ctrl+Shift+D
    GenerateStub: TShortCut;         // 기본: Ctrl+Shift+G
    GenerateHelp: TShortCut;         // 기본: Ctrl+Shift+H
    CoverageReport: TShortCut;       // 기본: Ctrl+Shift+R
    NextUndocumented: TShortCut;     // 기본: Ctrl+Alt+N (다음 미문서화 요소로 이동)
  end;

  // ── 일반 ──
  General: record
    Language: string;                // UI 언어 (auto/en/ko/ja/zh)
    CheckUpdates: Boolean;           // 업데이트 확인 (기본: True)
    LogLevel: TLogLevel;             // llNone, llError, llWarn, llInfo, llDebug
    LogPath: string;                 // 로그 파일 경로
  end;
end;

TProjectSettings = record
  // ── 도움말 생성 기본값 ──
  HelpGen: record
    DefaultFormats: TArray<string>;  // ['html', 'md']
    OutputDir: string;               // 상대 경로 (기본: 'docs')
    Title: string;                   // 프로젝트 문서 제목
    ExcludePatterns: TArray<string>; // 제외 패턴
    IncludePrivate: Boolean;
    InterfaceOnly: Boolean;
    HTMLTheme: string;               // HTML 테마 이름
    CoverageMinPercent: Integer;     // 최소 커버리지 (CI용)
  end;

  // ── 프로젝트별 오버라이드 ──
  Editor: record
    // Global 설정을 오버라이드할 항목만 포함
    // nil이면 Global 값 사용
    FontSize: Nullable<Integer>;
    Theme: Nullable<string>;
  end;
end;
```

#### 13-3. 프로젝트별 설정 파일 (`.xmldocplugin.json`)

프로젝트 루트에 위치하며, 팀원 간 공유 가능 (VCS 커밋).

```json
{
  "$schema": "https://xmldocplugin.dev/schema/v1/project-settings.json",
  "version": 1,
  "helpGen": {
    "defaultFormats": ["html", "md"],
    "outputDir": "docs",
    "title": "MyProject API Reference",
    "excludePatterns": ["*Test*", "vendor\\*"],
    "includePrivate": false,
    "interfaceOnly": true,
    "htmlTheme": "modern-dark",
    "coverageMinPercent": 70
  },
  "codeGen": {
    "tagOrder": ["summary", "param", "returns", "exception", "remarks", "example", "seealso"]
  }
}
```

#### 13-4. 설정 다이얼로그 (`uSettingsDialog.pas`)

```
┌─────────────────────────────────────────────────────────┐
│  XmlDoc Plugin Settings                                  │
├───────────┬─────────────────────────────────────────────┤
│           │                                              │
│ ▶ Editor  │  WYSIWYG Editor                             │
│   Code Gen│  ─────────────────────────────               │
│   Stub Gen│                                              │
│   Shortcuts│  ☑ Auto-show on cursor move                │
│   Help Gen │  Debounce:  [300 ] ms                      │
│   General  │  Save delay: [500 ] ms                     │
│           │  Font size: [13 ▼]                           │
│           │  Theme: [Auto (follow IDE) ▼]                │
│           │                                              │
│           │  ☑ Collapse empty sections                   │
│           │  ☑ Show signature in header                  │
│           │                                              │
│           │  ── Preview ──────────────────                │
│           │  ┌──────────────────────────┐                │
│           │  │ /// <summary>            │                │
│           │  │ /// TODO: 설명 입력      │                │
│           │  │ /// </summary>           │                │
│           │  │ /// <param name="AId">   │                │
│           │  │ ///   TODO: 파라미터 설명│                │
│           │  │ /// </param>             │                │
│           │  └──────────────────────────┘                │
│           │                                              │
├───────────┴─────────────────────────────────────────────┤
│  Scope: ○ Global  ○ This Project Only                    │
│                                                          │
│        [OK]  [Cancel]  [Apply]  [Reset to Defaults]     │
└─────────────────────────────────────────────────────────┘
```

---

### 14. HTML 테마 엔진 (`uThemeEngine.pas`)

도움말 HTML 출력의 비주얼 테마를 관리한다.

#### 14-1. 테마 구조

```pascal
TThemeInfo = record
  Id: string;            // 'modern-dark'
  Name: string;          // 'Modern Dark'
  Author: string;
  Version: string;
  Description: string;
  PreviewImage: string;  // 미리보기 이미지 경로
end;

TThemeEngine = class
  function GetAvailableThemes: TArray<TThemeInfo>;
  function LoadTheme(const AThemeId: string): TThemeAssets;
  procedure InstallTheme(const AZipPath: string);

  // 커스텀 테마 생성 지원
  function CreateThemeFromBase(
    const ABaseThemeId: string;
    const AOverrides: TThemeOverrides
  ): string;
end;

TThemeAssets = record
  CSS: string;            // 메인 CSS
  DarkCSS: string;        // 다크 모드 CSS (선택)
  LogoSVG: string;        // 기본 로고
  FontFiles: TArray<string>; // 웹폰트 (선택)
  JSExtensions: string;   // 추가 JS (선택)
end;

TThemeOverrides = record
  PrimaryColor: string;     // '#3B82F6'
  SecondaryColor: string;
  BackgroundColor: string;
  SidebarColor: string;
  FontFamily: string;       // 'Pretendard, sans-serif'
  CodeFontFamily: string;   // 'JetBrains Mono, monospace'
  LogoPath: string;         // 커스텀 로고
  HeaderHTML: string;       // 커스텀 헤더
  FooterHTML: string;       // 커스텀 푸터
end;
```

#### 14-2. 테마 파일 구조

```
themes/
├── default/
│   ├── theme.json           // 테마 메타데이터
│   ├── style.css            // 메인 스타일
│   ├── dark.css             // 다크 모드
│   ├── print.css            // 인쇄용
│   ├── preview.png          // 미리보기
│   └── fonts/               // 웹폰트 (선택)
│
├── modern-dark/
│   ├── theme.json
│   ├── style.css
│   └── preview.png
│
├── classic/                 // Delphi 전통 스타일 (HelpInsight 유사)
│   ├── theme.json
│   ├── style.css
│   └── preview.png
│
└── minimal/                 // 미니멀 (Read the Docs 유사)
    ├── theme.json
    ├── style.css
    └── preview.png
```

**theme.json 예시:**
```json
{
  "id": "modern-dark",
  "name": "Modern Dark",
  "author": "XmlDocPlugin",
  "version": "1.0.0",
  "description": "어두운 배경의 현대적 테마",
  "supports": ["html", "chm"],
  "colors": {
    "primary": "#60A5FA",
    "secondary": "#A78BFA",
    "background": "#1E1E2E",
    "surface": "#2D2D3F",
    "sidebar": "#252536",
    "text": "#CDD6F4",
    "textMuted": "#6C7086",
    "border": "#45475A",
    "codeBackground": "#313244",
    "linkColor": "#89B4FA",
    "warningBackground": "#F9E2AF20",
    "noteBackground": "#89B4FA20"
  },
  "typography": {
    "fontFamily": "Pretendard, -apple-system, sans-serif",
    "codeFontFamily": "JetBrains Mono, D2Coding, Consolas, monospace",
    "baseFontSize": "15px",
    "lineHeight": "1.7"
  },
  "layout": {
    "sidebarWidth": "280px",
    "contentMaxWidth": "900px",
    "borderRadius": "8px"
  }
}
```

#### 14-3. 내장 테마 4종

| 테마 | 특징 | 대상 |
|---|---|---|
| **default** | 밝은 배경, 블루 계열, 깔끔한 기본 테마 | 범용 |
| **modern-dark** | 어두운 배경, Catppuccin 계열, 개발자 친화 | IDE 사용자 |
| **classic** | Delphi HelpInsight/MSDN 스타일, 전통적 | 기존 Delphi 사용자 |
| **minimal** | Read the Docs 유사, 최소한의 장식 | 오픈소스 프로젝트 |

#### 14-4. 테마 적용 흐름

```
HTML Renderer 실행
  │
  ├─ TThemeEngine.LoadTheme(설정의 ThemeId)
  │   └→ TThemeAssets 반환
  │
  ├─ 페이지 템플릿에 CSS 삽입
  │   └→ <link rel="stylesheet" href="assets/theme.css">
  │
  ├─ 다크/라이트 모드 지원
  │   └→ <html data-theme="auto">
  │       media query + JS 토글 버튼
  │
  └─ 커스텀 오버라이드 적용
      └→ TThemeOverrides → CSS 변수 오버라이드 생성
          :root { --primary: #custom; ... }
```

---

### 15. 에러 처리 + 로깅 (`uLogger.pas`, `uErrorHandler.pas`)

#### 15-1. 로깅 시스템

```pascal
TLogLevel = (llDebug, llInfo, llWarn, llError, llFatal);

TLogger = class
private
  class var FInstance: TLogger;
  FLogFile: TStreamWriter;
  FLogLevel: TLogLevel;
  FLogPath: string;
  FMaxFileSize: Int64;    // 로그 회전 크기 (기본: 5MB)
  FMaxFiles: Integer;     // 최대 보관 수 (기본: 3)

  procedure RotateIfNeeded;
  procedure WriteEntry(ALevel: TLogLevel; const AMsg: string;
    const AContext: string = '');

public
  class function Instance: TLogger;

  procedure Debug(const AMsg: string; const AContext: string = '');
  procedure Info(const AMsg: string; const AContext: string = '');
  procedure Warn(const AMsg: string; const AContext: string = '');
  procedure Error(const AMsg: string; const AContext: string = '');
  procedure Error(E: Exception; const AContext: string = '');
  procedure Fatal(const AMsg: string; const AContext: string = '');

  property Level: TLogLevel;
end;
```

**로그 파일 형식:**
```
[2026-03-03 14:23:15.123] [INFO ] [DocParser] Parsing MyUnit.pas (1,234 lines)
[2026-03-03 14:23:15.456] [INFO ] [DocParser] Found 23 documentable elements
[2026-03-03 14:23:16.001] [WARN ] [CrossRef] Unresolved cref="TUnknownClass" in MyUnit.TFoo.Bar
[2026-03-03 14:23:16.789] [ERROR] [AST     ] Parse error at line 45: unexpected token
                                              Source: MyBrokenUnit.pas
                                              Stack: TPasSyntaxTreeBuilder.Run → ...
```

**로그 파일 위치:**
```
%APPDATA%\XmlDocPlugin\
├── xmldocplugin.log          // 현재 로그
├── xmldocplugin.1.log        // 회전된 이전 로그
├── xmldocplugin.2.log
└── settings.reg.bak          // 설정 백업
```

#### 15-2. 에러 처리 전략

```pascal
TErrorSeverity = (
  esRecoverable,    // 계속 진행 가능 (경고 표시)
  esElementSkip,    // 해당 요소만 건너뜀
  esUnitSkip,       // 해당 유닛만 건너뜀
  esFatal           // 전체 작업 중단
);

TErrorHandler = class
private
  FErrors: TList<TPluginError>;
  FOnError: TErrorCallback;

public
  procedure HandleException(E: Exception; ASeverity: TErrorSeverity;
    const AContext: string);

  // IDE 메시지 패널에 경고/에러 출력
  procedure ReportToIDE(const AMsg: string; AKind: TOTAMessageKind);

  // 사용자에게 선택권 부여 (계속/건너뜀/중단)
  function AskUser(const AMsg: string; ASeverity: TErrorSeverity): TUserAction;

  property Errors: TList<TPluginError>;
end;

TPluginError = record
  Timestamp: TDateTime;
  Severity: TErrorSeverity;
  Message: string;
  Context: string;        // 'DocParser.ParseUnit'
  FileName: string;       // 관련 파일
  Line: Integer;          // 관련 행 (-1이면 해당 없음)
  ExceptionClass: string; // 원본 Exception 클래스명
end;
```

#### 15-3. 모듈별 에러 처리 정책

| 모듈 | 에러 상황 | 처리 |
|---|---|---|
| **DocParser** | AST 파싱 실패 (구문 오류) | `esRecoverable` — 이전 캐시 AST 유지, 에디터에 경고 표시 |
| **DocParser** | 타이핑 중 불완전한 코드 | `esRecoverable` — 무시 (디바운싱으로 자연 해소) |
| **DocModel** | XML 파싱 실패 (잘못된 주석) | `esRecoverable` — 원본 텍스트 그대로 표시, 에디터에 경고 |
| **CodeGenerator** | OTA Writer 실패 | `esRecoverable` — 재시도 1회, 실패 시 사용자 알림 |
| **BatchParser** | 개별 유닛 파싱 실패 | `esUnitSkip` — 해당 유닛 건너뛰고 계속 진행, 로그 기록 |
| **CrossRefResolver** | cref 해석 실패 | `esRecoverable` — 경고 목록에 추가, 링크 없이 텍스트만 출력 |
| **HTMLRenderer** | 파일 쓰기 실패 | `esFatal` — 출력 폴더 권한 문제, 사용자에게 알림 후 중단 |
| **CHMRenderer** | hhc.exe 없음 | `esRecoverable` — HTML만 출력, CHM 건너뜀 경고 |
| **TEdgeBrowser** | WebView2 런타임 없음 | `esFatal` — 설치 안내 다이얼로그 표시 |

#### 15-4. IDE 메시지 패널 통합

```pascal
// IDE의 Messages 패널에 경고/에러를 출력
procedure TErrorHandler.ReportToIDE(const AMsg: string; AKind: TOTAMessageKind);
var
  Services: IOTAMessageServices;
begin
  Services := BorlandIDEServices as IOTAMessageServices;
  // 전용 메시지 그룹 사용
  Services.AddToolMessage(
    FCurrentFile,        // 관련 파일
    AMsg,                // 메시지
    'XmlDocPlugin',      // 도구 이름
    FCurrentLine,        // 행 번호
    0,                   // 열
    nil,                 // 부모
    FMessageGroup        // 'XmlDoc' 그룹
  );
end;
```

```
Messages 패널 출력 예시:
─────────────────────────────────────────────────
[XmlDoc] ─────────────────────────────────────────
  ⚠ MyUnit.pas(45): Unresolved reference: TUnknownClass
  ⚠ MyUnit.pas(78): Empty <summary> tag for TFoo.DoSomething
  ✗ BrokenUnit.pas: Parse error — skipped
  ℹ Generated 23 HTML pages in docs\html\
  ℹ Coverage: 71.7% (142/198 elements)
```

---

### 16. 단축키 + 툴바 (`uShortcuts.pas`, `uToolbarIntegration.pas`)

#### 16-1. 키보드 바인딩

```pascal
TXmlDocKeyBinding = class(TNotifierObject, IOTAKeyboardBinding)
  procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
end;

procedure TXmlDocKeyBinding.BindKeyboard(
  const BindingServices: IOTAKeyBindingServices);
begin
  // 설정에서 단축키 로드
  BindingServices.AddKeyBinding(
    [Settings.Shortcuts.ToggleInspector],   // Ctrl+Shift+D
    ToggleDocInspector, nil);

  BindingServices.AddKeyBinding(
    [Settings.Shortcuts.GenerateStub],      // Ctrl+Shift+G
    GenerateDocStub, nil);

  BindingServices.AddKeyBinding(
    [Settings.Shortcuts.NextUndocumented],  // Ctrl+Alt+N
    JumpToNextUndocumented, nil);
end;
```

**전체 단축키 맵:**

| 단축키 | 기능 | 설명 |
|---|---|---|
| `Ctrl+Shift+D` | Toggle Doc Inspector | WYSIWYG 패널 표시/숨김 |
| `Ctrl+Shift+G` | Generate Doc Stub | 현재 요소에 빈 /// 주석 삽입 |
| `Ctrl+Shift+H` | Generate Help | 일괄 문서 생성 다이얼로그 |
| `Ctrl+Shift+R` | Coverage Report | 커버리지 리포트 다이얼로그 |
| `Ctrl+Alt+N` | Next Undocumented | 다음 미문서화 요소로 커서 이동 |
| `Ctrl+Alt+P` | Previous Undocumented | 이전 미문서화 요소로 커서 이동 |
| `Ctrl+Alt+D` | Quick Doc Preview | 현재 요소의 문서를 풍선 도움말로 표시 |

#### 16-2. 컨텍스트 메뉴 통합

```
소스 에디터 우클릭 메뉴:
  ─────────────────────
  Cut
  Copy
  Paste
  ─────────────────────
  XmlDoc                    ◄ 서브메뉴
    ├─ Edit Documentation   (현재 요소의 문서 편집 → Inspector로 포커스)
    ├─ Generate Stub        (빈 주석 생성)
    ├─ Remove Documentation (현재 요소의 /// 주석 삭제)
    ├─ ────────────────
    ├─ Preview as HTML      (현재 요소의 문서를 HTML 미리보기)
    └─ Copy as Markdown     (현재 요소의 문서를 MD로 클립보드 복사)
  ─────────────────────
  Refactoring
  ...
```

#### 16-3. 툴바 아이콘

IDE 툴바에 XmlDoc 전용 버튼 그룹을 추가한다.

```
[기존 IDE 툴바 ...] │ [📝] [📄] [📊] [⚙️] │
                      │    │    │    │
                      │    │    │    └─ Settings
                      │    │    └─ Coverage Report
                      │    └─ Generate Help
                      └─ Toggle Doc Inspector
```

**아이콘 사양:**
- 크기: 16x16 (일반), 24x24 (고DPI), 32x32 (4K)
- 형식: PNG with alpha (IDE ImageList에 등록)
- 스타일: Delphi IDE 기본 아이콘 스타일과 조화 (단색 라인 아이콘)

```pascal
TToolbarIntegration = class
  procedure CreateToolbar;
private
  FToolbar: TToolBar;
  FImageList: TImageList;

  procedure LoadIcons;
  procedure AddButton(const ACaption, AHint: string;
    AImageIndex: Integer; AOnClick: TNotifyEvent);
end;
```

---

### 17. Quick Doc Preview — 풍선 도움말 (`uQuickDocPreview.pas`)

커서 위치 요소의 문서를 에디터 내 풍선(HintWindow)으로 표시한다. Delphi의 기본 Help Insight와 유사하지만, `///` 주석 기반.

```pascal
TQuickDocPreview = class
  // Help Insight 스타일의 풍선 도움말 표시
  procedure ShowPreview(const AElement: TCodeElementInfo;
    AScreenPos: TPoint);
  procedure HidePreview;
private
  FHintWindow: THintWindow;

  // DocModel → 간단한 HTML 변환 (풍선용)
  function RenderCompactHTML(const AModel: TXmlDocModel;
    const AElement: TCodeElementInfo): string;
end;
```

**풍선 레이아웃:**
```
┌─────────────────────────────────────────────┐
│ function UpdateUser(AUserId: Integer;       │
│   const ANewName: string): Boolean;         │
├─────────────────────────────────────────────┤
│ 지정된 사용자의 정보를 업데이트합니다.      │
│                                             │
│ Parameters:                                  │
│   AUserId  — 대상 사용자 ID                 │
│   ANewName — 새로운 이름                    │
│                                             │
│ Returns: 업데이트 성공 여부                  │
│                                             │
│ Raises: EUserNotFoundException              │
└─────────────────────────────────────────────┘
```

---

### 18. 미문서화 요소 네비게이터 (`uUndocNavigator.pas`)

현재 유닛에서 `///` 주석이 없는 public 요소를 순차 탐색한다.

```pascal
TUndocNavigator = class
private
  FParser: TDocParser;
  FUndocElements: TArray<TCodeElementInfo>;
  FCurrentIndex: Integer;

  procedure RebuildList;  // AST에서 미문서화 요소 목록 구축

public
  procedure JumpToNext;     // Ctrl+Alt+N
  procedure JumpToPrevious; // Ctrl+Alt+P

  // 현재 유닛의 미문서화 상태 요약
  function GetUnitStatus: string;
  // 예: "5/23 undocumented (public)"
end;
```

**에디터 거터 마커 (선택적):**
- 미문서화된 public 요소 옆에 노란색 마커 표시
- IOTAElideActions 또는 커스텀 거터 페인터 사용

---

### 19. 패키징 + 설치 시스템

#### 19-1. 설치 프로그램 (InnoSetup)

```
XmlDocPlugin_Setup_v1.0.0.exe
│
├─ 설치 과정:
│  1. 지원 Delphi 버전 감지 (레지스트리 조회)
│  2. 사용자 선택: Delphi 11 / 12 / 양쪽
│  3. 파일 배포:
│     ├─ BPL → $(BDSCOMMONDIR)\Bpl\
│     ├─ DCP → $(BDSCOMMONDIR)\Dcp\
│     ├─ 웹 에디터 리소스 → $(APPDATA)\XmlDocPlugin\
│     ├─ 테마 파일 → $(APPDATA)\XmlDocPlugin\themes\
│     └─ CLI 도구 → $(ProgramFiles)\XmlDocPlugin\
│  4. IDE 레지스트리 등록:
│     HKCU\Software\Embarcadero\BDS\<ver>\Known Packages
│     → XmlDocPlugin.bpl 추가
│  5. PATH에 CLI 도구 경로 추가 (선택)
│
├─ 제거 과정:
│  1. IDE 레지스트리에서 BPL 제거
│  2. 배포 파일 삭제
│  3. 설정/로그 보존 여부 선택
```

**InnoSetup 스크립트 핵심 부분:**
```pascal
[Setup]
AppName=XmlDoc Plugin
AppVersion={#Version}
DefaultDirName={autopf}\XmlDocPlugin
OutputBaseFilename=XmlDocPlugin_Setup_v{#Version}

[Files]
// Delphi 11 BPL
Source: "bin\d28\XmlDocPlugin.bpl"; DestDir: "{code:GetBPLDir|28.0}"; \
  Check: IsDelphiInstalled('28.0')
// Delphi 12 BPL
Source: "bin\d29\XmlDocPlugin.bpl"; DestDir: "{code:GetBPLDir|29.0}"; \
  Check: IsDelphiInstalled('29.0')
// 공용 파일
Source: "resources\*"; DestDir: "{userappdata}\XmlDocPlugin"; Flags: recursesubdirs
Source: "bin\XmlDocGen.exe"; DestDir: "{app}"; Flags: ignoreversion

[Registry]
// Delphi 11 패키지 등록
Root: HKCU; Subkey: "Software\Embarcadero\BDS\22.0\Known Packages"; \
  ValueType: string; ValueName: "{code:GetBPLDir|28.0}\XmlDocPlugin.bpl"; \
  ValueData: "XmlDoc Plugin - XML Documentation Editor"; \
  Check: IsDelphiInstalled('28.0')
```

#### 19-2. GetIt 패키지 (선택)

Embarcadero GetIt 패키지 매니저를 통한 배포도 지원 가능.

```json
{
  "id": "XmlDocPlugin",
  "name": "XmlDoc Plugin - WYSIWYG XML Documentation Editor",
  "version": "1.0.0",
  "platforms": ["Win32", "Win64"],
  "ideVersions": ["22.0", "23.0"],
  "type": "DesignTimePackage",
  "dependencies": [],
  "files": [
    { "source": "XmlDocPlugin.bpl", "destination": "$(BDSCOMMONDIR)\\Bpl" },
    { "source": "resources\\", "destination": "$(APPDATA)\\XmlDocPlugin" }
  ]
}
```

#### 19-3. 업데이트 확인

```pascal
TUpdateChecker = class
  procedure CheckAsync;
private
  procedure OnCheckComplete(const ALatestVersion: string;
    const AReleaseNotes: string; const ADownloadURL: string);
public
  property OnUpdateAvailable: TUpdateEvent;
end;
```

```
업데이트 확인 흐름:
  IDE 시작 → 24시간 경과 확인 → HTTPS GET
  https://xmldocplugin.dev/api/v1/latest?current={version}&ide={ideVersion}
  → 새 버전 있으면 IDE 시작 시 비침습적 알림 바 표시

┌─────────────────────────────────────────────────────┐
│ ℹ XmlDoc Plugin v1.1.0 available. [Update] [Later] │
└─────────────────────────────────────────────────────┘
```

---

### 20. 접근성 + 국제화 (i18n)

#### 20-1. 국제화 구조

```pascal
TI18n = class
private
  class var FInstance: TI18n;
  FLang: string;
  FStrings: TDictionary<string, string>;

  procedure LoadLanguage(const ALang: string);

public
  class function Instance: TI18n;

  // 번역 문자열 조회 (키가 없으면 기본 영어 반환)
  function T(const AKey: string): string;
  function T(const AKey: string; const AArgs: array of const): string;

  property CurrentLanguage: string;
end;

// 사용 예시
Caption := I18n.T('menu.generate_help');  // 'Generate Help...' 또는 '도움말 생성...'
Msg := I18n.T('coverage.percent', [Stats.CoveragePercent]);
// '커버리지: 71.7%' 또는 'Coverage: 71.7%'
```

**언어 파일 (JSON):**
```
locales/
├── en.json    // 영어 (기본)
├── ko.json    // 한국어
├── ja.json    // 일본어
└── zh.json    // 중국어 (간체)
```

```json
// ko.json
{
  "menu": {
    "toggle_inspector": "문서 편집기 토글",
    "generate_stub": "문서 스텁 생성",
    "generate_help": "도움말 생성...",
    "coverage_report": "커버리지 리포트...",
    "settings": "설정..."
  },
  "inspector": {
    "summary": "요약",
    "parameters": "매개변수",
    "returns": "반환값",
    "remarks": "비고",
    "exceptions": "예외",
    "examples": "예제",
    "see_also": "참고",
    "no_element": "커서를 코드 요소 위에 놓아주세요."
  },
  "helpgen": {
    "title": "API 문서 생성",
    "source": "소스",
    "output_format": "출력 형식",
    "generating": "문서 생성 중...",
    "complete": "생성 완료: {0}개 페이지"
  },
  "coverage": {
    "title": "문서화 커버리지 리포트",
    "overall": "전체: {0}/{1} ({2}%)",
    "undocumented": "미문서화 항목"
  },
  "errors": {
    "ast_parse_fail": "소스 파싱 실패: {0}",
    "webview_missing": "WebView2 런타임이 설치되어 있지 않습니다.",
    "hhc_not_found": "HTML Help Workshop이 설치되어 있지 않아 CHM을 생성할 수 없습니다."
  }
}
```

#### 20-2. WYSIWYG 에디터 국제화

웹 에디터(TipTap)의 UI 문자열도 국제화를 지원한다.

```typescript
// bridge.ts에서 Delphi로부터 언어 설정 수신
bridge.receive({ type: 'setLanguage', data: { lang: 'ko', strings: {...} } });

// 에디터 UI에 적용
document.querySelector('.section-title.summary').textContent = strings['inspector.summary'];
document.querySelector('.toolbar-bold').title = strings['toolbar.bold'];
```

#### 20-3. 키보드 접근성

WYSIWYG 에디터의 키보드 네비게이션 지원:

| 키 | 기능 |
|---|---|
| `Tab` | 다음 섹션으로 이동 (Summary → Parameters → Returns → ...) |
| `Shift+Tab` | 이전 섹션으로 이동 |
| `Enter` | 접힌 섹션 열기 / 편집 모드 진입 |
| `Escape` | 편집 모드 종료 / 섹션 접기 |
| `Ctrl+Enter` | 편집 완료 및 소스에 적용 |

---

## 최종 프로젝트 구조 (Phase 3 포함)

```
XmlDocPlugin/
├── src/
│   ├── Core/
│   │   ├── uDocParser.pas
│   │   ├── uDocModel.pas
│   │   ├── uDocCodeGen.pas
│   │   ├── uDocStubGen.pas
│   │   ├── uConsts.pas
│   │   ├── uLogger.pas                // ★ 로깅 시스템
│   │   ├── uErrorHandler.pas          // ★ 에러 처리
│   │   └── uI18n.pas                  // ★ 국제화
│   │
│   ├── Plugin/
│   │   ├── XmlDocPlugin.dpr
│   │   ├── XmlDocPlugin.dpk
│   │   ├── uPluginMain.pas
│   │   ├── uPluginSettings.pas        // ★ 설정 시스템
│   │   ├── uEditorNotifier.pas
│   │   ├── uDocInspector.pas
│   │   ├── uBatchGenDialog.pas
│   │   ├── uSettingsDialog.pas        // ★ 설정 다이얼로그
│   │   ├── uShortcuts.pas             // ★ 단축키 바인딩
│   │   ├── uToolbarIntegration.pas    // ★ 툴바 아이콘
│   │   ├── uContextMenu.pas           // ★ 컨텍스트 메뉴
│   │   ├── uQuickDocPreview.pas       // ★ 풍선 도움말
│   │   ├── uUndocNavigator.pas        // ★ 미문서화 요소 네비게이터
│   │   └── uUpdateChecker.pas         // ★ 업데이트 확인
│   │
│   ├── HelpGen/
│   │   ├── uProjectScanner.pas
│   │   ├── uBatchParser.pas
│   │   ├── uCrossRefResolver.pas
│   │   ├── uDocCoverageReport.pas
│   │   ├── uDocRenderer.pas
│   │   ├── uDocRendererHTML.pas
│   │   ├── uDocRendererMD.pas
│   │   ├── uDocRendererCHM.pas
│   │   ├── uDocRendererJSON.pas
│   │   ├── uSitePublisher.pas         // ★ MkDocs/Docusaurus/VitePress 퍼블리셔
│   │   └── uThemeEngine.pas           // ★ 테마 엔진
│   │
│   └── CLI/
│       ├── XmlDocGen.dpr
│       └── uCLIMain.pas
│
├── vendor/
│   └── DelphiAST/
│
├── web/
│   ├── src/
│   │   ├── editor.ts
│   │   ├── bridge.ts
│   │   ├── i18n.ts                    // ★ 웹 에디터 국제화
│   │   ├── nodes/
│   │   ├── sections/
│   │   └── styles.css
│   ├── vite.config.ts
│   └── package.json
│
├── templates/
│   └── html/
│
├── themes/                            // ★ 테마 폴더
│   ├── default/
│   ├── modern-dark/
│   ├── classic/
│   └── minimal/
│
├── locales/                           // ★ 언어 파일
│   ├── en.json
│   ├── ko.json
│   ├── ja.json
│   └── zh.json
│
├── icons/                             // ★ 툴바/메뉴 아이콘
│   ├── 16/
│   ├── 24/
│   └── 32/
│
├── installer/                         // ★ 설치 프로그램
│   ├── XmlDocPlugin.iss              // InnoSetup 스크립트
│   ├── license.txt
│   └── getit-package.json            // GetIt 패키지 정의
│
├── resources/
│   └── editor.html
│
└── tests/
    ├── TestDocParser.pas
    ├── TestDocModel.pas
    ├── TestDocCodeGen.pas
    ├── TestBatchParser.pas
    ├── TestCrossRefResolver.pas
    ├── TestRendererHTML.pas
    ├── TestRendererMD.pas
    ├── TestCoverage.pas
    ├── TestSettings.pas               // ★ 설정 로드/저장 테스트
    ├── TestThemeEngine.pas            // ★ 테마 로드 테스트
    ├── TestI18n.pas                   // ★ 국제화 테스트
    └── fixtures/
        ├── SampleClass.pas
        ├── SampleGeneric.pas
        ├── SampleWithDocs.pas
        ├── SampleNested.pas
        ├── SampleInheritance.pas
        └── SampleProject/
```

---

## 구현 순서 (전체 — Phase 3 상세화)

### Phase 1 — 코어 + WYSIWYG (인터랙티브 편집)

1. **DocModel + CodeGenerator** — XML ↔ JSON ↔ /// 주석 변환 핵심 로직 (DUnit 테스트)
2. **DocParser (DelphiAST)** — AST 파싱 + 커서→코드요소 매핑 + /// 주석 추출
3. **Web Editor** — TipTap 기반 WYSIWYG (독립 브라우저에서 먼저 개발/테스트)
4. **OTA Plugin Shell** — IDE 등록, 도킹 패널, 에디터 노티파이어
5. **TEdgeBrowser 통합** — WebView2 로드, PostMessage 양방향 통신
6. **동기화 연결** — 커서↔파서↔모델↔에디터↔코드생성 전체 파이프라인
7. **Stub Generator** — 자동 템플릿 생성 + 파라미터 힌트

### Phase 2 — 일괄 문서 생성

8. **Project Scanner** — .dpr/.dpk 파싱 + 디렉토리 스캔
9. **Batch Parser** — 전체 유닛 AST 파싱 + 심볼 테이블 구축
10. **Cross-Reference Resolver** — `<see cref>` 링크 해석
11. **HTML Renderer** — 멀티페이지 정적 사이트 생성 (핵심 렌더러)
12. **Markdown Renderer** — GitHub Wiki / GitBook 호환 출력
13. **Coverage Report** — 문서화 완성도 측정 + 리포트

### Phase 3 — 확장 + 폴리싱

14. **로깅 + 에러 처리** — TLogger, TErrorHandler, IDE 메시지 패널 통합
15. **설정 시스템** — 레지스트리 + JSON 이중 저장, 설정 다이얼로그
16. **단축키 + 컨텍스트 메뉴 + 툴바** — IOTAKeyboardBinding, 아이콘 리소스
17. **HTML 테마 엔진** — 4종 내장 테마, 커스텀 테마 지원
18. **Quick Doc Preview** — Help Insight 스타일 풍선 도움말
19. **미문서화 네비게이터** — Ctrl+Alt+N/P 순회, 거터 마커
20. **CHM Renderer** — HTML Help Workshop 연동
21. **JSON Renderer** — 기계 판독용 API 스키마
22. **CLI 도구** — XmlDocGen.exe 커맨드라인 생성기
23. **IDE 통합 UI** — 일괄 생성 다이얼로그, 진행 표시
24. **국제화 (i18n)** — 한국어/영어/일본어/중국어
25. **패키징 + 설치** — InnoSetup 설치 프로그램, GetIt 패키지
26. **업데이트 시스템** — 자동 업데이트 확인 + 알림

---

## 검증 방법 (Phase 3 추가)

- **단위 테스트**: DocModel, Parser, CodeGenerator, BatchParser, CrossRefResolver, CoverageReport에 DUnit 테스트
  - fixtures/ 폴더에 다양한 패턴의 .pas 파일 준비
  - 왕복 변환 (/// → XML → DocModel → JSON → DocModel → XML → ///) 무손실 확인
- **웹 에디터**: 독립 브라우저에서 TipTap 에디터 테스트 후 IDE 통합
- **렌더러 테스트**: SampleProject fixtures를 대상으로 각 렌더러(HTML, MD, JSON) 출력 검증
  - HTML: 모든 페이지 생성 확인, 링크 무결성, 검색 인덱스
  - Markdown: 문법 유효성, 내부 링크 유효성
  - JSON: JSON Schema 검증
- **크로스 레퍼런스**: 유닛 간 참조, 미해석 cref 경고, 상속 체인 추적 정확도
- **커버리지**: 의도적으로 미문서화된 요소 포함한 샘플로 정확한 측정 확인
- **CLI**: 커맨드라인 인자 조합 테스트 + exit code 확인
- **AST 정확도**: DelphiAST가 다양한 Delphi 문법(generics, anonymous methods, attributes 등)을 정확히 파싱하는지 검증
- **호환성**: Delphi 11 Alexandria, Delphi 12 Athens 양쪽에서 BPL 빌드 및 로드 테스트
- **설정 시스템**: 레지스트리/JSON 로드·저장 왕복, 프로젝트 설정 우선순위, 기본값 복원
- **테마 엔진**: 4종 내장 테마 렌더링, 커스텀 오버라이드 적용, 다크/라이트 전환
- **국제화**: 4개 언어 파일 로드, 누락 키 폴백(영어), 런타임 언어 전환
- **에러 처리**: 각 모듈별 에러 시나리오 (파싱 실패, 파일 권한, WebView 미설치 등) 시뮬레이션
- **설치 프로그램**: 클린 환경에서 설치→IDE 인식→사용→제거 사이클 검증
- **접근성**: 키보드만으로 WYSIWYG 에디터 전체 기능 사용 가능 확인

---

## 의존성 요약

| 라이브러리 | 버전 | 용도 | 라이선스 |
|---|---|---|---|
| DelphiAST | master | 파스칼 소스 AST 파싱 | MPL 2.0 |
| TEdgeBrowser | Delphi 11+ 내장 | WebView2 호스팅 | Embarcadero |
| TipTap | v2.x | WYSIWYG 리치 텍스트 에디터 | MIT |
| Vite | 5.x | 웹 에디터 빌드 (단일 HTML) | MIT |
| vite-plugin-singlefile | latest | HTML 인라인 번들링 | MIT |
| highlight.js | 11.x | HTML 도움말 코드 구문 강조 | BSD-3 |
| HTML Help Workshop | 4.74 | CHM 컴파일 (선택, MS 배포) | Microsoft |
| InnoSetup | 6.x | 설치 프로그램 빌드 | Inno Setup License |
