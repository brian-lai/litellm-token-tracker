# Phase 1: Core Contracts and LiteLLM Client

> **Parent plan:** `2026-05-18-litellm-menubar-spend.md`
> **Estimated time:** 1-2 days
> **Prerequisite:** Plan approval
> **Outcome:** The app has a tested data layer that can discover the current LiteLLM user, fetch summarized spend for supported ranges, store credentials in Keychain, and compute the `$80` percentage.

---

## Objective

Create the tested core layer for a local SwiftUI menu bar app without building the final UI. This phase should make spend retrieval and aggregation reliable before any menu bar presentation code depends on it.

---

## Key Context from Master Plan

**Relevant principles:**
- Use the validated deployment contract first: `/user/info` and `/spend/logs?summarize=true`.
- Keep sensitive data local and quiet: Keychain only, no credential or raw payload logging.
- Make date math explicit: local calendar dates and exclusive `end_date`.

**Relevant architecture decisions:**
- Native Swift/SwiftUI package: lightweight and Keychain-friendly.
- `$80` default limit: hardcoded app constant in v1.
- `/spend/logs?summarize=true`: primary source for today's and range spend.

**Contracts this phase implements or depends on:**

```swift
enum SpendRange: String { case today, last7Days, last30Days, monthToDate, yearToDate }

protocol DateRangeResolving {
    func dateRange(for range: SpendRange, now: Date, calendar: Calendar) -> DateRange
}

protocol APIKeyStoring {
    func readAPIKey() throws -> String
    func saveAPIKey(_ apiKey: String) throws
    func deleteAPIKey() throws
}

protocol LiteLLMClientProtocol {
    func fetchCurrentUser() async throws -> LiteLLMUserContext
    func fetchSpendRows(range: DateRange, userID: String) async throws -> [SpendLogSummaryRow]
}

protocol SpendServicing {
    func refresh(range: SpendRange, now: Date, calendar: Calendar) async -> SpendRefreshResult
}

enum SpendRefreshResult {
    case refreshed(SpendSnapshot)
    case stale(SpendSnapshot, message: String)
    case setupRequired(message: String)
    case authFailed(message: String)
    case failed(message: String)
}
```

HTTP contract details live in `context/data/2026-05-18-litellm-menubar-spend-spec.yaml`.

---

## Scope

### In Scope

- Swift package target organization that supports testable core code.
- Working test runner for the local environment.
- Contract fixtures for `/user/info` and summarized `/spend/logs`.
- Date range calculation for today, last 7 days, last 30 days, month-to-date, and year-to-date.
- Decoders and request builders for the validated LiteLLM endpoints.
- Keychain-backed API key store.
- Fakeable Keychain gateway for unit tests, with real Keychain coverage only as an opt-in integration test.
- URL loading, logging, snapshot cache, app configuration, and service protocols needed for isolated tests.
- Spend aggregation and `$80` percent calculation.
- Redacted, correlation-id logging around network calls.

### Out of Scope

- Final menu bar UI and chart rendering; Phase 2 owns this.
- Signing, notarization, MDM, or company distribution.
- Admin-only endpoints such as `/spend/logs/v2`, `/user/list`, and `/user/daily/activity/aggregated`.
- Raw log mode with `summarize=false`.

---

## Implementation Steps

> Each checklist item below maps to one git commit. The checkbox text is the commit message.
> Tests come BEFORE the implementation they cover (TDD).

- [ ] **Wire Swift test target for the local package**
  - Add a `JWTokensCore` library target if needed so tests can import non-UI logic without launching the app.
  - Add `JWTokensTests` with the test framework available in the local toolchain or document the exact `xcodebuild test` invocation if CLI `swift test` remains blocked.
  - Commit only when the smoke test passes in the selected runner.
  - **Tests:** `func testTestRunnerLoadsCoreTarget() throws` — imports the core target and asserts `SpendRange.today.rawValue == "today"`.

- [ ] **Add LiteLLM response DTOs and decoder contract tests**
  - Add JSON fixtures for validated `/user/info` and `/spend/logs?summarize=true` responses with secrets removed.
  - Cover optional/null spend rows, skipped rows with missing/unparseable dates, fully invalid responses, and extra zero rows for exclusive `end_date`.
  - Implement the minimal DTO decoders in the same commit so the committed suite remains green.
  - **Tests:** `func testDecodesUserInfoSpendAndBudget() throws`, `func testDecodesSummarizedSpendRows() throws`, `func testDecodesMissingSpendAsZero() throws`, `func testSkipsRowsWithUnparseableDates() throws`, `func testFullyInvalidSpendLogsResponseMapsToMalformedResponse() throws`.

- [ ] **Add date range resolver and spend aggregation**
  - Implement `SpendRangeResolver` for all five ranges using local calendar boundaries.
  - Implement aggregation from `SpendLogSummaryRow` to `SpendSnapshot`.
  - Filter daily points to `range.startDate <= row.date < range.endDate` so exclusive-end rows never appear in charts.
  - Compute `percentOfLimit = totalSpendUSD / 80`.
  - **Tests:** `func testTodayUsesTomorrowAsExclusiveEnd() throws`, `func testLast7DaysIncludesTodayAndSixPriorDays() throws`, `func testMonthToDateStartsAtFirstOfMonth() throws`, `func testSumsRowsAndComputesLimitPercent() throws`, `func testDropsExclusiveEndDateRowsFromDailyPoints() throws`.

