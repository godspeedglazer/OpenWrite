import AppKit
import SwiftUI

// MARK: - Themed NSScroller

/// Thin overlay scroller tinted from the active `ThemePalette`.
final class OpenWriteThemedScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override class func scrollerWidth(
        for controlSize: NSControl.ControlSize,
        scrollerStyle: NSScroller.Style
    ) -> CGFloat {
        if scrollerStyle == .overlay {
            return DesignTokens.Scrollbar.overlayWidth
        }
        return super.scrollerWidth(for: controlSize, scrollerStyle: scrollerStyle)
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        guard flag else { return }
        let track = NSColor(DesignTokens.Color.scrollbarTrack)
            .withAlphaComponent(DesignTokens.Scrollbar.trackAlphaWhileActive)
        track.setFill()
        let inset = slotRect.insetBy(
            dx: DesignTokens.Scrollbar.trackHorizontalInset,
            dy: DesignTokens.Scrollbar.trackVerticalInset
        )
        let radius = DesignTokens.Scrollbar.trackCornerRadius
        NSBezierPath(roundedRect: inset, xRadius: radius, yRadius: radius).fill()
    }

    override func drawKnob() {
        let knob = NSColor(DesignTokens.Color.scrollbarKnob)
        knob.setFill()
        let rect = rect(for: .knob).insetBy(
            dx: DesignTokens.Scrollbar.knobHorizontalInset,
            dy: DesignTokens.Scrollbar.knobVerticalInset
        )
        let radius = DesignTokens.Scrollbar.knobCornerRadius
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }
}

// MARK: - NSScrollView styling

extension NSScrollView {
    /// Applies OpenWrite overlay scrollers (neutral thumb, minimal track).
    func openWriteApplyThemedScrollers(vertical: Bool = true, horizontal: Bool = false) {
        openWriteSuppressFocusRing()
        drawsBackground = false
        borderType = .noBorder
        scrollerStyle = .overlay
        autohidesScrollers = true
        hasVerticalScroller = vertical
        hasHorizontalScroller = horizontal
        verticalScrollElasticity = .automatic
        horizontalScrollElasticity = .automatic

        if vertical {
            if !(verticalScroller is OpenWriteThemedScroller) {
                let scroller = OpenWriteThemedScroller()
                scroller.scrollerStyle = .overlay
                scroller.controlSize = .mini
                verticalScroller = scroller
            }
            verticalScroller?.controlSize = .mini
            verticalScroller?.needsDisplay = true
        }
        if horizontal {
            if !(horizontalScroller is OpenWriteThemedScroller) {
                let scroller = OpenWriteThemedScroller()
                scroller.scrollerStyle = .overlay
                scroller.controlSize = .mini
                horizontalScroller = scroller
            }
            horizontalScroller?.controlSize = .mini
            horizontalScroller?.needsDisplay = true
        }
    }

    func openWriteRefreshThemedScrollers() {
        verticalScroller?.needsDisplay = true
        horizontalScroller?.needsDisplay = true
    }

    func openWriteScrollToBottom(animated: Bool = true) {
        guard let documentView else { return }
        let clip = contentView
        let maxY = max(0, documentView.frame.height - clip.bounds.height)
        let target = NSPoint(x: 0, y: maxY)
        if animated {
            clip.animator().setBoundsOrigin(target)
        } else {
            clip.scroll(to: target)
        }
        reflectScrolledClipView(clip)
    }

    /// Resizes or relayouts the document view without resetting the user's scroll offset.
    func openWriteUpdateDocumentPreservingScroll(_ update: () -> Void) {
        let clip = contentView
        let savedOrigin = clip.bounds.origin
        update()
        guard let documentView else { return }
        let maxY = max(0, documentView.frame.height - clip.bounds.height)
        let restoredY = min(max(savedOrigin.y, 0), maxY)
        let target = NSPoint(x: savedOrigin.x, y: restoredY)
        if abs(clip.bounds.origin.y - target.y) > 0.5 || abs(clip.bounds.origin.x - target.x) > 0.5 {
            clip.scroll(to: target)
            reflectScrolledClipView(clip)
        }
    }
}

// MARK: - Scroll container (live resize + content growth)

/// NSScrollView that remeasures its hosting document when the clip view **size** changes (not on scroll).
private final class OpenWriteThemedScrollContainer: NSScrollView {
    var onClipViewLayout: (() -> Void)?
    private var lastNotifiedClipSize = NSSize.zero

    func resetClipLayoutTracking() {
        lastNotifiedClipSize = .zero
    }

    override func layout() {
        super.layout()
        let clipSize = contentView.bounds.size
        guard clipSize.width > 0.5, clipSize.height > 0.5 else { return }
        guard abs(clipSize.width - lastNotifiedClipSize.width) > 0.5
            || abs(clipSize.height - lastNotifiedClipSize.height) > 0.5 else { return }
        lastNotifiedClipSize = clipSize
        onClipViewLayout?()
    }
}

// MARK: - SwiftUI themed scroll

/// Theme-aware vertical scroll surface (NSScrollView + custom scroller).
struct OpenWriteThemedScrollView<Content: View>: View {
    @Environment(\.openWritePalette) private var palette

    private let axes: Axis.Set
    private let scrollToken: Int
    private let canvasColor: Color?
    /// When true, a changed `scrollToken` scrolls to the bottom (chat). When false, remeasures only (editor).
    private let scrollToBottomOnTokenChange: Bool
    private let content: Content

    init(
        _ axes: Axis.Set = .vertical,
        scrollToken: Int = 0,
        canvasColor: Color? = nil,
        scrollToBottomOnTokenChange: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.scrollToken = scrollToken
        self.canvasColor = canvasColor
        self.scrollToBottomOnTokenChange = scrollToBottomOnTokenChange
        self.content = content()
    }

