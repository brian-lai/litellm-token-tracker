import Foundation
import JWTokensCore

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

final class StubURLLoader: URLLoading, @unchecked Sendable {
    var requests: [URLRequest] = []
    var data: Data
    var statusCode: Int
    var error: Error?

    init(data: Data = Data(), statusCode: Int = 200, error: Error? = nil) {
        self.data = data
        self.statusCode = statusCode
        self.error = error
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if let error {
            throw error
        }
        return (
            data,
            HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        )
    }
}

final class CapturingLogger: AppLogging, @unchecked Sendable {
    var events: [AppLogEvent] = []

    func log(_ event: AppLogEvent) {
        events.append(event)
    }
}

final class FakeKeychainGateway: KeychainGateway, @unchecked Sendable {
    var storage: [String: String] = [:]
    var savedValues: [String] = []

    func read(service: String, account: String) throws -> String? {
        storage["\(service):\(account)"]
    }

    func save(_ value: String, service: String, account: String) throws {
        savedValues.append(value)
        storage["\(service):\(account)"] = value
    }

    func delete(service: String, account: String) throws {
        storage.removeValue(forKey: "\(service):\(account)")
    }
}

struct FakeAPIKeyStore: APIKeyStoring {
    let result: Result<String, Error>

    func readAPIKey() throws -> String {
        try result.get()
    }

    func saveAPIKey(_ apiKey: String) throws {}
    func deleteAPIKey() throws {}
}

final class MutableAPIKeyStore: APIKeyStoring, @unchecked Sendable {
    var savedKeys: [String] = []

    func readAPIKey() throws -> String {
        savedKeys.last ?? ""
    }

    func saveAPIKey(_ apiKey: String) throws {
        savedKeys.append(apiKey)
    }

    func deleteAPIKey() throws {
        savedKeys.removeAll()
    }
}

enum FakePreferenceError: Error {
    case failed
}

final class FakeMenuBarPreferenceStore: MenuBarPreferenceStoring, @unchecked Sendable {
    var metric: MenuBarMetric
    var savedMetrics: [MenuBarMetric] = []
    var loadError: Error?
    var saveError: Error?

    init(metric: MenuBarMetric = .dollars, loadError: Error? = nil, saveError: Error? = nil) {
        self.metric = metric
        self.loadError = loadError
        self.saveError = saveError
    }

    func loadMetric() throws -> MenuBarMetric {
        if let loadError {
            throw loadError
        }
        return metric
    }

    func saveMetric(_ metric: MenuBarMetric) throws {
        if let saveError {
            throw saveError
        }
        savedMetrics.append(metric)
        self.metric = metric
    }
}

struct FakeClient: LiteLLMClientProtocol {
    var userResult: Result<LiteLLMUserContext, Error>
    var activityResult: Result<SpendAnalyticsSummary, Error>?
    var rowsResult: Result<[SpendLogSummaryRow], Error>
    var currentKeyResult: Result<KeySpendSummary, Error> = .success(KeySpendSummary(alias: nil, name: nil, spendUSD: 0, maxBudgetUSD: nil, budgetResetAt: nil, lastActiveAt: nil))
    var userKeysResult: Result<[KeySpendSummary], Error> = .success([])

    func fetchCurrentUser() async throws -> LiteLLMUserContext {
        try userResult.get()
    }

    func fetchUserDailyActivity(range: DateRange, userID: String) async throws -> SpendAnalyticsSummary {
        if let activityResult {
            return try activityResult.get()
        }
        throw LiteLLMClientError.unavailable
    }

    func fetchSpendRows(range: DateRange, userID: String) async throws -> [SpendLogSummaryRow] {
        try rowsResult.get()
    }

    func fetchCurrentKey() async throws -> KeySpendSummary {
        try currentKeyResult.get()
    }

    func fetchUserKeys(userID: String) async throws -> [KeySpendSummary] {
        try userKeysResult.get()
    }
}

final class RecordingSpendService: SpendServicing, @unchecked Sendable {
    var results: [SpendRefreshResult]
    var requestedRanges: [SpendRange] = []

    init(results: [SpendRefreshResult]) {
        self.results = results
    }

    func refresh(range: SpendRange, now: Date, calendar: Calendar) async -> SpendRefreshResult {
        requestedRanges.append(range)
        return results.removeFirst()
    }
}

