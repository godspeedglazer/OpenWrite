import Foundation
import Combine

@MainActor
final class WorkbenchState: ObservableObject {
    @Published var selectedSection: SidebarSection = .notes
    @Published var sidebarVisible: Bool = ShellChromePreferences.sidebarVisible
    /// Slim AI assist strip (≤280pt) — collapsed by default; writing-first layout.
    @Published var aiAssistExpanded: Bool = ShellChromePreferences.assistStripExpanded
    /// Icon-only navigation rail (~48pt) when true.
    @Published var navigationRailCollapsed: Bool = ShellChromePreferences.navigationRailCollapsed
    @Published var centerTab: CenterWorkbenchTab = .editor
    @Published var inspectorTab: InspectorTab = .chat
    @Published var aiAssistNavigation = AIAssistNavigationState()
    /// Set by Past chat list; consumed by `ChatPanelView` to restore an archived thread.
    @Published var archivedChatThreadIDToOpen: UUID?
    /// Optional filter when an object-type row is chosen in the sidebar (scoped per vault).
    @Published var vaultTypeFilter: PageType?
    @Published private(set) var editorFocusMode = false
    /// Bump to force graph canvas relayout after structural note changes.
    @Published var graphRefreshToken: Int = 0
    /// Set from chat when the user taps Apply on parsed `ow` actions; consumed by `EditorView`.
    @Published var chatOWActionsApplyToken: UUID?
    @Published var chatOWActionsToApply: [OWAction] = []

    func requestApplyChatOWActions(_ actions: [OWAction]) {
        guard !actions.isEmpty else { return }
        chatOWActionsToApply = actions
        chatOWActionsApplyToken = UUID()
    }
    private var vaultTypeFilters: [UUID: PageType?] = [:]
    private var chromeSnapshotBeforeFocus: (sidebar: Bool, assist: Bool)?

    init(selectedSection: SidebarSection = .notes) {
        self.selectedSection = selectedSection
    }

    func vaultTypeFilter(for vaultID: UUID) -> PageType? {
        vaultTypeFilters[vaultID] ?? nil
    }

    func setVaultTypeFilter(_ filter: PageType?, for vaultID: UUID) {
        vaultTypeFilters[vaultID] = filter
        vaultTypeFilter = filter
    }

    /// Restore the object-type filter saved for this vault (call after `activeVaultID` changes).
    func applyVaultContext(_ vaultID: UUID) {
        vaultTypeFilter = vaultTypeFilters[vaultID] ?? nil
    }

    func toggleVaultTypeFilter(_ type: PageType, for vaultID: UUID) {
        let current = vaultTypeFilter(for: vaultID)
        let next: PageType? = current == type ? nil : type
        setVaultTypeFilter(next, for: vaultID)
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

    func clearVaultTypeFilter(for vaultID: UUID?) {
        if let vaultID {
            setVaultTypeFilter(nil, for: vaultID)
        } else {
            vaultTypeFilter = nil
        }
    }

    func persistChromePreferences() {
        ShellChromePreferences.sidebarVisible = sidebarVisible
        ShellChromePreferences.assistStripExpanded = aiAssistExpanded
        ShellChromePreferences.navigationRailCollapsed = navigationRailCollapsed
    }

    /// Hides sidebar + assist for distraction-free writing (restores prior chrome on exit).
    func toggleEditorFocusMode() {
        if editorFocusMode {
            editorFocusMode = false
            if let snapshot = chromeSnapshotBeforeFocus {
                sidebarVisible = snapshot.sidebar
                aiAssistExpanded = snapshot.assist
            }
            chromeSnapshotBeforeFocus = nil
        } else {
            chromeSnapshotBeforeFocus = (sidebarVisible, aiAssistExpanded)
            editorFocusMode = true
            sidebarVisible = false
            aiAssistExpanded = false
        }
        persistChromePreferences()
    }

    /// Restores the rail when preferences say hidden but focus mode is off (legacy fullscreen auto-hide).
    func recoverSidebarIfOrphaned() {
        guard !sidebarVisible, !editorFocusMode else { return }
        sidebarVisible = true
        persistChromePreferences()
    }

    /// Legacy alias for toolbar toggles migrating to `aiAssistExpanded`.
    var inspectorVisible: Bool {
        get { aiAssistExpanded }
        set { aiAssistExpanded = newValue }
    }
}
