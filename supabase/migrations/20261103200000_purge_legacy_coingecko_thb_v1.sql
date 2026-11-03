-- User-authorized 2026-11-03 targeted cleanup of retired CoinGecko THB crypto observations.
-- This is NOT age-based retention. Current architecture consumes native CoinGecko USD only.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='90s';

DO $preflight$
BEGIN
  IF (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job WHERE active)
       <> ARRAY[14,15,16,17,18,19]::bigint[]
  THEN RAISE EXCEPTION 'LEGACY_COINGECKO_THB_ACTIVE_CRON_DRIFT'; END IF;

  IF (SELECT count(*) FROM fwios.instruments WHERE lifecycle_status='ACTIVE') <> 10
     OR (SELECT count(*) FROM fwios.instrument_symbols
         WHERE active AND valid_to IS NULL AND is_primary) <> 10
  THEN RAISE EXCEPTION 'LEGACY_COINGECKO_THB_IDENTITY_DRIFT'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid='fwios.market_observations'::regclass
      AND tgname='market_observations_append_only'
      AND tgenabled='O')
  THEN RAISE EXCEPTION 'LEGACY_COINGECKO_THB_APPEND_ONLY_TRIGGER_NOT_ENABLED'; END IF;

  IF (SELECT count(*) FROM fwios.market_observations
      WHERE provider='COINGECKO'
        AND observation_type='LIVE_QUOTE'
        AND value_currency='THB') <> 12462
  THEN RAISE EXCEPTION 'LEGACY_COINGECKO_THB_TARGET_COUNT_DRIFT'; END IF;

  IF EXISTS (
    SELECT 1 FROM fwios.market_observations
    WHERE provider='COINGECKO'
      AND observation_type='LIVE_QUOTE'
      AND value_currency='THB'
      AND observed_at >= '2026-10-29 00:00:00+00'::timestamptz)
  THEN RAISE EXCEPTION 'LEGACY_COINGECKO_THB_UNEXPECTED_RECENT_WRITE'; END IF;
END $preflight$;

-- Prevent concurrent observation writes while the append-only guard is temporarily disabled.
LOCK TABLE fwios.market_observations IN ACCESS EXCLUSIVE MODE;

CREATE TEMP TABLE _legacy_coingecko_thb_read_before ON COMMIT DROP AS
SELECT x.symbol,
       q->>'price_usd' AS price_usd,
       q->>'status' AS status,
       q->>'provider' AS provider,
       q->>'session_date' AS session_date,
       q->>'observation_id' AS observation_id,
       q->>'quote_kind' AS quote_kind
FROM unnest(ARRAY['BTC','DOGE','ETH','HBAR','SOL','XRP','MSFT','NVDA','TLN','TTWO']::text[]) x(symbol)
CROSS JOIN LATERAL (SELECT fwios.pr7_native_usd_price_read_v1(x.symbol) q) r;

CREATE TEMP TABLE _legacy_coingecko_thb_receipt(
  total_before bigint NOT NULL,
  target_before bigint NOT NULL,
  target_deleted bigint NOT NULL DEFAULT 0,
  crypto_usd_before bigint NOT NULL,
  stock_eod_before bigint NOT NULL,
  fx_before bigint NOT NULL
) ON COMMIT DROP;

INSERT INTO _legacy_coingecko_thb_receipt(
  total_before,target_before,crypto_usd_before,stock_eod_before,fx_before)
SELECT
  count(*)::bigint,
  count(*) FILTER (
    WHERE provider='COINGECKO'
      AND observation_type='LIVE_QUOTE'
      AND value_currency='THB')::bigint,
  count(*) FILTER (
    WHERE provider='COINGECKO'
      AND observation_type='LIVE_QUOTE'
      AND value_currency='USD')::bigint,
  count(*) FILTER (
    WHERE provider IN ('ALPHA_VANTAGE_PRICE','TWELVE_DATA')
      AND observation_type='REGULAR_CLOSE'
      AND value_currency='USD')::bigint,
  count(*) FILTER (
    WHERE provider='FRANKFURTER_FX'
      AND observation_type='FX'
      AND fx_base_currency='USD'
      AND fx_quote_currency='THB')::bigint
FROM fwios.market_observations;

