import AppKit
import SwiftUI

// MARK: - AppKit focus ring (NSHostingView bridge)

extension NSView {
    /// Clears AppKit’s default focus ring on bridge containers (`NSHostingView`, paste capture, etc.).
    /// SwiftUI buttons inside otherwise pick up the thick system blue highlight.
    func openWriteSuppressFocusRing() {
        focusRingType = .none
    }
}

// MARK: - NSWindow titlebar metrics

extension NSWindow {
    /// Non-client titlebar height above `contentLayoutRect` (toolbar + traffic-light row).
    var openWriteTitlebarChromeHeight: CGFloat {
        guard frame.height > 0 else { return 0 }
        return frame.height - contentLayoutRect.maxY
    }

    /// SwiftUI title-bar band height — tracks AppKit `contentLayoutRect` so shell chrome stays flush (no gray void).
    var openWriteShellChromeSafeAreaTop: CGFloat {
        let measured = openWriteTitlebarChromeHeight
        guard measured >= DesignTokens.Spacing.spacing2 else {
            return DesignTokens.Layout.shellChromeSafeAreaTop
        }
        let rounded = (measured * 2).rounded() / 2
        return max(rounded, DesignTokens.Layout.shellChromeSafeAreaTop)
    }

    /// Leading inset clearing native traffic lights (content layout rect + button geometry).
    var openWriteShellChromeContentLeadingInset: CGFloat {
        let fallback = DesignTokens.Layout.shellChromeContentLeadingInset
        guard frame.height > 0 else { return fallback }
        let layoutLeading = max(contentLayoutRect.minX, 0) + DesignTokens.Spacing.spacing2
        guard let contentView else {
            return max(layoutLeading, DesignTokens.Layout.shellChromeCompactLeadingInset)
        }
        let buttons: [NSButton] = [
            standardWindowButton(.closeButton),
            standardWindowButton(.miniaturizeButton),
            standardWindowButton(.zoomButton),
        ].compactMap { $0 }
        let buttonTrailing: CGFloat
        if buttons.isEmpty {
            buttonTrailing = 0
        } else {
            buttonTrailing = buttons
                .map { $0.convert($0.bounds, to: contentView).maxX }
                .max() ?? 0
            + DesignTokens.Spacing.spacing2
        }
        let measured = max(layoutLeading, buttonTrailing)
        return max(
            measured,
            DesignTokens.Layout.shellChromeCompactLeadingInset
        )
    }

    /// Top padding that vertically centers custom traffic-light squares in the titlebar band.
    /// Falls back to `DesignTokens.Layout.windowControlTopInset` when layout is not yet resolved.
    var openWriteWindowControlTopInset: CGFloat {
        let chrome = openWriteTitlebarChromeHeight
        let controlSize = DesignTokens.Layout.windowControlSize
        let fallback = DesignTokens.Layout.windowControlTopInset
        guard chrome >= controlSize + 2 else { return fallback }
        let centered = (chrome - controlSize) * 0.5
        let clamped = centered.clamped(
            to: DesignTokens.Spacing.spacing1 ... max(fallback, chrome - controlSize - DesignTokens.Spacing.spacing1)
        )
        return (clamped * 2).rounded() / 2
    }
}

// MARK: - NSWindow configuration

