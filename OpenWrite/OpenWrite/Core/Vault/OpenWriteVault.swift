import Foundation

/// Logical vault root — multiple vaults can coexist in one in-memory store until disk bundles ship.
struct OpenWriteVault: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case primary
        case demo
    }

    let id: UUID
    var name: String
    var subtitle: String
    var kind: Kind

    init(id: UUID, name: String, subtitle: String, kind: Kind) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.kind = kind
    }

    static let primaryID = UUID(uuidString: "E1C00000-7B2A-4E8F-9D01-000000000001")!
    static let demoID = UUID(uuidString: "E1C00000-7B2A-4E8F-9D01-000000000002")!

    static let primary = OpenWriteVault(
        id: primaryID,
        name: "My Space",
        subtitle: "Your vault",
        kind: .primary
    )

    static let demo = OpenWriteVault(
        id: demoID,
        name: "Links Demo",
        subtitle: "Sample graph",
        kind: .demo
    )

    static let builtIn: [OpenWriteVault] = [.primary, .demo]

    enum MetadataKey {
        static let vaultID = "openwrite.vaultID"
        static let demoSeedVersion = "openwrite.demoSeedVersion"
        static let isDemoSeed = "openwrite.isDemoSeed"
    }
}

extension VaultDocument {
    var vaultID: UUID {
        if let raw = metadata[OpenWriteVault.MetadataKey.vaultID],
           let id = UUID(uuidString: raw) {
            return id
        }
        return OpenWriteVault.primaryID
    }

    mutating func assignVault(_ vaultID: UUID, demoSeed: Bool = false) {
        metadata[OpenWriteVault.MetadataKey.vaultID] = vaultID.uuidString
        if demoSeed {
            metadata[OpenWriteVault.MetadataKey.isDemoSeed] = "true"
            metadata[OpenWriteVault.MetadataKey.demoSeedVersion] = DemoVaultSeeder.seedVersion
        }
    }

    func belongsToVault(_ vaultID: UUID) -> Bool {
        self.vaultID == vaultID
    }
}

enum VaultLaunchPreferences {
    private static let didSeedDemoOnFirstLaunchKey = "openwrite.didSeedDemoOnFirstLaunch"

    static var didSeedDemoOnFirstLaunch: Bool {
        get { UserDefaults.standard.bool(forKey: didSeedDemoOnFirstLaunchKey) }
        set { UserDefaults.standard.set(newValue, forKey: didSeedDemoOnFirstLaunchKey) }
    }
}
