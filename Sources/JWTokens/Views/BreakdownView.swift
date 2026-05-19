import SwiftUI
import JWTokensCore

struct BreakdownView: View {
    let presentation: BreakdownPresentation

    var body: some View {
        if presentation.isEmpty {
            Text(presentation.emptyText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(presentation.accessibilityLabel)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(presentation.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(spacing: 7) {
                    ForEach(presentation.rows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(row.label)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 8)
                                Text(row.spendText)
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            HStack(spacing: 6) {
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.10))
                                        Capsule()
                                            .fill(Color.cyan.opacity(0.85))
                                            .frame(width: row.share <= 0 ? 0 : max(2, geometry.size.width * row.share))
                                    }
                                }
                                .frame(height: 5)
                                Text(row.percentText)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 34, alignment: .trailing)
                            }
                            if row.tokenText != nil || row.requestText != nil {
                                Text([row.tokenText, row.requestText].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(presentation.accessibilityLabel)
        }
    }
}
