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
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.menuBarTitle)
                    .font(.headline)
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .task {
                await viewModel.refresh()
            }
        }
    }
}