/// Applies unified transparent titlebar so custom shell chrome can sit behind traffic lights.
///
/// **Why this is more aggressive than a simple "apply once on theme revision":**
/// The previous implementation gated on `revision != lastAppliedRevision`, but the very first
/// `updateNSView` after a fresh launch fires with `revision == lastAppliedRevision == 0` AND
/// `nsView.window == nil`, so we bailed out without ever scheduling an apply. By the time
/// SwiftUI inserted the view into the window hierarchy, no further `updateNSView` was triggered
/// (no state change), leaving macOS to render its default vibrant grey title strip — the
/// "gray void" above the custom traffic lights. We now:
///   • apply once `nsView.window` resolves (window-attach observer), and
///   • react to `NSWindow.didBecomeKey` / `didChangeOcclusionState` so fullscreen and re-keying
///     never strand the title bar in the system grey appearance.
struct OWWindowChromeConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = OWWindowChromeProbeView(coordinator: context.coordinator)
        view.openWriteSuppressFocusRing()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.refresh(view: nsView)
    }

    final class Coordinator {
        var lastAppliedRevision: UInt = .max
        var boundWindowID: ObjectIdentifier?
        private var observers: [NSObjectProtocol] = []

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }

        func refresh(view: NSView) {
            let revision = ThemeManager.shared.revision
            let windowID = view.window.map(ObjectIdentifier.init)
            let windowChanged = windowID != boundWindowID
            let revisionChanged = revision != lastAppliedRevision

            if windowChanged {
                rebindObservers(for: view.window)
                boundWindowID = windowID
            }

            guard revisionChanged || windowChanged else { return }
            lastAppliedRevision = revision

            guard let window = view.window else { return }
            // Apply on the next runloop turn so AppKit has finished installing the content view
            // (paintThemeFrame walks superviews — those are nil during the synchronous SwiftUI pass).
            DispatchQueue.main.async { [weak view] in
                guard let view, view.window === window else { return }
                OWWindowChrome.apply(to: window)
                // Second pass after AppKit lays out ThemeFrame / titlebar accessories.
                DispatchQueue.main.async {
                    guard view.window === window else { return }
                    OWWindowChrome.apply(to: window)
                }
            }
        }

        private func rebindObservers(for window: NSWindow?) {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            guard let window else { return }
            let center = NotificationCenter.default
            let notifications: [Notification.Name] = [
                NSWindow.didBecomeKeyNotification,
                NSWindow.didChangeOcclusionStateNotification,
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
                NSWindow.didChangeBackingPropertiesNotification
            ]
            for name in notifications {
                let token = center.addObserver(forName: name, object: window, queue: .main) { _ in
                    DispatchQueue.main.async {
                        OWWindowChrome.apply(to: window)
                    }
                }
                observers.append(token)
            }
            // Theme cycles can outlive the configurator's last `updateNSView` (e.g. quick rebind);
            // listen here too so the chrome refreshes even if SwiftUI does not redraw the probe.
            let themeToken = center.addObserver(
                forName: .openWriteThemeDidChange,
                object: nil,
                queue: .main
            ) { [weak self, weak window] _ in
                guard let self, let window else { return }
                self.lastAppliedRevision = ThemeManager.shared.revision
                DispatchQueue.main.async {
                    OWWindowChrome.apply(to: window)
                }
            }
            observers.append(themeToken)
        }
    }
}

/// Sub-classed NSView so we can react when AppKit attaches the configurator probe to a window.
private final class OWWindowChromeProbeView: NSView {
    weak var coordinator: OWWindowChromeConfigurator.Coordinator?

    init(coordinator: OWWindowChromeConfigurator.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // `updateNSView` doesn't always re-fire after the SwiftUI hosting view is attached, so we
        // poke the coordinator directly. This was the single most common cause of the gray strip.
        coordinator?.refresh(view: self)
    }
}

/// Compact OpenWrite mark for title bar and About surfaces.
struct OWBrandMark: View {
    var size: CGFloat = 20

    var body: some View {
        OWBrandLogoView(size: size)
    }
}

enum OWWindowChrome {
    /// OpenWrite-drawn close / minimize / zoom (muted squares). Native traffic lights are hidden.
    static let usesCustomWindowControls = true

    /// When true (e.g. graph canvas visible), background clicks must not move the window.
    static var suppressBackgroundWindowDrag = false

    private static var titlebarFillAccessories: [ObjectIdentifier: OWSolidTitlebarAccessory] = [:]
    private static var installedWindowCloseObserver = false
    private static var isApplyingChrome = false

