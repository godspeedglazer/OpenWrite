import AppKit
import SwiftUI

// MARK: - NSWindow configuration

/// Applies unified transparent titlebar so custom shell chrome can sit behind traffic lights.
struct OWWindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
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

enum OWWindowChrome {
    static func apply(to window: NSWindow) {
        window.title = "OpenWrite"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unifiedCompact
        }
        window.styleMask.insert(.fullSizeContentView)
        window.backgroundColor = .clear
        window.isOpaque = false
    }
}

extension View {
    func openWriteWindowChrome() -> some View {
        background(OWWindowChromeConfigurator())
    }
}

// MARK: - Filled shell title bar

struct OWShellTitleBar: View {
    let tabs: [CenterWorkbenchTab]
    let selectedTab: CenterWorkbenchTab
    let onSelectTab: (CenterWorkbenchTab) -> Void

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < DesignTokens.Layout.shellCompactBreakpoint
            let leadingInset = compact
                ? DesignTokens.Layout.shellChromeCompactLeadingInset
                : DesignTokens.Layout.shellChromeContentLeadingInset

            VStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    HStack(spacing: DesignTokens.Spacing.spacing3) {
                        Text("OpenWrite")
                            .font(compact ? OWTypography.captionEmphasis : OWTypography.bodyEmphasis)
                            .foregroundStyle(DesignTokens.Color.textPrimary)
                            .lineLimit(1)

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
                DesignTokens.Color.shellChrome
                    .ignoresSafeArea(edges: .top)
            }
        }
        .frame(height: DesignTokens.Layout.shellChromeSafeAreaTop + DesignTokens.Layout.shellChromeBarHeight + DesignTokens.Layout.borderWidth)
    }

    private var tabStrip: some View {
        HStack(spacing: DesignTokens.Spacing.spacing1) {
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
                        .padding(.vertical, DesignTokens.Spacing.spacing1)
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
            }
        }
        .padding(DesignTokens.Spacing.spacing1)
        .background(
            DesignTokens.Color.surface.opacity(0.55),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
        )
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

    static func splitChromeWidth(isResizable: Bool) -> CGFloat {
        DesignTokens.Layout.shellColumnGutter
            + (isResizable ? DesignTokens.Layout.splitDividerHitWidth : 0)
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
        let maxFixed = max(minWidth, availableWidth - flexibleMinWidth - chrome)
        return preferred.clamped(to: minWidth ... min(maxWidth, maxFixed))
    }

    /// When assist is expanded, returns false if there is not enough room for editor + assist minimums.
    static func canFitAssistStrip(centerWidth: CGFloat) -> Bool {
        let editorMin = editorMinimum(forCenterWidth: centerWidth)
        let chrome = splitChromeWidth(isResizable: true)
        return centerWidth >= editorMin + DesignTokens.Layout.assistStripMinWidth + chrome
    }

    static func maxAssistWidth(
        centerWidth: CGFloat,
        preferredAssistWidth: CGFloat
    ) -> CGFloat {
        let editorMin = editorMinimum(forCenterWidth: centerWidth)
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
        }
    }

    private func reconcileFixedWidth(availableWidth: CGFloat) {
        guard !isDragging else { return }
        let resolved = OWShellLayout.clampedFixedWidth(
            preferred: fixedWidth,
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
