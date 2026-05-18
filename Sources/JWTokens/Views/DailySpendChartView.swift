import SwiftUI
import JWTokensCore

struct DailySpendChartView: View {
    let presentation: DailySpendChartPresentation

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(presentation.bars) { bar in
                VStack(spacing: 3) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.blue)
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
