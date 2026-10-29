# FWIOS PRICE-ONLY DECOMMISSION — ACTIVE CUTOVER / INCOMPLETE (2026-10-29)

## Exact user mandate
Remove **all** Stock Discovery, Technical Screening, Thesis, Valuation, Scoring, Decision and redundant Portfolio backend state/functions from Supabase. **Keep only API market-price collection, authoritative market-price storage/verification/quotas, and the Google Sheet price update path.** The Investment Portfolio Tracker Google Sheet remains the owner of Transactions, Holdings, cost basis and portfolio accounting.

## Safe work actually completed on live production

Project: `ysjbmeukwbfnxnwqchuq`.
1. New Edge Function `price-sheet-sync-v1`, **ACTIVE v1**, source `supabase/functions/price-sheet-sync-v1/index.ts`. This reads *live open asset symbols* via the Google Sheet Holdings API **without saving holdings to Supabase**, reads native USD quote status through market observation resolver, retrieves USD/THB from market observations, and writes **only** `_Market_Data!A2:Q` + FX `R2:X2`. It performs Google Sheets full price-and-FX readback verification. No portfolio transactions/holdings/accounting writes.
2. Dry-run returned HTTP 200, `asset_count=10`, DB writes 0, Sheet writes 0 (HTTP request #11957).
3. Real Sheet write/readback returned HTTP 200, `asset_count=10`, `sheet_write_readback_verified=true`, DB writes 0 (HTTP request #11958); independent connected Google Sheets readback confirmed exact `_Market_Data` header and 10 rows BTC,DOGE,ETH,HBAR,MSFT,NVDA,SOL,TLN,TTWO,XRP.
4. Cron #16's existing daily 17:20 New York schedule is **CUT OVER** from `portfolio-sheet-shadow-sync-v1` to `price-sheet-sync-v1`, source `supabase/migrations/20261029091000_price_only_sheet_sync_cutover_v1.sql`. It remains active. Old Edge Function still deployed but no longer called by this Cron.
5. User-approved isolated TTWO AI-generated model cleanup applied: `fwios.ai_model_candidates_v1`, `fwios.ai_model_evaluations_v1` and associated TTWO-only register/evaluator functions dropped with **RESTRICT** (not CASCADE); source `supabase/migrations/20261029161500_drop_isolated_ttwo_model_shadow_v1.sql`. Live readback confirms `to_regclass` and `to_regprocedure` are NULL. Production fwios base-table count **116 → 114**.
6. Existing 64-name daily stock close jobs #6 and #7 stay active; crypto/USD and FX observation maintenance is still live from the *old* Portfolio MTM worker jobs #14 and #15. No source market prices, Google Sheet ledger, or portfolio data dropped in this phase.

## NOT YET COMPLETE — critical production blockers

**DO NOT ASSERT full schema deletion or functional dependency cutover.** 114 fwios tables plus 57 views and many SQL functions remain. Cron #14 and #15 still use `portfolio-mtm-refresh-v1`, which reads `fwios.v_portfolio_positions_current` and writes `fwios.portfolio_market_quote_snapshots`, `fwios.portfolio_mtm_runs`, and `fwios.system_state`. It is currently responsible for native USD CoinGecko crypto data and for USDTHB FX via Twelve Data / fallback. **Dropping any of those core Portfolio dependencies now would break current price-collection freshness and ultimately the Google Sheet**.

The stock EOD worker additionally reads `fwios.decision_refresh_provider_registry` for Twelve Data credential routing and `fwios.decision_refresh_automation_access` for token verification. They are wrongly named legacy dependencies but are **live price dependencies**; DO NOT DROP until refactored.

The new price-only Sheet worker still calls `fwios.pr7_native_usd_price_read_v1`, which depends on `pr5_native_usd_price_shadow_v1`, instrument identity, and canonical market observations. Preserve these dependencies. The old market data schema includes source/quota/history/verification tables; not all tables with legacy names may be deleted blindly.

Existing Decision/Thesis/Scanner cron tasks #2, #8, #9 were previously paused on 2026-10-29; opportunity quality #10 already inactive; TTWO daily ChatGPT Research Manager paused. Research provider validator #5 remains active and may update price-provider readiness; audit before retirement. Disabling or dropping auth/provider registry without replacing it could break market EOD ingestion.

## Required remaining execution, in order

1. Build **independent price-only CoinGecko USD + USD/THB FX collector**, with token auth, provider/quota safety, point-in-time freshness and direct write to `fwios.market_observations`; no portfolio MTM/run/status/holdings storage. Test it with independent API and Google Sheet readback across two price sessions.
2. Replace Cron #14 and #15 with that dedicated price API collector; prove crypto/FX and 64-stock EOD fresh and verified, no unexpected portfolio DB writes for full cycle.
3. Decouple EOD worker from `decision_refresh_provider_registry` and `decision_refresh_automation_access` by moving needed configuration/auth to dedicated price-only configuration with a migration, preserving keys in Vault and least privilege.
4. Inventory and separately migrate **every function/view/trigger/table/foreign key**, retaining only necessary market price/identity/verification/quota/Google Sheet price services. No broad `DROP SCHEMA` or `CASCADE` until the price-only graph is proven. Create a verified restore point or approved backup before irreversible physical removal; keep source migrations in GitHub.
5. Stop/delete remaining non-price Cron + edge endpoints, retire research/valuation/scoring/decision tables, portfolio account/ledger/MTM and their functions, then perform negative tests (non-price tables/functions absent) and end-to-end price/sheet parity.
6. Reconcile contract `contracts/system-contract.yaml` ownership semantics after measured cutover; current `portfolio_state.current_authority: Supabase` is not the desired end state.
7. Keep `auto_trade=false` and do not mutate transactions in the Google Sheet. Existing historical prices must remain intact.

## Safety / honesty

This work is **partially complete**. All market price Cron paths remain functioning while a new price-only Google Sheet sync is now independent of Portfolio database writes. Old Stock Discovery and other requested tables have **not** yet all been removed. Current multi-purpose `fwios` cannot safely be dropped as a single schema without losing actual price and sheet functionality. Complete the remaining steps before a final mass cleanup.
