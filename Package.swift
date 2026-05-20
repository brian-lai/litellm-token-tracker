// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "LiteLLMTokenTracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LiteLLMTokenTrackerCore", targets: ["LiteLLMTokenTrackerCore"]),
        .executable(name: "LiteLLMTokenTracker", targets: ["LiteLLMTokenTracker"]),
        .executable(name: "LiteLLMTokenTrackerTests", targets: ["LiteLLMTokenTrackerTests"])
    ],
    targets: [
        .target(
            name: "LiteLLMTokenTrackerCore"
        ),
        .executableTarget(
            name: "LiteLLMTokenTracker",
            dependencies: ["LiteLLMTokenTrackerCore"]
        ),
        .executableTarget(
            name: "LiteLLMTokenTrackerTests",
            dependencies: ["LiteLLMTokenTrackerCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
