// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "JWTokens",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "JWTokensCore", targets: ["JWTokensCore"]),
        .executable(name: "JWTokens", targets: ["JWTokens"]),
        .executable(name: "JWTokensTests", targets: ["JWTokensTests"])
    ],
    targets: [
        .target(
            name: "JWTokensCore"
        ),
        .executableTarget(
            name: "JWTokens",
            dependencies: ["JWTokensCore"]
        ),
        .executableTarget(
            name: "JWTokensTests",
            dependencies: ["JWTokensCore"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
