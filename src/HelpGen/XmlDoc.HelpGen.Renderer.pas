unit XmlDoc.HelpGen.Renderer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  XmlDoc.HelpGen.Types,
  XmlDoc.HelpGen.CrossRef;

type
  /// <summary>렌더링 옵션</summary>
  TRenderOptions = record
    CSSTheme: string;
    FooterText: string;
    IncludeInheritanceTree: Boolean;
    IncludePrivate: Boolean;
    IncludeSearchIndex: Boolean;
    IncludeSource: Boolean;
    LogoPath: string;
    OutputDir: string;
    Title: string;
  end;

  /// <summary>문서 렌더러 인터페이스</summary>
  IDocRenderer = interface
    ['{B3F5C2A1-8D4E-47F9-A2C1-6E3B5D8F1A2C}']
    procedure Render(
      const AUnits: TObjectList<TUnitDocInfo>;
      const AResolver: TCrossRefResolver;
      const AOptions: TRenderOptions
    );
  end;

implementation

end.
