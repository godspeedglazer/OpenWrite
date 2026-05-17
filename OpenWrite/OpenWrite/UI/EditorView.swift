import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var pastWrites: InMemoryPastWritesService
    @EnvironmentObject private var aiServices: OpenWriteAIServices

    let documentID: UUID
    @State private var editingText: String = ""
    @State private var showRenderedPreview: Bool = false
    @State private var showProperties: Bool = false
    @State private var showTypePicker: Bool = false
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
                OWEmptyState(title: "Note missing", icon: .missingNote)
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
        .onChange(of: document?.updatedAt) { _, _ in
            guard !showRenderedPreview, let doc = self.document else { return }
            if doc.plainText != editingText {
                syncFromDocument(doc)
            }
        }
    }

    @ViewBuilder
    private func editorBody(_ document: VaultDocument) -> some View {
        VStack(spacing: 0) {
            pageBanner(document)

            if showTypePicker {
                editorTypePickerStrip(document)
            }

            editorActionBar(document)

            editorMain(document)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func pageBanner(_ document: VaultDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            OWPageBanner(
                title: document.displayTitle,
                icon: document.pageType.owIcon,
                pageType: document.pageType,
                showsGradient: true
            ) {
                metadataRow(document)
            }

            if showProperties {
                OWRoundedRect(style: .elevated, padding: DesignTokens.Spacing.spacing2) {
                    PropertyInspectorView(documentID: document.id)
                }
                .openWriteEditorContentWidth()
                .padding(.horizontal, DesignTokens.Spacing.spacing3)
                .padding(.bottom, DesignTokens.Spacing.spacing2)
            }
        }
    }

    private func metadataRow(_ document: VaultDocument) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.spacing2) {
                Button {
                    showTypePicker.toggle()
                } label: {
                    OWObjectTypeChip(pageType: document.pageType)
                }
                .buttonStyle(.plain)
                .help(showTypePicker ? "Hide type picker" : "Change page type")

                OWMetadataChip(
                    label: "Updated",
                    icon: .clock,
                    value: document.updatedAt.formatted(.relative(presentation: .named))
                )

                if let status = nonEmptyProperty(document, key: .status) {
                    OWMetadataChip(label: status, icon: .statusDot)
                }

                if let tags = nonEmptyProperty(document, key: .tags) {
                    OWMetadataChip(label: tags, icon: .tag)
                }

                Button {
                    showProperties.toggle()
                } label: {
                    OWMetadataChip(
                        label: showProperties ? "Hide properties" : "Properties",
                        icon: .sliders
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func editorTypePickerStrip(_ document: VaultDocument) -> some View {
        TypePickerView(documentID: document.id, mode: .switchType, layout: .compact)
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.bottom, DesignTokens.Spacing.spacing1)
    }

    private func editorActionBar(_: VaultDocument) -> some View {
        HStack(spacing: DesignTokens.Spacing.spacing3) {
            Spacer()

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
                    OWLabel(title: "Refine", icon: .sparkles)
                        .font(OWTypography.captionEmphasis)
                }
            }
            .disabled(!inlineAssist.canRefineSelection)
            .help("Improve selected text with local AI")
        }
        .openWriteEditorContentWidth()
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.spacing3)
        .padding(.vertical, DesignTokens.Spacing.spacing1)
    }

    @ViewBuilder
    private func editorMain(_ document: VaultDocument) -> some View {
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
            .font(OWTypography.body)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .openWriteEditorContentWidth()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.bottom, DesignTokens.Spacing.spacing3)
            .onChange(of: editingText) { _, newValue in
                commitEdit(document: document, plainText: newValue)
            }
        }
    }

    private func nonEmptyProperty(_ document: VaultDocument, key: PagePropertyKey) -> String? {
        let value = document.properties.string(for: key).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func syncFromDocument(_ document: VaultDocument?) {
        guard let document else { return }
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
                    OWEmptyState(
                        title: "Refine failed",
                        icon: .warning,
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
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                ForEach(document.rootBlocks.filter { $0.kind != .property }) { block in
                    OWPreviewBlockRow(block: block)
                }
            }
            .openWriteEditorContentWidth()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.bottom, DesignTokens.Spacing.spacing3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
