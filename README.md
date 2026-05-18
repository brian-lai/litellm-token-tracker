# JWTokens

Local-first macOS menu bar app for tracking LiteLLM spend.

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
