import Foundation
import Combine

@MainActor
final class QuickCaptureController: ObservableObject {
    @Published var draftText: String = ""
    @Published var isPresented: Bool = false

    func present() {
        draftText = ""
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }

    /// Stub: would append a new document or daily note block tree.
    func commit(into store: VaultStore) {
        _ = store
        draftText = ""
        isPresented = false
    }
}
