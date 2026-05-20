import SwiftUI
import LiteLLMTokenTrackerCore

struct SpendPopoverView: View {
    static var modeSelectorModes: [SpendPopoverMode] {
        SpendPopoverMode.allCases
    }

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
            HStack {
                Spacer()
                PopoverHeaderAccessoryView {
                    Task {
                        await viewModel.openSettings()
                    }
                }
            }
            HStack(alignment: .center, spacing: 14) {
                SpendGaugeView(presentation: presentation.primaryGauge)
                VStack(alignment: .leading, spacing: 7) {
                    Text(presentation.rangeName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(presentation.totalText)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                    Text("\(presentation.percentText) of \(presentation.limitText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                    if let overLimitText = presentation.overLimitText {
                        Text(overLimitText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .allowsTightening(true)
                    }
                    Text(presentation.refreshedText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            detailGrid(rows: presentation.detailRows)
            modeSelector
            controlPanel
            if let statusText = presentation.statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(viewModel.currentSnapshot?.isStale == true ? .orange : .secondary)
            }
            switch viewModel.selectedPopoverMode {
            case .overview:
                if let snapshot = viewModel.currentSnapshot {
                    DailySpendChartView(presentation: .make(points: snapshot.dailyPoints))
                }
            case .trends:
                TrendView(presentation: .make(analytics: viewModel.currentSnapshot?.analytics))
            case .breakdown:
                BreakdownView(presentation: .make(analytics: viewModel.currentSnapshot?.analytics))
            case .keys:
                KeyBudgetView(presentation: .make(snapshot: viewModel.keyContextSnapshot, errorMessage: viewModel.keyContextErrorMessage))
            case .settings:
                SettingsDiagnosticsView(
                    viewModel: viewModel,
                    presentation: .make(
                        baseURLText: viewModel.baseURLDraft,
                        spendLimitText: viewModel.spendLimitDraft,
                        snapshot: viewModel.currentSnapshot,
                        settingsError: viewModel.settingsErrorMessage,
                        lastError: viewModel.settingsErrorMessage ?? viewModel.errorMessage ?? viewModel.keyContextErrorMessage
                    )
                )
            }
            Button {
                Task {
                    await viewModel.refreshSelectedMode()
                }
            } label: {
                Text((viewModel.isRefreshing || viewModel.isKeyContextRefreshing) ? "Refreshing..." : "Refresh")
            }
            .disabled(viewModel.isRefreshing || viewModel.isKeyContextRefreshing)
            if presentation.showsKeyUpdateAction {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("LiteLLM Base URL", text: $viewModel.baseURLDraft)
                        .textFieldStyle(.roundedBorder)
                    Button("Save Base URL") {
                        viewModel.saveBaseURL()
                    }
                    .disabled(viewModel.baseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    SecureField("LiteLLM API key", text: $viewModel.apiKeyDraft)
                        .textFieldStyle(.roundedBorder)
                    Button("Save API Key") {
                        viewModel.saveAPIKey()
                    }
                    .disabled(viewModel.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
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

    private var modeSelector: some View {
        HStack(spacing: 6) {
            ForEach(Self.modeSelectorModes) { mode in
                selectorButton(
                    title: mode.displayName,
                    isSelected: viewModel.selectedPopoverMode == mode
                ) {
                    Task {
                        await viewModel.selectPopoverMode(mode)
                    }
                }
            }
        }
    }

    private var rangeSelector: some View {
        HStack(spacing: 6) {
            ForEach(SpendRange.allCases) { range in
                selectorButton(
                    title: range.displayName,
                    isSelected: viewModel.selectedRange == range
                ) {
                    Task {
                        await viewModel.selectRange(range)
                    }
                }
            }
        }
    }

    private var metricSelector: some View {
        HStack(spacing: 6) {
            ForEach(MenuBarMetric.allCases, id: \.self) { metric in
                selectorButton(
                    title: metric.displayName,
                    isSelected: viewModel.menuBarMetric == metric
                ) {
                    viewModel.setMenuBarMetric(metric)
                }
            }
        }
    }

    private func selectorButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(isSelected ? Color.blue.opacity(0.95) : Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.blue.opacity(0.95) : Color.white.opacity(0.16), lineWidth: 1)
                )
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func detailGrid(rows: [SpendPopoverPresentation.DetailRow]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            ForEach(rows) { row in
                GridRow {
                    Text(row.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(row.value)
                        .font(.caption.monospacedDigit().weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
    }
}
