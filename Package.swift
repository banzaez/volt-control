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
    targets: [
        .executableTarget(
            name: "VoltControl",
            path: "Sources/VoltControl",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
        .executableTarget(
            name: "VoltControlHelper",
            path: "Sources/VoltControlHelper"
        ),
        .testTarget(
            name: "VoltControlTests",
            dependencies: ["VoltControl"],
            path: "Tests/VoltControlTests"
        )
    ]
)
