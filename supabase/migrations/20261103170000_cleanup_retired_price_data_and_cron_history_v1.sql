-- Authorized 2026-11-03 legacy cleanup.
-- Scope: retired provider observations, retired pg_cron run history, dead helper,
-- and obsolete instrument legacy seed key. Preserve the 3 canonical price tables.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='90s';

DO $preflight$
BEGIN
  IF (SELECT count(*) FROM cron.job WHERE active) <> 5
     OR (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job WHERE active) <> ARRAY[14,15,16,17,18]::bigint[]
  THEN RAISE EXCEPTION 'LEGACY_CLEANUP_ACTIVE_CRON_DRIFT'; END IF;

  IF (SELECT count(*) FROM fwios.instruments) <> 10
     OR (SELECT count(*) FROM fwios.instrument_symbols WHERE active AND valid_to IS NULL AND is_primary) <> 10
  THEN RAISE EXCEPTION 'LEGACY_CLEANUP_HELD_IDENTITY_DRIFT'; END IF;

  IF to_regprocedure('fwios.market_observation_type_v1(text,text)') IS NULL
     OR NOT EXISTS (
       SELECT 1 FROM information_schema.columns
       WHERE table_schema='fwios' AND table_name='instruments' AND column_name='legacy_seed_key')
  THEN RAISE EXCEPTION 'LEGACY_CLEANUP_EXPECTED_OBJECT_MISSING'; END IF;
END $preflight$;

CREATE TEMP TABLE _fwios_read_before ON COMMIT DROP AS
SELECT x.symbol,
       q->>'price_usd' AS price_usd,
       q->>'status' AS status,
       q->>'provider' AS provider,
       q->>'session_date' AS session_date,
       q->>'observation_id' AS observation_id,
       q->>'quote_kind' AS quote_kind
FROM unnest(ARRAY['BTC','DOGE','ETH','HBAR','SOL','XRP','MSFT','NVDA','TLN','TTWO']::text[]) x(symbol)
CROSS JOIN LATERAL (SELECT fwios.pr7_native_usd_price_read_v1(x.symbol) q) r;

