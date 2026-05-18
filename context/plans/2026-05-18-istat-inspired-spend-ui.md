# iStat-Inspired Spend UI

> **Master plan.** Phase-specific details are in sub-plan files. Load only the phase you're working on.

---

## Objective

Upgrade the LiteLLM spend menu bar app with a progress-ring menu bar indicator and a cleaner, denser popover inspired by iStat Menus. The first iteration stays focused: one primary spend gauge, range controls, chart, refresh/API controls, and simple color bands against the `$80` limit.

---

## Core Principles

1. **Keep spend visible at a glance.** The menu bar should communicate today's usage and proximity to the limit without requiring a click.
2. **Prefer SwiftUI, allow AppKit only for the menu bar surface.** Use SwiftUI views and presentation models first; introduce an `NSStatusItem` bridge only if `MenuBarExtra` cannot render the ring plus label reliably.
3. **Make thresholds deterministic.** Use simple bands: green `<50%`, yellow `50-75%`, orange `75-90%`, red `>=90%`.
4. **Keep the popover useful, not sprawling.** Borrow the compact dark-panel feeling from iStat Menus without implementing a full dashboard framework.
5. **Preserve existing API and refresh behavior.** This is a visual/control expansion; LiteLLM API contracts, Keychain storage, refresh cadence, stale fallback, and date math stay intact.

---

## Spec

- `context/data/2026-05-18-istat-inspired-spend-ui-spec.yaml`

The spec covers menu bar ring behavior, metric preferences, color bands, popover presentation, optional AppKit status item fallback, graceful degradation, and test boundaries.

---

## Stub Strategy

Planning will not write source stubs directly to `main`; project rules require code changes to happen in execution worktrees. Each phase creates its own stubs first, then immediately covers them with tests before implementation.

| Phase | Stub Files Created During Execution |
|-------|-------------------------------------|
| Phase 1 | `Sources/JWTokensCore/Support/SpendStatusBand.swift`, `Sources/JWTokensCore/Support/MenuBarSpendPresentation.swift`, `Sources/JWTokensCore/Support/MenuBarPreferenceStore.swift`, optional `Sources/JWTokens/App/StatusItemController.swift` |
| Phase 2 | `Sources/JWTokens/Views/SpendGaugeView.swift`, `Sources/JWTokens/Views/MetricPickerView.swift`, updated `Sources/JWTokens/Views/SpendPopoverView.swift`, updated presentation contracts in `Sources/JWTokensCore/Support/SpendPopoverPresentation.swift` |

---

## Architecture Decisions

| Decision | Choice | Rationale | Alternatives Rejected |
|----------|--------|-----------|----------------------|
| Plan type | Two phases | Phase 1 can make the menu bar indicator/prefs independently mergeable; Phase 2 can redesign the popover on top of stable presentation contracts | One large UI phase would mix app shell behavior, preferences, and visual redesign in a harder-to-review diff |
| Menu bar metric | User-selectable dollars or percent, default dollars | User explicitly wants either dollars or percentage; dollars preserve current spend-first behavior | Always showing both consumes too much menu bar width |
| Threshold model | Four simple bands | Matches user preference and is easy to test/read | Smooth gradient is visually richer but harder to make consistent and accessible |
| Ring rendering | SwiftUI first, AppKit bridge allowed | Avoids unnecessary AppKit until `MenuBarExtra` proves insufficient | AppKit-first increases surface area before there is evidence SwiftUI cannot handle it |
| Popover style | One large spend gauge plus compact controls/chart | Captures iStat's glanceable feel while keeping v1 modest | Full iStat-style multi-panel dashboard is out of scope for this iteration |
| Preference storage | UserDefaults for non-secret metric selection | Metric choice is non-secret local preference | Keychain is only for secrets; config files are unnecessary |

---

## Interface Boundaries

| Boundary | Contract |
|----------|----------|
| UI spec | `context/data/2026-05-18-istat-inspired-spend-ui-spec.yaml` |
| Spend threshold mapping | `SpendStatusBand.band(for percentOfLimit: Decimal) -> SpendStatusBand` |
| Menu bar metric preference | `MenuBarPreferenceStoring.loadMetric/saveMetric` backed by UserDefaults |
| Menu bar snapshot ownership | `SpendDashboardViewModel.menuBarSnapshot` is always the latest today snapshot and is independent from `currentSnapshot` for the selected popover range |
| Shared ring presentation | `RingProgressPresentation.make(snapshot:metric:rangeName:requiresSetup:)` handles nil, setup, stale, and over-limit states |
| Menu bar presentation | `MenuBarSpendPresentation.make(menuBarSnapshot:requiresSetup:metric:)` returns ring + compact label state |
| Optional AppKit bridge | `StatusItemRendering.render(presentation:)` if SwiftUI cannot render the intended status item |
| Popover presentation | `SpendPopoverPresentation` extended with primary gauge, metric selection, limit text, and over-limit status |
| Existing refresh/API boundary | Existing `SpendDashboardViewModel`, `SpendServicing`, Keychain, LiteLLM client, and timer contracts remain unchanged |

