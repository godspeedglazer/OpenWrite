import Foundation

enum LMStudioConfigPersistence {
    static let storageKey = "com.openwrite.lmStudioConfig"

    static func load() -> LMStudioConfig? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(LMStudioConfig.self, from: data)
    }

    static func save(_ config: LMStudioConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
