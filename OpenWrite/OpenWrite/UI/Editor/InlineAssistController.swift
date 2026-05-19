import AppKit
import Foundation
import SwiftUI

/// Quick-transform presets for selection refine (context menu + toolbar).
enum InlineRefinePreset: String, CaseIterable, Sendable {
    case improve
    case shorten
    case fixGrammar

    var menuTitle: String {
        switch self {
        case .improve: return "Improve selection"
        case .shorten: return "Shorten selection"
        case .fixGrammar: return "Fix grammar"
        }
    }

    fileprivate var instructionSuffix: String {
        switch self {
        case .improve:
            return "Improve clarity, flow, and word choice while preserving meaning and voice."
        case .shorten:
            return "Make the selection more concise. Remove redundancy; keep essential meaning."
        case .fixGrammar:
            return "Fix grammar, punctuation, and spelling only. Do not change meaning or tone."
        }
    }
}

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
/// Design: selection-only payload, explicit Refine invoke, popover + Apply (no auto-apply). See `docs/design/InlineAIEditing.md`.
///
/// Writing-core phase 2 (not here): Affine-style block store + slash menu; Anytype object/relations on blocks;
/// CRDT/collab; direct `NSTextView` range replace on Apply (today merges via `NoteBlock.text` string match).
@MainActor
final class InlineAssistController: ObservableObject {
    @Published private(set) var phase: InlineAssistPhase = .idle
    @Published private(set) var latestSnapshot: InlineSelectionSnapshot?
    @Published var showRefineResult = false
    @Published private(set) var refinePipelineSteps: [ChatPipelineStep] = []
    @Published private(set) var pendingActions: [OWAction] = []
    /// Live model output while refine streams (shown in the panel before `.ready`).
    @Published private(set) var streamingProse: String = ""

    private var debounceTask: Task<Void, Never>?
    private var refineTask: Task<Void, Never>?

    private static let refineStepOrder = ["selection", "vault", "model", "review"]
    /// Brief pacing so early stepper beats are visible (panel still opens immediately).
    private static let refinePacingStepDelayNs: UInt64 = 220_000_000

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

    /// Flushes debounced capture immediately (e.g. before context-menu refine).
    func commitPendingCapture() {
        debounceTask?.cancel()
        debounceTask = nil
        applyPendingCapture()
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
        if case .ready(let prose, _) = phase {
            return !prose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingActions.isEmpty
        }
        return false
    }

    var readyProse: String? {
        if case .ready(let text, _) = phase { return text }
        return nil
    }

    var isRefining: Bool {
        if case .refining = phase { return true }
        return false
    }

    var refineStatusCaption: String {
        switch phase {
        case .refining:
            return refineActiveStepTitle
        case .ready:
            return "Review the suggestion, then apply or dismiss."
        case .failed:
            return "Something went wrong — check LM Studio in Settings."
        default:
            return "Improve the highlighted passage with vault context."
        }
    }

    var refineActiveStepTitle: String {
        refinePipelineSteps.first(where: { $0.status == .active })?.title
            ?? refinePipelineSteps.last(where: { $0.status == .completed })?.title
            ?? "Working…"
    }

    private func seedRefinePipelinePending() {
        refinePipelineSteps = [
            ChatPipelineStep(id: "selection", title: "Reading selection", status: .pending),
            ChatPipelineStep(id: "vault", title: "Searching vault", status: .pending),
            ChatPipelineStep(id: "model", title: "Local model", status: .pending),
            ChatPipelineStep(id: "review", title: "Review & apply", status: .pending)
        ]
    }

    /// Opens the refine rail immediately; early steps animate via `playRefineOpeningBeat`.
    func beginRefineSession() {
        refineTask?.cancel()
        streamingProse = ""
        pendingActions = []
        phase = .refining
        showRefineResult = true
        seedRefinePipelinePending()
        setRefineSteps(upTo: "selection")
    }

    /// Enjoyable stepper pacing — selection then vault — without blocking panel open.
    private func playRefineOpeningBeat() async {
        setRefineSteps(upTo: "selection")
        try? await Task.sleep(nanoseconds: Self.refinePacingStepDelayNs)
        guard !Task.isCancelled else { return }
        setRefineStep("selection", status: .completed, title: "Selection captured")
        setRefineStep("vault", status: .active, title: "Searching vault")
        try? await Task.sleep(nanoseconds: Self.refinePacingStepDelayNs)
        guard !Task.isCancelled else { return }
        setRefineStep("vault", status: .completed, title: "Vault context")
        setRefineSteps(upTo: "model")
    }

    func setRefineModelStepTitle(_ title: String) {
        setRefineStep("model", status: .active, title: title)
    }

