[CmdletBinding()]
param([string]$Configuration = "Release", [string]$Platform = "x64")
$ErrorActionPreference = "Stop"

$solution = "src/Span/Span.sln"
if (-not (Test-Path $solution)) { throw "Run this from the FinderSpan repository root." }

$msbuild = Get-Command msbuild -ErrorAction SilentlyContinue
if (-not $msbuild) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $install = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
        if ($install) {
            $candidate = Join-Path $install "MSBuild\Current\Bin\MSBuild.exe"
            if (Test-Path $candidate) { $msbuild = $candidate }
        }
    }
}
if (-not $msbuild) { throw "MSBuild not found. Install Visual Studio 2022 Build Tools with WinUI/Windows App SDK components." }

& $msbuild $solution /t:Restore /p:Configuration=$Configuration /p:Platform=$Platform
if ($LASTEXITCODE -ne 0) { throw "Restore failed" }
& $msbuild $solution /m /p:Configuration=$Configuration /p:Platform=$Platform
if ($LASTEXITCODE -ne 0) { throw "Build failed" }

Write-Host "FinderSpan build complete." -ForegroundColor Green
