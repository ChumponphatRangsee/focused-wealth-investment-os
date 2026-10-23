# FWIOS — Legacy Dashboard Dependency & Retirement Audit

**Inspection:** 2026-10-23 (Asia/Bangkok). **GitHub baseline:** `main` at `51eb5bcaf7e7904de190e43a0ebd34966a199e7d` (merged PR #65). **Supabase project:** `ysjbmeukwbfnxnwqchuq`. **Google Sheet:** `Focused Wealth Dashboard - Chumponphat`.

> **Decision: HOLD — NO PRODUCTION RETIREMENT AUTHORIZED.** This is a read-only dependency inventory, not approval to delete the legacy `_Data` tab, Edge Function, database objects, credentials or deploys. Do not equate an absence of recent requests with proven absence of external consumers. No private access tokens, authenticated feed URLs or portfolio account data are recorded here.

## Scope and evidence

Audited **live** Supabase Edge Function inventory, `cron.job`, `fwios.dashboard_refresh_access` metadata (no secrets/hashes read), `fwios.dashboard_refresh_cache` timestamps, existence of `fwios.dashboard_refresh_payload_v1()`, the current scanner view definition, and per-function `function_edge_logs` counts. Inspected current Google Sheets tab metadata and **user-entered formulas in all eight tabs across their defined grid bounds**, without recording raw URL/token values. Cross-checked repository implementation and October PR-A/PR-B handovers.

Read-only inspection did not exercise or change public endpoints, database records, Sheets formulas, Edge Functions, cron jobs or access controls.

## Dependency inventory — observed 2026-10-23

| Component | Observed live state | Dependency / classification | Safe action now |
| --- | --- | --- | --- |
| `supabase/functions/scanner-refresh-csv-v1` | Edge Function **ACTIVE v4**; distinct `GOOGLE_SHEET_SCANNER_IMPORTDATA` access key **active** | **Current scanner feed — KEEP** | No change |
| `S&P500 Scanner` | Visible tab, 21 formulas refer to `_Scanner_Data`, **zero** refer to `_Data` | Current UI — KEEP | No change |
| `Valuation Map` | Visible tab, 6 formulas refer to `_Scanner_Data`, **zero** refer to `_Data` | Current UI — KEEP | No change |
| `_Scanner_Data` / `_Scanner_Config` | Hidden helpers; one `IMPORTDATA` formula in `_Scanner_Data`, scanner URL in `_Scanner_Config` | Current scanner path — KEEP; never copy URL to Git | No change |
| `Dashboard` | Hidden; 22 formulas refer to legacy `_Data` | Legacy UI — internally dependent on `_Data` | Candidate **only after** approved removal of its formulas/tab |
| `Thesis Tracker` | Hidden; 19 formulas refer to legacy `_Data` | Legacy UI — internally dependent | Candidate after approved snapshot/backup |
| `Opportunity Quality` | Hidden; 20 formulas refer to legacy `_Data` | Legacy UI — internally dependent | Candidate after approved snapshot/backup |
| `_Data` | Hidden, populated historical cells; **no remaining `IMPORTDATA` formula** in its scanned grid; legacy endpoint URL text still present | Legacy cache/feed backing; still read by **61 formulas** across the three hidden tabs | **KEEP until hidden consumer tabs are retired and external/rollback audit is complete** |
| `dashboard-refresh-csv-v1` | Supabase Edge Function **ACTIVE v7**; source in GitHub | Legacy CSV feed / rollback endpoint; possible external consumers | **DO NOT DELETE/UNDEPLOY YET** |
| `GOOGLE_SHEET_IMPORTDATA` | Access row **active=true** in `fwios.dashboard_refresh_access` | Legacy bearer-style URL token authorization; no token value inspected | **DO NOT REVOKE** without approved cutover and rollback plan |
| `fwios.dashboard_refresh_payload_v1()` | SQL function exists | Legacy endpoint invokes it | Keep pending endpoint retirement |
| `fwios.dashboard_refresh_cache` | `PRIMARY` last-good and updated timestamps **2026-09-24 15:14:15 UTC** | Stale cache receipt; alone does **not** prove zero external use | Retain historical and rollback evidence |
| `fwios.dashboard_refresh_access` | Stores **both legacy and scanner access keys** | **SHARED — KEEP TABLE**. Dropping it would threaten active scanner authentication | **NEVER DROP as legacy-only cleanup** |
| `fwios.v_dashboard_valuation_map`, `fwios.v_thesis_tracking_current` | `fwios.v_scanner_current_v1` currently references **both** | **SHARED BACKEND — KEEP** | No change |
| Five `dashboard-refresh-*-probe-v1` diagnostic endpoints | Five different probe slugs still **ACTIVE** (static/env/db/query/role) | Older diagnostic deploys, absent from current repository tree | Separate security and external dependency assessment; do not remove yet |

**Live schedule inspection:** No `pg_cron` command matched `dashboard-refresh-csv-v1`, `dashboard_refresh_payload_v1` or `scanner-refresh-csv-v1`. Other decision, provider-validation, daily-close, portfolio refresh and Sheet sync jobs remain active; do **not** treat them as legacy dashboard jobs.

**Request-log observation:** A day-scoped `function_edge_logs` count by the exact legacy Function ID `2186e14b-2f86-4a84-b7cf-dcc72932d2d1` returned **zero observed requests in each UTC day from 2026-10-16 through 2026-10-22**, and the separate most-recent-24-hour check on 2026-10-23 also showed no legacy request. Other Edge functions had log records in those windows (including scanner traffic). These are **bounded observations only**; do not extrapolate beyond retention, covered dates, logger completeness, or the application's periodic refresh cadence.

**Important distinction:** Google Sheets `_Data!A1` no longer has an IMPORTDATA formula in the inspected current workbook. The legacy feed is therefore not the *current automatic import path for this workbook*, but saved URL cells, an active legacy access key, hidden tab formulas and potential external bookmarks or consumers remain. No inspection of every external URL consumer, Google Apps Script trigger, third-party integration or all historical Sheets copies was performed.

## Safety decision by object

- **KEEP unconditionally:** current scanner Edge Function and helper tabs; `fwios.v_scanner_current_v1`, `v_dashboard_valuation_map`, `v_thesis_tracking_current`; shared `dashboard_refresh_access` table; all SQL migrations and regression history.
- **Conditional retirement candidates:** three hidden legacy display tabs; static legacy `_Data` cache and the legacy-only credential *row*; deployed `dashboard-refresh-csv-v1`; its private payload function and last-good cache only after identifying any additional references; diagnostic probe functions in a separately scoped review.
- **Not yet proven safe:** removal of any of the conditional candidates. The **absence of Cron or week-long log traffic is insufficient** to prove absence of an external consumer or close a rollback window.

## Proposed staged retirement — **separate explicit approval required**

1. **Inventory all consumers:** confirm with the owner whether any older Portfolio Dashboard, duplicated Sheets, Apps Script, external bookmarks, mobile dashboards or automation still accesses the legacy CSV URL or expects hidden tabs. Where possible, check a representative business/refresh cycle and provider logs, without exposing credentials.
2. **Snapshot and acceptance:** make an owner-approved backup of the current Google Sheet including hidden tabs/config; prove scanner `S&P500 Scanner` and `Valuation Map` output parity with current `v_scanner_current_v1`, access controls, refresh freshness and no formula errors. Preserve a documented rollback route and owner-selected observation window.
3. **Retire hidden consumers first:** in an independently reviewed Sheets-change step, remove or replace the three hidden legacy tabs' formulas (61 current references). Re-scan all surviving tabs to prove **zero references to `_Data`**. Do not remove `_Data` until this is verified.
4. **Gate legacy endpoint shutdown:** after owner approval, a distinct controlled Supabase change may disable the **legacy access row only**, and observe for errors/calls. **Do not disable the scanner access row or drop `dashboard_refresh_access`**. Keep a documented reversibility/rotation plan; avoid exposing token values.
5. **Separate irreversible cleanup:** only after sustained zero dependency, approved rollback closure and formal change review should a follow-up PR remove `dashboard-refresh-csv-v1` source/deployment (and, if independently unreferenced, the legacy-only payload/cache objects through explicit migrations). Keep migration history. Re-run scanner and portfolio-reconciliation tests before/after deployment.
6. **Diagnostic probes:** handle the five deployed dashboard probe functions in a separate least-privilege/security review, checking exposure and use; do not intermingle with scanner retirement.

## Follow-up acceptance checklist

- [x] PR #65 on `main` at baseline and docs-only scope confirmed.
- [x] Scanner has no direct `_Data` formula dependency in the two visible tabs.
- [x] Full live workbook scan found **61 hidden-tab formulas referencing `_Data`**.
- [x] No direct matching `pg_cron` jobs; legacy endpoint still ACTIVE; legacy credential row active.
- [x] One-week bounded Edge request-log sampling found no legacy function hits.
- [x] Shared scanner database views and shared auth table identified and protected.
- [ ] External consumers, Apps Script, Sheets copies, and rollback owner sign-off obtained.
- [ ] Backup + current scanner parity/refresh/regression acceptance recorded.
- [ ] Approved deprecation window completed and surviving tabs verified dependency-free.
- [ ] Separate code/deploy/data retirement PR reviewed, approved and verified.

## References

- [Focused Dashboard PR-A dependency audit](FOCUSED_DASHBOARD_PR_A_DEPENDENCY_AUDIT_20261019.md) — dated design and scanner separation
- [Archived PR-B handover](../archive/handovers/2026-10/FOCUSED_DASHBOARD_PR_B_CLEANUP_HANDOVER_20261019.md) — transition receipt; **historical only**
- [Legacy Dashboard Auto Refresh](../07_DASHBOARD_AUTO_REFRESH.md) — original feed contract and rollback risks
- [Documentation audit](../DOCUMENTATION_AUDIT_20261020.md) — earlier exclusions
- [Living FWIOS status](../CURRENT_STATUS.md) — next-task navigation

**Execution boundary:** This audit authorizes **no deployment, destructive Sheet mutation, table/function DDL, credential rotation/revocation, trade, accounting write or portfolio position change**.
