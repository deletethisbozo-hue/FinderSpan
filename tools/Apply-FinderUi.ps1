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
$details = Join-Path $src "Views/DetailsModeView.xaml"
$detailsCs = Join-Path $src "Views/DetailsModeView.xaml.cs"
$mainVm = Join-Path $src "ViewModels/MainViewModel.cs"
$settingsSvc = Join-Path $src "Services/SettingsService.cs"

foreach($p in @($app,$main,$mainCs,$settings,$address,$manifest,$iconSvc,$details,$detailsCs,$mainVm,$settingsSvc)) {
  if(-not (Test-Path $p)){ throw "Missing upstream file: $p" }
}

# -----------------------------------------------------------------------------
# Classic macOS Finder palette and geometry.
# The reference is the classic light Finder window, not Tahoe/Liquid Glass.
# -----------------------------------------------------------------------------
$t = ReadText $app
$replacements = [ordered]@{
  '<Color x:Key="SpanBgMicaColor">#F3F3F3</Color>' = '<Color x:Key="SpanBgMicaColor">#F1F1F1</Color>'
  '<Color x:Key="SpanBgLayer1Color">#F9F9F9</Color>' = '<Color x:Key="SpanBgLayer1Color">#ECECEC</Color>'
  '<Color x:Key="SpanBgLayer2Color">#F3F3F3</Color>' = '<Color x:Key="SpanBgLayer2Color">#F7F7F7</Color>'
  '<Color x:Key="SpanBgLayer3Color">#E6E6E6</Color>' = '<Color x:Key="SpanBgLayer3Color">#DADADA</Color>'
  '<Color x:Key="SpanAccentColor">#0078D4</Color>' = '<Color x:Key="SpanAccentColor">#007AFF</Color>'
  '<Color x:Key="SpanAccentHoverColor">#106EBE</Color>' = '<Color x:Key="SpanAccentHoverColor">#0A84FF</Color>'
  '<Color x:Key="SpanAccentDimColor">#B30078D4</Color>' = '<Color x:Key="SpanAccentDimColor">#B3007AFF</Color>'
  '<Color x:Key="SpanTextPrimaryColor">#1B1B1B</Color>' = '<Color x:Key="SpanTextPrimaryColor">#1F1F1F</Color>'
  '<Color x:Key="SpanTextSecondaryColor">#616161</Color>' = '<Color x:Key="SpanTextSecondaryColor">#626262</Color>'
  '<Color x:Key="SpanTextTertiaryColor">#8B8B8B</Color>' = '<Color x:Key="SpanTextTertiaryColor">#8E8E8E</Color>'
  '<SolidColorBrush x:Key="SpanBgHoverBrush" Color="#0F0078D4" />' = '<SolidColorBrush x:Key="SpanBgHoverBrush" Color="#12000000" />'
  '<SolidColorBrush x:Key="SpanBgActiveBrush" Color="#1A0078D4" />' = '<SolidColorBrush x:Key="SpanBgActiveBrush" Color="#1C000000" />'
  '<SolidColorBrush x:Key="SpanBgSelectedBrush" Color="#250078D4" />' = '<SolidColorBrush x:Key="SpanBgSelectedBrush" Color="#33007AFF" />'
  '<SolidColorBrush x:Key="SpanBgSelectedHoverBrush" Color="#300078D4" />' = '<SolidColorBrush x:Key="SpanBgSelectedHoverBrush" Color="#42007AFF" />'
  '<x:Double x:Key="TitleBarHeight">40</x:Double>' = '<x:Double x:Key="TitleBarHeight">0</x:Double>'
  '<x:Double x:Key="CommandBarHeight">44</x:Double>' = '<x:Double x:Key="CommandBarHeight">52</x:Double>'
  '<x:Double x:Key="StatusBarHeight">28</x:Double>' = '<x:Double x:Key="StatusBarHeight">22</x:Double>'
  '<x:Double x:Key="SidebarWidth">200</x:Double>' = '<x:Double x:Key="SidebarWidth">244</x:Double>'
  '<CornerRadius x:Key="RadiusSm">4</CornerRadius>' = '<CornerRadius x:Key="RadiusSm">5</CornerRadius>'
  '<FontFamily x:Key="AppFont">Segoe UI Variable, Segoe UI, Malgun Gothic, Microsoft YaHei UI, Microsoft JhengHei UI, Yu Gothic UI</FontFamily>' = '<FontFamily x:Key="AppFont">Segoe UI Variable Text, Segoe UI Variable, Segoe UI, Malgun Gothic, Microsoft YaHei UI, Microsoft JhengHei UI, Yu Gothic UI</FontFamily>'
}
foreach($k in $replacements.Keys) { $t = $t.Replace($k,$replacements[$k]) }
WriteText $app $t

