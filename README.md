# XmlDoc Plugin for Delphi

An **XML Documentation** plugin integrated into the Delphi IDE. Write C#-style `///` XML comments with a WYSIWYG editor and generate full API documentation for your projects.

[한국어](README.ko.md)

## Why This Project?

XML Documentation comments (`///`) are a standard practice in C# and many other languages, yet Delphi has never shipped with built-in tooling to author or manage them. The only option available today is [Documentation Insight](https://www.devjetsoftware.com/products/documentation-insight/) by DevJet Software — a well-made commercial product, but its licensing cost can be a barrier, especially for individual developers, small teams, and open-source contributors.

This project was born from a simple belief: **writing documentation should be a first-class feature of any modern IDE, not a paid add-on.** We hope that by building an open-source alternative, we can both serve the community today and encourage Embarcadero to eventually provide official XML documentation support in Delphi.

## Features

### IDE Plugin (BPL)

- **Doc Inspector** — A docking panel that provides real-time editing of XML documentation for the code element at the cursor position
- **Documentation Explorer** — Browse the entire unit's classes, methods, and properties in a tree view while editing their documentation
- **WYSIWYG Editor** — TipTap-based rich text editor rendered via TEdgeBrowser (WebView2)
- **Doc Stub Generation** — Generate documentation stubs with a single shortcut, including parameters, return types, and generic type parameters
- **Undocumented Element Navigation** — Jump sequentially through elements that lack documentation
- **Coverage Report** — Analyze and report documentation coverage across your project
- **Customizable Shortcuts** — All features are accessible via user-configurable keyboard shortcuts

### Documentation Engine (HelpGen)

- **Multiple Output Formats** — HTML, Markdown, CHM (Windows Help), JSON
- **Theme Engine** — Customizable HTML themes
- **Cross-References** — Automatic link generation between types and members
- **Static Site Publishing** — Generate standalone API documentation sites

### CLI Tool (XmlDocGen)

```
XmlDocGen -d "C:\MyProject\src" -o "C:\MyProject\docs" -f HTML,MD
```

Generate documentation from the command line. Integrates with CI/CD pipelines.

## Supported XML Tags

| Tag | Description |
|-----|-------------|
| `<summary>` | Brief description of an element |
| `<param>` | Method parameter description |
| `<returns>` | Return value description |
| `<remarks>` | Additional notes |
| `<value>` | Property value description |
| `<typeparam>` | Generic type parameter description |
| `<exception>` | Possible exception documentation |
| `<example>` | Usage example |
| `<seealso>` | Related item reference |

```pascal
/// <summary>Retrieves information for the specified user.</summary>
/// <param name="AUserId">The ID of the user to look up</param>
/// <returns>User info, or nil if not found</returns>
/// <exception cref="EAuthException">Raised when not authenticated</exception>
function GetUser(const AUserId: Integer): TUser;
```

## Project Structure

```
src/
  Core/         Core modules (parser, model, codegen — shared by BPL and CLI)
  Plugin/       IDE plugin (BPL)
  HelpGen/      Batch documentation generation engine
  CLI/          Command-line tool
  Packages/     Delphi package project files
web/            TipTap WYSIWYG editor (TypeScript + Vite)
tests/          DUnitX unit tests
vendor/         External libraries (DelphiAST)
docs/           Generated API documentation
resources/      Built web resources
```

## Building

### Prerequisites

- Delphi 11 Alexandria or later (requires TEdgeBrowser / WebView2)
- Node.js 18+ (for building the web editor)
- WebView2 Runtime (included by default on Windows 10/11)

### Build Steps

```bash
# 1. Build the web editor
cd web
npm install
npm run build

# 2. Compile resources
cd ../src/Plugin
brcc32 XmlDocEditor.rc

# 3. Build the BPL in Delphi
# Open src/Packages/13/XmlDocPlugin.dpk → Build + Install
```

## Tech Stack

| Area | Technology |
|------|------------|
| IDE Plugin | Delphi OTA (Open Tools API), VCL |
| Source Parsing | [DelphiAST](https://github.com/RomanYankworsky/DelphiAST) |
| Doc Editor | [TipTap](https://tiptap.dev/) + TypeScript, WebView2 |
| Build Tool | Vite + vite-plugin-singlefile |
| Testing | DUnitX |

## License

- DelphiAST: [MPL 2.0](vendor/DelphiAST/LICENSE)
