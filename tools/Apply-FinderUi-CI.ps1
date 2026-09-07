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
$keyboard = Join-Path $src "MainWindow.KeyboardHandler.cs"
$address = Join-Path $src "Controls/AddressBarControl.xaml"
$chrome = Join-Path $src "MainWindow.FinderChrome.cs"

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
# Finder chrome without fake features.
# Keep the visual language from the screenshot, but expose SpanFinder's real,
# dynamic Windows functionality underneath.
# -----------------------------------------------------------------------------
$t = ReadText $main

# Remove the static mock sidebar inserted by the broad Finder skin.
# That sidebar contained decorative AirDrop/Tags and hard-coded cloud entries.
$t = [regex]::Replace(
  $t,
  '(?s)\s*<ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">\s*<StackPanel Padding="6,8,6,8" Spacing="0">.*?</ScrollViewer>\s*(?=<ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Visibility="Collapsed")',
  "`r`n                ",
  1)

# Re-enable the original dynamic sidebar: real Favorites drag/drop, local disks,
# CloudDrives (OneDrive/iCloud/etc.), mapped/network drives and context menus.
$t = $t.Replace(
  '<ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Visibility="Collapsed"',
  '<ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"')
$t = $t.Replace('<StackPanel Padding="0,12">','<StackPanel Padding="6,8">')
$t = $t.Replace('<Grid Height="28" Padding="12,0" Background="Transparent"','<Grid Height="27" Margin="3,1" Padding="8,0" Background="Transparent"')
$t = $t.Replace('<Grid Height="26" Padding="12,0,8,0"','<Grid Height="26" Margin="3,1" Padding="8,0,6,0"')
$t = $t.Replace('Margin="16,0,16,8"','Margin="8,6,8,5"')
$t = $t.Replace('Margin="12,12"','Margin="8,6"')

# Put the toolbar above an optional tab strip, like Finder. Single-tab windows
# keep the tab strip collapsed; code-behind reveals it only for 2+ tabs.
$t = $t.Replace('<Grid x:Name="FinderToolbar" Grid.Row="1"','<Grid x:Name="FinderToolbar" Grid.Row="0"')
$t = $t.Replace('<Grid x:Name="AppTitleBar" Height="{StaticResource TitleBarHeight}"','<Grid x:Name="AppTitleBar" Grid.Row="1" Height="{StaticResource TitleBarHeight}"')
$t = $t.Replace(
  '<StackPanel Orientation="Horizontal" Grid.Column="0" VerticalAlignment="Center" Margin="16,0,16,0" Spacing="8">',
  '<StackPanel Orientation="Horizontal" Grid.Column="0" VerticalAlignment="Center" Margin="16,0,16,0" Spacing="8" Visibility="Collapsed">')

# Use the real address/breadcrumb control instead of overlaying a second title.
# This fixes the stray OneDrive/cloud icon overlap and keeps Ctrl+L/Alt+D alive.
$t = $t.Replace('<TextBlock x:Name="FinderCurrentFolderTitle" Grid.ColumnSpan="3"','<TextBlock x:Name="FinderCurrentFolderTitle" Grid.ColumnSpan="3" Visibility="Collapsed"')
$t = $t.Replace('<appcontrols:AddressBarControl x:Name="MainAddressBar" Grid.Column="1" Visibility="Collapsed"','<appcontrols:AddressBarControl x:Name="MainAddressBar" Grid.Column="1"')
# These legacy address icons can be made Visible by upstream navigation code;
# force their layout footprint to zero so they can never overlap breadcrumbs.
$t = $t.Replace('<StackPanel x:Name="HomeAddressIcon" Grid.Column="0" Orientation="Horizontal"','<StackPanel x:Name="HomeAddressIcon" Grid.Column="0" Orientation="Horizontal" Width="0" Opacity="0" IsHitTestVisible="False"')
$t = $t.Replace('<StackPanel x:Name="RecycleBinAddressIcon" Grid.Column="0" Orientation="Horizontal"','<StackPanel x:Name="RecycleBinAddressIcon" Grid.Column="0" Orientation="Horizontal" Width="0" Opacity="0" IsHitTestVisible="False"')

# The Finder-looking Share button now launches the REAL Google Quick Share app
# when installed. If Quick Share is absent, code-behind keeps this button hidden.
$t = $t.Replace(
  'ToolTipService.ToolTip="Share / copy path" Click="OnFinderShareClick"',
  'x:Name="FinderQuickShareButton" Visibility="Collapsed" ToolTipService.ToolTip="Quick Share" Click="OnFinderQuickShareClick"')

# Remove the decorative Finder-style Tags button completely. Upstream's real
# folder-tag support remains available from its native context menus where valid.
$t = [regex]::Replace(
  $t,
  '(?s)\s*<Button Style="\{StaticResource UnifiedButtonStyle\}" Width="34" Height="28" MinWidth="34" Padding="0" ToolTipService\.ToolTip="Tags">.*?</Button>\s*',
  "`r`n",
  1)

