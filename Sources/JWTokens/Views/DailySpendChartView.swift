import SwiftUI
import JWTokensCore

struct DailySpendChartView: View {
    let presentation: DailySpendChartPresentation

    var body: some View {
        if presentation.isEmpty {
            Text("No daily spend")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 80)
                .frame(maxWidth: .infinity)
        } else {
            bars
        }
    }

    private var bars: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(presentation.bars) { bar in
                VStack(spacing: 3) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: bar.band))
                        .frame(height: max(2, 72 * bar.heightRatio))
                        .help(bar.amountText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }

    private func color(for band: SpendStatusBand) -> Color {
        switch band.id {
        case "yellow":
            return .yellow.opacity(0.85)
        case "orange":
            return .orange.opacity(0.9)
        case "red":
            return .red.opacity(0.9)
        default:
            return .cyan.opacity(0.85)
        }
    }
}
