-- PR7 Phase-1: make canonical US stock EOD available before the
-- 07:00 Asia/Bangkok portfolio stock sync.
--
-- pg_cron runs in UTC in this project.
-- 22:05 UTC Mon-Fri = 05:05 Asia/Bangkok Tue-Sat.
-- It is 17:05 ET (EST) or 18:05 ET (EDT), safely after the 16:00 ET
-- US regular-session close while leaving >1h before 07:00 Bangkok.
--
-- The enqueue command intentionally uses the SAME New York calendar date at
-- 22:05 UTC. Do not use decision_refresh_target_session_v1() here because
-- that helper returns the prior NY date and was designed for the old
-- next-day ingestion window.
--
-- Stock portfolio sync moves to Tue-Sat in UTC/Bangkok day terms so Friday
-- US closes are consumed on Saturday 07:00 Asia/Bangkok.
--
-- This migration does not touch Price Data, Transactions, Holdings,
-- Cost Basis, P&L, or any trade/accounting records.

do $migration$
declare
  v_enqueue_job bigint;
  v_worker_job bigint;
  v_stock_sync_job bigint;
begin
  select jobid into v_enqueue_job
  from cron.job
  where jobname = 'fwios-market-daily-close-enqueue';

  select jobid into v_worker_job
  from cron.job
  where jobname = 'fwios-market-daily-close-worker';

  select jobid into v_stock_sync_job
  from cron.job
  where jobname = 'fwios-portfolio-stock-post-close-sync';

  if v_enqueue_job is null or v_worker_job is null or v_stock_sync_job is null then
    raise exception 'PR7 timing migration blocked: required FWIOS cron job missing';
  end if;

  perform cron.alter_job(
    job_id := v_enqueue_job,
    schedule := '5 22 * * 1-5',
    command := 'select fwios.start_market_daily_close_run_v1((now() at time zone ''America/New_York'')::date,''CRON_EOD_DAILY_CLOSE'');'
  );

  perform cron.alter_job(
    job_id := v_worker_job,
    schedule := '*/2 22-23 * * 1-5'
  );

  perform cron.alter_job(
    job_id := v_stock_sync_job,
    schedule := '0 0 * * 2-6'
  );
end
$migration$;
