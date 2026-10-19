# FWIOS Phase-1 — Handover to next chat (2026-10-19, Asia/Bangkok)

## Update — Performance daily snapshots restored (2026-10-19)
- Root cause: `portfolio-sheet-shadow-sync-v1` published native market data and live valuation but never wrote the `Performance` history table, so snapshots stopped at 2026-09-03.
- Worker v7 now publishes verified daily frozen snapshots for ALL / Best / Loan Money / Mom after the live valuation gate passes.
- Production write/readback PASS on 2026-10-19; `Performance!A21:I24` populated and Snapshot Status reports `FRESH · 2026-10-19`.
- Contributions are explicit-only: the worker never infers deposits/withdrawals from BUY/SELL. New rows default to zero and preserve an explicit same-day contribution when present.
- Benchmark remains intentionally deferred in Phase 1; no extra market-data universe/API usage was added.
- No Transactions, Cost Basis, realized P&L, quantities, or Holdings formulas were mutated.
- Details: `docs/implementation/PHASE1_PERFORMANCE_SNAPSHOT_FIX_20261019.md`.

## Update — Portfolio Tracker cleanup deployed (2026-10-19)
- Google Sheet is now focused on accounting + portfolio display: visible tabs are Dashboard, Transactions, Price Data, Holdings and Performance.
- Hidden helpers are Checks, Lists, _Market_Data and FWIOS Live Valuation.
- Portfolio Guardrails, Risk Dashboard, Thesis Tracker, Thesis History, Thesis Evidence and AI Integration Config were removed after dependency checks and backups.
- Supabase system state owns `portfolio_price_read_mode=FWIOS_NATIVE`; Price Data no longer depends on a Sheet config switch.
- `portfolio-sheet-shadow-sync-v1` deployed as v6 and now publishes OPEN holdings only from `fwios.v_portfolio_live_positions_current_v1`.
- `_Market_Data` was reduced from ~70 active-instrument rows to exactly 10 open-held assets + USDTHB FX.
- Transactions and Holdings matched the pre-slim backup after cleanup; operational checks all OK; live valuation remains PASS with 0 unpriced and 0.00 reconciliation deltas.
- Legacy Price Data K/L remain only as rollback reference until autonomous US-close E2E confidence is complete.
- Details: `docs/implementation/PHASE1_PORTFOLIO_SHEET_CLEANUP_20261019.md`.


## Update — crypto UTC rollover P0 fixed and deployed (2026-10-19)
- Applied Supabase migration `phase1_crypto_utc_rollover_freshness_v1` to project `ysjbmeukwbfnxnwqchuq`.
- `fwios.pr5_native_usd_price_shadow_v1` no longer requires crypto `session_date = current UTC date` for `FRESH`; it still requires CoinGecko native USD provenance, positive price, non-future observation and age <= 30 hours.
- Post-deploy regression: 10/10 PASS. BTC/DOGE/ETH/HBAR/SOL/XRP are `FRESH` + valuation-eligible; MSFT/NVDA/TLN/TTWO remain `LAST_CLOSE`; all have `trading_eligible=false`.
- Live `fwios.v_portfolio_live_account_valuation_v1` recovered to `PASS` with 0 unpriced positions for ALL/Best/Loan Money/Mom; numerical values and projection batch were unchanged by the DDL-only fix.
- `auto_trade=false` and `portfolio_mutation=false` confirmed. Function remains SECURITY INVOKER with EXECUTE only for postgres/service_role.
- The next priorities are now: distinguish live gate vs last-written Sheet status, verify 1–2 autonomous US-close E2E sessions, confirm legacy CoinGecko Apps Script does not overwrite formulas, then proceed to Focused Dashboard MVP.

## User-authorized scope and decisions
- Continue the **MVP-first** approach; avoid speculative refactoring or over-engineering.
- The user independently disabled/deleted the legacy CoinGecko direct Google Apps Script function and trigger; the six crypto `Price Data` G/H/M native formulas were restored and inspected immediately afterward.
- The user **explicitly deferred** the stock exact-US-session freshness gate (prior point 2). DO NOT implement that policy without another request.
- User approved items 3 (current positions projection), 4 (normalize operational system state), 5 (full readback verification), and subsequently explicitly approved using `fwios.v_portfolio_live_account_valuation_v1` in the Google Sheet.
- **HARD GUARDRAILS**: `auto_trade=false`, human execution only, do not update or recreate accounting Transactions, Cost Basis, realized P&L, cash, position quantities in source accounting tables, or existing Holdings formulas.

