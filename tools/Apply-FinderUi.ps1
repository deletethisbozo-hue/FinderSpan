[CmdletBinding()]
param([string]$Root = (Resolve-Path ".").Path)
$ErrorActionPreference = "Stop"

function ReadText($p) { [IO.File]::ReadAllText($p) }
function WriteText($p,$t) { [IO.File]::WriteAllText($p,$t,(New-Object Text.UTF8Encoding($false))) }
function ReplaceRequired($p,$old,$new,$label) {
  $t = ReadText $p
  if (-not $t.Contains($old)) { throw "FinderSpan patch failed [$label]: expected source not found in $p" }
  WriteText $p ($t.Replace($old,$new))
  Write-Host "patched: $label"
}

$src = Join-Path $Root "src/Span/Span"
$app = Join-Path $src "App.xaml"
$main = Join-Path $src "MainWindow.xaml"
$mainCs = Join-Path $src "MainWindow.xaml.cs"
$settings = Join-Path $src "MainWindow.SettingsHandler.cs"
$address = Join-Path $src "Controls/AddressBarControl.xaml"
$manifest = Join-Path $src "Package.appxmanifest"
$iconSvc = Join-Path $src "Services/IconService.cs"

foreach($p in @($app,$main,$mainCs,$settings,$address,$manifest,$iconSvc)) { if(-not (Test-Path $p)){ throw "Missing upstream file: $p" } }

# Finder/Tahoe palette and geometry
$t = ReadText $app
$map = [ordered]@{
  '#1C2838'='#1F1F21'; '#223248'='#29292C'; '#2A3C55'='#303033'; '#334A66'='#3A3A3D';
  '#5CA8E8'='#0A84FF'; '#79B9F0'='#3498FF'; '#805CA8E8'='#990A84FF';
  '#F5F8FC'='#F5F5F7'; '#B8C5D4'='#B2B2B7'; '#7F91A5'='#8E8E93';
  '#F5F8FB'='#F6F6F8'; '#EDF3F9'='#ECECEF'; '#E3EBF3'='#E4E4E8';
  '#2878B8'='#007AFF'; '#1E6DA8'='#0A84FF'; '#802878B8'='#99007AFF';
  '#1F2935'='#1D1D1F'; '#5A6A7A'='#6E6E73'; '#8A98A7'='#8E8E93';
  '#302878B8'='#99007AFF'; '#402878B8'='#B3007AFF'; '#405CA8E8'='#990A84FF'; '#505CA8E8'='#B30A84FF'
}
foreach($k in $map.Keys){ $t=$t.Replace($k,$map[$k]) }
$t=$t.Replace('<x:Double x:Key="TitleBarHeight">40</x:Double>','<x:Double x:Key="TitleBarHeight">38</x:Double>')
$t=$t.Replace('<x:Double x:Key="CommandBarHeight">48</x:Double>','<x:Double x:Key="CommandBarHeight">44</x:Double>')
$t=$t.Replace('<x:Double x:Key="SidebarWidth">200</x:Double>','<x:Double x:Key="SidebarWidth">220</x:Double>')
$t=$t.Replace('<x:Double x:Key="MillerColumnWidth">220</x:Double>','<x:Double x:Key="MillerColumnWidth">236</x:Double>')
$t=$t.Replace('<x:Double x:Key="PreviewWidth">280</x:Double>','<x:Double x:Key="PreviewWidth">310</x:Double>')
$t=$t.Replace('<CornerRadius x:Key="RadiusSm">3</CornerRadius>','<CornerRadius x:Key="RadiusSm">6</CornerRadius>')
$t=$t.Replace('<CornerRadius x:Key="RadiusMd">6</CornerRadius>','<CornerRadius x:Key="RadiusMd">8</CornerRadius>')
$t=$t.Replace('<CornerRadius x:Key="RadiusLg">8</CornerRadius>','<CornerRadius x:Key="RadiusLg">10</CornerRadius>')
$t=$t.Replace('<FontFamily x:Key="AppFont">Segoe UI Variable, Segoe UI, Malgun Gothic, Microsoft YaHei UI, Microsoft JhengHei UI, Yu Gothic UI</FontFamily>','<FontFamily x:Key="AppFont">Segoe UI Variable Text, Segoe UI Variable, Segoe UI, Malgun Gothic, Microsoft YaHei UI, Microsoft JhengHei UI, Yu Gothic UI</FontFamily>')
$t=$t.Replace('<Setter Property="MinHeight" Value="24" />','<Setter Property="MinHeight" Value="26" />')
$t=$t.Replace('<Setter Property="CornerRadius" Value="0" />','<Setter Property="CornerRadius" Value="5" />')
WriteText $app $t

