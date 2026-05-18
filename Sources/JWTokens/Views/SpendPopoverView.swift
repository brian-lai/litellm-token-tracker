import SwiftUI
import JWTokensCore

struct SpendPopoverView: View {
    @Bindable var viewModel: SpendDashboardViewModel

    var body: some View {
        let presentation = SpendPopoverPresentation.make(
            range: viewModel.selectedRange,
            snapshot: viewModel.currentSnapshot,
            errorMessage: viewModel.errorMessage,
            requiresSetup: viewModel.requiresSetup
        )

        VStack(alignment: .leading, spacing: 12) {
            rangeSelector
            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.rangeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text(presentation.totalText)
                        .font(.title2.weight(.semibold))
                    Text(presentation.percentText)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                Text(presentation.refreshedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let statusText = presentation.statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(viewModel.currentSnapshot?.isStale == true ? .orange : .secondary)
            }
            if let snapshot = viewModel.currentSnapshot {
                DailySpendChartView(presentation: .make(points: snapshot.dailyPoints))
            }
            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Text(viewModel.isRefreshing ? "Refreshing..." : "Refresh")
            }
            .disabled(viewModel.isRefreshing)
            if presentation.showsKeyUpdateAction {
                SecureField("LiteLLM API key", text: $viewModel.apiKeyDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Save API Key") {
                    viewModel.saveAPIKey()
                }
                .disabled(viewModel.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .frame(width: 280, alignment: .leading)
        .padding(12)
    }

    private var rangeSelector: some View {
        Picker("Range", selection: rangeBinding) {
            ForEach(SpendRange.allCases) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var rangeBinding: Binding<SpendRange> {
        Binding(
            get: { viewModel.selectedRange },
            set: { range in
                Task {
                    await viewModel.selectRange(range)
                }
            }
        )
    }
}
