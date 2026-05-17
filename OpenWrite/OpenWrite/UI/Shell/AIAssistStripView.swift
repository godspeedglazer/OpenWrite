// Compact AI assist — Reor vault chat / related / past writes (secondary column).
// Layout: slim trailing strip (max 280pt), not a 50% Reor split. Patterns from reor-main (AGPL) studied clean-room.

import SwiftUI

struct AIAssistStripView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @ObservedObject var workbench: WorkbenchState
    @ObservedObject var pastWrites: InMemoryPastWritesService
    let onCollapse: () -> Void

    private var navigation: AIAssistNavigationState { workbench.aiAssistNavigation }

    var body: some View {
        VStack(spacing: 0) {
            assistToolbar

            Divider()

            stripContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            minWidth: DesignTokens.Layout.inspectorMinWidth,
            maxWidth: DesignTokens.Layout.assistStripMaxWidth
        )
        .background(DesignTokens.Color.surfaceElevated)
    }

    @ViewBuilder
    private var stripContent: some View {
        switch navigation.current {
        case .root:
            rootTabContent
        case .chatThread:
            ChatPanelView()
        case .relatedDetail(let hit):
            RelatedNoteDetailView(hit: hit)
        }
    }

    @ViewBuilder
    private var rootTabContent: some View {
        switch workbench.inspectorTab {
        case .chat:
            ChatPanelView()
        case .related:
            RelatedNotesView()
        case .pastWrites:
            PastWritesTimelineView(
                pastWrites: pastWrites,
                filterNoteID: vaultStore.selectedDocumentID
            )
        }
    }

    private var assistToolbar: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            if navigation.canGoBack {
                assistNavButton(icon: .back, help: "Back") {
                    navigation.backFromToolbar()
                }
            } else {
                OWIconView(icon: .sparkles, size: 14, color: DesignTokens.Color.accent)
            }

            if navigation.isAtRoot {
                Picker("Assist", selection: $workbench.inspectorTab) {
                    ForEach(InspectorTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            } else {
                Text(navigation.toolbarTitle)
                    .font(DesignTokens.Typography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if navigation.canGoForward {
                assistNavButton(icon: .forward, help: "Forward") {
                    navigation.goForward()
                }
            }

            Button(action: onCollapse) {
                OWIconView(icon: .chevronRight, size: 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignTokens.Color.textSecondary)
            .help("Collapse AI assist")
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .padding(.vertical, DesignTokens.Spacing.spacing2)
    }

    private func assistNavButton(icon: OWIcon, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            OWIconView(icon: icon, size: 14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(DesignTokens.Color.textSecondary)
        .help(help)
    }
}

/// Collapsed affordance along the bottom of the center column.
struct AIAssistBottomBar: View {
    @ObservedObject var workbench: WorkbenchState
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            Button(action: onExpand) {
                HStack(spacing: DesignTokens.Spacing.spacing1) {
                    OWIconView(icon: .sparkles, size: 12, color: DesignTokens.Color.accent)
                    Text("AI assist")
                        .font(DesignTokens.Typography.captionEmphasis)
                        .foregroundStyle(DesignTokens.Color.accent)
                    Text("· \(contextHint)")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: DesignTokens.Spacing.spacing2)

            ForEach(InspectorTab.allCases) { tab in
                Button {
                    workbench.inspectorTab = tab
                    onExpand()
                } label: {
                    OWIconView(icon: tab.owIcon, size: 12)
                        .foregroundStyle(
                            workbench.inspectorTab == tab
                                ? DesignTokens.Color.accent
                                : DesignTokens.Color.textTertiary
                        )
                }
                .buttonStyle(.plain)
                .help(tab.title)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing3)
        .frame(height: DesignTokens.Layout.assistBottomBarHeight)
        .background(DesignTokens.Color.surfaceElevated.opacity(0.92))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignTokens.Color.borderSubtle)
                .frame(height: DesignTokens.Layout.borderWidth)
        }
    }

    private var contextHint: String {
        let nav = workbench.aiAssistNavigation
        if !nav.isAtRoot {
            return nav.toolbarTitle
        }
        return "Chat · Related · Past Writes"
    }
}

// MARK: - Related detail

struct RelatedNoteDetailView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    let hit: RetrievalHit

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
                Text(hit.documentTitle)
                    .font(DesignTokens.Typography.callout.weight(.semibold))

                Text(String(format: "%.0f%% match", hit.score * 100))
                    .font(DesignTokens.Typography.caption.monospacedDigit())
                    .foregroundStyle(DesignTokens.Color.textSecondary)

                Text(hit.snippet)
                    .font(DesignTokens.Typography.callout)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .textSelection(.enabled)

                Text("chunk:\(hit.id.uuidString)")
                    .font(DesignTokens.Typography.caption.monospaced())
                    .foregroundStyle(DesignTokens.Color.textTertiary)

                Button("Open in editor") {
                    vaultStore.selectedDocumentID = hit.documentID
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(DesignTokens.Spacing.spacing3)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
