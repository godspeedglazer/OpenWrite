import SwiftUI

// MARK: - Environment

private struct AgentsWorkbenchPresentationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when chat is hosted in the center Agents tab (not the sideline assist strip).
    var agentsWorkbenchPresentation: Bool {
        get { self[AgentsWorkbenchPresentationKey.self] }
        set { self[AgentsWorkbenchPresentationKey.self] = newValue }
    }
}

enum AgentsWorkbenchMetrics {
    static let contentMaxWidth: CGFloat = 720
    static let heroTopPadding: CGFloat = 72
}

// MARK: - View

/// Full-width agent workspace — Gemini / Cowork–style focus; no sideline assist duplication.
struct AgentsWorkbenchView: View {
    @Environment(\.openWritePalette) private var palette
    @EnvironmentObject private var workbench: WorkbenchState
    @EnvironmentObject private var aiServices: OpenWriteAIServices

    var body: some View {
        ZStack {
            agentsCanvas
            VStack(spacing: 0) {
                agentsTopChrome
                ChatPanelView(model: workbench.chatPanel)
                    .environment(\.agentsWorkbenchPresentation, true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(palette.background)
        .onAppear {
            workbench.inspectorTab = .chat
            workbench.aiAssistExpanded = false
            workbench.persistChromePreferences()
            workbench.aiAssistNavigation.openChatThread()
        }
    }

    private var agentsCanvas: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.38)
            RadialGradient(
                colors: [
                    DesignTokens.Color.accent.opacity(0.14),
                    DesignTokens.Color.accent.opacity(0.04),
                    palette.background.opacity(0)
                ],
                center: .center,
                startRadius: 24,
                endRadius: max(geometry.size.width, geometry.size.height) * 0.45
            )
            .position(center)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private var agentsTopChrome: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.spacing3) {
            Spacer(minLength: 0)
            VStack(spacing: DesignTokens.Spacing.spacing2) {
                AgentPickerView(selectedAgentID: $aiServices.selectedAgentID)
                Text(agentSubtitle)
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: AgentsWorkbenchMetrics.contentMaxWidth)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing4)
        .padding(.top, DesignTokens.Spacing.spacing3)
        .padding(.bottom, DesignTokens.Spacing.spacing2)
    }

    private var agentSubtitle: String {
        let agent = AgentRegistry.agent(id: aiServices.selectedAgentID)
        return agent.uiSummary
    }
}
