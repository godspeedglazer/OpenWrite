import SwiftUI

struct AgentPickerView: View {
    @Binding var selectedAgentID: String

    private var selection: AgentConfig {
        AgentRegistry.agent(id: selectedAgentID)
    }

    var body: some View {
        OWThemedDropdown(
            accessibilityLabel: "Agent",
            selection: $selectedAgentID,
            options: AgentRegistry.pickerAgents.map(\.id),
            optionTitle: { id in AgentRegistry.agent(id: id).name },
            minWidth: 120,
            compact: true,
            leadingIcon: .agent
        )
        .help(agentHelp(selection))
    }

    private func agentHelp(_ agent: AgentConfig) -> String {
        var parts = ["Retrieves up to \(agent.effectiveChunkLimit) chunks."]
        if agent.toolFlags.allowCreateNote {
            parts.append("Create-note tool enabled (confirmation required).")
        }
        if agent.toolFlags.passFullNoteContext {
            parts.append("Uses wider excerpts per chunk.")
        }
        return parts.joined(separator: " ")
    }
}
