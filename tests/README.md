# Delphi 12 tests

Run `build-delphi12.ps1`, then `test-delphi12.ps1` from the repository root.
Both scripts accept `-Bds` for the Delphi installation directory. Test binaries
and DCUs are written below `%LOCALAPPDATA%\XmlDocPlugin\Tests`.

The settings smoke test changes persisted settings temporarily and restores
their original values in `finally`; close the IDE before running it.
The browser smoke test uses the actual embedded editor and WebView2 Runtime.
It checks document rendering, light/dark/system themes, and saved section state
through three HWND recreations on both Win32 and Win64.

The full core suite runs on both Win32 and Win64, alongside the settings and
browser smoke tests. The script returns a failure status if any test fails.

For IDE integration, open Doc Inspector, dock it in an IDE tab group, and check
that its content and selected documentation remain visible. Save the desktop
layout, close the IDE, and reopen that layout. Verify that Inspector is recreated
in the same tab group and its section choices and editor theme are preserved.
