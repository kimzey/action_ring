// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ActionRing",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ActionRingCore", targets: ["ActionRingCore"]),
        .executable(name: "ActionRing", targets: ["ActionRing"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ActionRingCore",
            dependencies: [],
            path: "Sources/ActionRingCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "ActionRing",
            dependencies: ["ActionRingCore"],
            path: "Sources/ActionRing",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // Lightweight, dependency-free invariant checker. Runs the core logic
        // tests via `swift run ARCheck` in environments without Xcode/XCTest.
        .executableTarget(
            name: "ARCheck",
            dependencies: ["ActionRingCore"],
            path: "Sources/ARCheck",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "ActionRingCoreTests",
            dependencies: ["ActionRingCore"],
            path: "Tests/ActionRingCoreTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
