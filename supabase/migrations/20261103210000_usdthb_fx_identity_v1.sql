-- 2026-11-03: normalize USD/THB FX identity without rewriting append-only history.
-- Keep the 9 legacy MSFT-carried FX observations untouched as historical evidence.
-- Add one canonical FX pair identity (USDTHB), seed the latest verified FX receipt under it,
-- and let current workers cut over to the dedicated identity.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='90s';

DO $preflight$
DECLARE v_msft uuid;
BEGIN
  IF (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job WHERE active)
       <> ARRAY[14,15,16,17,18,19]::bigint[]
  THEN RAISE EXCEPTION 'FX_IDENTITY_ACTIVE_CRON_DRIFT'; END IF;

  IF (SELECT count(*) FROM fwios.instruments) <> 10
     OR (SELECT count(*) FROM fwios.instrument_symbols
         WHERE active AND valid_to IS NULL AND is_primary) <> 10
     OR (SELECT count(*) FROM fwios.v_instrument_identity_current) <> 10
  THEN RAISE EXCEPTION 'FX_IDENTITY_PREEXISTING_IDENTITY_COUNT_DRIFT'; END IF;

  IF EXISTS (
    SELECT 1 FROM fwios.instruments WHERE asset_class='FX'
  ) OR EXISTS (
    SELECT 1 FROM fwios.instrument_symbols
    WHERE upper(symbol)='USDTHB' AND active AND valid_to IS NULL
  )
  THEN RAISE EXCEPTION 'FX_IDENTITY_ALREADY_EXISTS'; END IF;

  SELECT fwios.resolve_instrument_id_v1('MSFT','Stock',NULL,NULL) INTO v_msft;
  IF v_msft IS NULL THEN
    RAISE EXCEPTION 'FX_IDENTITY_MSFT_RESOLUTION_FAILED';
  END IF;

  IF (SELECT count(*) FROM fwios.market_observations
      WHERE observation_type='FX'
        AND provider='FRANKFURTER_FX'
        AND fx_base_currency='USD'
        AND fx_quote_currency='THB'
        AND value_currency='THB'
        AND provenance_status='PASS') <> 9
  THEN RAISE EXCEPTION 'FX_IDENTITY_LEGACY_FX_COUNT_DRIFT'; END IF;

  IF EXISTS (
    SELECT 1 FROM fwios.market_observations
    WHERE observation_type='FX'
      AND provider='FRANKFURTER_FX'
      AND fx_base_currency='USD'
      AND fx_quote_currency='THB'
      AND value_currency='THB'
      AND provenance_status='PASS'
      AND instrument_id <> v_msft
  )
  THEN RAISE EXCEPTION 'FX_IDENTITY_LEGACY_FX_NOT_MSFT_CARRIER'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid='fwios.market_observations'::regclass
      AND tgname='market_observations_append_only'
      AND tgenabled='O')
  THEN RAISE EXCEPTION 'FX_IDENTITY_APPEND_ONLY_TRIGGER_NOT_ENABLED'; END IF;
END $preflight$;

CREATE TEMP TABLE _fx_identity_current_reads_before ON COMMIT DROP AS
SELECT x.symbol,
       q->>'price_usd' AS price_usd,
       q->>'status' AS status,
       q->>'provider' AS provider,
       q->>'session_date' AS session_date,
       q->>'observation_id' AS observation_id,
       q->>'quote_kind' AS quote_kind
FROM unnest(ARRAY['BTC','DOGE','ETH','HBAR','SOL','XRP','MSFT','NVDA','TLN','TTWO']::text[]) x(symbol)
CROSS JOIN LATERAL (SELECT fwios.pr7_native_usd_price_read_v1(x.symbol) q) r;

CREATE TEMP TABLE _fx_identity_legacy_before ON COMMIT DROP AS
SELECT *
FROM fwios.market_observations
WHERE observation_type='FX'
  AND provider='FRANKFURTER_FX'
  AND fx_base_currency='USD'
  AND fx_quote_currency='THB'
  AND value_currency='THB'
  AND provenance_status='PASS'
ORDER BY observation_id;

CREATE TEMP TABLE _fx_identity_receipt(
  fx_instrument_id uuid NOT NULL,
  seed_observation_id uuid NOT NULL,
  source_observation_id uuid NOT NULL
) ON COMMIT DROP;

DO $create$
DECLARE
  v_fx_id uuid;
  v_seed_id uuid;
  v_source fwios.market_observations%rowtype;