---

## Graceful Degradation

| Failure Scenario | Expected Behavior |
|------------------|-------------------|
| Missing API key | Menu bar uses setup state; popover shows API key entry |
| Stale snapshot | Menu bar keeps last value; popover shows stale status and last refreshed time |
| Spend exceeds `$80` | Ring is full red; popover shows over-limit state without breaking layout |
| UserDefaults preference read fails | Use default metric `dollars` and continue |
| UserDefaults preference write fails | Keep in-memory selection for the session and show non-blocking status only if needed |
| SwiftUI menu bar ring is not viable | Switch to AppKit `NSStatusItem` renderer behind `StatusItemRendering`; keep presentation contracts unchanged |
| Chart has no daily points | Show empty chart area or concise empty state, not a collapsed layout |

### Menu Bar Snapshot Invariant

The menu bar indicator always represents **today's** spend, regardless of the range selected in the popover. Phase 1 must split view-model state into:

- `menuBarSnapshot`: the latest today snapshot used by the status item.
- `currentSnapshot`: the selected popover range snapshot.

Initial refresh loads today into both when the selected range is `.today`. Selecting last 7 days, last 30 days, MTD, or YTD updates only `currentSnapshot`. Automatic refresh updates `menuBarSnapshot` every 5 minutes and also refreshes the selected range if it is different from today. Auth/setup failures preserve existing snapshots and pause automatic refresh as they do today.

---

## Observability

- Keep existing LiteLLM request logging unchanged.
- UI logging, if added, must use redacted structured events only: `ui_surface`, `selected_range`, `selected_metric`, `status_band`, `correlation_id`.
- Do not log API keys, Keychain values, raw LiteLLM payloads, or full user data.

---

## Phase Overview

| Phase | Title | Scope | Mergeable Outcome |
|-------|-------|-------|-------------------|
| **1** | Menu Bar Ring and Metric Preference | Status bands, ring presentation, user metric preference, menu bar integration, optional AppKit fallback decision | Menu bar shows a color-coded progress ring plus selected dollars/percent label |
| **2** | iStat-Inspired Popover Redesign | Large spend gauge, dark compact panel styling, metric/range controls, chart polish, setup/error/stale integration | Popover visually matches the simpler iStat-inspired target while preserving current behavior |

### Progressive Regression Rule

```
Phase 1 -> Existing core/UI tests remain green; new menu bar band, metric, preference, and status item presentation tests pass.
Phase 2 -> Phase 1 tests remain green; new popover gauge, controls, chart, and state presentation tests pass.
```

---

## Out of Scope

- Company-wide installer, signing, notarization, or auto-update.
- Model/key breakdown dashboards.
- Editing the `$80` limit in this iteration.
- Smooth color gradients; use simple bands first.
- Full iStat Menus parity, system metrics, tabs, sensors, disks, or process lists.
- Live screenshot automation unless the implementation introduces an AppKit status item bridge that needs visual verification.

### SwiftUI vs AppKit Acceptance Gate

Phase 1 starts with SwiftUI. It must switch to an AppKit `NSStatusItem` bridge only if one of these acceptance checks fails during local smoke verification:

- The status item cannot show a ring plus compact label at normal menu bar height.
- The status item lacks an accessibility label containing spend, percent, and band.
- The popover cannot still open from the indicator.
- The indicator layout clips or jitters when switching between dollars and percent.

If AppKit is introduced, `StatusItemController` owns the `NSStatusItem` lifecycle, renders from `MenuBarSpendPresentation`, and hosts the existing SwiftUI popover content in an `NSPopover`.

---

## Sub-Plans

- `2026-05-18-istat-inspired-spend-ui-phase-1.md` — menu bar ring, thresholds, metric preference, and status item integration.
- `2026-05-18-istat-inspired-spend-ui-phase-2.md` — iStat-inspired popover redesign and visual controls.

---

## Self-Review Notes

- **Round 1:** Split the work into two phases so AppKit fallback risk is contained before popover redesign begins; made existing LiteLLM/API behavior explicitly unchanged.
- **Round 2:** Added concrete interface boundaries for status bands, ring presentation, preferences, and optional status item rendering; tightened graceful degradation around UserDefaults and over-limit states.
- **Round 3:** Staff+ review found that the menu bar needed an explicit independent today snapshot contract. Added `menuBarSnapshot` ownership, refresh semantics, AppKit acceptance gates, and visual smoke requirements.
