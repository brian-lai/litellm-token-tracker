# JWTokens

Local-first macOS menu bar app for tracking LiteLLM spend.

## Local Run

Build and run the menu bar app:

```bash
swift build
swift run JWTokens
```

The menu bar indicator shows a small progress ring plus the selected label:

- Green: under 50% of the `$80` limit
- Yellow: 50-74%
- Orange: 75-89%
- Red: 90% and above

Use the popover's `Dollars` / `Percent` control to choose the menu bar label. The ring always represents today's spend, even when the popover range is set to 7D, 30D, MTD, or YTD.

Run the local test suite:

```bash
swift run JWTokensTests
```

## LiteLLM API Key

The local app stores the LiteLLM API key in:

- `~/.config/jw_tokens/litellm_api_key`

The file is plaintext and should be readable only by your user account. The app creates the directory with `0700` permissions and the key file with `0600` permissions.

You can set the key from the app when it shows `Set API Key`, or seed it from the terminal without using Keychain:

```bash
mkdir -p ~/.config/jw_tokens
chmod 700 ~/.config/jw_tokens
printf '%s' "$LITELLM_API_KEY" > ~/.config/jw_tokens/litellm_api_key
chmod 600 ~/.config/jw_tokens/litellm_api_key
```

The core package still includes `KeychainAPIKeyStore` for future signed/distributed builds, but the local app defaults to the file store so rebuilds do not trigger repeated Keychain access prompts.

The default LiteLLM base URL is `https://litellm.justworksai.net`, and the default spend limit is `$80`.

## Visual Smoke States

Preview states avoid LiteLLM and Keychain calls:

```bash
swift run JWTokens -- --preview-state normal
swift run JWTokens -- --preview-state setup
swift run JWTokens -- --preview-state stale
swift run JWTokens -- --preview-state auth_error
swift run JWTokens -- --preview-state over_limit
swift run JWTokens -- --preview-state empty_chart
swift run JWTokens -- --preview-state long_model_names
swift run JWTokens -- --preview-state fallback_source
swift run JWTokens -- --preview-state normal --preview-metric percent
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
swift run JWTokensTests
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