    private var resolvedCanvasColor: Color {
        canvasColor ?? palette.background
    }

    var body: some View {
        OpenWriteThemedScrollRepresentable(
            axes: axes,
            scrollToken: scrollToken,
            canvasColor: resolvedCanvasColor,
            scrollToBottomOnTokenChange: scrollToBottomOnTokenChange,
            content: content
        )
    }
}

private struct OpenWriteThemedScrollRepresentable<Content: View>: NSViewRepresentable {
    let axes: Axis.Set
    let scrollToken: Int
    let canvasColor: Color
    let scrollToBottomOnTokenChange: Bool
    let content: Content

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> OpenWriteThemedScrollContainer {
        let scrollView = OpenWriteThemedScrollContainer()
        scrollView.openWriteApplyThemedScrollers(
            vertical: axes.contains(.vertical),
            horizontal: axes.contains(.horizontal)
        )
        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.sizingOptions = [.intrinsicContentSize]
        context.coordinator.applyCanvasColor(canvasColor, to: hosting)
        context.coordinator.hostingView = hosting
        scrollView.documentView = hosting

        scrollView.onClipViewLayout = { [weak coordinator = context.coordinator, weak scrollView] in
            guard let coordinator, let scrollView else { return }
            coordinator.scheduleRefreshDocumentSize(in: scrollView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: OpenWriteThemedScrollContainer, context: Context) {
        scrollView.openWriteApplyThemedScrollers(
            vertical: axes.contains(.vertical),
            horizontal: axes.contains(.horizontal)
        )
        scrollView.openWriteRefreshThemedScrollers()

        guard let hosting = context.coordinator.hostingView else { return }
        context.coordinator.applyCanvasColor(canvasColor, to: hosting)
        hosting.rootView = content

        let themeRevision = ThemeManager.shared.revision
        if context.coordinator.lastThemeRevision != themeRevision {
            context.coordinator.lastThemeRevision = themeRevision
            context.coordinator.invalidateDocumentMeasurement(in: scrollView)
        }

        context.coordinator.scheduleRefreshDocumentSize(in: scrollView)

        if context.coordinator.lastScrollToken != scrollToken {
            context.coordinator.lastScrollToken = scrollToken
            if scrollToBottomOnTokenChange {
                DispatchQueue.main.async {
                    scrollView.openWriteScrollToBottom(animated: true)
                }
            } else {
                context.coordinator.invalidateDocumentMeasurement(in: scrollView)
                context.coordinator.scheduleRefreshDocumentSize(in: scrollView)
            }
        }
    }

    /// Read-only height probe — `fittingSize` only; never forces subtree layout during SwiftUI measure.
    private static func measureDocumentHeight(
        for hosting: NSHostingView<Content>,
        width: CGFloat,
        clipHeight: CGFloat
    ) -> CGFloat {
        let safeWidth = max(width, 1)
        let priorFrame = hosting.frame
        if abs(priorFrame.width - safeWidth) > 0.5 {
            hosting.frame.size.width = safeWidth
        }
        let measured = max(hosting.fittingSize.height, hosting.intrinsicContentSize.height)
        if abs(priorFrame.width - safeWidth) > 0.5 || abs(priorFrame.height - hosting.frame.height) > 0.5 {
            hosting.frame = priorFrame
        }

        let minHeight = max(clipHeight + 1, 1)
        return max(measured, minHeight)
    }

    final class Coordinator {
        var hostingView: NSHostingView<Content>?
        var lastScrollToken: Int = -1
        var lastThemeRevision: UInt = 0
        private var lastAppliedDocumentSize = NSSize.zero
        private var lastClipSize: NSSize = .zero
        private var refreshGeneration = 0

        func applyCanvasColor(_ color: Color, to hosting: NSHostingView<Content>) {
            hosting.layer?.backgroundColor = NSColor(color).cgColor
        }

        func invalidateDocumentMeasurement(in scrollView: NSScrollView) {
            lastClipSize = .zero
            lastAppliedDocumentSize = .zero
            (scrollView as? OpenWriteThemedScrollContainer)?.resetClipLayoutTracking()
        }

        func scheduleRefreshDocumentSize(in scrollView: NSScrollView) {
            refreshGeneration += 1
            let generation = refreshGeneration
            DispatchQueue.main.async { [weak self, weak scrollView] in
                guard let self, let scrollView, generation == self.refreshGeneration else { return }
                self.refreshDocumentSize(in: scrollView)
            }
        }

        func refreshDocumentSize(in scrollView: NSScrollView) {
            guard let hosting = hostingView else { return }

            let clipSize = scrollView.contentView.bounds.size
            let width = max(clipSize.width, 1)
            let height = OpenWriteThemedScrollRepresentable.measureDocumentHeight(
                for: hosting,
                width: width,
                clipHeight: clipSize.height
            )

            let targetSize = NSSize(width: width, height: height)
            let sizeChanged =
                abs(lastAppliedDocumentSize.width - targetSize.width) > 0.5
                || abs(lastAppliedDocumentSize.height - targetSize.height) > 0.5
                || abs(lastClipSize.width - clipSize.width) > 0.5
                || abs(lastClipSize.height - clipSize.height) > 0.5

            guard sizeChanged else { return }

            lastClipSize = clipSize
            lastAppliedDocumentSize = targetSize

            scrollView.openWriteUpdateDocumentPreservingScroll {
                hosting.frame = NSRect(origin: .zero, size: targetSize)
                hosting.needsLayout = true
                scrollView.tile()
            }
        }
    }
}
