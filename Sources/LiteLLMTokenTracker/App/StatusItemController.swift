import AppKit
import Observation
import SwiftUI
import LiteLLMTokenTrackerCore

@MainActor
public final class StatusItemController: NSObject {
    private let viewModel: SpendDashboardViewModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let popoverToggleAction: (() -> Void)?
    private let contextMenuPopupAction: ((NSMenu) -> Void)?
    private let settingsPopoverAction: (() -> Void)?
    private let terminateAction: () -> Void
    private var activeContextMenu: NSMenu?

    public convenience init(viewModel: SpendDashboardViewModel) {
        self.init(
            viewModel: viewModel,
            popoverToggleAction: nil,
            contextMenuPopupAction: nil,
            settingsPopoverAction: nil,
            terminateAction: nil
        )
    }

    init(
        viewModel: SpendDashboardViewModel,
        popoverToggleAction: (() -> Void)? = nil,
        contextMenuPopupAction: ((NSMenu) -> Void)? = nil,
        settingsPopoverAction: (() -> Void)? = nil,
        terminateAction: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popoverToggleAction = popoverToggleAction
        self.contextMenuPopupAction = contextMenuPopupAction
        self.settingsPopoverAction = settingsPopoverAction
        self.terminateAction = terminateAction ?? { NSApp.terminate(nil) }
        super.init()
        configureStatusItem()
        configurePopover()
        updateStatusItem()
        observePresentation()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 520)
        popover.contentViewController = NSHostingController(rootView: SpendPopoverView(viewModel: viewModel))
    }

    private func observePresentation() {
        withObservationTracking {
            _ = viewModel.menuBarPresentation
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateStatusItem()
                self?.observePresentation()
            }
        }
    }

    private func updateStatusItem() {
        let presentation = viewModel.menuBarPresentation
        guard let button = statusItem.button else {
            return
        }
        button.image = StatusRingImageRenderer.image(for: presentation)
        button.title = " \(presentation.label)"
        button.toolTip = presentation.accessibilityLabel
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        button.imagePosition = .imageLeading
        button.sizeToFit()
    }

    func availableMenuActions() -> [StatusItemMenuActionState] {
        [
            StatusItemMenuActionState(action: .settings, isEnabled: true),
            StatusItemMenuActionState(
                action: .refresh,
                isEnabled: !(viewModel.isRefreshing || viewModel.isKeyContextRefreshing)
            ),
            StatusItemMenuActionState(action: .exit, isEnabled: true)
        ]
    }

    func handlePrimaryClick() {
        if let popoverToggleAction {
            popoverToggleAction()
        } else {
            togglePopover()
        }
    }

    func handleSecondaryClick() {
        if popover.isShown {
            popover.performClose(nil)
        }

        presentContextMenu(availableMenuActions())
    }

    func performMenuAction(_ action: StatusItemMenuAction) async {
        switch action {
        case .settings:
            await viewModel.openSettings()
            showSettingsPopover()
        case .refresh:
            await viewModel.refreshSelectedMode()
        case .exit:
            terminateAction()
        }
    }

    @objc private func handleStatusItemClick() {
        switch NSApp.currentEvent?.type {
        case .rightMouseUp:
            handleSecondaryClick()
        default:
            handlePrimaryClick()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            updateStatusItem()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showSettingsPopover() {
        if let settingsPopoverAction {
            settingsPopoverAction()
            return
        }

        guard let button = statusItem.button else {
            return
        }
        if !popover.isShown {
            updateStatusItem()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        popover.contentViewController?.view.window?.makeKey()
    }

    private func presentContextMenu(_ actions: [StatusItemMenuActionState]) {
        let menu = NSMenu()
        for actionState in actions {
            if actionState.action == .exit {
                menu.addItem(.separator())
            }
            let item = NSMenuItem(title: actionState.action.menuTitle, action: #selector(handleContextMenuSelection(_:)), keyEquivalent: "")
            item.target = self
            item.isEnabled = actionState.isEnabled
            item.representedObject = actionState.action.rawValue
            menu.addItem(item)
        }
        activeContextMenu = menu
        if let contextMenuPopupAction {
            contextMenuPopupAction(menu)
        } else {
            let popupSelector = NSSelectorFromString("popUpStatusItemMenu:")
            _ = statusItem.perform(popupSelector, with: menu)
        }
        activeContextMenu = nil
    }

    @objc private func handleContextMenuSelection(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let action = StatusItemMenuAction(rawValue: rawValue)
        else {
            return
        }
        Task { @MainActor in
            await performMenuAction(action)
        }
    }
}

private enum StatusRingImageRenderer {
    static func image(for presentation: MenuBarSpendPresentation) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        guard let context = NSGraphicsContext.current?.cgContext else {
            return image
        }

        context.setLineWidth(2)
        context.setLineCap(.round)
        context.setStrokeColor(NSColor.secondaryLabelColor.withAlphaComponent(0.35).cgColor)

        let rect = CGRect(x: 2, y: 2, width: 10, height: 10)
        context.strokeEllipse(in: rect)

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius: CGFloat = 5
        let start = CGFloat.pi / 2
        let end = start - (CGFloat(min(1, max(0, presentation.progress))) * 2 * CGFloat.pi)
        context.setStrokeColor(color(for: presentation.band).cgColor)
        context.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
        context.strokePath()

        image.isTemplate = false
        return image
    }

    private static func color(for band: SpendStatusBand) -> NSColor {
        switch band.id {
        case "yellow":
            return NSColor.systemYellow
        case "orange":
            return NSColor.systemOrange
        case "red":
            return NSColor.systemRed
        default:
            return NSColor.systemGreen
        }
    }
}
