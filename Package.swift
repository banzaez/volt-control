// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "VoltControl",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "VoltControl",
            targets: ["VoltControl"]
        ),
        .executable(
            name: "VoltControlHelper",
            targets: ["VoltControlHelper"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "VoltCore",
            path: "Sources/VoltCore",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
        .executableTarget(
            name: "VoltControl",
            dependencies: [
                "VoltCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/VoltControl",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
        .executableTarget(
            name: "VoltControlHelper",
            dependencies: ["VoltCore"],
            path: "Sources/VoltControlHelper",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
        .testTarget(
            name: "VoltCoreTests",
            dependencies: ["VoltCore"],
            path: "Tests/VoltCoreTests"
        ),
        .testTarget(
            name: "VoltControlTests",
            dependencies: ["VoltControl", "VoltCore"],
            path: "Tests/VoltControlTests"
        )
    ]
)
