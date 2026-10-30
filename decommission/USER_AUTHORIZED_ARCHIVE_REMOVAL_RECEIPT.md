# User-authorized archive deletion receipt — 2026-10-30 (Asia/Bangkok)

This is an operational record, **not a data backup or recovery mechanism**.

The user explicitly declined backup and authorized irreversible removal of unneeded Legacy FWIOS database history. They were given the Supabase SQL Editor procedure to remove `fwios_legacy_archive_20261029`. The ChatGPT connector did **not** itself execute that schema drop. Subsequent live read-only inspection confirmed:
- `to_regnamespace('fwios_legacy_archive_20261029') IS NULL`
- Archival table count = **0** (formerly 87)
- Production `fwios` still had five price tables and the three scheduled price Cron jobs #14, #15, #16
- `fwios.market_observations` retained at least 20,427 canonical observations.

Former archived contents included **58 transaction rows** / 29 distinct source IDs, **1,590** historic stock daily-close records and **19,608** market lineage links. These are no longer recoverable from the database archive. The user specifically chose not to take an independent backup; Git history of SQL/source code is not a substitute for deleted database records.

After verification of archive deletion, an authorized live migration `retire_last_7_legacy_trigger_functions_v1` successfully removed the seven remaining orphan trigger routines with `RESTRICT`. `fwios` retained **six** price/identity SQL functions. Post-deletion direct live Crypto/FX/Google Sheet E2E passed HTTP 200 (response IDs 11978–11980), with six Crypto price writes, one FX write and Sheet readback verification. Read-only 27/27 regression passed.

Sixteen retired Edge deployments still exist as HTTP 410 and require separate physical deletion. **Never delete** `price-market-refresh-v1` or `price-sheet-sync-v1`.
