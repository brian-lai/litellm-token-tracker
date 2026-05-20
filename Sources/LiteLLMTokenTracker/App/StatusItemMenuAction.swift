import Foundation

enum StatusItemMenuAction: String, CaseIterable {
    case settings
    case refresh
    case exit

    var menuTitle: String {
        switch self {
        case .settings:
            return "Settings"
        case .refresh:
            return "Refresh"
        case .exit:
            return "Exit"
        }
    }
}

struct StatusItemMenuActionState: Equatable {
    let action: StatusItemMenuAction
    let isEnabled: Bool
}
