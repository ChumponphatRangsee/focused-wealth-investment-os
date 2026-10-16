# PR5 — Native USD market price shadow read (2026-10-15)

**STATE: ADDITIVE SHADOW — NO CONSUMER CUTOVER.**
Depends on stacked PR4 #51 (itself depends on PR3 #50 and PR2 #49).
Repo branch: `feat/pr5-native-usd-price-shadow`.
Supabase project: `ysjbmeukwbfnxnwqchuq` (production-as-test; treat as live).
All changes are bounded to an ADDITIVE DB read RPC and a NEW protected
Edge Function. No old market workers were changed, no provider calls scheduled,
no ledger/holdings/valuation/accounting cutover.

## Live deployment

- Postgres function `fwios.pr5_native_usd_price_shadow_v1(text)`
  created with migration `migrations/20261015_pr5_native_usd_read_shadow_v1.sql`.
  Read-only, `STABLE SECURITY INVOKER`; `anon`/`authenticated`
  EXECUTE revoked; `service_role` only (plus database owner).
- New protected Edge `market-price-usd-shadow-v1`, **ACTIVE v1,
  verify_jwt=true**. Authenticated JWT required by Supabase gateway;
  Edge accepts only GET and a bounded asset query, executes the read-only
  function with parameterized SQL through `SUPABASE_DB_URL`; status:
  200 for verified native USD, 404 for missing native USD, 400 for unknown
  identity, 503 for unavailable DB or contract violation.
  URL: `https://ysjbmeukwbfnxnwqchuq.supabase.co/functions/v1/market-price-usd-shadow-v1?asset=NVDA`.
  **HTTP E2E pending**: no test user JWT exists in this FWIOS Supabase project
  (previous live inspection showed `auth.users=0`). Do NOT claim authenticated
  HTTP requests were end-to-end tested. Presence of `SUPABASE_DB_URL` in
  the Edge runtime has also not been verified by an HTTP request.
- Neither `market-price-canary-v1` v3 nor existing 8 active cron jobs
  nor `portfolio-mtm-refresh-v1` was modified.

## Currency guarantee and source selection

- Only canonical active **Stock** or **Crypto** instruments with unique
  current identity; reject unknown/ambiguous symbols, FX instruments, QA.
- Read ONLY existing `fwios.market_observations` with
  `value_currency='USD'`, positive price, `provenance_status='PASS'`,
  no future timestamp and approved source/status semantics.
- Stocks: Tier A Twelve Data / Alpha Vantage `REGULAR_CLOSE`
  (last-close 5d age gate); Twelve Data `LIVE_QUOTE` only if
  market status OPEN and age <= 15m. No after-hours-as-live.
- Crypto: native USD CoinGecko `LIVE_QUOTE` only, 24/7 session
  semantics, 15m freshness. Existing CoinGecko crypto/THB observations
  **never** converted using USDTHB in PR5.
- Missing native USD returns `status=MISSING`, `price_usd=null` and
  `currency=USD`. Native USD data returns `price_usd` with provider,
  observation ID, session, observed_at, valid_until and exact status.
- Every reply: `read_only=true`, `shadow_only=true`,
  `valuation_eligible=false`, `accounting_eligible=false`,
  `trading_eligible=false`, `new_provider_calls=0`,
  `new_quota_reservations=0`. This API **does not** authorize
  portfolio accounting, valuation inputs or trading.

## Live SQL evidence

Executed `queries/pr5_native_usd_shadow_all.sql` against connected
Supabase on 2026-10-15. Returned **70** active canonical instruments:
- **63 stocks**: LAST_CLOSE, native USD, all valuation-ineligible in shadow.
- **7 MISSING**: BTC, DOGE, ETH, HBAR, SOL, XRP, CRWD.
- **0 incorrect USD currency/native-source/valuation eligible values**.
- Tested symbols BTC, ETH, NVDA, TTWO, CRWD, USDTHB, WDC.
  FX and unsupported symbols were rejected correctly.

Important: 63 last closes is not 63 live real-time quotes; return timestamps
and statuses. Source existence does not guarantee every quote/session is
usable on a future date.

## Native CoinGecko USD adapter — preparation only

