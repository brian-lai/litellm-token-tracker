import SwiftUI
import LiteLLMTokenTrackerUI
import LiteLLMTokenTrackerCore

@main
struct LiteLLMTokenTrackerApp: App {
    @NSApplicationDelegateAdaptor(LiteLLMTokenTrackerAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class LiteLLMTokenTrackerAppDelegate: NSObject, NSApplicationDelegate {
    private var viewModel: SpendDashboardViewModel?
    private var refreshCoordinator: SpendRefreshCoordinator?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let viewModel = Self.makeViewModel()
        let coordinator = SpendRefreshCoordinator(viewModel: viewModel)
        let controller = StatusItemController(viewModel: viewModel)

        self.viewModel = viewModel
        self.refreshCoordinator = coordinator
        self.statusItemController = controller

        coordinator.start()
        Task {
            await viewModel.refreshReleaseAvailability()
            await viewModel.refresh()
        }
    }

    private static func makeViewModel() -> SpendDashboardViewModel {
        if let previewViewModel = LiteLLMTokenTrackerPreviewFixtures.makeViewModelFromArguments() {
            return previewViewModel
        }
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let apiKeyStore = EnvironmentFallbackAPIKeyStore(primary: LocalFileAPIKeyStore())
        let configurationStore = LocalAppConfigurationStore()
        return SpendDashboardViewModel(
            spendService: SpendService(
                apiKeyStore: apiKeyStore,
                configurationStore: configurationStore,
                gatewayClientFactory: { provider, baseURL, apiKey in
                    switch provider {
                    case .litellm:
                        LiteLLMClient(baseURL: baseURL, apiKey: apiKey)
                    case .bifrost:
                        BifrostClient(baseURL: baseURL, apiKey: apiKey)
                    }
                }
            ),
            keyContextService: KeyContextService(
                apiKeyStore: apiKeyStore,
                configurationStore: configurationStore,
                gatewayClientFactory: { provider, baseURL, apiKey in
                    switch provider {
                    case .litellm:
                        LiteLLMClient(baseURL: baseURL, apiKey: apiKey)
                    case .bifrost:
                        BifrostClient(baseURL: baseURL, apiKey: apiKey)
                    }
                }
            ),
            apiKeyStore: apiKeyStore,
            menuBarPreferenceStore: UserDefaultsMenuBarPreferenceStore(),
            configurationStore: configurationStore,
            releaseUpdateChecker: GitHubReleaseUpdateChecker(),
            appVersion: appVersion
        )
    }
}
