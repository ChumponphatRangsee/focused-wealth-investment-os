# Current Live Status — Asset Price Data Service v1.0.0

**Verified 2026-10-29 (Asia/Bangkok)**. This document reflects the production read-only inspection, live migrations and end-to-end tests performed after the FWIOS scope reset. Contract: `ASSET-PRICE-CONTRACT-1.0.0`. **This is NOT a Full Cleanup certification**: historical objects remain intentionally quarantined in a private schema, legacy source code still awaits PR review, and a naturally scheduled post-cutover cycle has not yet been independently verified.

## Only supported functionality

CoinGecko native USD Crypto quotes (BTC, DOGE, ETH, HBAR, SOL, XRP) plus Frankfurter USD/THB FX → `fwios.market_observations` → `price-sheet-sync-v1` → Investment Portfolio Tracker `_Market_Data` → existing `Price Data` / `Holdings` formulas.

Google Sheet owns all Transactions, Holdings, cost basis and portfolio accounting. No stock ingestion, S&P scanner, research, technical, thesis, valuation, scoring, decision, portfolio backend or automatic trading. `auto_trade=false`. **No future roadmap.**

## Live production structure after cleanup

- Active `fwios` schema has **5 base tables**: `asset_entities`, `instruments`, `instrument_symbols`, `instrument_identifiers`, `market_observations`; **1 view**: `v_instrument_identity_current`; and **13 SQL functions** (the price read/write/identity functions and retained trigger/archival support functions).
- **87 historical tables** were moved, without deleting a single row, to the **private** `fwios_legacy_archive_20261029` schema. `anon` and `authenticated` have no schema USAGE. This is quarantine **within the same database**, not an independent/exported backup. Legacy data is not physically deleted.
- Historical `portfolio_transactions` **58 records / 29 unique source IDs**, plus related `portfolio_accounts`, `portfolio_assets`, and `portfolio_import_batches`, are retained in that private archive. Prior read-only comparison matched 522 key fields between database and Google Sheet across 58 rows with no discrepancy; Sheet contains two additional source IDs, `SRC-0030`/`SRC-0031`. Keep archived ledger until raw-payload preservation and an independently recoverable backup are verified.
- Historical `market_daily_closes` **1,590 records / 64 symbols** and `market_observation_legacy_links` **19,608 records** remain in the archive. Existing four stock rows (`MSFT`, `NVDA`, `TLN`, `TTWO`) in `_Market_Data` are **frozen historical prices, not updated stock quotes**.
- `fwios.market_observations` contained **20,413 records** after the live manual refresh E2E (six new Crypto + one new FX). Historical market observations, instrument identity and provenance were preserved.

## Price Service and Cron

| ID | Mode / endpoint | Status |
| --- | --- | --- |
| #14 | CRYPTO → `price-market-refresh-v1` | Active |
| #15 | FX → `price-market-refresh-v1` | Active |
| #16 | `price-sheet-sync-v1` v2 | Active |

Old inactive Crons #2, #5, #6, #7, #8, #9, #10 were **unscheduled**. The names of #14/#15/#16 are still inherited from the former project; validate their *commands*, not their legacy names. All 16 non-price Edge endpoints now return retired HTTP 410 responses (and preserve their existing JWT verification settings). Two supported Edge workers remain active.

## Live verification receipts

- Manual post-cleanup Crypto collection: **HTTP 200 / CoinGecko / 6 assets / 6 price observation writes / 0 Portfolio writes**.
- Manual post-cleanup FX collection: **HTTP 200 / Frankfurter / 1 FX observation write / 0 Portfolio writes**.
- `price-sheet-sync-v1` v2: **HTTP 200 / six Crypto rows updated / Google Sheet readback PASS / 0 database writes**. Tested again after ledger quarantine and Cron unscheduling, also HTTP 200 and readback PASS.
- Google Sheet still has six live Crypto price rows and four preserved historic Stock rows; ten `Price Data` asset prices were positive, and the checked `Price Data` and `Holdings` ranges had **zero formula errors**. Verified FX provider: `FRANKFURTER_FX`.
- Updated read-only SQL regression: **27/27 PASS**.
- **The naturally scheduled post-cutover #14/#15/#16 round on 2026-10-30 Asia/Bangkok has been independently verified**; no claim of scheduled continuity or a complete long-running provider quota audit.

## Applied cleanup migrations and review

Existing live migration history includes:

- `20261029102608_remove_legacy_views_and_empty_tables_v1`: removed 38 obsolete views and 9 **exact-count-verified empty** tables using `RESTRICT`.
- `20261029102911_retire_legacy_sql_functions_v1`: removed 114 obsolete functions using `RESTRICT`.
- `20261029103229_archive_noncore_legacy_tables_v1`: moved 83 non-core tables into a private archive, preserving rows, indexes, foreign keys and triggers.
- `20261029103602_archive_historical_portfolio_ledger_v1`: moved 4 ledger/support tables without losing the 58 historical transactions.
- `20261029103659_unschedule_retired_legacy_crons_v1`: removed 7 inactive legacy Cron registrations.

The previous price collector and sheet worker cutover migrations had already been executed; **do not replay migrations purely because corresponding files appear on an unmerged PR**. New migration files and updated tests are recorded on [PR #100](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/100), which remains Draft. `main` was reset by merged PR #101. Merge only after reviewing source and migration history versus live state; do not restore old docs.

## Explicit remaining limits

The 87 historical tables remain physically in the same Supabase database, not externally backed up. Several preserved legacy trigger routines remain in `fwios`. The private `system_state_legacy_archive_v1` table still has RLS disabled; direct `anon`/`authenticated` permissions did not permit archive schema USAGE at audit, but a security/policy decision is outstanding. The first naturally scheduled run was verified; longer-term API quota behaviour still needs verification.

Do not assert **Full Cleanup** until all required legacy-object retention and recoverability decisions are complete and scheduled Crypto + FX → Supabase → Google Sheet continues working.

## Verified naturally scheduled cycle — 2026-10-30 Asia/Bangkok

Cron #14 and #15 ran at **04:10** local (2026-10-29 21:10 UTC), each enqueued one request. Actual `net._http_response` IDs **11970** (Crypto) and **11971** (FX) reported HTTP 200, native USD Crypto 6/6 and FX 1/1, **zero portfolio writes**. Cron #16 ran at **04:20** local, response ID **11972** HTTP 200, six Crypto rows synced and readback verified, zero database writes. Matching `fwios.market_observations` rows and the live Google Sheet prices/FX were independently checked. The second UTC-hour schedule passes returned zero rows intentionally due to the New York 17:10/17:20 clock guard.

Current Supabase organization tier is **Free**; it must not be presumed to have managed daily backups. Archive size ~31 MB, **87 tables**. No complete external logical SQL dump or test restore was produced during this cleanup, so permanent `DROP SCHEMA ... CASCADE` or historical data deletion is blocked. The original 187 obsolete repo files were retired from the active Git tree and remain recoverable in Git history. The old 16 deployed Edge slugs remain HTTP 410 tombstones because the available Supabase connector does not support physical function deletion.

Security: `normalize_architecture_system_state_write_v1` has its legacy trigger `search_path` pinned to `pg_catalog, pg_temp` by `pin_archive_trigger_search_path_v1`. See live Security Advisor for any remaining advisories.