# -----------------------------------------------------------------------------
# Main window: one Finder toolbar, classic sidebar, white content pane.
# Keep original controls collapsed so code-behind fields and functionality survive.
# -----------------------------------------------------------------------------
$t = ReadText $main
$t = $t.Replace('<Grid x:Name="RootGrid" Background="{ThemeResource SpanBgMicaBrush}">','<Grid x:Name="RootGrid" RequestedTheme="Light" Background="#FFFFFF">')
$t = $t.Replace('<Grid x:Name="AppTitleBar" Height="{StaticResource TitleBarHeight}" Background="{ThemeResource SpanBgLayer1Brush}">','<Grid x:Name="AppTitleBar" Height="{StaticResource TitleBarHeight}" Background="#EFEFEF" Visibility="Collapsed">')
$t = $t.Replace('<ColumnDefinition x:Name="SidebarCol" Width="200"/>','<ColumnDefinition x:Name="SidebarCol" Width="244"/>')

$oldToolbar = @'
        <Grid Grid.Row="1" Height="{StaticResource CommandBarHeight}" Background="{ThemeResource SpanBgLayer1Brush}" BorderBrush="{ThemeResource SpanBorderSubtleBrush}"
              BorderThickness="{x:Bind UnifiedBarBorderThickness(ViewModel.IsSplitViewEnabled), Mode=OneWay}" Padding="8,0"
              Visibility="{x:Bind IsNotSettingsMode(ViewModel.CurrentViewMode), Mode=OneWay}">
'@
$newToolbar = @'
        <Grid x:Name="FinderToolbar" Grid.Row="1" Height="{StaticResource CommandBarHeight}" Background="#EFEFEF" BorderBrush="#C9C9C9"
              BorderThickness="0,0,0,1" Padding="12,0"
              Visibility="{x:Bind IsNotSettingsMode(ViewModel.CurrentViewMode), Mode=OneWay}">
'@
if (-not $t.Contains($oldToolbar.TrimStart("`n"))) { throw 'Finder toolbar anchor not found' }
$t = $t.Replace($oldToolbar.TrimStart("`n"),$newToolbar.TrimStart("`n"))

$navOpen = @'
            <StackPanel Orientation="Horizontal" Spacing="2" Margin="0,0,8,0"
                        Visibility="{x:Bind IsSingleNonSettingsVisible(ViewModel.IsSplitViewEnabled, ViewModel.CurrentViewMode), Mode=OneWay}">
'@
$navNew = @'
            <StackPanel x:Name="FinderNavGroup" Orientation="Horizontal" Spacing="3" Margin="0,0,10,0"
                        Visibility="{x:Bind IsSingleNonSettingsVisible(ViewModel.IsSplitViewEnabled, ViewModel.CurrentViewMode), Mode=OneWay}">
                <StackPanel x:Name="FinderTrafficLights" Orientation="Horizontal" Spacing="7" Margin="0,0,16,0" VerticalAlignment="Center">
                    <Button x:Name="FinderCloseButton" Width="14" Height="14" MinWidth="14" MinHeight="14" Padding="0" Background="Transparent" BorderThickness="0" Click="OnFinderCloseClick"><Ellipse Width="12" Height="12" Fill="#FF5F57" Stroke="#33000000" StrokeThickness="1"/></Button>
                    <Button x:Name="FinderMinimizeButton" Width="14" Height="14" MinWidth="14" MinHeight="14" Padding="0" Background="Transparent" BorderThickness="0" Click="OnFinderMinimizeClick"><Ellipse Width="12" Height="12" Fill="#FEBC2E" Stroke="#33000000" StrokeThickness="1"/></Button>
                    <Button x:Name="FinderZoomButton" Width="14" Height="14" MinWidth="14" MinHeight="14" Padding="0" Background="Transparent" BorderThickness="0" Click="OnFinderZoomClick"><Ellipse Width="12" Height="12" Fill="#28C840" Stroke="#33000000" StrokeThickness="1"/></Button>
                </StackPanel>
'@
if (-not $t.Contains($navOpen.TrimStart("`n"))) { throw 'Finder nav anchor not found' }
$t = $t.Replace($navOpen.TrimStart("`n"),$navNew.TrimStart("`n"))

$t = $t.Replace('<Button x:Name="BackButton" AutomationProperties.AutomationId="Button_Back" Style="{StaticResource UnifiedButtonStyle}"','<Button x:Name="BackButton" AutomationProperties.AutomationId="Button_Back" Style="{StaticResource UnifiedButtonStyle}" Width="28" Height="28" MinWidth="28" MinHeight="28" Padding="0"')
$t = $t.Replace('<Button x:Name="ForwardButton" AutomationProperties.AutomationId="Button_Forward" Style="{StaticResource UnifiedButtonStyle}"','<Button x:Name="ForwardButton" AutomationProperties.AutomationId="Button_Forward" Style="{StaticResource UnifiedButtonStyle}" Width="28" Height="28" MinWidth="28" MinHeight="28" Padding="0"')
$t = $t.Replace('<Button x:Name="UpButton" Style="{StaticResource UnifiedButtonStyle}"','<Button x:Name="UpButton" Style="{StaticResource UnifiedButtonStyle}" Visibility="Collapsed"')

