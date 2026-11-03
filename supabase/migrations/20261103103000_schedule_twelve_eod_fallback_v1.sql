-- Activate only after live Twelve Data EOD no-write test and database quota tests.
-- Retain existing Cron IDs 17 and 18; DST guards use New York wall-clock time.
BEGIN;
SET LOCAL lock_timeout='5s';
DO $$
BEGIN
 IF (SELECT count(*) FROM cron.job WHERE jobid IN (17,18) AND active)=2
    AND (SELECT count(*) FROM cron.job WHERE jobid IN (17,18))=2
    AND EXISTS (SELECT 1 FROM cron.job WHERE jobid=17 AND command LIKE '%''mode'',''US_STOCK_EOD''%')
    AND EXISTS (SELECT 1 FROM cron.job WHERE jobid=18 AND command LIKE '%19:30%')
    AND to_regclass('fwios_quota.api_call_ledger') IS NOT NULL
 THEN NULL;
 ELSE RAISE EXCEPTION 'FALLBACK_CRON_PRECONDITIONS_FAILED'; END IF;
END $$;

SELECT cron.alter_job(
 job_id=>17,
 schedule=>'0,55 0,5,6,23 * * *',
 command=>replace(
   replace(command,
      '''mode'',''US_STOCK_EOD''',
      '''mode'',CASE WHEN to_char(now() AT TIME ZONE ''America/New_York'',''HH24:MI'')=''01:55'' THEN ''TWELVE_STOCK_EOD_FALLBACK'' ELSE ''US_STOCK_EOD'' END'),
   '''HH24:MI'')=''19:00''',
   '''HH24:MI'') IN (''19:00'',''01:55'')')
)
FROM cron.job WHERE jobid=17;

SELECT cron.alter_job(
 job_id=>18,
 schedule=>'10,30 0,6,7,23 * * *',
 command=>replace(command,
   '''HH24:MI'')=''19:30''',
   '''HH24:MI'') IN (''19:30'',''02:10'')')
)
FROM cron.job WHERE jobid=18;
COMMIT;