## Repository, links, and runtime
- GitHub repository: https://github.com/ChumponphatRangsee/focused-wealth-investment-os
- Canonical branch: `main`.
- Supabase production-as-test project ID: `ysjbmeukwbfnxnwqchuq`.
- Google Sheet source-of-truth for accounting: `Investment Portfolio Tracker - Chumponphat`, ID `1MUZD_nevvmH3yx972Ep6o8pCRmsdd_IgzSzjD6TPCjw`.
- Native Price Data mode: Supabase `fwios.system_state` key `architecture_consolidation_v1.state_value.portfolio_price_read_mode=FWIOS_NATIVE`; the former `AI Integration Config` Sheet tab has been removed.
- Deployed `portfolio-mtm-refresh-v1` ACTIVE v7; `portfolio-sheet-shadow-sync-v1` ACTIVE v6; `market-daily-close-worker-v1` ACTIVE v3.
- Current Price Data refresh path: `Supabase open-held assets only -> _Market_Data (10 assets + FX) -> Price Data -> Holdings`.
- Current valuation-display path: `Holdings (READ ONLY) -> fwios.portfolio_live_holdings_*_v1 -> fwios.v_portfolio_live_account_valuation_v1 -> FWIOS Live Valuation!A5:I8 -> Dashboard!A7`.
- `Dashboard!J5` selects account; `Dashboard!J6` displays `FWIOS SNAPSHOT` or `SHEET FALLBACK`. The fallback uses the original Holdings summation without changing its records.

## Completed PRs, confirmed merged into main
- #49 (Provider Quota) -> main, merge commit `549faaba65174d86569dc35ce6164b185f78c29e`.
- #50 (Atomic Quota), merge commit `26be8ed411464a220f12965046ab98aad17a6934`.
- #51 (Cache/Single-flight/Priority Scheduler), merge commit `738053102456fe47c633a015def02ac60abc107a`.
- #52 (Native USD shadow adapter), merge commit `ea5c99414cf430f7613279b42bbc046b8e659800`.
- #53 (read-only Holdings projection, system_state archived+normalized with recurrence-prevention trigger, per-row/FX Sheet verification), merge commit `cf24cff4b8af070ef6a9879158df573240cadae5`.
  - Docs: `docs/implementation/PHASE1_P3_P4_P5_ACCEPTANCE_20261017.md`.
  - `fwios.system_state_legacy_archive_v1` holds original 145 entries; current `fwios.system_state` state is JSON object, `auto_trade=false`.
  - The old accounting-derived `fwios.v_portfolio_positions_current` intentionally still has older reconciled batch quantities. NEW `fwios.v_portfolio_live_positions_current_v1` is source for current projection; old accounting views were not rewritten.
- #54 (Google Sheet live-valuation display cutover), merge commit `ad9989b4cec0ebadbbe644e3d57f010b45bb8da0`.
  - Docs: `docs/implementation/PHASE1_SHEET_LIVE_VALUATION_CUTOVER_20261017.md`.
  - On 2026-10-17 manual test: 70/70 rows `_Market_Data` readback verified; 4/4 account valuations and reconciliation deltas (0.00) verified, HTTP 200. Dashboard `A7` shows Supabase-based valuation with explicit source label.
  - CI on PR54 head `PR5 Native USD Adapter (offline)` passed; PR54 merged into main.

## Deployed schedule (America/New_York time; DST guarded)
- Equity EOD enqueue 16:05 ET; EOD worker from 16:05–17:05 ET; stock and crypto refresh 17:10 ET; native shadow + valuation Sheet sync 17:20 ET.
- Existing cron job names `fwios-market-daily-close-enqueue`, `fwios-market-daily-close-worker`, `fwios-portfolio-stock-post-close-sync`, `fwios-portfolio-crypto-daily-snapshot`, `fwios-portfolio-sheet-shadow-sync-native`.
- Crypto and Sheet cron jobs ran autonomously for Sunday 2026-10-18 ET (at 21:10/21:20 UTC), with current state receipt `PASS` for `CRON_US_CLOSE_NATIVE_SHEET_SYNC`.
- The **first full autonomous U.S. equity-close E2E after new cadence remains unverified** as of 2026-10-19 08:11 Bangkok. Next eligible equity session: Monday 2026-10-19 ET / Tuesday 2026-10-20 Bangkok.
- A two-session automation for October 20 and 21 at 04:35 Bangkok was set in the previous chat. Verify its results before declaring scheduled E2E accepted.