ALTER TABLE fwios.market_observations
  DISABLE TRIGGER market_observations_append_only;

WITH deleted AS (
  DELETE FROM fwios.market_observations
  WHERE provider='COINGECKO'
    AND observation_type='LIVE_QUOTE'
    AND value_currency='THB'
  RETURNING 1
)
UPDATE _legacy_coingecko_thb_receipt
SET target_deleted=(SELECT count(*) FROM deleted);

ALTER TABLE fwios.market_observations
  ENABLE TRIGGER market_observations_append_only;

CREATE TEMP TABLE _legacy_coingecko_thb_read_after ON COMMIT DROP AS
SELECT x.symbol,
       q->>'price_usd' AS price_usd,
       q->>'status' AS status,
       q->>'provider' AS provider,
       q->>'session_date' AS session_date,
       q->>'observation_id' AS observation_id,
       q->>'quote_kind' AS quote_kind
FROM unnest(ARRAY['BTC','DOGE','ETH','HBAR','SOL','XRP','MSFT','NVDA','TLN','TTWO']::text[]) x(symbol)
CROSS JOIN LATERAL (SELECT fwios.pr7_native_usd_price_read_v1(x.symbol) q) r;

DO $postflight$
DECLARE r _legacy_coingecko_thb_receipt%rowtype;
DECLARE v_total_after bigint;
DECLARE v_crypto_usd_after bigint;
DECLARE v_stock_eod_after bigint;
DECLARE v_fx_after bigint;
BEGIN
  SELECT * INTO r FROM _legacy_coingecko_thb_receipt;

  IF r.target_before <> 12462 OR r.target_deleted <> 12462
  THEN RAISE EXCEPTION 'LEGACY_COINGECKO_THB_DELETE_COUNT_MISMATCH'; END IF;

  IF EXISTS (
    SELECT 1 FROM fwios.market_observations
    WHERE provider='COINGECKO'
      AND observation_type='LIVE_QUOTE'
      AND value_currency='THB')
  THEN RAISE EXCEPTION 'LEGACY_COINGECKO_THB_ROWS_REMAIN'; END IF;

  SELECT
    count(*)::bigint,
    count(*) FILTER (
      WHERE provider='COINGECKO'
        AND observation_type='LIVE_QUOTE'
        AND value_currency='USD')::bigint,
    count(*) FILTER (
      WHERE provider IN ('ALPHA_VANTAGE_PRICE','TWELVE_DATA')
        AND observation_type='REGULAR_CLOSE'
        AND value_currency='USD')::bigint,
    count(*) FILTER (
      WHERE provider='FRANKFURTER_FX'
        AND observation_type='FX'
        AND fx_base_currency='USD'
        AND fx_quote_currency='THB')::bigint
  INTO v_total_after,v_crypto_usd_after,v_stock_eod_after,v_fx_after
  FROM fwios.market_observations;

  IF v_total_after <> r.total_before-r.target_deleted
     OR v_crypto_usd_after <> r.crypto_usd_before
     OR v_stock_eod_after <> r.stock_eod_before
     OR v_fx_after <> r.fx_before
  THEN RAISE EXCEPTION 'LEGACY_COINGECKO_THB_ACTIVE_HISTORY_CHANGED'; END IF;

  IF EXISTS (
    (SELECT * FROM _legacy_coingecko_thb_read_before
     EXCEPT SELECT * FROM _legacy_coingecko_thb_read_after)
    UNION ALL
    (SELECT * FROM _legacy_coingecko_thb_read_after
     EXCEPT SELECT * FROM _legacy_coingecko_thb_read_before)
  )
  THEN RAISE EXCEPTION 'LEGACY_COINGECKO_THB_CURRENT_READ_CHANGED'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid='fwios.market_observations'::regclass
      AND tgname='market_observations_append_only'
      AND tgenabled='O')
  THEN RAISE EXCEPTION 'LEGACY_COINGECKO_THB_TRIGGER_NOT_RESTORED'; END IF;

  IF (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job WHERE active)
       <> ARRAY[14,15,16,17,18,19]::bigint[]
  THEN RAISE EXCEPTION 'LEGACY_COINGECKO_THB_CRON_CHANGED'; END IF;
END $postflight$;

COMMIT;
