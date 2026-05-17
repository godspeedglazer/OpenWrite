import CoreGraphics
import Foundation

/// Persisted shell column widths and collapse state (UserDefaults).
enum ShellChromePreferences {
    private static let navigationRailWidthKey = "openwrite.navigationRailWidth"
    private static let assistStripWidthKey = "openwrite.assistStripWidth"
    private static let navigationRailCollapsedKey = "openwrite.navigationRailCollapsed"
    private static let sidebarVisibleKey = "openwrite.sidebarVisible"
    private static let assistStripExpandedKey = "openwrite.assistStripExpanded"

    static var navigationRailWidth: CGFloat {
        get {
            let stored = UserDefaults.standard.double(forKey: navigationRailWidthKey)
            if stored > 0 {
                return CGFloat(stored).clamped(
                    to: DesignTokens.Layout.sidebarMinWidth ... DesignTokens.Layout.sidebarMaxWidth
                )
            }
            return DesignTokens.Layout.sidebarPreferredWidth
        }
        set {
            let clamped = newValue.clamped(
                to: DesignTokens.Layout.sidebarMinWidth ... DesignTokens.Layout.sidebarMaxWidth
            )
            UserDefaults.standard.set(Double(clamped), forKey: navigationRailWidthKey)
        }
    }

    static var assistStripWidth: CGFloat {
        get {
            let stored = UserDefaults.standard.double(forKey: assistStripWidthKey)
            if stored > 0 {
                return CGFloat(stored).clamped(
                    to: DesignTokens.Layout.assistStripMinWidth ... DesignTokens.Layout.assistStripMaxWidth
                )
            }
            return DesignTokens.Layout.assistStripDefaultWidth
        }
        set {
            let clamped = newValue.clamped(
                to: DesignTokens.Layout.assistStripMinWidth ... DesignTokens.Layout.assistStripMaxWidth
            )
            UserDefaults.standard.set(Double(clamped), forKey: assistStripWidthKey)
        }
    }

    static var navigationRailCollapsed: Bool {
        get { UserDefaults.standard.bool(forKey: navigationRailCollapsedKey) }
        set { UserDefaults.standard.set(newValue, forKey: navigationRailCollapsedKey) }
    }

    static var sidebarVisible: Bool {
        get {
            if UserDefaults.standard.object(forKey: sidebarVisibleKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: sidebarVisibleKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: sidebarVisibleKey) }
    }

    static var assistStripExpanded: Bool {
        get { UserDefaults.standard.bool(forKey: assistStripExpandedKey) }
        set { UserDefaults.standard.set(newValue, forKey: assistStripExpandedKey) }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
