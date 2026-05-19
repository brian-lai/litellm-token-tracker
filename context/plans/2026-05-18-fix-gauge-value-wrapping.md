# Fix Gauge Value Wrapping

## Objective

Keep large spend values on one line in the popover gauge by scaling the text down inside the existing circle instead of wrapping.

## Implementation Steps

- [ ] Prevent spend gauge and popover values from wrapping
  - Tests: `swift build`, `swift run JWTokensTests`; manual visual check with YTD and today ranges.

## Boundaries

- This is a view-only change in `SpendGaugeView` and `SpendPopoverView`.
- Presentation formatting and LiteLLM data behavior stay unchanged.

## Degradation

- Extremely long values scale down to the minimum factor and then truncate as a last resort rather than wrapping into multiple lines.
