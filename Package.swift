// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Break",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Break",
            path: "Sources/Break",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "BreakTests",
            dependencies: ["Break"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