BEGIN
  INSERT INTO fwios.instruments(
    asset_class,instrument_type,primary_venue,trading_currency,lifecycle_status,metadata
  ) VALUES (
    'FX','CURRENCY_PAIR','FRANKFURTER','THB','ACTIVE',
    jsonb_build_object(
      'fx_pair',jsonb_build_object(
        'base_currency','USD',
        'quote_currency','THB',
        'display_name','USD/THB FX Rate',
        'canonical_symbol','USDTHB'
      ),
      'purpose','PRICE_SERVICE_FX_IDENTITY'
    )
  )
  RETURNING instrument_id INTO v_fx_id;

  INSERT INTO fwios.instrument_symbols(
    instrument_id,symbol,venue,symbol_namespace,is_primary,active,metadata
  ) VALUES (
    v_fx_id,'USDTHB','FX','FX_PAIR',true,true,
    jsonb_build_object('base_currency','USD','quote_currency','THB')
  );

  SELECT * INTO v_source
  FROM fwios.market_observations
  WHERE observation_type='FX'
    AND provider='FRANKFURTER_FX'
    AND fx_base_currency='USD'
    AND fx_quote_currency='THB'
    AND value_currency='THB'
    AND provenance_status='PASS'
  ORDER BY observed_at DESC,created_at DESC
  LIMIT 1;

  IF v_source.observation_id IS NULL THEN
    RAISE EXCEPTION 'FX_IDENTITY_SOURCE_OBSERVATION_MISSING';
  END IF;

  SELECT fwios.ensure_market_observation_v1(
    v_fx_id,
    'FX',
    v_source.observation_value,
    'THB',
    v_source.session_date,
    v_source.observed_at,
    'FX',
    'FRANKFURTER_FX',
    'B',
    v_source.source_url,
    'PASS',
    jsonb_build_object(
      'price_only',true,
      'fx_identity_normalization_seed',true,
      'source_observation_id',v_source.observation_id::text,
      'source_url',v_source.source_url,
      'quote_date',v_source.session_date::text
    ),
    'USD',
    'THB'
  ) INTO v_seed_id;

  IF v_seed_id IS NULL THEN
    RAISE EXCEPTION 'FX_IDENTITY_SEED_INSERT_FAILED';
  END IF;

  INSERT INTO _fx_identity_receipt(fx_instrument_id,seed_observation_id,source_observation_id)
  VALUES (v_fx_id,v_seed_id,v_source.observation_id);
END $create$;

CREATE OR REPLACE VIEW fwios.v_instrument_identity_current AS
SELECT
 i.instrument_id,
 i.entity_id,
 CASE
   WHEN i.asset_class='FX' THEN 'FX_PAIR'
   ELSE i.metadata->'retired_entity'->>'entity_type'
 END AS entity_type,
 CASE
   WHEN i.asset_class='FX' THEN coalesce(i.metadata->'fx_pair'->>'display_name',s.symbol)
   ELSE i.metadata->'retired_entity'->>'display_name'
 END AS entity_name,
 i.asset_class,
 i.instrument_type,
 i.lifecycle_status,
 s.symbol AS asset_symbol,
 CASE WHEN i.asset_class='Stock' THEN s.symbol ELSE NULL::text END AS ticker,
 s.venue AS exchange,
 i.trading_currency AS currency,
 s.symbol_namespace,
 i.primary_venue,
 i.metadata AS instrument_metadata,
 CASE
   WHEN i.asset_class='FX' THEN i.metadata->'fx_pair'
   ELSE i.metadata->'retired_entity'->'metadata'
 END AS entity_metadata
FROM fwios.instruments i
JOIN fwios.instrument_symbols s
 ON s.instrument_id=i.instrument_id
 AND s.active=true AND s.valid_to IS NULL AND s.is_primary=true;

CREATE TEMP TABLE _fx_identity_current_reads_after ON COMMIT DROP AS
SELECT x.symbol,
       q->>'price_usd' AS price_usd,
       q->>'status' AS status,
       q->>'provider' AS provider,
       q->>'session_date' AS session_date,
       q->>'observation_id' AS observation_id,
       q->>'quote_kind' AS quote_kind
FROM unnest(ARRAY['BTC','DOGE','ETH','HBAR','SOL','XRP','MSFT','NVDA','TLN','TTWO']::text[]) x(symbol)
CROSS JOIN LATERAL (SELECT fwios.pr7_native_usd_price_read_v1(x.symbol) q) r;

CREATE TEMP TABLE _fx_identity_legacy_after ON COMMIT DROP AS
SELECT m.*
FROM fwios.market_observations m
JOIN _fx_identity_legacy_before b USING(observation_id)
ORDER BY m.observation_id;

DO $postflight$
DECLARE
  r _fx_identity_receipt%rowtype;
  v_msft uuid;
