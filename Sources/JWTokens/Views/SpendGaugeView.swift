import SwiftUI
import JWTokensCore

struct SpendGaugeView: View {
    let presentation: RingProgressPresentation

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 12)
            Circle()
                .trim(from: 0, to: presentation.progress)
                .stroke(
                    bandColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 3) {
                Text(presentation.label)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text(presentation.band.accessibleName.uppercased())
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 132, height: 132)
        .preferredColorScheme(.dark)
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
