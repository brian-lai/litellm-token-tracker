# LiteLLM Menu Bar Spend Tracker

> **Master plan.** Phase-specific details are in sub-plan files. Load only the phase you're working on.

---

## Objective

Build a native macOS SwiftUI menu bar app that displays the user's LiteLLM spend. The menu bar defaults to today's spend and shows the percentage of an $80 spend limit, with a popover for today, last 7 days, last 30 days, month-to-date, and year-to-date visualizations.

---

## Core Principles

1. **Use the validated deployment contract first.** Target `https://litellm.justworksai.net` with `GET /user/info` and `GET /spend/logs?summarize=true`; keep generic LiteLLM alternatives behind clear fallbacks.
2. **Keep sensitive data local and quiet.** Store API keys in Keychain and never log credentials, raw request payloads, or raw response payloads.
3. **Make date math explicit.** All product ranges use local calendar dates with exclusive `end_date` semantics.
4. **Prefer small native pieces.** Use SwiftUI `MenuBarExtra`, Foundation networking, and Security framework APIs before adding dependencies.
5. **Degrade visibly.** Show stale cached spend and an actionable error state when LiteLLM or Keychain fails.

---

## Architecture

```
MenuBarExtra / Popover
        |
SpendDashboardViewModel
        |
SpendService
   |            |
LiteLLMClient   APIKeyStore
   |            |
HTTPS API      macOS Keychain
```

### Data/Event Flow

```
1. App starts and asks APIKeyStore for the LiteLLM API key.
2. LiteLLMClient calls GET /user/info to discover user_id and budget metadata.
3. SpendRangeResolver computes the default "today" start_date and exclusive end_date.
4. LiteLLMClient calls GET /spend/logs with summarize=true.
5. SpendService sums row.spend, computes total / 80, and exposes a SpendSnapshot.
6. MenuBarExtra renders "$N.NN (P%)"; popover renders selectable ranges and daily bars.
7. Refresh occurs every 5 minutes plus manual user-triggered refresh.
```

---

## Architecture Decisions

| Decision | Choice | Rationale | Alternatives Rejected |
|----------|--------|-----------|----------------------|
| macOS stack | Native Swift/SwiftUI package | Lightweight local app with direct access to Keychain and menu bar APIs | Electron/Tauri add runtime weight and packaging complexity for a macOS-only utility |
| First API source | `/spend/logs?summarize=true` for range totals | Validated with current `internal_user` credentials and supports today's spend plus all requested ranges | `/user/daily/activity/aggregated` and `/spend/logs/v2` require proxy admin on the live deployment |
| User discovery | `/user/info` on startup | Validated endpoint returns `user_id`, user spend, max budget, and reset metadata | `/v2/user/info` returned 404 on the live deployment |
| Default limit | `$80` app constant in v1 | Matches current spend limit requirement and keeps v1 simple | User-configurable limits deferred until internal feedback confirms need |
| Refresh cadence | 5-minute timer plus manual refresh | Good enough for spend visibility without hammering deprecated `/spend/logs` | Realtime/push updates unavailable; shorter polling is unnecessary |
| Packaging | Local-first app | User will test locally before company distribution | Signing/notarization/deployment automation deferred |

---

## Responsibility Split

| Responsibility | Owner |
|---------------|-------|
| Date range calculation | `SpendRangeResolver` |
| API key persistence | `KeychainAPIKeyStore` |
| LiteLLM request construction and decoding | `LiteLLMClient` |
| Spend aggregation and percent calculation | `SpendService` / domain models |
| Stale snapshot persistence | `SpendSnapshotCache` |
| Non-secret app configuration | `AppConfigurationStore` |
| Structured, redacted diagnostics | `AppLogger` |
| Refresh orchestration and UI state | `SpendDashboardViewModel` |
| Menu bar title, popover, and chart | SwiftUI app views |

---

## Interface Boundaries

| Boundary | Contract |
|----------|----------|
| App to LiteLLM API | `context/data/2026-05-18-litellm-menubar-spend-spec.yaml` |
| Domain range calculation | `SpendRangeResolver.dateRange(for:now:calendar:) -> DateRange` |
| Secure credential storage | `APIKeyStoring` protocol |
| Keychain gateway | `KeychainGateway` wrapper around SecItem; fake in unit tests, real only in opt-in integration tests |
| Networking boundary | `LiteLLMClientProtocol.fetchCurrentUser() async throws -> LiteLLMUserContext` and `fetchSpendRows(range:userID:) async throws -> [SpendLogSummaryRow]` |
| URL loading | `URLLoading.data(for:) async throws -> (Data, HTTPURLResponse)` |
| Service boundary | `SpendServicing.refresh(range: SpendRange, now: Date, calendar: Calendar) async -> SpendRefreshResult`, where result is one of `refreshed(snapshot)`, `stale(snapshot,message)`, `setupRequired(message)`, `authFailed(message)`, or `failed(message)` |
| Snapshot cache | `SpendSnapshotCaching.load/save` for stale fallback |
| Non-secret configuration | `AppConfigurationStore` for base URL and fixed/default spend limit |
| Logging | `AppLogging.log(event:)` with redacted structured events |
| Refresh scheduler | `RefreshScheduling` 300-second ticks and in-flight coalescing |
| UI state boundary | `SpendDashboardViewModel` depends on `SpendServicing` only |

---

