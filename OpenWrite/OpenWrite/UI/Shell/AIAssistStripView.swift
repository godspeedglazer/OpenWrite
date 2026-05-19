// Compact AI assist — Reor vault chat / related / past writes (secondary column).
// Layout: slim trailing strip (max 280pt), not a 50% Reor split. Patterns from reor-main (AGPL) studied clean-room.

import SwiftUI

private struct AIAssistStripWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = DesignTokens.Layout.assistStripDefaultWidth
}

extension EnvironmentValues {
    var aiAssistStripWidth: CGFloat {
        get { self[AIAssistStripWidthKey.self] }
        set { self[AIAssistStripWidthKey.self] = newValue }
    }
}

/// Bottom inset to reserve when the collapsed assist affordance bar is visible (editor column).
private struct WorkbenchAssistBottomBarInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var workbenchAssistBottomBarInset: CGFloat {
        get { self[WorkbenchAssistBottomBarInsetKey.self] }
        set { self[WorkbenchAssistBottomBarInsetKey.self] = newValue }
    }
}

extension View {
    /// Pads scrollable editor content so the collapsed assist bar does not cover the last blocks.
    func workbenchAssistBottomBarInset(active: Bool) -> some View {
        padding(.bottom, active ? DesignTokens.Layout.assistBottomBarHeight : 0)
    }

    /// Publishes bottom-bar height into the environment for nested editor surfaces.
    func workbenchAssistBottomBarEnvironment(active: Bool) -> some View {
        environment(
            \.workbenchAssistBottomBarInset,
            active ? DesignTokens.Layout.assistBottomBarHeight : 0
        )
    }
}

struct AIAssistStripView: View {
    @Environment(\.openWritePalette) private var palette
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @Environment(\.aiAssistStripWidth) private var assistColumnWidth
    @ObservedObject var workbench: WorkbenchState
    @ObservedObject var pastWrites: InMemoryPastWritesService
    let onCollapse: () -> Void

    private var navigation: AIAssistNavigationState { workbench.aiAssistNavigation }
    @Environment(\.workbenchCenterLayout) private var workbenchLayout

    private var stripIsCompact: Bool {
        !workbenchLayout.assistUsesHorizontalComposer
    }

    private var stripIconsOnly: Bool {
        workbenchLayout.assistColumnWidth < DesignTokens.Layout.assistStripIconsOnlyThreshold
    }