actor SuspendingSpendService: SpendServicing {
    private var continuation: CheckedContinuation<SpendRefreshResult, Never>?
    private(set) var callCount = 0

    func refresh(range: SpendRange, now: Date, calendar: Calendar) async -> SpendRefreshResult {
        callCount += 1
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume(with result: SpendRefreshResult) {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(returning: result)
    }
}

final class FakeRefreshScheduler: RefreshScheduling, @unchecked Sendable {
    var interval: TimeInterval?
    var operation: (@Sendable () async -> Void)?
    var didStop = false

    func start(every seconds: TimeInterval, operation: @escaping @Sendable () async -> Void) {
        interval = seconds
        self.operation = operation
    }

    func stop() {
        didStop = true
        operation = nil
    }

    func fire() async {
        await operation?()
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw TestFailure(description: message)
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) throws {
    if actual != expected {
        throw TestFailure(description: "\(message). Expected \(expected), got \(actual)")
    }
}

func fixtureData(_ name: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: name, withExtension: nil) else {
        throw TestFailure(description: "Missing fixture: \(name)")
    }
    return try Data(contentsOf: url)
}

func testTestRunnerLoadsCoreTarget() throws {
    try expect(SpendRange.today.rawValue == "today", "SpendRange.today raw value should be stable")
}

func testDecodesUserInfoSpendAndBudget() throws {
    let context = try LiteLLMResponseDecoder.decodeUserInfo(from: fixtureData("user-info.json"))

    try expectEqual(context.userID, "4a5641d6-f56a-4657-aa55-98cb447fec95", "user_id should decode")
    try expectEqual(context.email, "blai@example.com", "user email should decode")
    try expectEqual(context.totalSpendUSD, Decimal(string: "524.3974209499993")!, "user spend should decode as Decimal")
    try expectEqual(context.maxBudgetUSD, Decimal(2400), "max budget should decode")
    try expect(context.budgetResetAt != nil, "budget reset date should decode")
}

func testDecodesCurrentKeyInfoSafeFieldsOnly() throws {
    let summary = try LiteLLMResponseDecoder.decodeCurrentKey(from: fixtureData("key-info.json"))

    try expectEqual(summary.alias, "Claude Code", "key alias should decode")
    try expectEqual(summary.name, "claude-code-key", "key name should decode")
    try expectEqual(summary.spendUSD, Decimal(string: "65.5663")!, "key spend should decode")
    try expectEqual(summary.maxBudgetUSD, 80, "key budget should decode")
    try expect(summary.budgetResetAt != nil, "budget reset should decode")
    try expect(summary.lastActiveAt != nil, "last active should decode")
}

func testDecodesUserKeyListAliasesAndBudgets() throws {
    let summaries = try LiteLLMResponseDecoder.decodeUserKeys(from: fixtureData("key-list.json"))

    try expectEqual(summaries.count, 2, "key list should decode keys")
    try expectEqual(summaries[0].displayName, "Claude Code", "alias should be preferred for display")
    try expectEqual(summaries[0].maxBudgetUSD, 80, "key budget should decode")
    try expectEqual(summaries[1].displayName, "fallback-name", "key name should be fallback display")
}

func testKeyDTOsDoNotExposeRawTokenFields() throws {
    let summary = try LiteLLMResponseDecoder.decodeCurrentKey(from: fixtureData("key-info.json"))
    let summaries = try LiteLLMResponseDecoder.decodeUserKeys(from: fixtureData("key-list.json"))
    let rendered = String(describing: summary) + String(describing: summaries)

    try expect(!rendered.contains("sk-should-not-decode"), "decoded key DTOs should not expose raw api_key")
    try expect(!rendered.contains("token-should-not-decode"), "decoded key DTOs should not expose raw token")
}

func testDecodesSummarizedSpendRows() throws {
    let result = try LiteLLMResponseDecoder.decodeSpendRows(from: fixtureData("spend-logs-summary.json"))

    try expectEqual(result.rows.count, 3, "three rows should decode with valid dates")
    try expectEqual(result.rows[0].spendUSD, Decimal(string: "7.5715082499999955")!, "first spend row should decode")
    try expectEqual(result.rows[1].spendUSD, 0, "zero spend row should decode")
}

func testDecodesMissingSpendAsZero() throws {
    let result = try LiteLLMResponseDecoder.decodeSpendRows(from: fixtureData("spend-logs-summary.json"))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let row = result.rows.first { calendar.component(.day, from: $0.date) == 17 }

    try expectEqual(row?.spendUSD, 0, "missing spend should decode as zero")
}

func testSkipsRowsWithUnparseableDates() throws {
    let result = try LiteLLMResponseDecoder.decodeSpendRows(from: fixtureData("spend-logs-summary.json"))

    try expectEqual(result.skippedRowCount, 2, "invalid and missing startTime rows should be skipped")
}

func testFullyInvalidSpendLogsResponseMapsToMalformedResponse() throws {
    do {
        _ = try LiteLLMResponseDecoder.decodeSpendRows(from: Data(#"{"not":"an array"}"#.utf8))
        throw TestFailure(description: "invalid top-level response should throw")
    } catch LiteLLMClientError.malformedResponse {
        return
    }
}

func testDecodesUserDailyActivitySummary() throws {
    let timeZone = TimeZone(identifier: "America/New_York")!
    let result = try LiteLLMResponseDecoder.decodeUserDailyActivity(
        from: fixtureData("user-daily-activity.json"),
        calendar: fixedCalendar(timeZone: timeZone)
    )

    try expectEqual(result.summary.totalSpendUSD, Decimal(string: "65.5663")!, "activity metadata total should decode")
    try expectEqual(result.summary.dailyPoints.count, 2, "valid activity rows should decode into daily points")
    try expectEqual(result.summary.dailyPoints[0].spendUSD, Decimal(string: "48.498672049999996")!, "activity spend should decode oldest-first")
    try expectEqual(result.skippedRowCount, 1, "unparseable dates should be skipped")
}

func testUserDailyActivityFallbackSumsRowsWhenMetadataTotalIsMissing() throws {
    let data = Data(#"{"results":[{"date":"2026-05-18","metrics":{"spend":2.5}},{"date":"2026-05-19","metrics":{"spend":3}}]}"#.utf8)
    let result = try LiteLLMResponseDecoder.decodeUserDailyActivity(from: data, calendar: fixedCalendar())

    try expectEqual(result.summary.totalSpendUSD, Decimal(string: "5.5")!, "decoder should sum activity rows when metadata total is absent")
}

func testAnalyticsSummaryStoresUsageTotals() throws {
    let totals = SpendUsageTotals(
        totalTokens: 30,
        promptTokens: 10,
        completionTokens: 20,
        cacheCreationTokens: 4,
        cacheReadTokens: 5,
        apiRequests: 3,
        successfulRequests: 2,
        failedRequests: 1
    )
    let summary = SpendAnalyticsSummary(
        totalSpendUSD: Decimal(string: "12.34")!,
        totals: totals,
        dailyPoints: [
            DailyActivityPoint(date: try fixedDate("2026-05-18"), spendUSD: 12, totals: totals)
        ],
        breakdowns: [:],
        source: .userDailyActivity
    )

    try expectEqual(summary.totalSpendUSD, Decimal(string: "12.34")!, "analytics summary should store total spend")
    try expectEqual(summary.totals.totalTokens, 30, "analytics summary should store total tokens")
    try expectEqual(summary.totals.failedRequests, 1, "analytics summary should store failed requests")
    try expectEqual(summary.dailyPoints.first?.totals.promptTokens, 10, "daily activity points should carry usage totals")
}

func testAnalyticsSummaryStoresBreakdownItemsWithoutPresentationPercents() throws {
    let item = SpendBreakdownItem(label: "claude-sonnet", spendUSD: Decimal(string: "9.25")!, tokens: 1000, requests: 4)
    let summary = SpendAnalyticsSummary(
        totalSpendUSD: Decimal(string: "9.25")!,
        totals: .zero,
        dailyPoints: [],
        breakdowns: [.models: [item]],
        source: .userDailyActivity
    )

    try expectEqual(summary.breakdowns[.models], [item], "analytics summary should store model breakdown items")
    try expectEqual(summary.breakdowns[.models]?.first?.tokens, 1000, "breakdown items should store optional tokens")
    try expectEqual(summary.breakdowns[.models]?.first?.requests, 4, "breakdown items should store optional requests")
}

func testSpendDataSourceCasesAreStable() throws {
    try expectEqual(SpendDataSource.userDailyActivity.rawValue, "userDailyActivity", "activity source raw value should be stable")
    try expectEqual(SpendDataSource.spendLogsFallback.rawValue, "spendLogsFallback", "fallback source raw value should be stable")
    try expectEqual(SpendDataSource.staleCache.rawValue, "staleCache", "stale source raw value should be stable")
}

func testDecodesUserDailyActivityUsageTotals() throws {
    let result = try LiteLLMResponseDecoder.decodeUserDailyActivity(
        from: fixtureData("user-daily-activity-breakdown.json"),
        calendar: fixedCalendar()
    )

    try expectEqual(result.analytics.totalSpendUSD, Decimal(string: "12.5")!, "analytics total spend should decode from metadata")
    try expectEqual(result.analytics.totals.totalTokens, 3000, "metadata total tokens should decode")
    try expectEqual(result.analytics.totals.promptTokens, 1200, "metadata prompt tokens should decode")
    try expectEqual(result.analytics.totals.completionTokens, 1800, "metadata completion tokens should decode")
    try expectEqual(result.analytics.totals.apiRequests, 3, "metadata request count should decode")
    try expectEqual(result.analytics.totals.failedRequests, 1, "metadata failed request count should decode")
    try expectEqual(result.analytics.dailyPoints.first?.totals.totalTokens, 2000, "daily point token totals should decode")
}

func testDecodesUserDailyActivityModelBreakdown() throws {
    let result = try LiteLLMResponseDecoder.decodeUserDailyActivity(
        from: fixtureData("user-daily-activity-breakdown.json"),
        calendar: fixedCalendar()
    )
    let models = result.analytics.breakdowns[.models] ?? []

    try expectEqual(models.count, 2, "valid model breakdown items should decode")
    try expectEqual(models.first { $0.label == "claude-sonnet" }?.spendUSD, Decimal(string: "10.5")!, "same model spend should aggregate across days")
    try expectEqual(models.first { $0.label == "claude-sonnet" }?.tokens, 2500, "same model tokens should aggregate across days")
    try expectEqual(models.first { $0.label == "claude-sonnet" }?.requests, 2, "same model request counts should aggregate across days")
    try expectEqual(models.first { $0.label == "gpt-4.1" }?.spendUSD, 2, "nested metrics breakdown values should decode")
}

func testSkipsMalformedBreakdownItems() throws {
    let result = try LiteLLMResponseDecoder.decodeUserDailyActivity(
        from: fixtureData("user-daily-activity-breakdown.json"),
        calendar: fixedCalendar()
    )
    let labels = Set((result.analytics.breakdowns[.models] ?? []).map(\.label))

    try expect(!labels.contains("bad_model"), "malformed breakdown values should be skipped")
}

func testMalformedBreakdownObjectDoesNotDropActivityTotals() throws {
    let data = Data(#"{"metadata":{"total_spend":7,"total_tokens":100},"results":[{"date":"2026-05-18","metrics":{"spend":7,"total_tokens":100},"breakdown":"not-an-object"}]}"#.utf8)
    let result = try LiteLLMResponseDecoder.decodeUserDailyActivity(from: data, calendar: fixedCalendar())

    try expectEqual(result.analytics.totalSpendUSD, 7, "malformed breakdown object should not drop total spend")
    try expectEqual(result.analytics.totals.totalTokens, 100, "malformed breakdown object should not drop usage totals")
    try expectEqual(result.analytics.dailyPoints.count, 1, "malformed breakdown object should not drop daily points")
    try expectEqual(result.analytics.breakdowns, [:], "malformed breakdown object should produce empty breakdowns")
}

func testUserDailyActivityAnalyticsPointsAreSortedOldestFirst() throws {
    let result = try LiteLLMResponseDecoder.decodeUserDailyActivity(
        from: fixtureData("user-daily-activity.json"),
        calendar: fixedCalendar()
    )

    try expectEqual(result.analytics.dailyPoints.map(\.date), result.analytics.dailyPoints.map(\.date).sorted(), "analytics daily points should be normalized oldest first")
}

func fixedCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

func fixedCalendar(timeZone: TimeZone) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar
}

func fixedDate(_ value: String) throws -> Date {
    let formatter = DateFormatter()
    formatter.calendar = fixedCalendar()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: value) else {
        throw TestFailure(description: "Invalid fixed date \(value)")
    }
    return date
}

func fixedDate(_ value: String, timeZone: TimeZone) throws -> Date {
    let formatter = DateFormatter()
    formatter.calendar = fixedCalendar(timeZone: timeZone)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: value) else {
        throw TestFailure(description: "Invalid fixed date \(value)")
    }
    return date
}

func testDecodesSummarizedSpendRowsInRequestedTimezone() throws {
    let timeZone = TimeZone(identifier: "America/New_York")!
    let result = try LiteLLMResponseDecoder.decodeSpendRows(
        from: Data(#"[{"startTime":"2026-05-18","spend":8}]"#.utf8),
        calendar: fixedCalendar(timeZone: timeZone)
    )

    try expectEqual(result.rows.first?.date, try fixedDate("2026-05-18", timeZone: timeZone), "date-only spend rows should decode at local start of day")
}

func testTodayUsesTomorrowAsExclusiveEnd() throws {
    let calendar = fixedCalendar()
    let now = try fixedDate("2026-05-18")
    let range = SpendRangeResolver().dateRange(for: .today, now: now, calendar: calendar)

    try expectEqual(range.startDate, try fixedDate("2026-05-18"), "today starts at local start of day")
    try expectEqual(range.endDate, try fixedDate("2026-05-19"), "today ends at tomorrow exclusive")
}

func testLast7DaysIncludesTodayAndSixPriorDays() throws {
    let calendar = fixedCalendar()
    let now = try fixedDate("2026-05-18")
    let range = SpendRangeResolver().dateRange(for: .last7Days, now: now, calendar: calendar)

    try expectEqual(range.startDate, try fixedDate("2026-05-12"), "last 7 days should include today plus six prior days")
    try expectEqual(range.endDate, try fixedDate("2026-05-19"), "last 7 days should end tomorrow exclusive")
}

func testMonthToDateStartsAtFirstOfMonth() throws {
    let calendar = fixedCalendar()
    let now = try fixedDate("2026-05-18")
    let range = SpendRangeResolver().dateRange(for: .monthToDate, now: now, calendar: calendar)

    try expectEqual(range.startDate, try fixedDate("2026-05-01"), "month-to-date should start on first day of month")
    try expectEqual(range.endDate, try fixedDate("2026-05-19"), "month-to-date should end tomorrow exclusive")
}

func utcDateRange(start: String = "2026-05-18", end: String = "2026-05-19") throws -> DateRange {
    DateRange(startDate: try fixedDate(start), endDate: try fixedDate(end), timeZone: TimeZone(secondsFromGMT: 0)!)
}

func testSumsRowsAndComputesLimitPercent() throws {
    let dateRange = try utcDateRange()
    let rows = [
        SpendLogSummaryRow(date: try fixedDate("2026-05-18"), spendUSD: Decimal(string: "5.25")!),
        SpendLogSummaryRow(date: try fixedDate("2026-05-18"), spendUSD: Decimal(string: "2.75")!)
    ]

    let snapshot = SpendAggregator.snapshot(rows: rows, range: .today, dateRange: dateRange, limitUSD: 80, refreshedAt: try fixedDate("2026-05-19"))

    try expectEqual(snapshot.totalSpendUSD, 8, "snapshot should sum spend rows")
    try expectEqual(snapshot.percentOfLimit, Decimal(string: "0.1")!, "snapshot should compute total over limit")
    try expectEqual(snapshot.dailyPoints.count, 1, "same-day rows should group into one daily point")
}

func testDropsExclusiveEndDateRowsFromDailyPoints() throws {
    let dateRange = try utcDateRange()
    let rows = [
        SpendLogSummaryRow(date: try fixedDate("2026-05-18"), spendUSD: 7),
        SpendLogSummaryRow(date: try fixedDate("2026-05-19"), spendUSD: 0)
    ]

    let snapshot = SpendAggregator.snapshot(rows: rows, range: .today, dateRange: dateRange, limitUSD: 80, refreshedAt: try fixedDate("2026-05-19"))

    try expectEqual(snapshot.dailyPoints.count, 1, "exclusive end date row should not become a daily chart point")
    try expectEqual(snapshot.dailyPoints[0].date, try fixedDate("2026-05-18"), "daily point should be the requested start date")
}

func testUserInfoRequestUsesAuthorizationBearer() async throws {
    let loader = StubURLLoader(data: try fixtureData("user-info.json"))
    let client = LiteLLMClient(baseURL: URL(string: "https://litellm.justworksai.net")!, apiKey: "secret-token", loader: loader)

    _ = try await client.fetchCurrentUser()

    try expectEqual(loader.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token", "Authorization header should use bearer token")
    try expectEqual(loader.requests.first?.url?.path, "/user/info", "user info request path should be correct")
}

func testSpendLogsRequestUsesSummarizeTrueAndExclusiveEndDate() async throws {
    let loader = StubURLLoader(data: try fixtureData("spend-logs-summary.json"))
    let client = LiteLLMClient(baseURL: URL(string: "https://litellm.justworksai.net")!, apiKey: "secret-token", loader: loader)
    let range = try utcDateRange()

    _ = try await client.fetchSpendRows(range: range, userID: "user-123")

    let components = URLComponents(url: loader.requests.first!.url!, resolvingAgainstBaseURL: false)
    let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    try expectEqual(query["user_id"], "user-123", "user_id query should be present")
    try expectEqual(query["start_date"], "2026-05-18", "start date query should be present")
    try expectEqual(query["end_date"], "2026-05-19", "exclusive end date query should be present")
    try expectEqual(query["summarize"], "true", "summarize query should be true")
}

func testKeyInfoRequestUsesCurrentKeyByDefault() async throws {
    let loader = StubURLLoader(data: try fixtureData("key-info.json"))
    let client = LiteLLMClient(baseURL: URL(string: "https://litellm.justworksai.net")!, apiKey: "secret-token", loader: loader)

    _ = try await client.fetchCurrentKey()

    try expectEqual(loader.requests.first?.url?.path, "/key/info", "key info request path should be correct")
    try expectEqual(loader.requests.first?.url?.query, nil, "current key info should not require query parameters")
}

func testKeyListRequestFiltersByUserID() async throws {
    let loader = StubURLLoader(data: try fixtureData("key-list.json"))
    let client = LiteLLMClient(baseURL: URL(string: "https://litellm.justworksai.net")!, apiKey: "secret-token", loader: loader)

    _ = try await client.fetchUserKeys(userID: "user-123")

    let components = URLComponents(url: loader.requests.first!.url!, resolvingAgainstBaseURL: false)
    let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    try expectEqual(loader.requests.first?.url?.path, "/key/list", "key list request path should be correct")
    try expectEqual(query["user_id"], "user-123", "key list should filter by user id")
    try expectEqual(query["size"], "100", "key list should request bounded page size")
}

func testKeyListRequestDoesNotRequestFullObjects() async throws {
    let loader = StubURLLoader(data: try fixtureData("key-list.json"))
    let client = LiteLLMClient(baseURL: URL(string: "https://litellm.justworksai.net")!, apiKey: "secret-token", loader: loader)

    _ = try await client.fetchUserKeys(userID: "user-123")

    let components = URLComponents(url: loader.requests.first!.url!, resolvingAgainstBaseURL: false)
    let queryNames = Set((components?.queryItems ?? []).map(\.name))
    try expect(!queryNames.contains("return_full_object"), "key list should not request full key objects")
}

func testUserDailyActivityRequestUsesInclusiveEndDateAndTimezone() async throws {
    let loader = StubURLLoader(data: try fixtureData("user-daily-activity.json"))
    let client = LiteLLMClient(baseURL: URL(string: "https://litellm.justworksai.net")!, apiKey: "secret-token", loader: loader)
    let timeZone = TimeZone(identifier: "America/New_York")!
    let range = DateRange(
        startDate: try fixedDate("2026-05-18", timeZone: timeZone),
        endDate: try fixedDate("2026-05-19", timeZone: timeZone),
        timeZone: timeZone
    )

    _ = try await client.fetchUserDailyActivity(range: range, userID: "user-123")

    let components = URLComponents(url: loader.requests.first!.url!, resolvingAgainstBaseURL: false)
    let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    try expectEqual(loader.requests.first?.url?.path, "/user/daily/activity", "activity request path should be correct")
    try expectEqual(query["user_id"], "user-123", "user_id query should be present")
    try expectEqual(query["start_date"], "2026-05-18", "start date query should be present")
    try expectEqual(query["end_date"], "2026-05-18", "activity end date should be inclusive")
    try expectEqual(query["timezone"], "240", "timezone should use JavaScript offset minutes")
    try expectEqual(query["page_size"], "1000", "activity request should fetch enough daily rows for supported ranges")
}

func testMapsUnauthorized() async throws {
    let loader = StubURLLoader(data: Data(#"{"error":"no"}"#.utf8), statusCode: 401)
    let client = LiteLLMClient(baseURL: URL(string: "https://litellm.justworksai.net")!, apiKey: "secret-token", loader: loader)

    do {
        _ = try await client.fetchCurrentUser()
        throw TestFailure(description: "401 should throw unauthorized")
    } catch LiteLLMClientError.unauthorized {
        return
    }
}

func testMapsFullyInvalidJSONToMalformedResponse() async throws {
    let loader = StubURLLoader(data: Data(#"{"not":"array"}"#.utf8), statusCode: 200)
    let client = LiteLLMClient(baseURL: URL(string: "https://litellm.justworksai.net")!, apiKey: "secret-token", loader: loader)
    let range = try utcDateRange()

    do {
        _ = try await client.fetchSpendRows(range: range, userID: "user-123")
        throw TestFailure(description: "invalid JSON shape should throw malformedResponse")
    } catch LiteLLMClientError.malformedResponse {
        return
    }
}

func testRedactsAuthorizationHeaderFromLogs() async throws {
    let logger = CapturingLogger()
    let loader = StubURLLoader(data: try fixtureData("user-info.json"))
    let client = LiteLLMClient(baseURL: URL(string: "https://litellm.justworksai.net")!, apiKey: "secret-token", loader: loader, logger: logger)

    _ = try await client.fetchCurrentUser()

    try expect(!String(describing: logger.events).contains("secret-token"), "logs should not contain the API key")
    try expect(!String(describing: logger.events).contains("Bearer"), "logs should not contain authorization header values")
}

func testFetchSpendRowsDoesNotComputeSnapshot() async throws {
    let loader = StubURLLoader(data: try fixtureData("spend-logs-summary.json"))
    let client = LiteLLMClient(baseURL: URL(string: "https://litellm.justworksai.net")!, apiKey: "secret-token", loader: loader)
    let range = try utcDateRange()

    let rows = try await client.fetchSpendRows(range: range, userID: "user-123")

    try expectEqual(rows.count, 3, "client should return decoded rows, not an aggregated snapshot")
}

func testFetchUserDailyActivityDoesNotLogPayloads() async throws {
    let logger = CapturingLogger()
    let loader = StubURLLoader(data: try fixtureData("user-daily-activity.json"))
    let client = LiteLLMClient(baseURL: URL(string: "https://litellm.justworksai.net")!, apiKey: "secret-token", loader: loader, logger: logger)
    let analytics = try await client.fetchUserDailyActivity(range: try utcDateRange(), userID: "user-123")

    try expectEqual(analytics.totalSpendUSD, Decimal(string: "65.5663")!, "client should return decoded activity total")
    try expect(!String(describing: logger.events).contains("65.5663"), "logs should not include raw spend payload values")
}

func testSaveReadDeleteUsesGateway() throws {
    let gateway = FakeKeychainGateway()
    let store = KeychainAPIKeyStore(service: "svc", account: "acct", gateway: gateway)

    try store.saveAPIKey("secret-token")
    try expectEqual(try store.readAPIKey(), "secret-token", "saved key should read back through gateway")
    try store.deleteAPIKey()

    do {
        _ = try store.readAPIKey()
        throw TestFailure(description: "deleted key should be missing")
    } catch APIKeyStoreError.missingKey {
        return
    }
}

func testMissingKeyMapsToSetupRequired() throws {
    let store = KeychainAPIKeyStore(service: "svc", account: "acct", gateway: FakeKeychainGateway())

    do {
        _ = try store.readAPIKey()
        throw TestFailure(description: "missing key should throw")
    } catch APIKeyStoreError.missingKey {
        return
    }
}

func testLocalFileAPIKeyStoreSaveReadDelete() throws {
    let fileURL = temporaryAPIKeyFileURL()
    let store = LocalFileAPIKeyStore(fileURL: fileURL)

    try store.saveAPIKey("secret-token\n")
    try expectEqual(try store.readAPIKey(), "secret-token", "file store should trim surrounding newlines")
    try store.deleteAPIKey()

    do {
        _ = try store.readAPIKey()
        throw TestFailure(description: "deleted file key should be missing")
    } catch APIKeyStoreError.missingKey {
        return
    }
}

func testLocalFileAPIKeyStoreMissingFileMapsToMissingKey() throws {
    let store = LocalFileAPIKeyStore(fileURL: temporaryAPIKeyFileURL())

    do {
        _ = try store.readAPIKey()
        throw TestFailure(description: "missing file should throw missingKey")
    } catch APIKeyStoreError.missingKey {
        return
    }
}

func testLocalFileAPIKeyStoreUsesPrivatePermissions() throws {
    let fileURL = temporaryAPIKeyFileURL()
    let store = LocalFileAPIKeyStore(fileURL: fileURL)

    try store.saveAPIKey("secret-token")

    let directoryPermissions = try permissions(at: fileURL.deletingLastPathComponent())
    let filePermissions = try permissions(at: fileURL)
    try expectEqual(directoryPermissions, 0o700, "credential directory should be private")
    try expectEqual(filePermissions, 0o600, "credential file should be private")
}

func temporaryAPIKeyFileURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("jw_tokens_tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("litellm_api_key", isDirectory: false)
}

func permissions(at url: URL) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    guard let value = attributes[.posixPermissions] as? NSNumber else {
        throw TestFailure(description: "missing POSIX permissions for \(url.path)")
    }
    return value.intValue & 0o777
}

func testDoesNotExposeKeyInErrorDescription() throws {
    let errorDescription = APIKeyStoreError.unavailable.description

    try expect(!errorDescription.contains("secret-token"), "error description should not expose API keys")
}

func testRefreshFetchesUserThenTodaySpend() async throws {
    let cache = InMemorySpendSnapshotCache()
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .success("secret-token")),
        configurationStore: StaticAppConfigurationStore(configuration: AppConfiguration(spendLimitUSD: 80)),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .success(LiteLLMUserContext(userID: "user-123", email: nil, totalSpendUSD: 100, maxBudgetUSD: nil, budgetResetAt: nil)),
                rowsResult: .success([SpendLogSummaryRow(date: try! fixedDate("2026-05-18"), spendUSD: 8)])
            )
        },
        cache: cache
    )

    let result = await service.refresh(range: .today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    guard case let .refreshed(snapshot) = result else {
        throw TestFailure(description: "expected refreshed result")
    }
    try expectEqual(snapshot.totalSpendUSD, 8, "service should aggregate today's spend")
}

func testRefreshPrefersDailyActivitySummary() async throws {
    let activity = analyticsSummary(
        totalSpendUSD: Decimal(string: "65.5663")!,
        dailyPoints: [
            DailySpendPoint(date: try fixedDate("2026-05-18"), spendUSD: Decimal(string: "48.498672049999996")!),
            DailySpendPoint(date: try fixedDate("2026-05-19"), spendUSD: Decimal(string: "17.067627950000004")!)
        ]
    )
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .success("secret-token")),
        configurationStore: StaticAppConfigurationStore(configuration: AppConfiguration(spendLimitUSD: 80)),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .success(LiteLLMUserContext(userID: "user-123", email: nil, totalSpendUSD: 100, maxBudgetUSD: nil, budgetResetAt: nil)),
                activityResult: .success(activity),
                rowsResult: .success([SpendLogSummaryRow(date: try! fixedDate("2026-05-18"), spendUSD: 8)])
            )
        }
    )

    let result = await service.refresh(range: .today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    guard case let .refreshed(snapshot) = result else {
        throw TestFailure(description: "expected refreshed result")
    }
    try expectEqual(snapshot.totalSpendUSD, Decimal(string: "65.5663")!, "service should prefer activity summary total")
    try expectEqual(snapshot.percentOfLimit, Decimal(string: "0.81957875")!, "percent should be based on activity total")
    try expectEqual(snapshot.dailyPoints.count, 2, "activity points should be preserved for the chart")
}

func testRefreshMarksActivitySource() async throws {
    let activity = analyticsSummary(totalSpendUSD: 12, dailyPoints: [
        DailySpendPoint(date: try fixedDate("2026-05-18"), spendUSD: 12)
    ])
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .success("secret-token")),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .success(LiteLLMUserContext(userID: "user-123", email: nil, totalSpendUSD: 100, maxBudgetUSD: nil, budgetResetAt: nil)),
                activityResult: .success(activity),
                rowsResult: .success([])
            )
        }
    )

    let result = await service.refresh(range: .today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    guard case let .refreshed(snapshot) = result else {
        throw TestFailure(description: "expected refreshed result")
    }
    try expectEqual(snapshot.analytics?.source, .userDailyActivity, "activity refresh should mark analytics source")
}