-- Current architecture is EOD-only for Stocks. Retire historical live-quote support.
CREATE OR REPLACE FUNCTION fwios.pr5_native_usd_price_shadow_v1(p_asset text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
declare
  v_asset text := upper(btrim(coalesce(p_asset,'')));
  v_count integer;
  v_instrument_id uuid;
  v_class text;
  v_o fwios.market_observations%rowtype;
  v_now timestamptz := now();
  v_max_age interval;
  v_status text;
  v_kind text;
begin
  if length(v_asset) < 1 or length(v_asset) > 24 then
    return jsonb_build_object(
      'asset',left(v_asset,24),'status','UNSUPPORTED',
      'reason','INVALID_ASSET','shadow_only',true,'read_only',true,
      'valuation_eligible',false,'accounting_eligible',false,
      'trading_eligible',false,'new_provider_calls',0,'new_quota_reservations',0);
  end if;

  select count(*),(array_agg(i.instrument_id))[1],(array_agg(i.asset_class))[1]
    into v_count,v_instrument_id,v_class
  from fwios.instruments i
  join fwios.v_instrument_identity_current id
    on id.instrument_id=i.instrument_id
  where id.asset_symbol=v_asset
    and i.lifecycle_status='ACTIVE'
    and i.asset_class in ('Stock','Crypto')
    and i.instrument_type in ('COMMON_STOCK','CRYPTO_ASSET')
    and not (i.metadata ? 'qa_identity');

  if v_count <> 1 then
    return jsonb_build_object(
      'asset',v_asset,
      'status',case when v_count=0 then 'UNSUPPORTED' else 'AMBIGUOUS_INSTRUMENT' end,
      'reason','ACTIVE_CANONICAL_IDENTITY_NOT_UNIQUE',
      'currency','USD','shadow_only',true,'read_only',true,
      'valuation_eligible',false,'accounting_eligible',false,
      'trading_eligible',false,'new_provider_calls',0,'new_quota_reservations',0);
  end if;

  -- Stocks: verified A-tier regular close only.
  -- Crypto: native CoinGecko USD only. No FX-derived price in this function.
  select o.* into v_o
  from fwios.market_observations o
  where o.instrument_id=v_instrument_id
    and o.value_currency='USD'
    and o.provenance_status='PASS'
    and o.observation_value>0
    and o.observed_at <= v_now+interval '5 seconds'
    and coalesce(o.raw_payload->'fwios_pr4'->>'qa_only','false')<>'true'
    and (
      (v_class='Crypto'
       and o.provider='COINGECKO' and o.source_tier='B'
       and o.observation_type='LIVE_QUOTE' and o.market_status='24X7'
       and o.session_date <= (v_now at time zone 'UTC')::date)
      or
      (v_class='Stock'
       and o.source_tier='A'
       and o.session_date <= (v_now at time zone 'America/New_York')::date
       and o.observation_type='REGULAR_CLOSE' and o.market_status='CLOSED'
       and o.provider in ('TWELVE_DATA','ALPHA_VANTAGE_PRICE'))
    )
  order by o.observed_at desc, o.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'asset',v_asset,'instrument_id',v_instrument_id,
      'asset_class',v_class,'currency','USD','price_usd',null,
      'status','MISSING','reason','NATIVE_USD_VERIFIED_OBSERVATION_MISSING',
      'shadow_only',true,'read_only',true,'source_native_usd',false,
      'valuation_eligible',false,'accounting_eligible',false,
      'trading_eligible',false,'new_provider_calls',0,'new_quota_reservations',0);
  end if;

  if v_class='Crypto' then
    v_max_age := interval '30 hours';
    v_kind := 'CRYPTO_DAILY_SNAPSHOT';
    v_status := case
      when v_o.observed_at >= v_now-v_max_age
      then 'FRESH' else 'STALE' end;
  else
    v_max_age := interval '5 days';
    v_kind := 'STOCK_REGULAR_CLOSE';
    v_status := case when v_o.observed_at >= v_now-v_max_age
      then 'LAST_CLOSE' else 'STALE' end;
  end if;

  return jsonb_build_object(
    'asset',v_asset,'instrument_id',v_instrument_id,
    'asset_class',v_class,'currency','USD','price_usd',v_o.observation_value,
    'status',v_status,'quote_kind',v_kind,'observed_at',v_o.observed_at,
    'valid_until',v_o.observed_at+v_max_age,
    'session_date',v_o.session_date,'provider',v_o.provider,
    'source_tier',v_o.source_tier,'observation_id',v_o.observation_id,
    'provenance_status',v_o.provenance_status,
    'source_native_usd',true,'checked_at',v_now,
    'shadow_only',true,'read_only',true,'valuation_eligible',false,
    'accounting_eligible',false,'trading_eligible',false,
    'new_provider_calls',0,'new_quota_reservations',0);
end
$function$;

CREATE TEMP TABLE _fwios_read_after ON COMMIT DROP AS
SELECT x.symbol,
       q->>'price_usd' AS price_usd,
       q->>'status' AS status,
       q->>'provider' AS provider,
       q->>'session_date' AS session_date,
       q->>'observation_id' AS observation_id,
       q->>'quote_kind' AS quote_kind
FROM unnest(ARRAY['BTC','DOGE','ETH','HBAR','SOL','XRP','MSFT','NVDA','TLN','TTWO']::text[]) x(symbol)
CROSS JOIN LATERAL (SELECT fwios.pr7_native_usd_price_read_v1(x.symbol) q) r;

DO $read_guard$
BEGIN
  IF EXISTS (
    (SELECT * FROM _fwios_read_before EXCEPT SELECT * FROM _fwios_read_after)
    UNION ALL
    (SELECT * FROM _fwios_read_after EXCEPT SELECT * FROM _fwios_read_before)
  ) THEN
    RAISE EXCEPTION 'LEGACY_CLEANUP_PRICE_READ_MODEL_CHANGED';
  END IF;
END $read_guard$;

CREATE TEMP TABLE _fwios_cleanup_receipt(
  legacy_observations_before bigint,
  legacy_observations_deleted bigint,
  retired_cron_runs_before bigint,
  retired_cron_runs_deleted bigint
) ON COMMIT DROP;

INSERT INTO _fwios_cleanup_receipt(
  legacy_observations_before,legacy_observations_deleted,
  retired_cron_runs_before,retired_cron_runs_deleted)
SELECT
  (SELECT count(*) FROM fwios.market_observations WHERE provider IN (
    'TWELVE_DATA_FX','TWELVE_DATA_QUOTE','FWIOS_DAILY_CLOSE_SYNC',
    'GOOGLE_SHEETS_MARKET_SEED','TWELVE_DATA_DAILY_CLOSE_FALLBACK',
    'StockAnalysis','Yahoo Finance')),
  0,
  (SELECT count(*) FROM cron.job_run_details d
    WHERE NOT EXISTS(SELECT 1 FROM cron.job j WHERE j.jobid=d.jobid)),
  0;

