# Phase 1 Summary: LiteLLM Core Spend Layer

## What Changed

- Refactored the package into a reusable `JWTokensCore` library plus the `JWTokens` executable.
- Added an executable `JWTokensTests` target because the local SwiftPM CLI environment does not provide XCTest/Testing.
- Added LiteLLM DTO decoding for `/user/info` and summarized `/spend/logs` responses.
- Added range resolution for today, last 7 days, last 30 days, month-to-date, and year-to-date.
- Added spend aggregation, daily points, exclusive-end filtering, and `$80` limit percentage calculation.
- Added a LiteLLM HTTP client with injectable URL loading, bearer auth, status mapping, redacted logging, and timezone-aware date query construction.
- Added a Keychain-backed API key store with fakeable gateway.
- Added spend service orchestration with stale cache fallback and fixed default configuration for `https://litellm.justworksai.net`.
- Documented a live smoke test path that uses `LITELLM_API_KEY` or `OPENAI_API_KEY` without printing secrets.

## Review Results

- Local diff review against `main` found and fixed a date query timezone issue in `3bd61d6`.
- A follow-up review found and fixed date-only spend row decoding so local-day rows do not fall outside local date ranges in `34834dd`.
- A follow-up review found and fixed unsynchronized mutable state in the in-memory spend snapshot cache in `a84bd92`.
- No unresolved Phase 1 review findings remain.

## Verification

- `swift build`
- `swift run JWTokensTests`

Both commands pass after the review fixes.

## Notes for Phase 2

- `SpendDashboardViewModel` is intentionally still a placeholder for Phase 2 UI work.
- Phase 2 can build on the tested `SpendServicing` contract and the `SpendRefreshResult` states.
- The menu bar title should use the local calendar and continue to display today's spend by default.
