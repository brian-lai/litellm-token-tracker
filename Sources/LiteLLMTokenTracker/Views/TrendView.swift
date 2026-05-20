import SwiftUI
import LiteLLMTokenTrackerCore

struct TrendView: View {
    let presentation: TrendPresentation

    var body: some View {
        if presentation.isEmpty {
            Text("No daily activity")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(presentation.accessibilityLabel)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(presentation.totalText)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                    Spacer()
                    Text("\(presentation.tokenSummary) · \(presentation.requestSummary)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(presentation.days) { day in
                        VStack(spacing: 3) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.cyan.opacity(0.85))
                                .frame(height: max(2, 72 * day.heightRatio))
                                .help("\(day.dateText): \(day.amountText), \(day.tokenText), \(day.requestText)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 80)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.accessibilityLabel)
        }
    }
}
