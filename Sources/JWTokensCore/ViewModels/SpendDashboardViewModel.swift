import Foundation
import Observation

@Observable
@MainActor
public final class SpendDashboardViewModel {
    private let spendService: SpendServicing
    private let apiKeyStore: APIKeyStoring?

    public var selectedRange: SpendRange = .today
    public var currentSnapshot: SpendSnapshot?
    public var userContext: LiteLLMUserContext?
    public var errorMessage: String?
    public var isRefreshing = false
    public var requiresSetup = false
    public var pausesAutomaticRefresh = false
    public var apiKeyDraft = ""

    public var menuBarTitle: String {
        if requiresSetup {
            return MenuBarTitleFormatter.setupTitle()
        }
        return MenuBarTitleFormatter.title(for: currentSnapshot)
    }

    public init(
        spendService: SpendServicing,
        apiKeyStore: APIKeyStoring? = nil
    ) {
        self.spendService = spendService
        self.apiKeyStore = apiKeyStore
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

        let result = await spendService.refresh(range: selectedRange, now: now, calendar: calendar)
        switch result {
        case let .refreshed(snapshot):
            currentSnapshot = snapshot
            errorMessage = nil
            requiresSetup = false
            pausesAutomaticRefresh = false
        case let .stale(snapshot, message):
            currentSnapshot = snapshot
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

    public func selectRange(_ range: SpendRange, now: Date = Date(), calendar: Calendar = .current) async {
        guard range != selectedRange else {
            return
        }
        selectedRange = range
        await refresh(now: now, calendar: calendar)
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
        do {
            try apiKeyStore?.saveAPIKey(trimmedKey)
            apiKeyDraft = ""
            errorMessage = nil
            apiKeyDidChange()
        } catch {
            errorMessage = "Unable to save LiteLLM API key"
        }
    }
}
