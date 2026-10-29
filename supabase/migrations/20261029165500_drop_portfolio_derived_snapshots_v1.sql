-- Remove non-accounting portfolio derivatives after independent price-only readback proof.
-- NOTE: portfolio_transactions ledger is intentionally retained pending Sheet reconciliation.
DO $pre$
BEGIN
 IF (SELECT count(*) FROM fwios.portfolio_live_holdings_batches_v1)<>1 OR
    (SELECT count(*) FROM fwios.portfolio_live_holdings_rows_v1)<>15 OR
    (SELECT count(*) FROM fwios.portfolio_position_reconciliations)<>32 OR
    (SELECT count(*) FROM fwios.portfolio_source_positions)<>32 OR
    (SELECT count(*) FROM fwios.portfolio_transaction_reconciliations)<>58 OR
    (SELECT count(*) FROM fwios.portfolio_theme_registry)<>10 OR
    (SELECT count(*) FROM fwios.candidate_portfolio_fit_snapshots)<>5 OR
    (SELECT count(*) FROM fwios.portfolio_fit_policies)<>1 OR
    (SELECT count(*) FROM fwios.candidate_portfolio_scenario_reviews_v2)<>0 THEN
      RAISE EXCEPTION 'PORTFOLIO_DERIVED_PRE_DROP_COUNT_DRIFT'; END IF;
 IF (SELECT count(*) FROM cron.job WHERE active AND command LIKE '%portfolio-mtm-refresh-v1%')>0 THEN
      RAISE EXCEPTION 'OLD_PORTFOLIO_MTM_STILL_ACTIVE'; END IF;
END $pre$;
DROP VIEW fwios.v_portfolio_live_quantity_reconciliation_v1 RESTRICT;
DROP VIEW fwios.v_portfolio_live_account_valuation_v1 RESTRICT;
DROP VIEW fwios.v_portfolio_live_positions_current_v1 RESTRICT;
DROP VIEW fwios.v_portfolio_positions_current RESTRICT;
DROP VIEW fwios.v_candidate_portfolio_fit_current RESTRICT;
DROP VIEW fwios.v_candidate_portfolio_scenario_review_current RESTRICT;
DROP TABLE fwios.portfolio_live_holdings_rows_v1 RESTRICT;
DROP TABLE fwios.portfolio_live_holdings_batches_v1 RESTRICT;
DROP TABLE fwios.portfolio_position_reconciliations RESTRICT;
DROP TABLE fwios.portfolio_source_positions RESTRICT;
DROP TABLE fwios.portfolio_transaction_reconciliations RESTRICT;
DROP TABLE fwios.portfolio_theme_registry RESTRICT;
DROP TABLE fwios.candidate_portfolio_fit_snapshots RESTRICT;
DROP TABLE fwios.candidate_portfolio_scenario_reviews_v2 RESTRICT;
DROP TABLE fwios.portfolio_fit_policies RESTRICT;
