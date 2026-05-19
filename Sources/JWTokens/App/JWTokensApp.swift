import SwiftUI
import JWTokensCore

@main
struct JWTokensApp: App {
    @NSApplicationDelegateAdaptor(JWTokensAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class JWTokensAppDelegate: NSObject, NSApplicationDelegate {
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
            await viewModel.refresh()
        }
    }

    private static func makeViewModel() -> SpendDashboardViewModel {
        if let previewViewModel = JWTokensPreviewFixtures.makeViewModelFromArguments() {
            return previewViewModel
        }
        let apiKeyStore = KeychainAPIKeyStore()
        return SpendDashboardViewModel(
            spendService: SpendService(
                apiKeyStore: apiKeyStore,
                clientFactory: { baseURL, apiKey in
                    LiteLLMClient(baseURL: baseURL, apiKey: apiKey)
                }
            ),
            apiKeyStore: apiKeyStore,
            menuBarPreferenceStore: UserDefaultsMenuBarPreferenceStore()
        )
    }
}
