import AppKit
import SwiftUI

// MARK: - Themed NSScroller

/// Thin overlay scroller tinted from the active `ThemePalette`.
final class OpenWriteThemedScroller: NSScroller {
    override class var isCompatibleWithOverlayScrollers: Bool { true }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        let palette = ThemeManager.shared.palette
        let track = NSColor(palette.editorCanvas).withAlphaComponent(0.38)
        track.setFill()
        let inset = slotRect.insetBy(dx: 2, dy: 5)
        NSBezierPath(roundedRect: inset, xRadius: 2.5, yRadius: 2.5).fill()
    }

    override func drawKnob() {
        let palette = ThemeManager.shared.palette
        let knob = NSColor(palette.accent).withAlphaComponent(0.48)
        knob.setFill()
        let rect = self.rect(for: .knob).insetBy(dx: 1, dy: 1)
        NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill()
    }
}

// MARK: - NSScrollView styling

extension NSScrollView {
    /// Applies OpenWrite overlay scrollers (accent thumb, canvas track).
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
                verticalScroller = scroller
            }
            verticalScroller?.needsDisplay = true
        }
        if horizontal {
            if !(horizontalScroller is OpenWriteThemedScroller) {
                let scroller = OpenWriteThemedScroller()
                scroller.scrollerStyle = .overlay
                horizontalScroller = scroller
            }
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
}

// MARK: - Scroll container (live resize + content growth)

/// NSScrollView that remeasures its hosting document whenever the clip view resizes.
private final class OpenWriteThemedScrollContainer: NSScrollView {
    var onClipViewLayout: (() -> Void)?

    override func layout() {
        super.layout()
        onClipViewLayout?()
    }
}

// MARK: - SwiftUI themed scroll

/// Theme-aware vertical scroll surface (NSScrollView + custom scroller).
struct OpenWriteThemedScrollView<Content: View>: View {
    private let axes: Axis.Set
    private let scrollToken: Int
    /// When true, a changed `scrollToken` scrolls to the bottom (chat). When false, remeasures only (editor).
    private let scrollToBottomOnTokenChange: Bool
    private let content: Content

    init(
        _ axes: Axis.Set = .vertical,
        scrollToken: Int = 0,
        scrollToBottomOnTokenChange: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.scrollToken = scrollToken
        self.scrollToBottomOnTokenChange = scrollToBottomOnTokenChange
        self.content = content()
    }

    var body: some View {
        OpenWriteThemedScrollRepresentable(
            axes: axes,
            scrollToken: scrollToken,
            scrollToBottomOnTokenChange: scrollToBottomOnTokenChange,
            content: content
        )
    }
}

private struct OpenWriteThemedScrollRepresentable<Content: View>: NSViewRepresentable {
    let axes: Axis.Set
    let scrollToken: Int
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
        if let layer = hosting.layer {
            layer.backgroundColor = NSColor(DesignTokens.Color.background).cgColor
        }
        context.coordinator.hostingView = hosting
        scrollView.documentView = hosting

        scrollView.onClipViewLayout = { [weak coordinator = context.coordinator, weak scrollView] in
            guard let coordinator, let scrollView else { return }
            coordinator.refreshDocumentSize(in: scrollView)
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
        hosting.rootView = content

        context.coordinator.refreshDocumentSize(in: scrollView)

        if context.coordinator.lastScrollToken != scrollToken {
            context.coordinator.lastScrollToken = scrollToken
            if scrollToBottomOnTokenChange {
                DispatchQueue.main.async {
                    scrollView.openWriteScrollToBottom(animated: true)
                }
            } else {
                context.coordinator.invalidateDocumentMeasurement()
                context.coordinator.refreshDocumentSize(in: scrollView)
            }
        }
    }

    private static func measureDocumentHeight(
        for hosting: NSHostingView<Content>,
        width: CGFloat,
        clipHeight: CGFloat
    ) -> CGFloat {
        let safeWidth = max(width, 1)
        // Measure with minimal height so lazy stacks and growing content are not clipped
        // to a previously assigned document frame (fixes assist-strip scroll softlock).
        hosting.frame = NSRect(x: 0, y: 0, width: safeWidth, height: 1)
        hosting.needsLayout = true
        hosting.layoutSubtreeIfNeeded()

        let measured = max(hosting.fittingSize.height, hosting.intrinsicContentSize.height)
        let minHeight = max(clipHeight + 1, 1)
        return max(measured, minHeight)
    }

    final class Coordinator {
        var hostingView: NSHostingView<Content>?
        var lastScrollToken: Int = -1
        private var lastClipSize: NSSize = .zero

        func invalidateDocumentMeasurement() {
            lastClipSize = .zero
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

            let sizeChanged =
                abs(hosting.frame.width - width) > 0.5
                || abs(hosting.frame.height - height) > 0.5
                || abs(lastClipSize.width - clipSize.width) > 0.5
                || abs(lastClipSize.height - clipSize.height) > 0.5

            guard sizeChanged else { return }

            lastClipSize = clipSize
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
            hosting.needsLayout = true
            hosting.layoutSubtreeIfNeeded()
            scrollView.tile()
        }
    }
}
