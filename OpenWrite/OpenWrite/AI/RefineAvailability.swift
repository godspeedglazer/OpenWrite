import Foundation

/// User-facing refine vs index availability (local hash embeddings vs LM Studio chat).
enum RefineAvailability {
    static let indexOfflineNotice =
        "Note search and indexing work offline using local embedding fallback."

    static let refineRequiresChatModel =
        "Refine rewrites selection with your chat model. Start LM Studio, load a model, or set Chat model in Settings → AI."

    static func refineBlockedMessage(
        connectionState: OpenWriteAIServices.LMConnectionState
    ) -> String? {
        switch connectionState {
        case .connected:
            return nil
        case .offline:
            return """
            \(refineRequiresChatModel)

            \(indexOfflineNotice) You can still search notes in chat when a model is loaded.
            """
        case .noModelLoaded:
            return """
            LM Studio is running but no chat model is loaded. Load a model, then try Refine again.

            \(indexOfflineNotice)
            """
        case .notChecked, .checking, .connecting:
            return """
            Still checking LM Studio… Try Refine again in a moment.

            \(indexOfflineNotice)
            """
        }
    }

    /// Optional cloud key scaffold (Settings → AI). Not required for local refine.
    static let optionalAPIKeyUserDefaultsKey = "openwrite.ai.optionalAPIKey"

    static var hasOptionalAPIKey: Bool {
        let trimmed = UserDefaults.standard.string(forKey: optionalAPIKeyUserDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !trimmed.isEmpty
    }
}
