# FWIOS v3 — Phase 1 MVP-First Roadmap

**Decision date:** 2026-10-16  
**Goal:** Make the investment workflows usable end-to-end before expanding infrastructure for scale.

## Product-first rule

Phase 1 optimizes for a single-owner / very-low-user-count system. Existing PR2–PR4 quota, reservation, cache and single-flight foundations are retained but **feature expansion and enterprise-scale acceptance work are frozen unless needed to ship a working feature**.

Do not remove safety-critical controls: secrets stay server-side, provider calls remain bounded, historical currency/provenance is truthful, transactions/cost basis are never silently rewritten, and automated trading remains off.

## Phase 1 sequence

1. **PR5 Native USD market data — working MVP**
   - Stocks + crypto expose native USD canonical observations.
   - Reuse existing provider calls where possible; avoid duplicate network requests.
   - Explicit FRESH / LAST_CLOSE / MISSING semantics.
   - Current receipt: 70/70 supported assets covered.

2. **PR6 Portfolio Tracker shadow — working MVP**
   - Hidden `_Market_Data` receives canonical USD snapshot plus separate USDTHB.
   - Google Sheets calculates THB shadow values.
   - Compare against current Price Data/Holdings without changing accounting.
   - Current receipt: implemented; open holdings shadow reconciliation complete.

3. **PR7 Price Data read cutover — only after semantic acceptance**
   - Decide whether stock valuation uses last close, live quote, or explicit fallback.
   - Replace only market-price read formulas; never rewrite Transactions/Cost Basis.
   - Keep immediate rollback to old read path.

4. **Focused Dashboard MVP**
   - Scanner/research uses the shared market-data source for the subset of features actually used.
   - Do not block on full S&P 500 enrichment or advanced scheduling.

## Deferred technical backlog

Until real user/load evidence requires it:
- 20-session distributed concurrency proof;
- richer P0–P4 scheduler behavior;
- advanced quota analytics and alerting;
- multi-user authorization/scaling;
- full-universe enrichment and high-frequency refresh.

These are not deleted; they are intentionally postponed.

## Phase 1 success

A normal workflow should be possible without SQL/GitHub intervention:
- Tracker shows trustworthy prices and portfolio values;
- Dashboard supports useful discovery/research;
- prices expose freshness/source;
- failures degrade visibly instead of corrupting accounting;
- no automated trade execution.


## PR7 Task 1 receipt — Held-stock live quote MVP (2026-10-16)

**Status: COMPLETE**

- Scope is dynamically derived from open stock positions only. Current set: `MSFT, NVDA, TLN, TTWO` (4 stocks); closed CRWD and the rest of the 64-stock canonical universe are not polled by this portfolio live-quote loop.
- Existing `portfolio-mtm-refresh-v1` Twelve Data `/quote` path and existing atomic daily/minute quota reservation are reused; no new stock provider or new Cron was added.
- Correctness fix: canonical stock quote observation time now uses Twelve Data `last_quote_at` (fallback `timestamp`) instead of request `now()`, preventing an old vendor quote from masquerading as newly observed.
- CI run `38836600779` passed adapter tests and Deno worker type-check.
- Edge function deployed ACTIVE as `portfolio-mtm-refresh-v1` v3.
- One authorized force verification run returned HTTP 200 and exactly four stock results: MSFT, NVDA, TLN, TTWO; all PASS, no errors, pricing gate PASS, auto_trade=false.
- Verification happened while US market was closed. Twelve Data correctly returned `market_status=CLOSED`; PR5 shadow resolver therefore continued to expose `LAST_CLOSE` rather than falsely label the closed quote `FRESH`. During market hours, only an `OPEN` quote no older than 15 minutes is eligible as `STOCK_LIVE_QUOTE / FRESH`.

No Price Data cutover, transaction/accounting mutation, or additional 64-stock live polling was enabled.


## PR7 Task 1 policy revision — Daily post-close stocks (2026-10-17)

Owner rejected intraday stock polling as too frequent for Phase 1.

Final Phase-1 stock policy:
- **No intraday stock /quote polling.**
- Existing 15-minute portfolio Cron remains for Crypto only; stock mode defaults to `OFF`.
- Open-Holdings stock prices sync **once per completed US weekday session**, via `fwios-portfolio-stock-post-close-sync` at `00:00 UTC Tue-Sat` (07:00 Asia/Bangkok Tue-Sat), after canonical EOD ingestion begins at 22:05 UTC Mon-Fri.
- Daily stock sync reads already-ingested canonical `REGULAR_CLOSE` observations and writes only the current Open Holdings into the portfolio quote snapshot.
- Current Open Holdings stocks: `MSFT, NVDA, TLN, TTWO`.
- The daily sync performs no per-stock quote API calls. Verification quota log showed only one `USD/THB` FX call.
- Smoke verification:
  - stock mode OFF -> HTTP 200, `stock_refresh_attempted=false`, `stocks=[]`;
  - DAILY_CLOSE_ONLY -> HTTP 200, 4/4 held stocks PASS as `LAST_CLOSE`, Crypto skipped;
  - pricing gate PASS, auto_trade=false.
