# PR7 Native Portfolio Tracker Shadow Sync — Runbook

**Date:** 2026-10-17  
**Status:** DEPLOYED / NATIVE WRITE+READBACK PASS / CRON ACTIVE  
**Target:** `Investment Portfolio Tracker - Chumponphat` → hidden `_Market_Data` only.

## Purpose

Replace the temporary ChatGPT-driven Sheet shadow sync with an FWIOS-native path:

`07:00 Asia/Bangkok portfolio refresh → 07:10 native Edge Function → _Market_Data`

This does **not** authorize a `Price Data` cutover and does not write Transactions, Holdings, Cost Basis, realized P&L, quantities, cash, or trade execution.

## Runtime

Edge Function:
- `portfolio-sheet-shadow-sync-v1`
- deployed ACTIVE v1
- server-authenticated with the existing FWIOS automation token
- spreadsheet ID is fixed to the Portfolio Tracker
- target sheet is fixed to `_Market_Data`

Native worker gates before any Google write:
1. portfolio pricing gate must be PASS;
2. canonical native-USD shadow rows must resolve;
3. every open holding must be covered;
4. valid USDTHB observation must exist;
5. Google service-account credential must exist;
6. Google write must succeed and be read back;
7. only after verification are stale shadow rows cleared.

## Google credential

Required Supabase Vault secret name:

`fwios_google_sheets_service_account_json`

Value must be a Google service-account JSON object containing at least:
- `client_email`
- `private_key`
- optional `token_uri`

The service-account email must have Editor access to:
`1MUZD_nevvmH3yx972Ep6o8pCRmsdd_IgzSzjD6TPCjw`

The worker requests only:
`https://www.googleapis.com/auth/spreadsheets`

Never commit the credential to GitHub or place it in a readable Google Sheet.

## Scheduler

Cron:
- job: `fwios-portfolio-sheet-shadow-sync-native`
- schedule: `10 0 * * *`
- local time: 07:10 Asia/Bangkok daily
- **active=true after native E2E write/read-back PASS**

Activation gate completed on 2026-10-17 after credential installation and native write/read-back verification.

## Verification receipt — 2026-10-17

CI:
- GitHub Actions run #39023037273 PASS
- CoinGecko adapter tests PASS
- portfolio worker type-check PASS
- native sheet shadow worker type-check PASS

Native dry-run:
- HTTP 200
- row_count=70
- open_asset_count=10
- all 10 open holdings covered
- pricing_gate=PASS
- USDTHB available
- price_data_cutover=false
- auto_trade=false
- write_attempted=false

Fail-closed live-write probe without Google credential:
- HTTP 503
- error=`GOOGLE_SERVICE_ACCOUNT_CREDENTIAL_MISSING`
- write_attempted=false
- Google Sheet not touched by the native worker

Native E2E after credential installation:
- HTTP 200
- write_attempted=true
- verified_row_count=70
- open holdings 10/10 covered
- Google read-back confirmed 70 data rows + header
- USDTHB block present and provenance PASS
- Price Data cutover=false
- auto_trade=false
- native Cron enabled at 07:10 Asia/Bangkok
- temporary ChatGPT automation disabled

## Cutover rule

Cutover completed: Vault credential exists, Sheet sharing works, manual native write/read-back passed, the 07:10 native Cron is enabled, and the temporary ChatGPT automation is disabled.

`Price Data` remains unchanged until separate reconciliation approval.


## P0 upstream timing issue discovered before handover

Native Sheet delivery is healthy, but the stock source feeding it is not yet guaranteed to be the newest US close by 07:00 Asia/Bangkok.

Live schedules:
- `fwios-market-daily-close-enqueue`: `25 5 * * 1-5` UTC
- `fwios-market-daily-close-worker`: `*/2 5-8 * * 1-5` UTC
- `fwios-portfolio-stock-post-close-sync`: `0 0 * * 1-5` UTC

Therefore the portfolio stock sync occurs before the broad EOD ingestion window.

Live check on 2026-10-17 showed latest `REGULAR_CLOSE` session still `2026-10-15` for MSFT, NVDA, TLN and TTWO, despite the 2026-10-16 US session already being closed.

This does not invalidate the native Google Sheet write/read-back E2E. It does block any claim that 07:00 stock data is latest-session complete and therefore blocks `Price Data` cutover.

Resolve EOD schedule/session alignment first, including US/Bangkok day boundary and DST.