func testRefreshFallsBackToSpendLogsWhenDailyActivityUnavailable() async throws {
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .success("secret-token")),
        configurationStore: StaticAppConfigurationStore(configuration: AppConfiguration(spendLimitUSD: 80)),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .success(LiteLLMUserContext(userID: "user-123", email: nil, totalSpendUSD: 100, maxBudgetUSD: nil, budgetResetAt: nil)),
                activityResult: .failure(LiteLLMClientError.unavailable),
                rowsResult: .success([SpendLogSummaryRow(date: try! fixedDate("2026-05-18"), spendUSD: 8)])
            )
        }
    )

    let result = await service.refresh(range: .today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    guard case let .refreshed(snapshot) = result else {
        throw TestFailure(description: "expected refreshed result")
    }
    try expectEqual(snapshot.totalSpendUSD, 8, "service should fall back to summarized spend logs")
}

func testRefreshMarksSpendLogsFallbackSource() async throws {
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .success("secret-token")),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .success(LiteLLMUserContext(userID: "user-123", email: nil, totalSpendUSD: 100, maxBudgetUSD: nil, budgetResetAt: nil)),
                activityResult: .failure(LiteLLMClientError.unavailable),
                rowsResult: .success([SpendLogSummaryRow(date: try! fixedDate("2026-05-18"), spendUSD: 8)])
            )
        }
    )

    let result = await service.refresh(range: .today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    guard case let .refreshed(snapshot) = result else {
        throw TestFailure(description: "expected refreshed result")
    }
    try expectEqual(snapshot.analytics?.source, .spendLogsFallback, "spend logs fallback should mark analytics source")
}

func testFallbackAnalyticsHasEmptyBreakdowns() async throws {
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .success("secret-token")),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .success(LiteLLMUserContext(userID: "user-123", email: nil, totalSpendUSD: 100, maxBudgetUSD: nil, budgetResetAt: nil)),
                activityResult: .failure(LiteLLMClientError.unavailable),
                rowsResult: .success([SpendLogSummaryRow(date: try! fixedDate("2026-05-18"), spendUSD: 8)])
            )
        }
    )

    let result = await service.refresh(range: .today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    guard case let .refreshed(snapshot) = result else {
        throw TestFailure(description: "expected refreshed result")
    }
    try expectEqual(snapshot.analytics?.breakdowns, [:], "fallback analytics should not invent breakdowns")
}

