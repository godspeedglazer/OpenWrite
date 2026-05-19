import Foundation

enum LMStudioConfigPersistence {
    private static let legacyDefaultsKey = "com.openwrite.lmStudioConfig"
    private static let configFileName = "lm_studio_config.json"

    static var configDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("openwrite", isDirectory: true)
    }

    static var configFileURL: URL {
        configDirectoryURL.appendingPathComponent(configFileName)
    }

    static func load() -> LMStudioConfig? {
        if let fromDisk = loadFromApplicationSupport() {
            return fromDisk
        }
        if let legacy = loadLegacyUserDefaults() {
            save(legacy)
            UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
            return legacy
        }
        return nil
    }

    static func save(_ config: LMStudioConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        do {
            try FileManager.default.createDirectory(
                at: configDirectoryURL,
                withIntermediateDirectories: true
            )
            try data.write(to: configFileURL, options: .atomic)
        } catch {
            // Fall back so settings still stick for this session.
            UserDefaults.standard.set(data, forKey: legacyDefaultsKey)
        }
    }

    private static func loadFromApplicationSupport() -> LMStudioConfig? {
        guard FileManager.default.fileExists(atPath: configFileURL.path),
              let data = try? Data(contentsOf: configFileURL)
        else { return nil }
        return decode(data)
    }

    private static func loadLegacyUserDefaults() -> LMStudioConfig? {
        guard let data = UserDefaults.standard.data(forKey: legacyDefaultsKey) else { return nil }
        return decode(data)
    }

    private static func decode(_ data: Data) -> LMStudioConfig? {
        guard var config = try? JSONDecoder().decode(LMStudioConfig.self, from: data) else { return nil }
        let chat = config.chatModel.trimmingCharacters(in: .whitespacesAndNewlines)
        // Clear legacy placeholders so `resolveChatModelID` adopts the first loaded /v1/models entry,
        // rather than asserting a hardcoded id that may not be loaded on this machine.
        if chat == "local-model" || chat == "gemma-4-e4b" || chat == "google/gemma-4-e4b" {
            config.chatModel = ""
        }
        return config
    }
}
