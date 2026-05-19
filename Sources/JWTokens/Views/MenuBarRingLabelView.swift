import SwiftUI
import JWTokensCore

struct MenuBarRingLabelView: View {
    let presentation: MenuBarSpendPresentation

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.3), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: presentation.progress)
                    .stroke(
                        bandColor,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 12, height: 12)

            Text(presentation.label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 42, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityLabel(presentation.accessibilityLabel)
    }

    private var bandColor: Color {
        switch presentation.band.id {
        case "yellow":
            return .yellow
        case "orange":
            return .orange
        case "red":
            return .red
        default:
            return .green
        }
    }
}
