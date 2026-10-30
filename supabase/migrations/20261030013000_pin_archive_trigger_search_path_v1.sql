-- Security hardening: archive-only legacy trigger has no external table/function dependencies.
-- Pin its search_path against hostile caller context without changing its behavior or legacy data.
SET LOCAL lock_timeout='5s';
DO $pre$
BEGIN
 IF to_regprocedure('fwios.normalize_architecture_system_state_write_v1()') IS NULL THEN RAISE EXCEPTION 'Expected archive trigger routine absent'; END IF;
 IF (SELECT prosecdef FROM pg_proc WHERE oid='fwios.normalize_architecture_system_state_write_v1()'::regprocedure) THEN RAISE EXCEPTION 'Unexpected SECURITY DEFINER context'; END IF;
END $pre$;
ALTER FUNCTION fwios.normalize_architecture_system_state_write_v1() SET search_path = pg_catalog, pg_temp;
DO $post$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid='fwios.normalize_architecture_system_state_write_v1()'::regprocedure AND proconfig @> ARRAY['search_path=pg_catalog, pg_temp']::text[]) THEN RAISE EXCEPTION 'Search path pin not applied'; END IF;
END $post$;