- [ ] **Add LiteLLM HTTP client with injectable URL loading and logging**
  - Build `/user/info` and `/spend/logs` URLs from a configurable base URL.
  - Send `Authorization: Bearer <api-key>`.
  - Add `URLLoading` for deterministic unit tests.
  - Add `AppLogging` sink and assert credentials/payloads are redacted.
  - Map 401/403, 5xx, network errors, and fully malformed responses to app errors.
  - For partial row-level malformed data, skip invalid-date rows, treat missing/null spend as zero, and log skipped-row count.
  - Return decoded DTOs/rows only; do not compute `SpendSnapshot` in the client.
  - **Tests:** `func testUserInfoRequestUsesAuthorizationBearer() async throws`, `func testSpendLogsRequestUsesSummarizeTrueAndExclusiveEndDate() async throws`, `func testMapsUnauthorized() async throws`, `func testMapsFullyInvalidJSONToMalformedResponse() async throws`, `func testRedactsAuthorizationHeaderFromLogs() async throws`, `func testFetchSpendRowsDoesNotComputeSnapshot() async throws`.

- [ ] **Add API key store with fakeable Keychain gateway**
  - Introduce `KeychainGateway` as the only wrapper around Security framework calls.
  - Implement `KeychainAPIKeyStore` against the gateway.
  - Store only the API key in Keychain; store base URL separately as non-secret configuration.
  - Normalize missing-key and Keychain-unavailable errors.
  - Keep real SecItem round-trip tests opt-in/local, not part of the default suite.
  - **Tests:** `func testSaveReadDeleteUsesGateway() throws`, `func testMissingKeyMapsToSetupRequired() throws`, `func testDoesNotExposeKeyInErrorDescription() throws`.

- [ ] **Add spend service orchestration, stale cache, and live smoke documentation**
  - Add a `SpendService` that reads user context, fetches range spend, and returns snapshots.
  - Add `SpendSnapshotCaching` for stale fallback and `AppConfigurationStore` for base URL plus `$80` default limit.
  - Add a local smoke-test command or documented one-liner for validating against `https://litellm.justworksai.net` without printing credentials.
  - Keep live smoke tests opt-in and out of the default unit test suite.
  - **Tests:** `func testRefreshFetchesUserThenTodaySpend() async throws`, `func testReturnsStaleSnapshotOnTransientAPIFailure() async throws`, `func testAuthFailureReturnsAuthFailedWithoutRetrying() async throws`, `func testMissingKeyReturnsSetupRequired() async throws`, `func testMalformedResponseWithoutCacheReturnsFailed() async throws`, `func testUsesConfiguredSpendLimit() async throws`.

---

## Phase-Specific Risks

- **CLI test framework is unavailable in the current shell.**
  - *Mitigation:* First commit resolves test infrastructure before domain work; acceptable outcomes are working `swift test` or a documented `xcodebuild test` path.
- **Deprecated `/spend/logs` may be rate-sensitive.**
  - *Mitigation:* Use date-bounded `summarize=true` calls and keep refresh cadence in Phase 2 at 5 minutes.
- **Decimal precision can drift if implemented with `Double`.**
  - *Mitigation:* Decode through `Decimal` for display and percentage calculations.

---

## Green Tests After This Phase

- ✅ Package smoke tests — core target loads in the test runner.
- ✅ Decoder contract tests — validated LiteLLM payloads parse.
- ✅ Unit tests — date ranges, aggregation, percent math, error mapping.
- ✅ Keychain adapter tests — save/read/delete behavior works locally.
- ❌ UI acceptance test — Phase 2 owns app interaction.

---

## Files Created/Modified

| File | Action | Purpose |
|------|--------|---------|
| `Package.swift` | Modify | Add testable target structure if needed |
| `Sources/JWTokens/Domain/SpendModels.swift` | Modify | Implement range and snapshot domain models |
| `Sources/JWTokens/LiteLLM/LiteLLMClient.swift` | Modify | Implement LiteLLM HTTP client |
| `Sources/JWTokens/Security/APIKeyStore.swift` | Modify | Implement Keychain storage |
| `Sources/JWTokens/Domain/SpendService.swift` | Create | Orchestrate user discovery and spend refresh |
| `Sources/JWTokens/Support/AppConfigurationStore.swift` | Create | Store non-secret config and default spend limit |
| `Sources/JWTokens/Support/AppLogger.swift` | Create | Redacted structured diagnostics |
| `Sources/JWTokens/Support/SpendSnapshotCache.swift` | Create | Last-known-value fallback |
| `Sources/JWTokens/Support/URLLoading.swift` | Create | Fakeable URLSession boundary |
| `Sources/JWTokens/Security/KeychainGateway.swift` | Create | Fakeable SecItem boundary |
| `Tests/JWTokensTests/*.swift` | Create | Contract, unit, and adapter tests |
| `Tests/JWTokensTests/Fixtures/*.json` | Create | Redacted LiteLLM response fixtures |

---

**Next Step:** Once reviewed and approved, run `$para-execute --phase=1` to begin implementation.
