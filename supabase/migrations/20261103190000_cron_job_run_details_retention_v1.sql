-- Operational retention for managed pg_cron run receipts.
-- Keep 30 days of completed run history; preserve active/incomplete runs because end_time is NULL.
-- Existing production Cron jobs 14-18 must remain byte-for-byte unchanged.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';

CREATE TEMP TABLE _cron_jobs_before ON COMMIT DROP AS
SELECT jobid, schedule, command, nodename, nodeport, database, username, active, jobname
FROM cron.job
WHERE jobid IN (14,15,16,17,18);

CREATE TEMP TABLE _cron_run_details_before ON COMMIT DROP AS
SELECT count(*)::bigint AS row_count
FROM cron.job_run_details;

DO $preflight$
BEGIN
  IF to_regclass('cron.job_run_details') IS NULL
     OR to_regclass('cron.job') IS NULL
  THEN
    RAISE EXCEPTION 'CRON_RETENTION_REQUIRED_OBJECT_MISSING';
  END IF;

  IF (SELECT count(*) FROM cron.job WHERE active) <> 5
     OR (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job WHERE active)
        <> ARRAY[14,15,16,17,18]::bigint[]
     OR (SELECT count(*) FROM _cron_jobs_before) <> 5
  THEN
    RAISE EXCEPTION 'CRON_RETENTION_ACTIVE_JOB_DRIFT';
  END IF;

  IF EXISTS (
    SELECT 1 FROM cron.job
    WHERE jobname='fwios-cron-run-details-retention-v1'
  ) THEN
    RAISE EXCEPTION 'CRON_RETENTION_JOB_ALREADY_EXISTS';
  END IF;

  IF NOT has_table_privilege(current_user, 'cron.job_run_details', 'DELETE')
  THEN
    RAISE EXCEPTION 'CRON_RETENTION_DELETE_PRIVILEGE_MISSING';
  END IF;

  IF coalesce(current_setting('cron.timezone', true),'') <> 'GMT'
  THEN
    RAISE EXCEPTION 'CRON_RETENTION_TIMEZONE_DRIFT';
  END IF;
END $preflight$;

-- Supabase/pg_cron does not prune this managed run-history table automatically.
-- Run at 03:15 GMT daily, away from the current FWIOS price-service windows.
SELECT cron.schedule(
  'fwios-cron-run-details-retention-v1',
  '15 3 * * *',
  $cron$
    DELETE FROM cron.job_run_details
    WHERE end_time < now() - interval '30 days';
  $cron$
);

DO $postflight$
BEGIN
  IF EXISTS (
    (SELECT jobid, schedule, command, nodename, nodeport, database, username, active, jobname
       FROM _cron_jobs_before
     EXCEPT
     SELECT jobid, schedule, command, nodename, nodeport, database, username, active, jobname
       FROM cron.job
      WHERE jobid IN (14,15,16,17,18))
    UNION ALL
    (SELECT jobid, schedule, command, nodename, nodeport, database, username, active, jobname
       FROM cron.job
      WHERE jobid IN (14,15,16,17,18)
     EXCEPT
     SELECT jobid, schedule, command, nodename, nodeport, database, username, active, jobname
       FROM _cron_jobs_before)
  ) THEN
    RAISE EXCEPTION 'CRON_RETENTION_EXISTING_JOBS_CHANGED';
  END IF;

  IF (SELECT count(*) FROM cron.job WHERE active) <> 6
     OR (SELECT count(*) FROM cron.job
         WHERE jobname='fwios-cron-run-details-retention-v1'
           AND active
           AND schedule='15 3 * * *'
           AND command LIKE '%DELETE FROM cron.job_run_details%'
           AND command LIKE '%interval ''30 days''%') <> 1
  THEN
    RAISE EXCEPTION 'CRON_RETENTION_SCHEDULE_FAILED';
  END IF;

  IF (SELECT row_count FROM _cron_run_details_before)
     <> (SELECT count(*) FROM cron.job_run_details)
  THEN
    RAISE EXCEPTION 'CRON_RETENTION_MIGRATION_DELETED_HISTORY';
  END IF;
END $postflight$;

COMMIT;
