# LiteLLMTokenTracker

Local-first macOS menu bar app for tracking LiteLLM spend.

## Local Run

Build and run the menu bar app:

```bash
swift build
swift run LiteLLMTokenTracker
```

The menu bar indicator shows a small progress ring plus the selected label:

- Green: under 50% of the `$80` limit
- Yellow: 50-74%
- Orange: 75-89%
- Red: 90% and above

Use the popover's `Dollars` / `Percent` control to choose the menu bar label. The ring always represents today's spend, even when the popover range is set to 7D, 30D, MTD, or YTD.

Run the local test suite:

```bash
swift run LiteLLMTokenTrackerTests
```

## LiteLLM API Key

The local app stores the LiteLLM API key in:

- `~/.config/litellm_token_tracker/litellm_api_key`

The file is plaintext and should be readable only by your user account. The app creates the directory with `0700` permissions and the key file with `0600` permissions.

You can set the key from the app when it shows `Set API Key`, or seed it from the terminal without using Keychain:

```bash
mkdir -p ~/.config/litellm_token_tracker
chmod 700 ~/.config/litellm_token_tracker
printf '%s' "$LITELLM_API_KEY" > ~/.config/litellm_token_tracker/litellm_api_key
chmod 600 ~/.config/litellm_token_tracker/litellm_api_key
```

The core package still includes `KeychainAPIKeyStore` for future signed/distributed builds, but the local app defaults to the file store so rebuilds do not trigger repeated Keychain access prompts.
If `~/.config/litellm_token_tracker/` is empty but legacy `~/.config/jw_tokens/` files exist, the app migrates them automatically on first read.

The default LiteLLM base URL is `https://litellm.justworksai.net`, and the default spend limit is `$80`.

## Visual Smoke States

Preview states avoid LiteLLM and Keychain calls:

```bash
swift run LiteLLMTokenTracker -- --preview-state normal
swift run LiteLLMTokenTracker -- --preview-state setup
swift run LiteLLMTokenTracker -- --preview-state stale
swift run LiteLLMTokenTracker -- --preview-state auth_error
swift run LiteLLMTokenTracker -- --preview-state over_limit
swift run LiteLLMTokenTracker -- --preview-state empty_chart
swift run LiteLLMTokenTracker -- --preview-state long_model_names
swift run LiteLLMTokenTracker -- --preview-state fallback_source
swift run LiteLLMTokenTracker -- --preview-state normal --preview-metric percent
```

Checklist: status item ring and label are visible, the popover opens, the accessibility label describes spend and band, and switching dollars/percent does not clip or jitter.

The popover uses a compact dark layout inspired by iStat Menus: a primary spend gauge, selected-range summary, mode selector, range selector, menu bar metric selector, trend details, model breakdown, refresh control, and setup/error states. Use the preview states above to check normal, setup, stale, auth error, over-limit, empty chart, fallback source, and long model label layouts without live API calls.

Advanced popover checklist:

- Overview shows spend, limit, tokens, requests, source, and refresh status without wrapping values.
- Trends renders daily bars with token/request summaries for populated and empty states.
- Breakdown ranks model spend, truncates long model labels, and shows a clear empty state when fallback data lacks model details.
- Narrow popover sizing remains stable; controls should not resize when switching Overview, Trends, and Breakdown.

## Phase 1 Smoke Test

The default unit suite does not call the live LiteLLM API:

```bash
swift build
swift run LiteLLMTokenTrackerTests
```

## Build/Test/Install Verification

```bash
swift build
swift run LiteLLMTokenTrackerTests
swift build -c release
ls .build/release/LiteLLMTokenTracker
```

To validate the live deployment without printing credentials, use the current shell's `LITELLM_API_KEY` or `OPENAI_API_KEY`:

```bash
ROOT="https://litellm.justworksai.net"
KEY="${LITELLM_API_KEY:-$OPENAI_API_KEY}"
TODAY="$(date +%Y-%m-%d)"
TOMORROW="$(date -v+1d +%Y-%m-%d)"
USER_ID="$(curl -fsSL -H "Authorization: Bearer $KEY" "$ROOT/user/info" | jq -r '.user_id')"
curl -fsSL -H "Authorization: Bearer $KEY" \
  "$ROOT/spend/logs?user_id=$USER_ID&start_date=$TODAY&end_date=$TOMORROW&summarize=true" \
  | jq '[.[].spend // 0] | add'
```
