# Research: User Dollar Spend API Support

**Date:** 2026-05-18
**Status:** Complete
**Scope:** Focused API contract analysis
**Focus:** Identify LiteLLM API endpoints that can support a macOS menu bar app showing how much a user has spent in dollars.

---

## High-Level Architecture

This repository is newly initialized and has no application code yet. The only implementation-relevant contract is the LiteLLM OpenAPI spec captured from `https://litellm-api.up.railway.app/openapi.json` into `context/data/2026-05-18-litellm-openapi.json`.

```
macOS menu bar app
  -> stores LiteLLM base URL + API key in Keychain
  -> calls LiteLLM proxy API over HTTPS
  -> reads spend fields from user or analytics endpoints
  -> renders dollar spend in menu bar and detail popover
```

The spec reports `LiteLLM API` version `1.82.6`.

---

## Relevant Components

### LiteLLM OpenAPI Contract

- **Purpose:** Defines the available proxy API endpoints and response schemas.
- **Key files:** `context/data/2026-05-18-litellm-openapi.json`
- **Public API / Interface:** OpenAPI 3.1.0; relevant endpoints under `Internal User management` and `Budget & Spend Tracking`.
- **Dependencies:** Hosted LiteLLM proxy API at `https://litellm-api.up.railway.app/`.
- **Test coverage:** None in this repository yet. Future client tests should use local JSON fixtures based on these response schemas.

### Authentication Boundary

- **Purpose:** Authorize spend queries.
- **Contract:** Security scheme `APIKeyHeader` is an API key in header `x-litellm-api-key`; description says `Bearer token`.
- **Important ambiguity:** Endpoint examples in descriptions often use `Authorization: Bearer sk-1234`, while OpenAPI declares `x-litellm-api-key`. Live testing against `https://litellm.justworksai.net` showed both headers work for `GET /v1/models`, but `Authorization: Bearer <key>` is the known-good header for `GET /user/info` and `GET /spend/logs`.

### Live Justworks Deployment Findings

- **Base URL:** `https://litellm.justworksai.net`
- **Validated with:** Existing Claude Code / LiteLLM environment credentials on 2026-05-18.
- **Credential role:** `internal_user`, not `proxy_admin`.
- **OpenAI-compatible health check:** `GET /v1/models` returned `200`.
- **Current total user spend:** `GET /user/info` returned `user_info.spend`.
- **Today spend:** `GET /spend/logs?user_id=<user_id>&start_date=2026-05-18&end_date=2026-05-19&summarize=true` returned summarized rows whose `spend` values can be summed.
- **Unavailable for current credentials:** `GET /user/daily/activity/aggregated`, `GET /spend/logs/v2`, and `GET /user/list` returned `401` because they require `proxy_admin` for this deployment.
- **Unavailable on this deployment:** `GET /v2/user/info` returned `404`; use `GET /user/info` instead.

---

## API Contracts

### Validated Primary Endpoint: `GET /user/info`

- **Location:** `paths["/user/info"]`, response schema `UserInfoResponse`.
- **Type:** OpenAPI endpoint.
- **Covers:** Current authenticated user row plus associated key information.
- **Query params:** Optional `user_id`; for the menu bar app, omit it and let LiteLLM resolve the current user from the API key.
- **Auth:** `Authorization: Bearer <api-key>` validated against `https://litellm.justworksai.net`.
- **Response fields relevant to app:**
  - `user_id: string`
  - `user_info.spend: number` current total user spend
  - `user_info.max_budget: number | null`
  - `user_info.budget_reset_at: date-time | null`
  - `user_info.budget_duration: string | null`
  - `user_info.user_email: string | null`
  - `user_info.user_role: string | null`
  - `keys[]`: key-level spend records; useful for optional detail views, not for the primary user total
- **Planning implication:** Use this endpoint at startup to discover the current user id and budget metadata. It can also display account/budget-period total spend, but it should not be the default menu bar number because the product requirement is "today's spend".

Example request shape:

```http
GET /user/info
Authorization: Bearer <api-key>
```

Example parser target:

```json
{
  "user_id": "4a5641d6-f56a-4657-aa55-98cb447fec95",
  "user_info": {
    "spend": 524.3974209499993,
    "max_budget": 2400.0,
    "budget_reset_at": "2026-06-01T00:00:00Z",
    "user_email": "blai@justworks.com",
    "user_role": "internal_user"
  }
}
```

### Validated Range Endpoint: `GET /spend/logs`

