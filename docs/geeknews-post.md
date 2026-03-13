# GeekNews 소개글

**제목:**
Show GN: Delphi용 XML Documentation 플러그인 (오픈소스)

**URL:**
https://github.com/civilian7/XmlDocPlugin

**내용:**

Delphi IDE에서 C# 스타일의 `///` XML 문서 주석을 WYSIWYG 에디터로 작성할 수 있는 오픈소스 플러그인입니다.

- Doc Inspector: 커서 위치의 코드 요소에 대한 문서를 실시간 편집
- Documentation Explorer: 유닛 전체 구조를 트리로 탐색하며 문서 편집
- TipTap 기반 리치 텍스트 에디터 (WebView2)
- HTML/Markdown/CHM/JSON 문서 자동 생성
- CLI 도구로 CI/CD 파이프라인 통합 가능

상용으로는 DevJet의 Documentation Insight가 있지만, 문서화 도구는 IDE의 기본 기능이어야 한다는 생각에서 시작했습니다. Embarcadero가 공식적으로 이 기능을 제공해주길 바라는 마음도 담았습니다.

기술 스택: Delphi OTA + VCL, DelphiAST, TipTap + TypeScript, Vite
