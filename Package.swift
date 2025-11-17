// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BackgroundAIAgent",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "BackgroundAIAgent",
            targets: ["BackgroundAIAgent"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "BackgroundAIAgent",
            dependencies: [],
            path: "Sources"
        )
    ]
)
