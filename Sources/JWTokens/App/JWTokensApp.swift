import SwiftUI
import JWTokensCore

@main
struct JWTokensApp: App {
    @State private var viewModel = JWTokensApp.makeViewModel()
    @State private var refreshCoordinator: SpendRefreshCoordinator?

    var body: some Scene {
        MenuBarExtra(viewModel.menuBarTitle) {
            SpendPopoverView(viewModel: viewModel)
                .task {
                    if refreshCoordinator == nil {
                        let coordinator = SpendRefreshCoordinator(viewModel: viewModel)
                        coordinator.start()
                        refreshCoordinator = coordinator
                    }
                    await viewModel.refresh()
                }
        }
    }

    private static func makeViewModel() -> SpendDashboardViewModel {
        let apiKeyStore = KeychainAPIKeyStore()
        return SpendDashboardViewModel(
            spendService: SpendService(
                apiKeyStore: apiKeyStore,
                clientFactory: { baseURL, apiKey in
                    LiteLLMClient(baseURL: baseURL, apiKey: apiKey)
                }
            ),
            apiKeyStore: apiKeyStore
        )
    }
}
