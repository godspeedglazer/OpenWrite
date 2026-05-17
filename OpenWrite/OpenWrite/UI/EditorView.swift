import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var pastWrites: InMemoryPastWritesService
    @EnvironmentObject private var aiServices: OpenWriteAIServices

    let documentID: UUID
    @State private var editingText: String = ""
    @State private var showRenderedPreview: Bool = false
    @StateObject private var inlineAssist = InlineAssistController()
    init(document: VaultDocument) {
        self.documentID = document.id
    }

    init(documentID: UUID) {
        self.documentID = documentID
    }

    private var document: VaultDocument? {
        vaultStore.documents.first { $0.id == documentID }
    }

    var body: some View {
        Group {
            if let document {
                editorBody(document)
            } else {
                ContentUnavailableView("Note missing", systemImage: "doc.questionmark")
            }
        }
        .navigationTitle(document?.displayTitle ?? "Note")
    }

    @ViewBuilder
    private func editorBody(_ document: VaultDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    PageTypeBadge(pageType: document.pageType)
                    Spacer()
                    Text(document.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Preview", isOn: $showRenderedPreview)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    Button {
                        inlineAssist.refineSelection(using: aiServices.rag)
                    } label: {
                        if inlineAssist.isRefining {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Refine selection", systemImage: "sparkles")
                        }
                    }
                    .disabled(!inlineAssist.canRefineSelection)
                    .help("Improve selected text with local AI (does not block typing)")
                }

                Text(document.displayTitle)
                    .font(.largeTitle.bold())

                TypePickerView(documentID: document.id, mode: .switchType)

                PropertyInspectorView(documentID: document.id)
                    .padding(12)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)

            if showRenderedPreview {
                renderedPreview(document)
            } else {
                SelectablePlainTextEditor(text: $editingText) { range in
                    inlineAssist.scheduleSelectionCapture(
                        documentID: document.id,
                        fullText: editingText,
                        selectedRange: range
                    )
                }
                .padding(12)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .onChange(of: editingText) { _, newValue in
                    commitEdit(document: document, plainText: newValue)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $inlineAssist.showRefineResult) {
            refineResultSheet
        }
        .onAppear { syncFromDocument(document) }
        .onChange(of: documentID) { _, _ in
            if let doc = self.document { syncFromDocument(doc) }
        }
        .onChange(of: document.updatedAt) { _, _ in
            guard !showRenderedPreview, let doc = self.document else { return }
            if doc.plainText != editingText {
                syncFromDocument(doc)
            }
        }
    }

    private func syncFromDocument(_ document: VaultDocument) {
        editingText = document.plainText
    }

    @ViewBuilder
    private var refineResultSheet: some View {
        NavigationStack {
            Group {
                switch inlineAssist.phase {
                case .refining:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Refining selection…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .ready(let text):
                    ScrollView {
                        Text(text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                case .failed(let message):
                    ContentUnavailableView(
                        "Refine failed",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                default:
                    Text("No result")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Refine selection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { inlineAssist.dismissRefine() }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 280)
    }

    private func commitEdit(document: VaultDocument, plainText: String) {
        vaultStore.updatePlainText(for: document.id, plainText: plainText)
        pastWrites.recordEdit(
            noteID: document.id,
            noteTitle: document.displayTitle,
            plainText: plainText
        )
    }

    private func renderedPreview(_ document: VaultDocument) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(document.rootBlocks.filter { $0.kind != .property }) { block in
                    blockView(block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }

    @ViewBuilder
    private func blockView(_ block: NoteBlock) -> some View {
        switch block.kind {
        case .heading1:
            Text(block.text).font(.title)
        case .heading2:
            Text(block.text).font(.title2)
        case .heading3:
            Text(block.text).font(.title3)
        case .bullet:
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                Text(block.text)
            }
        case .quote:
            Text(block.text)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 3)
                }
        case .code:
            Text(block.text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        case .divider:
            Divider()
        case .wikilink:
            Text(block.text)
                .foregroundStyle(.tint)
        case .property:
            HStack(spacing: 6) {
                Text(block.propertyKey?.displayName ?? block.text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(block.propertyValuePayload)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        case .paragraph:
            Text(block.text)
        }
    }
}

struct PageTypeBadge: View {
    let pageType: PageType

    var body: some View {
        Label(pageType.displayName, systemImage: pageType.systemImage)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch pageType {
        case .note: return .blue
        case .task: return .orange
        case .reference: return .purple
        case .journal: return .green
        case .project: return .indigo
        case .book: return .brown
        case .document: return .teal
        case .wikiSite: return .cyan
        case .collection: return .gray
        }
    }
}