# Quick Share replaces AirDrop semantically on Windows. Put it at the top of the
# real Favorites section, but keep it hidden unless Google Quick Share is found.
$quickShareSidebar = @'
                        <Grid x:Name="FinderQuickShareSidebarItem" Height="27" Margin="3,1" Padding="8,0"
                              Background="Transparent" Visibility="Collapsed"
                              Tapped="OnFinderQuickShareSidebarTapped"
                              PointerEntered="OnSidebarItemPointerEntered" PointerExited="OnSidebarItemPointerExited"
                              PointerPressed="OnSidebarItemPointerPressed" PointerReleased="OnSidebarItemPointerReleased"
                              ToolTipService.ToolTip="Quick Share">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <FontIcon Grid.Column="0" Glyph="&#xE72D;" FontSize="16" Foreground="#4DA3E8"
                                      VerticalAlignment="Center" Margin="0,0,12,0"/>
                            <TextBlock Grid.Column="1" Text="Quick Share"
                                       FontSize="{Binding ItemFontSize, Source={StaticResource FontScale}}"
                                       VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                        </Grid>
'@
$favoriteListAnchor = '                        <!-- Flat Favorites List (default, no tree expansion) -->'
if (-not $t.Contains($favoriteListAnchor)) { throw 'Finder Quick Share sidebar anchor not found.' }
$t = $t.Replace($favoriteListAnchor, $quickShareSidebar + "`r`n`r`n" + $favoriteListAnchor)

# Visual polish retained from the Finder skin.
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

# Hide breadcrumb glyphs. They were the blue cloud/folder blobs visible beside
# OneDrive in the toolbar. Text + chevrons remain fully functional.
$t = ReadText $address
$t = [regex]::Replace(
  $t,
  '(<FontIcon Glyph="\{x:Bind IconGlyph\}"[\s\S]*?)Visibility="\{x:Bind IconVisibility\}"',
  '$1Visibility="Collapsed"',
  1)
$t = $t.Replace('Foreground="{ThemeResource SpanTextSecondaryBrush}"/>','Foreground="#303030"/>')
WriteText $address $t

# -----------------------------------------------------------------------------
# Restore upstream navigation behavior and performance characteristics.
# The earlier Finder pass forced Details everywhere and disabled preview, which
# made the app feel like a different, less capable program.
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

# Ctrl+F must reveal the Finder search field before focusing it.
$t = ReadText $keyboard
$t = $t.Replace(
  'SearchBox.Focus(FocusState.Keyboard);  // Ctrl+F → 검색',
  'SearchBox.Visibility = Visibility.Visible;`r`n                            SearchBox.Focus(FocusState.Keyboard);`r`n                            SearchBox.SelectAll();  // Ctrl+F → Finder search')
$t = $t.Replace(
  'SearchBox.Visibility = Visibility.Visible;`r`n                            SearchBox.Focus(FocusState.Keyboard);`r`n                            SearchBox.SelectAll();  // Ctrl+F → Finder search',
  "SearchBox.Visibility = Visibility.Visible;`r`n                            SearchBox.Focus(FocusState.Keyboard);`r`n                            SearchBox.SelectAll();  // Ctrl+F → Finder search")
WriteText $keyboard $t

# Details view stays available and Finder-like when explicitly selected:
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

$t = ReadText $detailsCs
$t = [regex]::Replace(
  $t,
  'TypeHeaderButton\.Content\s*=\s*_loc\.Get\("Type"\);\s*SizeHeaderButton\.Content\s*=\s*_loc\.Get\("Size"\);',
  'TypeHeaderButton.Content = _loc.Get("Size");`r`n            SizeHeaderButton.Content = "Kind";',
  1)
