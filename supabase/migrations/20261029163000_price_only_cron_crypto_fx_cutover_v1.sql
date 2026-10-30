-- LIVE price-only schedule cutover, after both modes and Google Sheet E2E passed.
DO $cutover$
BEGIN
 IF (SELECT count(*) FROM cron.job
    WHERE jobid IN (14,15) AND active
      AND command LIKE '%/functions/v1/portfolio-mtm-refresh-v1%'
      AND ((jobid=14 AND jobname='fwios-portfolio-crypto-daily-snapshot')
        OR (jobid=15 AND jobname='fwios-portfolio-stock-post-close-sync'))) <> 2
 THEN RAISE EXCEPTION 'PRICE_ONLY_CRON_CUTOVER_PREFLIGHT_FAILED'; END IF;
 PERFORM cron.alter_job(job_id=>14,command=>$crypto$
   SELECT net.http_post(
    url:=(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='fwios_project_url' LIMIT 1)||'/functions/v1/price-market-refresh-v1',
    headers:=jsonb_build_object('Content-Type','application/json',
       'x-fwios-automation-token',(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='fwios_automation_token' LIMIT 1)),
    body:=jsonb_build_object('mode','CRYPTO','dry_run',false,'source','CRON_PRICE_ONLY_CRYPTO','requested_at',now()),
    timeout_milliseconds:=28000)
   WHERE to_char(now() AT TIME ZONE 'America/New_York','HH24:MI')='17:10';
 $crypto$);
 PERFORM cron.alter_job(job_id=>15,command=>$fx$
   SELECT net.http_post(
    url:=(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='fwios_project_url' LIMIT 1)||'/functions/v1/price-market-refresh-v1',
    headers:=jsonb_build_object('Content-Type','application/json',
       'x-fwios-automation-token',(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='fwios_automation_token' LIMIT 1)),
    body:=jsonb_build_object('mode','FX','dry_run',false,'source','CRON_PRICE_ONLY_FX','requested_at',now()),
    timeout_milliseconds:=28000)
   WHERE to_char(now() AT TIME ZONE 'America/New_York','HH24:MI')='17:10';
 $fx$);
END $cutover$;
