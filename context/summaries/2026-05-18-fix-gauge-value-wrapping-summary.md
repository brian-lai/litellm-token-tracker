# Fix Gauge Value Wrapping Summary

## What Changed

- Added one-line scaling to the primary spend gauge value.
- Reserved a fixed inner width for gauge text so large values shrink instead of wrapping.
- Applied one-line scaling and tightening to the side summary, over-limit text, and detail values.

## Verification

- `swift build`
- `swift run JWTokensTests`

## Manual Check

YTD values like `$4,270.75` should remain on one line inside the gauge, while normal today values should keep their current visual size.
