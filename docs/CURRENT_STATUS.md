# Current Live Status — Asset Price Data Service v1.0.0

**Checked in live Supabase, 2026-10-30 Asia/Bangkok.** Contract: `ASSET-PRICE-CONTRACT-1.0.0`. Production's price-only database schema is fully reduced. Sixteen inert legacy Edge deployments remain physically registered.

## Supported functionality

CoinGecko native USD quotes for active BTC, DOGE, ETH, HBAR, SOL and XRP holdings + Frankfurter USD/THB FX → Supabase `fwios.market_observations` → `price-sheet-sync-v1` → Investment Portfolio Tracker Google Sheet tab `_Market_Data` → existing `Price Data` and `Holdings` formulas. Holdings symbols are read from Sheet; transactions, holdings, cost basis, accounting and overrides remain exclusively in Google Sheet.

Stock discovery, scanner, historical stock EOD ingestion, research, thesis, valuation, scoring, portfolio MTM, account ledger and automated trading are out of scope. `auto_trade=false`. No future roadmap.

## Final database state

- The user **explicitly authorized permanent deletion without backup** of the retired archive. They performed the SQL Editor operation manually. Live read-only verification confirmed `to_regnamespace('fwios_legacy_archive_20261029') IS NULL` and **zero archived tables**. The 87 retired tables and their 58 historical portfolio transactions / 29 source IDs, 1,590 historical Stock daily-close rows and 19,608 lineage links cannot be restored from that removed schema. **No backup was created for this deletion.**
- After archive removal, seven former archival trigger functions were dropped in live Supabase using `DROP FUNCTION ... RESTRICT` with preflight protections (migration: `retire_last_7_legacy_trigger_functions_v1`). `fwios` now contains **five tables**, **one identity view** and exactly **six remaining SQL functions**.
- Six remaining functions: `ensure_market_observation_v1`, `market_observation_append_only_guard_v1`, `market_observation_type_v1`, `pr5_native_usd_price_shadow_v1`, `pr7_native_usd_price_read_v1`, `resolve_instrument_id_v1`. The append-only trigger remains attached to `fwios.market_observations`.
- `fwios.market_observations` and instrument identity tables were **not deleted**. They remain the approved canonical price data. The prior count was 20,427 before the latest post-cleanup refresh; the count grows on successful observations.
- The retired database object removal is permanent. Git preserves **source and migration history**, not the deleted production database rows.

## Cron and Edge Functions

| Cron | Mode | Active destination |
| --- | --- | --- |
| #14 | Crypto native USD | `price-market-refresh-v1` v2 |
| #15 | USD/THB FX | `price-market-refresh-v1` v2 |
| #16 | Sheet sync | `price-sheet-sync-v1` v2 |

Only these three registered Cron jobs remain. Their inherited names mention portfolio/stock but **their commands invoke price-only workers**. The naturally scheduled post-cutover Crypto / FX / Sheet cycle was independently verified on 2026-10-30 Bangkok (HTTP 200 across all three; six Crypto observations, one FX and Sheet readback PASS).

**Sixteen obsolete Edge slugs are still deployed** as HTTP 410 tombstones. These do not run the former logic, but physical deletion requires an authorized dashboard or CLI operator because the connected Supabase plugin exposes deploy/list/get, not delete. See `decommission/RETIRED_EDGE_FUNCTION_REMOVAL.md`. Do **not** delete the two supported price-only workers.

## Post-removal verification

After the user deleted the schema and the seven obsolete functions were removed, `price-market-refresh-v1` ran again with Crypto HTTP **200**, 6/6 USD observations written and zero portfolio writes (response 11978); FX HTTP **200**, one observation written and zero portfolio writes (response 11979). `price-sheet-sync-v1` wrote the six Crypto rows/FX and verified Google Sheet readback HTTP **200**, zero database writes (response 11980). Four existing Stock rows in `_Market_Data` are **frozen historical Sheet values, not live quotes**; they were not overwritten.

Live read-only SQL regression **27/27 PASS**, updated to require deleted archive and legacy routines absent, five price tables and six price functions intact. Latest Supabase Security Advisor: no warning findings; five informational `rls_enabled_no_policy` entries for service-access-only tables.

## Source and applied-migration accuracy

GitHub PR #100 merged the clean two-worker source to `main`, removed 187 out-of-scope files from the current source tree and preserved the old Git history. This follow-up updates the post-deletion documentation, regression test and final seven-function cleanup migration. **Do not replay previously applied migrations as an initial database bootstrap.**

**Remaining cleanup:** Physical de-registration of 16 inactive HTTP 410 Edge deployments, not further SQL schema deletion. Data loss from the user-authorized no-backup archive deletion must not be described as recoverable.
