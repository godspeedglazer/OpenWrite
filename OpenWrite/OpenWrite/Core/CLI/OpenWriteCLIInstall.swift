import Foundation

/// Installs `openwrite` CLI binaries shipped in the app bundle into the user's PATH.
enum OpenWriteCLIInstall {
    private static let toolNames = ["openwrite", "openwrite-index", "openwrite-query", "openwrite-stats"]

    static var bundledHelpersURL: URL? {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers", isDirectory: true)
    }

    static var defaultInstallDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin", isDirectory: true)
    }

    static func bundledToolsPresent() -> Bool {
        guard let helpers = bundledHelpersURL else { return false }
        return toolNames.allSatisfy {
            FileManager.default.isExecutableFile(atPath: helpers.appendingPathComponent($0).path)
        }
    }

    /// Copies bundled helpers into `~/Library/Application Support/openwrite/bin` and `~/.local/bin`.
    @discardableResult
    static func installBundledTools() throws -> URL {
        guard let helpers = bundledHelpersURL else {
            throw InstallError.helpersMissing
        }
        guard bundledToolsPresent() else {
            throw InstallError.helpersMissing
        }

        let supportBin = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("openwrite/bin", isDirectory: true)
        let userLocalBin = defaultInstallDirectory

        try FileManager.default.createDirectory(at: supportBin, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: userLocalBin, withIntermediateDirectories: true)

        for name in toolNames {
            let source = helpers.appendingPathComponent(name)
            try installExecutable(from: source, to: supportBin.appendingPathComponent(name))
            try installExecutable(from: source, to: userLocalBin.appendingPathComponent(name))
        }
        return userLocalBin
    }

    private static func installExecutable(from source: URL, to destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
    }

    enum InstallError: LocalizedError {
        case helpersMissing

        var errorDescription: String? {
            switch self {
            case .helpersMissing:
                return "Command-line tools were not found inside the app bundle. Reinstall OpenWrite from a Release build."
            }
        }
    }
}
