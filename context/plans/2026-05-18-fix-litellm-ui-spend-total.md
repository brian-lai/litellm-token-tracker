# Fix LiteLLM UI Spend Total

## Objective

Make the menu bar app match LiteLLM UI spend totals for local-day usage windows and restore readable popover information after the iStat-inspired redesign.

## Core Principles

- Prefer the endpoint that matches LiteLLM UI semantics: `/user/daily/activity`.
- Keep `/spend/logs` as a graceful fallback because it was already validated and deployed.
- Preserve the existing range model and five-minute refresh behavior.
- Keep UI changes small and focused on readability.
- Avoid logging raw LiteLLM payloads or secrets.

## Spec

`context/data/2026-05-18-fix-litellm-ui-spend-total-spec.yaml`

## Stubs

No separate stub files are needed. The implementation extends existing core interfaces in `LiteLLMClientProtocol` and uses test doubles as stubs.

## Architecture Decisions

| Decision | Choice | Rationale | Alternatives Rejected |
| --- | --- | --- | --- |
| Primary spend source | `GET /user/daily/activity` | Live validation shows it matches the LiteLLM UI local-day spend behavior. | Keep `/spend/logs` only, because it undercounts the UI total for local day windows. |
| Date semantics | Convert exclusive app ranges to inclusive API dates | The activity endpoint accepts UI-style inclusive ranges. | Change app range model globally, because existing app internals and tests use exclusive end dates. |
| Fallback | Fall back to summarized `/spend/logs` on transient/malformed activity errors | Keeps the app working on deployments or roles where activity analytics fail. | Fail the whole refresh, because it would regress existing users. |
| UI controls | Explicit pill buttons instead of segmented pickers | Segmented pickers rendered as checkmarks in the dark popover. | Tune SwiftUI segmented styling, because native rendering is inconsistent in menu bar popovers. |

## Interface Boundaries

- LiteLLM client boundary: `LiteLLMClientProtocol.fetchUserDailyActivity(range:userID:)` returns `SpendActivitySummary`.
- Decoder boundary: `LiteLLMResponseDecoder.decodeUserDailyActivity(from:calendar:)` parses the analytics response without exposing raw payloads.
- Service boundary: `SpendService.refresh(range:now:calendar:)` returns the same `SpendSnapshot` model regardless of primary or fallback source.
- UI boundary: `SpendPopoverPresentation` supplies display strings and control state to `SpendPopoverView`.

## Graceful Degradation

| Failure Scenario | Expected Behavior |
| --- | --- |
| `/user/daily/activity` returns 401, 5xx, malformed JSON, or network failure | Use existing summarized `/spend/logs` fallback for the selected range. |
| Both activity and spend logs fail | Return stale cached snapshot if available, otherwise show refresh failure. |
| API key is rejected by `/user/info` | Preserve existing auth failure behavior and pause automatic refresh. |
| Popover controls cannot refresh immediately | Selected control remains visible; existing error/stale status is shown. |

## Implementation Steps

- [ ] Add LiteLLM daily activity decoding and client contract
  - Tests: `testDecodesUserDailyActivitySummary`, `testUserDailyActivityRequestUsesInclusiveEndDateAndTimezone`
- [ ] Prefer daily activity spend with summarized logs fallback
  - Tests: `testRefreshPrefersDailyActivitySummary`, `testRefreshFallsBackToSpendLogsWhenDailyActivityUnavailable`
- [ ] Restore readable popover controls and detail rows
  - Tests: `testPopoverPresentationIncludesMetricRows`, existing range/metric control tests

## Risks

- The activity endpoint is beta in the generic LiteLLM spec, so fallback must remain.
- The activity endpoint returns UTC-adjacent date buckets for local-day windows; totals should trust `metadata.total_spend`.
- Live totals move while testing, so verification should compare endpoint shape and relative match rather than hard-code a current value.

## Success Criteria

- The menu bar total for today uses `/user/daily/activity` and matches the LiteLLM UI class of totals.
- The app still works if daily activity is unavailable.
- Popover range and metric controls are legible, with spend, usage, limit, and updated details visible.
- `swift build` and `swift run JWTokensTests` pass.

## Testing Strategy

- Contract tests cover decoding and request construction for `/user/daily/activity`.
- Service tests cover primary-source preference and fallback behavior.
- Presentation/UI tests cover restored detail strings and controls.
- A live smoke check compares `/user/daily/activity` and `/spend/logs` totals without printing secrets.
