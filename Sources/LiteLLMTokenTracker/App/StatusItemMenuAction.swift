import Foundation

enum StatusItemMenuAction: String, CaseIterable {
    case settings
    case refresh
    case checkForUpdates
    case update
    case exit

    var menuTitle: String {
        switch self {
        case .settings:
            return "Settings"
        case .refresh:
            return "Refresh"
        case .checkForUpdates:
            return "Check for Updates..."
        case .update:
            return "Update..."
        case .exit:
            return "Exit"
        }
    }
}

struct StatusItemMenuActionState: Equatable {
    let action: StatusItemMenuAction
    let title: String
    let isEnabled: Bool

    init(action: StatusItemMenuAction, title: String? = nil, isEnabled: Bool) {
        self.action = action
        self.title = title ?? action.menuTitle
        self.isEnabled = isEnabled
    }
}
