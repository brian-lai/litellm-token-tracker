import Foundation

enum StatusItemMenuAction: String, CaseIterable {
    case settings
    case refresh
    case exit
}

struct StatusItemMenuActionState: Equatable {
    let action: StatusItemMenuAction
    let isEnabled: Bool
}
