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
  synthetic Deno unit test cases. **Unit tests are checked in, but no
  Deno test runner was available in this execution environment; do not
  report test suite as executed**.
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
