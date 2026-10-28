-- Phase 1 Production Acceptance Regression / 2026-10-28 closure checkpoint.
-- SELECT ONLY. Does not promote BUY, refresh valuations, mutate portfolio or run cron.
WITH
valuation AS (
 SELECT v.ticker,v.run_id,v.model_version_id,m.status,m.regression_status
 FROM fwios.valuation_runs v JOIN fwios.valuation_model_versions m ON m.version_id=v.model_version_id
 WHERE v.run_id IN (
  SELECT valuation_run_id FROM fwios.v_research_readiness_current_v1
  WHERE ticker IN ('ACN','ADBE','PINS')
 )
), checks(name,pass) AS (
 SELECT '01_scanner_universe_64',(SELECT COUNT(*)=64 FROM fwios.v_scanner_current_v1)
 UNION ALL SELECT '02_valued_28',(SELECT COUNT(*)=28 FROM fwios.v_dashboard_valuation_map)
 UNION ALL SELECT '03_adbe_retired_version',(SELECT status='RETIRED' FROM valuation WHERE ticker='ADBE')
 UNION ALL SELECT '04_adbe_not_in_valuation_map',(SELECT COUNT(*)=0 FROM fwios.v_dashboard_valuation_map WHERE ticker='ADBE')
 UNION ALL SELECT '05_adbe_price_only_no_fair_value',(SELECT probability_weighted_fv IS NULL AND scanner_score IS NULL AND scan_status='PRICE_ONLY' AND valuation_status='NO VALUATION' FROM fwios.v_scanner_current_v1 WHERE ticker='ADBE')
 UNION ALL SELECT '06_acn_valid_model_24071',(SELECT status='PRODUCTION' AND regression_status='PASS' AND EXISTS(SELECT 1 FROM fwios.v_dashboard_valuation_map d WHERE d.ticker='ACN' AND d.valuation_run_id=v.run_id AND ABS(d.fair_value-240.7142520975)<0.0000001) FROM valuation v WHERE v.ticker='ACN')
 UNION ALL SELECT '07_pins_valid_model_4400',(SELECT status='PRODUCTION' AND regression_status='PASS' AND EXISTS(SELECT 1 FROM fwios.v_dashboard_valuation_map d WHERE d.ticker='PINS' AND d.valuation_run_id=v.run_id AND ABS(d.fair_value-44.0023427075)<0.0000001) FROM valuation v WHERE v.ticker='PINS')
 UNION ALL SELECT '08_acn_quality_review',(SELECT overall_gate='REVIEW' FROM fwios.v_candidate_quality_hardening_current WHERE ticker='ACN')
 UNION ALL SELECT '09_pins_quality_review',(SELECT overall_gate='REVIEW' FROM fwios.v_candidate_quality_hardening_current WHERE ticker='PINS')
 UNION ALL SELECT '10_no_acn_pins_auto_buy',(SELECT COUNT(*)=0 FROM fwios.v_opportunity_quality_current WHERE ticker IN ('ACN','PINS') AND final_buy_review_gate='PASS - READY FOR HUMAN REVIEW')
 UNION ALL SELECT '11_broken_opportunity_cron_quarantined',(SELECT active=false FROM cron.job WHERE jobid=10 AND jobname='fwios-opportunity-quality-refresh')
 UNION ALL SELECT '12_view_security_invoker_preserved',(SELECT reloptions @> ARRAY['security_invoker=true']::text[] FROM pg_class WHERE oid='fwios.v_dashboard_valuation_map'::regclass)
)
SELECT name,CASE WHEN pass IS TRUE THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks ORDER BY name;