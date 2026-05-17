import Combine
import SwiftUI

// MARK: - Strip-level destinations

enum AIAssistScreen: Equatable {
    case root
    case chatThread
    case relatedDetail(RetrievalHit)
}

enum ChatPanelScreen: Equatable {
    case agentPicker
    case conversation
}

// MARK: - Navigation state

@MainActor
final class AIAssistNavigationState: ObservableObject {
    @Published private(set) var stack: [AIAssistScreen] = [.root]
    @Published private(set) var forwardStack: [AIAssistScreen] = []
    @Published var chatPanelScreen: ChatPanelScreen = .agentPicker
    @Published var relatedDetailHit: RetrievalHit?

    var current: AIAssistScreen { stack.last ?? .root }
    var isAtRoot: Bool { stack == [.root] }
    var canGoBack: Bool { !isAtRoot }
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// Strip / panel back when stack depth ≥ 1 or chat has drilled into a thread at root.
    var stripCanGoBack: Bool {
        if !isAtRoot { return true }
        return chatPanelScreen == .conversation
    }

    var stripBackAccessibilityLabel: String {
        if isAtRoot, chatPanelScreen == .conversation {
            return "Back to agents"
        }
        switch current {
        case .root:
            return "Back"
        case .chatThread:
            return "Back to AI assist"
        case .relatedDetail:
            return "Back to related notes"
        }
    }

    var toolbarTitle: String {
        switch current {
        case .root:
            return "AI assist"
        case .chatThread:
            return "Chat"
        case .relatedDetail(let hit):
            return hit.documentTitle
        }
    }

    /// Title for assist-strip chrome (accounts for in-panel chat depth at root).
    var stripToolbarTitle: String {
        if isAtRoot, chatPanelScreen == .conversation {
            return "Chat"
        }
        return toolbarTitle
    }

    func push(_ screen: AIAssistScreen) {
        guard stack.last != screen else { return }
        forwardStack.removeAll()
        stack.append(screen)
        if case .relatedDetail(let hit) = screen {
            relatedDetailHit = hit
        }
    }

    func pop() {
        guard stack.count > 1 else { return }
        let removed = stack.removeLast()
        forwardStack.append(removed)
        syncAfterPop()
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        stack.append(next)
        if case .relatedDetail(let hit) = next {
            relatedDetailHit = hit
        }
        if next == .chatThread {
            chatPanelScreen = .conversation
        }
    }

    func popToRoot() {
        forwardStack.removeAll()
        stack = [.root]
        relatedDetailHit = nil
        chatPanelScreen = .agentPicker
    }

    /// In-panel drill-in: agent list → conversation (strip stays at root with tab picker).
    func openChatThread() {
        chatPanelScreen = .conversation
    }

    func closeChatThread() {
        chatPanelScreen = .agentPicker
        if current == .chatThread {
            pop()
        }
    }

    func stripBack() {
        if !isAtRoot {
            backFromToolbar()
            return
        }
        if chatPanelScreen == .conversation {
            closeChatThread()
        }
    }

    func openRelatedDetail(_ hit: RetrievalHit) {
        relatedDetailHit = hit
        push(.relatedDetail(hit))
    }

    func backFromToolbar() {
        switch current {
        case .chatThread:
            closeChatThread()
        case .relatedDetail:
            relatedDetailHit = nil
            pop()
        case .root:
            break
        }
    }

    private func syncAfterPop() {
        switch current {
        case .root:
            if chatPanelScreen == .conversation {
                chatPanelScreen = .agentPicker
            }
            relatedDetailHit = nil
        case .chatThread:
            chatPanelScreen = .conversation
        case .relatedDetail(let hit):
            relatedDetailHit = hit
        }
    }
}