## Graceful Degradation

| Failure Scenario | Expected Behavior |
|-----------------|-------------------|
| API key missing | Menu shows setup state; popover prompts for key entry |
| Keychain read/write fails | Menu shows setup/error state; no API call attempted |
| LiteLLM unavailable or times out | Keep last known snapshot, mark stale, show retry action |
| LiteLLM returns 401/403 | Stop automatic retries until the key changes; show authentication error |
| `/spend/logs` returns partially malformed rows | Skip rows with missing/unparseable dates, treat null or missing `spend` as zero, log skipped-row count without payloads |
| `/spend/logs` returns a fully invalid response | Client maps to malformed response; service returns stale cached snapshot if available, otherwise failed state |
| Timer fires during manual refresh | Coalesce into one in-flight refresh |

---

## Phase Overview

| Phase | Title | Scope | Est. Time |
|-------|-------|-------|-----------|
| **1** | Core Contracts and LiteLLM Client | Test infrastructure, date math, decoders, Keychain store, API client, spend aggregation | 1-2 days |
| **2** | Menu Bar UI and Local App Behavior | Menu bar title, popover ranges, chart, refresh timer, manual refresh, local run docs | 1-2 days |

### Progressive Regression Rule

```
Phase 1 → Core package builds; contract/unit tests for date ranges, decoders, spend aggregation, Keychain adapter, and LiteLLM request construction go green.
Phase 2 → + View-model tests, app-state tests, and local app acceptance test go green.
```

---

## Execution Plan

1. **Review all phases** - Ensure the contract and scope are right before implementation.
2. **Execute Phase 1** - Run `$para-execute --phase=1`.
3. **Summarize Phase 1** - Run `$para-summarize --phase=1`.
4. **Review & Merge Phase 1** - Push branch, create PR, review, merge to main.
5. **Execute Phase 2** - Run `$para-execute --phase=2`.
6. **Summarize Phase 2** - Run `$para-summarize --phase=2`.
7. **Review & Merge Phase 2** - Push branch, create PR, review, merge to main.
8. **Archive** - Run `$para-archive`.

### Worktree & Branch Strategy

| Phase | Branch | Worktree Path |
|-------|--------|---------------|
| Phase 1 | `para/litellm-menubar-spend-phase-1` | `.para-worktrees/litellm-menubar-spend-phase-1` |
| Phase 2 | `para/litellm-menubar-spend-phase-2` | `.para-worktrees/litellm-menubar-spend-phase-2` |

---

## New Components

| Component | Location | Purpose |
|-----------|----------|---------|
| Swift package manifest | `Package.swift` | Defines the local macOS app package |
| App entry | `Sources/JWTokens/App/JWTokensApp.swift` | SwiftUI `MenuBarExtra` app entry |
| Domain models | `Sources/JWTokens/Domain/SpendModels.swift` | Spend ranges, snapshots, daily points, user context |
| LiteLLM client | `Sources/JWTokens/LiteLLM/LiteLLMClient.swift` | API request construction, response decoding, error mapping |
| Credential store | `Sources/JWTokens/Security/APIKeyStore.swift` | Keychain-backed API key storage |
| Dashboard state | `Sources/JWTokens/ViewModels/SpendDashboardViewModel.swift` | Observable refresh and selection state |
| Contract spec | `context/data/2026-05-18-litellm-menubar-spend-spec.yaml` | Product/API/domain contract for the app |

---

## Security Model Summary

- **API key storage:** Keychain item under app-specific service/account; never stored in UserDefaults or logs.
- **Network auth:** `Authorization: Bearer <api-key>` for the validated Justworks endpoints.
- **Logging:** Record endpoint name, status, duration, row count, and correlation id only; redact headers and payloads.
- **Raw logs:** The app must not call `/spend/logs?summarize=false` in normal operation.

---

## Local Dev Setup

```bash
swift build
swift test
swift run JWTokens
```

Current stub verification: `swift build` passes. The local command-line Swift toolchain did not expose `XCTest` or `Testing` during planning, so Phase 1 starts by wiring a working test runner for this environment. Each implementation checklist item must end with the committed test suite green; red TDD work can happen locally inside a commit but must not be committed as a standalone failing step.

---

## Sub-Plans

- `2026-05-18-litellm-menubar-spend-phase-1.md` — Data contracts, tests, Keychain, LiteLLM client, and spend aggregation.
- `2026-05-18-litellm-menubar-spend-phase-2.md` — SwiftUI menu bar UX, popover visualizations, timer/manual refresh, and local app docs.

---

## Self-Review Notes

- **Round 1:** Corrected the API source of truth from generic `/v2/user/info` to validated `/user/info` plus `/spend/logs?summarize=true`; kept admin-only endpoints out of v1.
- **Round 2:** Moved tests before implementation in each phase, added explicit contract tests for date-range exclusivity and spend aggregation, and called out the local test-runner blocker.
- **Staff+ review round 1 response:** Split client DTO decoding from service aggregation, added explicit `SpendServicing` boundary for the view model, added exclusive-end-date filtering to the spec, and rewrote checklist items so each commit is independently green and mergeable.
- **Staff+ review round 2 response:** Made `SpendServicing` and `SpendRefreshResult` canonical across spec and plans, clarified row-level versus full-response malformed behavior, and narrowed Phase 2 acceptance scope to avoid testing future UI before it exists.
