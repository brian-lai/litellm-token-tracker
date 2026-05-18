# Phase 2: iStat-Inspired Popover Redesign

> **Parent plan:** `2026-05-18-istat-inspired-spend-ui.md`
> **Estimated time:** 0.5-1 day
> **Prerequisite:** Phase 1 merged
> **Outcome:** Popover has a simpler iStat-inspired visual treatment with one prominent spend gauge, compact controls, chart, and clear status states.

---

## Objective

Redesign the popover to feel denser and more polished, using the attached iStat Menus screenshot as a visual reference. This phase intentionally keeps the scope small: one primary spend gauge, range and metric controls, summary, chart, refresh, and API key setup.

---

## Key Context from Master Plan

**Relevant principles:**
- Compact dark panel, not a landing page.
- One primary spend gauge first; expand later only after feedback.
- Keep existing refresh/API/key behavior intact.

**Contracts this phase extends:**

```swift
public struct SpendPopoverPresentation {
    public let primaryGauge: RingProgressPresentation
    public let rangeName: String
    public let totalText: String
    public let percentText: String
    public let limitText: String
    public let refreshedText: String
    public let statusText: String?
    public let showsKeyUpdateAction: Bool
    public let menuBarMetric: MenuBarMetric
}
```

---

## Scope

### In Scope

- Dark compact popover shell, approximately `320-360` SwiftUI points wide.
- One large circular gauge for selected range spend vs `$80`.
- Range selector for existing five ranges.
- Metric selector for menu bar label preference.
- Limit summary and over-limit status.
- Current daily chart with visual polish for the new theme.
- Manual refresh and API key controls integrated into the redesigned layout.
- Accessibility labels for gauge, chart, and controls.

### Out of Scope

- Multiple gauges or iStat-style module tabs.
- Model/user breakdowns.
- Animations beyond normal SwiftUI state transitions.
- Custom icons unless they are already available from SF Symbols.
- Installer/distribution.

---

## Implementation Steps

> Each checklist item below maps to one git commit. The checkbox text is the commit message.
> Tests come BEFORE implementation inside each commit; committed state must be green.

- [ ] **Extend popover presentation for gauge and limit states**
  - Add `primaryGauge`, `limitText`, `overLimitText`, and selected metric fields.
  - Preserve stale/error/setup behavior from the existing presentation model.
  - **Tests:** `func testPopoverPresentationIncludesPrimaryGauge() throws`, `func testPopoverPresentationShowsLimitText() throws`, `func testPopoverPresentationShowsOverLimitState() throws`, `func testPopoverPresentationPreservesStaleStatus() throws`.

- [ ] **Implement reusable spend gauge view**
  - Create `SpendGaugeView` using the shared `RingProgressPresentation`.
  - Keep stable dimensions and support dark-panel contrast.
  - Add accessibility label from presentation.
  - **Tests:** `func testGaugePresentationUsesBandColor() throws`, `func testGaugeAccessibilityLabelIncludesRangeAndSpend() throws`; `swift build`.

- [ ] **Redesign popover shell and hierarchy**
  - Rework `SpendPopoverView` into a compact dark panel: primary gauge, summary rows, controls, chart, status, actions.
  - Avoid nested cards; use sections/bands with restrained borders and spacing.
  - **Tests:** `func testPopoverFixtureUsesGaugeFirstLayout() throws`, `func testPopoverFixtureKeepsAllPrimaryControls() throws`; `swift build`.

- [ ] **Polish chart and controls for the dark visual style**
  - Update `DailySpendChartView` colors using spend bands or muted blue accent.
  - Keep chart dimensions stable across 1, 7, 30, MTD, and YTD daily point counts.
  - Ensure range selector, metric selector, refresh button, and API key controls remain compact.
  - **Tests:** `func testDailyChartPresentationSupportsEmptyPoints() throws`, `func testDailyChartPresentationScalesThirtyPoints() throws`, `func testMetricAndRangeControlsRemainIndependent() async throws`.

- [ ] **Verify visual degradation and document redesign**
  - Update README with the popover design and controls.
  - Verify setup, stale, auth error, over-limit, empty chart, and normal states through presentation tests.
  - Run full suite and local app smoke check.
  - Use `JWTokensPreviewFixtures` with `swift run JWTokens -- --preview-state <state>` to force normal, setup, stale, auth error, over-limit, and empty chart states without LiteLLM or Keychain.
  - Complete and document the pass/fail visual checklist: status item visible, popover opens, gauge-first layout visible, range/metric controls visible, state message matches preview state, no text overlap or clipping. If an AppKit status item bridge exists, include screenshot-based verification of the status item and popover open state.
  - **Tests:** `swift build`; `swift run JWTokensTests`; `swift run JWTokens -- --preview-state normal`; local visual checklist for setup, stale, auth error, over-limit, and empty chart states.

---

## Phase-Specific Risks

| Risk | Mitigation |
|------|------------|
| Dark popover harms readability | Use system semantic colors where possible and keep high contrast for labels/status |
| Gauge layout crowds controls | Fixed gauge dimensions and a width budget of `320-360` SwiftUI points |
| View tests become brittle | Keep assertions mostly in presentation models; use build smoke for SwiftUI rendering |
| Over-limit or no-data states break layout | Explicit presentation tests for over-limit and empty chart |

---

## Green Tests After This Phase

- Existing spend/API/refresh tests stay green.
- Phase 1 ring/menu bar tests stay green.
- Popover presentation tests cover gauge, limit, over-limit, stale, setup, and normal states.
- Chart presentation tests cover empty, one-day, thirty-day, and selected-range point counts.

---

## Files Created/Modified

| File | Action | Purpose |
|------|--------|---------|
| `Sources/JWTokensCore/Support/SpendPopoverPresentation.swift` | Modify | Add gauge/limit/metric fields |
| `Sources/JWTokens/Views/SpendGaugeView.swift` | Create | Large circular gauge |
| `Sources/JWTokens/Views/SpendPopoverView.swift` | Modify | Redesign popover hierarchy and style |
| `Sources/JWTokens/Views/DailySpendChartView.swift` | Modify | Dark style chart polish |
| `Sources/JWTokensCore/Support/DailySpendChartPresentation.swift` | Modify | Empty/thirty-point chart behavior |
| `Sources/JWTokensTests/main.swift` | Modify | Add presentation and visual-contract tests |
| `README.md` | Modify | Document controls and visual states |

---

**Next Step:** After this phase is reviewed and merged, archive the completed workflow.
