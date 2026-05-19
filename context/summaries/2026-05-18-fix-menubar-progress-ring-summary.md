# Fix Menu Bar Progress Ring Summary

## What Changed

- Replaced the app's SwiftUI `MenuBarExtra` label with an AppKit `NSStatusItem` controller.
- Added a status item renderer that draws a non-template color progress ring image from `MenuBarSpendPresentation`.
- Kept the existing SwiftUI `SpendPopoverView` by hosting it in an `NSPopover`.
- Preserved startup refresh and five-minute polling through `SpendRefreshCoordinator`.

## Why

SwiftUI `MenuBarExtra` flattened the custom ring label to text in the macOS status bar, so the UI showed only `89%` instead of a ring plus label.

## Verification

- `swift build`
- `swift run JWTokensTests`

## Manual Check

Relaunching the app should show a colored progress ring image next to the selected dollars or percent value in the menu bar.
