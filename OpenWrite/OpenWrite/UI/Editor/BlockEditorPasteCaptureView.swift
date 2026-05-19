import AppKit

/// Wraps a SwiftUI host and intercepts image paste for the block editor.
/// `NSView` (not `NSControl`) so hit-testing reaches SwiftUI checklist buttons and fields.
final class BlockEditorPasteCaptureView: NSView {
    var onPasteImage: (() -> Void)?
    var onAttachedToWindow: (() -> Void)?
    let hostedView: NSView

    private var cachedMeasureWidth: CGFloat = 0
    private var cachedMeasureHeight: CGFloat = 1
    /// Bumped by the paste host coordinator when block text/checkbox changes; measure cache is keyed on this.
    private(set) var cachedContentRevision: UInt64 = 0
    private var lastAppliedLayoutWidth: CGFloat = 0
    private var isApplyingLayout = false

    init(hostedView: NSView) {
        self.hostedView = hostedView
        super.init(frame: .zero)
        clipsToBounds = true
        layer?.masksToBounds = true
        openWriteSuppressFocusRing()
        hostedView.openWriteSuppressFocusRing()
        hostedView.clipsToBounds = true
        addSubview(hostedView)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Do not steal first responder from block fields / todo checkboxes (was causing scroll jumps).
    override var acceptsFirstResponder: Bool { false }

    /// Forward wheel events to the SwiftUI `ScrollView` ancestor when the block stack does not consume them.
    override func scrollWheel(with event: NSEvent) {
        if let scrollView = openWriteEnclosingEditorScrollView() {
            scrollView.scrollWheel(with: event)
            return
        }
        super.scrollWheel(with: event)
    }

    override func layout() {
        super.layout()
        guard bounds.width > 0 else { return }
        if hostedView.frame != bounds {
            hostedView.frame = bounds
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        onAttachedToWindow?()
    }

    var onDropImageFile: ((URL) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        ImagePasteSupport.canAcceptDrag(sender) ? .copy : []
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        ImagePasteSupport.canAcceptDrag(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let url = ImagePasteSupport.imageFileURL(from: sender) {
            onDropImageFile?(url)
            return true
        }
        if ImagePasteSupport.canAcceptDrag(sender), ImagePasteSupport.imageFromPasteboard() != nil {
            onPasteImage?()
            return true
        }
        return false
    }

    /// Clears width-keyed measure state only. Never zero `cachedMeasureHeight` — that collapses
    /// `intrinsicContentSize` to ~1pt, SwiftUI shrinks the host, measure returns full height, apply
    /// expands, and `invalidateIntrinsicContentSize` repeats (Welcome fork-bomb / 23GB RAM).
    func invalidateMeasurementCache(resetContentRevision: Bool = true) {
        cachedMeasureWidth = 0
        lastAppliedLayoutWidth = 0
        if resetContentRevision {
            cachedContentRevision = 0
        }
    }

    /// Read-only measure — width probe + `fittingSize` only; never forces subtree layout (AttributeGraph-safe).
    func measureDocumentSize(width: CGFloat, contentRevision: UInt64) -> CGSize {
        let safeWidth = max(width, 320)
        if abs(cachedMeasureWidth - safeWidth) < 0.5,
           cachedMeasureHeight >= 120,
           cachedContentRevision == contentRevision {
            return CGSize(width: safeWidth, height: cachedMeasureHeight)
        }
        let priorFrame = hostedView.frame
        let probeFrame = CGRect(x: 0, y: 0, width: safeWidth, height: max(priorFrame.height, bounds.height, 120))
        hostedView.frame = probeFrame
        let fitting = hostedView.fittingSize.height
        let intrinsic = hostedView.intrinsicContentSize.height
        hostedView.frame = priorFrame
        let contentHeight = max(floor(max(fitting, intrinsic, 120) + 0.5), 120)
        cachedMeasureWidth = safeWidth
        cachedMeasureHeight = contentHeight
        cachedContentRevision = contentRevision
        return CGSize(width: safeWidth, height: contentHeight)
    }

    /// Applies width + height on the next run loop turn only — `layoutSubtreeIfNeeded` is safe here,
    /// not in `measureDocumentSize` / SwiftUI `sizeThatFits` (AttributeGraph precondition / SIGABRT).
    func applyDocumentLayout(width: CGFloat, contentRevision: UInt64) {
        guard !isApplyingLayout else { return }
        let safeWidth = max(width, 320)
        if abs(lastAppliedLayoutWidth - safeWidth) < 0.5,
           abs(frame.width - safeWidth) < 0.5,
           abs(hostedView.frame.width - safeWidth) < 0.5,
           cachedMeasureHeight >= 120,
           abs(frame.height - cachedMeasureHeight) < 0.5,
           abs(hostedView.frame.height - cachedMeasureHeight) < 0.5 {
            return
        }

        isApplyingLayout = true
        defer { isApplyingLayout = false }

        if abs(hostedView.frame.width - safeWidth) > 0.5 {
            hostedView.frame.size.width = safeWidth
        }
        hostedView.layoutSubtreeIfNeeded()
        let fitting = hostedView.fittingSize.height
        let intrinsic = hostedView.intrinsicContentSize.height
        let contentHeight = max(floor(max(fitting, intrinsic, 120) + 0.5), 120)
        let target = CGSize(width: safeWidth, height: contentHeight)
        cachedMeasureWidth = safeWidth
        cachedMeasureHeight = contentHeight
        cachedContentRevision = contentRevision

        let frameUnchanged =
            abs(frame.width - target.width) < 0.5
            && abs(frame.height - target.height) < 0.5
            && abs(hostedView.frame.width - target.width) < 0.5
            && abs(hostedView.frame.height - target.height) < 0.5
        if frameUnchanged {
            lastAppliedLayoutWidth = safeWidth
            return
        }

        frame.size = NSSize(width: target.width, height: target.height)
        hostedView.frame = bounds
        lastAppliedLayoutWidth = safeWidth
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        let height = max(cachedMeasureHeight, 120)
        let width = cachedMeasureWidth > 0 ? cachedMeasureWidth : NSView.noIntrinsicMetric
        return NSSize(width: width, height: height)
    }

    @objc func paste(_ sender: Any?) {
        if ImagePasteSupport.pasteboardHasIngestibleImage {
            onPasteImage?()
            return
        }
        NSApp.sendAction(#selector(NSTextView.paste(_:)), to: nil, from: sender)
    }
}

private extension NSView {
    /// Walks up to the outer document scroll view (skips nested `NSTextView` scrollers).
    func openWriteEnclosingEditorScrollView() -> NSScrollView? {
        var candidate: NSScrollView?
        var view: NSView? = superview
        while let current = view {
            if let scroll = current as? NSScrollView, scroll.documentView != nil {
                if scroll.documentView is NSTextView {
                    view = scroll.superview
                    continue
                }
                candidate = scroll
            }
            view = current.superview
        }
        return candidate
    }
}
