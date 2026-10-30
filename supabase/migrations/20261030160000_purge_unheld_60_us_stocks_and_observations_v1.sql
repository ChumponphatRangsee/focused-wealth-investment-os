-- One-time, user-authorized destructive cleanup (2026-10-30, Asia/Bangkok).
-- Permanent deletion: 60 NOT OPEN-HELD US stock identities and exactly 1,789
-- corresponding market_observations. Retain precisely four held Stock symbols
-- MSFT/NVDA/TLN/TTWO and six Crypto symbols BTC/DOGE/ETH/HBAR/SOL/XRP.
-- The authoritative list was confirmed read-only from Investment Portfolio
-- Tracker Google Sheet Holdings immediately before executing this migration.
-- This does NOT delete or edit any Google Sheet rows or portfolio ledger.
-- No backup of the deleted history is created by this migration.
-- All operations are atomic; any guard failure rolls back and restores trigger state.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

LOCK TABLE fwios.market_observations,fwios.instrument_symbols,fwios.instruments
 IN SHARE ROW EXCLUSIVE MODE;

DO $purge$
DECLARE
 keep_stock text[] := ARRAY['MSFT','NVDA','TLN','TTWO']::text[];
 keep_crypto text[] := ARRAY['BTC','DOGE','ETH','HBAR','SOL','XRP']::text[];
 doomed uuid[];
 before_observations bigint;
 kept_observations bigint;
 deleted_prices integer;
 deleted_symbols integer;
 deleted_instruments integer;
