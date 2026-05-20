import SwiftUI
import LiteLLMTokenTrackerCore

struct KeyBudgetView: View {
    let presentation: KeyBudgetPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.currentKeyName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(presentation.currentKeyBudgetText ?? presentation.currentKeySpendText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let resetText = presentation.currentKeyResetText {
                    Text(resetText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if !presentation.ownedKeys.isEmpty {
                VStack(spacing: 7) {
                    ForEach(presentation.ownedKeys) { key in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(key.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text([key.budgetText, key.lastActiveText].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            Spacer(minLength: 8)
                            Text(key.spendText)
                                .font(.caption.monospacedDigit().weight(.semibold))
                        }
                    }
                }
            }
            if let statusText = presentation.statusText {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if presentation.isEmpty && presentation.statusText == nil {
                Text("No key context available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
