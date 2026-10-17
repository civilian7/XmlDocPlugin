param(
    [string]$Bds = 'D:\Embarcadero RAD Studio\23.0',
    [ValidateSet('Debug', 'Release')][string]$Config = 'Release',
    [string]$OutputDir = "$env:PUBLIC\Documents\Embarcadero\Studio\23.0\Bpl"
)
$ErrorActionPreference = 'Stop'
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$cache = Join-Path $env:LOCALAPPDATA 'XmlDocPlugin\Build\WebView2-1.0.2045.28'
New-Item -ItemType Directory -Force $cache, $OutputDir | Out-Null
$archive = Join-Path $cache 'sdk.zip'
if (!(Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest 'https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/1.0.2045.28/microsoft.web.webview2.1.0.2045.28.nupkg' -OutFile $archive
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne '6488BF8E5A84F1E2D41AC2DA789052CB5C731D043A0BE4A2D764EF703A72DFB7') {
    throw 'WebView2 SDK archive checksum mismatch.'
}
Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $cache 'sdk') -Force
Push-Location $PSScriptRoot
try {
    Push-Location web
    try {
        & npm.cmd ci --no-audit --no-fund
        if ($LASTEXITCODE) { throw 'npm ci failed' }
        & npm.cmd run build
        if ($LASTEXITCODE) { throw 'Web editor build failed' }
    } finally { Pop-Location }
    Push-Location src\Plugin
    try {
        & "$Bds\bin\brcc32.exe" XmlDocEditor.rc
        if ($LASTEXITCODE) { throw 'Resource compilation failed' }
    } finally { Pop-Location }
    & cmd.exe /d /c "`"$Bds\bin\rsvars.bat`" && msbuild src\Packages\12\XmlDocPlugin.dproj /t:Build /p:Config=$Config /p:Platform=Win32 `"/p:DCC_BplOutput=$OutputDir`" /v:minimal"
    if ($LASTEXITCODE) { throw 'Delphi package build failed' }
    Copy-Item -LiteralPath "$cache\sdk\build\native\x86\WebView2Loader.dll" -Destination $OutputDir
    Copy-Item -LiteralPath "$cache\sdk\LICENSE.txt" -Destination (Join-Path $OutputDir 'WebView2-LICENSE.txt')
    Copy-Item -LiteralPath "$cache\sdk\NOTICE.txt" -Destination (Join-Path $OutputDir 'WebView2-NOTICE.txt')
} finally { Pop-Location }
Write-Host "Built Delphi 12 Win32 IDE package in $OutputDir"
