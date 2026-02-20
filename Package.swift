// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacRing",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MacRingCore",
            targets: ["MacRingCore"]
        )
    ],
    dependencies: [
        // Add external dependencies here when needed:
        // .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")
    ],
    targets: [
        .target(
            name: "MacRingCore",
            dependencies: [],
            path: "Sources/MacRingCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "MacRingCoreTests",
            dependencies: ["MacRingCore"],
            path: "Tests/MacRingCoreTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
