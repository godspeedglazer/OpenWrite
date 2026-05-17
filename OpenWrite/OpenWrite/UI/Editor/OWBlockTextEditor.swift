import AppKit
import SwiftUI

/// AppKit block field with theme-aware selection highlight and inline markdown WYSIWYG.
struct OWBlockTextEditor: NSViewRepresentable {
    @Binding var markdown: String
    @Binding var blockAttributes: [String: String]
    let blockID: UUID
    let baseSwiftUIFont: Font
    let textColor: Color
    let selectionHighlight: Color
    let selectionForeground: Color
    @ObservedObject var formatting: BlockFormattingState
    var onSelectionChange: ((NSRange?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> BlockTextContainerView {
        let container = BlockTextContainerView()
        let textView = BlockFormattingTextView()
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 2)
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
        if !context.coordinator.isProgrammaticUpdate {
            let current = InlineMarkdown.markdown(from: textView.textStorage ?? NSAttributedString())
            if current != markdown {
                context.coordinator.applyContent()
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: OWBlockTextEditor
        weak var textView: BlockFormattingTextView?
        var isProgrammaticUpdate = false

        init(parent: OWBlockTextEditor) {
            self.parent = parent
        }

        func applyContent() {
            guard let textView else { return }
            let family = InlineMarkdown.FontFamily(attribute: parent.blockAttributes["fontFamily"])
            let size = parent.blockAttributes["fontSize"].flatMap { Int($0) }.flatMap { $0 > 0 ? CGFloat($0) : nil }
            let parsed = InlineMarkdown.attributedString(
                from: parent.markdown,
                family: family,
                pointSize: size,
                textColor: NSColor(parent.textColor)
            )
            isProgrammaticUpdate = true
            textView.textStorage?.setAttributedString(parsed)
            isProgrammaticUpdate = false
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
            parent.markdown = InlineMarkdown.markdown(from: storage)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            parent.formatting.refreshSelectionState(textView)
            let range = textView.selectedRange()
            parent.onSelectionChange?(range.length > 0 ? range : nil)
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let textView else { return }
            parent.formatting.register(textView: textView, blockID: parent.blockID) { [weak self] markdown in
                self?.parent.markdown = markdown
            }
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView else { return }
            parent.formatting.resign(textView: textView)
        }
    }
}

// MARK: - AppKit views

final class BlockTextContainerView: NSView {
    weak var textView: BlockFormattingTextView?

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

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok {
            formattingCoordinator?.applySelectionChrome()
        }
        return ok
    }
}
