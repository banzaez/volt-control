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
        .testTarget(
            name: "VoltControlTests",
            dependencies: ["VoltControl"],
            path: "Tests/VoltControlTests"
        )
    ]
)
