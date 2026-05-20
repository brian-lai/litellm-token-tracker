import SwiftUI

struct PopoverHeaderAccessoryView: View {
    static let settingsSymbolName = "gearshape"

    let settingsAction: () -> Void

    var body: some View {
        Button(action: settingsAction) {
            Image(systemName: Self.settingsSymbolName)
        }
        .buttonStyle(.plain)
        .help("Open Settings")
    }
}
