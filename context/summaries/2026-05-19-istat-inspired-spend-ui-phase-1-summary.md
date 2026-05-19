# Phase 1 Summary: Menu Bar Ring and Metric Preference

## What Changed

- Added spend status bands for green/yellow/orange/red threshold mapping.
- Added ring and menu bar presentation contracts with compact dollar/percent labels, over-limit clamping, setup state, and accessibility text.
- Added a UserDefaults-backed menu bar metric preference store.
- Updated `SpendDashboardViewModel` to keep an independent today `menuBarSnapshot` separate from the selected popover `currentSnapshot`.
- Rendered a SwiftUI progress ring plus compact label in the menu bar.
- Added a Dollars/Percent selector to the current popover without triggering spend refreshes.
- Added preview fixture states via `swift run JWTokens -- --preview-state <state>` for local visual smoke checks.
- Marked cached stale fallback snapshots as stale so menu bar accessibility discloses stale data.

## Review Results

- Staff+ plan review was already approved in 2 rounds before execution.
- Phase 1 implementation review found one MUST FIX: stale cached snapshots were not marked `isStale`; fixed in `6699e5a`.
- Follow-up review approved the diff and suggested avoiding setup label clipping; fixed in `12ab80e`.

## Verification

- `swift build`
- `swift run JWTokensTests`

Both pass after review fixes.
