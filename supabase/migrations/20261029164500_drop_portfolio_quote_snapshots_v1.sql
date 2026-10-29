-- Remove redundant THB portfolio quote snapshot projection after independent native USD price cutover.
-- User expressly requested DROP; no CASCADE. Source market_observations and prices remain untouched.
DO $pre$
BEGIN
 IF (SELECT count(*) FROM cron.job WHERE active AND command LIKE '%portfolio-mtm-refresh-v1%')<>0 THEN
   RAISE EXCEPTION 'LEGACY_MTM_STILL_ENABLED'; END IF;
 IF (SELECT count(*) FROM fwios.portfolio_market_quote_snapshots)<>15044 THEN
   RAISE EXCEPTION 'PORTFOLIO_QUOTES_COUNT_DRIFT'; END IF;
END $pre$;
DROP VIEW fwios.v_dashboard_alerts RESTRICT;
DROP VIEW fwios.v_dashboard_system_health RESTRICT;
DROP VIEW fwios.v_new_cash_allocation_current_context RESTRICT;
DROP VIEW fwios.v_holding_valuation_coverage_current RESTRICT;
DROP VIEW fwios.v_dashboard_account_summary RESTRICT;
DROP VIEW fwios.v_portfolio_guardrails_current RESTRICT;
DROP VIEW fwios.v_portfolio_exposure_current RESTRICT;
DROP VIEW fwios.v_dashboard_holdings RESTRICT;
DROP VIEW fwios.v_portfolio_positions_marked_current RESTRICT;
DROP VIEW fwios.v_portfolio_market_price_health RESTRICT;
DROP VIEW fwios.v_portfolio_market_quotes_observation_compat RESTRICT;
DROP VIEW fwios.v_portfolio_market_quote_current RESTRICT;
DROP FUNCTION IF EXISTS fwios.sync_portfolio_market_quote_observation_v1() RESTRICT;
DROP TABLE fwios.portfolio_market_quote_snapshots RESTRICT;
