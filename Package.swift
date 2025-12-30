// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "mac-menu",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "6.2.0")
    ],
    targets: [
        .target(
            name: "FuzzyMatchModule",
            path: "src",
            exclude: ["main.swift", "Version.swift"],
            sources: ["FuzzyMatch.swift"]
        ),
        .testTarget(
            name: "FuzzyMatchTests",
            dependencies: [
                "FuzzyMatchModule",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "tests"
        )
    ]
)
