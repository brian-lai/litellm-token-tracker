import Foundation
import JWTokensCore

struct TestFailure: Error, CustomStringConvertible {
    let description: String
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

let tests: [(String, () throws -> Void)] = [
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
    ("testDropsExclusiveEndDateRowsFromDailyPoints", testDropsExclusiveEndDateRowsFromDailyPoints)
]

var failures: [String] = []

for (name, test) in tests {
    do {
        try test()
        print("PASS \(name)")
    } catch {
        failures.append("\(name): \(error)")
        print("FAIL \(name): \(error)")
    }
}

if !failures.isEmpty {
    Foundation.exit(1)
}
