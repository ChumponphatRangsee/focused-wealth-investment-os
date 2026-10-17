# PR 2 — Unified Provider Registry & Quota Policy (reuse-first)

**Status (2026-10-13):** Database migration APPLIED to the existing Supabase Production project as the authorized test environment. GitHub PR remains DRAFT / unmerged; provider cutover is still OFF.  
**Parent:** FWIOS Architecture Refactor v3 / `docs/implementation/API_QUOTA_IMPLEMENTATION_PLAN.md`.  
**Related:** PR 3 owns shared atomic reservations and usage finalization; PR 4 owns cache/single-flight/priority dispatch.

## What PR 2 actually delivers

1. Reuses **`fwios.decision_refresh_provider_registry`** as the only provider-identity registry.
2. Reuses **`fwios.market_daily_close_policy`** for current Twelve Data operational budgets and **`fwios.decision_refresh_api_quota_policy`** for shared Alpha Vantage budgets. These numeric columns remain authoritative; no second numeric copy is written into the registry.
3. Adds an additive, namespaced `config.unified_quota_v1` provider descriptor: plan identity, route → capability, readiness, credit/reset verification status, existing budget source, quota/accounting-window semantics, protected-capacity intent and 429 handling.
4. For **future providers without a legacy budget table**, permits verified minute/hour/day/concurrency inputs in that provider's **existing registry `config.unified_quota_v1.limits`**, instead of creating `api_provider_registry`, `api_quota_policy` or another table.
5. Adds one **service-role-only read resolver**: `fwios.resolve_provider_quota_policy_v1(provider_key, capability, endpoint)`. This returns normalized internal budgets and a concrete DENY reason for missing/disabled/unverified routes.
6. Adds disabled, **unverified placeholders** for `COINGECKO` and `FRANKFURTER_FX`, because production `portfolio-mtm-refresh-v1` actually accesses those services. This documents dependencies; it does **not** activate a quota-free production route.
7. Keeps all legacy callers, reservation functions, usage tables, cron, Sheets, research, quote stores, portfolio accounting and decision logic untouched.

**Non-negotiable:** Policy discovery is **not** a permit to spend an API credit. All PR 2 resolver results return `allowed=false`, `dispatch_allowed=false`, `cutover=false`. Only PR 3 may grant permission via an atomic shared reservation.

## Verified Supabase inventory at drafting time

| Existing object | Current observed baseline | PR 2 treatment |
| --- | --- | --- |
| `decision_refresh_provider_registry` | 5 registered providers | Reuse; annotate only existing Twelve Data and two Alpha Vantage split-provider rows; two disabled placeholders |
| `market_daily_close_policy` | Twelve Data `per_minute_budget=8`, `daily_budget=700`, `config.daily_reserve=100` | Read values, do not rewrite |
| `decision_refresh_api_quota_policy` | `ALPHA_VANTAGE_SHARED`, daily 25; `PRICE=15`, `VALIDATOR=2`, reserve 3 | Read **operational table**, not stale provider-descriptor hints |
| `market_daily_close_api_usage` | 3,232 entries | Untouched |
| `decision_refresh_api_usage` | 353 entries | Untouched |
| `reserve_market_daily_close_api_call_v1` | Existing Twelve Data minute/day quota reservation | Untouched; PR 3 will integrate |
| `reserve_decision_refresh_api_call_v1` | Existing Alpha quota path | Untouched; existing unconfigured-provider allow path is a known PR 3 blocker |

**Important budget semantics:** Twelve Data's 700/day is the **current worker application budget**, not a newly verified vendor entitlement. The configured 100 daily headroom is outside that 700 worker budget; **do not subtract 100 again**. Alpha Vantage reserve 3 is a **bucket inside** its 25/day total. The active Alpha price-class limit is **15**, despite a distinct old `daily_price_budget=20` hint in provider config. Do not silently resolve that mismatch by increasing the live budget.

Provider entitlements, pricing and reset boundaries depend on the actual account/API plan. Labels such as `BASIC_FREE`, `official_limit`, or historical vendor-support notes are **not sufficient evidence** for `entitlement_status=VERIFIED`.

## Provider × endpoint routing model