$oldAddress = @'
            <Grid x:Name="AddressBarContainer" AutomationProperties.AutomationId="AddressBar" Grid.Column="1" Height="32"
                  Background="{ThemeResource SpanBgLayer2Brush}"
                  CornerRadius="4" VerticalAlignment="Center"
                  Padding="4,0"
'@
$newAddress = @'
            <Grid x:Name="AddressBarContainer" AutomationProperties.AutomationId="AddressBar" Grid.Column="1" Height="32"
                  Background="Transparent"
                  CornerRadius="0" VerticalAlignment="Center"
                  Padding="8,0"
'@
if (-not $t.Contains($oldAddress.TrimStart("`n"))) { throw 'Finder title/address anchor not found' }
$t = $t.Replace($oldAddress.TrimStart("`n"),$newAddress.TrimStart("`n"))

$titleInsert = @'
                <TextBlock x:Name="FinderCurrentFolderTitle" Grid.ColumnSpan="3"
                           Text="{x:Bind ViewModel.ActiveTab.Header, Mode=OneWay}"
                           FontSize="13" FontWeight="SemiBold" Foreground="#262626"
                           VerticalAlignment="Center" TextTrimming="CharacterEllipsis" MaxLines="1"/>

                <!-- Home icon (visible only in Home mode, controlled via code-behind) -->
'@
$t = $t.Replace('                <!-- Home icon (visible only in Home mode, controlled via code-behind) -->',$titleInsert.TrimStart("`n"))
$t = $t.Replace('<appcontrols:AddressBarControl x:Name="MainAddressBar" Grid.Column="1"','<appcontrols:AddressBarControl x:Name="MainAddressBar" Grid.Column="1" Visibility="Collapsed"')
$t = $t.Replace('<Button x:Name="CopyPathButton" AutomationProperties.AutomationId="Button_CopyPath" Grid.Column="2"','<Button x:Name="CopyPathButton" AutomationProperties.AutomationId="Button_CopyPath" Grid.Column="2" Visibility="Collapsed"')

$normalCommands = @'
                <StackPanel Orientation="Horizontal" Spacing="2"
                            Visibility="{x:Bind IsNotSpecialMode(ViewModel.CurrentViewMode), Mode=OneWay}">
