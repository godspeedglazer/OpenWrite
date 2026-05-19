import AppKit
import SwiftUI
import UniformTypeIdentifiers

// Paste: `onPasteCommand` on the field + `ChatComposerPasteBridge` for ⌘V when the field is focused.

// MARK: - Composer measurement

struct ChatComposerMeasuredHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Composer chrome

struct ChatComposerView: View {
    @ObservedObject var model: ChatPanelModel
    @Binding var measuredHeight: CGFloat

    @Environment(\.openWritePalette) private var palette
    @Environment(\.workbenchCenterLayout) private var workbenchLayout
    @EnvironmentObject private var aiServices: OpenWriteAIServices

    @State private var showFileImporter = false
    @FocusState private var composerFieldFocused: Bool

    private var usesHorizontalComposer: Bool {
        workbenchLayout.assistUsesHorizontalComposer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(palette.borderSubtle)
                .frame(height: DesignTokens.Layout.borderWidth)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                if let attachmentError = model.attachmentError {
                    Text(attachmentError)
                        .font(OWTypography.caption)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !model.pendingAttachments.isEmpty {
                    pendingAttachmentRow
                }

                composerInputStack
                composerModelCaption
            }
            .padding(DesignTokens.Spacing.assistStripComposerPadding)
            .padding(.bottom, DesignTokens.Layout.assistStripComposerBottomInset)
            .safeAreaPadding(.bottom, DesignTokens.Spacing.spacing1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .background(palette.background)
        .onPasteCommand(of: [.png, .tiff, .jpeg, .heic, .image]) { _ in
            guard ImagePasteSupport.shouldIngestImageFromPasteboard else { return }
            model.importImageFromPasteboard()
        }
        .background {
            ChatComposerPasteBridge(
                isActive: true,
                onPasteImage: { model.importImageFromPasteboard() }
            )
        }
        .onPasteCommand(of: [.png, .tiff, .image]) { _ in
            guard ImagePasteSupport.shouldIngestImageFromPasteboard else { return }
            model.importImageFromPasteboard()
        }
        .background {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ChatComposerMeasuredHeightKey.self,
                    value: geometry.size.height
                )
            }
        }
        .onPreferenceChange(ChatComposerMeasuredHeightKey.self) { height in
            guard height > 0, abs(height - measuredHeight) > 0.5 else { return }
            measuredHeight = height
        }
        .help("Paste images with ⌘V or attach files with the document button.")
    }

    private var composerModelCaption: some View {
        composerModelName
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(composerModelCaptionHelp)
    }

    private var composerModelName: some View {
        Text(aiServices.lmConfig.chatModelDisplay)
            .font(OWTypography.caption2)
            .foregroundStyle(DesignTokens.Color.textTertiary)
            .lineLimit(usesHorizontalComposer ? 1 : 2)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var composerModelCaptionHelp: String {
        let model = aiServices.lmConfig.chatModelDisplay
        let state = aiServices.lmConnectionState.statusPillLabel
        return """
        Chat model: \(model) (\(state)). \(aiServices.lmStatus). Configure in Settings → AI; \
        connection is verified with LM Studio GET /v1/models.
        """
    }

    @ViewBuilder
    private var composerInputStack: some View {
        if usesHorizontalComposer {
            HStack(alignment: .bottom, spacing: DesignTokens.Spacing.spacing2) {
                composerTextField(
                    placeholder: "Ask about your notes…",
                    minHeight: DesignTokens.Layout.composerBoardHeight
                )
                VStack(alignment: .trailing, spacing: DesignTokens.Spacing.spacing1) {
                    OWLMConnectionStatusPill(state: aiServices.lmConnectionState)
                    composerActionBoard
                }
            }
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.composerBoardSpacing) {
                composerTextField(
                    placeholder: "Ask…",
                    minHeight: DesignTokens.Layout.composerActionSize
                )
                HStack {
                    Spacer(minLength: 0)
                    OWLMConnectionStatusPill(state: aiServices.lmConnectionState)
                }
                composerActionBoard
            }
        }
    }

    private func composerTextField(placeholder: String, minHeight: CGFloat) -> some View {
        OWThemedComposerField(
            placeholder: placeholder,
            text: $model.draft,
            lineLimit: 1 ... 6,
            minHeight: minHeight,
            onSubmit: {
                if !model.isBusy {
                    model.send(services: aiServices, agent: aiServices.selectedAgent)
                }
            },
            isFocused: $composerFieldFocused
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
        .disabled(model.isBusy)
        .onPasteCommand(of: [.png, .tiff, .image]) { _ in
            guard ImagePasteSupport.shouldIngestImageFromPasteboard else { return }
            model.importImageFromPasteboard()
        }
    }

    /// 2×2 control board: Notes / Web on top; Attach + Send (or Stop) on bottom.
    private var composerActionBoard: some View {
        let gap = DesignTokens.Layout.composerBoardSpacing
        let iconSize = DesignTokens.Layout.composerBoardIconSize

        return VStack(spacing: gap) {
            HStack(spacing: gap) {
                OWThemedToggleButton(
                    label: "Search vault notes",
                    isOn: $model.searchVaultEnabled,
                    icon: .search,
                    showsLabel: false
                )
                .help("Search vault notes")

                OWThemedToggleButton(
                    label: "Fetch web pages",
                    isOn: $model.webLookupEnabled,
                    icon: .wiki,
                    showsLabel: false
                )
                .help("Fetch web pages")
            }

            HStack(spacing: gap) {
                Button {
                    showFileImporter = true
                } label: {
                    OWUnicodeIconView(
                        icon: .document,
                        size: iconSize,
                        color: DesignTokens.Color.textSecondary
                    )
                }
                .buttonStyle(OWComposerIconButtonStyle())
                .help("Attach file")
                .disabled(model.isBusy)
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: ChatAttachmentStore.allowedContentTypes,
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        model.importAttachments(from: urls)
                    case .failure(let error):
                        model.attachmentError = error.localizedDescription
                    }
                }

                if model.isBusy {
                    Button {
                        model.cancelSend(services: aiServices)
                    } label: {
                        OWUnicodeIconView(icon: .stop, size: iconSize, color: DesignTokens.Color.warning)
                    }
                    .buttonStyle(OWComposerStopButtonStyle())
                    .help("Stop generation")
                } else {
                    Button {
                        model.send(services: aiServices, agent: aiServices.selectedAgent)
                    } label: {
                        OWUnicodeIconView(
                            icon: .send,
                            size: iconSize,
                            color: DesignTokens.Color.selectionPill
                        )
                    }
                    .buttonStyle(OWComposerSendButtonStyle(isEnabled: canSendMessage))
                    .disabled(!canSendMessage)
                    .help("Send message")
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private var canSendMessage: Bool {
        AIInput.sanitizeQuery(model.draft) != nil || !model.pendingAttachments.isEmpty
    }

    private var pendingAttachmentRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.spacing1) {
                ForEach(model.pendingAttachments) { attachment in
                    HStack(spacing: 6) {
                        if attachment.kind == .image {
                            ChatAttachmentPreviewThumbnail(url: attachment.storedURL, size: 28)
                        } else {
                            OWUnicodeIconView(icon: .document, size: 12, color: DesignTokens.Color.textSecondary)
                        }
                        Text(attachment.displayName)
                            .font(OWTypography.caption)
                            .lineLimit(1)
                        Button {
                            model.removePendingAttachment(id: attachment.id)
                        } label: {
                            Text("×")
                                .font(OWTypography.captionEmphasis)
                        }
                        .buttonStyle(.plain)
                        .openWriteFocusChrome()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(DesignTokens.Color.surface.opacity(0.9), in: Capsule())
                }
            }
            .padding(.bottom, DesignTokens.Spacing.spacing1)
        }
    }
}

struct ChatAttachmentPreviewThumbnail: View {
    let url: URL
    var size: CGFloat = 16

    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            OWUnicodeIconView(icon: .document, size: 12, color: DesignTokens.Color.textSecondary)
        }
    }
}
