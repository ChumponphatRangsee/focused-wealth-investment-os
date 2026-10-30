-- Asset Price Data Service v1.1.0: reduce five core tables to three.
-- Preserve canonical instrument UUIDs, symbol mappings and all market_observations.
-- Preserve every former entity attribute in instruments.metadata.retired_entity,
-- while retaining original entity_id as a non-relational provenance UUID.
-- No CASCADE: unexpected dependencies must abort the entire transaction.

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '45s';

DO $preflight$
BEGIN
 IF to_regnamespace('fwios_legacy_archive_20261029') IS NOT NULL
    THEN RAISE EXCEPTION 'UNEXPECTED_LEGACY_SCHEMA'; END IF;
 IF (SELECT count(*) FROM pg_class
     WHERE relnamespace='fwios'::regnamespace AND relkind='r')<>5
    THEN RAISE EXCEPTION 'PRICE_SCHEMA_TABLE_COUNT_DRIFT'; END IF;
 IF (SELECT count(*) FROM fwios.asset_entities)<>70
  OR (SELECT count(*) FROM fwios.instruments)<>70
  OR (SELECT count(*) FROM fwios.instrument_symbols)<>70
  OR (SELECT count(*) FROM fwios.instrument_identifiers)<>70
    THEN RAISE EXCEPTION 'INSTRUMENT_SEED_ROW_COUNT_DRIFT'; END IF;
 IF (SELECT count(*) FROM fwios.v_instrument_identity_current)<>70
    THEN RAISE EXCEPTION 'IDENTITY_VIEW_ROW_COUNT_DRIFT'; END IF;
 IF (SELECT count(*) FROM fwios.market_observations)<20000
  OR (SELECT count(DISTINCT instrument_id) FROM fwios.market_observations)<>70
    THEN RAISE EXCEPTION 'PRICE_OBSERVATION_LINEAGE_DRIFT'; END IF;
 IF EXISTS (SELECT 1 FROM fwios.instruments
      WHERE metadata ? 'retired_entity' OR entity_id IS NULL)
    THEN RAISE EXCEPTION 'UNEXPECTED_INSTRUMENT_METADATA_OR_NULL_ENTITY'; END IF;
 IF (SELECT count(*) FROM fwios.instruments i
     JOIN fwios.asset_entities e ON e.entity_id=i.entity_id)<>70
    THEN RAISE EXCEPTION 'ENTITY_RELATIONSHIP_MISSING'; END IF;
 IF EXISTS (SELECT 1 FROM fwios.instrument_identifiers
      WHERE identifier_type<>'LEGACY_SEED' OR
        identifier_namespace<>'FWIOS' OR coalesce(provider,'')<>'FWIOS')
    THEN RAISE EXCEPTION 'NONLEGACY_IDENTIFIER_FOUND'; END IF;
 IF (SELECT count(*) FROM pg_constraint
     WHERE conname='instruments_entity_id_fkey'
       AND conrelid='fwios.instruments'::regclass AND contype='f')<>1
    THEN RAISE EXCEPTION 'ENTITY_FK_MISMATCH'; END IF;
END
$preflight$;

DO $copy$
DECLARE updated_rows integer;
BEGIN
 UPDATE fwios.instruments i
    SET metadata = i.metadata || jsonb_build_object(
     'retired_entity',to_jsonb(e)-'entity_id')
   FROM fwios.asset_entities e
  WHERE i.entity_id=e.entity_id;
 GET DIAGNOSTICS updated_rows=ROW_COUNT;
 IF updated_rows<>70 THEN
   RAISE EXCEPTION 'ENTITY_METADATA_COPY_MISMATCH: %',updated_rows;
 END IF;
END
$copy$;

-- Retain the original column list and types so price read paths are unchanged.
CREATE OR REPLACE VIEW fwios.v_instrument_identity_current AS
SELECT
 i.instrument_id,
 i.entity_id,
 i.metadata->'retired_entity'->>'entity_type' AS entity_type,
 i.metadata->'retired_entity'->>'display_name' AS entity_name,
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
 i.metadata->'retired_entity'->'metadata' AS entity_metadata
FROM fwios.instruments i
JOIN fwios.instrument_symbols s
 ON s.instrument_id=i.instrument_id
 AND s.active=true AND s.valid_to IS NULL AND s.is_primary=true;

-- Keep the historical entity UUID in instruments.entity_id without a now-invalid FK.
ALTER TABLE fwios.instruments DROP CONSTRAINT instruments_entity_id_fkey RESTRICT;

DROP TABLE fwios.instrument_identifiers RESTRICT;
DROP TABLE fwios.asset_entities RESTRICT;

DO $postflight$
BEGIN
 IF (SELECT count(*) FROM pg_class
     WHERE relnamespace='fwios'::regnamespace AND relkind='r')<>3
    THEN RAISE EXCEPTION 'THREE_TABLE_EXPECTATION_FAILED'; END IF;
 IF to_regclass('fwios.asset_entities') IS NOT NULL OR
    to_regclass('fwios.instrument_identifiers') IS NOT NULL
    THEN RAISE EXCEPTION 'RETIRED_RELATIONS_REMAIN'; END IF;
 IF (SELECT count(*) FROM fwios.instruments
     WHERE metadata ? 'retired_entity'
       AND nullif(metadata->'retired_entity'->>'display_name','') IS NOT NULL
       AND nullif(metadata->'retired_entity'->>'entity_type','') IS NOT NULL
       AND metadata->'retired_entity'->'metadata' IS NOT NULL)<>70
    THEN RAISE EXCEPTION 'ENTITY_METADATA_NOT_PRESERVED'; END IF;
 IF (SELECT count(*) FROM fwios.v_instrument_identity_current)<>70
    OR (SELECT count(*) FROM fwios.v_instrument_identity_current
         WHERE entity_name IS NULL OR entity_type IS NULL)<>0
    THEN RAISE EXCEPTION 'IDENTITY_VIEW_CHANGED_SHAPE'; END IF;
 IF (SELECT count(*) FROM fwios.market_observations)<20000
   OR (SELECT count(DISTINCT instrument_id) FROM fwios.market_observations)<>70
    THEN RAISE EXCEPTION 'PRICE_HISTORY_NOT_PRESERVED'; END IF;
 IF (SELECT count(*) FROM pg_proc
      WHERE pronamespace='fwios'::regnamespace)<>6
    THEN RAISE EXCEPTION 'PRICE_FUNCTIONS_CHANGED'; END IF;
END
$postflight$;
COMMIT;