    private static func installWindowCloseObserverIfNeeded() {
        guard !installedWindowCloseObserver else { return }
        installedWindowCloseObserver = true
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            let key = ObjectIdentifier(window)
            if let accessory = titlebarFillAccessories.removeValue(forKey: key) {
                if let index = window.titlebarAccessoryViewControllers.firstIndex(where: { $0 === accessory }) {
                    window.removeTitlebarAccessoryViewController(at: index)
                }
            }
        }
    }

    /// Main document windows only — not sheets, panels, or borderless utility chrome.
    static func canApplyChrome(to window: NSWindow) -> Bool {
        if window.isSheet { return false }
        if window is NSPanel { return false }
        let mask = window.styleMask
        if mask.contains(.borderless) && !mask.contains(.titled) { return false }
        if mask.contains(.nonactivatingPanel) { return false }
        return mask.contains(.titled) || mask.contains(.fullSizeContentView)
    }

    /// `NSTitlebarAccessoryViewController` is only valid on standard titled app windows.
    static func supportsTitlebarAccessory(on window: NSWindow) -> Bool {
        guard canApplyChrome(to: window) else { return false }
        return window.styleMask.contains(.titled)
    }

    static func apply(to window: NSWindow) {
        guard canApplyChrome(to: window) else { return }
        guard !isApplyingChrome else { return }
        isApplyingChrome = true
        defer { isApplyingChrome = false }

        window.title = "OpenWrite"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
        }
        if window.styleMask.contains(.titled) {
            window.styleMask.insert(.fullSizeContentView)
        }
        window.collectionBehavior.insert(.fullScreenPrimary)
        if #available(macOS 10.12, *) {
            window.collectionBehavior.insert(.fullScreenAllowsTiling)
        }
        window.toolbar = nil

        let theme = ThemeManager.shared.selectedTheme
        let palette = ThemeManager.shared.palette
        let chrome = NSColor(palette.shellChrome)
        let appearance = NSAppearance(named: theme.prefersDarkAppearance ? .darkAqua : .aqua)
        if window.appearance?.name != appearance?.name {
            window.appearance = appearance
        }
        window.isOpaque = true
        window.backgroundColor = chrome
        paintThemeFrame(window, color: chrome)
        stripTitlebarVibrancy(in: window, fill: chrome)
        installSolidTitlebarFill(on: window, color: chrome)
        tintHostingRoot(window, color: chrome)
        if usesCustomWindowControls {
            hideSystemTrafficLights(in: window)
        } else {
            showSystemTrafficLights(in: window)
        }

        if window.contentView?.superview == nil {
            DispatchQueue.main.async {
                guard window.contentView?.superview != nil else { return }
                apply(to: window)
            }
        }
    }

    private static func showSystemTrafficLights(in window: NSWindow) {
        guard canApplyChrome(to: window) else { return }
        window.standardWindowButton(.closeButton)?.superview?.isHidden = false
        for kind: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(kind) else { continue }
            button.isHidden = false
            button.alphaValue = 1
            button.isEnabled = true
        }
    }

    private static func hideSystemTrafficLights(in window: NSWindow) {
        guard canApplyChrome(to: window) else { return }
        for kind: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(kind) else { continue }
            button.isHidden = true
            button.alphaValue = 0
        }
        window.standardWindowButton(.closeButton)?.superview?.isHidden = true
    }

    /// Removes legacy solid titlebar fill accessories (see `apply` — we no longer install them).
    private static func removeSolidTitlebarFill(from window: NSWindow) {
        let key = ObjectIdentifier(window)
        if let accessory = titlebarFillAccessories.removeValue(forKey: key) {
            if let index = window.titlebarAccessoryViewControllers.firstIndex(where: { $0 === accessory }) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
        }
    }

    static func applyToAllWindows() {
        for window in NSApp.windows where canApplyChrome(to: window) {
            apply(to: window)
        }
    }

    static func reapplyToKeyWindow() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow,
              canApplyChrome(to: window) else { return }
        apply(to: window)
    }

    /// Recolors AppKit theme frame so the strip behind traffic lights is not system grey vibrancy.
    private static func paintThemeFrame(_ window: NSWindow, color: NSColor) {
        guard let contentSuperview = window.contentView?.superview else { return }
        var view: NSView? = contentSuperview
        while let current = view {
            tintChromeLayer(current, color: color, skipButtons: true)
            let typeName = String(describing: type(of: current))
            if typeName.contains("ThemeFrame") || typeName.contains("NSFrameView") {
                break
            }
            view = current.superview
        }
        if let root = window.contentView?.superview {
            for effect in visualEffectViews(in: root) {
                effect.isHidden = true
                effect.alphaValue = 0
            }
        }
    }

    private static func tintHostingRoot(_ window: NSWindow, color: NSColor) {
        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = color.cgColor
    }

    /// Detaches any `OWSolidTitlebarAccessory` previously installed for this window. The accessory
    /// is no longer used (see `apply(to:)` rationale) but legacy state may still be present.
    private static func removeLegacyTitlebarFill(from window: NSWindow) {
        let key = ObjectIdentifier(window)
        if let accessory = titlebarFillAccessories.removeValue(forKey: key),
           let index = window.titlebarAccessoryViewControllers.firstIndex(where: { $0 === accessory }) {
            window.removeTitlebarAccessoryViewController(at: index)
        }
        // Also sweep up any orphans that aren't tracked in our dictionary (e.g. from older builds).
        let orphans = window.titlebarAccessoryViewControllers.enumerated().filter { _, vc in
            vc is OWSolidTitlebarAccessory
        }
        for (index, _) in orphans.reversed() {
            window.removeTitlebarAccessoryViewController(at: index)
        }
    }

    /// `NSTitlebarAccessoryViewController` crashes on unsupported windows — always guard first.
    private static func installSolidTitlebarFill(on window: NSWindow, color: NSColor) {
        guard supportsTitlebarAccessory(on: window) else { return }
        installWindowCloseObserverIfNeeded()
        let key = ObjectIdentifier(window)
        if let accessory = titlebarFillAccessories[key] {
            accessory.chromeColor = color
            accessory.syncHeightToTitlebar()
            return
        }
        let accessory = OWSolidTitlebarAccessory(color: color)
        window.addTitlebarAccessoryViewController(accessory)
        titlebarFillAccessories[key] = accessory
        accessory.syncHeightToTitlebar()
    }

    /// Replaces titlebar vibrancy materials with opaque shell chrome (Manuscripts-style flush strip).
    private static func stripTitlebarVibrancy(in window: NSWindow, fill chrome: NSColor) {
        guard let root = window.contentView?.superview else { return }
        var view: NSView? = root
        while let current = view {
            let typeName = String(describing: type(of: current))
            if let effect = current as? NSVisualEffectView {
                effect.isHidden = true
                effect.alphaValue = 0
                effect.state = .inactive
            } else if typeName.contains("Titlebar") || typeName.contains("TitleBar") || typeName.contains("ThemeFrame") {
                tintChromeLayer(current, color: chrome, skipButtons: true)
            }
            view = current.superview
        }
        for effect in visualEffectViews(in: root) {
            effect.isHidden = true
            effect.alphaValue = 0
            effect.state = .inactive
        }
        walkChromeSubviews(in: root, chrome: chrome)
    }

    private static func walkChromeSubviews(in root: NSView, chrome: NSColor) {
        func walk(_ view: NSView) {
            let typeName = String(describing: type(of: view))
            if view is NSVisualEffectView {
                view.isHidden = true
                view.alphaValue = 0
            } else if typeName.contains("Titlebar") || typeName.contains("TitleBar") || typeName.contains("ThemeFrame") {
                tintChromeLayer(view, color: chrome, skipButtons: true)
            }
            for child in view.subviews {
                walk(child)
            }
        }
        walk(root)
    }

    private static func tintChromeLayer(_ view: NSView, color: NSColor, skipButtons: Bool) {
        if skipButtons, view is NSButton { return }
        view.wantsLayer = true
        view.layer?.backgroundColor = color.cgColor
        view.layer?.isOpaque = true
    }

    private static func visualEffectViews(in root: NSView) -> [NSVisualEffectView] {
        var found: [NSVisualEffectView] = []
        func walk(_ view: NSView) {
            if let effect = view as? NSVisualEffectView {
                found.append(effect)
            }
            for child in view.subviews {
                walk(child)
            }
        }
        walk(root)
        return found
    }
}

