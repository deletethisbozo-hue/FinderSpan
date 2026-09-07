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
$details = Join-Path $src "Views/DetailsModeView.xaml"
$detailsCs = Join-Path $src "Views/DetailsModeView.xaml.cs"

# Normalize literal newline sequences emitted by the base patch into valid C#.
$t = ReadText $mainCs
foreach($pair in @(
  @('SetTitleBar(AppTitleBar);`r`n            InitializeFinderChrome();', "SetTitleBar(AppTitleBar);`r`n            InitializeFinderChrome();"),
  @('SetTitleBar(FinderToolbar);`r`n            InitializeFinderChrome();', "SetTitleBar(FinderToolbar);`r`n            InitializeFinderChrome();")
)) {
  $t = $t.Replace($pair[0], $pair[1])
}
WriteText $mainCs $t

# Normalize visual details that are intentionally applied after the broad base patch.
$t = ReadText $main
$t = $t.Replace('Foreground="#FFD54F"', 'Foreground="#4DA3E8"')
$t = [regex]::Replace(
  $t,
  '(<!-- Sidebar bottom bar:[^\r\n]*-->\s*<Grid Grid.Row="1")(?![^>]*Visibility=)',
  '$1 Visibility="Collapsed"',
  1)
$t = [regex]::Replace(
  $t,
  '(<Grid x:Name="LeftPaneContainer"[^>]*\s)Background="Transparent"',
  '$1Background="#FFFFFF"',
  1)
$t = [regex]::Replace(
  $t,
  '(<Border x:Name="SidebarSplitter"[^>]*\s)Background="\{ThemeResource SpanBgLayer1Brush\}"',
  '$1Background="Transparent"',
  1)
WriteText $main $t

# Enforce Finder list semantics: Name / Date Modified / Size / Kind.
$t = ReadText $details
$t = [regex]::Replace(
  $t,
  '(<Button x:Name="TypeHeaderButton"\s+)Content="[^"]+"([\s\S]*?)Tag="[^"]+"',
  '$1Content="Size"$2Tag="Size"',
  1)
$t = [regex]::Replace(
  $t,
  '(<Button x:Name="SizeHeaderButton"\s+)Content="[^"]+"([\s\S]*?)Tag="[^"]+"',
  '$1Content="Kind"$2Tag="Type"',
  1)
$t = [regex]::Replace(
  $t,
  '(<Grid Grid.Column="11" x:Name="GitHeaderContainer")(?![^>]*Visibility=)',
  '$1 Visibility="Collapsed"',
  1)
$t = [regex]::Replace(
  $t,
  '(<Grid Grid.Row="0" Height="22"[\s\S]*?x:Name="HeaderGrid"[\s\S]*?)Background="\{ThemeResource SpanBgLayer2Brush\}"',
  '$1Background="#F8F8F8"',
  1)
$t = [regex]::Replace(
  $t,
  '(<Grid Grid.Row="0" Height="22"[\s\S]*?x:Name="HeaderGrid"[\s\S]*?)BorderBrush="\{ThemeResource SpanBorderSubtleBrush\}"',
  '$1BorderBrush="#D5D5D5"',
  1)
WriteText $details $t

# Localization runs after XAML load, so keep the Finder column names there too.
$t = ReadText $detailsCs
$t = [regex]::Replace(
  $t,
  'TypeHeaderButton\.Content\s*=\s*_loc\.Get\("Type"\);\s*SizeHeaderButton\.Content\s*=\s*_loc\.Get\("Size"\);',
  'TypeHeaderButton.Content = _loc.Get("Size");`r`n            SizeHeaderButton.Content = "Kind";',
  1)
# Convert the replacement's literal CRLF marker if regex replacement preserved it literally.
$t = $t.Replace('TypeHeaderButton.Content = _loc.Get("Size");`r`n            SizeHeaderButton.Content = "Kind";', "TypeHeaderButton.Content = _loc.Get(`"Size`");`r`n            SizeHeaderButton.Content = `"Kind`";")
WriteText $detailsCs $t

# FinderSpan must not install as the official SPAN package. Give the fork an
# independent identity whose Publisher matches the ephemeral CI signing cert.
$t = ReadText $manifest
$t = $t.Replace('Name="LumiBearStudio.SPANFinder"', 'Name="FinderSpan.FinderSpan"')
$t = [regex]::Replace($t, 'Publisher="CN=[^"]+"', 'Publisher="CN=FinderSpan"', 1)
$t = $t.Replace('<PublisherDisplayName>LumiBear Studio</PublisherDisplayName>', '<PublisherDisplayName>FinderSpan</PublisherDisplayName>')
$t = $t.Replace('Alias="spanfinder.exe"', 'Alias="finderspan.exe"')
WriteText $manifest $t

Write-Host "FinderSpan classic Finder CI patch normalized and package identity separated from upstream." -ForegroundColor Green
