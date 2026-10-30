# Changelog — Asset Price Data Service

## 2026-10-30 — Permanent legacy database retirement

- User explicitly authorized deletion of the unused 87-table archived schema without backup and executed removal manually through Supabase SQL Editor. Confirmed schema absent and 5 production price tables preserved. Former archival data no longer recoverable from the deleted schema.
- Retired the seven remaining orphaned SQL trigger functions via production `DROP FUNCTION ... RESTRICT` migration; six essential price/identity functions remain. Price schema: **5 tables + 1 view + 6 functions**.
- Re-ran production Crypto 6/6, FX 1/1 and Google Sheet readback: all HTTP 200, zero Portfolio writes. Updated SQL regression **27/27 PASS**; Security Advisor has INFO-only no-policy notices.
- Physical cleanup of sixteen inert 410 Edge deployments still requires authorized Dashboard/CLI action; the app connector does not offer deletion.

## 2026-10-30 — Source retirement and price-only cutover

- Verified natural scheduled Crypto/FX/Sheet E2E, HTTP 200. Removed 187 out-of-scope files from the current Git tree with Git history preserved.
- Merged PR #100 to `main`, leaving only price workers, scoped CI and source/migration receipts.
