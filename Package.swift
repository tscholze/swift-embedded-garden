// swift-tools-version: 6.0
//
// SwiftPM source-layout metadata for editor tooling and future dependencies.
// Firmware linking is performed by CMake because it combines the Swift object
// with Pico SDK startup, the volatile MMIO bridge, and RP2040 linker settings.

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
        "Display",
        "Graphics",
        "Hardware",
      ],
      swiftSettings: [
        // Mirrors the CMake Swift Embedded compilation mode for editor builds.
        .unsafeFlags(
          [
            "-enable-experimental-feature",
            "Embedded",
          ], .when(configuration: .release))
      ]
    )
  ]
)