'@
$finderCommands = @'
                <StackPanel x:Name="FinderToolbarCommands" Orientation="Horizontal" Spacing="5" VerticalAlignment="Center"
                            Visibility="{x:Bind IsNotSpecialMode(ViewModel.CurrentViewMode), Mode=OneWay}">
                    <Button Style="{StaticResource UnifiedButtonStyle}" Width="34" Height="28" MinWidth="34" Padding="0" ToolTipService.ToolTip="View">
                        <Button.Flyout>
                            <MenuFlyout Placement="Bottom">
                                <MenuFlyoutItem Text="List" Click="OnViewModeDetails"><MenuFlyoutItem.Icon><FontIcon Glyph="&#xE8EF;"/></MenuFlyoutItem.Icon></MenuFlyoutItem>
                                <MenuFlyoutItem Text="Columns" Click="OnViewModeMillerColumns"><MenuFlyoutItem.Icon><FontIcon Glyph="&#xF0E2;"/></MenuFlyoutItem.Icon></MenuFlyoutItem>
                                <MenuFlyoutItem Text="Icons" Click="OnViewModeIconMedium"><MenuFlyoutItem.Icon><FontIcon Glyph="&#xE80A;"/></MenuFlyoutItem.Icon></MenuFlyoutItem>
                            </MenuFlyout>
                        </Button.Flyout>
                        <FontIcon Glyph="&#xE8EF;" FontSize="15" Foreground="#444444"/>
                    </Button>
                    <Button Style="{StaticResource UnifiedButtonStyle}" Width="34" Height="28" MinWidth="34" Padding="0" ToolTipService.ToolTip="Sort">
                        <Button.Flyout>
                            <MenuFlyout Placement="Bottom">
                                <MenuFlyoutItem Text="Name" Click="OnSortByName"/>
                                <MenuFlyoutItem Text="Date Modified" Click="OnSortByDate"/>
                                <MenuFlyoutItem Text="Size" Click="OnSortBySize"/>
                                <MenuFlyoutItem Text="Kind" Click="OnSortByType"/>
                            </MenuFlyout>
                        </Button.Flyout>
                        <FontIcon Glyph="&#xE8CB;" FontSize="15" Foreground="#444444"/>
                    </Button>
                    <Button Style="{StaticResource UnifiedButtonStyle}" Width="34" Height="28" MinWidth="34" Padding="0"
                            ToolTipService.ToolTip="Share / copy path" Click="OnFinderShareClick">
                        <FontIcon Glyph="&#xE72D;" FontSize="15" Foreground="#444444"/>
                    </Button>
                    <Button Style="{StaticResource UnifiedButtonStyle}" Width="34" Height="28" MinWidth="34" Padding="0" ToolTipService.ToolTip="Tags">
                        <Button.Flyout>
                            <MenuFlyout Placement="Bottom">
                                <MenuFlyoutItem Text="Red" Tag="Red" Click="OnFinderTagClick"/>
                                <MenuFlyoutItem Text="Orange" Tag="Orange" Click="OnFinderTagClick"/>
                                <MenuFlyoutItem Text="Yellow" Tag="Yellow" Click="OnFinderTagClick"/>
                                <MenuFlyoutItem Text="Green" Tag="Green" Click="OnFinderTagClick"/>
                                <MenuFlyoutItem Text="Blue" Tag="Blue" Click="OnFinderTagClick"/>
                                <MenuFlyoutItem Text="Purple" Tag="Purple" Click="OnFinderTagClick"/>
                                <MenuFlyoutSeparator/>
                                <MenuFlyoutItem Text="Remove Tag" Tag="None" Click="OnFinderTagClick"/>
                            </MenuFlyout>
                        </Button.Flyout>
                        <FontIcon Glyph="&#xE8EC;" FontSize="15" Foreground="#444444"/>
                    </Button>
                    <Button Style="{StaticResource UnifiedButtonStyle}" Width="34" Height="28" MinWidth="34" Padding="0" ToolTipService.ToolTip="More">
                        <Button.Flyout>
                            <MenuFlyout Placement="Bottom">
                                <MenuFlyoutItem Text="New Folder" Click="OnNewFolderClick"/>
                                <MenuFlyoutItem Text="Toggle Preview" Click="OnPreviewToggleClick"/>
                                <MenuFlyoutItem Text="Split View" Click="OnSplitViewToggleClick"/>
                                <MenuFlyoutSeparator/>
                                <MenuFlyoutItem Text="Settings" Click="OnSettingsClick"/>
                            </MenuFlyout>
                        </Button.Flyout>
                        <FontIcon Glyph="&#xE712;" FontSize="15" Foreground="#444444"/>
                    </Button>
                    <Button Style="{StaticResource UnifiedButtonStyle}" Width="34" Height="28" MinWidth="34" Padding="0"
                            ToolTipService.ToolTip="Search" Click="OnFinderSearchClick">
                        <FontIcon Glyph="&#xE721;" FontSize="15" Foreground="#444444"/>
                    </Button>
                </StackPanel>

                <StackPanel Orientation="Horizontal" Spacing="2" Visibility="Collapsed">
'@
if (-not $t.Contains($normalCommands.TrimStart("`n"))) { throw 'Normal commands anchor not found' }
$t = $t.Replace($normalCommands.TrimStart("`n"),$finderCommands.TrimStart("`n"))

$t = $t.Replace('<TextBox x:Name="SearchBox" AutomationProperties.AutomationId="TextBox_Search" Width="220" Height="28" FontSize="12"','<TextBox x:Name="SearchBox" AutomationProperties.AutomationId="TextBox_Search" Width="170" Height="28" CornerRadius="6" FontSize="12" Visibility="Collapsed" LostFocus="OnFinderSearchLostFocus"')
$t = $t.Replace('PlaceholderText="Search (kind: size: ext: date:)"','PlaceholderText="Search"')

# Classic Finder sidebar. Original sidebar remains collapsed for compatibility.
$t = $t.Replace('<Border x:Name="SidebarBorder" AutomationProperties.AutomationId="Sidebar" Grid.Column="0" Background="{ThemeResource SpanBgLayer1Brush}">','<Border x:Name="SidebarBorder" AutomationProperties.AutomationId="Sidebar" Grid.Column="0" Background="#ECECEC" BorderBrush="#C9C9C9" BorderThickness="0,0,1,0">')

$oldScroll = @'
                <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"
                              RightTapped="OnSidebarEmptyRightTapped">
