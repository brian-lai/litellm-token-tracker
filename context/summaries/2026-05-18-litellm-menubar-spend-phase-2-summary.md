# Phase 2 Summary: Menu Bar UI and Local App Behavior

## What Changed

- Implemented the SwiftUI `MenuBarExtra` app shell with a live title.
- Added a compact title formatter for `$spent (percent%)` against the `$80` default limit.
- Implemented the `SpendDashboardViewModel` refresh state machine, range selection, stale/error/setup handling, credential save flow, and automatic-refresh pause after auth failures.
- Added a popover with five range controls: today, last 7 days, last 30 days, month-to-date, and year-to-date.
- Added selected-range summary text, refreshed timestamp, stale/error messaging, manual refresh, and Keychain API key entry.
- Added a compact daily spend chart driven by tested presentation data.
- Added a 5-minute timer refresh coordinator with in-flight coalescing.
- Updated README with local run, test, Keychain, and live smoke instructions.

## Review Results

- Local diff review against `main` found that the API key update affordance was initially a dead button; fixed in `7f6c213`.
- Follow-up review found that API key saving should not silently succeed without a configured store and that the timer should use common run loop mode; fixed in `d0b1141`.
- No unresolved Phase 2 review findings remain.

## Verification

- `swift build`
- `swift run JWTokensTests`
- Live smoke against `https://litellm.justworksai.net` using environment credentials returned today's spend: `$33.424660854999985`.

## Result

The local menu bar app now displays today's spend by default, supports the required spend ranges, refreshes every 5 minutes, allows manual refresh, stores credentials locally in Keychain, and visualizes daily spend points.
