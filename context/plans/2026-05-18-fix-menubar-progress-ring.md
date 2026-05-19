# Fix Menu Bar Progress Ring

## Objective

Render the requested progress circle in the macOS menu bar. SwiftUI `MenuBarExtra` is currently flattening the custom label to text only, so the fix is to use a small AppKit `NSStatusItem` renderer for the menu bar surface while keeping the existing SwiftUI popover.

## Implementation Steps

- [ ] Add an AppKit status item renderer for the progress ring
  - Tests: `swift build`; existing presentation tests continue to cover progress, band, label, and accessibility values.
- [ ] Wire app startup to the AppKit renderer and existing refresh coordinator
  - Tests: `swift build`, `swift run JWTokensTests`; manual visual check for ring plus title and popover opening.

## Boundaries

- `MenuBarSpendPresentation` remains the view-model-to-renderer contract.
- `SpendPopoverView` remains the popover content.
- `SpendRefreshCoordinator` remains the timer owner.

## Degradation

- If no snapshot is loaded yet, the ring shows empty progress and the selected text metric shows `$0` or `0%`.
- If setup is required, the title remains `Set API Key` and the popover still exposes key entry.