'@
$newScroll = @'
                <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                    <StackPanel Padding="6,8,6,8" Spacing="0">
                        <TextBlock Text="Favorites" FontSize="11" FontWeight="SemiBold" Foreground="#858585" Margin="5,1,0,4"/>

                        <Button Style="{StaticResource UnifiedButtonStyle}" Height="26" MinHeight="26" Padding="7,0" HorizontalContentAlignment="Stretch" Tag="AirDrop" Click="OnFinderSidebarClick">
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><FontIcon Glyph="&#xE701;" FontSize="15" Foreground="#2D7FD3"/><TextBlock Grid.Column="1" Text="AirDrop" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        </Button>
                        <Button Style="{StaticResource UnifiedButtonStyle}" Height="26" MinHeight="26" Padding="7,0" HorizontalContentAlignment="Stretch" Background="#D7D7D7" Tag="Recents" Click="OnFinderSidebarClick">
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><FontIcon Glyph="&#xE823;" FontSize="15" Foreground="#2D7FD3"/><TextBlock Grid.Column="1" Text="Recents" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        </Button>
                        <Button Style="{StaticResource UnifiedButtonStyle}" Height="26" MinHeight="26" Padding="7,0" HorizontalContentAlignment="Stretch" Tag="Applications" Click="OnFinderSidebarClick">
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><FontIcon Glyph="&#xE71D;" FontSize="15" Foreground="#2D7FD3"/><TextBlock Grid.Column="1" Text="Applications" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        </Button>
                        <Button Style="{StaticResource UnifiedButtonStyle}" Height="26" MinHeight="26" Padding="7,0" HorizontalContentAlignment="Stretch" Tag="Desktop" Click="OnFinderSidebarClick">
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><FontIcon Glyph="&#xE7F4;" FontSize="15" Foreground="#2D7FD3"/><TextBlock Grid.Column="1" Text="Desktop" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        </Button>
                        <Button Style="{StaticResource UnifiedButtonStyle}" Height="26" MinHeight="26" Padding="7,0" HorizontalContentAlignment="Stretch" Tag="Documents" Click="OnFinderSidebarClick">
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><FontIcon Glyph="&#xE8A5;" FontSize="15" Foreground="#2D7FD3"/><TextBlock Grid.Column="1" Text="Documents" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        </Button>
                        <Button Style="{StaticResource UnifiedButtonStyle}" Height="26" MinHeight="26" Padding="7,0" HorizontalContentAlignment="Stretch" Tag="Downloads" Click="OnFinderSidebarClick">
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><FontIcon Glyph="&#xE896;" FontSize="15" Foreground="#2D7FD3"/><TextBlock Grid.Column="1" Text="Downloads" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        </Button>

                        <TextBlock Text="iCloud" FontSize="11" FontWeight="SemiBold" Foreground="#858585" Margin="5,12,0,4"/>
                        <Button Style="{StaticResource UnifiedButtonStyle}" Height="26" MinHeight="26" Padding="7,0" HorizontalContentAlignment="Stretch" Tag="OneDrive" Click="OnFinderSidebarClick">
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><FontIcon Glyph="&#xE753;" FontSize="15" Foreground="#2D7FD3"/><TextBlock Grid.Column="1" Text="iCloud Drive" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        </Button>
                        <Button Style="{StaticResource UnifiedButtonStyle}" Height="26" MinHeight="26" Padding="7,0" HorizontalContentAlignment="Stretch" Tag="Shared" Click="OnFinderSidebarClick">
                            <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><FontIcon Glyph="&#xE716;" FontSize="15" Foreground="#2D7FD3"/><TextBlock Grid.Column="1" Text="Shared" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        </Button>

                        <TextBlock Text="Tags" FontSize="11" FontWeight="SemiBold" Foreground="#858585" Margin="5,12,0,4"/>
                        <Grid Height="23" Margin="7,0"><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Ellipse Width="11" Height="11" Fill="#FF5A52"/><TextBlock Grid.Column="1" Text="Red" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        <Grid Height="23" Margin="7,0"><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Ellipse Width="11" Height="11" Fill="#FF9F0A"/><TextBlock Grid.Column="1" Text="Orange" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        <Grid Height="23" Margin="7,0"><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Ellipse Width="11" Height="11" Fill="#FFD60A"/><TextBlock Grid.Column="1" Text="Yellow" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        <Grid Height="23" Margin="7,0"><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Ellipse Width="11" Height="11" Fill="#30D158"/><TextBlock Grid.Column="1" Text="Green" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        <Grid Height="23" Margin="7,0"><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Ellipse Width="11" Height="11" Fill="#0A84FF"/><TextBlock Grid.Column="1" Text="Blue" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        <Grid Height="23" Margin="7,0"><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Ellipse Width="11" Height="11" Fill="#BF5AF2"/><TextBlock Grid.Column="1" Text="Purple" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        <Grid Height="23" Margin="7,0"><Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><Ellipse Width="11" Height="11" Fill="#8E8E93"/><TextBlock Grid.Column="1" Text="Grey" FontSize="12" Foreground="#2A2A2A" VerticalAlignment="Center"/></Grid>
                        <TextBlock Text="All Tags..." FontSize="12" Foreground="#2A2A2A" Margin="29,3,0,0"/>
                    </StackPanel>
                </ScrollViewer>

                <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Visibility="Collapsed"
                              RightTapped="OnSidebarEmptyRightTapped">
