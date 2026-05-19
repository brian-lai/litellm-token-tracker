import Foundation
import Observation

@Observable
@MainActor
public final class SpendDashboardViewModel {
    private let spendService: SpendServicing
    private let keyContextService: KeyContextServicing?
    private let apiKeyStore: APIKeyStoring?
    private let menuBarPreferenceStore: MenuBarPreferenceStoring?

    public var selectedRange: SpendRange = .today
    public var currentSnapshot: SpendSnapshot?
    public var menuBarSnapshot: SpendSnapshot?
    public var currentAnalyticsSummary: SpendAnalyticsSummary?
    public var userContext: LiteLLMUserContext?
    public var keyContextSnapshot: KeyContextSnapshot?
    public var keyContextErrorMessage: String?
    public var isKeyContextRefreshing = false
    public var selectedPopoverMode: SpendPopoverMode = .overview
    public var errorMessage: String?
    public var isRefreshing = false
    public var requiresSetup = false
    public var pausesAutomaticRefresh = false
    public var apiKeyDraft = ""
    public var menuBarMetric: MenuBarMetric

    public var menuBarTitle: String {
        menuBarPresentation.label
    }

    public var menuBarPresentation: MenuBarSpendPresentation {
        MenuBarSpendPresentation.make(
            menuBarSnapshot: menuBarSnapshot,
            requiresSetup: requiresSetup,
            metric: menuBarMetric
        )
    }

    public init(
        spendService: SpendServicing,
        keyContextService: KeyContextServicing? = nil,
        apiKeyStore: APIKeyStoring? = nil,
        menuBarPreferenceStore: MenuBarPreferenceStoring? = nil
    ) {
        self.spendService = spendService
        self.keyContextService = keyContextService
        self.apiKeyStore = apiKeyStore
        self.menuBarPreferenceStore = menuBarPreferenceStore
        self.menuBarMetric = (try? menuBarPreferenceStore?.loadMetric()) ?? .dollars
    }

    public func refresh(now: Date = Date(), calendar: Calendar = .current, isAutomatic: Bool = false) async {
        if isAutomatic && pausesAutomaticRefresh {
            return
        }
        guard !isRefreshing else {
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        if isAutomatic && selectedRange != .today {
            let todayResult = await spendService.refresh(range: .today, now: now, calendar: calendar)
            apply(todayResult, toMenuBarSnapshot: true, toCurrentSnapshot: false)
            if pausesAutomaticRefresh {
                return
            }
            let selectedResult = await spendService.refresh(range: selectedRange, now: now, calendar: calendar)
            apply(selectedResult, toMenuBarSnapshot: false, toCurrentSnapshot: true)
        } else {
            let result = await spendService.refresh(range: selectedRange, now: now, calendar: calendar)
            let isToday = selectedRange == .today
            apply(result, toMenuBarSnapshot: isToday, toCurrentSnapshot: true)
        }
    }

    public func selectRange(_ range: SpendRange, now: Date = Date(), calendar: Calendar = .current) async {
        guard range != selectedRange else {
            return
        }
        selectedRange = range
        await refresh(now: now, calendar: calendar)
    }

    public func setMenuBarMetric(_ metric: MenuBarMetric) {
        menuBarMetric = metric
        do {
            try menuBarPreferenceStore?.saveMetric(metric)
        } catch {
            errorMessage = "Unable to save menu bar preference"
        }
    }

    public func selectPopoverMode(_ mode: SpendPopoverMode, now: Date = Date()) async {
        selectedPopoverMode = mode
        if mode == .keys, keyContextSnapshot == nil {
            await refreshKeyContext(now: now)
        }
    }

    public func refreshKeyContext(now: Date = Date()) async {
        guard let keyContextService, !isKeyContextRefreshing else {
            return
        }
        isKeyContextRefreshing = true
        defer { isKeyContextRefreshing = false }

        let result = await keyContextService.refresh(userContext: userContext, now: now)
        switch result {
        case let .refreshed(snapshot):
            keyContextSnapshot = snapshot
            keyContextErrorMessage = nil
        case let .stale(snapshot, message):
            keyContextSnapshot = snapshot
            keyContextErrorMessage = message
        case let .authFailed(message), let .failed(message):
            keyContextErrorMessage = message
        }
    }

    public func apiKeyDidChange() {
        pausesAutomaticRefresh = false
        requiresSetup = false
    }

    public func saveAPIKey() {
        let trimmedKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            return
        }
        guard let apiKeyStore else {
            errorMessage = "Unable to save LiteLLM API key"
            return
        }
        do {
            try apiKeyStore.saveAPIKey(trimmedKey)
            apiKeyDraft = ""
            errorMessage = nil
            apiKeyDidChange()
        } catch {
            errorMessage = "Unable to save LiteLLM API key"
        }
    }

    private func apply(_ result: SpendRefreshResult, toMenuBarSnapshot: Bool, toCurrentSnapshot: Bool) {
        switch result {
        case let .refreshed(snapshot):
            if toCurrentSnapshot {
                currentSnapshot = snapshot
                currentAnalyticsSummary = snapshot.analytics
            }
            if toMenuBarSnapshot {
                menuBarSnapshot = snapshot
            }
            if let snapshotUserContext = snapshot.userContext {
                userContext = snapshotUserContext
            }
            errorMessage = nil
            requiresSetup = false
            pausesAutomaticRefresh = false
        case let .stale(snapshot, message):
            if toCurrentSnapshot {
                currentSnapshot = snapshot
                currentAnalyticsSummary = snapshot.analytics ?? currentAnalyticsSummary
            }
            if toMenuBarSnapshot {
                menuBarSnapshot = snapshot
            }
            if let snapshotUserContext = snapshot.userContext {
                userContext = snapshotUserContext
            }
            errorMessage = message
            requiresSetup = false
        case let .setupRequired(message), let .authFailed(message):
            errorMessage = message
            requiresSetup = true
            pausesAutomaticRefresh = true
        case let .failed(message):
            errorMessage = message
            requiresSetup = false
        }
    }
}
