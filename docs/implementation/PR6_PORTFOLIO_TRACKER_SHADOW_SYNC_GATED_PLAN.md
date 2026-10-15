# PR6 preparation — Portfolio Tracker native-USD shadow sync (GATED, NOT ENABLED)

**Date:** 2026-10-15 (Asia/Bangkok)  
**Status:** DESIGN ONLY; no PR6 branch, deployment, Sheets mutation, sync job, or consumer cutover.  
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
