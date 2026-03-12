# XmlDocPlugin Project Rules

## Unit Naming Convention
- 모든 유닛 파일은 `XmlDoc.` 접두어를 사용하는 dot-separated namespace 형식
  - Core: `XmlDoc.Consts.pas`, `XmlDoc.Model.pas`, `XmlDoc.CodeGen.pas`
  - Parser: `XmlDoc.Parser.pas`, `XmlDoc.StubGen.pas`
  - Plugin: `XmlDoc.Plugin.Main.pas`, `XmlDoc.Plugin.EditorNotifier.pas`
  - HelpGen: `XmlDoc.HelpGen.ProjectScanner.pas`, `XmlDoc.HelpGen.BatchParser.pas`
  - CLI: `XmlDoc.CLI.Main.pas`
- 테스트 유닛은 접두어 없이 `TestDocModel.pas`, `TestDocCodeGen.pas` 등

## Project Structure
```
src/Core/       — 코어 모듈 (BPL + CLI 공유)
src/Plugin/     — IDE 플러그인 (BPL)
src/HelpGen/    — 일괄 문서 생성 엔진
src/CLI/        — 커맨드라인 도구
tests/          — DUnitX 테스트
tests/fixtures/ — 테스트용 샘플 소스
vendor/         — 외부 라이브러리 (DelphiAST 등)
web/            — TipTap WYSIWYG 에디터
templates/      — HTML 도움말 템플릿
resources/      — 빌드된 리소스
```

## Dependencies
- **DelphiAST**: `vendor/DelphiAST/Source/` — Delphi 소스 파서 (MPL 2.0)
  - 검색 경로에 `vendor/DelphiAST/Source` 및 `vendor/DelphiAST/Source/SimpleParser` 추가 필요

## Coding Standards
- Global CLAUDE.md의 Delphi Coding Standards 전체 적용
- 최소 지원 버전: Delphi 11 Alexandria (TEdgeBrowser 필수)
- 테스트 프레임워크: DUnitX
