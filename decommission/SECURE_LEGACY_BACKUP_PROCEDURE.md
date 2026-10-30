# Required independent backup before permanent legacy-data deletion

**Status: NOT COMPLETED.** This file documents a manual, auditable recovery procedure. Neither the agent nor the connected Supabase tool has exported and restored an independent backup. The linked organization uses a **Free** plan; do not assume managed daily backups. Do not execute permanent `DROP SCHEMA` or `TRUNCATE` based only on this runbook.

**Important:** `fwios_legacy_archive_20261029` contains 87 historical tables including 58 portfolio transactions (29 unique source IDs), 1,590 stock daily closes and 19,608 observation legacy links. Several foreign keys point to the active five-table `fwios` schema, so a standalone archive-only SQL export may not independently restore. Use a **complete database dump**, including both active and archival schemas and relevant extensions/roles.

## Export (secure operator workstation, PostgreSQL 17 client)

1. Supabase Dashboard → focused-wealth-investment-os → **Connect**: obtain the live Postgres host, port and username. If the direct host is unreachable over IPv6, use the Session Pooler connection details from the same page.
2. Confirm `pg_dump --version` is PostgreSQL **17 or newer** (server is 17). Create a private encrypted backup directory **outside** GitHub/Google Sheet.
3. From PowerShell/terminal, run the following with the host and user values from Dashboard (do not put the DB password in commands, ChatGPT, logs or commit history). The `-W` flag prompts interactively for the password:

```powershell
pg_dump --host "<HOST_FROM_CONNECT>" --port 5432 --username "<USER_FROM_CONNECT>" --dbname postgres --format custom --no-owner --no-privileges --verbose --file "fwios_full_20261030.dump" -W
pg_restore --list "fwios_full_20261030.dump" > "fwios_full_20261030_manifest.txt"
Get-FileHash "fwios_full_20261030.dump" -Algorithm SHA256
```

4. Ensure the dump file is **non-empty** and contains objects for **both** `fwios` and `fwios_legacy_archive_20261029`. Preserve checksum and manifest in an encrypted location separate from the production Supabase project. Handle full-database dumps as sensitive: they can include authentication/accounting records.
5. Restore to a **separate isolated Postgres 17 / Supabase test environment**, never directly into production. Include compatible extensions and roles. Verify the restored historical object inventory and row counts, at minimum:

```sql
SELECT count(*) FROM fwios_legacy_archive_20261029.portfolio_transactions; -- 58
SELECT count(DISTINCT source_id) FROM fwios_legacy_archive_20261029.portfolio_transactions; -- 29
SELECT count(*) FROM fwios_legacy_archive_20261029.market_daily_closes; -- 1590
SELECT count(*) FROM fwios_legacy_archive_20261029.market_observation_legacy_links; -- 19608
SELECT count(*) FROM fwios.market_observations; -- count should match the export snapshot
```

6. Record restore environment, timestamp, dump SHA256 and results. **Only after a full restore passes, decide explicitly whether historical accounting/research records should be permanently deleted**. A full schema dump made before latest price observations is not a current runtime backup; consider another fresh dump before destruction.

Reference: https://supabase.com/docs/guides/platform/backups and https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore

**Not a roadmap**: these are the retention and recovery gates required before destructive cleanup of financial history.