func testRefreshFallsBackToSpendLogsWhenDailyActivityIsUnauthorized() async throws {
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .success("secret-token")),
        configurationStore: StaticAppConfigurationStore(configuration: AppConfiguration(spendLimitUSD: 80)),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .success(LiteLLMUserContext(userID: "user-123", email: nil, totalSpendUSD: 100, maxBudgetUSD: nil, budgetResetAt: nil)),
                activityResult: .failure(LiteLLMClientError.unauthorized),
                rowsResult: .success([SpendLogSummaryRow(date: try! fixedDate("2026-05-18"), spendUSD: 8)])
            )
        }
    )

    let result = await service.refresh(range: .today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    guard case let .refreshed(snapshot) = result else {
        throw TestFailure(description: "expected refreshed result")
    }
    try expectEqual(snapshot.totalSpendUSD, 8, "activity route auth failures should fall back to summarized spend logs")
}

func testReturnsStaleSnapshotOnTransientAPIFailure() async throws {
    let stale = SpendSnapshot(range: .today, totalSpendUSD: 5, limitUSD: 80, percentOfLimit: Decimal(string: "0.0625")!, dailyPoints: [], refreshedAt: try fixedDate("2026-05-18"), isStale: false)
    let cache = InMemorySpendSnapshotCache()
    try cache.saveSnapshot(stale)
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .success("secret-token")),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .failure(LiteLLMClientError.unavailable),
                rowsResult: .success([])
            )
        },
        cache: cache
    )

    let result = await service.refresh(range: .today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    guard case let .stale(snapshot, _) = result else {
        throw TestFailure(description: "expected stale result")
    }
    try expectEqual(snapshot.totalSpendUSD, 5, "service should return cached stale spend")
    try expect(snapshot.isStale, "service should mark cached fallback snapshots stale")
}

func testAuthFailureReturnsAuthFailedWithoutRetrying() async throws {
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .success("secret-token")),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .failure(LiteLLMClientError.unauthorized),
                rowsResult: .success([])
            )
        }
    )

    let result = await service.refresh(range: .today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    guard case .authFailed = result else {
        throw TestFailure(description: "expected authFailed result")
    }
}

func testMissingKeyReturnsSetupRequired() async throws {
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .failure(APIKeyStoreError.missingKey)),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .failure(LiteLLMClientError.unavailable),
                rowsResult: .success([])
            )
        }
    )

    let result = await service.refresh(range: .today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    guard case .setupRequired = result else {
        throw TestFailure(description: "expected setupRequired result")
    }
}

func testMalformedResponseWithoutCacheReturnsFailed() async throws {
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .success("secret-token")),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .success(LiteLLMUserContext(userID: "user-123", email: nil, totalSpendUSD: 0, maxBudgetUSD: nil, budgetResetAt: nil)),
                rowsResult: .failure(LiteLLMClientError.malformedResponse)
            )
        }
    )

    let result = await service.refresh(range: .today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    guard case .failed = result else {
        throw TestFailure(description: "expected failed result")
    }
}

func testUsesConfiguredSpendLimit() async throws {
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .success("secret-token")),
        configurationStore: StaticAppConfigurationStore(configuration: AppConfiguration(spendLimitUSD: 40)),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .success(LiteLLMUserContext(userID: "user-123", email: nil, totalSpendUSD: 0, maxBudgetUSD: nil, budgetResetAt: nil)),
                rowsResult: .success([SpendLogSummaryRow(date: try! fixedDate("2026-05-18"), spendUSD: 10)])
            )
        }
    )

    let result = await service.refresh(range: .today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    guard case let .refreshed(snapshot) = result else {
        throw TestFailure(description: "expected refreshed result")
    }
    try expectEqual(snapshot.limitUSD, 40, "service should use configured spend limit")
    try expectEqual(snapshot.percentOfLimit, Decimal(string: "0.25")!, "service should compute percent from configured limit")
}

func snapshot(range: SpendRange = .today, total: Decimal = 8, isStale: Bool = false) throws -> SpendSnapshot {
    SpendSnapshot(
        range: range,
        totalSpendUSD: total,
        limitUSD: 80,
        percentOfLimit: total / 80,
        dailyPoints: [DailySpendPoint(date: try fixedDate("2026-05-18"), spendUSD: total)],
        refreshedAt: try fixedDate("2026-05-18"),
        isStale: isStale
    )
}

func analyticsSummary(totalSpendUSD: Decimal, dailyPoints: [DailySpendPoint], source: SpendDataSource = .userDailyActivity) -> SpendAnalyticsSummary {
    SpendAnalyticsSummary(
        totalSpendUSD: totalSpendUSD,
        totals: .zero,
        dailyPoints: dailyPoints.map { DailyActivityPoint(date: $0.date, spendUSD: $0.spendUSD, totals: .zero) },
        breakdowns: [:],
        source: source
    )
}

@MainActor
func testInitialRefreshLoadsTodaySnapshot() async throws {
    let expected = try snapshot(range: .today, total: 7)
    let service = RecordingSpendService(results: [.refreshed(expected)])
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(service.requestedRanges, [.today], "initial refresh should request today's spend")
    try expectEqual(viewModel.currentSnapshot, expected, "view model should expose refreshed snapshot")
    try expectEqual(viewModel.errorMessage, nil, "successful refresh should clear errors")
    try expect(!viewModel.isRefreshing, "refresh flag should reset after completion")
}

@MainActor
func testSelectingRangeFetchesThatRange() async throws {
    let expected = try snapshot(range: .last7Days, total: 11)
    let service = RecordingSpendService(results: [.refreshed(expected)])
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.selectRange(.last7Days, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.selectedRange, .last7Days, "selected range should update")
    try expectEqual(service.requestedRanges, [.last7Days], "range selection should refresh selected range")
    try expectEqual(viewModel.currentSnapshot, expected, "selected range snapshot should be exposed")
}

@MainActor
func testTransientFailureKeepsStaleSnapshot() async throws {
    let stale = try snapshot(range: .today, total: 5, isStale: true)
    let service = RecordingSpendService(results: [.stale(stale, message: "Showing last known spend")])
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.currentSnapshot, stale, "stale snapshot should remain visible")
    try expectEqual(viewModel.errorMessage, "Showing last known spend", "stale message should be shown")
}

@MainActor
func testViewModelStoresCurrentAnalyticsSummary() async throws {
    let analytics = analyticsSummary(totalSpendUSD: 13, dailyPoints: [
        DailySpendPoint(date: try fixedDate("2026-05-18"), spendUSD: 13)
    ])
    let refreshed = SpendSnapshot(
        range: .today,
        totalSpendUSD: 13,
        limitUSD: 80,
        percentOfLimit: Decimal(string: "0.1625")!,
        dailyPoints: analytics.activitySummary.dailyPoints,
        refreshedAt: try fixedDate("2026-05-18"),
        isStale: false,
        analytics: analytics,
        userContext: nil
    )
    let viewModel = SpendDashboardViewModel(spendService: RecordingSpendService(results: [.refreshed(refreshed)]))

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.currentAnalyticsSummary, analytics, "view model should store analytics from refreshed snapshots")
}

@MainActor
func testViewModelStoresUserContextFromRefresh() async throws {
    let user = LiteLLMUserContext(userID: "user-123", email: "blai@example.com", totalSpendUSD: 100, maxBudgetUSD: nil, budgetResetAt: nil)
    let refreshed = SpendSnapshot(
        range: .today,
        totalSpendUSD: 8,
        limitUSD: 80,
        percentOfLimit: Decimal(string: "0.1")!,
        dailyPoints: [],
        refreshedAt: try fixedDate("2026-05-18"),
        isStale: false,
        analytics: nil,
        userContext: user
    )
    let viewModel = SpendDashboardViewModel(spendService: RecordingSpendService(results: [.refreshed(refreshed)]))

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.userContext, user, "view model should store user context from refresh")
}

@MainActor
func testMenuBarSnapshotStillUsesTodaySpend() async throws {
    let today = try snapshot(range: .today, total: 8)
    let last7 = try snapshot(range: .last7Days, total: 20)
    let service = RecordingSpendService(results: [.refreshed(today), .refreshed(last7)])
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())
    await viewModel.selectRange(.last7Days, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.menuBarSnapshot?.totalSpendUSD, 8, "menu bar snapshot should stay on today")
    try expectEqual(viewModel.currentSnapshot?.totalSpendUSD, 20, "current snapshot should follow selected range")
}

@MainActor
func testStaleAnalyticsDoesNotClearCurrentSnapshot() async throws {
    let analytics = analyticsSummary(totalSpendUSD: 8, dailyPoints: [])
    let current = SpendSnapshot(
        range: .today,
        totalSpendUSD: 8,
        limitUSD: 80,
        percentOfLimit: Decimal(string: "0.1")!,
        dailyPoints: [],
        refreshedAt: try fixedDate("2026-05-18"),
        isStale: false,
        analytics: analytics,
        userContext: nil
    )
    let stale = current.markingStale()
    let viewModel = SpendDashboardViewModel(spendService: RecordingSpendService(results: [
        .refreshed(current),
        .stale(stale, message: "Showing last known spend")
    ]))

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())
    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.currentSnapshot?.totalSpendUSD, 8, "stale result should preserve current spend")
    try expectEqual(viewModel.currentAnalyticsSummary?.source, .staleCache, "stale result should mark analytics source as stale cache")
}

@MainActor
func testAuthFailureShowsCredentialError() async throws {
    let service = RecordingSpendService(results: [.authFailed(message: "LiteLLM API key was rejected")])
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.currentSnapshot, nil, "auth failure should not invent a snapshot")
    try expectEqual(viewModel.errorMessage, "LiteLLM API key was rejected", "auth failure should surface credential error")
}

func testDefaultTitleShowsTodaySpendAndLimitPercent() throws {
    let title = MenuBarTitleFormatter.title(for: try snapshot(range: .today, total: Decimal(string: "7.57")!))

    try expectEqual(title, "$7.57 (9%)", "menu bar title should show compact dollars and rounded percent")
}

func testSetupStateUsesCompactTitle() throws {
    try expectEqual(MenuBarTitleFormatter.setupTitle(), "Set API Key", "setup title should fit in the menu bar")
}

func testShowsAllFiveRanges() throws {
    let labels = SpendRange.allCases.map(\.displayName)

    try expectEqual(labels, ["Today", "7D", "30D", "MTD", "YTD"], "range selector should expose all required ranges")
}

func testShowsSelectedRangeTotalAndPercent() throws {
    let presentation = SpendPopoverPresentation.make(
        range: .last30Days,
        snapshot: try snapshot(range: .last30Days, total: Decimal(string: "24.25")!),
        errorMessage: nil,
        requiresSetup: false,
        calendar: fixedCalendar()
    )

    try expectEqual(presentation.rangeName, "Last 30 days", "popover should label selected range")
    try expectEqual(presentation.totalText, "$24.25", "popover should show selected range total")
    try expectEqual(presentation.percentText, "30%", "popover should show selected range percent")
}

func testPopoverPresentationIncludesPrimaryGauge() throws {
    let presentation = SpendPopoverPresentation.make(
        range: .today,
        snapshot: try snapshot(range: .today, total: 40),
        errorMessage: nil,
        requiresSetup: false,
        calendar: fixedCalendar()
    )

    try expectEqual(presentation.primaryGauge.progress, 0.5, "popover should include selected range gauge progress")
    try expectEqual(presentation.primaryGauge.band, .yellow, "popover gauge should use spend band")
}

func testPopoverPresentationShowsLimitText() throws {
    let presentation = SpendPopoverPresentation.make(
        range: .today,
        snapshot: try snapshot(range: .today, total: 20),
        errorMessage: nil,
        requiresSetup: false,
        calendar: fixedCalendar()
    )

    try expectEqual(presentation.limitText, "Limit $80.00", "popover should show spend limit")
    try expectEqual(presentation.overLimitText, nil, "under-limit spend should not show over-limit text")
}

func testPopoverPresentationIncludesMetricRows() throws {
    let presentation = SpendPopoverPresentation.make(
        range: .today,
        snapshot: try snapshot(range: .today, total: 40),
        errorMessage: nil,
        requiresSetup: false,
        calendar: fixedCalendar()
    )

    let rows = Dictionary(uniqueKeysWithValues: presentation.detailRows.map { ($0.label, $0.value) })
    try expectEqual(rows["Spend"], "$40.00", "detail rows should include spend")
    try expectEqual(rows["Usage"], "50%", "detail rows should include usage percent")
    try expectEqual(rows["Limit"], "$80.00", "detail rows should include limit")
    try expectEqual(rows["Updated"], "12:00 AM", "detail rows should include refresh time")
}

