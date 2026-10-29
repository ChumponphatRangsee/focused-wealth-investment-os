-- Asset Price Data Service v1.0.0: remove 38 obsolete read models and 9 CONFIRMED EMPTY legacy tables.
-- Historical market prices and 58 portfolio ledger rows explicitly preserved.
-- Live dependency audit on 2026-10-29; all operations RESTRICT, no CASCADE.
SET LOCAL lock_timeout = '5s';
DO $guard$
DECLARE v_n text; v_has boolean;
BEGIN
 IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='fwios' AND c.relkind IN ('v','m'))<>39 THEN RAISE EXCEPTION 'View count drift, abort'; END IF;
 IF to_regclass('fwios.market_observations') IS NULL OR to_regclass('fwios.v_instrument_identity_current') IS NULL OR to_regclass('fwios.portfolio_transactions') IS NULL THEN RAISE EXCEPTION 'Protected price/ledger object missing'; END IF;
 IF (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job WHERE active)<>ARRAY[14,15,16]::bigint[] THEN RAISE EXCEPTION 'Cron safety state drift'; END IF;
 FOREACH v_n IN ARRAY ARRAY['capital_allocation_actions','capital_allocation_metrics','capital_allocation_runs','human_approval_events','thesis_reactivation_events','thesis_reactivation_rules','market_refresh_flights_v1','scanner_discovery_enrollments_v1','system_events']::text[] LOOP
   EXECUTE format('SELECT EXISTS(SELECT 1 FROM fwios.%I LIMIT 1)',v_n) INTO v_has;
   IF v_has THEN RAISE EXCEPTION 'Expected-empty table has data: %',v_n; END IF;
 END LOOP;
END $guard$;
-- Drop dependent views before the views they depend on; preserve identity price lookup.
DROP VIEW fwios."v_api_usage_unified_v1" RESTRICT;
DROP VIEW fwios."v_candidate_chase_current" RESTRICT;
DROP VIEW fwios."v_candidate_decision_scores_current" RESTRICT;
DROP VIEW fwios."v_candidate_revision_current" RESTRICT;
DROP VIEW fwios."v_dashboard_current_action" RESTRICT;
DROP VIEW fwios."v_dashboard_opportunities" RESTRICT;
DROP VIEW fwios."v_decision_refresh_api_quota_today" RESTRICT;
DROP VIEW fwios."v_human_approval_current" RESTRICT;
DROP VIEW fwios."v_latest_decision_snapshots" RESTRICT;
DROP VIEW fwios."v_latest_portfolio_batch" RESTRICT;
DROP VIEW fwios."v_lineage_edges_resolved" RESTRICT;
DROP VIEW fwios."v_market_daily_closes_observation_compat" RESTRICT;
DROP VIEW fwios."v_market_price_quotes_observation_compat" RESTRICT;
DROP VIEW fwios."v_market_price_snapshots_observation_compat" RESTRICT;
DROP VIEW fwios."v_metric_observations_current" RESTRICT;
DROP VIEW fwios."v_model_debt_controller" RESTRICT;
DROP VIEW fwios."v_opportunity_quality_current" RESTRICT;
DROP VIEW fwios."v_opportunity_ranking_current" RESTRICT;
DROP VIEW fwios."v_portfolio_migration_controller" RESTRICT;
DROP VIEW fwios."v_research_pipeline_controller" RESTRICT;
DROP VIEW fwios."v_latest_reusable_evidence" RESTRICT;
DROP VIEW fwios."v_open_model_debt" RESTRICT;
DROP VIEW fwios."v_operating_controller" RESTRICT;
DROP VIEW fwios."v_decision_coverage" RESTRICT;
DROP VIEW fwios."v_research_readiness_current_v1" RESTRICT;
DROP VIEW fwios."v_candidate_quality_hardening_current" RESTRICT;
DROP VIEW fwios."v_scanner_current_v1" RESTRICT;
DROP VIEW fwios."v_thesis_condition_metric_links" RESTRICT;
DROP VIEW fwios."v_thesis_decision_memory_current" RESTRICT;
DROP VIEW fwios."v_thesis_memory_normalized_compat" RESTRICT;
DROP VIEW fwios."v_thesis_reactivation_latest" RESTRICT;
DROP VIEW fwios."v_thesis_tracking_current" RESTRICT;
DROP VIEW fwios."v_dashboard_valuation_map" RESTRICT;
DROP VIEW fwios."v_market_daily_close_latest" RESTRICT;
DROP VIEW fwios."v_thesis_sec_filing_current" RESTRICT;
DROP VIEW fwios."v_valuation_mispricing_current" RESTRICT;
DROP VIEW fwios."v_market_price_latest" RESTRICT;
DROP VIEW fwios."v_valuation_promotion_readiness_v1" RESTRICT;
-- Drop only tables proven empty. Parent tables follow their empty FK children.
DROP TABLE fwios."capital_allocation_actions" RESTRICT;
DROP TABLE fwios."capital_allocation_metrics" RESTRICT;
DROP TABLE fwios."capital_allocation_runs" RESTRICT;
DROP TABLE fwios."human_approval_events" RESTRICT;
DROP TABLE fwios."thesis_reactivation_events" RESTRICT;
DROP TABLE fwios."thesis_reactivation_rules" RESTRICT;
DROP TABLE fwios."market_refresh_flights_v1" RESTRICT;
DROP TABLE fwios."scanner_discovery_enrollments_v1" RESTRICT;
DROP TABLE fwios."system_events" RESTRICT;
DO $verify$
BEGIN
 IF to_regclass('fwios.v_instrument_identity_current') IS NULL THEN RAISE EXCEPTION 'Protected identity view lost'; END IF;
 IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='fwios' AND c.relkind IN ('v','m')) <> 1 THEN RAISE EXCEPTION 'Unexpected remaining view count'; END IF;
 IF (SELECT count(*) FROM fwios.portfolio_transactions)<>58 THEN RAISE EXCEPTION 'Portfolio ledger parity changed'; END IF;
END $verify$;
