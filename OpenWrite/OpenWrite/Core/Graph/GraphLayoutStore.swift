import CoreGraphics
import Foundation

/// Per-vault manual graph node positions (`~/Library/Application Support/openwrite/graph_layouts/`).
enum GraphLayoutStore {
    static let formatVersion = 1
    static let subdirectory = "openwrite/graph_layouts"

    private struct StoredLayout: Codable, Sendable {
        var version: Int
        var positions: [String: StoredPoint]
    }

    private struct StoredPoint: Codable, Sendable {
        var x: Double
        var y: Double
    }

    private static var layoutsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(subdirectory, isDirectory: true)
    }

    private static func fileURL(vaultID: UUID) -> URL {
        layoutsDirectory.appendingPathComponent("\(vaultID.uuidString).json")
    }

    static func load(vaultID: UUID) -> [UUID: CGPoint] {
        let url = fileURL(vaultID: vaultID)
        guard
            let data = try? Data(contentsOf: url),
            let stored = try? JSONDecoder().decode(StoredLayout.self, from: data),
            stored.version == formatVersion
        else { return [:] }

        var result: [UUID: CGPoint] = [:]
        result.reserveCapacity(stored.positions.count)
        for (key, point) in stored.positions {
            guard let id = UUID(uuidString: key) else { continue }
            result[id] = CGPoint(x: point.x, y: point.y)
        }
        return result
    }

    static func save(vaultID: UUID, positions: [UUID: CGPoint]) {
        guard !positions.isEmpty else {
            clear(vaultID: vaultID)
            return
        }

        let stored = StoredLayout(
            version: formatVersion,
            positions: Dictionary(
                uniqueKeysWithValues: positions.map { ($0.key.uuidString, StoredPoint(x: Double($0.value.x), y: Double($0.value.y))) }
            )
        )

        do {
            try FileManager.default.createDirectory(at: layoutsDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(stored)
            try data.write(to: fileURL(vaultID: vaultID), options: .atomic)
        } catch {
            // Best-effort persistence; graph remains usable without disk write.
        }
    }

    static func clear(vaultID: UUID) {
        let url = fileURL(vaultID: vaultID)
        try? FileManager.default.removeItem(at: url)
    }
}
