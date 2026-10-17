# PR7 HANDOVER TO NEXT CHAT — 2026-10-17

## Current status

Repository: `ChumponphatRangsee/focused-wealth-investment-os`  
Branch: `feat/pr5-native-usd-price-shadow`  
PR: #52 — **DRAFT / UNMERGED**  
Do not merge unless the owner explicitly asks.

Phase-1 principle remains MVP-first. Supabase is market-data/state infrastructure; Google Sheet `Investment Portfolio Tracker - Chumponphat` remains the portfolio accounting/transaction surface. No automated trading.

## Completed in this chat

### 1. Portfolio refresh cadence simplified

The previous 15-minute portfolio refresh was removed.

Current live portfolio schedules:
- Crypto snapshot: `fwios-portfolio-crypto-daily-snapshot`
  - cron `0 0 * * *`
  - 07:00 Asia/Bangkok every day
- Stock held-position sync: `fwios-portfolio-stock-post-close-sync`
  - cron `0 0 * * 1-5`
  - 07:00 Asia/Bangkok Monday-Friday
- Worker: `portfolio-mtm-refresh-v1` ACTIVE v7
- Crypto is `CRYPTO_DAILY_SNAPSHOT`, 30-hour validity.
- Stocks use canonical `REGULAR_CLOSE` and are exposed as `LAST_CLOSE`.
- No intraday held-stock quote polling remains.
- `auto_trade=false`.

### 2. Tracker shadow tab working

Google Sheet:
`Investment Portfolio Tracker - Chumponphat`  
Spreadsheet ID:
`1MUZD_nevvmH3yx972Ep6o8pCRmsdd_IgzSzjD6TPCjw`

Hidden tab:
`_Market_Data`

It contains:
- 70 canonical asset rows
- native USD price
- freshness/status/quote kind
- provider/provenance/observation IDs/timestamps
- separate USDTHB block
- `price_thb_shadow = price_usd × USDTHB`

No edits were made to:
- `Price Data`
- `Holdings`
- `Transactions`
- Cost Basis
- realized P&L
- accounting formulas

### 3. Native FWIOS Sheet sync completed

Temporary ChatGPT-driven sheet sync has been replaced with native FWIOS automation.

Edge Function:
`portfolio-sheet-shadow-sync-v1`

Deployment:
- ACTIVE v1
- server-authenticated with existing FWIOS automation token
- Google Sheets service-account credential is stored in Supabase Vault under:
  `fwios_google_sheets_service_account_json`
- Never expose or commit the secret value.

Native E2E receipt:
- HTTP 200
- `write_attempted=true`
- 70 shadow rows written
- Google read-back verified 70 rows + header
- 10/10 open holdings present
- pricing gate PASS
- USDTHB provenance PASS
- `price_data_cutover=false`
- `auto_trade=false`

Native sheet Cron:
`fwios-portfolio-sheet-shadow-sync-native`
- cron `10 0 * * *`
- 07:10 Asia/Bangkok daily
- **active=true**

The ChatGPT automation `FWIOS Sheet Shadow Sync` is now disabled.

CI:
GitHub Actions run #39023037273 PASS:
- CoinGecko native USD adapter tests
- portfolio worker type-check
- native sheet sync worker type-check

Relevant files:
- `supabase/functions/portfolio-sheet-shadow-sync-v1/index.ts`
- `supabase/functions/portfolio-sheet-shadow-sync-v1/deno.json`
- `migrations/20261017095500_pr7_native_sheet_shadow_sync_cron_v1.sql`
- `docs/implementation/PR7_NATIVE_SHEET_SHADOW_SYNC_RUNBOOK_20261017.md`
- `docs/implementation/PHASE1_MVP_FIRST_ROADMAP_20261016.md`
- `docs/architecture/FWIOS_ARCHITECTURE_V3.md`

Live `System_Foundation` records Native Tracker Shadow Sync as PASS.

