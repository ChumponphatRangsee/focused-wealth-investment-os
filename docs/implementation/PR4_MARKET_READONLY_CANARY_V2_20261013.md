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


## Existing Google Sheets consumer — Canary snapshot

**Connector write completed 2026-10-13 14:19:43 ICT.** The operational display for
this FWIOS project is a Google Sheet, NOT the independent `Research-Ledger`
Next.js frontend (that app has a separate source-of-truth and auth contract).
The same FWIOS Supabase project has **zero `auth.users`** at inspection;
therefore there is no pre-existing user JWT to reuse for authenticated Edge E2E.
Do not insert a service-role key into Sheets or mint a fake user JWT.

Updated the *existing* **Focused Wealth Dashboard - Chumponphat**:

- Spreadsheet ID `17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8`.
- Added new visible tab `PR4 Canary Snapshot`, sheetId `1579369903`.
- Captured four prices from `fwios.pr4_market_canary_quote_v2` at
  `2026-10-13T07:19:43.873001Z` (read-only query), and wrote a provenance-
  labeled fixed snapshot to `A1:L14`:
  - BTC/THB 2,807,143 (`FRESH` at capture, observed 07:14:47Z)
  - NVDA/USD 226.32001 (`LAST_CLOSE`, session 2026-10-12)
  - TTWO/USD 208.82001 (`LAST_CLOSE`, session 2026-10-12)
  - USDTHB 33.62546 (`STALE` and `FX_ATTACHED_REFERENCE`)
- Each row contains provider, session, observed time, captured time, TTL,
  accounting eligibility `NO`, and observation UUID. Price is a numeric
  cell; **price status is an at-capture label, never implied to auto-refresh**.
- The tab explicitly says *STATIC SNAPSHOT / NOT AUTO-REFRESH* and prohibits
  trading, portfolio valuation and accounting usage.
- Did NOT edit Dashboard, `_Data`, any scanner tab, Tracker, holdings,
  transactions, trading history, cost basis, provider registry or worker cron.
- Verified Google Sheets readback of header, values, notes, layout, and number
  formatting after writing. No direct database or provider credential appears
  in the new Sheet; only the authenticated Edge URL is referenced as text.

**Integration status**: first real Supabase-to-operational-Google-Sheet *snapshot*
completed. This is not continuous integration or a dynamic GET through Google
Sheets. Automatic synchronization still requires a **separately authorized**
server-side refresh mechanism with least privilege (not `IMPORTDATA` with a
secret URL), or an actual Supabase Auth user in the same FWIOS project for an
interactive dashboard. No such mechanism was silently enabled.

This snapshot can be removed by deleting only `PR4 Canary Snapshot` after
confirming no new references were added (none were added by this rollout).


## Supabase-only transition — 2026-10-13 17:35 ICT

**CURRENT STATE SUPERSEDES PREVIOUS GOOGLE SHEETS SNAPSHOT INSTRUCTIONS ABOVE.**
The owner requested stopping automated Google Sheets price sync and using Supabase
as the sole interactive read location for this *PR4 canary*. The scope is the
canary only; the unrelated operational Google Sheets dashboard, portfolio
Tracker and other live workflows were not cut over.

1. **Automation disabled:** `FWIOS PR4 Canary Sync` is set `is_enabled=false`
   (previously hourly). Existing older `Dashboard Market Sync` was already
   disabled and was not changed. No further scheduled canary writes to Sheets.
2. **Sheet projection removed:** deleted exclusively the owned sheet tab
   `PR4 Canary Snapshot`, sheetId `1579369903`, in spreadsheet
   `17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8`. Pre-delete
   inspected 6,533 cells including 172 formulas across other five tabs;
   found **zero** references to the temporary canary tab. Post-delete
   metadata readback confirmed all five operational tabs remain: Dashboard,
   Valuation Map, Thesis Tracker, Opportunity Quality, _Data. Trading ledger
   / holdings / portfolio Tracker were not edited.
3. **Supabase read-only replacement, verified:** query the existing
   `fwios.pr4_market_canary_quote_v2(asset)` function through a SELECT in
   the Supabase project SQL Editor. Exact runnable query is versioned as
   [queries/pr4_market_canary_current.sql](../../queries/pr4_market_canary_current.sql).
   This query returns four rows from existing canonical observations, with
   freshness/session/provenance and explicit ineligible trading/accounting
   flags, **without adding storage or invoking provider APIs**. Validated
   four expected symbols and false valuation/accounting eligibility at
   `2026-10-13 10:35:14 UTC`: BTC 2,798,701 THB (`FRESH` at check),
   NVDA 226.32001 USD (`LAST_CLOSE`), TTWO 208.82001 USD
   (`LAST_CLOSE`), USDTHB 33.62546 THB (`STALE`). These are not fixed
   current prices; new SQL SELECT runs recalculate freshness.
4. **No extra DB view deployed:** An additional optional view migration was
   proposed but the tool's safety gate rejected deployment. The un-applied
   migration was immediately removed from the PR branch. The existing
   `fwios.pr4_market_canary_quote_v2` RPC is sufficient and remains
   untouched.
5. **Auth boundaries remain:** SQL Editor requires a project admin session.
   The previous Edge Function `market-price-canary-v1` remains deployed
   with `verify_jwt=true`; an authenticated end-to-end HTTP request has
   **not** been verified, and the FWIOS Supabase project had 0 `auth.users`
   on inspection. Therefore **no standalone web price dashboard** or
   end-user browser auth was implemented in this transition.

**Rollback:** no automated canary sync is needed. To recreate a snapshot,
explicitly request it; otherwise leave Google Sheets untouched. All
legacy market provider workers and Cron remain subject to their prior
policies; this work does not represent external-provider dispatch cutover.
