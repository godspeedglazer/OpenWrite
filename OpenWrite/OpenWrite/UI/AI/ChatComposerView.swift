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
    @Environment(\.agentsWorkbenchPresentation) private var agentsWorkbench
    @EnvironmentObject private var aiServices: OpenWriteAIServices

    @State private var showFileImporter = false
    @FocusState private var composerFieldFocused: Bool

    private var actionColumnWidth: CGFloat {
        DesignTokens.Layout.composerActionSize * 2 + DesignTokens.Layout.composerBoardSpacing
    }

    var body: some View {
        Group {
            if agentsWorkbench {
                agentsFloatingComposer
            } else {
                stripComposerChrome
            }
        }
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
        .help("Paste images with ⌘V. Web (globe) searches the internet for your question or fetches HTTPS links in the message.")
        .onDisappear {
            aiServices.voiceInput.stopListening()
        }
    }

    private var stripComposerChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(palette.borderSubtle)
                .frame(height: DesignTokens.Layout.borderWidth)

            composerCore
                .padding(DesignTokens.Spacing.assistStripComposerPadding)
                .padding(.bottom, DesignTokens.Layout.assistStripComposerBottomInset)
                .safeAreaPadding(.bottom, DesignTokens.Spacing.spacing1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background)
    }

    private var agentsFloatingComposer: some View {
        VStack(spacing: 0) {
            composerCore
                .padding(DesignTokens.Spacing.spacing3)
                .background(
                    palette.surface,
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                        .strokeBorder(palette.borderSubtle.opacity(0.85), lineWidth: DesignTokens.Layout.borderWidth)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6)
        }
        .frame(maxWidth: AgentsWorkbenchMetrics.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.spacing4)
        .padding(.bottom, DesignTokens.Spacing.spacing4)
        .safeAreaPadding(.bottom, DesignTokens.Spacing.spacing1)
        .background(Color.clear)
    }

    private var composerCore: some View {
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
        }
    }

    /// Wireframe layout: model status header · field (left) · send + 2×2 tools (right).
    private var composerInputStack: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            composerModelHeaderRow

            HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
                composerTextField(
                    placeholder: agentsWorkbench ? "Ask your agent…" : "Ask about your notes…",
                    minHeight: agentsWorkbench
                        ? DesignTokens.Layout.composerColumnHeight + 8
                        : DesignTokens.Layout.composerColumnHeight
                )
                composerActionColumn
            }
        }
    }

    private var composerModelHeaderRow: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.spacing2) {
            OWLMConnectionStatusPill(state: aiServices.lmConnectionState)

            Text(composerModelCaption)
                .font(OWTypography.caption2)
                .foregroundStyle(DesignTokens.Color.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var composerModelCaption: String {
        var parts = [aiServices.composerChatModelLabel]
        if model.searchVaultEnabled { parts.append("vault search") }
        if model.webLookupEnabled { parts.append("web") }
        return parts.joined(separator: " · ")
    }

    private var composerActionColumn: some View {
        let gap = DesignTokens.Layout.composerBoardSpacing

        return VStack(spacing: gap) {
            sendOrStopControl
                .frame(width: actionColumnWidth, height: DesignTokens.Layout.composerBoardHeight)

            composerActionGrid
        }
        .frame(width: actionColumnWidth, alignment: .top)
    }

    /// 2×2 board: Search · Web / Attach · Mic (our shapes, wireframe positions).
    private var composerActionGrid: some View {
        let gap = DesignTokens.Layout.composerBoardSpacing
        let iconSize = DesignTokens.Layout.composerBoardIconSize
        let cell = DesignTokens.Layout.composerActionSize

        return VStack(spacing: gap) {
            HStack(spacing: gap) {
                OWThemedToggleButton(
                    label: "Search vault notes",
                    isOn: $model.searchVaultEnabled,
                    icon: .search,
                    showsLabel: false
                )
                .frame(width: cell, height: cell)
                .help("Search vault notes")

                OWThemedToggleButton(
                    label: "Search the web",
                    isOn: $model.webLookupEnabled,
                    icon: .wiki,
                    showsLabel: false
                )
                .frame(width: cell, height: cell)
                .help("Search the web for your question, or fetch HTTPS links in the message.")
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
                .frame(width: cell, height: cell)
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

                Button {
                    aiServices.voiceInput.toggleListening(currentDraft: model.draft) { model.draft = $0 }
                } label: {
                    OWUnicodeIconView(
                        icon: aiServices.voiceInput.isListening ? .micActive : .mic,
                        size: iconSize,
                        color: aiServices.voiceInput.isListening
                            ? DesignTokens.Color.warning
                            : DesignTokens.Color.textSecondary
                    )
                }
                .buttonStyle(OWComposerIconButtonStyle())
                .frame(width: cell, height: cell)
                .help(aiServices.voiceInput.statusMessage ?? "Voice input")
                .disabled(model.isBusy || !aiServices.voiceInput.isAvailable)
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
        .help(composerFieldHelp)
    }

    private var composerFieldHelp: String {
        let model = aiServices.composerChatModelLabel
        let state = aiServices.lmConnectionState.statusPillLabel
        return "Chat model: \(model) (\(state)). \(aiServices.lmStatus)"
    }

    @ViewBuilder
    private var sendOrStopControl: some View {
        let iconSize = DesignTokens.Layout.composerBoardIconSize

        if model.isBusy {
            Button {
                model.cancelSend(services: aiServices)
            } label: {
                OWUnicodeIconView(icon: .stop, size: iconSize, color: DesignTokens.Color.warning)
            }
            .buttonStyle(OWComposerStopButtonStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .help("Stop generation")
        } else {
            Button {
                model.send(services: aiServices, agent: aiServices.selectedAgent)
            } label: {
                OWUnicodeIconView(
                    icon: .send,
                    size: iconSize + 2,
                    color: DesignTokens.Color.selectionPill
                )
            }
            .buttonStyle(OWComposerSendButtonStyle(isEnabled: canSendMessage))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .disabled(!canSendMessage)
            .help("Send (⌘↩)")
            .keyboardShortcut(.return, modifiers: [.command])
        }
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
