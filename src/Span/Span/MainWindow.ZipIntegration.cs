using System;
using Span.Helpers;
using Span.Models;

namespace Span
{
    public sealed partial class MainWindow
    {
        /// <summary>
        /// Opens a physical ZIP as a read-only archive:// folder. The archive engine and
        /// provider already exist upstream; this connects Windows activation to real navigation.
        /// </summary>
        internal void HandleRedirectedArchive(string archivePath, bool createNewTab = true)
        {
            if (_isClosed || ViewModel == null || !ArchivePathHelper.IsBrowsableArchive(archivePath))
                return;

            try
            {
                if (createNewTab)
                {
                    ViewModel.AddNewTab();
                    if (ViewModel.ActiveTab != null)
                    {
                        CreateMillerPanelForTab(ViewModel.ActiveTab);
                        SwitchMillerPanel(ViewModel.ActiveTab.Id);
                    }
                }

                if (ViewModel.CurrentViewMode == ViewMode.Home ||
                    ViewModel.CurrentViewMode == ViewMode.RecycleBin)
                {
                    ViewModel.SwitchViewMode(ViewModel.ResolveViewModeFromHome());
                }

                UpdateViewModeVisibility();
                ResubscribeLeftExplorer();

                var archiveRoot = new FolderItem
                {
                    Name = System.IO.Path.GetFileName(archivePath),
                    Path = ArchivePathHelper.Combine(archivePath, string.Empty)
                };

                _ = ViewModel.ActiveExplorer?.NavigateTo(archiveRoot);
                FocusActiveView();
                Helpers.DebugLogger.Log($"[FinderSpan ZIP] Browsing {archivePath}");
            }
            catch (Exception ex)
            {
                Helpers.DebugLogger.Log($"[FinderSpan ZIP] Activation error: {ex.Message}");
            }
        }
    }
}