func testOverviewPresentationShowsTokenTotals() throws {
    let analytics = SpendAnalyticsSummary(
        totalSpendUSD: 8,
        totals: SpendUsageTotals(
            totalTokens: 12345,
            promptTokens: 5000,
            completionTokens: 7345,
            cacheCreationTokens: 100,
            cacheReadTokens: 200,
            apiRequests: 7,
            successfulRequests: 6,
            failedRequests: 1
        ),
        dailyPoints: [],
        breakdowns: [:],
        source: .userDailyActivity
    )
    let snapshot = SpendSnapshot(
        range: .today,
        totalSpendUSD: 8,
        limitUSD: 80,
        percentOfLimit: Decimal(string: "0.1")!,
        dailyPoints: [],
        refreshedAt: try fixedDate("2026-05-18"),
        isStale: false,
        analytics: analytics
    )
    let presentation = SpendPopoverPresentation.make(range: .today, snapshot: snapshot, errorMessage: nil, requiresSetup: false, calendar: fixedCalendar())
    let rows = Dictionary(uniqueKeysWithValues: presentation.detailRows.map { ($0.label, $0.value) })

    try expectEqual(rows["Tokens"], "12,345", "overview should show total token count")
}

func testOverviewPresentationShowsRequestTotals() throws {
    let analytics = SpendAnalyticsSummary(
        totalSpendUSD: 8,
        totals: SpendUsageTotals(totalTokens: 0, promptTokens: 0, completionTokens: 0, cacheCreationTokens: 0, cacheReadTokens: 0, apiRequests: 7, successfulRequests: 6, failedRequests: 1),
        dailyPoints: [],
        breakdowns: [:],
        source: .userDailyActivity
    )
    let snapshot = SpendSnapshot(range: .today, totalSpendUSD: 8, limitUSD: 80, percentOfLimit: Decimal(string: "0.1")!, dailyPoints: [], refreshedAt: try fixedDate("2026-05-18"), isStale: false, analytics: analytics)
    let presentation = SpendPopoverPresentation.make(range: .today, snapshot: snapshot, errorMessage: nil, requiresSetup: false, calendar: fixedCalendar())
    let rows = Dictionary(uniqueKeysWithValues: presentation.detailRows.map { ($0.label, $0.value) })

    try expectEqual(rows["Requests"], "7 (6 ok, 1 fail)", "overview should show request success and failure counts")
}

func testOverviewPresentationShowsDataSource() throws {
    let analytics = SpendAnalyticsSummary(totalSpendUSD: 8, totals: .zero, dailyPoints: [], breakdowns: [:], source: .spendLogsFallback)
    let snapshot = SpendSnapshot(range: .today, totalSpendUSD: 8, limitUSD: 80, percentOfLimit: Decimal(string: "0.1")!, dailyPoints: [], refreshedAt: try fixedDate("2026-05-18"), isStale: false, analytics: analytics)
    let presentation = SpendPopoverPresentation.make(range: .today, snapshot: snapshot, errorMessage: nil, requiresSetup: false, calendar: fixedCalendar())
    let rows = Dictionary(uniqueKeysWithValues: presentation.detailRows.map { ($0.label, $0.value) })

    try expectEqual(rows["Source"], "Spend logs fallback", "overview should show analytics source")
}

func testPopoverPresentationShowsOverLimitState() throws {
    let presentation = SpendPopoverPresentation.make(
        range: .today,
        snapshot: try snapshot(range: .today, total: 96),
        errorMessage: nil,
        requiresSetup: false,
        calendar: fixedCalendar()
    )

    try expectEqual(presentation.primaryGauge.progress, 1, "over-limit gauge should clamp")
    try expectEqual(presentation.overLimitText, "$16.00 over limit", "popover should show over-limit amount")
}

func testPopoverPresentationPreservesStaleStatus() throws {
    let presentation = SpendPopoverPresentation.make(
        range: .today,
        snapshot: try snapshot(range: .today, total: 5, isStale: true),
        errorMessage: "Showing last known spend",
        requiresSetup: false,
        calendar: fixedCalendar()
    )

    try expect(presentation.primaryGauge.accessibilityLabel.contains("stale"), "popover gauge should preserve stale context")
    try expectEqual(presentation.statusText, "Showing last known spend", "popover should preserve stale message")
}

func testGaugePresentationUsesBandColor() throws {
    let presentation = RingProgressPresentation.make(
        snapshot: try snapshot(range: .today, total: 96),
        metric: .dollars,
        rangeName: "Today",
        requiresSetup: false
    )

    try expectEqual(presentation.band.id, "red", "gauge should expose band for view color")
}

func testGaugeAccessibilityLabelIncludesRangeAndSpend() throws {
    let presentation = RingProgressPresentation.make(
        snapshot: try snapshot(range: .today, total: 40),
        metric: .percent,
        rangeName: "Today",
        requiresSetup: false
    )

    try expect(presentation.accessibilityLabel.contains("Today"), "gauge accessibility should include range")
    try expect(presentation.accessibilityLabel.contains("50%"), "gauge accessibility should include spend percent")
}

func testPopoverFixtureUsesGaugeFirstLayout() throws {
    let presentation = SpendPopoverPresentation.make(
        range: .today,
        snapshot: try snapshot(range: .today, total: 33),
        errorMessage: nil,
        requiresSetup: false,
        calendar: fixedCalendar()
    )

    try expectEqual(presentation.primaryGauge.label, "$33", "popover presentation should provide gauge-first label")
}

func testPopoverFixtureKeepsAllPrimaryControls() throws {
    try expectEqual(SpendRange.allCases.count, 5, "popover should keep all range controls")
    try expectEqual(MenuBarMetric.allCases.count, 2, "popover should keep metric controls")
}

func testStaleSnapshotShowsTimestamp() throws {
    let presentation = SpendPopoverPresentation.make(
        range: .today,
        snapshot: try snapshot(range: .today, total: 5, isStale: true),
        errorMessage: "Showing last known spend",
        requiresSetup: false,
        calendar: fixedCalendar()
    )

    try expectEqual(presentation.refreshedText, "Updated 12:00 AM", "stale snapshot should still show last refresh time")
    try expectEqual(presentation.statusText, "Showing last known spend", "stale status should be visible")
}

func testAuthErrorShowsKeyUpdateAction() throws {
    let presentation = SpendPopoverPresentation.make(
        range: .today,
        snapshot: nil,
        errorMessage: "LiteLLM API key was rejected",
        requiresSetup: true,
        calendar: fixedCalendar()
    )

    try expect(presentation.showsKeyUpdateAction, "auth/setup state should expose key update action")
    try expectEqual(presentation.statusText, "LiteLLM API key was rejected", "auth error should be visible")
}

func testDailyChartRendersOneBarPerPoint() throws {
    let presentation = DailySpendChartPresentation.make(points: [
        DailySpendPoint(date: try fixedDate("2026-05-16"), spendUSD: 2),
        DailySpendPoint(date: try fixedDate("2026-05-17"), spendUSD: 4),
        DailySpendPoint(date: try fixedDate("2026-05-18"), spendUSD: 8)
    ])

    try expectEqual(presentation.bars.count, 3, "chart should render one bar per daily point")
    try expectEqual(presentation.bars.last?.heightRatio, 1, "largest spend should scale to full height")
}

func testTodayChartDoesNotRenderExclusiveEndDateBar() throws {
    let dateRange = try utcDateRange()
    let snapshot = SpendAggregator.snapshot(
        rows: [
            SpendLogSummaryRow(date: try fixedDate("2026-05-18"), spendUSD: 7),
            SpendLogSummaryRow(date: try fixedDate("2026-05-19"), spendUSD: 0)
        ],
        range: .today,
        dateRange: dateRange,
        limitUSD: 80,
        refreshedAt: try fixedDate("2026-05-18")
    )
    let presentation = DailySpendChartPresentation.make(points: snapshot.dailyPoints)

    try expectEqual(presentation.bars.count, 1, "chart should not render the exclusive end date row")
}

func testDailyChartPresentationSupportsEmptyPoints() throws {
    let presentation = DailySpendChartPresentation.make(points: [])

    try expect(presentation.isEmpty, "empty chart presentation should be explicit")
    try expectEqual(presentation.bars.count, 0, "empty chart should have no bars")
    try expectEqual(presentation.accessibilityLabel, "Daily spend chart, no daily spend", "empty chart should have accessible summary")
}

func testDailyChartPresentationScalesThirtyPoints() throws {
    let points = try (0..<30).map { index in
        DailySpendPoint(date: try fixedDate("2026-05-01").addingTimeInterval(TimeInterval(index * 86400)), spendUSD: Decimal(index + 1))
    }
    let presentation = DailySpendChartPresentation.make(points: points)

    try expectEqual(presentation.bars.count, 30, "chart should support thirty daily points")
    try expectEqual(presentation.bars.last?.heightRatio, 1, "largest point should scale to full height")
    try expect(presentation.accessibilityLabel.contains("30 days"), "chart accessibility should include day count")
}

func testTrendPresentationIncludesDailySpendAndTokens() throws {
    let analytics = SpendAnalyticsSummary(
        totalSpendUSD: 12,
        totals: SpendUsageTotals(totalTokens: 300, promptTokens: 100, completionTokens: 200, cacheCreationTokens: 0, cacheReadTokens: 0, apiRequests: 3, successfulRequests: 3, failedRequests: 0),
        dailyPoints: [
            DailyActivityPoint(
                date: try fixedDate("2026-05-18"),
                spendUSD: 12,
                totals: SpendUsageTotals(totalTokens: 300, promptTokens: 100, completionTokens: 200, cacheCreationTokens: 0, cacheReadTokens: 0, apiRequests: 3, successfulRequests: 3, failedRequests: 0)
            )
        ],
        breakdowns: [:],
        source: .userDailyActivity
    )

    let presentation = TrendPresentation.make(analytics: analytics, calendar: fixedCalendar())

    try expectEqual(presentation.totalText, "$12.00", "trend presentation should show range total")
    try expectEqual(presentation.tokenSummary, "300 tokens", "trend presentation should show token summary")
    try expectEqual(presentation.requestSummary, "3 requests", "trend presentation should show request summary")
    try expectEqual(presentation.days.first?.amountText, "$12.00", "daily trend should show spend")
    try expectEqual(presentation.days.first?.tokenText, "300 tokens", "daily trend should show daily tokens")
}

func testTrendPresentationScalesLongRanges() throws {
    let points = try (0..<30).map { index in
        DailyActivityPoint(date: try fixedDate("2026-05-01").addingTimeInterval(TimeInterval(index * 86400)), spendUSD: Decimal(index + 1), totals: .zero)
    }
    let analytics = SpendAnalyticsSummary(totalSpendUSD: 465, totals: .zero, dailyPoints: points, breakdowns: [:], source: .userDailyActivity)

    let presentation = TrendPresentation.make(analytics: analytics, calendar: fixedCalendar())

    try expectEqual(presentation.days.count, 30, "trend presentation should preserve long ranges")
    try expectEqual(presentation.days.last?.heightRatio, 1, "largest day should scale to full height")
    try expect(presentation.accessibilityLabel.contains("30 days"), "trend accessibility should include range density")
}

func testTrendPresentationBucketsYearToDateScaleInput() throws {
    let points = try (0..<180).map { index in
        DailyActivityPoint(date: try fixedDate("2026-01-01").addingTimeInterval(TimeInterval(index * 86400)), spendUSD: Decimal(index + 1), totals: .zero)
    }
    let analytics = SpendAnalyticsSummary(totalSpendUSD: 16290, totals: .zero, dailyPoints: points, breakdowns: [:], source: .userDailyActivity)

    let presentation = TrendPresentation.make(analytics: analytics, calendar: fixedCalendar())

    try expectEqual(presentation.days.count, TrendPresentation.maximumRenderedDays, "trend presentation should bucket YTD-scale data to fit the popover")
    try expectEqual(presentation.days.last?.heightRatio, 1, "largest bucket should scale to full height")
    try expect(presentation.accessibilityLabel.contains("180 days"), "trend accessibility should preserve original day count")
}