BEGIN
 IF (SELECT count(*) FROM pg_class
      WHERE relnamespace='fwios'::regnamespace AND relkind='r')<>3
    OR (SELECT count(*) FROM pg_proc
      WHERE pronamespace='fwios'::regnamespace)<>6
    OR (SELECT count(*) FROM cron.job WHERE active)<>5
 THEN RAISE EXCEPTION 'PRICE_ONLY_RUNTIME_DRIFT'; END IF;

 IF (SELECT count(*) FROM fwios.instruments)<>70
   OR (SELECT count(*) FROM fwios.instrument_symbols)<>70
   OR (SELECT count(*) FROM fwios.v_instrument_identity_current)<>70
   OR (SELECT count(*) FROM fwios.instruments WHERE asset_class='Stock')<>64
   OR (SELECT count(*) FROM fwios.instruments WHERE asset_class='Crypto')<>6
 THEN RAISE EXCEPTION 'EXPECTED_70_INSTRUMENT_BASELINE_MISSING'; END IF;

 IF (SELECT count(*) FROM fwios.v_instrument_identity_current
       WHERE asset_class='Stock' AND asset_symbol=ANY(keep_stock)
       AND lifecycle_status='ACTIVE')<>4
   OR (SELECT count(*) FROM fwios.v_instrument_identity_current
       WHERE asset_class='Crypto' AND asset_symbol=ANY(keep_crypto)
       AND lifecycle_status='ACTIVE')<>6
   OR (SELECT count(*) FROM fwios.v_instrument_identity_current
       WHERE asset_class='Crypto'
       AND NOT(asset_symbol=ANY(keep_crypto)))<>0
 THEN RAISE EXCEPTION 'GOOGLE_SHEET_OPEN_HOLDINGS_AND_DB_UNIVERSE_MISMATCH'; END IF;

 IF (SELECT count(*) FROM pg_trigger
     WHERE tgrelid='fwios.market_observations'::regclass
       AND tgname='market_observations_append_only'
       AND tgenabled='O' AND NOT tgisinternal)<>1
 THEN RAISE EXCEPTION 'APPEND_ONLY_GUARD_MUST_BE_ENABLED'; END IF;

 SELECT array_agg(instrument_id ORDER BY instrument_id)
 INTO doomed
 FROM fwios.v_instrument_identity_current
 WHERE asset_class='Stock' AND NOT(asset_symbol=ANY(keep_stock));
 IF coalesce(cardinality(doomed),0)<>60
   OR (SELECT count(*) FROM fwios.instrument_symbols
       WHERE instrument_id=ANY(doomed))<>60
 THEN RAISE EXCEPTION 'EXPECTED_60_UNHELD_STOCK_INSTRUMENTS_MISSING'; END IF;

 SELECT count(*) INTO before_observations FROM fwios.market_observations;
 SELECT count(*) INTO kept_observations FROM fwios.market_observations
 WHERE NOT(instrument_id=ANY(doomed));

 IF (before_observations-kept_observations)<>1789
    OR (SELECT count(*) FROM fwios.market_observations
        WHERE instrument_id=ANY(doomed)
          AND observation_type='FX')<>0
 THEN RAISE EXCEPTION 'PRICE_DELETE_SET_MUST_EQUAL_1789_NON_FX_OBSERVATIONS'; END IF;

 -- Only this trigger can prevent a specifically authorized historical purge.
 -- Disable inside the transaction and re-enable BEFORE COMMIT.
 -- A SQL exception automatically rolls back the temporary trigger change.
 ALTER TABLE fwios.market_observations
    DISABLE TRIGGER market_observations_append_only;

 DELETE FROM fwios.market_observations
 WHERE instrument_id=ANY(doomed);
 GET DIAGNOSTICS deleted_prices = ROW_COUNT;
 IF deleted_prices<>1789 THEN
    RAISE EXCEPTION 'PRICE_PURGE_COUNT_MISMATCH: %', deleted_prices;
 END IF;

 ALTER TABLE fwios.market_observations
    ENABLE TRIGGER market_observations_append_only;

 DELETE FROM fwios.instrument_symbols
 WHERE instrument_id=ANY(doomed);
 GET DIAGNOSTICS deleted_symbols = ROW_COUNT;
 IF deleted_symbols<>60 THEN
    RAISE EXCEPTION 'SYMBOL_PURGE_COUNT_MISMATCH: %', deleted_symbols;
 END IF;

 DELETE FROM fwios.instruments
 WHERE instrument_id=ANY(doomed);
 GET DIAGNOSTICS deleted_instruments = ROW_COUNT;
 IF deleted_instruments<>60 THEN
    RAISE EXCEPTION 'INSTRUMENT_PURGE_COUNT_MISMATCH: %', deleted_instruments;
 END IF;

 IF (SELECT count(*) FROM fwios.instruments)<>10
  OR (SELECT count(*) FROM fwios.instrument_symbols)<>10
  OR (SELECT count(*) FROM fwios.v_instrument_identity_current)<>10
  OR (SELECT count(*) FROM fwios.instruments WHERE asset_class='Stock')<>4
  OR (SELECT count(*) FROM fwios.instruments WHERE asset_class='Crypto')<>6
  OR (SELECT count(*) FROM fwios.market_observations)<>kept_observations
  OR (SELECT count(DISTINCT instrument_id)
       FROM fwios.market_observations)<>10
  OR (SELECT count(*) FROM fwios.market_observations o
      LEFT JOIN fwios.instruments i ON i.instrument_id=o.instrument_id
      WHERE i.instrument_id IS NULL)<>0
  OR (SELECT count(*) FROM pg_trigger
       WHERE tgrelid='fwios.market_observations'::regclass
         AND tgname='market_observations_append_only'
         AND tgenabled='O' AND NOT tgisinternal)<>1
 THEN RAISE EXCEPTION 'PRICE_ONLY_POST_PURGE_VALIDATION_FAILED'; END IF;

 IF (SELECT array_agg(asset_symbol ORDER BY asset_symbol)
      FROM fwios.v_instrument_identity_current)
   <>ARRAY['BTC','DOGE','ETH','HBAR','MSFT','NVDA','SOL','TLN','TTWO','XRP']::text[]
 THEN RAISE EXCEPTION 'REMAINING_ASSET_UNIVERSE_MISMATCH'; END IF;

END
$purge$;
COMMIT;
