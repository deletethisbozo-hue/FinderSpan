[CmdletBinding()]
param([string]$Root = (Resolve-Path ".").Path)
$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "Apply-FinderUi.ps1") -Root $Root

function ReadText($p) { [IO.File]::ReadAllText($p) }
function WriteText($p,$t) { [IO.File]::WriteAllText($p,$t,(New-Object Text.UTF8Encoding($false))) }

$src = Join-Path $Root "src/Span/Span"
$mainCs = Join-Path $src "MainWindow.xaml.cs"
$main = Join-Path $src "MainWindow.xaml"

# v1 patch intentionally used a literal replacement string; normalize it to a real newline for C# compilation.
$t = ReadText $mainCs
$literal = 'SetTitleBar(AppTitleBar);`r`n            InitializeFinderChrome();'
$fixed = "SetTitleBar(AppTitleBar);`r`n            InitializeFinderChrome();"
$t = $t.Replace($literal, $fixed)
WriteText $mainCs $t

# Remove the last hard-coded yellow folder in the tab strip.
$t = ReadText $main
$t = $t.Replace('Foreground="#FFD54F"', 'Foreground="#5AB8F5"')
WriteText $main $t

Write-Host "FinderSpan CI patch normalized." -ForegroundColor Green
