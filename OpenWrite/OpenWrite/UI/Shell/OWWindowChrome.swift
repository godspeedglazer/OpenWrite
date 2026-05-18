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

// MARK: - NSWindow configuration

/// Applies unified transparent titlebar so custom shell chrome can sit behind traffic lights.
struct OWWindowChromeConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.openWriteSuppressFocusRing()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let revision = ThemeManager.shared.revision
        let windowID = nsView.window.map(ObjectIdentifier.init)
        let coordinator = context.coordinator
        let needsApply = revision != coordinator.lastAppliedRevision
            || windowID != coordinator.boundWindowID
        guard needsApply else { return }
        coordinator.lastAppliedRevision = revision
        coordinator.boundWindowID = windowID
        guard let window = nsView.window else { return }
        DispatchQueue.main.async {
            guard nsView.window === window else { return }
            OWWindowChrome.apply(to: window)
        }
    }

    final class Coordinator {
        var lastAppliedRevision: UInt = 0
        var boundWindowID: ObjectIdentifier?
    }
}

/// Compact OpenWrite mark for title bar and About surfaces.
struct OWBrandMark: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            Circle()
                .fill(DesignTokens.Color.accentMuted)
            Circle()
                .strokeBorder(DesignTokens.Color.accent.opacity(0.35), lineWidth: 1)
            Text("◎")
                .font(.system(size: size * 0.55, weight: .medium))
                .foregroundStyle(DesignTokens.Color.accent)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("OpenWrite")
    }
}

enum OWWindowChrome {
    /// When true (e.g. graph canvas visible), background clicks must not move the window.
    static var suppressBackgroundWindowDrag = false

    private static var titlebarFillAccessories: [ObjectIdentifier: OWSolidTitlebarAccessory] = [:]
    private static var installedWindowCloseObserver = false

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
            guard let accessory = titlebarFillAccessories.removeValue(forKey: key) else { return }
            if let index = window.titlebarAccessoryViewControllers.firstIndex(where: { $0 === accessory }) {
                window.removeTitlebarAccessoryViewController(at: index)
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

        window.title = "OpenWrite"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
            window.toolbarStyle = .unifiedCompact
        }
        if window.styleMask.contains(.titled) {
            window.styleMask.insert(.fullSizeContentView)
        }
        window.toolbar = nil

