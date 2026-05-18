import Foundation

/// Lightweight vault markdown watcher — scans on launch and when the vault root changes.
@MainActor
final class VaultMarkdownWatcher: ObservableObject {
    private var watchTask: Task<Void, Never>?
    private var lastSnapshot: [String: Date] = [:]
    private var onVaultChanged: (() -> Void)?

    func start(onChange: @escaping () -> Void) {
        onVaultChanged = onChange
        watchTask?.cancel()
        watchTask = Task { [weak self] in
            guard let self else { return }
            _ = try? VaultLocationPreferences.ensureDefaultVaultLayout()
            await self.scanAndNotifyIfNeeded(force: true)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await self.scanAndNotifyIfNeeded(force: false)
            }
        }
    }

    func stop() {
        watchTask?.cancel()
        watchTask = nil
    }

    func rescanNow() {
        Task { await scanAndNotifyIfNeeded(force: true) }
    }

    private func scanAndNotifyIfNeeded(force: Bool) async {
        let root = VaultLocationPreferences.resolvedVaultRootURL()
        let snapshot = await Task.detached(priority: .utility) {
            let files = VaultMarkdownCatalog.scan(vaultRoot: root)
            var snapshot: [String: Date] = [:]
            snapshot.reserveCapacity(files.count)
            for file in files {
                snapshot[file.relativePath] = file.modifiedAt
            }
            return snapshot
        }.value
        let changed = force || snapshot != lastSnapshot
        lastSnapshot = snapshot
        if changed {
            onVaultChanged?()
        }
    }
}
