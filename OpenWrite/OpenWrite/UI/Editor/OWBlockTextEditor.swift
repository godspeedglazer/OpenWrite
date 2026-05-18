import AppKit
import SwiftUI

/// AppKit block field with theme-aware selection highlight and inline markdown WYSIWYG.
struct OWBlockTextEditor: NSViewRepresentable {
    @Binding var markdown: String
    @Binding var blockAttributes: [String: String]
    let blockID: UUID
    let baseSwiftUIFont: Font
    let basePointSize: CGFloat
    let textColor: Color
    let selectionHighlight: Color
    let selectionForeground: Color
    @ObservedObject var formatting: BlockFormattingState
    var strikethrough: Bool = false
    var onSelectionChange: ((String?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> BlockTextContainerView {
        let container = BlockTextContainerView()
        container.openWriteSuppressFocusRing()
        let textView = BlockFormattingTextView()
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 2, height: 2)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = context.coordinator
        textView.formattingCoordinator = context.coordinator

        container.textView = textView
        container.embed(textView)
        context.coordinator.textView = textView
        context.coordinator.applyContent()
        context.coordinator.applySelectionChrome()
        return container
    }

    func updateNSView(_ container: BlockTextContainerView, context: Context) {
        guard let textView = container.textView else { return }
        context.coordinator.parent = self
        context.coordinator.applySelectionChrome()
        let layoutWidth = container.bounds.width
        if layoutWidth > 1 {
            context.coordinator.layout(toWidth: layoutWidth)
        }
        guard !context.coordinator.isProgrammaticUpdate else { return }

        let attributesChanged = context.coordinator.lastAppliedAttributes != blockAttributes
        let strikethroughChanged = context.coordinator.lastAppliedStrikethrough != strikethrough
        let markdownEcho = markdown == context.coordinator.lastEmittedMarkdown
        if context.coordinator.isActivelyEditing(textView), !attributesChanged, !strikethroughChanged {
            return
        }
        if markdownEcho, !attributesChanged, !strikethroughChanged {
            return
        }
        if strikethroughChanged, !attributesChanged, markdownEcho {
            context.coordinator.applyStrikethroughOnly(strikethrough)
            return
        }

        let current = InlineMarkdown.markdown(from: textView.textStorage ?? NSAttributedString())
        if current != markdown || attributesChanged || strikethroughChanged {
            context.coordinator.applyContent(preserveSelection: context.coordinator.isActivelyEditing(textView))
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BlockTextContainerView, context: Context) -> CGSize? {
        guard let proposedWidth = proposal.width, proposedWidth.isFinite, proposedWidth > 0, proposedWidth < 4096 else {
            return nil
        }
        context.coordinator.layout(toWidth: proposedWidth)
        let height = nsView.intrinsicContentSize.height
        return CGSize(width: proposedWidth, height: height)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: OWBlockTextEditor
        weak var textView: BlockFormattingTextView?
        var isProgrammaticUpdate = false
        var lastEmittedMarkdown: String = ""
        private var lastLayoutWidth: CGFloat = 0
        private var lastLayoutHeight: CGFloat = 24
        var lastAppliedAttributes: [String: String] = [:]
        var lastAppliedStrikethrough = false

        init(parent: OWBlockTextEditor) {
            self.parent = parent
            self.lastEmittedMarkdown = parent.markdown
        }

        func isActivelyEditing(_ textView: NSTextView) -> Bool {
            guard let window = textView.window else { return false }
            if window.firstResponder === textView { return true }
            if let fieldEditor = window.fieldEditor(false, for: textView) as? NSTextView,
               fieldEditor.delegate === textView.delegate {
                return true
            }
            return false
        }

        func layout(toWidth width: CGFloat) {
            guard let textView, let container = textView.textContainer else { return }
            let safeWidth = max(width, 1)
            if abs(textView.frame.width - safeWidth) > 0.5 {
                textView.frame.size.width = safeWidth
            }
            container.containerSize = NSSize(width: safeWidth, height: .greatestFiniteMagnitude)
            textView.layoutManager?.ensureLayout(for: container)
            var used = textView.layoutManager?.usedRect(for: container) ?? .zero
            let insetY = textView.textContainerInset.height * 2
            let tightContainerHeight = max(ceil(used.height) + insetY, 24)
            if abs(container.containerSize.height - tightContainerHeight) > 0.5 {
                container.containerSize = NSSize(width: safeWidth, height: tightContainerHeight)
                textView.layoutManager?.ensureLayout(for: container)
                used = textView.layoutManager?.usedRect(for: container) ?? used
            }
            let newHeight = max(ceil(used.height) + insetY, 24)
            let widthChanged = abs(lastLayoutWidth - safeWidth) > 0.5
            let heightChanged = abs(lastLayoutHeight - newHeight) > 0.5
            lastLayoutWidth = safeWidth
            lastLayoutHeight = newHeight
            guard widthChanged || heightChanged else { return }
            textView.invalidateIntrinsicContentSize()
            textView.superview?.invalidateIntrinsicContentSize()
        }

        func applyStrikethroughOnly(_ enabled: Bool) {
            guard let textView, let storage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)
            guard fullRange.length > 0 else {
                lastAppliedStrikethrough = enabled
                return
            }
            isProgrammaticUpdate = true
            if enabled {
                storage.addAttribute(
                    .strikethroughStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: fullRange
                )
            } else {
                storage.removeAttribute(.strikethroughStyle, range: fullRange)
            }
            isProgrammaticUpdate = false
            lastAppliedStrikethrough = enabled
        }

        func applyContent(preserveSelection: Bool = false) {
            guard let textView else { return }
            let selection = preserveSelection ? textView.selectedRange() : NSRange(location: 0, length: 0)
            let family = InlineMarkdown.FontFamily(attribute: parent.blockAttributes["fontFamily"])
            let size = resolvedPointSize()
            let parsed = InlineMarkdown.attributedString(
                from: parent.markdown,
                family: family,
                pointSize: size,
                textColor: NSColor(parent.textColor)
            )
            isProgrammaticUpdate = true
            let storage = NSMutableAttributedString(attributedString: parsed)
            if parent.strikethrough, storage.length > 0 {
                storage.addAttribute(
                    .strikethroughStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: NSRange(location: 0, length: storage.length)
                )
            }
            textView.textStorage?.setAttributedString(storage)
            if preserveSelection {
                let length = (textView.string as NSString).length
                if length > 0 {
                    let safeLocation = min(selection.location, max(length - 1, 0))
                    let safeLength = min(selection.length, length - safeLocation)
                    textView.setSelectedRange(NSRange(location: safeLocation, length: safeLength))
                }
            }
            isProgrammaticUpdate = false
            lastEmittedMarkdown = parent.markdown
            lastAppliedAttributes = parent.blockAttributes
            lastAppliedStrikethrough = parent.strikethrough
            layout(toWidth: textView.frame.width > 1 ? textView.frame.width : textView.bounds.width)
        }

        func applySelectionChrome() {
            guard let textView else { return }
            textView.selectedTextAttributes = [
                .backgroundColor: NSColor(parent.selectionHighlight),
                .foregroundColor: NSColor(parent.selectionForeground)
            ]
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate, let textView, let storage = textView.textStorage else { return }
            let emitted = InlineMarkdown.markdown(from: storage)
            lastEmittedMarkdown = emitted
            parent.markdown = emitted
            layout(toWidth: textView.frame.width > 1 ? textView.frame.width : textView.bounds.width)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            parent.formatting.refreshSelectionState(textView)
            let range = textView.selectedRange()
            guard range.length > 0 else {
                parent.onSelectionChange?(nil)
                return
            }
            let ns = textView.string as NSString
            guard NSMaxRange(range) <= ns.length else {
                parent.onSelectionChange?(nil)
                return
            }
            parent.onSelectionChange?(ns.substring(with: range))
        }

        func registerWithFormattingState() {
            guard let textView else { return }
            parent.formatting.register(textView: textView, blockID: parent.blockID) { [weak self] markdown in
                self?.lastEmittedMarkdown = markdown
                self?.parent.markdown = markdown
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            registerWithFormattingState()
        }

        private func resolvedPointSize() -> CGFloat {
            if let raw = parent.blockAttributes["fontSize"], let parsed = Int(raw), parsed > 0 {
                return CGFloat(parsed)
            }
            return parent.basePointSize
        }
    }
}

// MARK: - AppKit views

final class BlockTextContainerView: NSView {
    weak var textView: BlockFormattingTextView?

    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func embed(_ textView: BlockFormattingTextView) {
        addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override var intrinsicContentSize: NSSize {
        guard let textView else { return NSSize(width: NSView.noIntrinsicMetric, height: 24) }
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let used = textView.layoutManager?.usedRect(for: textView.textContainer!) ?? .zero
        return NSSize(width: NSView.noIntrinsicMetric, height: max(used.height + 6, 24))
    }
}

final class BlockFormattingTextView: NSTextView {
    weak var formattingCoordinator: OWBlockTextEditor.Coordinator?

    override var isOpaque: Bool { false }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok {
            formattingCoordinator?.applySelectionChrome()
            formattingCoordinator?.registerWithFormattingState()
        }
        return ok
    }
}