## LIVE snapshot recheck — 2026-10-19 08:10–08:12 Asia/Bangkok
- `FWIOS Live Valuation!A5:J8`: ALL THB **330,359.61**, Best 224,473.45, Loan Money 46,094.33, Mom 59,791.82; 15 open account-level rows, 10 distinct assets, `vs Holdings` deltas all THB 0.00.
- Sheet's LAST WRITTEN snapshot claims Gate PASS and `Dashboard!J6=FWIOS SNAPSHOT`, `Dashboard!A7` for Best ~THB 224,473.
- Supabase current `fwios.v_portfolio_market_price_health` (older compatibility quote snapshots): pricing_gate PASS, 10/10 fresh.
- **CRITICAL IMPORTANT:** live `fwios.v_portfolio_live_account_valuation_v1` now reports `valuation_gate=BLOCKED`, `unpriced_positions=10` overall, even though the numerical value still computes. This is a current-time state shift AFTER the last successful Sheet snapshot. Do not claim the live valuation is currently PASS just because the last-written Sheet status was PASS.
- Root cause confirmed from `pg_get_functiondef` of `fwios.pr5_native_usd_price_shadow_v1`: crypto's `FRESH` logic checks BOTH quote age <= 30h AND `market_observations.session_date = (now() at time zone 'UTC')::date`. After UTC midnight, all six crypto assets appear `STALE` despite recent observed_at around 2026-10-18T21:09:56Z and `valid_until=2026-10-20T03:09:56Z`. Stocks remain `LAST_CLOSE` and valuation_eligible=true. All ten affected account-position rows are crypto positions (3 Best, 6 Loan Money, 1 Mom).
- This is a **crypto daily-snapshot UTC rollover bug**, independent of the deferred exact-US-stock-session price gate.

## Priority next steps for new chat
1. **P0 FIX crypto UTC rollover false-STALE bug — COMPLETE / DEPLOYED 2026-10-19.** The minimal SQL fix removes only the crypto current-UTC-date equality from freshness; 30h max age and all provenance/positivity/future guards remain. Post-deploy regression 10/10 PASS; six crypto valuation-eligible, live account valuation PASS with zero unpriced positions. This is **not** the user-deferred stock exact-session check.
2. **P0 RECONCILE displayed snapshot vs live gate**: the Sheet retains last successful Gate PASS after a later live gate becomes BLOCKED; consider a simple truthful `as of` / stale display flag, without prematurely hiding last validated values or rewriting accounting.
3. **P1 OBSERVE 1–2 autonomous US-close equity sessions**: check EOD enqueue/worker real cron receipts, stock and crypto MTM, Native Sheet sync, four-account valuation rows, USDTHB, 15 Holdings positions, no source accounting edits. Report exact timestamps and PASS/FAIL; a successful pg_cron invocation with `0 rows` is a guard-suppressed run, not proof of completed E2E.
4. **P2 REGRESSION**: Confirm that after user removed legacy Apps Script trigger, `Price Data` crypto G/H/M native formulas have not been overwritten again; keep L rollback untouched.
5. **P2 THEN proceed to Focused Dashboard MVP**. Only Portfolio Value on the Google Sheet Dashboard was switched to the Supabase view: other P&L/allocation/risk fields intentionally remain based on Holdings accounting. Keep their meanings consistent; do not migrate account ledger or introduce auto-trading.
6. Continue keeping PRs and docs synchronized, run CI before merge and production verification after deploying. Favor shipping usable Phase-1 over architecture-heavy redesign.

## Read-first instructions for next agent
1. This handover.
2. `AGENTS.md`, `contracts/system-contract.yaml`.
3. `docs/implementation/PHASE1_P3_P4_P5_ACCEPTANCE_20261017.md`.
4. `docs/implementation/PHASE1_SHEET_LIVE_VALUATION_CUTOVER_20261017.md`.
5. `supabase/functions/portfolio-sheet-shadow-sync-v1/index.ts`; SQL function definitions `fwios.pr5_native_usd_price_shadow_v1`, `fwios.pr7_native_usd_price_read_v1`; relevant migrations.
6. Inspect live `fwios.v_portfolio_live_account_valuation_v1`, `fwios.v_portfolio_market_price_health`, `fwios.system_state`, live Sheet tabs and actual scheduled run receipts **before making changes**.

## Suggested kickoff prompt
Continue FWIOS Phase-1 from `docs/implementation/FWIOS_PHASE1_HANDOVER_20261019.md`. Verify latest production state first. Prioritize fixing the confirmed crypto daily UTC date-rollover false-STALE bug in the native price view (separate from the deferred stock session freshness policy), then reconcile live-gate vs last-written Google Sheet display, and verify scheduled 1–2 autonomous US-close E2E sessions. Keep the implementation minimal and reversible; preserve `auto_trade=false`, never mutate Transactions, Cost Basis, realized P&L, or source Holdings formulas. Report actual test evidence and PR/merge status.