- **Location:** `paths["/spend/logs"]`, response schema array of `LiteLLM_SpendLogs-Output`.
- **Type:** OpenAPI endpoint.
- **Covers:** Date-filtered user spend. This is marked deprecated in the generic LiteLLM spec, but it is the only validated range-spend endpoint available to the current `internal_user` credentials.
- **Query params for menu bar totals:**
  - `user_id`: current user id from `GET /user/info`
  - `start_date`: local calendar start date in `YYYY-MM-DD`
  - `end_date`: local calendar exclusive end date in `YYYY-MM-DD`; use tomorrow for "today"
  - `summarize=true`: avoids raw request/response payloads and returns aggregate rows
- **Response fields relevant to app:**
  - `[].startTime`: date bucket such as `2026-05-18`
  - `[].spend`: numeric dollar spend for that bucket
  - `[].models`, `[].users`, and key-hash fields: optional detail breakdowns
- **Observed behavior:** A today query from `2026-05-18` to `2026-05-19` returned two rows: one spend row for `2026-05-18` and a zero-spend row for `2026-05-19`. The client should sum `spend` across all returned rows and not assume exactly one row per range.
- **Privacy implication:** Keep `summarize=true` for normal app refreshes. `summarize=false` returns raw logs containing request/response payload fields and should be avoided unless an explicit diagnostics view is added.

Example request shape:

```http
GET /spend/logs?user_id=<user_id>&start_date=2026-05-18&end_date=2026-05-19&summarize=true
Authorization: Bearer <api-key>
```

Example parser target:

```json
[
  {
    "startTime": "2026-05-18",
    "spend": 7.5715082499999955
  },
  {
    "startTime": "2026-05-19",
    "spend": 0
  }
]
```

Display total = `sum(row.spend ?? 0)`.

### Required Menu Bar Spend Counts

The default menu bar display should be today's spend. Additional views can reuse the same `/spend/logs` summarized range call.

| Count | Range Semantics | `start_date` | `end_date` |
|-------|-----------------|--------------|------------|
| Today | Current local calendar day | today | tomorrow |
| Last 7 days | Seven local calendar days including today | today minus 6 days | tomorrow |
| Last 30 days | Thirty local calendar days including today | today minus 29 days | tomorrow |
| Month-to-date | Current local month through today | first day of current month | tomorrow |
| Year-to-date | Current local year through today | January 1 of current year | tomorrow |

Use local calendar dates for user-facing ranges. The API accepts date strings without explicit timezone, so compute ranges in the user's local timezone and keep the displayed label explicit.

### Visualization Granularities

- **Single total:** Sum all returned `spend` values for the selected range.
- **Daily chart:** Group returned rows by `startTime` and plot `sum(spend)` per date.
- **Model breakdown:** Use `models` from summarized rows if present; validate the live shape before relying on it.
- **Key breakdown:** Summarized rows include hashed key fields; avoid displaying hashes by default. For friendlier labels, map details from `/user/info.keys[].key_alias` where available.

### Recommended Primary Endpoint: `GET /v2/user/info`

- **Location:** `paths["/v2/user/info"]`, response schema `UserInfoV2Response`.
- **Type:** OpenAPI endpoint.
- **Covers:** Lightweight user lookup with direct dollar spend field.
- **Query params:** Optional `user_id`.
- **Access control from spec description:**
  - Proxy admins can query any user.
  - Team admins can query users in their teams.
  - Internal users can query themselves by omitting `user_id` or passing their own.
  - Nonexistent or unauthorized users return 404.
- **Response fields relevant to app:**
  - `user_id: string`
  - `spend: number` default `0.0`
  - `max_budget: number | null`
  - `budget_duration: string | null`
  - `budget_reset_at: date-time | null`
  - optional identity fields: `user_email`, `user_alias`, `user_role`
- **Spec-implementation consistency:** Spec is internally coherent and explicitly says this replaces the older `/user/info` endpoint to avoid loading keys and teams.
- **Planning implication:** This remains the preferred generic LiteLLM contract, but live testing against `https://litellm.justworksai.net` returned `404`. Do not use it as the first implementation target for this app.

Example request shape:

```http
GET /v2/user/info?user_id=user123
x-litellm-api-key: <api-key>
```

For the current authenticated internal user, try omitting `user_id`:

```http
GET /v2/user/info
x-litellm-api-key: <api-key>
```

### Recommended Time-Range Endpoint: `GET /user/daily/activity/aggregated`

