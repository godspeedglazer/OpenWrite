import SwiftUI

struct WorkbenchInspectorView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @ObservedObject var workbench: WorkbenchState
    @ObservedObject var pastWrites: InMemoryPastWritesService

    var body: some View {
        VStack(spacing: 0) {
            Picker("Inspector", selection: $workbench.inspectorTab) {
                ForEach(InspectorTab.allCases) { tab in
                    Label {
                        Text(tab.title)
                    } icon: {
                        OWUnicodeIconView(icon: tab.owIcon, size: 12)
                    }
                    .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.vertical, DesignTokens.Spacing.spacing2)

            Divider()

            Group {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: DesignTokens.Layout.inspectorMaxWidth)
        .background(DesignTokens.Color.surface)
    }
}
