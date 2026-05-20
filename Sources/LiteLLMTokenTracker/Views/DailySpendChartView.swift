import SwiftUI
import LiteLLMTokenTrackerCore

struct DailySpendChartView: View {
    let presentation: DailySpendChartPresentation

    var body: some View {
        if presentation.isEmpty {
            Text("No daily spend")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 80)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(presentation.accessibilityLabel)
        } else {
            bars
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(presentation.accessibilityLabel)
        }
    }

    private var bars: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(presentation.bars) { bar in
                VStack(spacing: 3) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.cyan.opacity(0.85))
                        .frame(height: max(2, 72 * bar.heightRatio))
                        .help(bar.amountText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
}
