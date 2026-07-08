import Foundation
import Observation

@Observable
@MainActor
public final class SpendDashboardViewModel {
    private let spendService: SpendServicing
    private let keyContextService: KeyContextServicing?
    private let apiKeyStore: APIKeyStoring?
    private let menuBarPreferenceStore: MenuBarPreferenceStoring?
    private let configurationStore: MutableAppConfigurationStoring?
    private let releaseUpdateChecker: ReleaseUpdateChecking?
    private let appVersion: String
    private var endpointStateGeneration = 0
    private var appliesGatewayDefaultURLChanges = false

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
    public var spendLimitDraft = ""
    public var baseURLDraft = ""
    public var gatewayProviderDraft: GatewayProvider = .litellm {
        didSet {
            applyGatewayDefaultBaseURLIfNeeded(previousProvider: oldValue)
        }
    }
    public var settingsErrorMessage: String?
    public var menuBarMetric: MenuBarMetric
    public var availableUpdateURL: URL?

    public var menuBarTitle: String {
        menuBarPresentation.label
    }

    public var currentVersionLabel: String {
        let trimmed = appVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "v0.0.0"
        }
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            return trimmed
        }
        return "v\(trimmed)"
    }

    public var gatewayProviderOptions: [GatewayProvider] {
        GatewayProvider.allCases
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
        menuBarPreferenceStore: MenuBarPreferenceStoring? = nil,
        configurationStore: MutableAppConfigurationStoring? = nil,
        releaseUpdateChecker: ReleaseUpdateChecking? = nil,
        appVersion: String = "0.0.0"
    ) {
        self.spendService = spendService
        self.keyContextService = keyContextService
        self.apiKeyStore = apiKeyStore
        self.menuBarPreferenceStore = menuBarPreferenceStore
        self.configurationStore = configurationStore
        self.releaseUpdateChecker = releaseUpdateChecker
        self.appVersion = appVersion
        self.menuBarMetric = (try? menuBarPreferenceStore?.loadMetric()) ?? .dollars
        let configuration = (try? configurationStore?.loadConfiguration()) ?? AppConfiguration()
        self.spendLimitDraft = NSDecimalNumber(decimal: configuration.spendLimitUSD).stringValue
        self.baseURLDraft = configuration.baseURL?.absoluteString ?? ""
        self.gatewayProviderDraft = configuration.gatewayProvider
        self.appliesGatewayDefaultURLChanges = true
        syncSetupState(preservingCurrentError: false)
    }

    public func refreshReleaseAvailability() async {
        guard let releaseUpdateChecker else {
            availableUpdateURL = nil
            return
        }
        availableUpdateURL = await releaseUpdateChecker.checkForUpdate(currentVersion: appVersion)
    }

    public func refresh(now: Date = Date(), calendar: Calendar = .current, isAutomatic: Bool = false) async {
        if isAutomatic && pausesAutomaticRefresh {
            return
        }
        guard !isRefreshing else {
            return
        }
        let refreshGeneration = endpointStateGeneration
        isRefreshing = true
        defer { isRefreshing = false }

        if isAutomatic && selectedRange != .today {
            let todayResult = await spendService.refresh(range: .today, now: now, calendar: calendar)
            guard refreshGeneration == endpointStateGeneration else {
                return
            }
            apply(todayResult, toMenuBarSnapshot: true, toCurrentSnapshot: false)
            if pausesAutomaticRefresh {
                return
            }
            let selectedResult = await spendService.refresh(range: selectedRange, now: now, calendar: calendar)
            guard refreshGeneration == endpointStateGeneration else {
                return
            }
            apply(selectedResult, toMenuBarSnapshot: false, toCurrentSnapshot: true)
        } else {
            let result = await spendService.refresh(range: selectedRange, now: now, calendar: calendar)
            guard refreshGeneration == endpointStateGeneration else {
                return
            }
            let isToday = selectedRange == .today
            apply(result, toMenuBarSnapshot: isToday, toCurrentSnapshot: true)
        }
    }

    public func refreshSelectedMode(now: Date = Date(), calendar: Calendar = .current) async {
        if selectedPopoverMode == .keys {
            await refreshKeyContext(now: now, bypassingCache: true)
        } else {
            await refresh(now: now, calendar: calendar)
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

    public func saveSpendLimit() {
        let trimmedValue = spendLimitDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let spendLimit = Decimal(string: trimmedValue), spendLimit > 0 else {
            settingsErrorMessage = "Daily budget must be a positive dollar amount"
            return
        }
        guard let configurationStore else {
            settingsErrorMessage = "Unable to save settings"
            return
        }

        do {
            let currentConfiguration = try configurationStore.loadConfiguration()
            try configurationStore.saveConfiguration(AppConfiguration(baseURL: currentConfiguration.baseURL, spendLimitUSD: spendLimit, gatewayProvider: currentConfiguration.gatewayProvider))
            applySpendLimit(spendLimit)
            spendLimitDraft = NSDecimalNumber(decimal: spendLimit).stringValue
            settingsErrorMessage = nil
        } catch {
            settingsErrorMessage = "Unable to save settings"
        }
    }

    public func saveBaseURL() {
        let trimmedValue = baseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: trimmedValue)?.normalizedForConfiguration else {
            settingsErrorMessage = "Base URL must be a valid HTTP URL"
            return
        }
        guard let configurationStore else {
            settingsErrorMessage = "Unable to save settings"
            return
        }

        do {
            let currentConfiguration = try configurationStore.loadConfiguration()
            try configurationStore.saveConfiguration(AppConfiguration(baseURL: baseURL, spendLimitUSD: currentConfiguration.spendLimitUSD, gatewayProvider: currentConfiguration.gatewayProvider))
            baseURLDraft = baseURL.absoluteString
            settingsErrorMessage = nil
            clearEndpointScopedState()
            syncSetupState(preservingCurrentError: false)
        } catch {
            settingsErrorMessage = "Unable to save settings"
        }
    }

    public func saveSettings() {
        let trimmedSpendLimit = spendLimitDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let spendLimit = Decimal(string: trimmedSpendLimit), spendLimit > 0 else {
            settingsErrorMessage = "Daily budget must be a positive dollar amount"
            return
        }

        let trimmedBaseURL = baseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: trimmedBaseURL)?.normalizedForConfiguration else {
            settingsErrorMessage = "Base URL must be a valid HTTP URL"
            return
        }

        guard let configurationStore else {
            settingsErrorMessage = "Unable to save settings"
            return
        }

        do {
            let currentConfiguration = try configurationStore.loadConfiguration()
            try configurationStore.saveConfiguration(AppConfiguration(baseURL: baseURL, spendLimitUSD: spendLimit, gatewayProvider: gatewayProviderDraft))

            applySpendLimit(spendLimit)
            spendLimitDraft = NSDecimalNumber(decimal: spendLimit).stringValue
            baseURLDraft = baseURL.absoluteString
            settingsErrorMessage = nil

            if currentConfiguration.baseURL != baseURL || currentConfiguration.gatewayProvider != gatewayProviderDraft {
                clearEndpointScopedState()
                syncSetupState(preservingCurrentError: false)
            }

            selectedPopoverMode = .overview
        } catch {
            settingsErrorMessage = "Unable to save settings"
        }
    }

    public func clearAPIKey() {
        guard let apiKeyStore else {
            errorMessage = "Unable to clear \(currentGatewayDisplayName()) API key"
            return
        }
        do {
            try apiKeyStore.deleteAPIKey()
            apiKeyDraft = ""
            errorMessage = "\(currentGatewayDisplayName()) API key is missing"
            apiKeyDidChange()
        } catch {
            errorMessage = "Unable to clear \(currentGatewayDisplayName()) API key"
        }
    }

    public func selectPopoverMode(_ mode: SpendPopoverMode, now: Date = Date()) async {
        selectedPopoverMode = mode
        if mode == .keys {
            await refreshKeyContext(now: now)
        }
    }

    public func openSettings(now: Date = Date()) async {
        await selectPopoverMode(.settings, now: now)
    }

    public func refreshKeyContext(now: Date = Date(), bypassingCache: Bool = false) async {
        guard let keyContextService, !isKeyContextRefreshing else {
            return
        }
        isKeyContextRefreshing = true
        defer { isKeyContextRefreshing = false }

        let result = await keyContextService.refresh(userContext: userContext, now: now, bypassingCache: bypassingCache)
        switch result {
        case let .refreshed(snapshot):
            keyContextSnapshot = snapshot
            keyContextErrorMessage = nil
        case let .stale(snapshot, message):
            keyContextSnapshot = snapshot
            keyContextErrorMessage = message
        case let .authFailed(message), let .failed(message):
            keyContextSnapshot = nil
            keyContextErrorMessage = message
        }
    }

    public func apiKeyDidChange() {
        clearEndpointScopedState()
        if apiKeyStore == nil && configurationStore == nil {
            requiresSetup = false
            pausesAutomaticRefresh = false
            errorMessage = nil
            return
        }
        syncSetupState(preservingCurrentError: false)
    }

    public func saveAPIKey() {
        let trimmedKey = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            return
        }
        guard let apiKeyStore else {
            errorMessage = "Unable to save \(currentGatewayDisplayName()) API key"
            return
        }
        do {
            try apiKeyStore.saveAPIKey(trimmedKey)
            apiKeyDraft = ""
            errorMessage = nil
            apiKeyDidChange()
        } catch {
            errorMessage = "Unable to save \(currentGatewayDisplayName()) API key"
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

    private func applySpendLimit(_ spendLimit: Decimal) {
        if let currentSnapshot {
            let rangeBudget = budgetLimit(for: currentSnapshot.range, dailyBudget: spendLimit)
            self.currentSnapshot = currentSnapshot.applyingLimit(rangeBudget)
        }
        if let menuBarSnapshot {
            let rangeBudget = budgetLimit(for: menuBarSnapshot.range, dailyBudget: spendLimit)
            self.menuBarSnapshot = menuBarSnapshot.applyingLimit(rangeBudget)
        }
    }

    private func budgetLimit(
        for range: SpendRange,
        dailyBudget: Decimal,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Decimal {
        let dateRange = SpendRangeResolver().dateRange(for: range, now: now, calendar: calendar)
        let start = calendar.startOfDay(for: dateRange.startDate)
        let end = calendar.startOfDay(for: dateRange.endDate)
        let dayDelta = calendar.dateComponents([.day], from: start, to: end).day ?? 1
        let dayCount = max(1, dayDelta)
        return dailyBudget * Decimal(dayCount)
    }

    private func clearSpendSnapshots() {
        currentSnapshot = nil
        menuBarSnapshot = nil
        currentAnalyticsSummary = nil
    }

    private func clearEndpointScopedState() {
        endpointStateGeneration += 1
        clearSpendSnapshots()
        spendService.clearCache()
        keyContextSnapshot = nil
        keyContextErrorMessage = nil
        userContext = nil
        keyContextService?.clearCache()
    }

    private func syncSetupState(preservingCurrentError: Bool = true) {
        var hasAnyStore = false
        var baseURLMissing = false
        var apiKeyMissing = false

        if let configurationStore {
            hasAnyStore = true
            baseURLMissing = (try? configurationStore.loadConfiguration().baseURL) == nil
        }
        if let apiKeyStore {
            hasAnyStore = true
            do {
                _ = try apiKeyStore.readAPIKey()
            } catch {
                apiKeyMissing = true
            }
        }

        guard hasAnyStore else {
            return
        }

        requiresSetup = baseURLMissing || apiKeyMissing
        pausesAutomaticRefresh = requiresSetup

        guard requiresSetup else {
            if !preservingCurrentError {
                errorMessage = nil
            }
            return
        }
        if preservingCurrentError, let errorMessage, !errorMessage.isEmpty {
            return
        }
        if baseURLMissing {
            errorMessage = "\(currentGatewayDisplayName()) base URL is missing"
        } else if apiKeyMissing {
            errorMessage = "\(currentGatewayDisplayName()) API key is missing"
        }
    }

    private func currentGatewayDisplayName() -> String {
        if let configuration = try? configurationStore?.loadConfiguration() {
            return configuration.gatewayProvider.displayName
        }
        return gatewayProviderDraft.displayName
    }

    private func applyGatewayDefaultBaseURLIfNeeded(previousProvider: GatewayProvider) {
        guard appliesGatewayDefaultURLChanges, previousProvider != gatewayProviderDraft else {
            return
        }
        baseURLDraft = gatewayProviderDraft.defaultBaseURL.absoluteString
    }
}
