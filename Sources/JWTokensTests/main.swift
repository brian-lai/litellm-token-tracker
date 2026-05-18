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

struct FakeClient: LiteLLMClientProtocol {
    var userResult: Result<LiteLLMUserContext, Error>
    var rowsResult: Result<[SpendLogSummaryRow], Error>

    func fetchCurrentUser() async throws -> LiteLLMUserContext {
        try userResult.get()
    }

    func fetchSpendRows(range: DateRange, userID: String) async throws -> [SpendLogSummaryRow] {
        try rowsResult.get()
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

func fixedCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
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

func testSumsRowsAndComputesLimitPercent() throws {
    let dateRange = DateRange(startDate: try fixedDate("2026-05-18"), endDate: try fixedDate("2026-05-19"))
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
    let dateRange = DateRange(startDate: try fixedDate("2026-05-18"), endDate: try fixedDate("2026-05-19"))
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
    let range = DateRange(startDate: try fixedDate("2026-05-18"), endDate: try fixedDate("2026-05-19"))

    _ = try await client.fetchSpendRows(range: range, userID: "user-123")

    let components = URLComponents(url: loader.requests.first!.url!, resolvingAgainstBaseURL: false)
    let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    try expectEqual(query["user_id"], "user-123", "user_id query should be present")
    try expectEqual(query["start_date"], "2026-05-18", "start date query should be present")
    try expectEqual(query["end_date"], "2026-05-19", "exclusive end date query should be present")
    try expectEqual(query["summarize"], "true", "summarize query should be true")
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
    let range = DateRange(startDate: try fixedDate("2026-05-18"), endDate: try fixedDate("2026-05-19"))

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
    let range = DateRange(startDate: try fixedDate("2026-05-18"), endDate: try fixedDate("2026-05-19"))

    let rows = try await client.fetchSpendRows(range: range, userID: "user-123")

    try expectEqual(rows.count, 3, "client should return decoded rows, not an aggregated snapshot")
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

let syncTests: [(String, () throws -> Void)] = [
    ("testTestRunnerLoadsCoreTarget", testTestRunnerLoadsCoreTarget),
    ("testDecodesUserInfoSpendAndBudget", testDecodesUserInfoSpendAndBudget),
    ("testDecodesSummarizedSpendRows", testDecodesSummarizedSpendRows),
    ("testDecodesMissingSpendAsZero", testDecodesMissingSpendAsZero),
    ("testSkipsRowsWithUnparseableDates", testSkipsRowsWithUnparseableDates),
    ("testFullyInvalidSpendLogsResponseMapsToMalformedResponse", testFullyInvalidSpendLogsResponseMapsToMalformedResponse)
    ,
    ("testTodayUsesTomorrowAsExclusiveEnd", testTodayUsesTomorrowAsExclusiveEnd),
    ("testLast7DaysIncludesTodayAndSixPriorDays", testLast7DaysIncludesTodayAndSixPriorDays),
    ("testMonthToDateStartsAtFirstOfMonth", testMonthToDateStartsAtFirstOfMonth),
    ("testSumsRowsAndComputesLimitPercent", testSumsRowsAndComputesLimitPercent),
    ("testDropsExclusiveEndDateRowsFromDailyPoints", testDropsExclusiveEndDateRowsFromDailyPoints),
    ("testSaveReadDeleteUsesGateway", testSaveReadDeleteUsesGateway),
    ("testMissingKeyMapsToSetupRequired", testMissingKeyMapsToSetupRequired),
    ("testDoesNotExposeKeyInErrorDescription", testDoesNotExposeKeyInErrorDescription)
]

let asyncTests: [(String, () async throws -> Void)] = [
    ("testUserInfoRequestUsesAuthorizationBearer", testUserInfoRequestUsesAuthorizationBearer),
    ("testSpendLogsRequestUsesSummarizeTrueAndExclusiveEndDate", testSpendLogsRequestUsesSummarizeTrueAndExclusiveEndDate),
    ("testMapsUnauthorized", testMapsUnauthorized),
    ("testMapsFullyInvalidJSONToMalformedResponse", testMapsFullyInvalidJSONToMalformedResponse),
    ("testRedactsAuthorizationHeaderFromLogs", testRedactsAuthorizationHeaderFromLogs),
    ("testFetchSpendRowsDoesNotComputeSnapshot", testFetchSpendRowsDoesNotComputeSnapshot)
    ,
    ("testRefreshFetchesUserThenTodaySpend", testRefreshFetchesUserThenTodaySpend),
    ("testReturnsStaleSnapshotOnTransientAPIFailure", testReturnsStaleSnapshotOnTransientAPIFailure),
    ("testAuthFailureReturnsAuthFailedWithoutRetrying", testAuthFailureReturnsAuthFailedWithoutRetrying),
    ("testMissingKeyReturnsSetupRequired", testMissingKeyReturnsSetupRequired),
    ("testMalformedResponseWithoutCacheReturnsFailed", testMalformedResponseWithoutCacheReturnsFailed),
    ("testUsesConfiguredSpendLimit", testUsesConfiguredSpendLimit)
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
