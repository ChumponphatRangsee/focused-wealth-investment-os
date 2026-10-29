-- Applied to live Supabase ysjbmeukwbfnxnwqchuq on 2026-10-29.
-- Disable stock ingestion schedules only; retain 1,590 historical daily-close rows.
-- Do not rerun against a database where this migration is already recorded.
DO $guard$
BEGIN
  IF (SELECT count(*) FROM cron.job WHERE active AND
      (jobid=6 AND jobname='fwios-market-daily-close-enqueue'
       OR jobid=7 AND jobname='fwios-market-daily-close-worker')) <> 2 THEN
    RAISE EXCEPTION 'Stock EOD cron precondition mismatch; no changes made';
  END IF;
END $guard$;
SELECT cron.alter_job(job_id := 6, active := false);
SELECT cron.alter_job(job_id := 7, active := false);
