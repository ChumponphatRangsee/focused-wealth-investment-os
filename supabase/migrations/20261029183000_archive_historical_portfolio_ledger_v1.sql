-- Non-destructive isolation of the unreconciled historical portfolio ledger.
-- Preserve 58 transactions, 29 unique source IDs and all three FK-supporting tables.
-- Core price-service functions and scheduled workers do not use these tables.
SET LOCAL lock_timeout='5s';
DO $guard$
BEGIN
 IF (SELECT count(*) FROM pg_class WHERE relnamespace='fwios'::regnamespace AND relkind IN ('r','p'))<>9 THEN RAISE EXCEPTION 'Core table count drift'; END IF;
 IF (SELECT count(*) FROM pg_class WHERE relnamespace='fwios_legacy_archive_20261029'::regnamespace AND relkind IN ('r','p'))<>83 THEN RAISE EXCEPTION 'Archive table count drift'; END IF;
 IF (SELECT count(*) FROM fwios.portfolio_transactions)<>58 OR (SELECT count(DISTINCT source_id) FROM fwios.portfolio_transactions)<>29 THEN RAISE EXCEPTION 'Historical source IDs drift'; END IF;
 IF (SELECT count(*) FROM fwios.market_observations)<>20413 THEN RAISE EXCEPTION 'Canonical market observation count drift'; END IF;
 IF (SELECT array_agg(jobid ORDER BY jobid) FROM cron.job WHERE active)<>ARRAY[14,15,16]::bigint[] THEN RAISE EXCEPTION 'Price schedule drift'; END IF;
 IF EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace='fwios'::regnamespace AND (lower(pg_get_functiondef(oid)) LIKE '%portfolio_transactions%' OR lower(pg_get_functiondef(oid)) LIKE '%portfolio_import_batches%' OR lower(pg_get_functiondef(oid)) LIKE '%portfolio_assets%' OR lower(pg_get_functiondef(oid)) LIKE '%portfolio_accounts%')) THEN RAISE EXCEPTION 'Core functions reference portfolio'; END IF;
END $guard$;
ALTER TABLE fwios.portfolio_transactions SET SCHEMA fwios_legacy_archive_20261029;
ALTER TABLE fwios.portfolio_accounts SET SCHEMA fwios_legacy_archive_20261029;
ALTER TABLE fwios.portfolio_assets SET SCHEMA fwios_legacy_archive_20261029;
ALTER TABLE fwios.portfolio_import_batches SET SCHEMA fwios_legacy_archive_20261029;
DO $verify$
BEGIN
 IF (SELECT count(*) FROM pg_class WHERE relnamespace='fwios'::regnamespace AND relkind IN ('r','p'))<>5 THEN RAISE EXCEPTION 'Expected exactly five core tables'; END IF;
 IF (SELECT count(*) FROM pg_class WHERE relnamespace='fwios_legacy_archive_20261029'::regnamespace AND relkind IN ('r','p'))<>87 THEN RAISE EXCEPTION 'Expected exactly 87 archived tables'; END IF;
 IF (SELECT count(*) FROM fwios_legacy_archive_20261029.portfolio_transactions)<>58 OR (SELECT count(DISTINCT source_id) FROM fwios_legacy_archive_20261029.portfolio_transactions)<>29 THEN RAISE EXCEPTION 'Historical ledger changed'; END IF;
 IF (SELECT count(*) FROM fwios.market_observations)<>20413 THEN RAISE EXCEPTION 'Market observations changed'; END IF;
 IF has_schema_privilege('anon','fwios_legacy_archive_20261029','USAGE') OR has_schema_privilege('authenticated','fwios_legacy_archive_20261029','USAGE') THEN RAISE EXCEPTION 'Archive not private'; END IF;
END $verify$;