// MARK: - Solid titlebar fill (no vibrancy)

private final class OWSolidTitlebarFillView: NSView {
    var chromeColor: NSColor = .windowBackgroundColor {
        didSet {
            needsDisplay = true
            layer?.backgroundColor = chromeColor.cgColor
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = chromeColor.cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        chromeColor.setFill()
        bounds.fill()
    }
}

private final class OWSolidTitlebarAccessory: NSTitlebarAccessoryViewController {
    private let fillView = OWSolidTitlebarFillView()

    var chromeColor: NSColor {
        get { fillView.chromeColor }
        set { fillView.chromeColor = newValue }
    }

    init(color: NSColor) {
        super.init(nibName: nil, bundle: nil)
        fillView.wantsLayer = true
        fillView.chromeColor = color
        view = fillView
        layoutAttribute = .top
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        syncHeightToTitlebar()
    }

    func syncHeightToTitlebar() {
        guard let window = view.window else { return }

        let trafficLightHeight = window.standardWindowButton(.closeButton)?
            .superview?
            .frame
            .maxY ?? 0
        let layoutChrome = window.frame.height - window.contentLayoutRect.maxY
        let controlsMinimum = DesignTokens.Layout.windowControlTopInset
            + DesignTokens.Layout.windowControlSize
            + DesignTokens.Spacing.spacing1
        let height = max(
            trafficLightHeight,
            layoutChrome,
            DesignTokens.Layout.shellChromeSafeAreaTop,
            controlsMinimum
        )

        if abs(view.frame.height - height) > 0.5 {
            view.frame.size.height = height
        }
        if abs(view.frame.width - window.frame.width) > 0.5 {
            view.frame.size.width = window.frame.width
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        syncHeightToTitlebar()
    }
}

// MARK: - Window drag policy (AppKit)

/// Opts this view out of `isMovableByWindowBackground` drags (graph nodes, canvas).
struct OWDisablesWindowDrag: NSViewRepresentable {
    func makeNSView(context: Context) -> OWWindowDragShieldView {
        let view = OWWindowDragShieldView()
        view.openWriteSuppressFocusRing()
        return view
    }