# Finder window chrome, toolbar, sidebar and tabs
$t = ReadText $main
$t = [regex]::Replace($t,'<!-- App Icon & Title -->\s*<StackPanel Orientation="Horizontal" Grid.Column="0"[\s\S]*?</StackPanel>','<!-- FinderSpan branding is intentionally visually hidden --><StackPanel Grid.Column="0" Visibility="Collapsed"><TextBlock x:Name="AppTitleText" Text="FinderSpan"/></StackPanel>',1)
$t=$t.Replace('<ColumnDefinition x:Name="SidebarCol" Width="200"/>','<ColumnDefinition x:Name="SidebarCol" Width="220"/>')
$t=$t.Replace('Background="{ThemeResource SpanBgLayer1Brush}" BorderBrush="{ThemeResource SpanBorderSubtleBrush}"','Background="{ThemeResource SpanBgLayer1Brush}" BorderBrush="{ThemeResource SpanBorderSubtleBrush}"')
$t=$t.Replace('<Grid Height="28" Padding="12,0" Background="Transparent"','<Grid Height="30" Margin="7,1" Padding="8,0,6,0" Background="Transparent"')
$t=$t.Replace('<Grid Height="26" Padding="12,0,8,0" Background="Transparent"','<Grid Height="28" Margin="7,1" Padding="8,0,6,0" Background="Transparent"')
$t=$t.Replace('<Rectangle Height="1" Fill="{ThemeResource SpanBorderSubtleBrush}" Margin="12,12"/>','<Rectangle Height="0" Margin="0,5"/>')
$t=$t.Replace('Height="34" MinWidth="80"','Height="30" MinWidth="88"')
$t=$t.Replace('Padding="14,0,6,0"','Padding="12,0,6,0"')
$t=$t.Replace('CornerRadius="6,6,0,0"','CornerRadius="7"')
$t=$t.Replace('<TextBox x:Name="SearchBox" AutomationProperties.AutomationId="TextBox_Search" Width="220" Height="28" FontSize="12"','<TextBox x:Name="SearchBox" AutomationProperties.AutomationId="TextBox_Search" Width="220" Height="28" CornerRadius="8" FontSize="12"')

if($t -notmatch 'FinderTrafficLights') {
  $anchor='<ItemsRepeater x:Name="TabRepeater"'
  if(-not $t.Contains($anchor)){ throw 'TabRepeater anchor not found' }
  $traffic=@'
<StackPanel x:Name="FinderTrafficLights" Orientation="Horizontal" Spacing="8" Margin="13,0,13,0" VerticalAlignment="Center">
  <Button x:Name="FinderCloseButton" Width="14" Height="14" MinWidth="14" MinHeight="14" Padding="0" Background="Transparent" BorderThickness="0" Click="OnFinderCloseClick"><Ellipse Width="12" Height="12" Fill="#FF5F57" Stroke="#26000000" StrokeThickness="1"/></Button>
  <Button x:Name="FinderMinimizeButton" Width="14" Height="14" MinWidth="14" MinHeight="14" Padding="0" Background="Transparent" BorderThickness="0" Click="OnFinderMinimizeClick"><Ellipse Width="12" Height="12" Fill="#FEBC2E" Stroke="#26000000" StrokeThickness="1"/></Button>
  <Button x:Name="FinderZoomButton" Width="14" Height="14" MinWidth="14" MinHeight="14" Padding="0" Background="Transparent" BorderThickness="0" Click="OnFinderZoomClick"><Ellipse Width="12" Height="12" Fill="#28C840" Stroke="#26000000" StrokeThickness="1"/></Button>
</StackPanel>
<ItemsRepeater x:Name="TabRepeater"
'@
  $t=$t.Replace($anchor,$traffic)
}
WriteText $main $t