func testTrendPresentationHandlesEmptyActivity() throws {
    let analytics = SpendAnalyticsSummary(totalSpendUSD: 0, totals: .zero, dailyPoints: [], breakdowns: [:], source: .userDailyActivity)
    let presentation = TrendPresentation.make(analytics: analytics, calendar: fixedCalendar())

    try expect(presentation.isEmpty, "empty trend presentation should be explicit")
    try expectEqual(presentation.days.count, 0, "empty trend should have no day rows")
    try expectEqual(presentation.accessibilityLabel, "Spend trend, no daily activity", "empty trend should have accessible summary")
}

func testModelBreakdownSortsBySpendDescending() throws {
    let analytics = SpendAnalyticsSummary(
        totalSpendUSD: 10,
        totals: .zero,
        dailyPoints: [],
        breakdowns: [.models: [
            SpendBreakdownItem(label: "small-model", spendUSD: 2, tokens: 100, requests: 1),
            SpendBreakdownItem(label: "large-model", spendUSD: 8, tokens: 400, requests: 2)
        ]],
        source: .userDailyActivity
    )

    let presentation = BreakdownPresentation.make(analytics: analytics)

    try expectEqual(presentation.rows.map(\.label), ["large-model", "small-model"], "model breakdown should sort by spend descending")
}

func testModelBreakdownComputesPercentOfTotal() throws {
    let analytics = SpendAnalyticsSummary(
        totalSpendUSD: 10,
        totals: .zero,
        dailyPoints: [],
        breakdowns: [.models: [
            SpendBreakdownItem(label: "large-model", spendUSD: 8, tokens: 400, requests: 2),
            SpendBreakdownItem(label: "small-model", spendUSD: 2, tokens: 100, requests: 1)
        ]],
        source: .userDailyActivity
    )

    let presentation = BreakdownPresentation.make(analytics: analytics)

    try expectEqual(presentation.rows.first?.percentText, "80%", "breakdown percent should be presentation-derived")
    try expectEqual(presentation.rows.first?.share, 0.8, "breakdown share should be selected breakdown total fraction")
    try expectEqual(presentation.rows.first?.tokenText, "400 tokens", "breakdown should show optional tokens")
    try expectEqual(presentation.rows.first?.requestText, "2 requests", "breakdown should show optional requests")
}

func testModelBreakdownShowsEmptyStateWhenUnavailable() throws {
    let analytics = SpendAnalyticsSummary(totalSpendUSD: 0, totals: .zero, dailyPoints: [], breakdowns: [:], source: .spendLogsFallback)
    let presentation = BreakdownPresentation.make(analytics: analytics)

    try expect(presentation.isEmpty, "missing model breakdown should show empty state")
    try expectEqual(presentation.emptyText, "No model breakdown available", "empty breakdown should be clear")
}

func testModelBreakdownCapsDenseListsWithOther() throws {
    let items = (0..<12).map { index in
        SpendBreakdownItem(label: "model-\(index)", spendUSD: Decimal(12 - index), tokens: nil, requests: nil)
    }
    let analytics = SpendAnalyticsSummary(totalSpendUSD: 78, totals: .zero, dailyPoints: [], breakdowns: [.models: items], source: .userDailyActivity)

    let presentation = BreakdownPresentation.make(analytics: analytics)

    try expectEqual(presentation.rows.count, BreakdownPresentation.maximumRows, "dense model lists should be capped")
    try expectEqual(presentation.rows.last?.label, "Other", "overflow model spend should aggregate into Other")
}

func testModelBreakdownZeroTotalRowsHaveZeroShare() throws {
    let analytics = SpendAnalyticsSummary(
        totalSpendUSD: 0,
        totals: .zero,
        dailyPoints: [],
        breakdowns: [.models: [
            SpendBreakdownItem(label: "zero-a", spendUSD: 0, tokens: nil, requests: nil),
            SpendBreakdownItem(label: "zero-b", spendUSD: 0, tokens: nil, requests: nil)
        ]],
        source: .userDailyActivity
    )

    let presentation = BreakdownPresentation.make(analytics: analytics)

    try expectEqual(presentation.rows.map(\.percentText), ["0%", "0%"], "zero-total breakdown rows should show zero percent")
    try expectEqual(presentation.rows.map(\.share), [0, 0], "zero-total breakdown rows should have zero-width shares")
}

func testPreviewFixtureIncludesAdvancedAnalytics() throws {
    let analytics = SpendAnalyticsPreviewFixture.advanced(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expect(analytics.totals.totalTokens > 0, "advanced preview fixture should include token totals")
    try expect(!(analytics.breakdowns[.models] ?? []).isEmpty, "advanced preview fixture should include model breakdowns")
}

func testPreviewFixtureIncludesLongModelNames() throws {
    let analytics = SpendAnalyticsPreviewFixture.longModelNames(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())
    let longest = (analytics.breakdowns[.models] ?? []).map(\.label).max { $0.count < $1.count } ?? ""

    try expect(longest.count > 40, "long model preview fixture should exercise truncation")
}

func testPreviewFixtureIncludesEmptyBreakdownAndFallbackSource() throws {
    let analytics = SpendAnalyticsPreviewFixture.fallbackSource(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(analytics.source, .spendLogsFallback, "fallback preview should expose fallback source")
    try expectEqual(analytics.breakdowns[.models], nil, "fallback preview should have no model breakdown")
}

@MainActor
func testMetricAndRangeControlsRemainIndependent() async throws {
    let today = try snapshot(range: .today, total: 8)
    let last30 = try snapshot(range: .last30Days, total: 30)
    let service = RecordingSpendService(results: [.refreshed(today), .refreshed(last30)])
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())
    viewModel.setMenuBarMetric(.percent)
    await viewModel.selectRange(.last30Days, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.menuBarMetric, .percent, "metric control should remain independent")
    try expectEqual(viewModel.currentSnapshot, last30, "range control should update selected snapshot")
    try expectEqual(viewModel.menuBarSnapshot, today, "range control should not replace menu bar snapshot")
}

@MainActor
func testSelectingSameRangeDoesNotRefreshAgain() async throws {
    let service = RecordingSpendService(results: [])
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.selectRange(.today, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(service.requestedRanges, [], "selecting the active range should not trigger duplicate refreshes")
}

@MainActor
func testMenuBarExtraUsesFormatterOutput() async throws {
    let service = RecordingSpendService(results: [.refreshed(try snapshot(range: .today, total: Decimal(string: "12.40")!))])
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.menuBarTitle, "$12.40", "view model menu title should use ring label output")
}

@MainActor
func testSetupStateDoesNotOverflowCompactTitle() async throws {
    let service = RecordingSpendService(results: [.setupRequired(message: "LiteLLM API key is missing")])
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.menuBarTitle, "Set API Key", "setup menu title should be compact")
    try expect(viewModel.menuBarTitle.count <= 12, "setup menu title should stay short")
}

@MainActor
func testFiresEveryFiveMinutes() async throws {
    let scheduler = FakeRefreshScheduler()
    let service = RecordingSpendService(results: [.refreshed(try snapshot())])
    let viewModel = SpendDashboardViewModel(spendService: service)
    let coordinator = SpendRefreshCoordinator(viewModel: viewModel, scheduler: scheduler)

    coordinator.start()
    await scheduler.fire()

    try expectEqual(scheduler.interval, 300, "refresh scheduler should use five-minute interval")
    try expectEqual(service.requestedRanges, [.today], "scheduled fire should refresh selected range")
}

@MainActor
func testManualRefreshCoalescesWithTimer() async throws {
    let service = SuspendingSpendService()
    let viewModel = SpendDashboardViewModel(spendService: service)

    async let first: Void = viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())
    while await service.callCount == 0 {
        await Task.yield()
    }
    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar(), isAutomatic: true)
    await service.resume(with: .refreshed(try snapshot()))
    try await first

    try expectEqual(await service.callCount, 1, "manual and timer refreshes should coalesce while one is in flight")
}

@MainActor
func testManualRefreshUpdatesSnapshot() async throws {
    let expected = try snapshot(total: 9)
    let service = RecordingSpendService(results: [.refreshed(expected)])
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.currentSnapshot, expected, "manual refresh should update current snapshot")
}

@MainActor
func testAuthFailureStopsTimerRetryUntilKeyChanges() async throws {
    let refreshed = try snapshot(total: 10)
    let service = RecordingSpendService(results: [
        .authFailed(message: "LiteLLM API key was rejected"),
        .refreshed(refreshed)
    ])
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())
    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar(), isAutomatic: true)
    try expectEqual(service.requestedRanges, [.today], "automatic refresh should pause after auth failure")

    viewModel.apiKeyDidChange()
    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar(), isAutomatic: true)

    try expectEqual(service.requestedRanges, [.today, .today], "automatic refresh should resume after key change")
    try expectEqual(viewModel.currentSnapshot, refreshed, "resumed refresh should update snapshot")
}

@MainActor
func testSavingAPIKeyClearsSetupPause() async throws {
    let store = MutableAPIKeyStore()
    let viewModel = SpendDashboardViewModel(
        spendService: RecordingSpendService(results: []),
        apiKeyStore: store
    )
    viewModel.requiresSetup = true
    viewModel.pausesAutomaticRefresh = true
    viewModel.errorMessage = "LiteLLM API key is missing"
    viewModel.apiKeyDraft = "  secret-token  "

    viewModel.saveAPIKey()

    try expectEqual(store.savedKeys, ["secret-token"], "view model should save trimmed API key")
    try expectEqual(viewModel.apiKeyDraft, "", "saved key should clear draft")
    try expectEqual(viewModel.errorMessage, nil, "saving key should clear setup error")
    try expect(!viewModel.requiresSetup, "saving key should clear setup state")
    try expect(!viewModel.pausesAutomaticRefresh, "saving key should resume automatic refresh")
}

@MainActor
func testViewModelLoadsMenuBarMetricPreference() async throws {
    let preferenceStore = FakeMenuBarPreferenceStore(metric: .percent)
    let viewModel = SpendDashboardViewModel(
        spendService: RecordingSpendService(results: []),
        menuBarPreferenceStore: preferenceStore
    )

    try expectEqual(viewModel.menuBarMetric, .percent, "view model should load saved menu bar metric")
}

@MainActor
func testViewModelSavesMetricSelection() async throws {
    let preferenceStore = FakeMenuBarPreferenceStore()
    let viewModel = SpendDashboardViewModel(
        spendService: RecordingSpendService(results: []),
        menuBarPreferenceStore: preferenceStore
    )

    viewModel.setMenuBarMetric(.percent)

    try expectEqual(viewModel.menuBarMetric, .percent, "view model should update in-memory menu bar metric")
    try expectEqual(preferenceStore.savedMetrics, [.percent], "view model should persist metric changes")
}

@MainActor
func testViewModelFallsBackWhenPreferenceLoadFails() async throws {
    let viewModel = SpendDashboardViewModel(
        spendService: RecordingSpendService(results: []),
        menuBarPreferenceStore: FakeMenuBarPreferenceStore(loadError: FakePreferenceError.failed)
    )

    try expectEqual(viewModel.menuBarMetric, .dollars, "preference load failures should fall back to dollars")
}

@MainActor
func testMenuBarPresentationRemainsTodayWhenPopoverRangeChanges() async throws {
    let today = try snapshot(range: .today, total: 8)
    let last7 = try snapshot(range: .last7Days, total: 20)
    let service = RecordingSpendService(results: [.refreshed(today), .refreshed(last7)])
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())
    await viewModel.selectRange(.last7Days, now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.menuBarSnapshot, today, "menu bar snapshot should remain today's spend")
    try expectEqual(viewModel.currentSnapshot, last7, "current snapshot should follow selected popover range")
    try expectEqual(viewModel.menuBarPresentation.label, "$8", "menu bar presentation should still use today")
}

@MainActor
func testAutomaticRefreshUpdatesMenuBarSnapshotAndSelectedRange() async throws {
    let staleToday = try snapshot(range: .today, total: 8)
    let staleLast7 = try snapshot(range: .last7Days, total: 20)
    let freshToday = try snapshot(range: .today, total: 9)
    let freshLast7 = try snapshot(range: .last7Days, total: 21)
    let service = RecordingSpendService(results: [.refreshed(freshToday), .refreshed(freshLast7)])
    let viewModel = SpendDashboardViewModel(spendService: service)
    viewModel.selectedRange = .last7Days
    viewModel.menuBarSnapshot = staleToday
    viewModel.currentSnapshot = staleLast7

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar(), isAutomatic: true)

    try expectEqual(service.requestedRanges, [.today, .last7Days], "automatic refresh should update today and selected range")
    try expectEqual(viewModel.menuBarSnapshot, freshToday, "automatic refresh should update menu bar today snapshot")
    try expectEqual(viewModel.currentSnapshot, freshLast7, "automatic refresh should update selected range snapshot")
}