    func updateNSView(_ nsView: OWWindowDragShieldView, context: Context) {}
}

final class OWWindowDragShieldView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}

/// Keeps the custom shell title bar draggable when graph suppresses background window move.
struct OWTitleBarDraggableRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> OWTitleBarDragView {
        let view = OWTitleBarDragView()
        view.openWriteSuppressFocusRing()
        return view
    }

    func updateNSView(_ nsView: OWTitleBarDragView, context: Context) {}
}

final class OWTitleBarDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

extension View {
    func openWriteWindowChrome() -> some View {
        background {
            DesignTokens.Color.shellChrome
                .ignoresSafeArea()
        }
        .background(OWWindowChromeConfigurator())
    }
}

// MARK: - Titlebar layout metrics (contentLayoutRect)

/// Publishes AppKit titlebar metrics into SwiftUI when the hosting window lays out or resizes.
private struct OWWindowChromeLayoutReader: NSViewRepresentable {
    @Binding var windowControlTopInset: CGFloat
    @Binding var shellChromeSafeAreaTop: CGFloat
    @Binding var shellChromeContentLeadingInset: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(
            windowControlTopInset: $windowControlTopInset,
            shellChromeSafeAreaTop: $shellChromeSafeAreaTop,
            shellChromeContentLeadingInset: $shellChromeContentLeadingInset
        )
    }

    func makeNSView(context: Context) -> OWWindowChromeLayoutProbeView {
        let view = OWWindowChromeLayoutProbeView(coordinator: context.coordinator)
        view.openWriteSuppressFocusRing()
        return view
    }

    func updateNSView(_ nsView: OWWindowChromeLayoutProbeView, context: Context) {
        context.coordinator.sync(from: nsView)
    }

    final class Coordinator {
        @Binding var windowControlTopInset: CGFloat
        @Binding var shellChromeSafeAreaTop: CGFloat
        @Binding var shellChromeContentLeadingInset: CGFloat
        private var boundWindowID: ObjectIdentifier?
        private var observers: [NSObjectProtocol] = []

        init(
            windowControlTopInset: Binding<CGFloat>,
            shellChromeSafeAreaTop: Binding<CGFloat>,
            shellChromeContentLeadingInset: Binding<CGFloat>
        ) {
            _windowControlTopInset = windowControlTopInset
            _shellChromeSafeAreaTop = shellChromeSafeAreaTop
            _shellChromeContentLeadingInset = shellChromeContentLeadingInset
        }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }

        func sync(from view: NSView) {
            guard let window = view.window else { return }
            publish(from: window)
            let windowID = ObjectIdentifier(window)
            guard windowID != boundWindowID else { return }
            boundWindowID = windowID
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            let center = NotificationCenter.default
            let names: [Notification.Name] = [
                NSWindow.didResizeNotification,
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
                NSWindow.didChangeBackingPropertiesNotification,
            ]
            for name in names {
                let token = center.addObserver(forName: name, object: window, queue: .main) { [weak self, weak window] _ in
                    guard let self, let window else { return }
                    self.publish(from: window)
                }
                observers.append(token)
            }
        }

        private func publish(from window: NSWindow) {
            let nextInset = window.openWriteWindowControlTopInset
            let nextSafeTop = window.openWriteShellChromeSafeAreaTop
            let nextLeading = OWWindowChrome.usesCustomWindowControls
                ? DesignTokens.Layout.shellChromeContentLeadingInset
                : window.openWriteShellChromeContentLeadingInset
            let changed = abs(windowControlTopInset - nextInset) > 0.25
                || abs(shellChromeSafeAreaTop - nextSafeTop) > 0.25
                || abs(shellChromeContentLeadingInset - nextLeading) > 0.25
            guard changed else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if abs(self.windowControlTopInset - nextInset) > 0.25 {
                    self.windowControlTopInset = nextInset
                }
                if abs(self.shellChromeSafeAreaTop - nextSafeTop) > 0.25 {
                    self.shellChromeSafeAreaTop = nextSafeTop
                }
                if abs(self.shellChromeContentLeadingInset - nextLeading) > 0.25 {
                    self.shellChromeContentLeadingInset = nextLeading
                }
            }
        }
    }
}

private final class OWWindowChromeLayoutProbeView: NSView {
    weak var coordinator: OWWindowChromeLayoutReader.Coordinator?

    init(coordinator: OWWindowChromeLayoutReader.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.sync(from: self)
    }

    override func layout() {
        super.layout()
        coordinator?.sync(from: self)
    }
}

// MARK: - Custom window controls (muted rounded squares)

