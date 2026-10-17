# PR6 preparation — Portfolio Tracker native-USD shadow sync (GATED, NOT ENABLED)

**Date:** 2026-10-15 (Asia/Bangkok)  
**Status:** FIRST WORKING SHADOW IMPLEMENTED 2026-10-16; hidden `_Market_Data` snapshot exists in the Tracker. No Price Data/Transactions/Holdings/Cost Basis formula cutover and no new sync Cron.  
**Prerequisite:** PR5 #52 must meet ingestion, security, source and quota gates first.

## Ownership invariant

- Supabase is the source of canonical **native USD asset market prices** with observation identity, provenance, time, provider, freshness/session and eligibility.
- USDTHB is a distinct **FX reference**, quoted as THB per USD. Google Sheets owns the USD × validated USDTHB calculation for THB display.
- `Investment Portfolio Tracker - Chumponphat` remains source of truth for executed transactions, holdings quantities, cost basis, cash and realized/unrealized P&L.
- Historical original THB observations/trades **must never** be re-labeled USD, repriced or rewritten.
- `Focused Wealth Dashboard - Chumponphat` remains scanner/research and must not become a transaction ledger.

## Prerequisite acceptance gates (all required)

1. PR5 native USD quote coverage and exact instrument identity: 70/70 current active canonical supported assets **or explicit MISSING and cutover blocked**. Include all currently-held symbols; CRWD currently has **zero** canonical source observations and six crypto lack native USD. A status of LAST_CLOSE is not a live quote.
2. Vendor entitlements and **combined consumer budget** verified for real deployed plan, endpoint, rate windows/reset time zone, credit cost, error and 429 rules. Legacy `portfolio-mtm-refresh-v1` calls CoinGecko public `api.coingecko.com` unauthenticated for THB with active `*/15 * * * *` cron; assess IP/public rate pressure separately from any future account/key credit bucket. PR3 reserve/dispatched/finalized + PR4 cache/single-flight must cover every new call. No double-spend/fallback bypass.
3. PR5 protected authenticated HTTP E2E: user JWT, signature validated at gateway (`verify_jwt=true`), server DB connectivity, expected 200/404/400/503 shape and authorization checks. Never deliver service-role keys or DB connection strings to Sheets or browser.
4. Freshness, exchange session, valuation eligibility, provider provenance, USD native currency, separate FX timestamp and USDTHB orientation all verified from the same reconciliation snapshot.
5. PR #49, #50, #51, #52 review and deployment-drift/rollback completed; *do not infer merge approval from applied additive Supabase migrations*.

## Proposed shadow-only data contract

Private/import-only Google Sheets tab `_Market_Data` with: `asset_symbol`, `instrument_id`, `price_usd`, `currency`, `source_native_usd`, `status`, `quote_kind`, `provider`, `observation_id`, `observed_at`, `session_date`, `valid_until`, `fetched_at`, `shadow_only`, and `valuation_eligible`. Keep validated `USDTHB` in a separately identified FX reference row/section with `fx_rate_thb_per_usd`, provider, source ID and times. Distinguish missing/stale from zero and refuse `valuation_eligible=false` as a production valuation input.

Initial PR6 is **read-only comparison**: no scheduled import, no live consumer formula change, no P&L/accounting writes. A protected, explicitly authorized server-mediated export is required: spreadsheet must not carry privileged Supabase secrets. Check quotas for both the reader and Google Sheets API before enabling periodic imports.

## Reconciliation and sign-off

- Snapshot price USD and separately validated USDTHB at a specified as-of time. Do not mix quote/FX ages silently.
- Reconcile Best, Loan Money, Mom and ALL: counts, instrument mapping, USD price, FX, implied THB display, stale/missing and total market-value *shadow comparison* against existing formulas. Document expected differences before any cutover.
- Keep **Transactions / Holdings / Cost Basis / Cash / Price Data source formulas / Cron** unchanged throughout PR6. Any proposed switch of Price Data read formulas belongs to a separate gated PR7 and manual owner sign-off.
- Preserve current Sheets display/workflow and a clean rollback (disable shadow import and discard disposable `_Market_Data` only after explicit authorization; retain all historical THB/trading data).

## Exit / no-go

**No-go on 2026-10-15:** CoinGecko new provider entry is `DISABLED / SHADOW_ONLY / UNVERIFIED`; six crypto and CRWD native USD price missing; authenticated HTTP E2E not completed. PR6 planning may proceed, but do not start syncing Sheets or cut over.


## MVP-first execution receipt — 2026-10-16

Owner approved a Phase-1 feature-first simplification: preserve safety/data integrity, but defer advanced distributed scheduling/quota hardening until usage requires it.

### PR5 prerequisite now satisfied for shadow use

- CoinGecko legacy portfolio request was changed from THB-only to **USD+THB in the same existing batch request**, so native USD crypto was added without a second CoinGecko HTTP call or Cron increase.
- `portfolio-mtm-refresh-v1` v2 deployed; one authorized verification run published all six native USD crypto observations while keeping existing THB snapshots.
- CRWD root cause was missing daily-close universe membership. The existing quota-guarded daily-close universe now includes active canonical stocks after holdings/research/company priorities; CRWD backfill passed through Twelve Data quota and produced a verified USD regular close.
- PR5 shadow coverage after verification: **70/70** — 64 Stock `LAST_CLOSE`, 6 Crypto `FRESH`, 0 `MISSING`.

### Tracker shadow created

Spreadsheet: `Investment Portfolio Tracker - Chumponphat`.

Hidden tab `_Market_Data` now contains:
- 70 canonical assets with `price_usd`, provider, observation ID, source/session/freshness metadata;
- separate `USDTHB` FX reference and provenance;
- `price_thb_shadow` calculated **inside Google Sheets** as `price_usd × USDTHB`;
- `shadow_only=true` and `valuation_eligible=false` retained from PR5.

No formulas or values were changed in `Price Data`, `Transactions`, `Holdings`, cost basis, cash, or P&L.

### Read-only reconciliation before cutover

Current open holdings map to 10 unique assets and all 10 exist in the shadow table.

- Mean absolute current-vs-shadow price difference: **~0.87%**.
- Crypto differences were small at the comparison time.
- Stock differences are expected to be larger because PR5 stock shadow is currently `LAST_CLOSE` while existing `Price Data` can use live GoogleFinance/provider prices.
- Largest observed difference: **TTWO ~3.91%**.

**Decision:** Shadow feature is usable; production `Price Data` cutover remains deferred. Next MVP work should improve/define stock live-vs-last-close behavior and then perform an explicit read cutover only when the owner accepts the pricing semantics.
