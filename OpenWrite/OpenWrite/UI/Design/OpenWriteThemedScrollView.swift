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

private let openWriteScrollBottomPinThreshold: CGFloat = 56

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
        Coordinator(stickToBottomOnGrowth: scrollToBottomOnTokenChange)
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
        context.coordinator.installScrollTracking(on: scrollView)

        if scrollToBottomOnTokenChange {
            scrollView.onClipViewLayout = { [weak coordinator = context.coordinator, weak scrollView] in
                guard let coordinator, let scrollView else { return }
                coordinator.scheduleRefreshDocumentSize(in: scrollView)
            }
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
        context.coordinator.stickToBottomOnGrowth = scrollToBottomOnTokenChange
        context.coordinator.applyCanvasColor(canvasColor, to: hosting)
        hosting.rootView = content

        let themeRevision = ThemeManager.shared.revision
        let themeChanged = context.coordinator.lastThemeRevision != themeRevision
        if themeChanged {
            context.coordinator.lastThemeRevision = themeRevision
            context.coordinator.invalidateDocumentMeasurement(in: scrollView)
        }

        let scrollTokenChanged = context.coordinator.lastScrollToken != scrollToken
        if scrollTokenChanged {
            let wasNearBottom = context.coordinator.isNearBottom(in: scrollView)
            context.coordinator.lastScrollToken = scrollToken
            if scrollToBottomOnTokenChange {
                context.coordinator.scheduleScrollToBottomIfPinned(in: scrollView, wasNearBottom: wasNearBottom)
            } else {
                context.coordinator.invalidateDocumentMeasurement(in: scrollView)
            }
        }

        // INVARIANT: Do not call `scheduleRefreshDocumentSize` on every SwiftUI tick — that fights the
        // nested block-editor paste host and retriggers `invalidateIntrinsicContentSize` in a loop.
        // Remeasure only when theme/scroll token changes or read-only probe shows height drift.
        if themeChanged || scrollTokenChanged {
            context.coordinator.scheduleRefreshDocumentSize(in: scrollView)
        } else if scrollToBottomOnTokenChange {
            context.coordinator.scheduleRefreshDocumentSizeIfContentGrew(in: scrollView)
        }
    }

    /// Read-only height probe — width + `fittingSize` only. Never `layoutSubtreeIfNeeded` or
    /// `invalidateIntrinsicContentSize` here: invalidation during measure retriggers layout →
    /// `updateNSView` → `refreshDocumentSize` (AttributeGraph / Welcome CPU fork-bomb).
    private static func measureDocumentHeight(
        for hosting: NSHostingView<Content>,
        width: CGFloat
    ) -> CGFloat {
        let safeWidth = max(width, 1)
        let priorFrame = hosting.frame
        if abs(priorFrame.width - safeWidth) > 0.5 {
            hosting.frame.size.width = safeWidth
        }
        let fitting = hosting.fittingSize.height
        let intrinsic = hosting.intrinsicContentSize.height
        hosting.frame = priorFrame
        return max(max(fitting, intrinsic), 1)
    }

    /// Bounded subtree layout (deferred `refreshDocumentSize` only — never from `measureDocumentHeight`).
    /// Uses a tight probe height instead of a multi-million-point frame so `fittingSize` reflects real content.
    private static func applyDocumentLayout(
        for hosting: NSHostingView<Content>,
        width: CGFloat
    ) -> CGFloat {
        let safeWidth = max(width, 1)
        let measured = measureDocumentHeight(for: hosting, width: safeWidth)
        let height = max(max(hosting.intrinsicContentSize.height, measured), 1)
        let target = CGRect(origin: .zero, size: CGSize(width: safeWidth, height: height))
        let frameUnchanged =
            abs(hosting.frame.width - target.width) < 0.5
            && abs(hosting.frame.height - target.height) < 0.5
        if !frameUnchanged {
            hosting.frame = target
            hosting.layoutSubtreeIfNeeded()
            hosting.invalidateIntrinsicContentSize()
        }
        return max(hosting.intrinsicContentSize.height, height, 1)
    }

    final class Coordinator {
        var hostingView: NSHostingView<Content>?
        var stickToBottomOnGrowth: Bool
        var lastScrollToken: Int = -1
        var lastThemeRevision: UInt = 0
        private var lastAppliedDocumentSize = NSSize.zero
        private var lastClipSize: NSSize = .zero
        private var refreshGeneration = 0
        private var followBottomGeneration = 0
        /// Set when clip bounds move away from the bottom; cleared when the user scrolls back down.
        var userHasScrolledAway = false
        private weak var trackedScrollView: NSScrollView?
        private var boundsObserver: NSObjectProtocol?

        init(stickToBottomOnGrowth: Bool) {
            self.stickToBottomOnGrowth = stickToBottomOnGrowth
        }

        deinit {
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
        }

        func installScrollTracking(on scrollView: NSScrollView) {
            guard trackedScrollView !== scrollView else { return }
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
            trackedScrollView = scrollView
            scrollView.contentView.postsBoundsChangedNotifications = true
            let clipView = scrollView.contentView
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self, weak scrollView] _ in
                guard let self, let scrollView else { return }
                if self.isNearBottom(in: scrollView) {
                    self.userHasScrolledAway = false
                } else {
                    self.userHasScrolledAway = true
                }
            }
        }

        func applyCanvasColor(_ color: Color, to hosting: NSHostingView<Content>) {
            hosting.layer?.backgroundColor = NSColor(color).cgColor
        }

        func isNearBottom(in scrollView: NSScrollView, threshold: CGFloat = openWriteScrollBottomPinThreshold) -> Bool {
            guard let documentView = scrollView.documentView else { return true }
            let clip = scrollView.contentView
            let maxY = max(0, documentView.frame.height - clip.bounds.height)
            if maxY <= threshold { return true }
            return clip.bounds.origin.y >= maxY - threshold
        }

        func scheduleScrollToBottomIfPinned(in scrollView: NSScrollView, wasNearBottom: Bool) {
            // Pin only when the user was already at the bottom and has not scrolled up to read history.
            guard wasNearBottom, !userHasScrolledAway else { return }
            followBottomGeneration += 1
            let generation = followBottomGeneration
            DispatchQueue.main.async { [weak self, weak scrollView] in
                guard let self, let scrollView, generation == self.followBottomGeneration else { return }
                self.refreshDocumentSize(in: scrollView)
                scrollView.openWriteScrollToBottom(animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak scrollView] in
                    guard let self, let scrollView, generation == self.followBottomGeneration else { return }
                    self.refreshDocumentSize(in: scrollView)
                    if self.isNearBottom(in: scrollView, threshold: openWriteScrollBottomPinThreshold * 2) {
                        scrollView.openWriteScrollToBottom(animated: false)
                    }
                }
            }
        }

        func invalidateDocumentMeasurement(in scrollView: NSScrollView) {
            lastClipSize = .zero
            lastAppliedDocumentSize = .zero
            (scrollView as? OpenWriteThemedScrollContainer)?.resetClipLayoutTracking()
        }

        /// Read-only probe; schedules deferred apply only when content height grew past last apply.
        func scheduleRefreshDocumentSizeIfContentGrew(in scrollView: NSScrollView) {
            guard let hosting = hostingView else { return }
            let clipWidth = max(scrollView.contentView.bounds.width, 1)
            let probeHeight = OpenWriteThemedScrollRepresentable.measureDocumentHeight(
                for: hosting,
                width: clipWidth
            )
            guard probeHeight > lastAppliedDocumentSize.height + 0.5 else { return }
            scheduleRefreshDocumentSize(in: scrollView)
        }

        /// Coalesces to one deferred refresh per run-loop turn (generation token drops stale work).
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
            // Deferred apply may use subtree layout; measure path stays read-only (see `measureDocumentHeight`).
            let height = OpenWriteThemedScrollRepresentable.applyDocumentLayout(
                for: hosting,
                width: width
            )

            // Exact content height — never clipHeight+1 or viewport fill; that creates a fake scroll range on empty chat.
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
            // Pin policy: `scheduleScrollToBottomIfPinned` runs only when `scrollToken` changes
            // (new message / pipeline step / stream end) — never on every deferred remeasure.
        }
    }
}
