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
                    Label(tab.title, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(10)

            Divider()

            Group {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 300, idealWidth: 340)
    }
}
