import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowPresentationAttempts = 0
    private let maxMainWindowPresentationAttempts = 40
    private var windowChromeObservers: [NSObjectProtocol] = []
    private var windowChromeReapplyTask: Task<Void, Never>?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        _ = OWTypography.verifyBundledFontsAtLaunch()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installWindowChromeObservers()
        presentMainWindow()
        // Launch paint: AppKit may not have laid out ThemeFrame yet when SwiftUI first appears.
        DispatchQueue.main.async {
            OWWindowChrome.applyToAllWindows()
            DispatchQueue.main.async {
                OWWindowChrome.applyToAllWindows()
            }
        }
    }

    deinit {
        windowChromeReapplyTask?.cancel()
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
            NSWindow.didEnterFullScreenNotification,
            NSApplication.didBecomeActiveNotification,
            .openWriteThemeDidChange,
        ]
        for name in names {
            let observer = center.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    if name == NSWindow.didBecomeKeyNotification,
                       let window = notification.object as? NSWindow,
                       OWWindowChrome.canApplyChrome(to: window) {
                        OWWindowChrome.apply(to: window)
                        return
                    }
                    self?.scheduleWindowChromeReapply()
                }
            }
            windowChromeObservers.append(observer)
        }
    }

    /// Coalesces resize/focus storms so titlebar paint does not spin the main thread.
    private func scheduleWindowChromeReapply() {
        windowChromeReapplyTask?.cancel()
        windowChromeReapplyTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            OWWindowChrome.applyToAllWindows()
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
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            // Defer chrome paint until AppKit has installed the content view hierarchy (matches OWWindowChromeConfigurator).
            DispatchQueue.main.async {
                guard window.isVisible else { return }
                OWWindowChrome.apply(to: window)
                DispatchQueue.main.async {
                    OWWindowChrome.apply(to: window)
                }
            }
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
