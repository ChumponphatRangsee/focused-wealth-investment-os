# FWIOS PR4 — Market Canary v2 (read-only real observations)

**Date:** 2026-10-13
**Target:** Supabase project `ysjbmeukwbfnxnwqchuq`
**Status:** **DB live read PASS / Edge deployment v2 ACTIVE / authenticated Edge HTTP GET NOT YET VERIFIED.**
This is deliberately *not* a vendor-dispatch, ledger, holdings, or portfolio valuation cutover.

## What was deployed

- Applied `fwios_pr4_market_readonly_canary_v2` migration, version `20261013070328`.
- New service-role-only, `SECURITY INVOKER` DB function:
  `fwios.pr4_market_canary_quote_v2(asset text)`.
- Updated `market-price-canary-v1` to deployed Edge **version 2**, `verify_jwt=true`,
  with browser preflight and GET-only access, strict asset allowlist and parameterized SQL.
- Existing `market-price-canary-v1` bare GET still defaults to BTC, preserving
  initial BTC-only caller behavior.
- Authenticated client implementation example:
  `examples/fwios-market-canary-client.ts`. It is not wired into a frontend,
  because this repository has no verified frontend app/package to safely modify.

### Endpoints

```text
GET https://ysjbmeukwbfnxnwqchuq.supabase.co/functions/v1/market-price-canary-v1?asset=BTC
GET https://ysjbmeukwbfnxnwqchuq.supabase.co/functions/v1/market-price-canary-v1?asset=NVDA
GET https://ysjbmeukwbfnxnwqchuq.supabase.co/functions/v1/market-price-canary-v1?asset=TTWO
GET https://ysjbmeukwbfnxnwqchuq.supabase.co/functions/v1/market-price-canary-v1?asset=USDTHB
```

For a real signed-in user, send headers `Authorization: Bearer <USER_ACCESS_TOKEN>`
and `apikey: <PUBLIC_PUBLISHABLE_KEY>`. The JWT MUST be
validated by Supabase Edge gateway; no service-role credentials in the browser.
Do not write tokens to logs, GitHub, or a document.
No backend credentials are required by the client. The server Edge runtime uses
its existing `SUPABASE_DB_URL` secret; availability of this secret was not proven
via an authenticated HTTP GET.

## Strict result contract

| Asset | Source | Quote type | Data state |
|---|---|---|---|
| BTC/THB | COINGECKO | LIVE_QUOTE | FRESH within 15 min UTC-day otherwise STALE |
| NVDA/USD | TWELVE_DATA | REGULAR_CLOSE | LAST_CLOSE if under five days; otherwise STALE |
| TTWO/USD | TWELVE_DATA | REGULAR_CLOSE | LAST_CLOSE if under five days; otherwise STALE |
| USD/THB | TWELVE_DATA_FX | FX attached to NVDA | FRESH_REFERENCE if under 30 minutes, otherwise STALE |

**No live WDC identity confirmed** for this canary; WDC returns UNSUPPORTED.
The FX row is an attached cross-currency *reference*, NOT an independent
canonical FX instrument and MUST NOT become the accounting FX source.
`LAST_CLOSE` never implies the market is currently open, while
`FRESH_REFERENCE` must not be interpreted as an actionable trading FX rate.
All paths set `canary_only=true`, `accounting_eligible=false`,
`valuation_eligible=false`, `trading_eligible=false`,
`new_provider_calls=0` and `new_quota_reservations=0`.
Freshness/status is always evaluated per invocation.

## Evidence captured at 2026-10-13 07:03:40 UTC

- BTC **2,807,777 THB**, `FRESH`, 2026-10-13 06:59:39 UTC observation
- NVDA **226.32001 USD**, `LAST_CLOSE`, session 2026-10-12
- TTWO **208.82001 USD**, `LAST_CLOSE`, session 2026-10-12
- USDTHB **33.62546 THB**, `STALE`, attached FX observed 2026-10-12
- `WDC` => `UNSUPPORTED`, no provider network requests or writes
- Function EXECUTE: `anon=false`; `authenticated=false`; `service_role=true`.
- Post-deployment counters: **0** PR4 flights, QA providers, QA observations,
  QA usage, and `migration_state=ACTIVE` provider routes.
  Eight active legacy cron jobs unchanged.
- Security advisor returned existing INFO `rls_enabled_no_policy` warnings
  on private internal `fwios` tables; these are **not** grounds to open policies.
  See https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy.

## Remaining one-step E2E acceptance

There is no authenticated Supabase user session/JWT provided to this execution
environment, and it cannot resolve the project host via HTTPS from its local
container. Therefore an authenticated `GET ?asset=NVDA` is **PENDING**.
On the user's already signed-in client, use
`readMarketCanary(supabase, PUBLIC_PUBLISHABLE_KEY, "NVDA")`
and verify HTTP success, `status=LAST_CLOSE`, `valuation_eligible=false`.
The client helper is a code example, not proof that the user's frontend is wired.

If GET returns 503, inspect Edge logs and the presence (not the value) of
`SUPABASE_DB_URL`; do not reveal credentials.
If browser CORS or JWT gateway authentication fails, fix only the new canary
Edge deployment, preserving `verify_jwt=true` and never relaxing DB grants.
See Supabase's authentication docs:
https://supabase.com/docs/guides/functions/auth

## Stop / rollback

The canary has **no** vendor dispatcher activation or production consumer.
To stop, disable/delete only `market-price-canary-v1` Edge deployment.
Do NOT delete canonical market observations or adjust Sheets, transaction ledger,
holdings, the eight active cron jobs, or existing production Edge workers.
PR #49/#50/#51 remain draft and unmerged.
