// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "JWTokens",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "JWTokens", targets: ["JWTokens"])
    ],
    targets: [
        .executableTarget(
            name: "JWTokens"
        )
    ]
)
