-- Price service Cron display-name correction; no price/portfolio data mutation.
-- Supabase pg_cron job names are immutable: schedule a replacement and unschedule
-- the previous name atomically, preserving the historical cron.job_run_details.
DO $rename_crypto$
DECLARE
  v_old cron.job%ROWTYPE;
  v_new_id bigint;
  v_unscheduled boolean;
  v_receipts_before bigint;
BEGIN
  PERFORM pg_advisory_xact_lock(20261109, 14);
  SELECT * INTO v_old FROM cron.job WHERE jobid=14;
  SELECT count(*) INTO v_receipts_before FROM cron.job_run_details WHERE jobid=14;
  IF v_old.jobid IS NULL
    OR v_old.jobname <> 'fwios-portfolio-crypto-daily-snapshot'
    OR v_old.active IS DISTINCT FROM true
    OR v_old.schedule <> '10 21,22 * * *'
    OR v_old.username <> current_user
    OR v_old.database <> current_database()
    OR v_old.command NOT LIKE '%price-market-refresh-v1%'
    OR v_old.command NOT LIKE '%''mode'',''CRYPTO''%'
    OR (SELECT count(*) FROM cron.job) <> 6
    OR EXISTS (SELECT 1 FROM cron.job WHERE jobname='fwios-crypto-price-daily-refresh')
    OR v_receipts_before < 1
  THEN
    RAISE EXCEPTION 'CRYPTO_PRICE_CRON_RENAME_PREFLIGHT_FAILED';
  END IF;

  v_new_id := cron.schedule(
    'fwios-crypto-price-daily-refresh', v_old.schedule, v_old.command
  );
  IF v_new_id IS NULL OR v_new_id=14 THEN
    RAISE EXCEPTION 'CRYPTO_PRICE_CRON_RENAME_CREATION_FAILED';
  END IF;

  SELECT cron.unschedule('fwios-portfolio-crypto-daily-snapshot')
    INTO v_unscheduled;
  IF v_unscheduled IS DISTINCT FROM true
    OR EXISTS (SELECT 1 FROM cron.job WHERE jobid=14
                OR jobname='fwios-portfolio-crypto-daily-snapshot')
    OR (SELECT count(*) FROM cron.job WHERE jobid=v_new_id
                AND jobname='fwios-crypto-price-daily-refresh'
                AND active=true AND schedule=v_old.schedule
                AND command=v_old.command AND username=v_old.username
                AND database=v_old.database) <> 1
    OR (SELECT count(*) FROM cron.job WHERE active
                AND command LIKE '%''mode'',''CRYPTO''%') <> 1
    OR (SELECT count(*) FROM cron.job) <> 6
    OR (SELECT count(*) FROM cron.job_run_details WHERE jobid=14) <>
       v_receipts_before
  THEN
    RAISE EXCEPTION 'CRYPTO_PRICE_CRON_RENAME_POSTFLIGHT_FAILED';
  END IF;
END $rename_crypto$;
