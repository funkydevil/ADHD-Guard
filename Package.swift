// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ADHDGuard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ADHDGuard", targets: ["ADHDGuard"])
    ],
    targets: [
        .executableTarget(
            name: "ADHDGuard",
            path: "Sources/ADHDGuard"
        ),
        .testTarget(
            name: "ADHDGuardTests",
            dependencies: ["ADHDGuard"],
            path: "Tests/ADHDGuardTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
