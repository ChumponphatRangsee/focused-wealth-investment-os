# Price Pipeline & Operations — Asset Price Data Service v1.0.0

**Only supported feature:** CoinGecko Crypto native USD prices + Frankfurter USD/THB FX → Supabase → Investment Portfolio Tracker Google Sheet. No Stock Discovery, Technical Screening, Fundamental Research, Thesis, Valuation, Scoring, Portfolio Backend, Trading or future roadmap.

## Authoritative flow

```text
Google Sheet Holdings (OPEN crypto symbols, read-only)
   ├── CoinGecko native USD quotes ─┐
   └── Frankfurter USD/THB FX ──────┤
                                    ▼
                         fwios.market_observations
                                    ▼
                      price-sheet-sync-v1 (v2)
                                    ▼
              Google Sheet _Market_Data (Crypto + FX)
                                    ▼
                      Price Data → Holdings formulas
```

The existing stock rows in `_Market_Data` are protected historical values, **not new or ongoing stock price collection**. Google Sheet owns Transactions, Holdings, cost basis, manual overrides and portfolio formulas.

## Active production schedules

| Cron ID | Runtime | Purpose |
| --- | --- | --- |
| #14 | `price-market-refresh-v1` / mode CRYPTO | Read supported OPEN crypto holdings, fetch current CoinGecko USD quotes, validate and store canonical observations |
| #15 | `price-market-refresh-v1` / mode FX | Fetch USD/THB from Frankfurter, validate FX date/rate, store observation |
| #16 | `price-sheet-sync-v1` v2 | Update only existing/needed Crypto price rows and FX cells in `_Market_Data`; verify by readback |

The inherited Cron job names may mention portfolio, stock or shadow; the **commands**, not the names, point to the price-only functions. All retired Cron registrations (#2, #5–#10) have been unscheduled. Sixteen retired Edge endpoints return HTTP 410; they are **not supported services**.

## Validation, auth and storage contract

- Supported Crypto: BTC, DOGE, ETH, HBAR, SOL, XRP, selected from current OPEN Crypto holdings read-only. Source: native CoinGecko USD with positive quote and provider timestamp no older than 2h at collection.
- FX: positive Frankfurter USD/THB and source date within five days. The conversion to THB is performed in Google Sheet formulas; no conversion of crypto quote source into synthetic USD values.
- Canonical destination: `fwios.market_observations`, via `fwios.ensure_market_observation_v1`. Required source identity, quote value/currency, observed time, session date, provenance and valid status. Price lookup uses `fwios.pr7_native_usd_price_read_v1` → `pr5_native_usd_price_shadow_v1` with `v_instrument_identity_current`.
- Server-to-server authentication: Vault-backed automation token; never disclose a credential, expose it in a URL, or commit it to GitHub. Price-only endpoints validate the supplied header token and fail closed on missing/invalid auth.
- `price-sheet-sync-v1` v2 **does not require live stock prices**: it matches Crypto symbols to current `_Market_Data` rows, updates Crypto and FX only, verifies values/readback, and rejects any attempted overwrite of a protected Stock row. No full-range clear. Preserves Manual Override J, Transactions, Holdings quantities, Cost Basis and downstream formulas.
- No database Portfolio mutation. `auto_trade=false`.

## Database isolation after cleanup

Production `fwios` contains **five** tables: `asset_entities`, `instruments`, `instrument_symbols`, `instrument_identifiers`, and `market_observations`. One identity view and 13 SQL routines remain (including trigger support for archived relations).

The historical private archive `fwios_legacy_archive_20261029` contains **87** preserved tables, including 58 ledger records, 1,590 historical Stock EOD records and old Research/Thesis/Decision tables. Its schema grants no USAGE to `anon` or `authenticated`. This archival retention is **not** an independent database backup, and cannot be described as permanent legacy-data deletion.

## Verified after live database cleanup — 2026-10-29

CoinGecko CRYPTO direct live execution **6/6 HTTP 200**, Frankfurter FX **1/1 HTTP 200**, each with zero reported portfolio writes. Then `price-sheet-sync-v1` v2 **HTTP 200**, six Crypto prices and the FX cells written/read back successfully, four historical stock rows preserved, no database ledger writes. A final Sheet sync after the ledger/Cron isolation also returned **HTTP 200 and readback verified**. Checked ten `Price Data` asset prices and `Holdings` formula cells had no errors. SQL regression **27/27 PASS**.

Manual tests plus the naturally scheduled 2026-10-30 Asia/Bangkok run are independently verified. Future operator checks should compare Cron job runs with actual Edge HTTP responses, source timestamps, stored observations, Sheet readback and read-only formula consumers. A Cron `succeeded` status alone may only confirm the HTTP request was queued.

Do not delete archival transaction/market history until independent recoverability is proven. Review GitHub [PR #100](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/100) against current live migration history before merging or applying code.

## Natural schedule receipt — 2026-10-30

#14/#15 04:10 Bangkok and #16 04:20 Bangkok: `cron.job_run_details` confirmed dispatch, `net._http_response` #11970/#11971/#11972 returned HTTP 200, with 6 CoinGecko observations and one Frankfurter FX observation committed, and Google Sheet Crypto+FX readback successful. Only source prices were refreshed; four Stock historical rows remained frozen. Supabase Free plan: **do not drop the 87-table historical archive without a separately verified external logical backup and restore**. Source tree has only the two dedicated price workers; prior code is preserved in Git history.

## Price collector v2 (2026-10-30)

Deployed after static Deno CI found two provenance JSON argument type errors in the worker source. The corrected worker explicitly serializes each provider provenance payload before SQL `::jsonb` cast. Live dry runs for Crypto+FX returned HTTP 200 without writes; live Crypto+FX collectors and subsequent Sheet Sync returned HTTP 200 with Google Sheet readback verified. No portfolio writes. The 27/27 database regression remains passing.

The 87 historical tables still live in the same Free-tier Supabase database. Before permanent deletion, follow `decommission/SECURE_LEGACY_BACKUP_PROCEDURE.md` to create a complete independently stored logical dump, restore it to an isolated environment and verify original ledger/market history counts. This is an operational retention requirement, not a roadmap.