`supabase/functions/_shared/pr5_coingecko_usd_adapter.ts` is **pure**
input/output validation with no fetch, no DB or secrets:
- One batch for BTC, ETH, XRP, SOL, HBAR, DOGE.
- `vs_currencies=usd&include_last_updated_at=true`.
- Requires positive numeric USD price and valid <=15m provider timestamp,
  forbids stale/future/missing/THB-only rows as READY.
- `tests/pr5_coingecko_native_usd_adapter_test.ts` contains 8
  synthetic Deno unit test cases. **The 8 tests have now been executed in a Deno 2.x GitHub Actions job:
  8 PASS / 0 FAIL on 2026-10-15**; see the follow-up receipt below.
- There is no scheduled dispatch, network call, quota debit, candidate
  write/publish or legacy-worker replacement.

## Why native USD crypto is not yet dispatched

As inspected 2026-10-15: `COINGECKO` PR4 provider registry is
`active=false`, `readiness_status=DISABLED`,
`migration_state=SHADOW_ONLY`, `plan_id=UNVERIFIED`,
`entitlement_status=UNVERIFIED`, and endpoint cost/reset remain
unverified. Existing legacy `portfolio-mtm-refresh-v1` still requests
CoinGecko `vs_currencies=thb` for portfolio compatibility.
Turning on a separate USD poller without reconciling provider account limits
would violate the quota/single-flight policy. Preserve old worker until
shadow USD ingestion + reconciliation passes; do not re-label THB as USD.

**CRWD:** Active canonical stock identity but no passing USD observation
in the market-observation table; do not fabricate a CRWD price by copying
GoogleFinance output without checked provenance/source semantics.

## Exit criteria and next safely-scoped steps

1. Verify actual CoinGecko plan/endpoint minute/day caps, reset windows and
   billable cost across old+new consumers; test fail-closed reservations.
2. Integrate pure USD batch adapter into the centrally protected
   PR4 cache/single-flight/priority provider dispatch (not raw sidecar HTTP),
   validate and publish six native-USD observations while preserving
   existing THB compatibility feed. Resolve CRWD with a verified USD source.
3. Run all 70 quote currency/freshness/provenance acceptance gates, including
   crypto and currently-held positions.
4. PR6 add Tracker `_Market_Data` shadow USD import (no change to trades
   or Price Data formulas); PR7 cutover only after account/FX reconciliation.
5. Obtain actual authenticated end-to-end HTTP receipt for the Edge.
6. Keep PRs DRAFT until review, and preserve legacy read paths.

## Stop / rollback

New Edge `market-price-usd-shadow-v1` can be disabled without touching
`market-price-canary-v1` or legacy market workers. The additive SQL
function has no writer or downstream production consumer and may be left
installed with private service-role-only execute permissions; no records
to delete. Do not remove canonical price/FX observations or trading history.

## Follow-up receipt — 2026-10-15, PR5 continuation (actual execution)

### Offline unit test CI — PASS

- Added `.github/workflows/pr5-native-usd-adapter.yml` on PR5 branch; workflow uses Deno 2.x with `deno test tests/pr5_coingecko_native_usd_adapter_test.ts`.
- Actual PR #52 [GitHub Actions run #38720690779](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/actions/runs/38720690779) completed **SUCCESS**. Job logs explicitly report **8 passed / 0 failed** (2026-10-15 10:30 UTC).
- Source tests cover USD-only batch URL, all six positive USD responses, THB-only rejection, stale/future timestamps, partial response, invalid prices and duplicate symbol rejection.
- No vendor call, DB write, API key or credential was part of the test. This is **unit coverage only**, not authenticated Edge HTTP E2E or native-USD ingestion.

### Live read-only checks (no changes to workloads)

