# FWIOS Price-Only Phase 2 — LIVE Decommission Receipt (2026-10-29)

**Authoritative status: PARTIAL CUTOVER; price transport PASS; complete Research/Decision schema teardown NOT YET DONE.** Supabase project `ysjbmeukwbfnxnwqchuq`. User expressly requested to remove all Stock Discovery/Technical Screening/Valuation/Decision and redundant Portfolio state and retain only API -> verified market price DB -> Google Sheet. No trading or portfolio/accounting mutation.

## Implemented and tested

1. New Edge `price-market-refresh-v1` ACTIVE v1 (source `supabase/functions/price-market-refresh-v1/index.ts`). Reads eligible open Crypto symbols from Google Sheet Holdings **READ ONLY**, fetches six native USD crypto quotes from CoinGecko with timestamps, and fetches USDTHB FX rate from Frankfurter. Writes ONLY via `fwios.ensure_market_observation_v1` into canonical `fwios.market_observations`; no portfolio MTM tables or calculations. Runtime token checked against Vault; only POST accepted; source freshness and positive prices are mandatory. Distinct CRYPTO/FX modes, no trade.
2. Live HTTP dry-run: FX request 11959 HTTP 200 / 0 writes; CRYPTO 11960 HTTP 200 / 6 assets / 0 writes. Live actual writes: FX request 11961 HTTP 200, 1 Market Observation; CRYPTO request 11962 HTTP 200, six observations, 0 Portfolio writes. Post-read confirmed 7 new price-only observations and no changes to portfolio quote/MTM counts at the manual test.
3. Live Google Sheet price-only sync HTTP request 11963 returned HTTP 200, 10 asset rows, verified `_Market_Data` write/readback; independent Google Drive connector read showed all 10 prices, and `Price Data`/ `Holdings` formulas consume `_Market_Data`.
4. Existing Cron #14 (Crypto daily) now invokes new CRYPTO mode and #15 (weekday post-US-close) new FX mode; Cron #16 had already been cut over to `price-sheet-sync-v1`; stock EOD Cron #6/#7 retain their market price role. Existing frequency/time windows preserved; **the next naturally scheduled run has not yet been observed**, so scheduled continuity should be checked after the next US close. Original Cron #14/15 command snapshot saved in `decommission/rollback/portfolio_mtm_cron14_15_before_price_cutover_20261029.sql.txt`.
5. Tombstoned old `portfolio-mtm-refresh-v1` ACTIVE v8 and legacy `portfolio-sheet-shadow-sync-v1` ACTIVE v8 with inert 410 handlers / JWT enforced; neither endpoint is called by an active Cron. Earlier scanner/decision workers were tombstoned too. Do not confuse an ACTIVE deployed 410 tombstone with an active business workflow.
6. Additional user-requested **irreversible removals** after dependency checks:
    - `portfolio_mtm_runs` (2,248 old rows), `portfolio_scenario_runs`, `portfolio_scenario_actions`, `portfolio_scenario_metrics`, `portfolio_scenario_positions`;
    - `portfolio_market_quote_snapshots` (15,044 redundant THB/portfolio quote rows), old views and `sync_portfolio_market_quote_observation_v1()` (its table-owned trigger dropped with table);
    - `portfolio_live_holdings_batches_v1`, `portfolio_live_holdings_rows_v1`, `portfolio_position_reconciliations`, `portfolio_source_positions`, `portfolio_transaction_reconciliations`, `portfolio_theme_registry`, `candidate_portfolio_scenario_reviews_v2` plus downstream views;
    - five old `portfolio_scenario_* / preview_portfolio_scenario_*` functions;
    - prior phase-1 TTWO `ai_model_candidates_v1`, `ai_model_evaluations_v1`, two TTWO-only model functions.
    All drop operations used **RESTRICT**, not CASCADE, with count/runtime preflights. The old Google Sheet transactions, price history, canonical `market_observations`, market EOD quota and worker were not dropped.
7. **18/18** live read-only regression PASS: `tests/price/test_price_only_decommission_phase2_20261029.sql`. Base-table count in fwios: initial **116 → 101** (15 tables physically removed). Remaining Research, Decision and financial model tables still exist and are outside this Phase 2.

## Ledger safety exception — avoid permanent loss

Live Supabase `fwios.portfolio_transactions` contains **58 historical entries**, while the connected Google Sheet Transactions tab exposes substantially fewer occupied data rows (read range A1:P140 yields 35 rows with 34 nonempty including labels and headers). It is **not proven that 58 ledger rows are mirrored in the Sheet**. Therefore the Supabase Ledger **has not been deleted**, despite owner's general cleanup request, pending exact source-ID reconciliation or user-specified secure export/backup. This is necessary to prevent irreversible accounting information loss; do not infer equality from Sheets being labeled the accounting authority.

`candidate_portfolio_fit_snapshots` and `portfolio_fit_policies` are also retained because old `candidate_decision_scores` and `decision_snapshots` maintain dependent foreign keys. The broader Decision/Valuation teardown must remove these references first (or explicitly remove the dependent non-price objects), not `CASCADE` blindly. EOD still uses `decision_refresh_provider_registry` and `decision_refresh_automation_access` for provider configuration/token check, so those decision-named **live price dependencies** cannot be dropped until migrated.

## Next safe phase

- Verify next scheduled #14/#15/#16 outcomes via `cron.job_run_details`, canonical price timestamps, Sheet `_Market_Data` readback.
- Refactor stock EOD provider/auth to dedicated price-only registry and OAuth/access policy; consider restricting 64-name EOD collector to desired pricing universe if user instructs, preserving historical daily closes.
- Reconcile/export the exact 58 legacy Supabase ledger source rows against Google Sheet Transactions without exposing trade history publicly; no deletion until discrepancy resolved.
- Inventory remaining 101 tables and dependent views/functions, build a scoped Research/Technical/Valuation/Decision drop migration with explicit price dependency allowlist and roll-forward/rollback runbook.
- Update `contracts/system-contract.yaml` after complete live cutover, not prematurely. Keep `auto_trade=false`.

**This is not a claim that FWIOS is fully price-only yet.**
