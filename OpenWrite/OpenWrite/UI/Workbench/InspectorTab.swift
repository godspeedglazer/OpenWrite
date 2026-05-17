import Foundation

/// Trailing workbench inspector panels.
enum InspectorTab: String, CaseIterable, Identifiable, Sendable {
    case chat
    case related
    case pastWrites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .related: return "Related"
        case .pastWrites: return "Past Writes"
        }
    }

}
