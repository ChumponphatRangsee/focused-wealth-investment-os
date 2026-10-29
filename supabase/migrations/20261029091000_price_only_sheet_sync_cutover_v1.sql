DO $price_cutover$
DECLARE v_name text;v_cmd text;v_active boolean;
BEGIN
 SELECT jobname,command,active INTO v_name,v_cmd,v_active FROM cron.job WHERE jobid=16;
 IF v_name IS DISTINCT FROM 'fwios-portfolio-sheet-shadow-sync-native' OR v_active IS DISTINCT FROM true OR v_cmd NOT LIKE '%portfolio-sheet-shadow-sync-v1%' THEN
  RAISE EXCEPTION 'PRICE_SHEET_CUTOVER_REFUSED_UNEXPECTED_CRON_STATE';
 END IF;
 PERFORM cron.alter_job(job_id=>16,command=>$command$
 select net.http_post(
  url := (select decrypted_secret from vault.decrypted_secrets where name='fwios_project_url' limit 1) || '/functions/v1/price-sheet-sync-v1',
  headers := jsonb_build_object(
   'Content-Type','application/json',
   'x-fwios-automation-token',(select decrypted_secret from vault.decrypted_secrets where name='fwios_automation_token' limit 1)
  ),
  body := jsonb_build_object('source','CRON_PRICE_ONLY_SHEET_SYNC','dry_run',false,'requested_at',now()),
  timeout_milliseconds := 28000
 )
 where to_char(now() at time zone 'America/New_York','HH24:MI')='17:20';
$command$);
END $price_cutover$;