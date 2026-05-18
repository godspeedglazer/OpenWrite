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

// MARK: - SwiftUI themed scroll

/// Theme-aware vertical scroll surface (NSScrollView + custom scroller).
struct OpenWriteThemedScrollView<Content: View>: View {
    private let axes: Axis.Set
    private let scrollToken: Int
    private let content: Content

    init(
        _ axes: Axis.Set = .vertical,
        scrollToken: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.axes = axes
        self.scrollToken = scrollToken
        self.content = content()
    }

    var body: some View {
        OpenWriteThemedScrollRepresentable(
            axes: axes,
            scrollToken: scrollToken,
            content: content
        )
    }
}

private struct OpenWriteThemedScrollRepresentable<Content: View>: NSViewRepresentable {
    let axes: Axis.Set
    let scrollToken: Int
    let content: Content

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.openWriteApplyThemedScrollers(
            vertical: axes.contains(.vertical),
            horizontal: axes.contains(.horizontal)
        )
        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.sizingOptions = [.intrinsicContentSize]
        context.coordinator.hostingView = hosting
        scrollView.documentView = hosting
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        scrollView.openWriteApplyThemedScrollers(
            vertical: axes.contains(.vertical),
            horizontal: axes.contains(.horizontal)
        )
        scrollView.openWriteRefreshThemedScrollers()

        guard let hosting = context.coordinator.hostingView else { return }
        hosting.rootView = content

        let width = max(scrollView.bounds.width, 1)
        let height = Self.documentHeight(for: hosting, width: width, minHeight: scrollView.bounds.height + 1)
        if abs(hosting.frame.width - width) > 0.5 || abs(hosting.frame.height - height) > 0.5 {
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
            hosting.needsLayout = true
            hosting.layoutSubtreeIfNeeded()
        }

        if context.coordinator.lastScrollToken != scrollToken {
            context.coordinator.lastScrollToken = scrollToken
            DispatchQueue.main.async {
                scrollView.openWriteScrollToBottom(animated: true)
            }
        }
    }

    private static func documentHeight(
        for hosting: NSHostingView<Content>,
        width: CGFloat,
        minHeight: CGFloat
    ) -> CGFloat {
        hosting.frame.size.width = width
        hosting.layoutSubtreeIfNeeded()
        let measured = max(hosting.fittingSize.height, hosting.intrinsicContentSize.height)
        return max(measured, minHeight)
    }

    final class Coordinator {
        var hostingView: NSHostingView<Content>?
        var lastScrollToken: Int = -1
    }
}