- Daily-close scanner ingestion for the broader canonical stock universe remains separate and unchanged.

This replaces the prior Task-1 intraday-live behavior for Phase 1.


## PR7 portfolio refresh policy — daily-only stocks + crypto (2026-10-17)

Owner requested Crypto cadence to match the Phase-1 low-frequency portfolio policy.

Final schedule:
- Crypto holdings: once daily at 00:00 UTC (07:00 Asia/Bangkok), every day.
- Stock holdings: once daily at 00:00 UTC Tue-Sat (07:00 Asia/Bangkok Tue-Sat), after the corresponding US Mon-Fri EOD stock pipeline.
- The former 15-minute portfolio Cron is removed.
- Crypto refresh is explicit opt-in (`refresh_crypto=true`); worker default is OFF.
- Crypto daily snapshot validity is 30 hours so it remains usable until the next daily refresh instead of going stale after 15-45 minutes.
- PR5 shadow labels crypto as `CRYPTO_DAILY_SNAPSHOT`.
- Smoke verification: 6/6 crypto updated and 6/6 native USD published; no missing/errors; pricing gate PASS.
- Deployed `portfolio-mtm-refresh-v1` ACTIVE v7.


## PR7 native Tracker shadow sync — 2026-10-17

Owner requested the temporary ChatGPT Sheet automation be replaced by a native FWIOS sync, but only after native E2E passes.

Current native status:
- Edge Function `portfolio-sheet-shadow-sync-v1` deployed ACTIVE v1.
- Worker is fail-closed and targets only `Investment Portfolio Tracker - Chumponphat / _Market_Data`.
- Native dry-run PASS: 70 shadow rows, 10/10 open holdings covered, pricing gate PASS, USDTHB present, no accounting/Price Data mutation.
- Live-write probe without Google credential correctly returned HTTP 503 with `GOOGLE_SERVICE_ACCOUNT_CREDENTIAL_MISSING` and `write_attempted=false`.
- Native Cron `fwios-portfolio-sheet-shadow-sync-native` runs at 00:10 UTC (07:10 Asia/Bangkok) and is **active=true** after Google service-account write/read-back E2E PASS.
- Portfolio refresh schedules are 07:00 Asia/Bangkok: Crypto daily; Stock Tuesday-Saturday, consuming US Monday-Friday closes.
- Required Vault secret: `fwios_google_sheets_service_account_json`.
- Temporary ChatGPT sync has been disabled after native write + read-back + Cron activation PASS.
- `Price Data` cutover remains explicitly forbidden pending final reconciliation.


### Native shadow sync cutover receipt — 2026-10-17
- Vault Google service-account credential installed.
- Native Edge write HTTP 200, write_attempted=true.
- Google read-back verified 70 shadow data rows plus header and 10/10 open holdings.
- USDTHB block present with PASS provenance.
- Native 07:10 Asia/Bangkok Cron active.
- ChatGPT FWIOS Sheet Shadow Sync automation disabled.
- Price Data cutover remains false.


## P0 resolved before PR7 Price Data cutover — stock EOD timing (2026-10-17)

The EOD ordering bug is fixed live and captured by
`migrations/20261017104500_pr7_stock_eod_pre_0700_timing_v1.sql`.

Final stock timing:
- EOD enqueue: `5 22 * * 1-5` UTC = 05:05 Asia/Bangkok Tue-Sat.
- Enqueue session date: same New York calendar date at 22:05 UTC.
- EOD worker: `*/2 22-23 * * 1-5` UTC.
- Held-stock sync: `0 0 * * 2-6` UTC = 07:00 Asia/Bangkok Tue-Sat.
- Native `_Market_Data` sync: `10 0 * * *` UTC = 07:10 Asia/Bangkok daily.

Targeted 2026-10-16 verification:
- EOD held-stock run PASS 4/4 for MSFT/NVDA/TLN/TTWO.
- All four latest canonical `REGULAR_CLOSE` rows = 2026-10-16.
- Portfolio DAILY_CLOSE_ONLY validation PASS with 10/10 open assets fresh.
- Native Sheet sync PASS with 70 rows and 10/10 open holdings.
- Held-stock observation IDs in `_Market_Data` match the 2026-10-16 canonical observations.

Final read-only reconciliation:
- mean absolute USD price delta across 10 unique open assets ~0.0889%;
- max USD delta XRP ~0.4538% due daily crypto snapshot timing;
- current Holdings market value ~THB 334,126.47;
- shadow value ~THB 333,825.15;
- total delta ~THB -301.32 (-0.0902%).

No Price Data, Transactions, Holdings, Cost Basis, cash or P&L formula/value was changed.
A controlled Price Data read cutover is now proposal-ready, but remains blocked on explicit owner approval.