'@
if (-not $t.Contains($oldScroll.TrimStart("`n"))) { throw 'Sidebar scroll anchor not found' }
$t = $t.Replace($oldScroll.TrimStart("`n"),$newScroll.TrimStart("`n"))
$t = $t.Replace('                <!-- Sidebar bottom bar: Help, Log (left) | Settings (right) -->`r`n                <Grid Grid.Row="1"','                <!-- Sidebar bottom bar: retained for compatibility, hidden in Finder skin -->`r`n                <Grid Grid.Row="1" Visibility="Collapsed"')
$t = $t.Replace('            <Border x:Name="SidebarSplitter" Grid.Column="1" Width="6"','            <Border x:Name="SidebarSplitter" Grid.Column="1" Width="4"')
$t = $t.Replace('                    Background="{ThemeResource SpanBgLayer1Brush}"`r`n                    BorderBrush="{ThemeResource SpanBorderSubtleBrush}" BorderThickness="0,0,1,0"','                    Background="Transparent"`r`n                    BorderBrush="#C9C9C9" BorderThickness="0,0,1,0"')
$t = $t.Replace('            <Grid Grid.Column="2" Background="Transparent">','            <Grid Grid.Column="2" Background="#FFFFFF">')
$t = $t.Replace('                <Grid x:Name="LeftPaneContainer" AutomationProperties.AutomationId="LeftPane" Grid.Column="0" GotFocus="OnLeftPaneGotFocus"`r`n                      Background="Transparent"','                <Grid x:Name="LeftPaneContainer" AutomationProperties.AutomationId="LeftPane" Grid.Column="0" GotFocus="OnLeftPaneGotFocus"`r`n                      Background="#FFFFFF"')

$t = $t.Replace('<Grid Grid.Row="3" AutomationProperties.AutomationId="StatusBar" Height="{StaticResource StatusBarHeight}" Background="{ThemeResource SpanBgMicaBrush}" BorderBrush="{ThemeResource SpanBorderSubtleBrush}" BorderThickness="0,1,0,0">','<Grid Grid.Row="3" AutomationProperties.AutomationId="StatusBar" Height="{StaticResource StatusBarHeight}" Background="#F3F3F3" BorderBrush="#D0D0D0" BorderThickness="0,1,0,0">')
$t = $t.Replace('<FontIcon Glyph="&#xE8A5;" FontSize="12" Foreground="{ThemeResource SpanTextTertiaryBrush}"/>','<FontIcon Glyph="&#xE8A5;" Visibility="Collapsed"/>')
$t = $t.Replace('<FontIcon Glyph="&#xEDA2;" FontSize="12" Foreground="{ThemeResource SpanTextTertiaryBrush}"/>','<FontIcon Glyph="&#xEDA2;" Visibility="Collapsed"/>')
$t = $t.Replace('<FontIcon Glyph="&#xE8A9;" FontSize="12" Foreground="{ThemeResource SpanTextSecondaryBrush}"/>','<FontIcon Glyph="&#xE8A9;" Visibility="Collapsed"/>')
$t = $t.Replace('<TextBlock Text="{x:Bind ViewModel.StatusViewModeText, Mode=OneWay}" FontSize="11" Foreground="{ThemeResource SpanTextSecondaryBrush}" VerticalAlignment="Center"/>','<TextBlock Text="{x:Bind ViewModel.StatusViewModeText, Mode=OneWay}" Visibility="Collapsed"/>')
WriteText $main $t

