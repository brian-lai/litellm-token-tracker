import SwiftUI
import JWTokensCore

struct SpendPopoverView: View {
    @Bindable var viewModel: SpendDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            rangeSelector
            Text(viewModel.menuBarTitle)
                .font(.title3.weight(.semibold))
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
