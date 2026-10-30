-- Already applied to live project ysjbmeukwbfnxnwqchuq on 2026-10-29.
-- Keep historical provider validation and quota records; stop obsolete recurring validation.
-- Do not reapply if this migration is already recorded.
DO $guard$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobid=5 AND jobname='fwios-provider-validator-v1' AND active
   AND command LIKE '%/functions/v1/decision-refresh-provider-validator-v1%') THEN
   RAISE EXCEPTION 'Legacy provider validator cron precondition mismatch';
 END IF;
END $guard$;
SELECT cron.alter_job(job_id := 5, active := false);
