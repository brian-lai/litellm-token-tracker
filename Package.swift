// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "LiteLLMTokenTracker",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LiteLLMTokenTrackerCore", targets: ["LiteLLMTokenTrackerCore"]),
        .library(name: "LiteLLMTokenTrackerUI", targets: ["LiteLLMTokenTrackerUI"]),
        .executable(name: "LiteLLMTokenTracker", targets: ["LiteLLMTokenTracker"]),
        .executable(name: "LiteLLMTokenTrackerTests", targets: ["LiteLLMTokenTrackerTests"])
    ],
    targets: [
        .target(
            name: "LiteLLMTokenTrackerCore"
        ),
        .target(
            name: "LiteLLMTokenTrackerUI",
            dependencies: ["LiteLLMTokenTrackerCore"],
            path: "Sources/LiteLLMTokenTracker",
            exclude: [
                "App/LiteLLMTokenTrackerApp.swift",
                "Support"
            ],
            sources: [
                "App/StatusItemController.swift",
                "App/StatusItemMenuAction.swift",
                "Views/BreakdownView.swift",
                "Views/DailySpendChartView.swift",
                "Views/KeyBudgetView.swift",
                "Views/MenuBarRingLabelView.swift",
                "Views/PopoverHeaderAccessoryView.swift",
                "Views/SettingsDiagnosticsView.swift",
                "Views/SpendGaugeView.swift",
                "Views/SpendPopoverView.swift",
                "Views/TrendView.swift"
            ]
        ),
        .executableTarget(
            name: "LiteLLMTokenTracker",
            dependencies: ["LiteLLMTokenTrackerCore", "LiteLLMTokenTrackerUI"],
            path: "Sources/LiteLLMTokenTracker",
            exclude: [
                "App/StatusItemController.swift",
                "App/StatusItemMenuAction.swift",
                "Views"
            ],
            sources: [
                "App/LiteLLMTokenTrackerApp.swift",
                "Support/LiteLLMTokenTrackerPreviewFixtures.swift"
            ]
        ),
        .executableTarget(
            name: "LiteLLMTokenTrackerTests",
            dependencies: ["LiteLLMTokenTrackerCore", "LiteLLMTokenTrackerUI"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