# -----------------------------------------------------------------------------
# Details mode: Finder list columns, spacing and typography.
# -----------------------------------------------------------------------------
$t = ReadText $details
$t = $t.Replace('<Setter Property="Height" Value="20"/>','<Setter Property="Height" Value="22"/>')
$t = $t.Replace('<Setter Property="FontWeight" Value="SemiBold"/>','<Setter Property="FontWeight" Value="Normal"/>')
$t = $t.Replace('<Setter Property="Foreground" Value="{ThemeResource SpanTextSecondaryBrush}"/>','<Setter Property="Foreground" Value="#666666"/>')
$t = $t.Replace('<Grid x:Name="RootGrid" Tapped="OnRootTapped" RightTapped="OnEmptyAreaRightTapped" Background="Transparent">','<Grid x:Name="RootGrid" Tapped="OnRootTapped" RightTapped="OnEmptyAreaRightTapped" Background="#FFFFFF">')
$t = $t.Replace('<Grid Grid.Row="0" Height="24"','<Grid Grid.Row="0" Height="22"')
$t = $t.Replace('Background="{ThemeResource SpanBgLayer2Brush}"`r`n              BorderBrush="{ThemeResource SpanBorderSubtleBrush}"','Background="#F8F8F8"`r`n              BorderBrush="#D5D5D5"')
$t = $t.Replace('<ColumnDefinition Width="40"/>','<ColumnDefinition Width="28"/>')
$t = $t.Replace('<ColumnDefinition x:Name="DateColumnDef" Width="200" MinWidth="80"/>','<ColumnDefinition x:Name="DateColumnDef" Width="165" MinWidth="90"/>')
$t = $t.Replace('<ColumnDefinition x:Name="TypeColumnDef" Width="150" MinWidth="50"/>','<ColumnDefinition x:Name="TypeColumnDef" Width="92" MinWidth="70"/>')
$t = $t.Replace('<ColumnDefinition x:Name="SizeColumnDef" Width="100" MinWidth="50"/>','<ColumnDefinition x:Name="SizeColumnDef" Width="180" MinWidth="90"/>')
$t = $t.Replace('<ColumnDefinition x:Name="GitColumnDef" Width="50" MinWidth="40"/>','<ColumnDefinition x:Name="GitColumnDef" Width="0" MinWidth="0"/>')
$t = $t.Replace('Content="Type"`r`n                        Click="OnHeaderClick"`r`n                        Tag="Type"','Content="Size"`r`n                        Click="OnHeaderClick"`r`n                        Tag="Size"')
$t = $t.Replace('Content="Size"`r`n                        Click="OnHeaderClick"`r`n                        Tag="Size"','Content="Kind"`r`n                        Click="OnHeaderClick"`r`n                        Tag="Type"')
$t = $t.Replace('<Grid Grid.Column="11" x:Name="GitHeaderContainer">','<Grid Grid.Column="11" x:Name="GitHeaderContainer" Visibility="Collapsed">')
$t = $t.Replace('<Grid Height="24" RightTapped="OnItemRightTapped"','<Grid Height="22" RightTapped="OnItemRightTapped"')
$t = $t.Replace('Text="{x:Bind FileType, Mode=OneWay}"','Text="{x:Bind __FinderSwap__, Mode=OneWay}"')
$t = $t.Replace('Text="{x:Bind Size, Mode=OneWay}"','Text="{x:Bind FileType, Mode=OneWay}"')
$t = $t.Replace('Text="{x:Bind __FinderSwap__, Mode=OneWay}"','Text="{x:Bind Size, Mode=OneWay}"')
$t = $t.Replace('<Border Grid.Column="6" x:Name="GitCell" Width="50">','<Border Grid.Column="6" x:Name="GitCell" Width="0" Visibility="Collapsed">')
WriteText $details $t

$t = ReadText $detailsCs
$t = $t.Replace('private double _densityRowHeight = 24.0; // comfortable default','private double _densityRowHeight = 22.0; // classic Finder density')
$t = $t.Replace('TypeHeaderButton.Content = _loc.Get("Type");`r`n            SizeHeaderButton.Content = _loc.Get("Size");','TypeHeaderButton.Content = _loc.Get("Size");`r`n            SizeHeaderButton.Content = "Kind";')
WriteText $detailsCs $t

# Finder should enter folders in list/details mode by default and without preview.
$t = ReadText $mainVm
$t = $t.Replace('private ViewMode _leftViewMode = ViewMode.MillerColumns;','private ViewMode _leftViewMode = ViewMode.Details;')
$t = $t.Replace('private ViewMode _rightViewMode = ViewMode.MillerColumns;','private ViewMode _rightViewMode = ViewMode.Details;')
$t = $t.Replace('private bool _isLeftPreviewEnabled = true;','private bool _isLeftPreviewEnabled = false;')
$t = $t.Replace('private bool _isRightPreviewEnabled = true;','private bool _isRightPreviewEnabled = false;')
$t = $t.Replace('private ViewMode _currentViewMode = ViewMode.MillerColumns;','private ViewMode _currentViewMode = ViewMode.Details;')
WriteText $mainVm $t

$t = ReadText $settingsSvc
$t = $t.Replace('get => Get("DefaultViewMode", 0); // 0 = MillerColumns','get => Get("DefaultViewMode", 1); // FinderSpan default = Details')
WriteText $settingsSvc $t

# Runtime sidebar sizing follows the visual width.
$t = ReadText $settings
$t = $t.Replace('double sidebarWidth = 200 + newLevel * 6;','double sidebarWidth = 244 + newLevel * 6;')
WriteText $settings $t

# Address bar survives collapsed for keyboard/path functionality; keep its editing UI compact.
$t = ReadText $address
$t = $t.Replace('Padding="6,2" MinWidth="0" MinHeight="0" CornerRadius="3"','Padding="6,2" MinWidth="0" MinHeight="0" CornerRadius="5"')
WriteText $address $t

