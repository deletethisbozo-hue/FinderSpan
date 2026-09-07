using Microsoft.UI.Xaml;

namespace Span
{
    public sealed partial class MainWindow
    {
        // FinderSpan's CI skin intentionally hides the decorative Finder-style Tags menu.
        // The base skin still emits XAML event references before the CI cleanup runs, so
        // keep a no-op handler to satisfy WinUI XAML compilation without exposing a fake
        // feature to users.
        private void OnFinderTagClick(object sender, RoutedEventArgs e)
        {
        }
    }
}
