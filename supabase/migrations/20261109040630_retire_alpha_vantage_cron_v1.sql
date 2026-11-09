
-- FWIOS alpha retirement phase A: schedule-only cutover, no provider invocation.
-- Preserve job identity, Vault credentials, provider observations and quota history.
DO $retire$
DECLARE
  j17 cron.job%ROWTYPE;
  j18 cron.job%ROWTYPE;
BEGIN
  SELECT * INTO j17 FROM cron.job WHERE jobid=17;
  SELECT * INTO j18 FROM cron.job WHERE jobid=18;
  IF j17.jobid IS NULL OR j18.jobid IS NULL
    OR j17.jobname<>'fwios-us-stock-eod-close-v1'
    OR j18.jobname<>'fwios-us-stock-eod-sheet-followup-v1'
    OR j17.active IS DISTINCT FROM true OR j18.active IS DISTINCT FROM true
    OR j17.schedule<>'0,55 0,5,6,23 * * *'
    OR j18.schedule<>'10,30 0,6,7,23 * * *'
    OR position('US_STOCK_EOD' IN j17.command)=0
    OR position('TWELVE_STOCK_EOD_FALLBACK' IN j17.command)=0
    OR (SELECT count(*) FROM vault.secrets WHERE name='TWELVE_DATA_API_KEY')<>1
  THEN
    RAISE EXCEPTION 'ALPHA_RETIREMENT_CRON_PREFLIGHT_FAILED';
  END IF;

  -- NY 01:55 occurs at 05:55 UTC in EDT and 06:55 UTC in EST.
  PERFORM cron.alter_job(
    job_id=>17,
    schedule=>'55 5,6 * * *',
    command=>$worker$
 SELECT net.http_post(
  url:=(SELECT decrypted_secret FROM vault.decrypted_secrets
        WHERE name='fwios_project_url' LIMIT 1)||'/functions/v1/price-market-refresh-v1',
  headers:=jsonb_build_object('Content-Type','application/json',
   'x-fwios-automation-token',(SELECT decrypted_secret FROM vault.decrypted_secrets
       WHERE name='fwios_automation_token' LIMIT 1)),
  body:=jsonb_build_object('mode','TWELVE_STOCK_EOD_FALLBACK','dry_run',false,
      'source','CRON_TWELVE_ONLY_STOCK_EOD','requested_at',now()),
  timeout_milliseconds:=90000
 )
 WHERE to_char(now() AT TIME ZONE 'America/New_York','HH24:MI')='01:55'
   AND extract(isodow FROM now() AT TIME ZONE 'America/New_York') BETWEEN 1 AND 5;
$worker$
  );

  -- NY 02:10 follow-up occurs at 06:10 UTC in EDT and 07:10 UTC in EST.
  PERFORM cron.alter_job(
    job_id=>18,
    schedule=>'10 6,7 * * *',
    command=>$sheet$
 SELECT net.http_post(
  url:=(SELECT decrypted_secret FROM vault.decrypted_secrets
        WHERE name='fwios_project_url' LIMIT 1)||'/functions/v1/price-sheet-sync-v1',
  headers:=jsonb_build_object('Content-Type','application/json',
   'x-fwios-automation-token',(SELECT decrypted_secret FROM vault.decrypted_secrets
       WHERE name='fwios_automation_token' LIMIT 1)),
  body:=jsonb_build_object('dry_run',false,'source','CRON_TWELVE_ONLY_STOCK_EOD_SHEET',
      'requested_at',now()),
  timeout_milliseconds:=90000
 )
 WHERE to_char(now() AT TIME ZONE 'America/New_York','HH24:MI')='02:10'
   AND extract(isodow FROM now() AT TIME ZONE 'America/New_York') BETWEEN 1 AND 5;
$sheet$
  );
  IF (SELECT count(*) FROM cron.job WHERE jobid IN (17,18) AND active
      AND ((jobid=17 AND schedule='55 5,6 * * *'
             AND command LIKE '%TWELVE_STOCK_EOD_FALLBACK%'
             AND command NOT LIKE '%US_STOCK_EOD%')
        OR (jobid=18 AND schedule='10 6,7 * * *')))<>2
  THEN
    RAISE EXCEPTION 'ALPHA_RETIREMENT_CRON_POSTFLIGHT_FAILED';
  END IF;
END $retire$;