BEGIN
  SELECT * INTO r FROM _fx_identity_receipt;
  SELECT fwios.resolve_instrument_id_v1('MSFT','Stock',NULL,NULL) INTO v_msft;

  IF (SELECT count(*) FROM fwios.instruments) <> 11
     OR (SELECT count(*) FROM fwios.instruments WHERE asset_class='Stock') <> 4
     OR (SELECT count(*) FROM fwios.instruments WHERE asset_class='Crypto') <> 6
     OR (SELECT count(*) FROM fwios.instruments WHERE asset_class='FX' AND instrument_type='CURRENCY_PAIR') <> 1
     OR (SELECT count(*) FROM fwios.v_instrument_identity_current) <> 11
  THEN RAISE EXCEPTION 'FX_IDENTITY_POSTFLIGHT_IDENTITY_COUNT_FAILED'; END IF;

  IF fwios.resolve_instrument_id_v1('USDTHB','FX','FX','FX_PAIR') IS DISTINCT FROM r.fx_instrument_id
  THEN RAISE EXCEPTION 'FX_IDENTITY_RESOLUTION_FAILED'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM fwios.v_instrument_identity_current
    WHERE instrument_id=r.fx_instrument_id
      AND asset_symbol='USDTHB'
      AND asset_class='FX'
      AND instrument_type='CURRENCY_PAIR'
      AND entity_type='FX_PAIR'
      AND entity_name='USD/THB FX Rate'
      AND currency='THB'
      AND symbol_namespace='FX_PAIR'
  )
  THEN RAISE EXCEPTION 'FX_IDENTITY_VIEW_ROW_INVALID'; END IF;

  IF (SELECT count(*) FROM fwios.market_observations
      WHERE instrument_id=r.fx_instrument_id
        AND observation_type='FX'
        AND provider='FRANKFURTER_FX'
        AND fx_base_currency='USD'
        AND fx_quote_currency='THB'
        AND value_currency='THB'
        AND provenance_status='PASS') <> 1
  THEN RAISE EXCEPTION 'FX_IDENTITY_NORMALIZED_SEED_COUNT_FAILED'; END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM fwios.market_observations seeded
    JOIN fwios.market_observations source
      ON source.observation_id=r.source_observation_id
    WHERE seeded.observation_id=r.seed_observation_id
      AND seeded.instrument_id=r.fx_instrument_id
      AND seeded.observation_value=source.observation_value
      AND seeded.session_date=source.session_date
      AND seeded.observed_at=source.observed_at
      AND seeded.provider=source.provider
      AND seeded.source_url=source.source_url
      AND seeded.raw_payload->>'fx_identity_normalization_seed'='true'
      AND seeded.raw_payload->>'source_observation_id'=source.observation_id::text
  )
  THEN RAISE EXCEPTION 'FX_IDENTITY_SEED_LINEAGE_MISMATCH'; END IF;

  IF (SELECT count(*) FROM fwios.market_observations
      WHERE observation_type='FX'
        AND provider='FRANKFURTER_FX'
        AND fx_base_currency='USD'
        AND fx_quote_currency='THB'
        AND value_currency='THB'
        AND provenance_status='PASS'
        AND instrument_id=v_msft) <> 9
  THEN RAISE EXCEPTION 'FX_IDENTITY_LEGACY_HISTORY_CHANGED'; END IF;

  IF EXISTS (
    (SELECT * FROM _fx_identity_legacy_before EXCEPT SELECT * FROM _fx_identity_legacy_after)
    UNION ALL
    (SELECT * FROM _fx_identity_legacy_after EXCEPT SELECT * FROM _fx_identity_legacy_before)
  )
  THEN RAISE EXCEPTION 'FX_IDENTITY_LEGACY_ROWS_MUTATED'; END IF;

  IF EXISTS (
    (SELECT * FROM _fx_identity_current_reads_before EXCEPT SELECT * FROM _fx_identity_current_reads_after)
    UNION ALL
    (SELECT * FROM _fx_identity_current_reads_after EXCEPT SELECT * FROM _fx_identity_current_reads_before)
  )
  THEN RAISE EXCEPTION 'FX_IDENTITY_NATIVE_USD_READ_CHANGED'; END IF;

  IF (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job WHERE active)
       <> ARRAY[14,15,16,17,18,19]::bigint[]
  THEN RAISE EXCEPTION 'FX_IDENTITY_CRON_CHANGED'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid='fwios.market_observations'::regclass
      AND tgname='market_observations_append_only'
      AND tgenabled='O')
  THEN RAISE EXCEPTION 'FX_IDENTITY_APPEND_ONLY_TRIGGER_CHANGED'; END IF;
END $postflight$;

COMMIT;
