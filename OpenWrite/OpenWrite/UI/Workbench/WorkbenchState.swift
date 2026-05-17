import Foundation
import Combine

@MainActor
final class WorkbenchState: ObservableObject {
    @Published var selectedSection: SidebarSection = .notes
    @Published var sidebarVisible: Bool = true
    /// Slim AI assist strip (≤280pt) — collapsed by default; writing-first layout.
    @Published var aiAssistExpanded: Bool = false
    @Published var centerTab: CenterWorkbenchTab = .editor
    @Published var inspectorTab: InspectorTab = .chat
    @Published var aiAssistNavigation = AIAssistNavigationState()
    /// Optional filter when an object-type row is chosen in the sidebar.
    @Published var vaultTypeFilter: PageType?

    init(selectedSection: SidebarSection = .notes) {
        self.selectedSection = selectedSection
    }

    func showGraph() {
        selectedSection = .graph
        centerTab = .graph
    }

    func showEditor() {
        selectedSection = .notes
        centerTab = .editor
    }

    func showDatabase(_ database: OWDatabase) {
        selectedSection = .notes
        centerTab = .database(database)
    }

    /// Legacy alias for toolbar toggles migrating to `aiAssistExpanded`.
    var inspectorVisible: Bool {
        get { aiAssistExpanded }
        set { aiAssistExpanded = newValue }
    }
}
