import AppKit
import Foundation
import SwiftUI

/// Selection snapshot for inline refine; safe to pass across actors.
struct InlineSelectionSnapshot: Sendable, Equatable {
    let documentID: UUID
    let blockID: UUID?
    let selectedText: String
    let selectedRange: NSRange
}

enum InlineAssistPhase: Equatable {
    case idle
    case capturing
    case refining
    case ready(String, sourceHits: [RetrievalHit])
    case failed(String)

    var sourceHits: [RetrievalHit] {
        if case .ready(_, let hits) = self { return hits }
        return []
    }
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
    private var pendingBlockID: UUID?
    private var pendingFullText: String = ""
    private var pendingRange: NSRange?

    private static let assistQueue = DispatchQueue(
        label: "com.openwrite.inline-assist",
        qos: .userInitiated
    )

    func scheduleSelectionCapture(
        documentID: UUID,
        fullText: String,
        selectedRange: NSRange?,
        blockID: UUID? = nil
    ) {
        pendingDocumentID = documentID
        pendingBlockID = blockID
        pendingFullText = fullText
        pendingRange = selectedRange
        pendingSelectedText = nil
        scheduleDebouncedCapture()
    }

    /// Block-editor path: selection text is already extracted from the active field.
    func scheduleSelectionCapture(
        documentID: UUID,
        blockID: UUID?,
        selectedText: String?
    ) {
        pendingDocumentID = documentID
        pendingBlockID = blockID
        pendingFullText = ""
        pendingRange = nil
        pendingSelectedText = selectedText

        scheduleDebouncedCapture()
    }

    private var pendingSelectedText: String?

