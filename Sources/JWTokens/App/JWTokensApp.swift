import SwiftUI
import JWTokensCore

@main
struct JWTokensApp: App {
    @State private var viewModel = JWTokensApp.makeViewModel()
    @State private var refreshCoordinator: SpendRefreshCoordinator?

    var body: some Scene {
        MenuBarExtra {
            SpendPopoverView(viewModel: viewModel)
                .task {
                    if refreshCoordinator == nil {
                        let coordinator = SpendRefreshCoordinator(viewModel: viewModel)
                        coordinator.start()
                        refreshCoordinator = coordinator
                    }
                    await viewModel.refresh()
                }
        } label: {
            MenuBarRingLabelView(presentation: viewModel.menuBarPresentation)
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
