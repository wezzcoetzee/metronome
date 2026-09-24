// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Metronome",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MetronomeCore"),
        .executableTarget(name: "Metronome", dependencies: ["MetronomeCore"]),
        .testTarget(name: "MetronomeCoreTests", dependencies: ["MetronomeCore"]),
    ]
)