/// Close / minimize / zoom controls integrated into the filled shell title bar.
struct OWShellWindowControls: View {
    @Environment(\.openWritePalette) private var palette

    var body: some View {
        HStack(spacing: DesignTokens.Layout.windowControlSpacing) {
            shellWindowButton(role: .close) {
                NSApp.keyWindow?.performClose(nil)
            }
            shellWindowButton(role: .minimize) {
                NSApp.keyWindow?.miniaturize(nil)
            }
            shellWindowButton(role: .zoom) {
                guard let window = NSApp.keyWindow else { return }
                if window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                } else {
                    window.zoom(nil)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Window controls")
    }

    private enum ControlRole {
        case close
        case minimize
        case zoom
    }

    private func shellWindowButton(role: ControlRole, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .fill(fillColor(for: role))
                .frame(
                    width: DesignTokens.Layout.windowControlSize,
                    height: DesignTokens.Layout.windowControlSize
                )
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                        .strokeBorder(DesignTokens.Color.borderSubtle.opacity(0.85), lineWidth: DesignTokens.Layout.borderWidth)
                }
                .overlay {
                    controlGlyph(role)
                        .foregroundStyle(DesignTokens.Color.textSecondary.opacity(role == .close ? 0.9 : 0.75))
                }
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .help(helpText(for: role))
    }

    @ViewBuilder
    private func controlGlyph(_ role: ControlRole) -> some View {
        switch role {
        case .close:
            Text("×")
                .font(.system(size: 11, weight: .semibold))
                .offset(y: -0.5)
        case .minimize:
            Text("−")
                .font(.system(size: 12, weight: .medium))
        case .zoom:
            Text("+")
                .font(.system(size: 12, weight: .medium))
        }
    }

    private func fillColor(for role: ControlRole) -> Color {
        switch role {
        case .close:
            return palette.warning.opacity(0.32)
        case .minimize, .zoom:
            return DesignTokens.Color.surfaceElevated.opacity(0.95)
        }
    }

    private func helpText(for role: ControlRole) -> String {
        switch role {
        case .close: return "Close window"
        case .minimize: return "Minimize window"
        case .zoom: return "Zoom window"
        }
    }
}

// MARK: - Filled shell title bar

struct OWShellTitleBar: View {
    @Environment(\.openWritePalette) private var palette
    @State private var windowControlTopInset = DesignTokens.Layout.windowControlTopInset
    @State private var shellChromeSafeAreaTop = DesignTokens.Layout.shellChromeSafeAreaTop
    @State private var shellChromeContentLeadingInset = DesignTokens.Layout.shellChromeContentLeadingInset

    let tabs: [CenterWorkbenchTab]
    let selectedTab: CenterWorkbenchTab
    let onSelectTab: (CenterWorkbenchTab) -> Void
    /// When the navigation rail is visible, align brand text with section headers inside the rail.
    var brandAlignsWithNavigationRail: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < DesignTokens.Layout.shellCompactBreakpoint
            let leadingInset: CGFloat = {
                if brandAlignsWithNavigationRail {
                    return DesignTokens.Layout.navigationRailBrandLeadingInset
                }
                return compact
                    ? DesignTokens.Layout.shellChromeCompactLeadingInset
                    : shellChromeContentLeadingInset
            }()

