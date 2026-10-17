# Phase-1 P3/P4/P5 acceptance — 2026-10-17

## Scope
- P1: user reports legacy Apps Script writer deleted. Six crypto Price Data G/H/M formulas restored from the native stock template; column L rollback and all accounting tabs preserved. Check again after the next previously scheduled interval.
- P2: **explicitly deferred**. Do not implement an exact US-session freshness gate.
- P3: non-accounting read-only Holdings quantity projection, not an update to transaction/cost-basis/source-reconciliation ledgers.
- P4: historical system_state journal archived (145 original entries), current status normalized to a JSON object; a database write trigger enforces object shape on future workers.
- P5: all 70 _Market_Data rows have post-write identity, native price, observation, eligibility and calculated THB verification; USDTHB FX provider/rate/observation/status are checked.

## Deployed
- Supabase project: ysjbmeukwbfnxnwqchuq.
- Edge worker portfolio-sheet-shadow-sync-v1 **v4 ACTIVE**.
- SQL migrations applied: phase1_live_holdings_projection_state_normalize_v1; phase1_system_state_trigger_guard_v1; phase1_native_live_valuation_align_v1.
- Manual request source PHASE1_P3_P5_VERIFY_V4 returned HTTP 200, 70 shadow rows verified, 15 live Holdings rows, 10 assets, no accounting writes, auto_trade=false.
- New live portfolio valuation: fwios.v_portfolio_live_account_valuation_v1; ALL: THB 333825.15 matching Google Sheet derived values, gate PASS and zero unpriced rows.
- Source reconciliation: 13 matching account-asset lines and 2 historical drift lines (Best NVDA and Best TTWO). Old canonical accounting snapshots are deliberately unchanged.
- Operational state readback: object, portfolio_tracker_shadow_sync_status=PASS, auto_trade=false.
- Six crypto Price Data audit G/H/M formulas repaired after the owner removed the old writer; Column L remains available for legacy rollback.

## Important non-claims
- Do not claim the historical fwios.v_portfolio_positions_current or fwios.v_dashboard_account_summary accounting-derived summary was rewritten. Use v_portfolio_live_positions_current_v1 and v_portfolio_live_account_valuation_v1 for the current quantity and live market value.
- Pricing is not guaranteed to belong to the **most recent expected** stock-market session; P2 remains deferred.
- Two autonomous US-close cycles under the new cadence are still pending. Existing scheduled checks cover the next two sessions.
- The live projection refreshes when the native Sheet shadow worker runs, nominally 17:20 America/New_York. It is not a real-time on-trade ledger sync.
- Do not enable auto execution, and never mutate Transactions, Cost Basis, P&L, balances, or source-accounting formulas.
