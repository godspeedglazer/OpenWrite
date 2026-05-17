import Foundation
import Combine

@MainActor
final class WorkbenchState: ObservableObject {
    @Published var selectedSection: SidebarSection = .notes
    @Published var sidebarVisible: Bool = true
    @Published var inspectorVisible: Bool = true
    @Published var inspectorTab: InspectorTab = .chat

    init(selectedSection: SidebarSection = .notes) {
        self.selectedSection = selectedSection
    }
}
