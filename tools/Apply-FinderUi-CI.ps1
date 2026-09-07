[CmdletBinding()]
param([string]$Root = (Resolve-Path ".").Path)
$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "Apply-FinderUi.ps1") -Root $Root

function ReadText($p) { [IO.File]::ReadAllText($p) }
function WriteText($p,$t) { [IO.File]::WriteAllText($p,$t,(New-Object Text.UTF8Encoding($false))) }

$src = Join-Path $Root "src/Span/Span"
$mainCs = Join-Path $src "MainWindow.xaml.cs"
$main = Join-Path $src "MainWindow.xaml"
$manifest = Join-Path $src "Package.appxmanifest"

# Normalize the literal newline emitted by the base patch into valid C# source.
$t = ReadText $mainCs
$literal = 'SetTitleBar(AppTitleBar);`r`n            InitializeFinderChrome();'
$fixed = "SetTitleBar(AppTitleBar);`r`n            InitializeFinderChrome();"
$t = $t.Replace($literal, $fixed)
WriteText $mainCs $t

# Remove the last hard-coded yellow folder in the tab strip.
$t = ReadText $main
$t = $t.Replace('Foreground="#FFD54F"', 'Foreground="#5AB8F5"')
WriteText $main $t

# FinderSpan must not install as the official SPAN package. Give the fork an
# independent identity whose Publisher matches the ephemeral CI signing cert.
$t = ReadText $manifest
$t = $t.Replace('Name="LumiBearStudio.SPANFinder"', 'Name="FinderSpan.FinderSpan"')
$t = [regex]::Replace($t, 'Publisher="CN=[^"]+"', 'Publisher="CN=FinderSpan"', 1)
$t = $t.Replace('<PublisherDisplayName>LumiBear Studio</PublisherDisplayName>', '<PublisherDisplayName>FinderSpan</PublisherDisplayName>')
$t = $t.Replace('Alias="spanfinder.exe"', 'Alias="finderspan.exe"')
WriteText $manifest $t

Write-Host "FinderSpan CI patch normalized and package identity separated from upstream." -ForegroundColor Green
