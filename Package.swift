// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacZones",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MacZones",
            path: "Sources/MacZones",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
