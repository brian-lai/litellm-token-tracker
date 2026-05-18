# Phase 1: Menu Bar Ring and Metric Preference

> **Parent plan:** `2026-05-18-istat-inspired-spend-ui.md`
> **Estimated time:** 0.5-1 day
> **Prerequisite:** Current `main` with completed LiteLLM spend tracker
> **Outcome:** Menu bar displays a color-coded progress ring plus user-selected dollars or percent label for today's spend, independent of the selected popover range.

---

## Objective

Replace the plain menu bar title with a glanceable spend progress indicator. The ring uses today's `percentOfLimit`, simple color bands, and a user preference that decides whether the label shows dollars or percent. The menu bar owns a separate today snapshot so selecting a different popover range does not change the status item value.

---

## Key Context from Master Plan

**Relevant principles:**
- Keep spend visible at a glance.
- Use simple threshold bands.
- SwiftUI first; AppKit bridge only if necessary.

**Contracts this phase creates:**

```swift
public enum MenuBarMetric: String, CaseIterable, Sendable {
    case dollars
    case percent
}

public struct SpendStatusBand: Equatable, Sendable {
    public let id: String
    public let accessibleName: String
    public static func band(for percentOfLimit: Decimal) -> SpendStatusBand
}

public struct RingProgressPresentation: Equatable, Sendable {
    public let progress: Double
    public let band: SpendStatusBand
    public let label: String
    public let accessibilityLabel: String
    public static func make(snapshot: SpendSnapshot?, metric: MenuBarMetric, rangeName: String, requiresSetup: Bool) -> RingProgressPresentation
}

public struct MenuBarSpendPresentation: Equatable, Sendable {
    public let progress: Double
    public let band: SpendStatusBand
    public let label: String
    public let metric: MenuBarMetric
    public let setupTitle: String?
    public let accessibilityLabel: String
    public static func make(menuBarSnapshot: SpendSnapshot?, requiresSetup: Bool, metric: MenuBarMetric) -> MenuBarSpendPresentation
}

public protocol MenuBarPreferenceStoring: Sendable {
    func loadMetric() throws -> MenuBarMetric
    func saveMetric(_ metric: MenuBarMetric) throws
}
```

---

## Scope

### In Scope

- Simple status bands: green `<50%`, yellow `50-75%`, orange `75-90%`, red `>=90%`.
- Menu bar metric preference: dollars or percent.
- Default metric: dollars.
- Persist metric selection in UserDefaults.
- Render ring + compact label in the menu bar.
- Split today menu bar state from selected popover range state.
- Add accessibility label for the menu bar indicator.
- Decide whether SwiftUI `MenuBarExtra` can support the target; introduce AppKit bridge only if needed.

### Out of Scope

- Redesigning the popover layout beyond adding the metric selector needed for preference control.
- Configurable spend limit.
- Smooth gradients.
- Packaging/distribution.

---

## Implementation Steps

> Each checklist item below maps to one git commit. The checkbox text is the commit message.
> Tests come BEFORE implementation inside each commit; committed state must be green.

- [ ] **Add spend status band and ring presentation contracts**
  - Create stubs for `SpendStatusBand`, `MenuBarMetric`, and `RingProgressPresentation`.
  - Implement threshold mapping, progress clamping, compact label selection, nil/setup behavior, stale accessibility context, and over-limit behavior.
  - **Tests:** `func testSpendStatusBandThresholds() throws`, `func testRingProgressClampsOverLimitSpend() throws`, `func testRingPresentationFormatsDollarMetric() throws`, `func testRingPresentationFormatsPercentMetric() throws`, `func testRingPresentationHandlesNilSnapshot() throws`, `func testRingPresentationAccessibilityIncludesBandAndRange() throws`.

- [ ] **Add menu bar preference store**
  - Create `MenuBarPreferenceStoring` and UserDefaults-backed `UserDefaultsMenuBarPreferenceStore`.
  - Default to `.dollars` on missing/invalid values.
  - **Tests:** `func testMenuBarPreferenceDefaultsToDollars() throws`, `func testMenuBarPreferencePersistsPercentMetric() throws`, `func testMenuBarPreferenceFallsBackOnInvalidRawValue() throws`.

- [ ] **Wire metric preference into dashboard view model**
  - Add `menuBarMetric`, `menuBarPresentation`, and `setMenuBarMetric(_:)`.
  - Add `menuBarSnapshot` as the independent today snapshot for the status item.
  - Load preference during initialization and continue with `.dollars` if loading fails.
  - Save preference when changed; keep in-memory selection even if save fails.
  - Selecting non-today popover ranges must update `currentSnapshot` without replacing `menuBarSnapshot`.
  - Automatic refresh must refresh today's `menuBarSnapshot` and refresh the selected range when it differs from today.
  - Auth/setup failures must preserve existing snapshots and keep current automatic-refresh pause semantics.
  - **Tests:** `func testViewModelLoadsMenuBarMetricPreference() async throws`, `func testViewModelSavesMetricSelection() async throws`, `func testViewModelFallsBackWhenPreferenceLoadFails() async throws`, `func testMenuBarPresentationRemainsTodayWhenPopoverRangeChanges() async throws`, `func testAutomaticRefreshUpdatesMenuBarSnapshotAndSelectedRange() async throws`, `func testAuthFailurePreservesMenuBarSnapshot() async throws`.

