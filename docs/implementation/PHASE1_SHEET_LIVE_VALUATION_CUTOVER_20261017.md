# FWIOS Live Valuation → Portfolio Tracker: production cutover
Date: 2026-10-17

## Owner and source
- PostgreSQL view: `fwios.v_portfolio_live_account_valuation_v1`
- Google Sheet: `Investment Portfolio Tracker - Chumponphat`
- Visible tab: `FWIOS Live Valuation` (`A4:J8`)
- Worker: `supabase/functions/portfolio-sheet-shadow-sync-v1/index.ts`, Edge Function v5
- Existing schedule unchanged: `fwios-portfolio-sheet-shadow-sync-native` (17:20 America/New_York)
- Accounting remains in `Holdings` / `Transactions`; the worker only **reads** Holdings and only **writes** `_Market_Data` + the new valuation display tab.

## Active data flow
`Holdings` (READ ONLY) → `fwios.portfolio_live_holdings_*_v1` → `fwios.v_portfolio_live_account_valuation_v1`
→ `FWIOS Live Valuation!A5:I8` → `Dashboard!A7`.

Four display rows keyed as ALL, Best, Loan Money, Mom. The worker compares source_batch_id with the just-refreshed Holdings projection batch, checks all account valuation gates and zero unpriced positions, verifies totals equal sum of the three account rows, and reads back all Sheet rows and the local `vs Holdings (THB)` formula. A mismatch fails the worker's receipt.

Dashboard `A7` switches `Portfolio Value` to the new tab when its selected-account gate is PASS; otherwise falls back to the existing, unchanged Holdings calculation. `Dashboard!I6:J6` explicitly displays `FWIOS SNAPSHOT` or `SHEET FALLBACK`. It does not change total P&L, allocation denominators elsewhere, or accounting records.

## Controlled production verification
- Manual authorized invocation `PHASE1_LIVE_VALUATION_SHEET_CUTOVER` returned HTTP 200.
- `_Market_Data` readback: 70 rows verified with native USD/FX.
- `FWIOS Live Valuation` readback: 4/4 PASS, `vs Holdings (THB)` = 0.00 for every account.
- ALL THB 333,825.15; Best 226,107.96; Loan Money 47,446.25; Mom 60,270.93.
- Dashboard A7 showed Best THB 226,108 rounded, source `FWIOS SNAPSHOT`.
- `auto_trade=false`. No transaction or cost-basis mutation.

## Accepted limitations
- This valuation feed is a **post-close snapshot**, not intraday or instant after a trade.
- User explicitly deferred exact-US-session freshness gate (prior point 2). No such policy was added.
- The first autonomous post-close E2E runs are separately monitored; a manual 200 does not mean scheduled E2E is complete.
- On feed failure, Dashboard A7 visibly falls back to its original Holdings value calculation; this is a display fallback, never a ledger rewrite.