## IMPORTANT OPEN ISSUE — P0 BEFORE PRICE DATA CUTOVER

The 07:00 stock portfolio sync is currently **earlier than the broad EOD daily-close ingestion pipeline**.

Live Cron:
- `fwios-market-daily-close-enqueue` = `25 5 * * 1-5` UTC
- `fwios-market-daily-close-worker` = `*/2 5-8 * * 1-5` UTC

This is approximately 12:25–15:00 Asia/Bangkok, later than the 07:00 portfolio stock sync.

Live verification on 2026-10-17:
- MSFT latest REGULAR_CLOSE session = 2026-10-15
- NVDA latest REGULAR_CLOSE session = 2026-10-15
- TLN latest REGULAR_CLOSE session = 2026-10-15
- TTWO latest REGULAR_CLOSE session = 2026-10-15

The US market session of Friday 2026-10-16 had already closed, so this proves the current 07:00 stock sync can lag by a session.

Do **not** call stock data at 07:00 fully production-current until this is resolved.

### Recommended next action

First task in next chat:
1. Inspect the daily-close enqueue/worker behavior and provider availability.
2. Re-align the EOD ingestion schedule so the latest US regular close is canonical **before 07:00 Asia/Bangkok**.
3. Account for Bangkok/US day-boundary and DST correctly. Likely US Monday-Friday sessions map to Bangkok Tuesday-Saturday mornings.
4. Run a targeted latest-session test for MSFT/NVDA/TLN/TTWO.
5. Confirm 07:00 stock sync reads the newest completed US session.
6. Confirm 07:10 native Sheet sync copies that same session into `_Market_Data`.
7. Only after this passes, perform final `_Market_Data` vs current `Price Data` reconciliation.
8. Do not cut over `Price Data` without owner approval.

## Price Data cutover status

**NOT DONE.**

Current production accounting read path is unchanged:
`Price Data → Holdings`

Shadow path:
`Supabase canonical market data → _Market_Data`

Future intended path, only after reconciliation and explicit approval:
`_Market_Data → Price Data → Holdings`

Do not rewrite Transactions or Cost Basis during this cutover.

## Current open holdings

10 unique open assets:
- BTC
- DOGE
- ETH
- HBAR
- MSFT
- NVDA
- SOL
- TLN
- TTWO
- XRP

Current open stocks:
- MSFT
- NVDA
- TLN
- TTWO

## Non-negotiable rules

- Never call `LAST_CLOSE` live.
- Native USD is canonical for asset prices.
- USDTHB is a separate FX reference.
- Historical THB records remain truthful; never relabel them USD.
- Google Sheet remains downstream view/accounting surface, not a second market-data authority.
- No second transaction ledger in Supabase.
- No automated trade execution.
- Never merge PR #52 without explicit owner permission.
- Keep `Price Data` unchanged until reconciliation is accepted.

## New-chat kickoff prompt

Continue FWIOS Phase-1 from:
`docs/implementation/PR7_HANDOVER_TO_NEXT_CHAT_20261017.md`

Before doing anything:
1. Read `AGENTS.md`, `contracts/system-contract.yaml`, `VERSION`, the handover, the Phase-1 roadmap and FWIOS Architecture v3.
2. Inspect live PR #52 and branch `feat/pr5-native-usd-price-shadow`.
3. Inspect Supabase live Cron and latest REGULAR_CLOSE sessions.
4. Do not merge PR #52.
5. Do not touch Price Data, Transactions, Holdings, Cost Basis or P&L yet.

Immediate task:
Fix/validate the EOD stock daily-close timing so latest US regular close is canonical before the 07:00 Asia/Bangkok portfolio stock sync. Then verify the 07:10 native `_Market_Data` sync uses that same latest session. After that, do final shadow reconciliation and propose the controlled Price Data read cutover, but do not execute cutover without explicit owner approval.
