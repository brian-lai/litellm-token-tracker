import SwiftUI
import JWTokensCore

struct SpendPopoverView: View {
    @Bindable var viewModel: SpendDashboardViewModel

    var body: some View {
        let presentation = SpendPopoverPresentation.make(
            range: viewModel.selectedRange,
            snapshot: viewModel.currentSnapshot,
            errorMessage: viewModel.errorMessage,
            requiresSetup: viewModel.requiresSetup,
            menuBarMetric: viewModel.menuBarMetric
        )

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                SpendGaugeView(presentation: presentation.primaryGauge)
                VStack(alignment: .leading, spacing: 7) {
                    Text(presentation.rangeName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(presentation.totalText)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    Text("\(presentation.percentText) of \(presentation.limitText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let overLimitText = presentation.overLimitText {
                        Text(overLimitText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                    Text(presentation.refreshedText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            controlPanel
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
        .frame(width: 340, alignment: .leading)
        .padding(14)
        .background(.black.opacity(0.84))
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private var controlPanel: some View {
        VStack(spacing: 8) {
            rangeSelector
            metricSelector
        }
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

    private var metricSelector: some View {
        Picker("Menu bar", selection: metricBinding) {
            ForEach(MenuBarMetric.allCases, id: \.self) { metric in
                Text(metric.displayName).tag(metric)
            }
        }
        .pickerStyle(.segmented)
    }

    private var metricBinding: Binding<MenuBarMetric> {
        Binding(
            get: { viewModel.menuBarMetric },
            set: { metric in
                viewModel.setMenuBarMetric(metric)
            }
        )
    }
}
