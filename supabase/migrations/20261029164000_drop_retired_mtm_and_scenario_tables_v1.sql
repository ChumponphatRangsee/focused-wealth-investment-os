-- SAFE price-only removal after Cron #14/#15 rerouted and legacy MTM worker tombstoned.
-- Destructive, user expressly authorized. No CASCADE, preserve market observations and Google Sheets.
DO $pre$
BEGIN
 IF (SELECT count(*) FROM cron.job WHERE active AND command LIKE '%/functions/v1/portfolio-mtm-refresh-v1%')>0 THEN
  RAISE EXCEPTION 'STOP:LEGACY_MTM_STILL_SCHEDULED';
 END IF;
 IF (SELECT count(*) FROM fwios.portfolio_mtm_runs)<>2248 THEN
  RAISE EXCEPTION 'STOP:MTM_HISTORY_COUNT_DRIFT';
 END IF;
 IF (SELECT count(*) FROM fwios.portfolio_scenario_runs)<>0 OR
    (SELECT count(*) FROM fwios.portfolio_scenario_actions)<>0 OR
    (SELECT count(*) FROM fwios.portfolio_scenario_metrics)<>0 OR
    (SELECT count(*) FROM fwios.portfolio_scenario_positions)<>0 THEN
  RAISE EXCEPTION 'STOP:PORTFOLIO_SCENARIOS_NONEMPTY';
 END IF;
END $pre$;
DROP TABLE fwios.portfolio_mtm_runs RESTRICT;
DROP TABLE fwios.portfolio_scenario_actions RESTRICT;
DROP TABLE fwios.portfolio_scenario_metrics RESTRICT;
DROP TABLE fwios.portfolio_scenario_positions RESTRICT;
DROP TABLE fwios.portfolio_scenario_runs RESTRICT;
