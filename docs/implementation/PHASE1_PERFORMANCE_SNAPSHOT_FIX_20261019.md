# Phase-1 Performance daily snapshot fix — 2026-10-19

## Problem

The Portfolio Tracker `Performance` tab had healthy live Current P&L formulas, but its frozen historical snapshot table stopped at 2026-09-03. The native US-close worker updated `_Market_Data` and `FWIOS Live Valuation`, but did not publish Performance history.

## Scope

Minimal Phase-1 fix in `portfolio-sheet-shadow-sync-v1`:

- After live Holdings projection and account valuation both verify PASS, publish one frozen Performance row per account: ALL, Best, Loan Money, Mom.
- Use Asia/Bangkok calendar date for the snapshot key.
- Upsert the same-day account row instead of creating duplicates.
- Require the same live projection batch, valuation gate PASS, zero unpriced positions, and finite account values before writing.
- Read back and verify date, account, value, contribution, cumulative contribution, and gain/loss.
- Do not infer deposits/withdrawals from BUY/SELL transactions. New automatic rows default `Net Contribution THB=0`; an explicit same-day value is preserved and cumulative contribution is recomputed from snapshot history.
- Benchmark columns remain blank in Phase 1. The open-holdings-only market-data feed is not widened solely for benchmark data.

## Google Sheet cleanup

`Performance`:
- Normalized 2026-08-31 and 2026-09-03 historical dates from text to real Sheet dates.
- Renamed the live metric label to `Current Holdings Value` to avoid implying cash-inclusive NAV.
- Added `Snapshot Status` with a FRESH/STALE date indicator.
- Updated the explanatory note to state explicit-only contribution handling and deferred benchmark behavior.

No Transactions, Cost Basis, realized P&L, source Holdings quantities, or existing Holdings formulas were changed.

## Production verification

Edge Function `portfolio-sheet-shadow-sync-v1` deployed ACTIVE v7.

Dry run:
- HTTP 200
- pricing gate PASS
- 10/10 open assets
- `FWIOS_NATIVE`
- no write attempted

Live write:
- HTTP 200
- 10 market rows verified
- 15 live position rows
- live projection batch `14b50cbc-8e7c-4341-92af-32b3127dc550`
- 4/4 account valuations verified
- Performance snapshot date `2026-10-19`
- Performance readback verified

Snapshot receipt:
- ALL: THB 330,359.61; cumulative contribution THB 10,000; gain/loss vs baseline THB 2,178.59; period return -2.56%
- Best: THB 224,473.45; cumulative contribution THB 10,000; gain/loss vs baseline THB 6,189.35; period return -1.10%
- Loan Money: THB 46,094.33; cumulative contribution THB 0; gain/loss vs baseline THB -3,411.87; period return -5.45%
- Mom: THB 59,791.82; cumulative contribution THB 0; gain/loss vs baseline THB -598.89; period return -5.54%

Post-write Sheet check:
- `Snapshot Status = FRESH · 2026-10-19`
- Filtered snapshot view includes 2026-10-19
- no operational formula errors found in `Performance!A1:S40`
- `auto_trade=false`; accounting remains read-only
