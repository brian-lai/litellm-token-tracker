# LiteLLMTokenTracker

`LiteLLMTokenTracker` is a local-first macOS menu bar app for tracking LiteLLM spend.

It shows today's spend in the menu bar by default and opens a compact popover for broader analytics, key context, and local settings.

## What It Does

- Shows today's spend in the menu bar with a progress ring against the configured spend limit.
- Lets the user choose whether the menu bar label shows dollars or percent.
- Supports `Today`, `7D`, `30D`, `MTD`, and `YTD` ranges in the popover.
- Includes popover modes for:
  - `Overview`
  - `Trends`
  - `Breakdown`
  - `Keys`
  - `Settings`
- Pulls richer analytics from LiteLLM daily activity when available and falls back to summarized spend logs when needed.
- Stores the LiteLLM API key locally in a plaintext file for local development convenience.

## Requirements

- macOS 14+
- Swift 5.10+
- A LiteLLM deployment reachable from your machine

## Install

Requirements:

- macOS 14+
- Xcode Command Line Tools with Swift 5.10+

### Install Latest Public Release (curl | bash)

```bash
curl -fsSL https://raw.githubusercontent.com/brian-lai/litellm_token_tracker/main/scripts/install-release.sh | bash
```

This downloads the latest `LiteLLMTokenTracker-macos.zip` GitHub release asset, installs `LiteLLMTokenTracker.app` into `~/Applications/LiteLLMTokenTracker.app`, and launches it.

### Install from Local Checkout

Build and install from the repository root:

```bash
make install
```

The installer script does the following:

- builds `LiteLLMTokenTracker` in release mode
- replaces any existing `~/Applications/LiteLLMTokenTracker.app`
- launches the installed app with `open`

After install, you can launch it again like a normal app:

```bash
open ~/Applications/LiteLLMTokenTracker.app
```

You can also launch it from Spotlight or Finder.

### Package Release Asset Locally

Build the release archive expected by the installer:

```bash
bash scripts/package-release.sh
```

This produces `dist/LiteLLMTokenTracker-macos.zip`.

## Local Development

Build and run directly with SwiftPM:

```bash
swift build
swift run LiteLLMTokenTracker
```

Run the local test suite:

```bash
swift run LiteLLMTokenTrackerTests
```

Run a release build:

```bash
swift build -c release --product LiteLLMTokenTracker
```

## Configuration

The app uses:

- Spend limit: `$80`
- Refresh cadence: every 5 minutes plus manual refresh

The app stores local configuration in:

- API key: `~/.config/litellm_token_tracker/litellm_api_key`
- App config: `~/.config/litellm_token_tracker/config.json`

The app creates the config directory with `0700` permissions and the key/config files with `0600` permissions.

On startup, the app resolves configuration in this order:

1. Persisted files under `~/.config/litellm_token_tracker/`
2. Legacy files under `~/.config/jw_tokens/` and migrates them forward
3. Environment variables:
   - `LITELLM_BASE_URL`
   - `LITELLM_API_KEY`
4. If either value is still missing, the popover prompts for it and persists it locally

## Setting the API Key and Base URL

You can set both values from the app when it shows `Configure`, or seed them from the terminal:

```bash
mkdir -p ~/.config/litellm_token_tracker
chmod 700 ~/.config/litellm_token_tracker
printf '%s' "$LITELLM_API_KEY" > ~/.config/litellm_token_tracker/litellm_api_key
printf '{"baseURL":"%s","spendLimitUSD":"80"}' "$LITELLM_BASE_URL" > ~/.config/litellm_token_tracker/config.json
chmod 600 ~/.config/litellm_token_tracker/litellm_api_key
chmod 600 ~/.config/litellm_token_tracker/config.json
```

This project intentionally uses local file storage for the API key during local development to avoid repeated Keychain prompts while rebuilding and running. The core package still includes `KeychainAPIKeyStore` for future signed or managed distribution.

## Menu Bar Behavior

- The ring always represents today's spend.
- The menu bar label can show dollars or percent.
- Color bands move from green to red as spend approaches the limit.
- The menu bar snapshot stays pinned to today even when the popover is looking at a broader range.

## Interaction Model

- Left click toggles the spend popover.
- Right click opens a context menu with `Settings`, `Refresh`, and `Exit`.
- `Settings` in the context menu opens the existing popover on the `Settings` mode.
- The expanded popover also shows a top-right cog that switches to the existing `Settings` mode.
- `Refresh` uses the same `refreshSelectedMode()` path as the in-popover refresh button, including the existing disabled state while refresh is already running.
- `Exit` terminates the app through the normal macOS app lifecycle.

## Popover Modes

`Overview`
: Spend summary, limit, tokens, requests, source, and refresh status.

`Trends`
: Daily spend chart and trend summaries for the selected range.

`Breakdown`
: Model-level spend breakdown from LiteLLM daily activity when available.

`Keys`
: Current key and owned-key budget context loaded lazily from LiteLLM key endpoints.

`Settings`
: Spend limit editing, base URL editing, API-key clearing, and redacted diagnostics.

## Privacy and Safety Notes

- Raw LiteLLM key material is not retained in DTOs or shown in diagnostics.
- Diagnostic endpoint display strips userinfo, query strings, and fragments.
- Persisted base URLs are normalized before save and on load.
- Spend stale-cache fallback is scoped by credential and base URL.
- Key context cache is also scoped by credential and base URL.
- In-flight refresh results are discarded if endpoint-scoped state changes before they return.

## Preview States

Preview states avoid live LiteLLM and credential access:

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

These are useful for quick UI smoke checks without hitting the live LiteLLM deployment.

## Live API Check

The local test suite does not call the live LiteLLM API. To validate the deployment manually without printing credentials:

```bash
ROOT="$LITELLM_BASE_URL"
KEY="$LITELLM_API_KEY"
TODAY="$(date +%Y-%m-%d)"
TOMORROW="$(date -v+1d +%Y-%m-%d)"
USER_ID="$(curl -fsSL -H "Authorization: Bearer $KEY" "$ROOT/user/info" | jq -r '.user_id')"
curl -fsSL -H "Authorization: Bearer $KEY" \
  "$ROOT/spend/logs?user_id=$USER_ID&start_date=$TODAY&end_date=$TOMORROW&summarize=true" \
  | jq '[.[].spend // 0] | add'
```
