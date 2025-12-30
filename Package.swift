// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "mac-menu",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "MacMenuLib", targets: ["MacMenuLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "6.2.0")
    ],
    targets: [
        // Combined library module with all core functionality
        .target(
            name: "MacMenuLib",
            path: "src",
            exclude: ["main.swift", "Version.swift"],
            sources: [
                "Models/SearchableItem.swift",
                "Core/Protocols.swift",
                "Core/FuzzyMatch.swift",
                "Core/SearchEngine.swift",
                "IO/InputLoader.swift",
                "IO/OutputWriter.swift",
                "UI/HoverTableRowView.swift"
            ]
        ),

        // Test targets
        .testTarget(
            name: "MacMenuTests",
            dependencies: [
                "MacMenuLib",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "tests",
            sources: [
                "Core/FuzzyMatchTests.swift",
                "Core/SearchEngineTests.swift",
                "IO/InputLoaderTests.swift"
            ]
        ),
    ]
)