@MainActor
func testAuthFailurePreservesMenuBarSnapshot() async throws {
    let today = try snapshot(range: .today, total: 8)
    let service = RecordingSpendService(results: [.authFailed(message: "LiteLLM API key was rejected")])
    let viewModel = SpendDashboardViewModel(spendService: service)
    viewModel.menuBarSnapshot = today
    viewModel.currentSnapshot = today

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expectEqual(viewModel.menuBarSnapshot, today, "auth failure should preserve menu bar snapshot")
    try expectEqual(viewModel.currentSnapshot, today, "auth failure should preserve current snapshot")
    try expect(viewModel.pausesAutomaticRefresh, "auth failure should pause automatic refresh")
}

@MainActor
func testStaleFallbackMarksMenuBarAccessibilityStale() async throws {
    let stale = try snapshot(range: .today, total: 5, isStale: false)
    let cache = InMemorySpendSnapshotCache()
    try cache.saveSnapshot(stale)
    let service = SpendService(
        apiKeyStore: FakeAPIKeyStore(result: .success("secret-token")),
        clientFactory: { _, _ in
            FakeClient(
                userResult: .failure(LiteLLMClientError.unavailable),
                rowsResult: .success([])
            )
        },
        cache: cache
    )
    let viewModel = SpendDashboardViewModel(spendService: service)

    await viewModel.refresh(now: try fixedDate("2026-05-18"), calendar: fixedCalendar())

    try expect(viewModel.menuBarSnapshot?.isStale == true, "view model should store stale-marked cached fallback")
    try expect(viewModel.menuBarPresentation.accessibilityLabel.contains("stale"), "menu bar accessibility should disclose stale fallback")
}

func testMenuBarPresentationUsesTodaySnapshot() throws {
    let presentation = MenuBarSpendPresentation.make(
        menuBarSnapshot: try snapshot(range: .today, total: 12),
        requiresSetup: false,
        metric: .dollars
    )

    try expectEqual(presentation.label, "$12", "menu bar presentation should use today's snapshot")
    try expectEqual(presentation.progress, 0.15, "menu bar presentation should compute progress from today's snapshot")
}

func testMenuBarPresentationUsesSetupState() throws {
    let presentation = MenuBarSpendPresentation.make(
        menuBarSnapshot: nil,
        requiresSetup: true,
        metric: .dollars
    )

    try expectEqual(presentation.label, "Set API Key", "setup state should show compact setup label")
    try expectEqual(presentation.setupTitle, "Set API Key", "setup title should be present")
}

func testMenuBarRingAccessibilityLabelIncludesSpendAndBand() throws {
    let presentation = MenuBarSpendPresentation.make(
        menuBarSnapshot: try snapshot(range: .today, total: 76),
        requiresSetup: false,
        metric: .percent
    )

    try expect(presentation.accessibilityLabel.contains("95%"), "accessibility should include spend percent")
    try expect(presentation.accessibilityLabel.contains("red band"), "accessibility should include band")
}

func testSpendStatusBandThresholds() throws {
    try expectEqual(SpendStatusBand.band(for: Decimal(string: "0.49")!), .green, "under 50 percent should be green")
    try expectEqual(SpendStatusBand.band(for: Decimal(string: "0.50")!), .yellow, "50 percent should be yellow")
    try expectEqual(SpendStatusBand.band(for: Decimal(string: "0.75")!), .orange, "75 percent should be orange")
    try expectEqual(SpendStatusBand.band(for: Decimal(string: "0.90")!), .red, "90 percent should be red")
}

func testRingProgressClampsOverLimitSpend() throws {
    let presentation = RingProgressPresentation.make(
        snapshot: try snapshot(total: 120),
        metric: .percent,
        rangeName: "Today",
        requiresSetup: false
    )

    try expectEqual(presentation.progress, 1, "ring progress should clamp over-limit spend")
    try expectEqual(presentation.band, .red, "over-limit spend should be red")
}

func testRingPresentationFormatsDollarMetric() throws {
    let presentation = RingProgressPresentation.make(
        snapshot: try snapshot(total: Decimal(string: "33.42")!),
        metric: .dollars,
        rangeName: "Today",
        requiresSetup: false
    )

    try expectEqual(presentation.label, "$33.42", "dollar metric should show compact currency")
}

func testRingPresentationFormatsPercentMetric() throws {
    let presentation = RingProgressPresentation.make(
        snapshot: try snapshot(total: 40),
        metric: .percent,
        rangeName: "Today",
        requiresSetup: false
    )

    try expectEqual(presentation.label, "50%", "percent metric should show rounded integer percent")
}

func testRingPresentationHandlesNilSnapshot() throws {
    let presentation = RingProgressPresentation.make(
        snapshot: nil,
        metric: .dollars,
        rangeName: "Today",
        requiresSetup: false
    )

    try expectEqual(presentation.progress, 0, "nil snapshot should show zero progress")
    try expectEqual(presentation.label, "$0", "nil snapshot should use the selected metric zero label")
}

func testRingPresentationAccessibilityIncludesBandAndRange() throws {
    let presentation = RingProgressPresentation.make(
        snapshot: try snapshot(range: .today, total: 70),
        metric: .dollars,
        rangeName: "Today",
        requiresSetup: false
    )

    try expect(presentation.accessibilityLabel.contains("Today"), "accessibility should include range")
    try expect(presentation.accessibilityLabel.contains("orange band"), "accessibility should include band")
}

func testMenuBarPreferenceDefaultsToDollars() throws {
    let suiteName = "jw_tokens.preference.defaults.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsMenuBarPreferenceStore(defaults: defaults)

    try expectEqual(try store.loadMetric(), .dollars, "missing preference should default to dollars")
}

func testMenuBarPreferencePersistsPercentMetric() throws {
    let suiteName = "jw_tokens.preference.percent.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = UserDefaultsMenuBarPreferenceStore(defaults: defaults)

    try store.saveMetric(.percent)

    try expectEqual(try store.loadMetric(), .percent, "saved metric should load back from UserDefaults")
}

func testMenuBarPreferenceFallsBackOnInvalidRawValue() throws {
    let suiteName = "jw_tokens.preference.invalid.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("invalid", forKey: UserDefaultsMenuBarPreferenceStore.metricKey)
    let store = UserDefaultsMenuBarPreferenceStore(defaults: defaults)

    try expectEqual(try store.loadMetric(), .dollars, "invalid preference should fall back to dollars")
}

func testMetricSelectorShowsDollarsAndPercentOptions() throws {
    try expectEqual(MenuBarMetric.allCases.map(\.displayName), ["Dollars", "Percent"], "metric selector should expose dollars and percent")
}

@MainActor
func testDefaultPopoverModeIsOverview() async throws {
    let viewModel = SpendDashboardViewModel(spendService: RecordingSpendService(results: []))

    try expectEqual(viewModel.selectedPopoverMode, .overview, "popover should default to overview mode")
}

@MainActor
func testSelectingPopoverModeDoesNotRefreshSpend() async throws {
    let service = RecordingSpendService(results: [])
    let viewModel = SpendDashboardViewModel(spendService: service)

    viewModel.selectPopoverMode(.breakdown)

    try expectEqual(viewModel.selectedPopoverMode, .breakdown, "mode selection should update view state")
    try expectEqual(service.requestedRanges, [], "mode selection should not refresh spend")
}

func testPopoverModesExposeOverviewTrendsBreakdown() throws {
    try expectEqual(SpendPopoverMode.allCases, [.overview, .trends, .breakdown], "phase 2 should expose the first advanced modes")
    try expectEqual(SpendPopoverMode.allCases.map(\.displayName), ["Overview", "Trends", "Breakdown"], "popover modes should have display names")
}

@MainActor
func testChangingMetricDoesNotRefreshSpend() async throws {
    let service = RecordingSpendService(results: [])
    let viewModel = SpendDashboardViewModel(spendService: service)

    viewModel.setMenuBarMetric(.percent)

    try expectEqual(service.requestedRanges, [], "changing display metric should not refresh spend")
}

@MainActor
func testChangingMetricUpdatesMenuBarPresentation() async throws {
    let viewModel = SpendDashboardViewModel(spendService: RecordingSpendService(results: []))
    viewModel.menuBarSnapshot = try snapshot(range: .today, total: 40)

    viewModel.setMenuBarMetric(.percent)

    try expectEqual(viewModel.menuBarPresentation.label, "50%", "changing metric should update menu bar presentation")
}

