import SwiftUI

struct AgentPickerView: View {
    @Binding var selectedAgentID: String

    private var selection: AgentConfig {
        BuiltInAgents.agent(id: selectedAgentID)
    }

    var body: some View {
        Menu {
            ForEach(BuiltInAgents.all) { agent in
                Button {
                    selectedAgentID = agent.id
                } label: {
                    if agent.id == selectedAgentID {
                        Label(agent.name, systemImage: "checkmark")
                    } else {
                        Text(agent.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.crop.circle")
                Text(selection.name)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
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
