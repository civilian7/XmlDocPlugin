# XmlDoc Plugin for Delphi

[English](README.md)

Delphi IDE에 통합되는 **XML Documentation** 플러그인입니다. C# 스타일의 `///` XML 주석을 WYSIWYG 에디터로 작성하고, 프로젝트 전체의 API 문서를 자동 생성할 수 있습니다.

## 이 프로젝트를 시작한 이유

XML Documentation 주석(`///`)은 C#을 비롯한 많은 언어에서 표준적으로 사용되지만, Delphi에는 이를 작성하거나 관리하는 도구가 내장되어 있지 않습니다. 현재 유일한 선택지는 DevJet Software의 [Documentation Insight](https://www.devjetsoftware.com/products/documentation-insight/)로, 잘 만들어진 상용 제품이지만 라이선스 비용이 개인 개발자나 소규모 팀, 오픈소스 기여자에게는 부담이 될 수 있습니다.

이 프로젝트는 단순한 믿음에서 출발했습니다. **문서화는 모든 현대적인 IDE가 기본으로 제공해야 할 기능이지, 유료 애드온이어서는 안 된다는 것입니다.** 오픈소스 대안을 만들어 커뮤니티에 기여하는 동시에, Embarcadero가 Delphi에 공식적으로 XML Documentation 지원을 제공하는 날이 오기를 바랍니다.

## 주요 기능

### IDE 플러그인 (BPL)

- **Doc Inspector** — 커서 위치의 코드 요소에 대한 XML 문서를 실시간으로 편집하는 도킹 패널
- **Documentation Explorer** — 유닛 전체의 클래스/메서드/프로퍼티를 트리로 탐색하며 문서를 편집
- **WYSIWYG 에디터** — TipTap 기반 리치 텍스트 에디터 (TEdgeBrowser/WebView2)
- **Doc Stub 생성** — 단축키 한 번으로 파라미터, 리턴값, 제네릭 타입을 포함한 문서 스텁 자동 생성
- **미문서화 요소 탐색** — 문서가 없는 요소를 순차적으로 찾아 이동
- **Coverage Report** — 프로젝트의 문서화 커버리지를 분석하고 리포트 생성
- **단축키 지원** — 모든 기능에 사용자 정의 가능한 단축키 제공

### 문서 생성 엔진 (HelpGen)

- **다중 출력 포맷** — HTML, Markdown, CHM (Windows Help), JSON
- **테마 엔진** — 커스터마이즈 가능한 HTML 테마
- **교차 참조** — 타입/멤버 간 자동 링크 생성
- **정적 사이트 퍼블리싱** — 독립적인 API 문서 사이트 생성

### CLI 도구 (XmlDocGen)

```
XmlDocGen -d "C:\MyProject\src" -o "C:\MyProject\docs" -f HTML,MD
```

커맨드라인에서 배치 문서 생성, CI/CD 파이프라인에 통합 가능합니다.

## 지원하는 XML 태그

| 태그 | 설명 |
|------|------|
| `<summary>` | 요소에 대한 요약 설명 |
| `<param>` | 메서드 파라미터 설명 |
| `<returns>` | 반환값 설명 |
| `<remarks>` | 추가 설명 |
| `<value>` | 프로퍼티 값 설명 |
| `<typeparam>` | 제네릭 타입 파라미터 설명 |
| `<exception>` | 발생 가능한 예외 |
| `<example>` | 사용 예제 |
| `<seealso>` | 관련 항목 참조 |

```pascal
/// <summary>지정된 사용자의 정보를 조회합니다.</summary>
/// <param name="AUserId">조회할 사용자 ID</param>
/// <returns>사용자 정보. 존재하지 않으면 nil</returns>
/// <exception cref="EAuthException">인증되지 않은 경우</exception>
function GetUser(const AUserId: Integer): TUser;
```

## 프로젝트 구조

```
src/
  Core/         코어 모듈 (파서, 모델, 코드 생성 — BPL + CLI 공유)
  Plugin/       IDE 플러그인 (BPL)
  HelpGen/      배치 문서 생성 엔진
  CLI/          커맨드라인 도구
  Packages/     Delphi 패키지 프로젝트 파일
web/            TipTap WYSIWYG 에디터 (TypeScript + Vite)
tests/          DUnitX 단위 테스트
vendor/         외부 라이브러리 (DelphiAST)
docs/           생성된 API 문서
resources/      빌드된 웹 리소스
```

## 빌드

### 요구 사항

- Delphi 11 Alexandria 이상 (TEdgeBrowser/WebView2 필요)
- Node.js 18+ (웹 에디터 빌드)
- WebView2 Runtime (Windows 10/11에 기본 포함)

### 빌드 순서

```bash
# 1. 웹 에디터 빌드
cd web
npm install
npm run build

# 2. 리소스 컴파일
cd ../src/Plugin
brcc32 XmlDocEditor.rc

# 3. Delphi에서 BPL 빌드
# src/Packages/13/XmlDocPlugin.dpk 열기 → Build + Install
```

## 기술 스택

| 영역 | 기술 |
|------|------|
| IDE 플러그인 | Delphi OTA (Open Tools API), VCL |
| 소스 파싱 | [DelphiAST](https://github.com/RomanYankworsky/DelphiAST) |
| 문서 에디터 | [TipTap](https://tiptap.dev/) + TypeScript, WebView2 |
| 빌드 도구 | Vite + vite-plugin-singlefile |
| 테스트 | DUnitX |

## 라이선스

이 프로젝트는 [MIT 라이선스](LICENSE)로 배포됩니다.

- DelphiAST: [MPL 2.0](vendor/DelphiAST/LICENSE)