    private func setRefineStep(_ id: String, status: ChatPipelineStep.Status, title: String? = nil) {
        guard let index = refinePipelineSteps.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.32)) {
            refinePipelineSteps[index].status = status
            if let title { refinePipelineSteps[index].title = title }
        }
    }

    private func setRefineSteps(upTo activeID: String, completedBefore: Bool = true) {
        guard let activeIndex = Self.refineStepOrder.firstIndex(of: activeID) else { return }
        withAnimation(.easeInOut(duration: 0.32)) {
            for (index, stepID) in Self.refineStepOrder.enumerated() {
                guard let stepIndex = refinePipelineSteps.firstIndex(where: { $0.id == stepID }) else { continue }
                if index < activeIndex, completedBefore {
                    refinePipelineSteps[stepIndex].status = .completed
                } else if stepID == activeID {
                    refinePipelineSteps[stepIndex].status = .active
                } else if index > activeIndex {
                    refinePipelineSteps[stepIndex].status = .pending
                }
            }
        }
    }

    func refineSelection(
        using rag: RAGService,
        preset: InlineRefinePreset = .improve,
        noteExcerpt: String? = nil
    ) {
        guard latestSnapshot != nil else { return }
        if !isRefining {
            beginRefineSession()
        }

        let query = Self.refineQuery(
            for: latestSnapshot!.selectedText,
            preset: preset,
            noteExcerpt: noteExcerpt
        )
        let agent = BuiltInAgents.refineProse

        refineTask?.cancel()
        refineTask = Task {
            await playRefineOpeningBeat()
            guard !Task.isCancelled else { return }
            do {
                let answer = try await Self.runRefineStream(
                    rag: rag,
                    query: query,
                    agent: agent,
                    onToken: { [weak self] partial in
                        Task { @MainActor in
                            self?.streamingProse = partial
                            if partial.isEmpty == false {
                                self?.setRefineStep("model", status: .active, title: "Writing…")
                            }
                        }
                    },
                    onModelConnecting: { [weak self] in
                        Task { @MainActor in
                            self?.setRefineModelStepTitle("Connecting…")
                        }
                    }
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    streamingProse = ""
                    setRefineStep("model", status: .completed, title: "Draft ready")
                    setRefineStep("review", status: .active, title: "Review & apply")
                    let stripped = AIInput.stripChunkReferences(answer.text)
                    let parsed = OWActionScript.parse(in: stripped)
                    pendingActions = parsed.actions
                    let prose = parsed.proseWithoutScripts.isEmpty ? stripped : parsed.proseWithoutScripts
                    phase = .ready(prose, sourceHits: answer.hits)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    streamingProse = ""
                    setRefineStep("model", status: .failed, title: "Refine failed")
                    setRefineStep("review", status: .failed, title: "Unavailable")
                    phase = .failed(error.localizedDescription)
                }
            }
        }
    }

    func dismissRefine() {
        refineTask?.cancel()
        showRefineResult = false
        pendingActions = []
        streamingProse = ""
        if case .ready = phase {
            phase = .idle
        } else if case .failed = phase {
            phase = .idle
        } else if case .refining = phase {
            phase = .idle
        }
    }

    /// Opens the refine rail with a user-visible message (no selection, LM Studio offline, etc.).
    func presentRefineMessage(_ message: String) {
        refineTask?.cancel()
        beginRefineSession()
        refineTask = Task {
            await playRefineOpeningBeat()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                setRefineStep("model", status: .failed, title: "Unavailable")
                setRefineStep("review", status: .failed, title: "Cannot continue")
                streamingProse = ""
                phase = .failed(message)
            }
        }
    }

    private static func refineQuery(
        for selection: String,
        preset: InlineRefinePreset,
        noteExcerpt: String?
    ) -> String {
        var body = """
        Refine the following selected excerpt from my note. Return only the improved text. \
        Do not wrap in markdown fences unless the selection already uses them.
        Task: \(preset.instructionSuffix)

        --- SELECTION ---
        \(selection)
        --- END SELECTION ---

        \(OWActionScript.systemPromptAppendix())
        """
        if let excerpt = noteExcerpt?.trimmingCharacters(in: .whitespacesAndNewlines), !excerpt.isEmpty {
            body += """


            --- NOTE CONTEXT (for tone only; do not quote or summarize) ---
            \(excerpt)
            --- END NOTE CONTEXT ---
            """
        }
        return body
    }

    private static func runRefineStream(
        rag: RAGService,
        query: String,
        agent: AgentConfig,
        onToken: @escaping @Sendable (String) -> Void,
        onModelConnecting: @escaping @Sendable () -> Void
    ) async throws -> RAGAnswer {
        try await withCheckedThrowingContinuation { continuation in
            Self.assistQueue.async {
                Task {
                    do {
                        let context = try await rag.buildContext(
                            query: query,
                            agent: agent,
                            attachments: []
                        )
                        var fullText = ""
                        var citationIDs: [UUID] = []
                        var announcedConnecting = false

                        for try await event in rag.streamAnswer(context: context, agent: agent) {
                            switch event.kind {
                            case .activity(let state):
                                if state == .connecting, !announcedConnecting {
                                    announcedConnecting = true
                                    onModelConnecting()
                                }
                            case .token(let token):
                                fullText += token
                                onToken(fullText)
                            case .citations(let ids):
                                citationIDs = ids
                            case .error(let message):
                                throw LMStudioError.httpStatus(0, message)
                            case .completed:
                                break
                            }
                        }

                        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            continuation.resume(throwing: LMStudioError.emptyResponse)
                        } else {
                            continuation.resume(
                                returning: RAGAnswer(
                                    text: trimmed,
                                    citationChunkIDs: citationIDs,
                                    hits: context.allHits
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
            guard ImagePasteSupport.shouldIngestImageFromPasteboard,
                  let block = ImagePasteSupport.ingestPastedImage(),
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