            ZStack(alignment: .topLeading) {
                palette.shellChrome
                    .ignoresSafeArea(edges: .top)

                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: DesignTokens.Spacing.spacing2) {
                        if OWWindowChrome.usesCustomWindowControls {
                            OWShellWindowControls()
                                .padding(.leading, DesignTokens.Layout.windowControlLeadingInset)
                        } else {
                            Color.clear
                                .frame(width: shellChromeContentLeadingInset)
                                .accessibilityHidden(true)
                        }

                        if !brandAlignsWithNavigationRail {
                            HStack(alignment: .center, spacing: DesignTokens.Spacing.spacing2) {
                                OWBrandMark(size: compact ? 18 : 20)
                                Text("OpenWrite")
                                    .font(compact ? OWTypography.captionEmphasis : OWTypography.bodyEmphasis)
                                    .foregroundStyle(DesignTokens.Color.textPrimary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.top, windowControlTopInset)
                    .padding(.bottom, DesignTokens.Spacing.spacing1)
                    .frame(height: shellChromeSafeAreaTop, alignment: .bottomLeading)
                    .padding(.trailing, DesignTokens.Spacing.spacing4)

                    HStack(spacing: 0) {
                        Spacer(minLength: leadingInset)
                        tabStrip
                            .layoutPriority(1)
                        Spacer(minLength: leadingInset)
                    }
                    .frame(height: DesignTokens.Layout.shellChromeBarHeight, alignment: .center)
                    .padding(.trailing, DesignTokens.Spacing.spacing4)

                    Rectangle()
                        .fill(DesignTokens.Color.borderHairline)
                        .frame(height: DesignTokens.Layout.borderWidth)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
            .zIndex(OWWindowChrome.usesCustomWindowControls ? 2 : 0)
        }
        .frame(height: shellChromeSafeAreaTop + DesignTokens.Layout.shellChromeBarHeight + DesignTokens.Layout.borderWidth)
        .clipped()
        .zIndex(10)
        .background {
            OWWindowChromeLayoutReader(
                windowControlTopInset: $windowControlTopInset,
                shellChromeSafeAreaTop: $shellChromeSafeAreaTop,
                shellChromeContentLeadingInset: $shellChromeContentLeadingInset
            )
        }
        .background(OWTitleBarDraggableRegion())
    }

    private var tabStrip: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            ForEach(tabs) { tab in
                Button {
                    onSelectTab(tab)
                } label: {
                    Text(tab.title)
                        .font(OWTypography.captionEmphasis)
                        .foregroundStyle(
                            isTabSelected(tab)
                                ? DesignTokens.Color.textPrimary
                                : DesignTokens.Color.textTertiary
                        )
                        .padding(.horizontal, DesignTokens.Spacing.spacing3)
                        .padding(.vertical, DesignTokens.Spacing.spacing1 + 1)
                        .background(
                            isTabSelected(tab)
                                ? DesignTokens.Color.surfaceElevated.opacity(0.95)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                        )
                        .overlay {
                            if isTabSelected(tab) {
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                                    .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: DesignTokens.Layout.borderWidth)
                            }
                        }
                }
                .buttonStyle(.plain)
                .openWriteFocusChrome()
            }
        }
    }

    private func isTabSelected(_ tab: CenterWorkbenchTab) -> Bool {
        switch (selectedTab, tab) {
        case (.editor, .editor), (.graph, .graph):
            return true
        case (.database(let active), .database(let candidate)):
            return active.id == candidate.id
        default:
            return false
        }
    }
}

// MARK: - Shell layout resolution

/// Computes column widths and collapse hints when the window or workbench shrinks.
enum OWShellLayout {
    static func editorMinimum(forCenterWidth centerWidth: CGFloat) -> CGFloat {
        max(
            DesignTokens.Layout.editorMinWidth,
            centerWidth * DesignTokens.Layout.editorMinWidthFraction
        )
    }

    /// Lower editor floor while assist is expanded so the strip can shrink before collapsing.
    static func editorMinimumWhenAssistOpen(forCenterWidth centerWidth: CGFloat) -> CGFloat {
        max(
            DesignTokens.Layout.editorMinWidthWhenAssistOpen,
            centerWidth * DesignTokens.Layout.editorMinWidthWhenAssistFraction
        )
    }

    static func flexibleMinimum(
        forCenterWidth centerWidth: CGFloat,
        assistExpanded: Bool
    ) -> CGFloat {
        assistExpanded
            ? editorMinimumWhenAssistOpen(forCenterWidth: centerWidth)
            : editorMinimum(forCenterWidth: centerWidth)
    }

    static func splitChromeWidth(isResizable: Bool) -> CGFloat {
        DesignTokens.Layout.shellColumnGutter
            + (isResizable ? DesignTokens.Layout.splitDividerHitWidth : 0)
    }

    /// Minimum center workbench width (after outer card padding) for editor + assist minimums.
    static func minimumCenterWidthForAssistOpen(forCenterWidth centerWidth: CGFloat) -> CGFloat {
        let editorMin = editorMinimumWhenAssistOpen(forCenterWidth: centerWidth)
        let chrome = splitChromeWidth(isResizable: true)
        return editorMin + DesignTokens.Layout.assistStripMinWidth + chrome
    }

    /// Maximum width the fixed column may occupy without starving the flexible column.
    static func clampedFixedWidth(
        preferred: CGFloat,
        minWidth: CGFloat,
        maxWidth: CGFloat,
        availableWidth: CGFloat,
        flexibleMinWidth: CGFloat,
        isResizable: Bool
    ) -> CGFloat {
        let chrome = splitChromeWidth(isResizable: isResizable)
        let flexibleBudget = max(0, availableWidth - chrome)
        let nominalMaxFixed = flexibleBudget - flexibleMinWidth
        if nominalMaxFixed < minWidth {
            // Container too narrow for both mins — cap fixed column so the flexible column keeps space.
            return preferred.clamped(to: 0 ... min(maxWidth, max(0, nominalMaxFixed)))
        }
        let maxFixed = max(minWidth, nominalMaxFixed)
        return preferred.clamped(to: minWidth ... min(maxWidth, maxFixed))
    }

