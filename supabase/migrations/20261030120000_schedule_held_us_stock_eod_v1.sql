-- US equity EOD price-only extension. NO scanner, MTM, transaction or decision writes.
-- Alpha Vantage TIME_SERIES_DAILY / raw regular close / held tickers only.
-- Do not schedule until both price-only Edge workers are deployed and EOD dry-run passes.
SET LOCAL lock_timeout='5s';
DO $$
BEGIN
 IF (SELECT count(*) FROM pg_class WHERE relnamespace='fwios'::regnamespace AND relkind='r')<>5
  OR (SELECT count(*) FROM pg_proc WHERE pronamespace='fwios'::regnamespace)<>6
  THEN RAISE EXCEPTION 'PRICE_CORE_SCHEMA_DRIFT'; END IF;
 IF EXISTS(SELECT 1 FROM cron.job WHERE jobname IN(
  'fwios-us-stock-eod-close-v1','fwios-us-stock-eod-sheet-followup-v1'))
  THEN RAISE EXCEPTION 'STOCK_EOD_CRON_ALREADY_EXISTS'; END IF;
 IF NOT EXISTS(SELECT 1 FROM vault.secrets WHERE name='ALPHA_VANTAGE_API_KEY')
  THEN RAISE EXCEPTION 'ALPHA_VANTAGE_KEY_NOT_PRESENT'; END IF;
 IF (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job)<>ARRAY[14,15,16]::bigint[]
  THEN RAISE EXCEPTION 'EXISTING_PRICE_CRON_UNEXPECTED'; END IF;
END $$;

-- 19:00 America/New_York = 23:00 or 00:00 UTC depending on DST.
-- Postgres timezone guard ensures EXACTLY one daily dispatch, weekdays only.
SELECT cron.schedule(
 'fwios-us-stock-eod-close-v1',
 '0 0,23 * * *',
 $job$
 SELECT net.http_post(
  url:=(SELECT decrypted_secret FROM vault.decrypted_secrets
        WHERE name='fwios_project_url' LIMIT 1)||'/functions/v1/price-market-refresh-v1',
  headers:=jsonb_build_object('Content-Type','application/json',
   'x-fwios-automation-token',(SELECT decrypted_secret FROM vault.decrypted_secrets
       WHERE name='fwios_automation_token' LIMIT 1)),
  body:=jsonb_build_object('mode','US_STOCK_EOD','dry_run',false,
      'source','CRON_PRICE_ONLY_US_STOCK_EOD','requested_at',now()),
  timeout_milliseconds:=90000
 )
 WHERE to_char(now() AT TIME ZONE 'America/New_York','HH24:MI')='19:00'
   AND extract(isodow FROM now() AT TIME ZONE 'America/New_York') BETWEEN 1 AND 5;
 $job$
);

-- 19:30 America/New_York: follow up after stock prices have been collected.
-- Existing 17:20 crypto+FX Sheet Sync (#16) remains unchanged.
SELECT cron.schedule(
 'fwios-us-stock-eod-sheet-followup-v1',
 '30 0,23 * * *',
 $job$
 SELECT net.http_post(
  url:=(SELECT decrypted_secret FROM vault.decrypted_secrets
        WHERE name='fwios_project_url' LIMIT 1)||'/functions/v1/price-sheet-sync-v1',
  headers:=jsonb_build_object('Content-Type','application/json',
   'x-fwios-automation-token',(SELECT decrypted_secret FROM vault.decrypted_secrets
       WHERE name='fwios_automation_token' LIMIT 1)),
  body:=jsonb_build_object('dry_run',false,'source','CRON_PRICE_ONLY_STOCK_EOD_SHEET',
      'requested_at',now()),
  timeout_milliseconds:=90000
 )
 WHERE to_char(now() AT TIME ZONE 'America/New_York','HH24:MI')='19:30'
   AND extract(isodow FROM now() AT TIME ZONE 'America/New_York') BETWEEN 1 AND 5;
 $job$
);