- **Location:** `paths["/user/daily/activity/aggregated"]`, response schema `SpendAnalyticsPaginatedResponse`.
- **Type:** OpenAPI endpoint.
- **Covers:** Aggregated spend analytics for a user without pagination.
- **Query params:** Optional `start_date`, `end_date`, `model`, `api_key`, `user_id`, `timezone`.
- **Response fields relevant to app:**
  - `metadata.total_spend: number` default `0.0`
  - `results[].date: date`
  - `results[].metrics.spend: number`
  - `results[].metrics.total_tokens`, `api_requests`, `successful_requests`, `failed_requests`
- **Spec-implementation consistency:** Response schema is structured and usable. Endpoint description says it returns the same response shape as the paginated endpoint with single-page metadata.
- **Planning implication:** Use this when the UI needs spend for a time window like today, this week, this month, or since last budget reset. It is better than summing raw logs.

Example request shape:

```http
GET /user/daily/activity/aggregated?user_id=user123&start_date=2026-05-01&end_date=2026-05-18&timezone=240
x-litellm-api-key: <api-key>
```

### Paginated Analytics Endpoint: `GET /user/daily/activity`

- **Location:** `paths["/user/daily/activity"]`, response schema `SpendAnalyticsPaginatedResponse`.
- **Type:** OpenAPI endpoint.
- **Covers:** Paginated version of daily user spend analytics.
- **Query params:** Same as aggregated, plus `page` and `page_size` with max `1000`.
- **Caveat:** Description marks it `[BETA] This is a beta endpoint. It will change.`
- **Planning implication:** Avoid as the default unless large date ranges or per-day paging become necessary. Prefer `/user/daily/activity/aggregated`.

### Admin / Lookup Endpoint: `GET /user/list`

- **Location:** `paths["/user/list"]`, response schema `UserListResponse`.
- **Type:** OpenAPI endpoint.
- **Covers:** Paginated user lookup with filtering and sorting.
- **Query params:** `user_ids`, `sso_user_ids`, `user_email`, `team`, `role`, pagination, sorting.
- **Response fields:** `users[]` items are `LiteLLM_UserTableWithKeyCount-Output`, which should include user table fields such as `spend`.
- **Planning implication:** Useful for admin setup/search flows where the app needs to resolve an email or choose among users. It is not the simplest way to show a single authenticated user's own spend.

### Legacy / Heavier Endpoint: `GET /user/info`

- **Location:** `paths["/user/info"]`, response schema `UserInfoResponse`.
- **Type:** OpenAPI endpoint.
- **Covers:** User row plus all user key info.
- **Query params:** Optional `user_id`.
- **Caveat:** The v2 endpoint explicitly describes this as a "god endpoint" that loads all keys and teams into memory.
- **Planning implication:** Generic LiteLLM guidance would avoid this for polling, but this is the validated primary user-info endpoint for the Justworks deployment. Poll it less frequently than `/spend/logs`; use it for user id discovery and budget metadata.

### Raw Logs Endpoint: `GET /spend/logs/v2`

- **Location:** `paths["/spend/logs/v2"]`.
- **Type:** OpenAPI endpoint.
- **Covers:** Paginated spend logs.
- **Query params relevant to users:** `user_id`, `end_user`, `api_key`, `team_id`, `start_date`, `end_date`, `page`, `page_size`, `model`, status/error filters, sorting.
- **Response fields:** Spec only declares a generic object with `additionalProperties: true`; description says it returns `data`, `total`, `page`, `page_size`, and `total_pages`.
- **Planning implication:** Good for drill-down/detail views, not the primary total. Because the response schema is loose, client parsing must be defensive. If used to calculate totals, fetch all pages and sum `spend`, but prefer analytics endpoints for totals.

### Deprecated Raw Logs Endpoint: `GET /spend/logs`

- **Location:** `paths["/spend/logs"]`, response schema array of `LiteLLM_SpendLogs-Output`.
- **Type:** OpenAPI endpoint.
- **Covers:** Non-paginated spend logs, filterable by `api_key`, `user_id`, `request_id`, date range, and `summarize`.
- **Caveat:** Description explicitly marks it deprecated and warns it can cause performance issues.
- **Planning implication:** Generic LiteLLM guidance says avoid this for performance, but the Justworks deployment allows this endpoint for `internal_user` credentials while blocking `/spend/logs/v2` and analytics endpoints. Use `summarize=true`, date-bounded ranges, conservative refresh intervals, and defensive parsing.

### Global Spend Report: `GET /global/spend/report`

