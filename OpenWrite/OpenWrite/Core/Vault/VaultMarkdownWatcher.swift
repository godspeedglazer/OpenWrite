import Foundation

/// Lightweight notes-folder watcher — scans on launch and on an interval for `.md` changes.
@MainActor
final class VaultMarkdownWatcher: ObservableObject {
    private var watchTask: Task<Void, Never>?
    private var lastSnapshot: [String: Date] = [:]
    private var onMarkdownChanged: (([URL]) -> Void)?

    func start(onMarkdownChanged handler: @escaping ([URL]) -> Void) {
        onMarkdownChanged = handler
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

        let changedURLs = changedMarkdownURLs(
            root: root,
            snapshot: snapshot,
            previous: lastSnapshot,
            treatAllAsChanged: force
        )
        lastSnapshot = snapshot
        guard !changedURLs.isEmpty else { return }
        onMarkdownChanged?(changedURLs)
    }

    private func changedMarkdownURLs(
        root: URL,
        snapshot: [String: Date],
        previous: [String: Date],
        treatAllAsChanged: Bool
    ) -> [URL] {
        if treatAllAsChanged {
            return snapshot.keys.sorted().map { root.appendingPathComponent($0) }
        }
        var urls: [URL] = []
        urls.reserveCapacity(snapshot.count)
        for (relative, modified) in snapshot where previous[relative] != modified {
            urls.append(root.appendingPathComponent(relative))
        }
        return urls
    }
}