- Connected Supabase project `ysjbmeukwbfnxnwqchuq`: ACTIVE_HEALTHY; new Edge `market-price-usd-shadow-v1` **ACTIVE v1** and `verify_jwt=true`.
- PR5 shadow SQL coverage still **70 assets: 63 Stock LAST_CLOSE, 6 Crypto MISSING and 1 Stock CRWD MISSING**. Native asset unit USD maintained. Stock last close is **not** a live price.
- RPC grants still `anon=false, authenticated=false, service_role=true`.
- Active cron **8**, Auth users **0**, PR4 IN_FLIGHT **0**.
- `CRWD`: zero rows in `fwios.market_observations` for the canonical symbol at the time of the check. Deeper read-only trace found **0 CRWD jobs in `fwios.market_daily_close_jobs`, 0 rows in `fwios.market_daily_closes`, and 0 CRWD entries in `fwios.market_daily_close_api_usage`**. This establishes absence of ingestion/attempt evidence in those tables (not a proven cause of omission). Diagnose stock-universe/producer coverage before any authorized provider call; no invented quote or GOOGLEFINANCE write.
- CoinGecko unified policy dry-read:
  `fwios.resolve_provider_quota_policy_v1('COINGECKO','CRYPTO_SPOT','/simple/price')`
  returned `reason=PROVIDER_DISABLED`, `allowed=false`, `dispatch_allowed=false`, `policy_ready=false`, `endpoint_credit_cost=null`, `vendor_reset_status=UNVERIFIED`. Registry remains `active=false`, `DISABLED`, `SHADOW_ONLY`, `plan_id=UNVERIFIED`, `entitlement_status=UNVERIFIED`.
- Legacy cron `fwios-portfolio-mtm-refresh` is scheduled `*/15 * * * *` (96 execution *opportunities* per 24 hours; actual request count not proven). Legacy Edge `portfolio-mtm-refresh-v1` uses unauthenticated public `api.coingecko.com/api/v3/simple/price?...` with `vs_currencies=thb`, **no CoinGecko account API key in this call path**, and it does not pass through PR3 CoinGecko reserve/dispatch/finalize. Public per-IP capacity and any later account-key credit bucket must be reviewed separately. Do not falsely treat legacy public requests as demonstrated charges to an unverified future Demo/Pro account.
- Official CoinGecko support (checked 2026-10-15): [credit accounting](https://support.coingecko.com/articles/1864417806-how-does-coingecko-api-count-the-api-usage-credit), [public rate limits](https://support.coingecko.com/articles/5125303456-what-is-the-rate-limit-for-coingecko-api-public-plan), [API account usage through /key](https://support.coingecko.com/articles/1894202112-how-to-check-your-api-call-usage-via-endpoint). Successful HTTP 200 commonly costs one monthly credit, but 4xx/5xx still consume per-minute capacity; actual FWIOS plan, remaining balance, reset and IP/key sharing **NOT VERIFIED**. Checking documentation is not checking entitlement.
- Authenticated Edge HTTP E2E remains **PENDING**: zero Auth users and no authorized user JWT; protected edge DB connection has not been proven via HTTP. Do not disable JWT verification to bypass this.

### Go/no-go

**NO-GO for real provider dispatch or Tracker sync.** Before enabling CoinGecko native USD, verify the actual vendor plan and key/public-IP boundaries, limit/billing windows and endpoint costs; inventory legacy usage; guarantee all new dispatch via PR3 atomic reservation and PR4 single-flight with no duplicate spend; verify native USD persistence and CRWD source. No existing Cron/transaction/holding/cost basis/THB history/Google Sheets data was modified in this continuation.

PR6 design-only prerequisite checklist: [PR6 gated shadow-sync plan](./PR6_PORTFOLIO_TRACKER_SHADOW_SYNC_GATED_PLAN.md). No PR6 live implementation or Sheets cutover yet.


## MVP-first implementation receipt — 2026-10-16

- CI run #38833494783: combined CoinGecko USD+THB adapter tests and Deno worker type-check PASS.
- Deployed existing `portfolio-mtm-refresh-v1` as v2; Cron cadence unchanged. Crypto uses one existing CoinGecko batch request for `usd,thb`; six native USD observations were published while legacy THB snapshots continued.
- Authorized smoke run returned HTTP 200, `usd_updated=6`, no crypto USD errors, portfolio pricing gate PASS, auto_trade=false.
- Added migration `pr5_mvp_canonical_stock_daily_close_coverage_v1`: existing daily-close universe now also includes active canonical common stocks at lowest priority. This added CRWD only in the current universe (63→64 stocks); existing Twelve Data quota guard remained active.
- CRWD targeted backfill: PASS, session 2026-10-14, USD close 249.28999, provider TWELVE_DATA, quota allowed.
- Final PR5 shadow readback: **70/70 covered** — 64 Stock LAST_CLOSE + 6 Crypto FRESH, 0 MISSING.
- Portfolio Tracker hidden `_Market_Data` shadow created separately; no Price Data/Transactions/Holdings/Cost Basis/Cron cutover.
