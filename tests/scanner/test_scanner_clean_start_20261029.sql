-- 2026-10-29 scanner clean-start one-time post-reset acceptance (READ ONLY).
-- Strict initial values intentionally fail once new stocks are legitimately discovered/enrolled.
WITH checks(check_id,ok) AS (
 SELECT '01_ZERO_SCANNER_STOCKS'::text,(SELECT COUNT(*)=0 FROM fwios.v_scanner_current_v1)
 UNION ALL SELECT '02_ZERO_ACTIVE_THESES',(SELECT COUNT(*)=0 FROM fwios.thesis_registry WHERE active)
 UNION ALL SELECT '03_ARCHIVED_63_THESES_RETAINED',(SELECT COUNT(*)=63 FROM fwios.thesis_registry)
 UNION ALL SELECT '04_ALL_ARCHIVED_THESES_TAGGED',(SELECT count(*)=63 FROM fwios.thesis_registry WHERE metadata->>'archived_by_scanner_reset'='SCAN-RESET-20261029')
 UNION ALL SELECT '05_EMPTY_FRESH_DISCOVERY_UNIVERSE',(SELECT COUNT(*)=0 FROM fwios.scanner_discovery_enrollments_v1)
 UNION ALL SELECT '06_RESET_RECEIPT_PRESERVED',(SELECT COUNT(*)=1 FROM fwios.scanner_reset_batches_v1 WHERE reset_id='SCAN-RESET-20261029' AND archived_thesis_count=63 AND prior_scanner_count=64 AND reset_mode='NON_DESTRUCTIVE_ARCHIVE')
 UNION ALL SELECT '07_OLD_RESEARCH_HISTORY_PRESERVED',(SELECT COUNT(*)=27 FROM fwios.research_candidates)
 UNION ALL SELECT '08_PORTFOLIO_TRANSACTIONS_UNCHANGED',(SELECT COUNT(*)=58 FROM fwios.portfolio_transactions)
 UNION ALL SELECT '09_MARKET_EOD_UNCHANGED',(SELECT COUNT(*)=64 FROM fwios.market_daily_closes WHERE session_date=DATE '2026-10-28')
 UNION ALL SELECT '10_STOCK_IDENTITY_PRESERVED',(SELECT COUNT(*)=64 FROM fwios.instruments WHERE asset_class='Stock' AND lifecycle_status='ACTIVE')
 UNION ALL SELECT '11_TTWO_RESEARCH_SCHEDULER_CANNOT_AUTO_REACTIVATE',
   (SELECT COUNT(*)=1 FROM fwios.thesis_registry WHERE ticker='TTWO' AND active=false)
 UNION ALL SELECT '12_MARKET_EOD_ENQUEUE_REMAINS_ACTIVE',(SELECT active FROM cron.job WHERE jobid=6 AND jobname='fwios-market-daily-close-enqueue')
 UNION ALL SELECT '13_MARKET_EOD_WORKER_REMAINS_ACTIVE',(SELECT active FROM cron.job WHERE jobid=7 AND jobname='fwios-market-daily-close-worker')
 UNION ALL SELECT '14_LEGACY_SHADOW_REFRESH_WORKER_PAUSED',(SELECT NOT active FROM cron.job WHERE jobid=2 AND jobname='fwios-shadow-decision-refresh-worker')
 UNION ALL SELECT '15_LEGACY_SHADOW_REFRESH_ENQUEUE_PAUSED',(SELECT NOT active FROM cron.job WHERE jobid=8 AND jobname='fwios-shadow-decision-refresh-enqueue')
 UNION ALL SELECT '16_LEGACY_THESIS_HEALTH_PAUSED',(SELECT NOT active FROM cron.job WHERE jobid=9 AND jobname='fwios-thesis-health-refresh')
 UNION ALL SELECT '17_PORTFOLIO_MARKET_SYNC_REMAINS_ACTIVE',(SELECT active FROM cron.job WHERE jobid=15 AND jobname='fwios-portfolio-stock-post-close-sync')
 UNION ALL SELECT '18_ENROLLMENT_TABLE_RLS_ENABLED',(SELECT relrowsecurity FROM pg_class WHERE oid='fwios.scanner_discovery_enrollments_v1'::regclass)
 UNION ALL SELECT '19_ENROLLMENT_NOT_PUBLICLY_WRITABLE',(SELECT NOT has_table_privilege('anon','fwios.scanner_discovery_enrollments_v1','INSERT') AND NOT has_table_privilege('authenticated','fwios.scanner_discovery_enrollments_v1','INSERT'))
)
SELECT check_id,CASE WHEN ok IS TRUE THEN 'PASS' ELSE 'FAIL' END result FROM checks ORDER BY check_id;