# FWIOS v3 PR4 — BTC/THB Real-Data Read-Only Canary (2026-10-13)

Status: **DEPLOYED DATA ACCESS / EDGE HTTP AUTHENTICATED INVOCATION PENDING.**
This is a *live existing-observation read path*, not PR4 vendor dispatch cutover.

## Scope

- Supabase project: `ysjbmeukwbfnxnwqchuq` (owner-authorized production-as-test).
- Source: existing canonical `fwios.market_observations`, BTC instrument UUID
  `2653312e-698d-4678-8975-0dd2c1b32901`, provider `COINGECKO`, BTC/THB,
  observation type `LIVE_QUOTE`, market status `24X7`, provenance `PASS`, tier `B`.
- No new provider HTTP call, billing reservation, API key, cron change, trade mutation,
  holdings edit, Google Sheets write, or accounting/valuation cutover.
- New database function `fwios.pr4_btc_canary_market_quote_v1()` is
  `SECURITY INVOKER`, fixed instrument, service-role-only EXECUTE.
- New Edge Function `market-price-canary-v1` v1, GET-only, JWT gate
  `verify_jwt=true`; permits gateway-verified JWT roles `authenticated` or
  `service_role` and calls only the fixed DB function. No bypass path to provider APIs.
- Endpoint: `GET /functions/v1/market-price-canary-v1`; authorization:
  `Authorization: Bearer <SUPABASE_USER_JWT>`. Never put a service-role key
  or database URL in frontend code, chat, issue comments, or logs.
- The Edge runtime requires its existing `SUPABASE_DB_URL` environment variable.
  Deploy success **does not prove** that the env exists or that an authenticated
  GET succeeded. If missing, the implementation returns
  `CANARY_DB_NOT_CONFIGURED` with 503.

## Data contract

On valid existing observation, return:
`status=FRESH|STALE`, `instrument=BTC`, `price`, `currency=THB`,
`observation_id`, `provider=COINGECKO`, `source_tier`,
`observed_at`, `valid_until`, `session_date`, `checked_at`,
`market_status=24X7`, `new_provider_calls=0`,
`new_quota_reservations=0`, `canary_only=true`,
`accounting_eligible=false`, `valuation_eligible=false`,
`trading_eligible=false`.

`FRESH` requires `observed_at` within 15 minutes, not in the future by >5
seconds, and UTC session date equal to the current UTC date.
All other valid historical prices return **STALE**, never silently a live valuation.
No valid records => `MISSING`. This may reveal the last known price, but
must never authorize portfolio accounting or a trade.

## Verified 2026-10-13 receipts

1. **APPLIED** `fwios_pr4_btc_readonly_canary_v1` on production-as-test.
2. **PASS — SQL live read**: at `2026-10-13T06:52:20Z` returned BTC/THB
   2,807,728, provenance COINGECKO, observed `06:44:36Z`, status FRESH
   at that moment; `new_provider_calls=0` and `accounting_eligible=false`.
   This price is historical evidence only, not a current live quote guarantee.
3. **PASS — permissions**: `anon=false`, `authenticated=false`,
   `service_role=true` for direct PostgreSQL function EXECUTE.
4. **DEPLOYED** Edge Function `market-price-canary-v1` v1, status ACTIVE,
   `verify_jwt=true`. **Authenticated HTTP GET NOT VERIFIED**: this session's
   external execution environment could not resolve the Supabase host.
   No real JWT was supplied or used.
5. **PASS — post-deploy DB isolation check**: zero PR4 flights, QA providers,
   QA observations, QA usage rows and ACTIVE provider dispatch policies.
6. Original production market/portfolio workers remain unchanged.
   PR #49/#50/#51 remain draft and unmerged.

## Next practical gate (minimum)

Invoke the read-only Edge GET exactly once from an authorized server/client
that already has a real Supabase user JWT. Verify:
- HTTP 200 plus `FRESH|STALE|MISSING` (never assume FRESH).
- `cache_origin=EXISTING_CANONICAL_OBSERVATION` for a price result.
- No new API quota usage and no QA or PR4 flight rows.
- 401/403 for missing/anon token; no secret leak.

If HTTP 503, inspect Edge function logs, verify DB URL secret is configured,
and check networking **without exposing credentials**.
Keep provider dispatch disabled until vendor limits and reset/credit rules
are verified and a separate, limited one-instrument dispatch canary is ready.
Do not modify original portfolio workers or Tracker transactions.

## Rollback

If unwanted, stop exposing the new read-only endpoint by removing its deployment
or changing it to refuse requests. **Do not** delete or rewrite canonical
observations. The new DB function can remain inaccessible to frontend roles.
Provider cutover is already OFF; the original workers remain untouched.
