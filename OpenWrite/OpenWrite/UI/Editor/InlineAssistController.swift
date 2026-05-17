import AppKit
import Foundation
import SwiftUI

/// Selection snapshot for inline refine; safe to pass across actors.
struct InlineSelectionSnapshot: Sendable, Equatable {
    let documentID: UUID
    let selectedText: String
    let selectedRange: NSRange
}

enum InlineAssistPhase: Equatable {
    case idle
    case capturing
    case refining
    case ready(String)
    case failed(String)
}

/// Debounced selection capture and async refine via `RAGService` — never blocks the text view.
/// Design: selection-only payload, explicit Refine invoke, popover + Apply (no auto-apply). See `docs/design/InlineAIEditing.md` and `InlineAI-GoogleDocsResearch.md`.
@MainActor
final class InlineAssistController: ObservableObject {
    @Published private(set) var phase: InlineAssistPhase = .idle
    @Published private(set) var latestSnapshot: InlineSelectionSnapshot?
    @Published var showRefineResult = false

    private var debounceTask: Task<Void, Never>?
    private var refineTask: Task<Void, Never>?

    private var pendingDocumentID: UUID?
    private var pendingFullText: String = ""
    private var pendingRange: NSRange?

    private static let assistQueue = DispatchQueue(
        label: "com.openwrite.inline-assist",
        qos: .userInitiated
    )

    func scheduleSelectionCapture(
        documentID: UUID,
        fullText: String,
        selectedRange: NSRange?
    ) {
        pendingDocumentID = documentID
        pendingFullText = fullText
        pendingRange = selectedRange

        debounceTask?.cancel()
        debounceTask = Task {
            let delay = UInt64(AISafetyLimits.inlineSelectionDebounceSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            applyPendingCapture()
        }
    }

    private func applyPendingCapture() {
        guard let documentID = pendingDocumentID,
              let range = pendingRange,
              range.length > 0,
              NSMaxRange(range) <= (pendingFullText as NSString).length
        else {
            latestSnapshot = nil
            if case .capturing = phase { phase = .idle }
            return
        }

        let nsText = pendingFullText as NSString
        var selected = nsText.substring(with: range)
        if selected.count > AISafetyLimits.maxInlineSelectionChars {
            selected = String(selected.prefix(AISafetyLimits.maxInlineSelectionChars))
        }
        guard let sanitized = AIInput.sanitizeQuery(selected) else {
            latestSnapshot = nil
            return
        }

        latestSnapshot = InlineSelectionSnapshot(
            documentID: documentID,
            selectedText: sanitized,
            selectedRange: range
        )
        phase = .idle
    }

    var canRefineSelection: Bool {
        latestSnapshot != nil && !isRefining
    }

    var isRefining: Bool {
        if case .refining = phase { return true }
        return false
    }

    func refineSelection(using rag: RAGService) {
        guard let snapshot = latestSnapshot else { return }
        refineTask?.cancel()
        phase = .refining
        showRefineResult = true

        let query = Self.refineQuery(for: snapshot.selectedText)
        let agent = BuiltInAgents.refineProse

        refineTask = Task {
            do {
                let answer = try await Self.runRefine(
                    rag: rag,
                    query: query,
                    agent: agent
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    phase = .ready(answer)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    phase = .failed(error.localizedDescription)
                }
            }
        }
    }

    func dismissRefine() {
        refineTask?.cancel()
        showRefineResult = false
        if case .ready = phase {
            phase = .idle
        } else if case .failed = phase {
            phase = .idle
        }
    }

    private static func refineQuery(for selection: String) -> String {
        """
        Refine the following selected excerpt from my note. Return only the improved text. \
        Preserve meaning and voice. Do not wrap in markdown fences unless the selection already uses them.

        --- SELECTION ---
        \(selection)
        --- END SELECTION ---
        """
    }

    private static func runRefine(
        rag: RAGService,
        query: String,
        agent: AgentConfig
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            Self.assistQueue.async {
                Task {
                    do {
                        let answer = try await rag.answer(query: query, agent: agent)
                        let trimmed = answer.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            continuation.resume(throwing: LMStudioError.emptyResponse)
                        } else {
                            continuation.resume(returning: trimmed)
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

// MARK: - AppKit editor bridge (selection without blocking typing)

struct SelectablePlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onSelectionChange: (NSRange?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]

        let textView = PasteAwareTextView()
        textView.pasteCoordinator = context.coordinator
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.font = DesignTokens.Typography.editorNSFont
        textView.defaultParagraphStyle = DesignTokens.Typography.editorParagraphStyle
        textView.typingAttributes = DesignTokens.Typography.editorTypingAttributes
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.string = text
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let font = DesignTokens.Typography.editorNSFont
        if textView.font != font {
            textView.font = font
        }
        textView.defaultParagraphStyle = DesignTokens.Typography.editorParagraphStyle
        if textView.string != text {
            context.coordinator.isProgrammaticUpdate = true
            textView.string = text
            context.coordinator.isProgrammaticUpdate = false
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectablePlainTextEditor
        weak var textView: NSTextView?
        var isProgrammaticUpdate = false

        init(parent: SelectablePlainTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticUpdate, let textView else { return }
            parent.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            let range = textView.selectedRange()
            parent.onSelectionChange(range.length > 0 ? range : nil)
        }

        @discardableResult
        func insertPastedImageLine() -> Bool {
            guard let block = ImagePasteSupport.ingestPastedImage(),
                  let textView else { return false }
            insertLine(NDLSerializer.serializeBlock(block), in: textView)
            return true
        }

        private func insertLine(_ line: String, in textView: NSTextView) {
            let range = textView.selectedRange()
            let ns = textView.string as NSString
            let needsLeadingNewline = range.location > 0
                && ns.substring(with: NSRange(location: range.location - 1, length: 1)) != "\n"
            let insertion = (needsLeadingNewline ? "\n" : "") + line + "\n"
            let newText = ns.replacingCharacters(in: range, with: insertion)
            isProgrammaticUpdate = true
            textView.string = newText
            isProgrammaticUpdate = false
            parent.text = newText
            let newLocation = range.location + (insertion as NSString).length
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))
        }
    }
}

// MARK: - Paste-aware AppKit surfaces

final class PasteAwareTextView: NSTextView {
    weak var pasteCoordinator: SelectablePlainTextEditor.Coordinator?

    override func paste(_ sender: Any?) {
        if pasteCoordinator?.insertPastedImageLine() == true {
            return
        }
        super.paste(sender)
    }
}

/// Wraps a SwiftUI host and intercepts image paste for the block editor.
final class BlockEditorPasteCaptureView: NSControl {
    var onPasteImageBlock: ((NoteBlock) -> Void)?
    private let hostedView: NSView

    init(hostedView: NSView) {
        self.hostedView = hostedView
        super.init(frame: .zero)
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    @objc func paste(_ sender: Any?) {
        if let block = ImagePasteSupport.ingestPastedImage() {
            onPasteImageBlock?(block)
            return
        }
        NSApp.sendAction(#selector(NSTextView.paste(_:)), to: nil, from: sender)
    }
}
