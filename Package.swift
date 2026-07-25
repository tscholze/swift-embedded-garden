// swift-tools-version: 6.0
//
// This package manifest is intentionally ready for future Swift Embedded growth.
// The current CMake pipeline performs firmware linking with the Pico SDK, while
// this file provides a clean place to add Swift package dependencies and modular
// source organization over time.

import PackageDescription

let package = Package(
    name: "SwiftPicoEmbeddedGarden",
    products: [
        .executable(name: "PicoBlink", targets: ["PicoBlink"])
    ],
    dependencies: [
        // Add future embedded dependencies here, for example:
        // .package(url: "https://github.com/apple/swift-mmio.git", from: "0.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "PicoBlink",
            dependencies: [
                // Example extension point:
                // .product(name: "MMIO", package: "swift-mmio"),
            ],
            path: "Sources",
            sources: [
                "Application",
                "BoardSupport",
                "Hardware",
            ],
            swiftSettings: [
                // Keep the current target focused on embedded-safe code patterns.
                .unsafeFlags([
                    "-enable-experimental-feature",
                    "Embedded",
                ], .when(configuration: .release)),
            ]
        )
    ]
)
