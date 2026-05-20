import SwiftUI
import LiteLLMTokenTrackerCore

struct SettingsDiagnosticsView: View {
    @Bindable var viewModel: SpendDashboardViewModel
    let presentation: SettingsPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Daily budget", text: $viewModel.spendLimitDraft)
                .textFieldStyle(.roundedBorder)
            TextField("Base URL", text: $viewModel.baseURLDraft)
                .textFieldStyle(.roundedBorder)
            Button("Save") {
                viewModel.saveSettings()
            }
            if let errorText = presentation.errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            diagnosticsGrid
            Text(presentation.warningText)
                .font(.caption2)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            Button("Clear API Key") {
                viewModel.clearAPIKey()
            }
        }
    }

    private var diagnosticsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            ForEach(presentation.diagnosticRows) { row in
                GridRow {
                    Text(row.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(row.value)
                        .font(.caption.monospacedDigit().weight(.medium))
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