# Address bar polish
$t=ReadText $address
$t=$t.Replace('Padding="6,2" MinWidth="0" MinHeight="0" CornerRadius="3"','Padding="7,3" MinWidth="0" MinHeight="0" CornerRadius="6"')
$t=$t.Replace('Padding="2,2" MinWidth="0" MinHeight="0" CornerRadius="2"','Padding="3,2" MinWidth="0" MinHeight="0" CornerRadius="5"')
$t=$t.Replace('BorderThickness="0" CornerRadius="0"','BorderThickness="0" CornerRadius="7"')
WriteText $address $t

# Runtime sidebar width
$t=ReadText $settings
$t=$t.Replace('double sidebarWidth = 200 + newLevel * 6;','double sidebarWidth = 220 + newLevel * 6;')
WriteText $settings $t

# Call custom chrome initializer
$t=ReadText $mainCs
if($t -notmatch 'InitializeFinderChrome\(\);'){
  if(-not $t.Contains('SetTitleBar(AppTitleBar);')){ throw 'SetTitleBar anchor not found' }
  $t=$t.Replace('SetTitleBar(AppTitleBar);','SetTitleBar(AppTitleBar);`r`n            InitializeFinderChrome();')
  WriteText $mainCs $t
}

# Custom chrome partial class
$chrome=@'
using System;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
namespace Span {
  public sealed partial class MainWindow {
    private const int FinderSW_MINIMIZE = 6;
    private const int FinderSW_MAXIMIZE = 3;
    private const int FinderSW_RESTORE = 9;
    private void InitializeFinderChrome(){
      try {
        AppWindow.Title = "FinderSpan";
        if(AppWindow.Presenter is OverlappedPresenter presenter) presenter.SetBorderAndTitleBar(true,false);
        AppWindow.TitleBar.ButtonBackgroundColor = Microsoft.UI.Colors.Transparent;
        AppWindow.TitleBar.ButtonInactiveBackgroundColor = Microsoft.UI.Colors.Transparent;
      } catch(Exception ex){ Helpers.DebugLogger.Log($"[FinderChrome] {ex.Message}"); }
    }
    private void OnFinderCloseClick(object sender,RoutedEventArgs e)=>Close();
    private void OnFinderMinimizeClick(object sender,RoutedEventArgs e){ if(_hwnd!=IntPtr.Zero) ShowWindow(_hwnd,FinderSW_MINIMIZE); }
    private void OnFinderZoomClick(object sender,RoutedEventArgs e){ if(_hwnd!=IntPtr.Zero) ShowWindow(_hwnd,IsZoomed(_hwnd)?FinderSW_RESTORE:FinderSW_MAXIMIZE); }
  }
}
'@
WriteText (Join-Path $src 'MainWindow.FinderChrome.cs') $chrome

# Independent visible branding
$t=ReadText $manifest
$t=$t.Replace('<DisplayName>SPAN Finder</DisplayName>','<DisplayName>FinderSpan</DisplayName>')
$t=$t.Replace('DisplayName="SPAN Finder"','DisplayName="FinderSpan"')
$t=$t.Replace('Description="SPAN Finder - High-Performance Miller Columns File Explorer"','Description="FinderSpan - Finder-inspired Windows file manager"')
WriteText $manifest $t

# Finder-like blue folder system
foreach($j in @('icons.json','icons-tabler.json','icons-phosphor.json')){
  $p=Join-Path $src $j; $t=ReadText $p; $t=$t.Replace('"folderColor": "#FFD54F"','"folderColor": "#5AB8F5"'); WriteText $p $t
}
$t=ReadText $iconSvc
$t=$t.Replace('public string FolderColor { get; set; } = "#FFD54F";','public string FolderColor { get; set; } = "#5AB8F5";')
WriteText $iconSvc $t

Write-Host 'FinderSpan UI patch applied.' -ForegroundColor Green
