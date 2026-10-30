-- Enforce defense-in-depth RLS on the last legacy archive table lacking RLS.
-- The private archive schema already denies USAGE to anon and authenticated.
SET LOCAL lock_timeout='5s';
DO $pre$
BEGIN
 IF to_regclass('fwios_legacy_archive_20261029.system_state_legacy_archive_v1') IS NULL THEN RAISE EXCEPTION 'Archive table missing'; END IF;
 IF has_schema_privilege('anon','fwios_legacy_archive_20261029','USAGE') OR has_schema_privilege('authenticated','fwios_legacy_archive_20261029','USAGE') THEN RAISE EXCEPTION 'Archive schema exposed'; END IF;
END $pre$;
ALTER TABLE fwios_legacy_archive_20261029.system_state_legacy_archive_v1 ENABLE ROW LEVEL SECURITY;
DO $post$
BEGIN
 IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid='fwios_legacy_archive_20261029.system_state_legacy_archive_v1'::regclass) THEN RAISE EXCEPTION 'RLS guard absent'; END IF;
END $post$;