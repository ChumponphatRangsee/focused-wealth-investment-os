# FWIOS — Legacy Dashboard Dependency & Retirement Audit

**Inspection:** 2026-10-23 (Asia/Bangkok). **GitHub baseline:** `main` at `51eb5bcaf7e7904de190e43a0ebd34966a199e7d` (merged PR #65). **Supabase project:** `ysjbmeukwbfnxnwqchuq`. **Google Sheet:** `Focused Wealth Dashboard - Chumponphat`.

> **RUNTIME EDGE RETIREMENT UPDATE — 2026-10-23 (Asia/Bangkok).** Supabase `dashboard-refresh-csv-v1` was updated from v7 to **ACTIVE v8** with `verify_jwt=true` and an intentionally inert source that returns **410 Gone** without accessing the database, cache, credentials or portfolio data. All five existing `dashboard-refresh-*-probe-v1` Functions were read back and already contain **410 Gone** inert handlers with `verify_jwt=true`. **All six function slugs remain deployed**; *no actual platform deletion / undeploy has happened*. See [GitHub issue #68](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/68) for the operator-only physical undeploy requirement. The source tombstone and a static regression test are included in the accompanying PR. The original historical audit below is retained unchanged as point-in-time evidence.

## 2026-10-23 Edge Function tombstone deployment evidence

- Read live `dashboard-refresh-csv-v1` after deployment: `version=8`, `status=ACTIVE`, `verify_jwt=true`, `index.ts` implements `status: 410`, no Postgres import or `SUPABASE_DB_URL` access. **Live HTTP execution was not independently exercised**, and `verify_jwt=true` may block unauthenticated requests at the gateway before they reach the 410 body.
- Read all five separate diagnostics: `dashboard-refresh-probe-v1`, `dashboard-refresh-env-probe-v1`, `dashboard-refresh-db-probe-v1`, `dashboard-refresh-query-probe-v1`, and `dashboard-refresh-role-probe-v1` each still show `status=ACTIVE`, `verify_jwt=true`, a 410 handler, and no DB imports.
- Scanner `scanner-refresh-csv-v1` remained `ACTIVE v4` with its original authentication model. `GOOGLE_SHEET_SCANNER_IMPORTDATA` remained `active=true`, old `GOOGLE_SHEET_IMPORTDATA` remained `active=false`, and `fwios.v_scanner_current_v1` still returned **64 rows**. The original Google Sheet retained exactly its four scanner and valuation tabs and a spot-check showed populated rows without formula errors.
- A first attempted deployment failed because the legacy version's import map used an obsolete temporary path. **No production version changed on that failed attempt**. The successful second deployment explicitly supplied `deno.json` and `import_map_path="deno.json"`.
- The platform deletion capability is **not available through the connected Supabase actions**. Keep [issue #68](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/68) open until an authorized operator undeploys the exact six obsolete names using Supabase Dashboard/CLI and verifies they no longer appear in inventory. Do not conflate returning 410 with undeployment.
- **No SQL, schema, access key, scanner view, cron, portfolio or trade mutation** was made during this deployment. Preserve `fwios.dashboard_refresh_access`, `fwios.v_dashboard_valuation_map`, and `fwios.v_thesis_tracking_current`.

---
> **POST-AUDIT EXECUTION RECEIPT — 2026-10-23 (Asia/Bangkok).** The original dependency matrix and HOLD decision below describe the state *before* the user's external-consumer confirmation and the controlled cleanup. The retirement of the **Google Sheets legacy tabs and the legacy auth row** was carried out and verified. **The legacy Edge Function is still deployed**, and shared Supabase objects must remain. This is a partial, reversible cutover — **not** permission to drop SQL objects or delete deployed functions.

## Post-audit execution — 2026-10-23

**Operator confirmation:** the user confirmed no additional apps or external consumers; the Dashboard's Apps Script had been deleted; the maintained Dashboard receives market/scanner data from Supabase. This is an owner statement, not proof that no historic token URLs have ever circulated.

**Backup and safety proof:** a private native Google Sheets backup created 2026-10-23 was verified against the live source: **8 tabs** retained with matching hidden states/grid dimensions, and **2,656 non-empty user-entered cells matched**, including formulas. The backup remains distinct and owner-only. Its ID, token-bearing hidden URLs, and raw credential values are intentionally not stored in public GitHub. The copy can recalculate imported values and is not a frozen market-price export.

**Actions applied to the original `Focused Wealth Dashboard - Chumponphat`:**

1. After re-reading live tab IDs and verifying no direct dependencies from the surviving scanner tabs, deleted the three hidden legacy display tabs `Dashboard`, `Thesis Tracker`, and `Opportunity Quality`; the scanner data/output still loaded with no observed visible formula errors.
2. Re-read all remaining user-entered formulas, confirmed **zero** references to legacy `_Data` or deleted tabs, and deleted the hidden `_Data` tab.
3. Verified the original now has **four tabs only**: visible `S&P500 Scanner` and `Valuation Map`, hidden `_Scanner_Data` and `_Scanner_Config`. Fresh targeted reads of both visible tabs and scanner helper were error-free.
4. Used a guarded SQL **data-only UPDATE** to set `active=false` **only** for `fwios.dashboard_refresh_access.access_key='GOOGLE_SHEET_IMPORTDATA'`. Verified `GOOGLE_SHEET_SCANNER_IMPORTDATA` remains `active=true`. No secret, token hash, row, table or function was deleted.
5. Rechecked `fwios.v_scanner_current_v1` still returns **64 rows**. Rechecked both legacy and scanner Edge Functions remain deployed ACTIVE; the legacy endpoint is **not retired at the platform level**.

**Rollback:** the private backup retains the old tabs and entered formulas. Recreating removed tabs requires owner-approved restore/copy (do not replace the current scanner tabs blindly). The legacy access flag can be enabled only through a separately authorized, audited action after validating secret handling, consumer needs and current security. Never reuse leaked or public URL tokens.

**Left open:**

- Deployed `dashboard-refresh-csv-v1` (**ACTIVE v7**) and its GitHub source remain: API callers should be rejected through inactive legacy access-row gating, but **this response behavior was not probed using a token**.
- Five older `dashboard-refresh-*-probe-v1` endpoints also remain deployed and require a separate exposure/consumer audit and platform deletion process.
- `fwios.dashboard_refresh_payload_v1()` and `dashboard_refresh_cache` persist as legacy-only candidates. **Keep** shared `dashboard_refresh_access`, `v_dashboard_valuation_map`, `v_thesis_tracking_current` and all migrations/tests until dependency-proven separate cleanup.
- A full trading-session fresh-data/E2E check and platform-level function retirement are still outstanding. PR merged status does not prove this.

---
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
