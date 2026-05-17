import Foundation
import Combine

@MainActor
final class WorkbenchState: ObservableObject {
    @Published var selectedSection: SidebarSection = .notes
    @Published var sidebarVisible: Bool = true

    init(selectedSection: SidebarSection = .notes) {
        self.selectedSection = selectedSection
    }
}