- [ ] **Render progress ring in the menu bar**
  - Add SwiftUI ring view for menu bar label first.
  - Use the acceptance gate before choosing whether to keep SwiftUI or introduce AppKit:
    - Ring plus compact label fits normal menu bar height.
    - Accessibility label includes spend, percent, and band.
    - Popover still opens from the indicator.
    - Indicator does not clip or jitter when switching dollars/percent.
  - If any gate fails, add a small AppKit `NSStatusItem` bridge behind `StatusItemRendering`. `StatusItemController` owns status item lifecycle, renders from `MenuBarSpendPresentation`, and hosts the SwiftUI popover in `NSPopover`.
  - Preserve setup state behavior.
  - **Tests:** `func testMenuBarPresentationUsesTodaySnapshot() throws`, `func testMenuBarPresentationUsesSetupState() throws`, `func testMenuBarRingAccessibilityLabelIncludesSpendAndBand() throws`, `func testStatusItemRendererFallsBackToCompactTextWhenNeeded() throws` if AppKit bridge is introduced.

- [ ] **Add metric selector control to current popover**
  - Add a compact segmented/menu control for dollars vs percent.
  - Wire to `setMenuBarMetric(_:)`; avoid triggering spend refresh when only display metric changes.
  - **Tests:** `func testMetricSelectorShowsDollarsAndPercentOptions() throws`, `func testChangingMetricDoesNotRefreshSpend() async throws`, `func testChangingMetricUpdatesMenuBarPresentation() async throws`.

- [ ] **Document menu bar indicator behavior and verify phase**
  - Update README with the ring, color thresholds, and metric preference.
  - Run full suite and a local app smoke run against the SwiftUI/AppKit acceptance gate.
  - Add or use `JWTokensPreviewFixtures` behind `swift run JWTokens -- --preview-state <state>` so normal, setup, stale, auth, over-limit, empty-chart, and metric-switch states can be forced without LiteLLM or Keychain.
  - Document the local visual checklist result: status item ring/label visible, popover opens, accessibility label present, no clipping/jitter while switching dollars/percent.
  - **Tests:** `swift build`; `swift run JWTokensTests`; `swift run JWTokens -- --preview-state normal`; local visual checklist for setup, stale, auth, over-limit, empty-chart, and metric-switch states.

---

## Phase-Specific Risks

| Risk | Mitigation |
|------|------------|
| `MenuBarExtra` title cannot host a custom ring view reliably | Keep presentation logic independent and introduce `NSStatusItem` renderer only for the menu bar surface |
| Ring plus label consumes too much menu bar width | Use compact dollars by default and allow percent mode |
| Over-limit values distort the ring | Clamp visual progress to `1.0`; color red and keep exact label |
| Preference storage fails | Continue with in-memory metric and default to dollars next launch |
| Selected popover range overwrites today's menu bar value | Keep `menuBarSnapshot` independent from `currentSnapshot` and cover range changes with tests |

---

## Green Tests After This Phase

- Existing Phase 1/2 spend tracker tests stay green.
- Status band threshold tests pass.
- Ring presentation formatting and clamping tests pass.
- Preference persistence/fallback tests pass.
- View model menu bar presentation and independent today snapshot tests pass.

---

## Files Created/Modified

| File | Action | Purpose |
|------|--------|---------|
| `Sources/JWTokensCore/Support/SpendStatusBand.swift` | Create | Color-band thresholds and labels |
| `Sources/JWTokensCore/Support/MenuBarSpendPresentation.swift` | Create | Ring/menu bar presentation contracts |
| `Sources/JWTokensCore/Support/MenuBarPreferenceStore.swift` | Create | UserDefaults metric preference |
| `Sources/JWTokensCore/ViewModels/SpendDashboardViewModel.swift` | Modify | Expose metric state and menu bar presentation |
| `Sources/JWTokens/App/JWTokensApp.swift` | Modify | Render ring-based menu bar indicator |
| `Sources/JWTokens/Views/SpendPopoverView.swift` | Modify | Add metric selector |
| `Sources/JWTokens/App/StatusItemController.swift` | Optional Create | AppKit fallback only if SwiftUI is insufficient |
| `Sources/JWTokensTests/main.swift` | Modify | Add executable tests |
| `README.md` | Modify | Document indicator behavior |

---

**Next Step:** After this phase is reviewed and merged, execute Phase 2 for the popover redesign.
