import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowPresentationAttempts = 0
    private let maxMainWindowPresentationAttempts = 40
    private var windowChromeObservers: [NSObjectProtocol] = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        _ = OWTypography.verifyBundledFontsAtLaunch()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installWindowChromeObservers()
        presentMainWindow()
    }

    deinit {
        for observer in windowChromeObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func installWindowChromeObservers() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didResizeNotification,
        ]
        for name in names {
            let observer = center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    OWWindowChrome.applyToAllWindows()
                }
            }
            windowChromeObservers.append(observer)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        presentMainWindow()
        return true
    }

    func presentMainWindow() {
        mainWindowPresentationAttempts = 0
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        orderMainWindowToFront()
    }

    private func orderMainWindowToFront() {
        mainWindowPresentationAttempts += 1

        if let window = NSApp.mainWindow ?? NSApp.keyWindow ?? preferredMainWindow() {
            applyWindowSizingPolicy(to: window)
            OWWindowChrome.apply(to: window)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        guard mainWindowPresentationAttempts < maxMainWindowPresentationAttempts else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.orderMainWindowToFront()
        }
    }

    private func preferredMainWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.canBecomeKey && !window.isSheet && window.contentView != nil
        }
    }

    private func applyWindowSizingPolicy(to window: NSWindow) {
        let minSize = NSSize(
            width: DesignTokens.Layout.windowMinWidth,
            height: DesignTokens.Layout.windowMinHeight
        )
        if window.minSize != minSize {
            window.minSize = minSize
        }
    }
}
