import SwiftUI
import JWTokensCore

@main
struct JWTokensApp: App {
    @State private var viewModel = SpendDashboardViewModel(
        spendService: SpendService(
            apiKeyStore: KeychainAPIKeyStore(),
            clientFactory: { baseURL, apiKey in
                LiteLLMClient(baseURL: baseURL, apiKey: apiKey)
            }
        )
    )

    var body: some Scene {
        MenuBarExtra(viewModel.menuBarTitle) {
            SpendPopoverView(viewModel: viewModel)
                .task {
                await viewModel.refresh()
            }
        }
    }
}
