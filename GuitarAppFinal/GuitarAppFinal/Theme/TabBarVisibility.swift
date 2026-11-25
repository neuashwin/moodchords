import SwiftUI

/// Lets deeper screens (song list, song) hide the floating tab bar, as in the design.
///
/// It counts requests instead of using a flag: when one hiding screen pushes another, the
/// new one appears before the old one disappears, so the bar stays hidden in between.
@Observable
final class TabBarVisibility {
    private(set) var hideRequests = 0
    var isHidden: Bool { hideRequests > 0 }

    func hide() { hideRequests += 1 }
    func show() { hideRequests = max(hideRequests - 1, 0) }
}

private struct HidesTabBar: ViewModifier {
    // Optional so screens still work in previews without the app shell.
    @Environment(TabBarVisibility.self) private var visibility: TabBarVisibility?

    func body(content: Content) -> some View {
        content
            .onAppear { visibility?.hide() }
            .onDisappear { visibility?.show() }
    }
}

extension View {
    /// Hides the app's tab bar while this screen is showing.
    func hidesTabBar() -> some View {
        modifier(HidesTabBar())
    }

    /// For a tab's top screen: lets scrolling content pass under the floating bar but always
    /// scroll far enough to clear it. Apply inside the tab's NavigationStack.
    func clearsTabBar() -> some View {
        safeAreaPadding(.bottom, RootView.tabBarClearance)
    }
}