    var body: some View {
        VStack(spacing: 0) {
            assistToolbar

            Divider()

            stripContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.background)
        }
        .frame(
            maxWidth: assistColumnWidth > 0 ? assistColumnWidth : .infinity,
            maxHeight: .infinity
        )
        .clipped()
        .background(palette.surface)
        .aiAssistKeyboardBack(navigation)
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
                workbench: workbench,
                pastWrites: pastWrites,
                filterNoteID: vaultStore.selectedDocumentID
            )
        }
    }

    private var assistToolbar: some View {
        Group {
            if navigation.isAtRoot, !navigation.stripCanGoBack {
                OWAIPanelHeader(
                    title: "AI assist",
                    showsSeparator: false
                ) {
                    OWThemedSegmentedControl(
                        selection: $workbench.inspectorTab,
                        options: Array(InspectorTab.allCases),
                        title: \.title,
                        icon: \.owIcon,
                        iconsOnly: stripIconsOnly
                    )
                } trailing: {
                    assistToolbarTrailing
                }
            } else if navigation.isAtRoot,
                      navigation.chatPanelScreen == .conversation,
                      workbench.inspectorTab == .chat {
                OWAIPanelHeader(
                    title: "Ask vault",
                    canGoBack: navigation.stripCanGoBack,
                    backAccessibilityLabel: navigation.stripBackAccessibilityLabel,
                    onBack: { navigation.stripBack() },
                    showsSeparator: false,
                    center: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ask vault")
                                .font(OWTypography.calloutEmphasis)
                                .foregroundStyle(DesignTokens.Color.textPrimary)
                            AgentPickerView(selectedAgentID: $aiServices.selectedAgentID)
                        }
                    },
                    trailing: {
                        assistToolbarTrailing
                    }
                )
            } else {
                OWAIPanelHeader(
                    title: navigation.stripToolbarTitle,
                    canGoBack: navigation.stripCanGoBack,
                    backAccessibilityLabel: navigation.stripBackAccessibilityLabel,
                    onBack: { navigation.stripBack() },
                    showsSeparator: false
                ) {
                    assistToolbarTrailing
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing1)
    }

    @ViewBuilder
    private var assistToolbarTrailing: some View {
        HStack(spacing: DesignTokens.Spacing.spacing1) {
            if navigation.canGoForward {
                Button {
                    navigation.goForward()
                } label: {
                    OWUnicodeIconView(icon: .forward, size: 14)
                }
                .buttonStyle(.plain)
                .openWriteFocusChrome()
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .help("Forward")
            }
            Button(action: onCollapse) {
                OWUnicodeIconView(icon: .collapseTrailing, size: 12)
            }
            .buttonStyle(.plain)
            .openWriteFocusChrome()
            .foregroundStyle(DesignTokens.Color.textSecondary)
            .help("Collapse AI assist")
        }
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
                    OWUnicodeIconView(icon: .sparkles, size: 12, color: DesignTokens.Color.accent)
                    Text("AI assist")
                        .font(OWTypography.captionEmphasis)
                        .foregroundStyle(DesignTokens.Color.accent)
                    Text("· \(contextHint)")
                        .font(OWTypography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .openWriteFocusChrome()

            Spacer(minLength: DesignTokens.Spacing.spacing2)

            ForEach(InspectorTab.allCases) { tab in
                Button {
                    workbench.inspectorTab = tab
                    onExpand()
                } label: {
                    OWUnicodeIconView(icon: tab.owIcon, size: 12)
                        .foregroundStyle(
                            workbench.inspectorTab == tab
                                ? DesignTokens.Color.accent
                                : DesignTokens.Color.textTertiary
                        )
                }
                .buttonStyle(.plain)
                .openWriteFocusChrome()
                .help(tab.title)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing3)
        .frame(
            maxWidth: .infinity,
            minHeight: DesignTokens.Layout.assistBottomBarHeight,
            maxHeight: DesignTokens.Layout.assistBottomBarHeight,
            alignment: .center
        )
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
        .background(DesignTokens.Color.surfaceElevated)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignTokens.Color.borderSubtle)
                .frame(height: DesignTokens.Layout.borderWidth)
        }
        .accessibilityIdentifier("openwrite.assist.bottomBar")
    }

    private var contextHint: String {
        let nav = workbench.aiAssistNavigation
        if !nav.isAtRoot {
            return nav.toolbarTitle
        }
        if nav.chatPanelScreen == .conversation {
            return "Chat"
        }
        return "Chat · Related · Past Writes"
    }
}

// MARK: - Related detail

struct RelatedNoteDetailView: View {
    @Environment(\.openWritePalette) private var palette
    @EnvironmentObject private var vaultStore: VaultStore
    let hit: RetrievalHit

    var body: some View {
        OpenWriteThemedScrollView(canvasColor: palette.background) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
                Text(hit.documentTitle)
                    .font(OWTypography.calloutEmphasis)

                Text(String(format: "%.0f%% match", hit.score * 100))
                    .font(OWTypography.caption.monospacedDigit())
                    .foregroundStyle(DesignTokens.Color.textSecondary)

                Text(hit.snippet)
                    .font(OWTypography.callout)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .textSelection(.enabled)

                Button("Open in editor") {
                    vaultStore.selectedDocumentID = hit.documentID
                }
                .buttonStyle(OWAccentCapsuleButtonStyle())
            }
            .padding(DesignTokens.Spacing.assistStripContentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.background)
    }
}
