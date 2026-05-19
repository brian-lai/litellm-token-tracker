# Fix LiteLLM UI Spend Total Summary

## What Changed

- Switched spend refresh to prefer `GET /user/daily/activity` with the current user's id, inclusive local range dates, `timezone` in JavaScript offset minutes, and `page_size=1000`.
- Kept summarized `GET /spend/logs` as a fallback when daily activity is unavailable, unauthorized for the route, malformed, or transiently failing.
- Added activity response decoding and domain aggregation that trusts `metadata.total_spend`, which matches the LiteLLM UI local-day total behavior.
- Restored readable popover controls by replacing dark segmented pickers with explicit range and menu-bar metric buttons.
- Added compact detail rows for spend, usage, limit, and updated time.

## Key Findings

- Live `GET /spend/logs` for May 18, 2026 returned `$48.498672049999996`, matching the app's incorrect `$48.50` display.
- Live `GET /user/daily/activity` with `timezone=240` returned the UI-style local-day total by including both May 18 and May 19 UTC buckets.
- `GET /user/daily/activity/aggregated` remains blocked for the current credentials, but the non-aggregated daily endpoint is usable.

## Verification

- `swift build`
- `swift run JWTokensTests`
- Live smoke against `https://litellm.justworksai.net` confirmed daily activity total differs from, and supersedes, the old spend logs total for today's local-day view.

## Review

Local diff review found and fixed one edge case before merge: daily activity route authorization failures now fall back to `/spend/logs` instead of incorrectly marking the API key invalid.
