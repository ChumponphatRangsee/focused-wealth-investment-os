-- PR7 native Google Sheet shadow sync scheduler.
-- Enabled after Google Sheets service-account credential installation,
-- target spreadsheet sharing, and successful native write/read-back E2E.
-- Schedule: 00:10 UTC = 07:10 Asia/Bangkok.

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname='fwios-portfolio-sheet-shadow-sync-native'
  limit 1;

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  v_job_id := cron.schedule(
    'fwios-portfolio-sheet-shadow-sync-native',
    '10 0 * * *',
    $cron$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name='fwios_project_url' limit 1)
        || '/functions/v1/portfolio-sheet-shadow-sync-v1',
      headers := jsonb_build_object(
        'Content-Type','application/json',
        'x-fwios-automation-token',
          (select decrypted_secret from vault.decrypted_secrets where name='fwios_automation_token' limit 1)
      ),
      body := jsonb_build_object(
        'source','CRON_NATIVE_SHEET_SHADOW_SYNC',
        'dry_run',false,
        'requested_at',now()
      ),
      timeout_milliseconds := 30000
    );
    $cron$
  );

  perform cron.alter_job(v_job_id, active => true);
end $$;
