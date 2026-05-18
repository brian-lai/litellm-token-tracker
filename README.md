# JWTokens

Local-first macOS menu bar app for tracking LiteLLM spend.

## Local Run

Build and run the menu bar app:

```bash
swift build
swift run JWTokens
```

Run the local test suite:

```bash
swift run JWTokensTests
```

## LiteLLM API Key

The app stores the LiteLLM API key in the macOS Keychain under:

- Service: `net.justworks.jw-tokens`
- Account: `litellm-api-key`

You can set the key from the app when it shows `Set API Key`, or seed it from the terminal:

```bash
security add-generic-password \
  -U \
  -s net.justworks.jw-tokens \
  -a litellm-api-key \
  -w "$LITELLM_API_KEY"
```

The default LiteLLM base URL is `https://litellm.justworksai.net`, and the default spend limit is `$80`.

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