- **Location:** `paths["/global/spend/report"]`.
- **Type:** OpenAPI endpoint.
- **Covers:** Daily spend grouped by `team`, `customer`, or `api_key`; filterable by `internal_user_id`, `team_id`, `customer_id`, `api_key`, dates.
- **Response caveat:** Response schema is an array of `LiteLLM_SpendLogs-Output`, but the description shows a grouped report shape. This is inconsistent.
- **Planning implication:** Not ideal for direct user spend display. Consider only for admin/global dashboards after validating real responses from the target deployment.

### Key Spend Endpoints

- **`GET /key/info`:** Returns key info; schema is empty, but description says if no `key` is passed it uses the authorization key. Likely includes key-level `spend`.
- **`GET /key/list`:** Can filter by `user_id` and return full key objects with `spend` fields in `UserAPIKeyAuth`.
- **Planning implication:** Use only if product requirements shift from "user spend" to "spend by API key". Key totals can differ from user totals when a user owns multiple keys, team keys, or created-by keys.

---

## Existing Patterns

- **Error handling:** OpenAPI consistently documents `422` validation errors. Some endpoint descriptions mention `404` for nonexistent/unauthorized users, but `/v2/user/info` only documents `200` and `422` in the formal response map.
- **Logging:** No client-side logging patterns exist yet. The app should avoid logging API keys and raw message/response bodies from spend logs.
- **Testing:** No code exists yet. Plan should introduce fixtures for `UserInfoV2Response`, `SpendAnalyticsPaginatedResponse`, auth failures, and malformed/partial responses.
- **Dependency injection:** No app structure exists yet. Plan should isolate a LiteLLM client interface from menu bar UI so endpoint behavior can be tested without network calls.
- **Config management:** Base URL, API key, optional user id, auth header mode, and preferred spend window should be user-configurable. API key belongs in macOS Keychain.

---

## Graceful Degradation

| External Dependency | Failure Handling |
|--------------------|------------------|
| LiteLLM API unreachable | Keep last known spend in memory or local cache, show stale timestamp, and expose a retry action. |
| Auth rejected | Show unauthenticated/error state and prompt to update API key. Do not retry aggressively. |
| `/v2/user/info` unavailable | Try `/user/daily/activity/aggregated` for configured date range if user id is known; otherwise show endpoint unsupported. |
| Analytics endpoint returns partial/malformed metadata | Sum `results[].metrics.spend` as fallback, mark total as derived. |
| Loose `/spend/logs/v2` response shape | Treat only as detail/fallback; parse defensively and avoid relying on undocumented keys for primary totals. |

---

## Gaps & Inconsistencies

- Auth header mismatch: OpenAPI security scheme declares `x-litellm-api-key`, while examples use `Authorization: Bearer ...`. `Authorization: Bearer <api-key>` is validated for the required Justworks endpoints.
- Dollar semantics are implicit. Fields named `spend`, `total_spend`, and `cost` appear to represent dollar cost, but the spec does not explicitly state currency or precision.
- `/user/info.user_info.spend` does not state whether it is lifetime spend, current budget-period spend, or post-reset spend. Pair it with `budget_duration` and `budget_reset_at`, and validate behavior against real data.
- `/user/daily/activity` is beta. Prefer `/user/daily/activity/aggregated` for time-window totals, but design the client so endpoint changes are isolated.
- `/user/daily/activity/aggregated` and `/spend/logs/v2` are blocked for the current `internal_user` credentials on the Justworks deployment.
- `/spend/logs/v2` has useful filters but a weak response schema. It should not be the first-choice source for the first version.
- `/global/spend/report` response schema conflicts with its prose description; avoid until real payloads are sampled.

---

## Recommendations

- Default menu bar display: call `GET /spend/logs` with `summarize=true` for today's local date range and display the summed `spend`, rounded to currency.
- Startup/config refresh: call `GET /user/info` to discover `user_id`, user email, total user spend, max budget, and budget reset metadata.
- Range views: use the same summarized `/spend/logs` call for today, last 7 days, last 30 days, month-to-date, and year-to-date by changing `start_date` and exclusive `end_date`.
- Visualization: build totals and daily charts from summarized rows first. Add model/key breakdowns only after validating the summarized row shape across broader ranges.
- Client design: implement a small typed LiteLLM client with endpoint-specific decoders and clear fallback rules. Keep auth header handling configurable, but default to `Authorization: Bearer <api-key>` for the Justworks deployment.
- Avoid `summarize=false` for normal app usage because raw logs include request and response payload fields.