$t = $t.Replace('TypeHeaderButton.Content = _loc.Get("Size");`r`n            SizeHeaderButton.Content = "Kind";', "TypeHeaderButton.Content = _loc.Get(`"Size`");`r`n            SizeHeaderButton.Content = `"Kind`";")
WriteText $detailsCs $t

# -----------------------------------------------------------------------------
# Replace the broad skin's chrome helper with a Windows-aware implementation.
# Quick Share is shown only when an actual installation is detected.
# -----------------------------------------------------------------------------
$chromeSource = @'
using System;
using System.Collections.Specialized;
using System.Diagnostics;
using System.IO;
using System.Linq;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;

namespace Span {
  public sealed partial class MainWindow {
    private const int FinderSW_MINIMIZE = 6;
    private const int FinderSW_MAXIMIZE = 3;
    private const int FinderSW_RESTORE = 9;
    private string? _finderQuickShareTarget;

    private void InitializeFinderChrome(){
      try {
        AppWindow.Title = "FinderSpan";
        if(AppWindow.Presenter is OverlappedPresenter presenter) presenter.SetBorderAndTitleBar(true,false);
        AppWindow.TitleBar.ButtonBackgroundColor = Microsoft.UI.Colors.Transparent;
        AppWindow.TitleBar.ButtonInactiveBackgroundColor = Microsoft.UI.Colors.Transparent;

        _finderQuickShareTarget = FindQuickShareTarget();
        UpdateFinderQuickShareVisibility();
        UpdateFinderTabStripVisibility();
        ViewModel.Tabs.CollectionChanged += OnFinderTabsChanged;
      } catch(Exception ex){ Helpers.DebugLogger.Log($"[FinderChrome] {ex.Message}"); }
    }

    private void OnFinderTabsChanged(object? sender, NotifyCollectionChangedEventArgs e)
      => UpdateFinderTabStripVisibility();

    private void UpdateFinderTabStripVisibility(){
      try {
        bool show = ViewModel.Tabs.Count > 1;
        AppTitleBar.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
        AppTitleBar.Height = show ? 34 : 0;
      } catch { }
    }

    private void OnFinderCloseClick(object sender,RoutedEventArgs e)=>Close();
    private void OnFinderMinimizeClick(object sender,RoutedEventArgs e){ if(_hwnd!=IntPtr.Zero) ShowWindow(_hwnd,FinderSW_MINIMIZE); }
    private void OnFinderZoomClick(object sender,RoutedEventArgs e){ if(_hwnd!=IntPtr.Zero) ShowWindow(_hwnd,IsZoomed(_hwnd)?FinderSW_RESTORE:FinderSW_MAXIMIZE); }

    private void OnFinderSearchClick(object sender, RoutedEventArgs e){
      SearchBox.Visibility = Visibility.Visible;
      SearchBox.Focus(FocusState.Programmatic);
      SearchBox.SelectAll();
    }

    private void OnFinderSearchLostFocus(object sender, RoutedEventArgs e){
      if(string.IsNullOrWhiteSpace(SearchBox.Text)) SearchBox.Visibility = Visibility.Collapsed;
    }

    private void UpdateFinderQuickShareVisibility(){
  try {
    var visibility = string.IsNullOrWhiteSpace(_finderQuickShareTarget)
      ? Visibility.Collapsed
      : Visibility.Visible;
    FinderQuickShareButton.Visibility = visibility;
    FinderQuickShareSidebarItem.Visibility = visibility;
  } catch { }
}

    private void LaunchFinderQuickShare(){
  try {
    _finderQuickShareTarget ??= FindQuickShareTarget();
    if(string.IsNullOrWhiteSpace(_finderQuickShareTarget)) {
      UpdateFinderQuickShareVisibility();
      ViewModel.ShowToast("Quick Share is not installed.");
      return;
    }
    Process.Start(new ProcessStartInfo(_finderQuickShareTarget) { UseShellExecute = true });
  } catch(Exception ex){
    Helpers.DebugLogger.Log($"[FinderQuickShare] {ex.Message}");
    ViewModel.ShowToast("Could not open Quick Share.");
  }
}

private void OnFinderQuickShareClick(object sender, RoutedEventArgs e)
  => LaunchFinderQuickShare();

private void OnFinderQuickShareSidebarTapped(object sender, TappedRoutedEventArgs e)
  => LaunchFinderQuickShare();

    private static string? FindQuickShareTarget(){
      try {
        string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        string[] exeCandidates = {
          Path.Combine(programFiles, "Google", "NearbyShare", "nearby_share.exe"),
          Path.Combine(programFiles, "Google", "NearbyShare", "nearby_share_launcher.exe"),
          Path.Combine(localAppData, "Google", "NearbyShare", "nearby_share.exe")
        };
        foreach(string candidate in exeCandidates)
          if(File.Exists(candidate)) return candidate;

        string[] shortcutRoots = {
          Environment.GetFolderPath(Environment.SpecialFolder.Programs),
          Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms)
        };
        foreach(string root in shortcutRoots){
          try {
            if(string.IsNullOrWhiteSpace(root) || !Directory.Exists(root)) continue;
            var shortcut = Directory.EnumerateFiles(root, "*.lnk", SearchOption.AllDirectories)
              .FirstOrDefault(p => {
                string name = Path.GetFileNameWithoutExtension(p);
                return name.Contains("Quick Share", StringComparison.OrdinalIgnoreCase)
                    || name.Contains("Nearby Share", StringComparison.OrdinalIgnoreCase);
              });
            if(shortcut != null) return shortcut;
          } catch { }
        }
      } catch { }
      return null;
    }
  }
}
'@
WriteText $chrome $chromeSource

# Independent FinderSpan package identity / branding.
$t = ReadText $manifest
$t = $t.Replace('Name="LumiBearStudio.SPANFinder"', 'Name="FinderSpan.FinderSpan"')
$t = [regex]::Replace($t, 'Publisher="CN=[^"]+"', 'Publisher="CN=FinderSpan"', 1)
$t = $t.Replace('<PublisherDisplayName>LumiBear Studio</PublisherDisplayName>', '<PublisherDisplayName>FinderSpan</PublisherDisplayName>')
$t = $t.Replace('Alias="spanfinder.exe"', 'Alias="finderspan.exe"')
WriteText $manifest $t

Write-Host "FinderSpan Finder skin applied with real Windows sidebar, Quick Share detection, tabs and navigation restored." -ForegroundColor Green
