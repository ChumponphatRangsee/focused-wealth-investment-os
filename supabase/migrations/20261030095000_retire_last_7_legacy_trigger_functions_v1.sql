-- Retire seven orphaned FWIOS legacy-only trigger routines, after verified archive deletion.
-- Do NOT replay against a fresh database.
SET LOCAL lock_timeout = '5s';
DO $pre$
BEGIN
 IF to_regnamespace('fwios_legacy_archive_20261029') IS NOT NULL THEN RAISE EXCEPTION 'ARCHIVE_STILL_EXISTS'; END IF;
 IF (SELECT count(*) FROM pg_class WHERE relnamespace='fwios'::regnamespace AND relkind IN('r','p'))<>5 THEN RAISE EXCEPTION 'PRICE_TABLE_COUNT_DRIFT'; END IF;
 IF (SELECT count(*) FROM pg_proc WHERE pronamespace='fwios'::regnamespace)<>13 THEN RAISE EXCEPTION 'FUNCTION_COUNT_DRIFT'; END IF;
 IF EXISTS (SELECT 1 FROM pg_trigger t WHERE NOT t.tgisinternal AND t.tgfoid IN (
  'fwios.immutable_snapshot_guard_v1()'::regprocedure,
  'fwios.lineage_append_only_guard_v1()'::regprocedure,
  'fwios.normalize_architecture_system_state_write_v1()'::regprocedure,
  'fwios.sync_market_daily_close_observation_v1()'::regprocedure,
  'fwios.sync_market_price_quote_observation_v1()'::regprocedure,
  'fwios.sync_market_price_snapshot_observation_v1()'::regprocedure,
  'fwios.thesis_memory_append_only_guard_v1()'::regprocedure
 )) THEN RAISE EXCEPTION 'LEGACY_TRIGGER_STILL_ATTACHED'; END IF;
END $pre$;
DROP FUNCTION fwios.immutable_snapshot_guard_v1() RESTRICT;
DROP FUNCTION fwios.lineage_append_only_guard_v1() RESTRICT;
DROP FUNCTION fwios.normalize_architecture_system_state_write_v1() RESTRICT;
DROP FUNCTION fwios.sync_market_daily_close_observation_v1() RESTRICT;
DROP FUNCTION fwios.sync_market_price_quote_observation_v1() RESTRICT;
DROP FUNCTION fwios.sync_market_price_snapshot_observation_v1() RESTRICT;
DROP FUNCTION fwios.thesis_memory_append_only_guard_v1() RESTRICT;
DO $post$
BEGIN
 IF (SELECT count(*) FROM pg_proc WHERE pronamespace='fwios'::regnamespace)<>6 THEN RAISE EXCEPTION 'REQUIRED_PRICE_FUNCTIONS_CHANGED'; END IF;
 IF (SELECT count(*) FROM pg_class WHERE relnamespace='fwios'::regnamespace AND relkind IN('r','p'))<>5 THEN RAISE EXCEPTION 'REQUIRED_PRICE_TABLES_CHANGED'; END IF;
END $post$;