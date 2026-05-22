// swift-tools-version: 5.9
import PackageDescription

// Run `make sync` after pulling app sources.

let package = Package(
    name: "OpenWriteCLI",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "openwrite", targets: ["openwrite"]),
        .executable(name: "openwrite-index", targets: ["openwrite-index"]),
        .executable(name: "openwrite-query", targets: ["openwrite-query"]),
        .executable(name: "openwrite-stats", targets: ["openwrite-stats"])
    ],
    targets: [
        .target(
            name: "OpenWriteKit",
            path: "Sources",
            exclude: [
                "openwrite",
                "openwrite-index",
                "openwrite-query",
                "openwrite-stats"
            ]
        ),
        .executableTarget(
            name: "openwrite",
            dependencies: ["OpenWriteKit"],
            path: "Sources/openwrite"
        ),
        .executableTarget(
            name: "openwrite-index",
            dependencies: ["OpenWriteKit"],
            path: "Sources/openwrite-index"
        ),
        .executableTarget(
            name: "openwrite-query",
            dependencies: ["OpenWriteKit"],
            path: "Sources/openwrite-query"
        ),
        .executableTarget(
            name: "openwrite-stats",
            dependencies: ["OpenWriteKit"],
            path: "Sources/openwrite-stats"
        ),
        .testTarget(
            name: "WritingCoreTests",
            dependencies: ["OpenWriteKit"]
        )
    ]
)
