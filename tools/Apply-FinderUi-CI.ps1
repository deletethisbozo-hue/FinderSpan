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
$mainVm = Join-Path $src "ViewModels/MainViewModel.cs"
$settingsSvc = Join-Path $src "Services/SettingsService.cs"

# Normalize literal newline sequences emitted by the base patch into valid C#.
$t = ReadText $mainCs
foreach($pair in @(
  @('SetTitleBar(AppTitleBar);`r`n            InitializeFinderChrome();', "SetTitleBar(AppTitleBar);`r`n            InitializeFinderChrome();"),
  @('SetTitleBar(FinderToolbar);`r`n            InitializeFinderChrome();', "SetTitleBar(FinderToolbar);`r`n            InitializeFinderChrome();")
)) {
  $t = $t.Replace($pair[0], $pair[1])
}
WriteText $mainCs $t

# -----------------------------------------------------------------------------
# Keep the Finder look, but restore the REAL SpanFinder sidebar underneath.
# The previous skin inserted a static mock sidebar (AirDrop, fake Tags, hard-coded
# iCloud/OneDrive entries) and hid the original dynamic sidebar. Remove the mock
# completely and unhide the original so Favorites drag/drop, real cloud drives,
# local/network drives and context menus keep working.
# -----------------------------------------------------------------------------
$t = ReadText $main

# Remove the injected static Finder sidebar ScrollViewer.
$t = [regex]::Replace(
  $t,
  '(?s)\s*<ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">\s*<StackPanel Padding="6,8,6,8" Spacing="0">.*?</ScrollViewer>\s*(?=<ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Visibility="Collapsed")',
  "`r`n                ",
  1)

# Re-enable the original dynamic sidebar and make its spacing Finder-like.
$t = $t.Replace(
  '<ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Visibility="Collapsed"',
  '<ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"')
$t = $t.Replace('<StackPanel Padding="0,12">','<StackPanel Padding="6,8">')
$t = $t.Replace('<Grid Height="28" Padding="12,0" Background="Transparent"','<Grid Height="27" Margin="3,1" Padding="8,0" Background="Transparent"')
$t = $t.Replace('<Grid Height="26" Padding="12,0,8,0"','<Grid Height="26" Margin="3,1" Padding="8,0,6,0"')
$t = $t.Replace('Margin="16,0,16,8"','Margin="8,6,8,5"')
$t = $t.Replace('Margin="12,12"','Margin="8,6"')

# Keep visual polish from the Finder skin.
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

# -----------------------------------------------------------------------------
# Restore original navigation behavior. The skin had forced Details view and
# disabled preview globally, which made the app feel less like SpanFinder and
# required manually choosing Miller Columns. Keep the Finder visual skin while
# preserving the upstream behavior/preferences.
# -----------------------------------------------------------------------------
$t = ReadText $mainVm
$t = $t.Replace('private ViewMode _leftViewMode = ViewMode.Details;','private ViewMode _leftViewMode = ViewMode.MillerColumns;')
$t = $t.Replace('private ViewMode _rightViewMode = ViewMode.Details;','private ViewMode _rightViewMode = ViewMode.MillerColumns;')
$t = $t.Replace('private ViewMode _currentViewMode = ViewMode.Details;','private ViewMode _currentViewMode = ViewMode.MillerColumns;')
$t = $t.Replace('private bool _isLeftPreviewEnabled = false;','private bool _isLeftPreviewEnabled = true;')
$t = $t.Replace('private bool _isRightPreviewEnabled = false;','private bool _isRightPreviewEnabled = true;')
WriteText $mainVm $t

$t = ReadText $settingsSvc
$t = $t.Replace('get => Get("DefaultViewMode", 1); // FinderSpan default = Details','get => Get("DefaultViewMode", 0); // FinderSpan default = MillerColumns')
WriteText $settingsSvc $t

# Enforce Finder list semantics when the user explicitly chooses Details view:
# Name / Date Modified / Size / Kind.
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

Write-Host "FinderSpan Finder skin applied with dynamic sidebar and original navigation behavior restored." -ForegroundColor Green
