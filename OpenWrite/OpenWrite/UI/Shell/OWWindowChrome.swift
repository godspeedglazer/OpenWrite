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
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.openWriteSuppressFocusRing()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            OWWindowChrome.apply(to: window)
        }
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

    static func apply(to window: NSWindow) {
        window.title = "OpenWrite"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = !suppressBackgroundWindowDrag
        if #available(macOS 11.0, *) {
            window.titlebarSeparatorStyle = .none
            window.toolbarStyle = .unified
        }
        window.styleMask.insert(.fullSizeContentView)
        window.isOpaque = false
        window.toolbar = nil

        let palette = ThemeManager.shared.palette
        let chrome = NSColor(palette.shellChrome)
        window.backgroundColor = chrome
    }

    static func reapplyToKeyWindow() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        apply(to: window)
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
        background(OWWindowChromeConfigurator())
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
            let leadingInset: CGFloat = {
                if brandAlignsWithNavigationRail {
                    return DesignTokens.Layout.navigationRailBrandLeadingInset
                }
                return compact
                    ? DesignTokens.Layout.shellChromeCompactLeadingInset
                    : DesignTokens.Layout.shellChromeContentLeadingInset
            }()

            VStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    HStack(spacing: DesignTokens.Spacing.spacing3) {
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
                    .padding(.leading, leadingInset)
                    .padding(.trailing, DesignTokens.Spacing.spacing4)

                    HStack(spacing: 0) {
                        Spacer(minLength: leadingInset)
                        tabStrip
                            .layoutPriority(1)
                        Spacer(minLength: leadingInset)
                    }
                    .padding(.trailing, DesignTokens.Spacing.spacing4)
                }
                .frame(height: DesignTokens.Layout.shellChromeBarHeight, alignment: .center)

                Rectangle()
                    .fill(DesignTokens.Color.borderHairline)
                    .frame(height: DesignTokens.Layout.borderWidth)
            }
            .padding(.top, DesignTokens.Layout.shellChromeSafeAreaTop)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .background {
                palette.shellChrome
                    .ignoresSafeArea(edges: .top)
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
