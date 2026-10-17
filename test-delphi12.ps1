param([string]$Bds = 'D:\Embarcadero RAD Studio\23.0')
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path $env:LOCALAPPDATA 'XmlDocPlugin\Tests'
$sdk = Join-Path $env:LOCALAPPDATA 'XmlDocPlugin\Build\WebView2-1.0.2045.28\sdk'
if (!(Test-Path "$sdk\build\native\x86\WebView2Loader.dll")) {
    throw 'Run build-delphi12.ps1 first to obtain the WebView2 SDK.'
}
function Compile-Test([string]$Compiler, [string]$Name, [string]$Output) {
    $search = "src\Core;src\Plugin;vendor\DelphiAST\Source;vendor\DelphiAST\Source\SimpleParser;$Bds\source\DunitX"
    & cmd.exe /d /c "`"$Bds\bin\rsvars.bat`" && $Compiler -B --codepage:65001 -NSSystem;System.Win;Winapi;Vcl `"-U$search`" `"-E$Output`" `"-N0$Output`" tests\$Name.dpr"
    if ($LASTEXITCODE) { throw "$Name compilation failed" }
}
Push-Location $PSScriptRoot
try {
    Push-Location tests
    try {
        & "$Bds\bin\brcc32.exe" BrowserSmoke.rc
        if ($LASTEXITCODE) { throw 'Smoke resource compilation failed' }
    } finally { Pop-Location }
    foreach ($arch in @('x86', 'x64')) {
        $output = Join-Path $testRoot $arch
        New-Item -ItemType Directory -Force $output | Out-Null
        Copy-Item "$sdk\build\native\$arch\WebView2Loader.dll" $output
        $compiler = if ($arch -eq 'x86') { 'dcc32' } else { 'dcc64' }
        foreach ($name in @('SettingsSmoke', 'BrowserSmoke', 'XmlDocTests')) {
            Compile-Test $compiler $name $output
            & "$output\$name.exe"
            if ($LASTEXITCODE) { throw "$arch $name failed" }
        }
    }
} finally { Pop-Location }
