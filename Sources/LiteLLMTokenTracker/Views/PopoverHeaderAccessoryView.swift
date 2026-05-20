import SwiftUI

struct PopoverHeaderAccessoryView: View {
    let settingsAction: () -> Void

    var body: some View {
        Button(action: settingsAction) {
            Image(systemName: "gearshape")
        }
        .buttonStyle(.plain)
    }
}