# Switch the custom drag/title region from the hidden old tab bar to FinderToolbar.
$t = ReadText $mainCs
if ($t.Contains('SetTitleBar(AppTitleBar);')) {
  $t = $t.Replace('SetTitleBar(AppTitleBar);','SetTitleBar(FinderToolbar);`r`n            InitializeFinderChrome();')
} elseif ($t -notmatch 'InitializeFinderChrome\(\);') {
  throw 'SetTitleBar anchor not found'
}
WriteText $mainCs $t

# Custom chrome + Finder-specific toolbar/sidebar interactions.
$chrome = @'
using System;
using System.IO;
using System.Linq;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.ApplicationModel.DataTransfer;

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

    private void OnFinderSidebarClick(object sender, RoutedEventArgs e){
      try {
        if(sender is not FrameworkElement fe || fe.Tag is not string key) return;
        if(key == "Recents" || key == "AirDrop") {
          ViewModel.SwitchViewMode(Models.ViewMode.Home);
          return;
        }

        string? path = key switch {
          "Applications" => Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
          "Desktop" => Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
          "Documents" => Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
          "Downloads" => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads"),
          "OneDrive" => Environment.GetEnvironmentVariable("OneDrive"),
          "Shared" => Environment.GetFolderPath(Environment.SpecialFolder.CommonDocuments),
          _ => null
        };
        if(string.IsNullOrWhiteSpace(path) || !Directory.Exists(path)) return;
        ViewModel.SwitchViewMode(Models.ViewMode.Details);
        ViewModel.NavigateToFavorite(new Models.FavoriteItem { Name = key, Path = path });
      } catch(Exception ex){ Helpers.DebugLogger.Log($"[FinderSidebar] {ex.Message}"); }
    }

    private void OnFinderSearchClick(object sender, RoutedEventArgs e){
      SearchBox.Visibility = Visibility.Visible;
      SearchBox.Focus(FocusState.Programmatic);
      SearchBox.SelectAll();
    }

    private void OnFinderSearchLostFocus(object sender, RoutedEventArgs e){
      if(string.IsNullOrWhiteSpace(SearchBox.Text)) SearchBox.Visibility = Visibility.Collapsed;
    }

    private void OnFinderShareClick(object sender, RoutedEventArgs e){
      try {
        var selected = GetCurrentSelectedItems();
        var paths = selected.Select(x => x.Path).Where(x => !string.IsNullOrWhiteSpace(x)).ToList();
        if(paths.Count == 0 && !string.IsNullOrWhiteSpace(ViewModel.ActiveExplorer?.CurrentPath))
          paths.Add(ViewModel.ActiveExplorer.CurrentPath);
        if(paths.Count == 0) return;
        var data = new DataPackage();
        data.SetText(string.Join(Environment.NewLine, paths));
        Clipboard.SetContent(data);
      } catch(Exception ex){ Helpers.DebugLogger.Log($"[FinderShare] {ex.Message}"); }
    }

    private void OnFinderTagClick(object sender, RoutedEventArgs e){
      try {
        if(sender is not FrameworkElement fe || fe.Tag is not string tagText) return;
        if(!Enum.TryParse<Models.FolderTagColor>(tagText, true, out var color)) return;
        var folder = GetCurrentSelectedItems().OfType<ViewModels.FolderViewModel>().FirstOrDefault();
        if(folder == null) return;
        ((Services.IContextMenuHost)this).PerformSetFolderTag(folder, color);
      } catch(Exception ex){ Helpers.DebugLogger.Log($"[FinderTag] {ex.Message}"); }
    }
  }
}
'@
WriteText (Join-Path $src 'MainWindow.FinderChrome.cs') $chrome

# Independent identity / visible branding.
$t = ReadText $manifest
$t = $t.Replace('<DisplayName>SPAN Finder</DisplayName>','<DisplayName>FinderSpan</DisplayName>')
$t = $t.Replace('DisplayName="SPAN Finder"','DisplayName="FinderSpan"')
$t = $t.Replace('Description="SPAN Finder - High-Performance Miller Columns File Explorer"','Description="FinderSpan - classic Finder-style Windows file manager"')
WriteText $manifest $t

# Finder blue folders.
foreach($j in @('icons.json','icons-tabler.json','icons-phosphor.json')){
  $p = Join-Path $src $j
  $t = ReadText $p
  $t = $t.Replace('"folderColor": "#FFD54F"','"folderColor": "#4DA3E8"')
  WriteText $p $t
}
$t = ReadText $iconSvc
$t = $t.Replace('public string FolderColor { get; set; } = "#FFD54F";','public string FolderColor { get; set; } = "#4DA3E8";')
WriteText $iconSvc $t

Write-Host 'FinderSpan classic Finder UI patch applied.' -ForegroundColor Green
