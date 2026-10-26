// swift-tools-version: 5.9
// Tools 5.9 keeps the Swift 5 language mode and builds with older
// Command Line Tools as well as recent Xcode versions.
import PackageDescription

let package = Package(
    name: "Break",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Break", path: "Sources/Break"),
        .testTarget(name: "BreakTests", dependencies: ["Break"]),
    ]
)
