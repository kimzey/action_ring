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
    targets: [
        .target(
            name: "MacRingCore",
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