    /// When assist is expanded, collapse before the split would clip below assist minimum width.
    static func shouldAutoCollapseAssist(centerWidth: CGFloat) -> Bool {
        centerWidth < minimumCenterWidthForAssistOpen(forCenterWidth: centerWidth)
    }

    static func maxAssistWidth(
        centerWidth: CGFloat,
        preferredAssistWidth: CGFloat,
        assistExpanded: Bool = true
    ) -> CGFloat {
        let editorMin = flexibleMinimum(forCenterWidth: centerWidth, assistExpanded: assistExpanded)
        let chrome = splitChromeWidth(isResizable: true)
        let cap = centerWidth - editorMin - chrome
        return preferredAssistWidth.clamped(
            to: DesignTokens.Layout.assistStripMinWidth ... min(DesignTokens.Layout.assistStripMaxWidth, cap)
        )
    }
}

// MARK: - Resizable column split

struct OWResizableColumnSplit<Leading: View, Trailing: View>: View {
    enum FixedColumn {
        case leading
        case trailing
    }

    @Binding var fixedWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    var fixedColumn: FixedColumn = .leading
    var isResizable: Bool = true
    /// Minimum width reserved for the flexible (non-fixed) column when the container shrinks.
    var flexibleMinWidth: CGFloat = DesignTokens.Layout.editorMinWidth
    var onCommitWidth: ((CGFloat) -> Void)?
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    @State private var dragOriginWidth: CGFloat?
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let resolvedFixed = OWShellLayout.clampedFixedWidth(
                preferred: fixedWidth,
                minWidth: minWidth,
                maxWidth: maxWidth,
                availableWidth: geometry.size.width,
                flexibleMinWidth: flexibleMinWidth,
                isResizable: isResizable
            )

            HStack(spacing: 0) {
                switch fixedColumn {
                case .leading:
                    leading()
                        .frame(width: resolvedFixed)
                    if isResizable {
                        splitDivider
                    }
                    trailing()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)
                case .trailing:
                    leading()
                        .frame(minWidth: flexibleMinWidth, maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)
                    if isResizable {
                        splitDivider
                    }
                    trailing()
                        .frame(width: resolvedFixed)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            .clipped()
            .onAppear {
                reconcileFixedWidth(availableWidth: geometry.size.width)
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                reconcileFixedWidth(availableWidth: newWidth)
            }
            .onChange(of: isResizable) { _, _ in
                reconcileFixedWidth(availableWidth: geometry.size.width)
            }
            .onChange(of: minWidth) { _, _ in
                reconcileFixedWidth(availableWidth: geometry.size.width)
            }
            .onChange(of: maxWidth) { _, _ in
                reconcileFixedWidth(availableWidth: geometry.size.width)
            }
        }
    }

    private func reconcileFixedWidth(availableWidth: CGFloat) {
        guard !isDragging else { return }
        let preferred = isResizable ? fixedWidth : minWidth
        let resolved = OWShellLayout.clampedFixedWidth(
            preferred: preferred,
            minWidth: minWidth,
            maxWidth: maxWidth,
            availableWidth: availableWidth,
            flexibleMinWidth: flexibleMinWidth,
            isResizable: isResizable
        )
        guard abs(fixedWidth - resolved) > 0.5 else { return }
        fixedWidth = resolved
    }

    private var splitDivider: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: DesignTokens.Layout.splitDividerHitWidth)
            .padding(.leading, DesignTokens.Layout.shellColumnGutter)
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(
                        isDragging
                            ? DesignTokens.Color.accent.opacity(0.55)
                            : DesignTokens.Color.borderSubtle
                    )
                    .frame(width: DesignTokens.Layout.borderWidth)
                    .padding(.leading, DesignTokens.Layout.shellColumnGutter)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if dragOriginWidth == nil {
                            dragOriginWidth = fixedWidth
                        }
                        isDragging = true
                        let origin = dragOriginWidth ?? fixedWidth
                        let delta = fixedColumn == .leading
                            ? value.translation.width
                            : -value.translation.width
                        fixedWidth = (origin + delta).clamped(to: minWidth ... maxWidth)
                    }
                    .onEnded { _ in
                        dragOriginWidth = nil
                        isDragging = false
                        onCommitWidth?(fixedWidth)
                        NSCursor.pop()
                    }
            )
            .accessibilityLabel("Resize sidebar")
            .accessibilityAddTraits(.isButton)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