-- User explicitly authorized permanent deletion of retired provider observations.
-- Hold an exclusive lock only for the short delete window while append-only guard is disabled.
LOCK TABLE fwios.market_observations IN ACCESS EXCLUSIVE MODE;
ALTER TABLE fwios.market_observations DISABLE TRIGGER market_observations_append_only;

WITH deleted AS (
  DELETE FROM fwios.market_observations
  WHERE provider IN (
    'TWELVE_DATA_FX','TWELVE_DATA_QUOTE','FWIOS_DAILY_CLOSE_SYNC',
    'GOOGLE_SHEETS_MARKET_SEED','TWELVE_DATA_DAILY_CLOSE_FALLBACK',
    'StockAnalysis','Yahoo Finance')
  RETURNING 1
)
UPDATE _fwios_cleanup_receipt
SET legacy_observations_deleted=(SELECT count(*) FROM deleted);

ALTER TABLE fwios.market_observations ENABLE TRIGGER market_observations_append_only;

WITH deleted AS (
  DELETE FROM cron.job_run_details d
  WHERE NOT EXISTS(SELECT 1 FROM cron.job j WHERE j.jobid=d.jobid)
  RETURNING 1
)
UPDATE _fwios_cleanup_receipt
SET retired_cron_runs_deleted=(SELECT count(*) FROM deleted);

DO $delete_guard$
DECLARE r _fwios_cleanup_receipt%rowtype;
BEGIN
  SELECT * INTO r FROM _fwios_cleanup_receipt;
  IF r.legacy_observations_before <> r.legacy_observations_deleted
     OR r.retired_cron_runs_before <> r.retired_cron_runs_deleted
  THEN RAISE EXCEPTION 'LEGACY_CLEANUP_DELETE_COUNT_MISMATCH'; END IF;

  IF EXISTS (SELECT 1 FROM fwios.market_observations WHERE provider IN (
    'TWELVE_DATA_FX','TWELVE_DATA_QUOTE','FWIOS_DAILY_CLOSE_SYNC',
    'GOOGLE_SHEETS_MARKET_SEED','TWELVE_DATA_DAILY_CLOSE_FALLBACK',
    'StockAnalysis','Yahoo Finance'))
  THEN RAISE EXCEPTION 'LEGACY_CLEANUP_PROVIDER_ROWS_REMAIN'; END IF;

  IF EXISTS (SELECT 1 FROM cron.job_run_details d
    WHERE NOT EXISTS(SELECT 1 FROM cron.job j WHERE j.jobid=d.jobid))
  THEN RAISE EXCEPTION 'LEGACY_CLEANUP_RETIRED_CRON_LOGS_REMAIN'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid='fwios.market_observations'::regclass
      AND tgname='market_observations_append_only' AND tgenabled='O')
  THEN RAISE EXCEPTION 'LEGACY_CLEANUP_APPEND_ONLY_TRIGGER_NOT_RESTORED'; END IF;
END $delete_guard$;

-- No database or runtime caller remains for this old mapper.
DROP FUNCTION fwios.market_observation_type_v1(text,text) RESTRICT;

-- Every canonical instrument is already identified by UUID + current symbol mapping.
-- legacy_seed_key is not used by any current view/function/worker/contract.
ALTER TABLE fwios.instruments
  DROP CONSTRAINT instruments_legacy_seed_key_key;
ALTER TABLE fwios.instruments
  DROP COLUMN legacy_seed_key RESTRICT;

DO $postflight$
BEGIN
  IF (SELECT count(*) FROM pg_proc WHERE pronamespace='fwios'::regnamespace) <> 5
     OR (SELECT count(*) FROM fwios.instruments) <> 10
     OR (SELECT count(*) FROM fwios.instrument_symbols WHERE active AND valid_to IS NULL AND is_primary) <> 10
     OR (SELECT count(*) FROM cron.job WHERE active) <> 5
  THEN RAISE EXCEPTION 'LEGACY_CLEANUP_POSTFLIGHT_COUNT_FAILED'; END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='fwios' AND table_name='instruments' AND column_name='legacy_seed_key')
     OR to_regprocedure('fwios.market_observation_type_v1(text,text)') IS NOT NULL
  THEN RAISE EXCEPTION 'LEGACY_CLEANUP_OBJECT_RETIREMENT_FAILED'; END IF;
END $postflight$;

COMMIT;