    private func scheduleDebouncedCapture() {
        debounceTask?.cancel()
        debounceTask = Task {
            let delay = UInt64(AISafetyLimits.inlineSelectionDebounceSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            applyPendingCapture()
        }
    }

    private func applyPendingCapture() {
        guard let documentID = pendingDocumentID else {
            latestSnapshot = nil
            if case .capturing = phase { phase = .idle }
            return
        }

        let selected: String?
        if let direct = pendingSelectedText?.trimmingCharacters(in: .whitespacesAndNewlines), !direct.isEmpty {
            selected = direct
        } else if let range = pendingRange,
                  range.length > 0,
                  NSMaxRange(range) <= (pendingFullText as NSString).length {
            selected = (pendingFullText as NSString).substring(with: range)
        } else {
            selected = nil
        }

        pendingSelectedText = nil

        guard var raw = selected, !raw.isEmpty else {
            latestSnapshot = nil
            if case .capturing = phase { phase = .idle }
            return
        }
        if raw.count > AISafetyLimits.maxInlineSelectionChars {
            raw = String(raw.prefix(AISafetyLimits.maxInlineSelectionChars))
        }
        guard let sanitized = AIInput.sanitizeQuery(raw) else {
            latestSnapshot = nil
            return
        }

        let range = pendingRange ?? NSRange(location: 0, length: (sanitized as NSString).length)
        latestSnapshot = InlineSelectionSnapshot(
            documentID: documentID,
            blockID: pendingBlockID,
            selectedText: sanitized,
            selectedRange: range
        )
        phase = .idle
    }

    /// Replaces the captured selection in `blocks` with refined prose and returns whether a block was updated.
    static func applyRefinement(
        _ refinedText: String,
        snapshot: InlineSelectionSnapshot,
        blocks: inout [NoteBlock],
        fallbackBlockID: UUID? = nil
    ) -> Bool {
        let trimmed = refinedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let targetID = snapshot.blockID ?? fallbackBlockID
        guard let blockID = targetID,
              let index = blocks.firstIndex(where: { $0.id == blockID }) else { return false }

        var blockText = blocks[index].text
        if let range = blockText.range(of: snapshot.selectedText) {
            blockText.replaceSubrange(range, with: trimmed)
        } else {
            blockText = trimmed
        }
        blocks[index].text = blockText
        return true
    }

    var canRefineSelection: Bool {
        latestSnapshot != nil && !isRefining
    }

    var canApplyRefinement: Bool {
        guard latestSnapshot != nil else { return false }
        if case .ready = phase { return true }
        return false
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
                    let display = AIInput.stripChunkReferences(answer.text)
                    phase = .ready(display, sourceHits: answer.hits)
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
    ) async throws -> RAGAnswer {
        try await withCheckedThrowingContinuation { continuation in
            Self.assistQueue.async {
                Task {
                    do {
                        let answer = try await rag.answer(query: query, agent: agent, attachments: [])
                        let trimmed = answer.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            continuation.resume(throwing: LMStudioError.emptyResponse)
                        } else {
                            continuation.resume(
                                returning: RAGAnswer(
                                    text: trimmed,
                                    citationChunkIDs: answer.citationChunkIDs,
                                    hits: answer.hits
                                )
                            )
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
    var selectionHighlight: Color = DesignTokens.Color.selectionHighlight
    var selectionForeground: Color = DesignTokens.Color.textPrimary
    var onSelectionChange: (NSRange?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.openWriteSuppressFocusRing()
        scrollView.openWriteApplyThemedScrollers(vertical: true, horizontal: false)
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
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(selectionHighlight),
            .foregroundColor: NSColor(selectionForeground)
        ]
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
        scrollView.openWriteRefreshThemedScrollers()
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let font = DesignTokens.Typography.editorNSFont
        if textView.font != font {
            textView.font = font
        }
        textView.defaultParagraphStyle = DesignTokens.Typography.editorParagraphStyle
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(selectionHighlight),
            .foregroundColor: NSColor(selectionForeground)
        ]
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
/// `NSView` (not `NSControl`) so hit-testing reaches SwiftUI checklist buttons and fields.
final class BlockEditorPasteCaptureView: NSView {
    var onPasteImage: (() -> Void)?
    let hostedView: NSView

    private var cachedMeasureWidth: CGFloat = 0
    private var cachedMeasureHeight: CGFloat = 1
    private var isApplyingLayout = false

    init(hostedView: NSView) {
        self.hostedView = hostedView
        super.init(frame: .zero)
        openWriteSuppressFocusRing()
        hostedView.openWriteSuppressFocusRing()
        addSubview(hostedView)
        registerForDraggedTypes([.fileURL, .tiff, .png])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

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

    func invalidateMeasurementCache() {
        cachedMeasureWidth = 0
        cachedMeasureHeight = 1
    }

    /// Read-only measure for SwiftUI `sizeThatFits` — width + `fittingSize` only; no subtree layout or intrinsic invalidation.
    func measureDocumentSize(width: CGFloat) -> CGSize {
        let safeWidth = max(width, 320)
        if abs(cachedMeasureWidth - safeWidth) < 0.5, cachedMeasureHeight > 0 {
            return CGSize(width: safeWidth, height: cachedMeasureHeight)
        }
        if abs(hostedView.frame.width - safeWidth) > 0.5 {
            hostedView.frame.size.width = safeWidth
        }
        let fitting = hostedView.fittingSize.height
        let intrinsic = hostedView.intrinsicContentSize.height
        let contentHeight = max(max(fitting, intrinsic), 1)
        return CGSize(width: safeWidth, height: contentHeight)
    }

    private func laidOutDocumentSize(width: CGFloat) -> CGSize {
        let safeWidth = max(width, 320)
        if abs(hostedView.frame.width - safeWidth) > 0.5 {
            hostedView.frame.size.width = safeWidth
        }
        hostedView.layoutSubtreeIfNeeded()
        let fitting = hostedView.fittingSize.height
        let intrinsic = hostedView.intrinsicContentSize.height
        let contentHeight = max(max(fitting, intrinsic), 1)
        cachedMeasureWidth = safeWidth
        cachedMeasureHeight = contentHeight
        return CGSize(width: safeWidth, height: contentHeight)
    }

    /// Applies width + height when width or hosted content changed; skips work when size is unchanged.
    func applyDocumentLayout(width: CGFloat) {
        guard !isApplyingLayout else { return }
        let safeWidth = max(width, 320)

        isApplyingLayout = true
        defer { isApplyingLayout = false }

        let target = laidOutDocumentSize(width: safeWidth)
        let frameUnchanged =
            abs(frame.width - target.width) < 0.5
            && abs(frame.height - target.height) < 0.5
            && abs(hostedView.frame.width - target.width) < 0.5
            && abs(hostedView.frame.height - target.height) < 0.5
        if frameUnchanged { return }

        hostedView.frame = CGRect(origin: .zero, size: target)
        frame.size = NSSize(width: target.width, height: target.height)
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        if cachedMeasureWidth > 0, cachedMeasureHeight > 0 {
            return NSSize(width: cachedMeasureWidth, height: cachedMeasureHeight)
        }
        let size = measureDocumentSize(width: max(bounds.width, 320))
        return NSSize(width: size.width, height: size.height)
    }

    override func layout() {
        super.layout()
        guard bounds.width > 1, !isApplyingLayout else { return }
        let safeWidth = bounds.width
        if abs(hostedView.frame.width - safeWidth) > 0.5 {
            hostedView.frame.size.width = safeWidth
        }
    }

    @objc func paste(_ sender: Any?) {
        if ImagePasteSupport.imageFromPasteboard() != nil {
            onPasteImage?()
            return
        }
        NSApp.sendAction(#selector(NSTextView.paste(_:)), to: nil, from: sender)
    }
}