let syncTests: [(String, () throws -> Void)] = [
    ("testTestRunnerLoadsCoreTarget", testTestRunnerLoadsCoreTarget),
    ("testDecodesUserInfoSpendAndBudget", testDecodesUserInfoSpendAndBudget),
    ("testDecodesCurrentKeyInfoSafeFieldsOnly", testDecodesCurrentKeyInfoSafeFieldsOnly),
    ("testDecodesUserKeyListAliasesAndBudgets", testDecodesUserKeyListAliasesAndBudgets),
    ("testKeyDTOsDoNotExposeRawTokenFields", testKeyDTOsDoNotExposeRawTokenFields),
    ("testDecodesSummarizedSpendRows", testDecodesSummarizedSpendRows),
    ("testDecodesMissingSpendAsZero", testDecodesMissingSpendAsZero),
    ("testSkipsRowsWithUnparseableDates", testSkipsRowsWithUnparseableDates),
    ("testFullyInvalidSpendLogsResponseMapsToMalformedResponse", testFullyInvalidSpendLogsResponseMapsToMalformedResponse),
    ("testDecodesUserDailyActivitySummary", testDecodesUserDailyActivitySummary),
    ("testUserDailyActivityFallbackSumsRowsWhenMetadataTotalIsMissing", testUserDailyActivityFallbackSumsRowsWhenMetadataTotalIsMissing),
    ("testAnalyticsSummaryStoresUsageTotals", testAnalyticsSummaryStoresUsageTotals),
    ("testAnalyticsSummaryStoresBreakdownItemsWithoutPresentationPercents", testAnalyticsSummaryStoresBreakdownItemsWithoutPresentationPercents),
    ("testSpendDataSourceCasesAreStable", testSpendDataSourceCasesAreStable),
    ("testDecodesUserDailyActivityUsageTotals", testDecodesUserDailyActivityUsageTotals),
    ("testDecodesUserDailyActivityModelBreakdown", testDecodesUserDailyActivityModelBreakdown),
    ("testSkipsMalformedBreakdownItems", testSkipsMalformedBreakdownItems),
    ("testMalformedBreakdownObjectDoesNotDropActivityTotals", testMalformedBreakdownObjectDoesNotDropActivityTotals),
    ("testUserDailyActivityAnalyticsPointsAreSortedOldestFirst", testUserDailyActivityAnalyticsPointsAreSortedOldestFirst),
    ("testDecodesSummarizedSpendRowsInRequestedTimezone", testDecodesSummarizedSpendRowsInRequestedTimezone),
    ("testTodayUsesTomorrowAsExclusiveEnd", testTodayUsesTomorrowAsExclusiveEnd),
    ("testLast7DaysIncludesTodayAndSixPriorDays", testLast7DaysIncludesTodayAndSixPriorDays),
    ("testMonthToDateStartsAtFirstOfMonth", testMonthToDateStartsAtFirstOfMonth),
    ("testSumsRowsAndComputesLimitPercent", testSumsRowsAndComputesLimitPercent),
    ("testDropsExclusiveEndDateRowsFromDailyPoints", testDropsExclusiveEndDateRowsFromDailyPoints),
    ("testSaveReadDeleteUsesGateway", testSaveReadDeleteUsesGateway),
    ("testMissingKeyMapsToSetupRequired", testMissingKeyMapsToSetupRequired),
    ("testLocalFileAPIKeyStoreSaveReadDelete", testLocalFileAPIKeyStoreSaveReadDelete),
    ("testLocalFileAPIKeyStoreMissingFileMapsToMissingKey", testLocalFileAPIKeyStoreMissingFileMapsToMissingKey),
    ("testLocalFileAPIKeyStoreUsesPrivatePermissions", testLocalFileAPIKeyStoreUsesPrivatePermissions),
    ("testDoesNotExposeKeyInErrorDescription", testDoesNotExposeKeyInErrorDescription),
    ("testDefaultTitleShowsTodaySpendAndLimitPercent", testDefaultTitleShowsTodaySpendAndLimitPercent),
    ("testSetupStateUsesCompactTitle", testSetupStateUsesCompactTitle),
    ("testShowsAllFiveRanges", testShowsAllFiveRanges),
    ("testShowsSelectedRangeTotalAndPercent", testShowsSelectedRangeTotalAndPercent),
    ("testPopoverPresentationIncludesPrimaryGauge", testPopoverPresentationIncludesPrimaryGauge),
    ("testPopoverPresentationShowsLimitText", testPopoverPresentationShowsLimitText),
    ("testPopoverPresentationIncludesMetricRows", testPopoverPresentationIncludesMetricRows),
    ("testOverviewPresentationShowsTokenTotals", testOverviewPresentationShowsTokenTotals),
    ("testOverviewPresentationShowsRequestTotals", testOverviewPresentationShowsRequestTotals),
    ("testOverviewPresentationShowsDataSource", testOverviewPresentationShowsDataSource),
    ("testPopoverPresentationShowsOverLimitState", testPopoverPresentationShowsOverLimitState),
    ("testPopoverPresentationPreservesStaleStatus", testPopoverPresentationPreservesStaleStatus),
    ("testGaugePresentationUsesBandColor", testGaugePresentationUsesBandColor),
    ("testGaugeAccessibilityLabelIncludesRangeAndSpend", testGaugeAccessibilityLabelIncludesRangeAndSpend),
    ("testPopoverFixtureUsesGaugeFirstLayout", testPopoverFixtureUsesGaugeFirstLayout),
    ("testPopoverFixtureKeepsAllPrimaryControls", testPopoverFixtureKeepsAllPrimaryControls),
    ("testStaleSnapshotShowsTimestamp", testStaleSnapshotShowsTimestamp),
    ("testAuthErrorShowsKeyUpdateAction", testAuthErrorShowsKeyUpdateAction),
    ("testDailyChartRendersOneBarPerPoint", testDailyChartRendersOneBarPerPoint),
    ("testTodayChartDoesNotRenderExclusiveEndDateBar", testTodayChartDoesNotRenderExclusiveEndDateBar),
    ("testDailyChartPresentationSupportsEmptyPoints", testDailyChartPresentationSupportsEmptyPoints),
    ("testDailyChartPresentationScalesThirtyPoints", testDailyChartPresentationScalesThirtyPoints),
    ("testTrendPresentationIncludesDailySpendAndTokens", testTrendPresentationIncludesDailySpendAndTokens),
    ("testTrendPresentationScalesLongRanges", testTrendPresentationScalesLongRanges),
    ("testTrendPresentationBucketsYearToDateScaleInput", testTrendPresentationBucketsYearToDateScaleInput),
    ("testTrendPresentationHandlesEmptyActivity", testTrendPresentationHandlesEmptyActivity),
    ("testModelBreakdownSortsBySpendDescending", testModelBreakdownSortsBySpendDescending),
    ("testModelBreakdownComputesPercentOfTotal", testModelBreakdownComputesPercentOfTotal),
    ("testModelBreakdownShowsEmptyStateWhenUnavailable", testModelBreakdownShowsEmptyStateWhenUnavailable),
    ("testModelBreakdownCapsDenseListsWithOther", testModelBreakdownCapsDenseListsWithOther),
    ("testModelBreakdownZeroTotalRowsHaveZeroShare", testModelBreakdownZeroTotalRowsHaveZeroShare),
    ("testPreviewFixtureIncludesAdvancedAnalytics", testPreviewFixtureIncludesAdvancedAnalytics),
    ("testPreviewFixtureIncludesLongModelNames", testPreviewFixtureIncludesLongModelNames),
    ("testPreviewFixtureIncludesEmptyBreakdownAndFallbackSource", testPreviewFixtureIncludesEmptyBreakdownAndFallbackSource),
    ("testSpendStatusBandThresholds", testSpendStatusBandThresholds),
    ("testRingProgressClampsOverLimitSpend", testRingProgressClampsOverLimitSpend),
    ("testRingPresentationFormatsDollarMetric", testRingPresentationFormatsDollarMetric),
    ("testRingPresentationFormatsPercentMetric", testRingPresentationFormatsPercentMetric),
    ("testRingPresentationHandlesNilSnapshot", testRingPresentationHandlesNilSnapshot),
    ("testRingPresentationAccessibilityIncludesBandAndRange", testRingPresentationAccessibilityIncludesBandAndRange),
    ("testMenuBarPresentationUsesTodaySnapshot", testMenuBarPresentationUsesTodaySnapshot),
    ("testMenuBarPresentationUsesSetupState", testMenuBarPresentationUsesSetupState),
    ("testMenuBarRingAccessibilityLabelIncludesSpendAndBand", testMenuBarRingAccessibilityLabelIncludesSpendAndBand),
    ("testMenuBarPreferenceDefaultsToDollars", testMenuBarPreferenceDefaultsToDollars),
    ("testMenuBarPreferencePersistsPercentMetric", testMenuBarPreferencePersistsPercentMetric),
    ("testMenuBarPreferenceFallsBackOnInvalidRawValue", testMenuBarPreferenceFallsBackOnInvalidRawValue),
    ("testMetricSelectorShowsDollarsAndPercentOptions", testMetricSelectorShowsDollarsAndPercentOptions),
    ("testPopoverModesExposeOverviewTrendsBreakdown", testPopoverModesExposeOverviewTrendsBreakdown)
]

let asyncTests: [(String, () async throws -> Void)] = [
    ("testUserInfoRequestUsesAuthorizationBearer", testUserInfoRequestUsesAuthorizationBearer),
    ("testSpendLogsRequestUsesSummarizeTrueAndExclusiveEndDate", testSpendLogsRequestUsesSummarizeTrueAndExclusiveEndDate),
    ("testKeyInfoRequestUsesCurrentKeyByDefault", testKeyInfoRequestUsesCurrentKeyByDefault),
    ("testKeyListRequestFiltersByUserID", testKeyListRequestFiltersByUserID),
    ("testKeyListRequestDoesNotRequestFullObjects", testKeyListRequestDoesNotRequestFullObjects),
    ("testUserDailyActivityRequestUsesInclusiveEndDateAndTimezone", testUserDailyActivityRequestUsesInclusiveEndDateAndTimezone),
    ("testMapsUnauthorized", testMapsUnauthorized),
    ("testMapsFullyInvalidJSONToMalformedResponse", testMapsFullyInvalidJSONToMalformedResponse),
    ("testRedactsAuthorizationHeaderFromLogs", testRedactsAuthorizationHeaderFromLogs),
    ("testFetchSpendRowsDoesNotComputeSnapshot", testFetchSpendRowsDoesNotComputeSnapshot),
    ("testFetchUserDailyActivityDoesNotLogPayloads", testFetchUserDailyActivityDoesNotLogPayloads),
    ("testRefreshFetchesUserThenTodaySpend", testRefreshFetchesUserThenTodaySpend),
    ("testRefreshPrefersDailyActivitySummary", testRefreshPrefersDailyActivitySummary),
    ("testRefreshMarksActivitySource", testRefreshMarksActivitySource),
    ("testRefreshFallsBackToSpendLogsWhenDailyActivityUnavailable", testRefreshFallsBackToSpendLogsWhenDailyActivityUnavailable),
    ("testRefreshMarksSpendLogsFallbackSource", testRefreshMarksSpendLogsFallbackSource),
    ("testFallbackAnalyticsHasEmptyBreakdowns", testFallbackAnalyticsHasEmptyBreakdowns),
    ("testRefreshFallsBackToSpendLogsWhenDailyActivityIsUnauthorized", testRefreshFallsBackToSpendLogsWhenDailyActivityIsUnauthorized),
    ("testReturnsStaleSnapshotOnTransientAPIFailure", testReturnsStaleSnapshotOnTransientAPIFailure),
    ("testAuthFailureReturnsAuthFailedWithoutRetrying", testAuthFailureReturnsAuthFailedWithoutRetrying),
    ("testMissingKeyReturnsSetupRequired", testMissingKeyReturnsSetupRequired),
    ("testMalformedResponseWithoutCacheReturnsFailed", testMalformedResponseWithoutCacheReturnsFailed),
    ("testUsesConfiguredSpendLimit", testUsesConfiguredSpendLimit),
    ("testInitialRefreshLoadsTodaySnapshot", testInitialRefreshLoadsTodaySnapshot),
    ("testSelectingRangeFetchesThatRange", testSelectingRangeFetchesThatRange),
    ("testTransientFailureKeepsStaleSnapshot", testTransientFailureKeepsStaleSnapshot),
    ("testViewModelStoresCurrentAnalyticsSummary", testViewModelStoresCurrentAnalyticsSummary),
    ("testViewModelStoresUserContextFromRefresh", testViewModelStoresUserContextFromRefresh),
    ("testMenuBarSnapshotStillUsesTodaySpend", testMenuBarSnapshotStillUsesTodaySpend),
    ("testStaleAnalyticsDoesNotClearCurrentSnapshot", testStaleAnalyticsDoesNotClearCurrentSnapshot),
    ("testAuthFailureShowsCredentialError", testAuthFailureShowsCredentialError),
    ("testSelectingSameRangeDoesNotRefreshAgain", testSelectingSameRangeDoesNotRefreshAgain),
    ("testMenuBarExtraUsesFormatterOutput", testMenuBarExtraUsesFormatterOutput),
    ("testSetupStateDoesNotOverflowCompactTitle", testSetupStateDoesNotOverflowCompactTitle),
    ("testFiresEveryFiveMinutes", testFiresEveryFiveMinutes),
    ("testManualRefreshCoalescesWithTimer", testManualRefreshCoalescesWithTimer),
    ("testManualRefreshUpdatesSnapshot", testManualRefreshUpdatesSnapshot),
    ("testAuthFailureStopsTimerRetryUntilKeyChanges", testAuthFailureStopsTimerRetryUntilKeyChanges),
    ("testSavingAPIKeyClearsSetupPause", testSavingAPIKeyClearsSetupPause),
    ("testViewModelLoadsMenuBarMetricPreference", testViewModelLoadsMenuBarMetricPreference),
    ("testViewModelSavesMetricSelection", testViewModelSavesMetricSelection),
    ("testViewModelFallsBackWhenPreferenceLoadFails", testViewModelFallsBackWhenPreferenceLoadFails),
    ("testMenuBarPresentationRemainsTodayWhenPopoverRangeChanges", testMenuBarPresentationRemainsTodayWhenPopoverRangeChanges),
    ("testAutomaticRefreshUpdatesMenuBarSnapshotAndSelectedRange", testAutomaticRefreshUpdatesMenuBarSnapshotAndSelectedRange),
    ("testAuthFailurePreservesMenuBarSnapshot", testAuthFailurePreservesMenuBarSnapshot),
    ("testStaleFallbackMarksMenuBarAccessibilityStale", testStaleFallbackMarksMenuBarAccessibilityStale),
    ("testChangingMetricDoesNotRefreshSpend", testChangingMetricDoesNotRefreshSpend),
    ("testChangingMetricUpdatesMenuBarPresentation", testChangingMetricUpdatesMenuBarPresentation),
    ("testMetricAndRangeControlsRemainIndependent", testMetricAndRangeControlsRemainIndependent),
    ("testDefaultPopoverModeIsOverview", testDefaultPopoverModeIsOverview),
    ("testSelectingPopoverModeDoesNotRefreshSpend", testSelectingPopoverModeDoesNotRefreshSpend)
]

var failures: [String] = []

for (name, test) in syncTests {
    do {
        try test()
        print("PASS \(name)")
    } catch {
        failures.append("\(name): \(error)")
        print("FAIL \(name): \(error)")
    }
}

for (name, test) in asyncTests {
    do {
        try await test()
        print("PASS \(name)")
    } catch {
        failures.append("\(name): \(error)")
        print("FAIL \(name): \(error)")
    }
}

if !failures.isEmpty {
    Foundation.exit(1)
}
