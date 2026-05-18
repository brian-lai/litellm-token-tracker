# Phase 2: Menu Bar UI and Local App Behavior

> **Parent plan:** `2026-05-18-litellm-menubar-spend.md`
> **Estimated time:** 1-2 days
> **Prerequisite:** Phase 1 merged
> **Outcome:** A local native macOS menu bar app displays today's spend and `$80` percentage by default, supports manual/5-minute refresh, and visualizes the required ranges in a simple popover.

---

## Objective

Build the user-facing SwiftUI menu bar experience on top of the tested core layer. The first screen is the actual menu bar utility, not a landing page or marketing surface.

---

## Key Context from Master Plan

**Relevant principles:**
- Default to today's spend.
- Keep UI compact, scannable, and local-first.
- Degrade visibly with stale/error states.

**Relevant architecture decisions:**
- Use SwiftUI `MenuBarExtra`.
- Refresh every 5 minutes plus manual refresh.
- Display `$spent (percent%)` against an `$80` limit.

**Contracts this phase implements or depends on:**

```swift
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

@MainActor
final class SpendDashboardViewModel {
    var selectedRange: SpendRange
    var currentSnapshot: SpendSnapshot?
    var userContext: LiteLLMUserContext?
    var errorMessage: String?
    var isRefreshing: Bool
    func refresh(now: Date, calendar: Calendar) async
}

protocol RefreshScheduling {
    func start(every seconds: TimeInterval, operation: @escaping @Sendable () async -> Void)
    func stop()
}
```

---

## Scope

### In Scope

- Menu bar title with today's spend and percent of `$80`.
- Popover with current range total, selectable range controls, and compact daily bar chart.
- Supported ranges: today, last 7 days, last 30 days, month-to-date, year-to-date.
- Manual refresh button and 5-minute timer refresh.
- Setup/error/stale states.
- Local run instructions.

### Out of Scope

- Company-wide installer, signing, notarization, or auto-update.
- Model/key breakdown UI unless trivial from summarized rows.
- Editable spend limit; `$80` remains fixed in v1.
- Raw request log inspection.

---

## Implementation Steps

> Each checklist item below maps to one git commit. The checkbox text is the commit message.
> Tests come BEFORE the implementation they cover (TDD).

- [ ] **Write view-model tests for refresh and range selection**
  - Use mock `SpendServicing` plus deterministic clock/calendar inputs.
  - Cover initial load, manual refresh, range change, stale fallback, and authentication error display.
  - Implement the minimal view-model behavior in the same commit so the committed suite remains green.
  - **Tests:** `func testInitialRefreshLoadsTodaySnapshot() async throws`, `func testSelectingRangeFetchesThatRange() async throws`, `func testTransientFailureKeepsStaleSnapshot() async throws`, `func testAuthFailureShowsCredentialError() async throws`.

- [ ] **Add menu bar title formatter and acceptance coverage**
  - Add formatter/acceptance coverage scoped only to the menu bar title and setup title state.
  - Implement `MenuBarTitleFormatter` in the same commit so the committed suite remains green.
  - **Tests:** `func testDefaultTitleShowsTodaySpendAndLimitPercent() throws` — expects a title like `$7.57 (9%)`; `func testSetupStateUsesCompactTitle() throws`.

- [ ] **Implement menu bar title and setup state**
  - Render `$0.00 (0%)` or setup text when no snapshot exists.
  - Render `$N.NN (P%)` for today's snapshot.
  - Avoid text overflow in compact menu bar title.
  - **Tests:** `func testMenuBarExtraUsesFormatterOutput() throws`, `func testSetupStateDoesNotOverflowCompactTitle() throws`.

- [ ] **Implement popover range selector**
  - Add a compact segmented or picker control for the five ranges.
  - Wire selection changes to the view model without triggering duplicate refreshes.
  - Keep the view utilitarian and dense; no landing page or decorative hero UI.
  - **Tests:** `func testShowsAllFiveRanges() throws`, `func testSelectingRangeUpdatesViewModel() async throws`, `func testPopoverFixtureRendersSelectedRangeState() throws`.

- [ ] **Implement popover summary, timestamps, and stale/error states**
  - Add selected range total, percent of `$80`, last refreshed time, setup state, and stale/error messaging.
  - Keep credential entry/update affordance separate from logs and diagnostics.
  - **Tests:** `func testShowsSelectedRangeTotalAndPercent() throws`, `func testStaleSnapshotShowsTimestamp() throws`, `func testAuthErrorShowsKeyUpdateAction() throws`.

- [ ] **Implement daily spend chart**
  - Render one bar per `dailyPoints` item after Phase 1 filtering removed exclusive-end rows.
  - Keep chart dimensions stable for 1, 7, 30, MTD, and YTD ranges.
  - **Tests:** `func testDailyChartRendersOneBarPerPoint() throws`, `func testTodayChartDoesNotRenderExclusiveEndDateBar() throws`.

- [ ] **Implement refresh timer and manual refresh action**
  - Start a 5-minute refresh loop while the app is active.
  - Coalesce overlapping refreshes.
  - Stop automatic timer retries after `authFailed` until the API key changes.
  - Add a manual refresh button with disabled/loading state.
  - **Tests:** `func testFiresEveryFiveMinutes() async throws`, `func testManualRefreshCoalescesWithTimer() async throws`, `func testManualRefreshUpdatesSnapshot() async throws`, `func testAuthFailureStopsTimerRetryUntilKeyChanges() async throws`.

- [ ] **Add local run documentation and final verification**
  - Document how to set/save the LiteLLM API key locally.
  - Document `swift build`, test command, and local app launch path.
  - Run local smoke verification against the real LiteLLM endpoint without printing secrets.
  - **Tests:** `swift build`; full test suite from Phases 1 and 2; optional live smoke command returns today's spend.

---

## Phase-Specific Risks

- **SwiftPM app launch may be less polished than an Xcode app target.**
  - *Mitigation:* Keep local-first path simple; if needed, add an Xcode project/package workspace in this phase without changing core contracts.
- **Menu bar text can become too wide.**
  - *Mitigation:* Use compact currency formatting and rounded percentage; keep details in popover.
- **Timer refresh can annoy the API or duplicate calls.**
  - *Mitigation:* Coalesce in-flight refreshes and keep the interval at 5 minutes.

---

## Green Tests After This Phase

- ✅ Phase 1 contract and unit tests remain green.
- ✅ View-model tests — refresh, stale, auth, and range state.
- ✅ UI formatting tests — title and percent formatting.
- ✅ Acceptance test — default app state shows today's spend and percent.

---

## Files Created/Modified

| File | Action | Purpose |
|------|--------|---------|
| `Sources/JWTokens/App/JWTokensApp.swift` | Modify | Build the real `MenuBarExtra` app shell |
| `Sources/JWTokens/ViewModels/SpendDashboardViewModel.swift` | Modify | Implement refresh/range state |
| `Sources/JWTokens/Views/SpendPopoverView.swift` | Create | Popover content and range selector |
| `Sources/JWTokens/Views/DailySpendChartView.swift` | Create | Compact daily spend chart |
| `Sources/JWTokens/Support/RefreshScheduler.swift` | Create | 5-minute timer and manual refresh coalescing |
| `Tests/JWTokensTests/*ViewModelTests.swift` | Create | View-model and scheduler tests |
| `README.md` | Create | Local install/run instructions |

---

**Next Step:** Once reviewed and approved, run `$para-execute --phase=2` after Phase 1 is merged.