        let theme = ThemeManager.shared.selectedTheme
        let palette = ThemeManager.shared.palette
        let chrome = NSColor(palette.shellChrome)
        window.appearance = NSAppearance(named: theme.prefersDarkAppearance ? .darkAqua : .aqua)
        window.isOpaque = true
        window.backgroundColor = chrome
        paintThemeFrame(window, color: chrome)
        stripTitlebarVibrancy(in: window, fill: chrome)
        if supportsTitlebarAccessory(on: window) {
            installSolidTitlebarFill(on: window, color: chrome)
            reorderTitlebarAccessories(on: window)
        }
        tintHostingRoot(window, color: chrome)
        hideSystemTrafficLights(in: window)
    }

    /// Replaces system traffic lights on the **main** titled window only (`canApplyChrome` excludes sheets).
    /// Sheets keep native controls so we never hide traffic lights without replacements.
    private static func hideSystemTrafficLights(in window: NSWindow) {
        guard canApplyChrome(to: window) else { return }
        for kind: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(kind)?.isHidden = true
        }
    }

    /// Keeps the opaque fill behind traffic lights (first accessory wins stacking).
    private static func reorderTitlebarAccessories(on window: NSWindow) {
        guard supportsTitlebarAccessory(on: window) else { return }
        let key = ObjectIdentifier(window)
        guard let accessory = titlebarFillAccessories[key] else { return }
        var accessories = window.titlebarAccessoryViewControllers
        guard let index = accessories.firstIndex(where: { $0 === accessory }), index > 0 else { return }
        accessories.remove(at: index)
        accessories.insert(accessory, at: 0)
        window.titlebarAccessoryViewControllers = accessories
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
        guard var view = window.contentView?.superview else { return }
        while true {
            let typeName = String(describing: type(of: view))
            view.wantsLayer = true
            view.layer?.backgroundColor = color.cgColor
            if typeName.contains("ThemeFrame") || typeName.contains("NSFrameView") {
                break
            }
            guard let parent = view.superview else { break }
            view = parent
        }
    }

    private static func tintHostingRoot(_ window: NSWindow, color: NSColor) {
        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = color.cgColor
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
                effect.material = .windowBackground
                effect.blendingMode = .withinWindow
                effect.state = .active
                effect.isEmphasized = false
                effect.wantsLayer = true
                effect.layer?.backgroundColor = chrome.cgColor
            } else if typeName.contains("Titlebar") || typeName.contains("TitleBar") || typeName.contains("ThemeFrame") {
                current.wantsLayer = true
                current.layer?.backgroundColor = chrome.cgColor
            }
            view = current.superview
        }
        for effect in visualEffectViews(in: root) {
            effect.material = .windowBackground
            effect.blendingMode = .withinWindow
            effect.state = .active
            effect.isEmphasized = false
            effect.wantsLayer = true
            effect.layer?.backgroundColor = chrome.cgColor
        }
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
                NSApp.keyWindow?.zoom(nil)
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
            return palette.warning.opacity(0.22)
        case .minimize, .zoom:
            return DesignTokens.Color.surfaceElevated.opacity(0.88)
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

    let tabs: [CenterWorkbenchTab]
    let selectedTab: CenterWorkbenchTab
    let onSelectTab: (CenterWorkbenchTab) -> Void
    /// When the navigation rail is visible, align brand text with section headers inside the rail.
    var brandAlignsWithNavigationRail: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < DesignTokens.Layout.shellCompactBreakpoint
            let chromeContentHeight = DesignTokens.Layout.shellChromeSafeAreaTop + DesignTokens.Layout.shellChromeBarHeight
            let leadingInset: CGFloat = {
                if brandAlignsWithNavigationRail {
                    return DesignTokens.Layout.navigationRailBrandLeadingInset
                }
                return compact
                    ? DesignTokens.Layout.shellChromeCompactLeadingInset
                    : DesignTokens.Layout.shellChromeContentLeadingInset
            }()

            ZStack(alignment: .top) {
                palette.shellChrome
                    .ignoresSafeArea(edges: .top)

                VStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        HStack(spacing: DesignTokens.Spacing.spacing3) {
                            OWShellWindowControls()
                                .padding(.leading, DesignTokens.Layout.windowControlLeadingInset)

                            if !brandAlignsWithNavigationRail {
                                HStack(spacing: DesignTokens.Spacing.spacing2) {
                                    OWBrandMark(size: compact ? 18 : 20)
                                    Text("OpenWrite")
                                        .font(compact ? OWTypography.captionEmphasis : OWTypography.bodyEmphasis)
                                        .foregroundStyle(DesignTokens.Color.textPrimary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.top, DesignTokens.Layout.windowControlTopInset)
                        .padding(.trailing, DesignTokens.Spacing.spacing4)

                        HStack(spacing: 0) {
                            Spacer(minLength: leadingInset)
                            tabStrip
                                .layoutPriority(1)
                            Spacer(minLength: leadingInset)
                        }
                        .padding(.top, DesignTokens.Layout.windowControlTopInset)
                        .padding(.trailing, DesignTokens.Spacing.spacing4)
                    }
                    .frame(height: chromeContentHeight, alignment: .top)

                    Rectangle()
                        .fill(DesignTokens.Color.borderHairline)
                        .frame(height: DesignTokens.Layout.borderWidth)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
        }
        .frame(height: DesignTokens.Layout.shellChromeSafeAreaTop + DesignTokens.Layout.shellChromeBarHeight + DesignTokens.Layout.borderWidth)
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

            HStack(spacing: DesignTokens.Layout.shellColumnGutter) {
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)
                    if isResizable {
                        splitDivider
                    }
                    trailing()
                        .frame(width: resolvedFixed)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
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
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(
                        isDragging
                            ? DesignTokens.Color.accent.opacity(0.55)
                            : DesignTokens.Color.borderSubtle
                    )
                    .frame(width: DesignTokens.Layout.borderWidth)
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
