-- Retire seven already inactive out-of-scope schedules; only three price-only jobs remain.
-- Each targeted job is asserted inactive, and the active schedule IDs must match the contract.
SET LOCAL lock_timeout='5s';
DO $guard$
BEGIN
 IF (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job WHERE active) <> ARRAY[14,15,16]::bigint[] THEN RAISE EXCEPTION 'Active price schedules drift'; END IF;
 IF (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job WHERE NOT active) <> ARRAY[2,5,6,7,8,9,10]::bigint[] THEN RAISE EXCEPTION 'Retired job IDs drift'; END IF;
END $guard$;
SELECT cron.unschedule(2);
SELECT cron.unschedule(5);
SELECT cron.unschedule(6);
SELECT cron.unschedule(7);
SELECT cron.unschedule(8);
SELECT cron.unschedule(9);
SELECT cron.unschedule(10);
DO $verify$
BEGIN
 IF (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job) <> ARRAY[14,15,16]::bigint[] THEN RAISE EXCEPTION 'Cron cleanup incomplete'; END IF;
END $verify$;