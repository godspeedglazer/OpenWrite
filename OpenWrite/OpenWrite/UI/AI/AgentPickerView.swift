import SwiftUI

struct AgentPickerView: View {
    @Binding var selectedAgentID: String

    private var selection: AgentConfig {
        AgentRegistry.agent(id: selectedAgentID)
    }

    var body: some View {
        Menu {
            ForEach(AgentRegistry.pickerAgents) { agent in
                Button {
                    selectedAgentID = agent.id
                } label: {
                    HStack {
                        Text(agent.name)
                        if agent.id == selectedAgentID {
                            Spacer()
                            OWIconView(icon: .checkmark, size: 12)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                OWIconView(icon: .agent, size: 14)
                Text(selection.name)
                    .lineLimit(1)
                OWIconView(icon: .chevronDown, size: 10)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
        }
        .menuStyle(.borderlessButton)
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
