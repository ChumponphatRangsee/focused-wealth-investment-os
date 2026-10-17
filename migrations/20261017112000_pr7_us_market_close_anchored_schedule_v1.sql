-- PR7 Phase-1 policy: anchor portfolio market-data refresh to the US market close.
--
-- Do not rely on a fixed Asia/Bangkok wall clock. pg_cron runs in UTC, so each
-- user-facing job is scheduled in both possible UTC hours and guarded by the
-- America/New_York local wall clock. This makes DST transitions automatic.
--
-- US regular close = 16:00 America/New_York.
-- EOD enqueue       = 16:05 ET.
-- Stock + crypto    = 17:10 ET.
-- Native Sheet sync = 17:20 ET.
--
-- Typical Bangkok mapping:
--   EDT: 03:05 / 04:10 / 04:20 next day.
--   EST: 04:05 / 05:10 / 05:20 next day.
--
-- No Price Data, Transactions, Holdings, Cost Basis, P&L, cash, or trade
-- execution mutation is authorized by this migration.

do $migration$
declare
  v_enqueue_job bigint;
  v_worker_job bigint;
  v_stock_job bigint;
  v_crypto_job bigint;
  v_sheet_job bigint;
begin
  select jobid into v_enqueue_job from cron.job where jobname='fwios-market-daily-close-enqueue';
  select jobid into v_worker_job from cron.job where jobname='fwios-market-daily-close-worker';
  select jobid into v_stock_job from cron.job where jobname='fwios-portfolio-stock-post-close-sync';
  select jobid into v_crypto_job from cron.job where jobname='fwios-portfolio-crypto-daily-snapshot';
  select jobid into v_sheet_job from cron.job where jobname='fwios-portfolio-sheet-shadow-sync-native';

  if v_enqueue_job is null or v_worker_job is null or v_stock_job is null
     or v_crypto_job is null or v_sheet_job is null then
    raise exception 'PR7 US-close schedule migration blocked: required cron job missing';
  end if;

  perform cron.alter_job(
    job_id := v_enqueue_job,
    schedule := '5 20,21 * * 1-5',
    command := $cmd$
      select fwios.start_market_daily_close_run_v1(
        (now() at time zone 'America/New_York')::date,
        'CRON_US_MARKET_CLOSE_EOD'
      )
      where to_char(now() at time zone 'America/New_York','HH24:MI')='16:05'
        and extract(isodow from now() at time zone 'America/New_York') between 1 and 5
        and not exists (
          select 1
          from fwios.market_daily_close_runs
          where session_date=(now() at time zone 'America/New_York')::date
        );
    $cmd$
  );

  perform cron.alter_job(
    job_id := v_worker_job,
    schedule := '*/2 20-22 * * 1-5',
    command := $cmd$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name='fwios_project_url' limit 1)
          || '/functions/v1/market-daily-close-worker-v1',
        headers := jsonb_build_object(
          'Content-Type','application/json',
          'x-fwios-automation-token',
            (select decrypted_secret from vault.decrypted_secrets where name='fwios_automation_token' limit 1)
        ),
        body := jsonb_build_object('source','PG_CRON_US_MARKET_CLOSE','requested_at',now()),
        timeout_milliseconds := 20000
      )
      where extract(isodow from now() at time zone 'America/New_York') between 1 and 5
        and (now() at time zone 'America/New_York')::time >= time '16:05'
        and (now() at time zone 'America/New_York')::time <= time '17:05';
    $cmd$
  );

  perform cron.alter_job(
    job_id := v_stock_job,
    schedule := '10 21,22 * * 1-5',
    command := $cmd$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name='fwios_project_url' limit 1)
          || '/functions/v1/portfolio-mtm-refresh-v1',
        headers := jsonb_build_object(
          'Content-Type','application/json',
          'x-fwios-automation-token',
            (select decrypted_secret from vault.decrypted_secrets where name='fwios_automation_token' limit 1)
        ),
        body := jsonb_build_object(
          'source','CRON_US_CLOSE_STOCK_' ||
            to_char((now() at time zone 'America/New_York')::date,'YYYYMMDD'),
          'stock_mode','DAILY_CLOSE_ONLY',
          'refresh_crypto',false,
          'requested_at',now()
        ),
        timeout_milliseconds := 25000
      )
      where to_char(now() at time zone 'America/New_York','HH24:MI')='17:10'
        and extract(isodow from now() at time zone 'America/New_York') between 1 and 5
        and not exists (
          select 1
          from (
            select distinct asset_symbol
            from fwios.v_portfolio_positions_current
            where upper(source_position_status)='OPEN'
              and coalesce(quantity,0)>0
              and upper(asset_class)='STOCK'
          ) s
          where not exists (
            select 1
            from fwios.market_observations o
            join fwios.v_instrument_identity_current id
              on id.instrument_id=o.instrument_id
            where id.asset_symbol=s.asset_symbol
              and o.observation_type='REGULAR_CLOSE'
              and o.value_currency='USD'
              and o.provenance_status='PASS'
              and o.source_tier='A'
              and o.session_date=(now() at time zone 'America/New_York')::date
          )
        );
    $cmd$
  );

  perform cron.alter_job(
    job_id := v_crypto_job,
    schedule := '10 21,22 * * *',
    command := $cmd$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name='fwios_project_url' limit 1)
          || '/functions/v1/portfolio-mtm-refresh-v1',
        headers := jsonb_build_object(
          'Content-Type','application/json',
          'x-fwios-automation-token',
            (select decrypted_secret from vault.decrypted_secrets where name='fwios_automation_token' limit 1)
        ),
        body := jsonb_build_object(
          'source','CRON_US_CLOSE_CRYPTO_SNAPSHOT',
          'stock_mode','OFF',
          'refresh_crypto',true,
          'requested_at',now()
        ),
        timeout_milliseconds := 25000
      )
      where to_char(now() at time zone 'America/New_York','HH24:MI')='17:10';
    $cmd$
  );

  perform cron.alter_job(
    job_id := v_sheet_job,
    schedule := '20 21,22 * * *',
    command := $cmd$
      select net.http_post(
        url := (select decrypted_secret from vault.decrypted_secrets where name='fwios_project_url' limit 1)
          || '/functions/v1/portfolio-sheet-shadow-sync-v1',
        headers := jsonb_build_object(
          'Content-Type','application/json',
          'x-fwios-automation-token',
            (select decrypted_secret from vault.decrypted_secrets where name='fwios_automation_token' limit 1)
        ),
        body := jsonb_build_object(
          'source','CRON_US_CLOSE_NATIVE_SHEET_SYNC',
          'dry_run',false,
          'requested_at',now()
        ),
        timeout_milliseconds := 30000
      )
      where to_char(now() at time zone 'America/New_York','HH24:MI')='17:20';
    $cmd$
  );
end
$migration$;