| Provider identity | Endpoint key | Capability | Budget source | Initial PR 2 state |
| --- | --- | --- | --- | --- |
| `TWELVE_DATA` | `TIME_SERIES` | `DAILY_CLOSE` | existing `market_daily_close_policy` | Active legacy worker; new resolver denies until verified |
| `TWELVE_DATA` | `QUOTE` | `MARKET_PRICE` | same account budget | New resolver denies until verified |
| `TWELVE_DATA` | `EXCHANGE_RATE` | `FX` | same account budget | New resolver denies until verified |
| `ALPHA_VANTAGE_PRICE` | `TIME_SERIES_DAILY` | `MARKET_PRICE`, `DAILY_CLOSE` | existing `ALPHA_VANTAGE_SHARED` | Active legacy; new resolver denies until verified |
| `ALPHA_VANTAGE_CONSENSUS` | `EARNINGS_ESTIMATES` | `ANALYST_DATA`, `EARNINGS` | same Alpha shared group | Disabled |
| `COINGECKO` | `SIMPLE_PRICE` | `MARKET_PRICE` | existing registry config; limits not populated | Disabled/unverified |
| `FRANKFURTER_FX` | `LATEST` | `FX` | existing registry config; limits not populated | Disabled/unverified |

Other requested capabilities—`FUNDAMENTALS`, `PROFILE`, `RESEARCH_ENRICHMENT`—remain **not configured** and must return DENY rather than selecting a permissive default.

### Normalized policy output

The service-only resolver reports `provider_key`, `provider_group`, `capability`, `endpoint`, `plan_id`, `budget_source`, budget limits, legacy accounting timezone, provider reset verification status, route credit cost, alert thresholds, protected-capacity designation, `policy_ready`, `reason`, and **`dispatch_allowed=false`**.

Example read-only check, executable with the appropriate internal DB role **after staging migration**:

```sql
select fwios.resolve_provider_quota_policy_v1('TWELVE_DATA','MARKET_PRICE','QUOTE');
select fwios.resolve_provider_quota_policy_v1('COINGECKO','MARKET_PRICE','SIMPLE_PRICE');
select fwios.resolve_provider_quota_policy_v1('UNKNOWN','FX','LATEST');
```

Internal accounting timezone from the legacy reservation path (Twelve UTC, Alpha `America/New_York`) is **not** presumed to be the vendor's contractual reset clock.

## What must be verified before a route can be marked ready

- Actual subscribed provider/account plan and whether credit limits are **per API key, account, endpoint or organization**, including shared keys used by both Tracker and Dashboard.
- Contractual minute/hour/day/month and concurrent-request limits, plus explicit `NOT_APPLICABLE` where the vendor genuinely imposes no such limit.
- Endpoint-specific billable credits, whether batch symbols have separate costs, and if 4xx/429/timeouts/retries consume credits.
- Vendor timezone, daily reset schedule, rolling windows, header semantics, `Retry-After` and plan migration behavior.
- Priority reserve across P0 holdings, P1 opportunities, P2 research, P3 watchlist, P4 S&P 500 scanner; alert levels and degradation behavior.
- Verified live caller inventory, including direct `CoinGecko simple/price` and `Frankfurter latest` calls in `portfolio-mtm-refresh-v1`. **These currently bypass the shared reservation path.** PR 3/4 must address them before making a global quota-safety claim.

Never set `entitlement_status=VERIFIED`, `endpoint_cost_status=VERIFIED` or `vendor_reset_status=VERIFIED` based solely on historical config; capture verification evidence and apply changes through a separately reviewed policy update.

## Acceptance and rollout

- Apply migration **only in staging after review**. Keep production flag `cutover=false`.
- Run `tests/market/test_unified_provider_quota_policy_pr2.sql`; verify unknown/disabled/unverified provider DENY, capability/endpoint mismatch DENY, Twelve 8/min + 700/day unchanged, Alpha 25/day + price 15 + reserve 3 unchanged, no public/authenticated execute privilege, original reservation functions still exist.
- Confirm no DDL created new registry, quota-usage or reservation tables; no historical API usage or portfolio records have been changed.
- Verify new resolver returns no `allowed=true` and no network calls are triggered by resolver reads.
- **PR 3 gate:** make the unified reservation enforce global billable credits and fail closed (including the legacy `UNLIMITED_OR_UNCONFIGURED` path) before any new consumer uses policy results.
- **PR 4 gate:** protected P0 refresh, cache/single-flight and bounded retry must pass before broad Scanner rollout.

## Rollback

The proposed migration is additive. With no consumer cutover, simply stop using the resolver. If schema rollback is explicitly needed, drop only `resolve_provider_quota_policy_v1`, remove only the `unified_quota_v1` namespace added to existing rows, and remove the two placeholder rows **only if no new dependency references them**. Never truncate or alter legacy usage, price, or transaction history.

**Deployment/test receipt (2026-10-13):** Supabase migration `fwios_pr2_unified_provider_registry_quota_policy_v1` applied successfully to project `ysjbmeukwbfnxnwqchuq`. Read-only regression SQL passed; resolver is deny-by-default, anon cannot execute it, service_role can. Provider registry has 7 rows including disabled CoinGecko and Frankfurter placeholders. No Edge Function deployment, provider cutover, credential rotation, provider API calls, broker trades, portfolio edits, Google Sheets writes or GitHub merge.
