# FWIOS Documentation Audit — 2026-10-20 (Asia/Bangkok)

**Scope:** GitHub `main` at `b04ac30a9b3f14141247ed48b28c0c9692466d58`, plus previously checked read-only Supabase scheduler/function inventory. This is **documentation maintenance**, not a code/worker retirement approval. Check live state again before any production-facing action.

## Findings addressed by this cleanup

| Category | Files / outcome | Disposition |
| --- | --- | --- |
| **Version drift** | `VERSION` had `0.87.17`, README had `0.87.1`, while the merged `AGENTS.md` + system contract have `0.87.19` | Align `VERSION` and README to the merged contract; retain source contract snapshot date as historical metadata |
| **Stale entrypoint** | README highlighted a September Communication Services run as latest project state | Replace with `CURRENT_STATUS.md` entrypoint, move September result to historical evidence links |
| **Change history drift** | CHANGELOG last recorded 2026-09-11 | Add scoped October GitHub PR history, without claiming production deployment from a merge |
| **Completed historical work** | Consolidation v1, M2/M3 migration receipt and Sep 5 research closeout | Preserve full text under `docs/archive/legacy/2026-09/` with compatibility pointers at old paths |
| **Legacy docs with current-sounding language** | Sector loop, Blocked Orchestrator, valuation/scoring docs, Dashboard feed and provider shadow docs | Add point-in-time/scope banners to prevent old text overriding current contracts |
| **Research run evidence** | `docs/runs/20260906_financials_sector_run.md` | Keep in `docs/runs` as historical record with explicit date; not deletable evidence |

## Live-dependency exclusion list (do not delete in this cleanup)

- SQL migrations and regression tests: necessary reproducible history / QA even if unedited for over 21 days.
- Policies, core rules, and `scripts/check_closeout.py`: retain pending separate dependency/utility verification.
- `supabase/functions/decision-refresh-worker-v1`, `decision-refresh-provider-validator-v1`, `market-daily-close-worker-v1`: scheduled/existing service dependencies were observed; age is not retirement justification.
- Legacy `dashboard-refresh-csv-v1` function: no direct `pg_cron` invocation or other `fwios` SQL function reference was found at inspection, **but deployed endpoint and external rollback consumers were not cleared**. A separate retirement audit must verify access logs, Sheets references, credential rollback and deploy inventory.
- `fwios.v_dashboard_valuation_map` and `fwios.v_thesis_tracking_current`: current scanner view `fwios.v_scanner_current_v1` still references both, so they must **not** be dropped.
- Deployed diagnostic/probe functions may exist outside the repo tree. Identify real consumers and use a gated retirement plan, not directory-age rules.

## Future retirement gates

1. Enumerate code/database/Sheet/external references and active Supabase Edge functions.
2. Prove zero consumer dependence and an accepted rollback plan; mere absence of cron references is insufficient.
3. Separate Git file cleanup from `Supabase` function disable/delete and SQL object migration. Never auto-delete either by treating docs as runtime authority.
4. Implement any retirement in its own scoped PR and authorization; verify data integrity, tests and deployment afterward.

## Records retained

- [Current project index](CURRENT_STATUS.md)
- [Documentation lifecycle policy](DOCUMENTATION_LIFECYCLE.md)
- [Archived legacy receipts](archive/legacy/README.md)
- [Archived chat handovers](archive/handovers/README.md)

**Change scope:** Markdown/documentation plus `VERSION` metadata. No SQL DDL, schema, cron, API keys, Edge deploys, Google Sheet writes, portfolio transactions or trading changes.
