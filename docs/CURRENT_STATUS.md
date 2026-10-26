# FWIOS — Current Status / New-Chat Entry Point

> **Navigation index, not operational authority.** GitHub docs-only strategy review **2026-10-23 (Asia/Bangkok)** based on `main` commit `be59ab3348b3955be1f6584ff6c8aa8ebc1d9e85`. The legacy Dashboard workstream has its own dated Supabase/Sheets/cron/Edge execution receipt from 2026-10-23; **this strategy-documentation review did not repeat that runtime verification**. **Other workstreams and current performance were not comprehensively re-verified**; re-check relevant systems before acting. Update this index when workstream state materially changes; do not treat its PR state as live indefinitely.

## Mandatory read / execution order

1. Read [AGENTS.md](../AGENTS.md) and [system-contract.yaml](../contracts/system-contract.yaml); preserve human-execution-only and financial-accounting guardrails.
2. Read this index to find the **one** relevant feature plan, current PR, and any known blockers.
3. Check the current `main`, head/base of open PRs, and latest CI; inspect **actual live** Supabase/Sheets/cron/worker state whenever work would touch production.
4. Read the feature's implementation plan/runbook and current GitHub issue/PR before edits. Treat dated handover observations as historical evidence.
5. Make scoped changes in a separate PR; update this index after merging or accepted cutover. Reconcile any discrepancy before action.

## Repository / source precedence

- Repository: [focused-wealth-investment-os](https://github.com/ChumponphatRangsee/focused-wealth-investment-os), default branch: `main`.
- GitHub main baseline used for the 2026-10-23 strategy-documentation change: `be59ab3348b3955be1f6584ff6c8aa8ebc1d9e85` (re-check on each new session).
- **Live operational truth > deployed source and current merged contracts > latest verified feature evidence > this dated index > archived handovers.**
- The active system contract controls execution safety. Historic architectural handover prose does **not** authorize a production cutover.

## Next-chat handover — SEC Shadow → Financial Metrics (2026-10-26)

- **Start with:** [FWIOS MVP-1 SEC-to-Metrics Handover](implementation/FWIOS_MVP1_SEC_TO_METRICS_HANDOVER_20261026.md). This is the current work-item handoff; older plans must be read in its context.
- **Latest read-only diagnosis:** Existing weekday SEC schedule successfully stores `SEC_SUBMISSIONS` and `SEC_COMPANY_FACTS` in `fwios.decision_refresh_shadow_evidence`. The Worker intentionally runs in `SHADOW` with `authoritative_write=false`, does **not** persist normalized canonical `metric_observations` or trigger a new valuation. `research_ingest_receipts_v1` still had 0 entries on 2026-10-26.
- **Immediate task:** Audit ACN Oct 16 10-K vs canonical metrics/model requirements; propose/implement a minimal deterministic SHADOW-to-controlled-PREVIEW normalized payload bridge, with read-only testing and a scoped PR. Then handle JPM and NFLX. **No new SEC Cron, new Dashboard, schema redesign or auto-trading.**
- **Authority:** This handover/docs PR does not approve controlled `APPLY`, production writes, production revaluation, worker deployment, scheduling changes or cutover. Preserve existing Contract and read-only-first workflow.

## MVP-1 scope correction — existing Valuation Map + Data Reliability, no new UI (2026-10-26)

- **Owner clarified goal:** do **not** build a separate dashboard/tab/report. Use the existing [Focused Wealth Dashboard / Valuation Map](https://docs.google.com/spreadsheets/d/17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8/edit) for display. MVP-1 measures **data capture completeness, correctness and freshness** for tracked stock prices, issuer financial facts, model inputs and revaluations. [Revised audit and acceptance checklist](implementation/FWIOS_MVP_FIRST_WORKING_SLICE_20261026.md).
- **Price data (verified read-only):** last completed US session 2026-10-23; 64/64 accepted Twelve Data EOD stock observations each trading day Oct 19–23, all Tier-A PASS and URLs present. 13 independent Alpha Vantage overlap prices on Oct 23 differ 0–0.0261%; do **not** assert all 64 independently cross-checked.
- **Valuation Map parity:** existing Google Sheet's 28 valued rows match backend 28 rows for price date, price, Bear/Base/Bull/PW Fair Value and upside within displayed rounding. Valuation dates are Sep 4–11, despite Oct 23 price session.
- **Financial ingestion freshness — confirmed gap:** 453 `metric_observations` rows covering 28/64 tracked instruments; last database metric ingestion Sep 30 and newest stored source `reported_at` Sep 10. ACN's stored metrics last reported Jun 18 (issuer Q4 FY26 Oct 1), JPM Jul 14 (issuer Q3 Oct 13), NFLX Jul 16 (issuer Q3 Oct 20). Their latest source filings must be triaged and verified before claiming current Fair Value. The current ten active cron names contain no independently established scheduled canonical financial-metric ingest.
- **Immediate delivery item:** pilot source/evidence/period/unit audit and missing/latest earnings capture for ACN/JPM/NFLX, then manual verified `PREVIEW`; controlled `APPLY`/production revaluation **only with separately explicit authorization**, and validate the existing Valuation Map afterward. No new table, scheduler, spreadsheet UI, score/quality threshold or trading.
- **Previous MVP SQL report:** stays as a read-only diagnostic; not a UI to implement. Previously named "read-only user-facing report" next action is **superseded**.

## MVP-first owner reprioritization and read-only E2E audit — 2026-10-26

- **Active delivery priority: Phase 1 Working MVP**, not Research Attention #38, autonomous research scheduling, all-S&P500 expansion, portfolio rotation or backtesting. The [MVP-first working-slice plan and read-only audit](implementation/FWIOS_MVP_FIRST_WORKING_SLICE_20261026.md) is the new scoped execution entrypoint.
- **Authorization scope:** roadmap/docs update and read-only E2E inspection; production schema/data, RLS, price jobs, scoring thresholds, policies, Google Sheets transactions and trading were **not modified**. New research APPLY and any production cutover require separate consent and regression acceptance.
- **Live Supabase read-only checks (2026-10-26):** 64 stocks in readiness view; 27 research-ready, 27 valuation-ready, 1 quality-hardened, 1 investment-review-ready. Scanner v1 scored/ranked 27 stocks; its score **does not mean investment-review-ready**. ACN readiness is READY but the independent old dashboard valuation map says `PRICE VERIFY`; preserve both meanings. ADBE's latest valuation and older hardening snapshot are not lineage-aligned, while PINS carries quality review and stale/conflicted legacy mispricing/decision signals. These are **acceptance/test cases**, not recommendations.
- **Next action:** the [MVP pilot SELECT](../queries/mvp_readonly_fair_value_status_v1.sql) has now returned 3/3 rows from existing views in live read-only inspection (ACN positive readiness but independent legacy-gate disagreement; ADBE lineage mismatch; PINS quality review). **Use the tested SQL only for investigation of freshness/lineage; do not build a new user-facing page.** Verify the existing Valuation Map data reliability and missing current financial inputs first, then fix one proven gap per separately reviewed PR. No runtime feature is yet deployed by this change.
- **Deferred:** Issue #38 remains OPEN but is **future backlog** until manual MVP and real resource constraints justify attention ranking/queues; Issue #39 remains cutover-gated. The proposed five-table attention schema is not approved. Scanner v2 and U1 are not automatically resumed.
- **Merge/deployment boundary:** check GitHub PR status for this roadmap/SELECT-only change; even a merge does **not** deploy a new end-user MVP report, adjust production gates or prove user-facing acceptance.

## Strategy documentation merge receipt — 2026-10-23

- [PR #70](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/70) **MERGED** into `main` at GitHub merge commit `f752f5c53441b0443e6d1660cfe31f6d733ea6f0`. The change is exclusively 4 Markdown files: an updated [master roadmap](00_SYSTEM_ROADMAP.md), new [Value / Entry / Rotation plan](implementation/VALUE_ENTRY_ROTATION_STRATEGY_ROADMAP_20261023.md), README navigation and this index. At review, 50 local links checked with 0 broken.
- The strategy remains **PROPOSED**, not implemented/approved for production. It does **not** authorize ChatGPT scheduling, research APPLY automation, database writes, valuation policy changes, trading, scanner cutover or portfolio mutation. No CI check run was reported for PR #70; do not claim CI PASS.
- [Epic #31](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/31) checklist reconciled: #35/#36/#37 closed and foundation-complete; **production read cutover remains separately gated**. [Issue #38](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/38) now contains **design-only** attention/selection/promotion/demotion requirements and remains OPEN, with no implementation authorized. Issue #39 also remains OPEN.
- **Superseded next step (2026-10-26):** Phase 1 MVP read-only report acceptance and focused E2E blocker repair take precedence. Research-attention design #38 is deferred; Scanner v2 and U1 S&P 500 expansion remain separately paused.

## Workstreams (verified GitHub status versus older feature snapshots)

| Stream | GitHub state at index creation | Next source to read / validation |
| --- | --- | --- |
| **Portfolio native pricing / Phase 1** | PRs #49–#57 documented as merged by the 2026-10-19 receipt; current live pricing and autonomous E2E acceptance **not checked here** | [Phase-1 snapshot](implementation/FWIOS_PHASE1_HANDOVER_20261019.md), [acceptance](implementation/PHASE1_P3_P4_P5_ACCEPTANCE_20261017.md). Check current scheduled US-close outcomes first. |
| **Daily Performance Backend / historical backfill** | Dedicated plan/handover exists; **do not infer feature is deployed** without live verification | [Feature plan](implementation/PHASE1_DAILY_PERFORMANCE_BACKEND_HANDOVER_20261019.md); start schema/writer/reconciliation only after checking actual Supabase/Sheets state and relevant PRs. |
| **Focused Dashboard / S&P 500 expansion** | Scanner separation PR [#59](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/59) and cleanup PR [#60](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/60) merged. Prior 2026-10-19 evidence listed **64 stock instruments**, not full S&P 500; not independently checked today. | [Universe expansion plan](implementation/SP500_UNIVERSE_EXPANSION_PLAN_20261019.md); check membership/source-of-truth design and live row counts before U1 implementation. |
| **Controlled Research / Scanner v2** | PR [#61](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/61), [#62](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/62), and research-readiness PR [#63](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/63) are merged. PR #63 completed **21/21** readiness acceptance before merge; Scanner v2 is not part of this cleanup. | [Research workflow](implementation/CHATGPT_RESEARCH_WORKFLOW_V1.md), [controlled ingest](implementation/PR2_CONTROLLED_RESEARCH_INGEST_V1.md), [PR4 readiness](implementation/PR4_RESEARCH_READINESS_FAIL_CLOSED_V1.md). Next **scanner-specific** implementation step: Scanner v2 (not started by this documentation PR). The 2026-10-26 owner decision **defers Issue #38** until after Phase 1 MVP acceptance; do not conflate it with current delivery. U1/full S&P 500 expansion remains paused unless explicitly resumed. |
| **Value / Entry / Rotation strategy — future feature overlay** | Owner-approved MVP-first prioritization replaces D1–D6 as the **immediate** execution order; no runtime/production change. Future strategy choices still require explicit authorization. | [MVP-first working slice](implementation/FWIOS_MVP_FIRST_WORKING_SLICE_20261026.md), [future strategy overlay](implementation/VALUE_ENTRY_ROTATION_STRATEGY_ROADMAP_20261023.md). #38/#39 remain future gated tasks. |
| **External API inventory / security** | Audit PR [#48](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/48) **open**, not merged (checked 2026-10-20). | Review PR #48 before asserting audit closure or changing vendor credentials. |

## Non-negotiable guardrails

- `auto_trade=false`, human execution only. No autonomous order placement.
- Do not mutate Transactions, quantity, cost basis, realized P&L, cash, accounting formulas or portfolio holdings during documentation or scanner work.
- For Phase 1, `Investment Portfolio Tracker - Chumponphat` remains the accounting/transaction authority as recorded in the relevant Phase-1 implementation decisions. Do not create a duplicate transaction ledger.
- Scanner presentation remains portfolio-independent. Preserve quota-aware shared market-data infrastructure and avoid expensive all-constituent deep research.
- A successful GitHub merge **does not prove** production deployment or autonomous E2E success. Confirm receipts, timestamps and current backend state.

## Documentation hygiene — audited 2026-10-20

- Latest merged contract as of this GitHub inspection: `FWIOS-CONTRACT-0.87.19` in AGENTS and system-contract YAML. PR #65 is **merged** as of 2026-10-23; README and VERSION align with `FWIOS-CONTRACT-0.87.19` on the inspected `main`. Re-check `main` on future sessions.
- [Documentation audit and classification](DOCUMENTATION_AUDIT_20261020.md): in-place legacy banners, historical evidence archives, files retained due to active dependencies and explicit deferred code retirement.
- The old Dashboard CSV function is still deployed as a rollback-only path in prior checked Supabase evidence; repository docs must not authorize deleting its deployed endpoint or shared valuation/thesis views.

## Legacy Dashboard — fail-closed runtime retired, physical undeploy pending (2026-10-23)

- [Execution receipt and live Edge verification](implementation/LEGACY_DASHBOARD_RETIREMENT_AUDIT_20261023.md). User confirmed no external clients / old Apps Script; private complete Google Sheet backup remains owner-only.
- Current Focused Wealth Dashboard retains only `S&P500 Scanner`, `Valuation Map`, hidden `_Scanner_Data` and `_Scanner_Config`; old `Dashboard`, `Thesis Tracker`, `Opportunity Quality`, `_Data` removed.
- Legacy access `GOOGLE_SHEET_IMPORTDATA` is **inactive**; scanner access `GOOGLE_SHEET_SCANNER_IMPORTDATA` remains **active**; `fwios.v_scanner_current_v1` returned **64 rows** after the runtime change.
- **Legacy CSV endpoint replaced with inert 410 tombstone:** deployed `dashboard-refresh-csv-v1` `ACTIVE v8`, `verify_jwt=true`, no database/portfolio reads. Five dashboard diagnostic probes already deploy inert 410 handlers with JWT verification. **All six slugs still exist on Supabase**.
- **Physical undeploy pending:** [Issue #68](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/68). Connected Supabase tools cannot undeploy functions; use a separate authorized platform action and verify inventory. Live HTTP invocation and full-trading-session E2E acceptance are not proven by a source/readback check.
- **Never drop:** shared `fwios.dashboard_refresh_access` table, `v_dashboard_valuation_map`, `v_thesis_tracking_current`, scanner Edge Function, or historical migrations.

## Documentation map

- **Current index:** this file, kept concise; update on meaningful workflow changes, not every Chat.
- **Contracts:** [AGENTS](../AGENTS.md) and [system contract](../contracts/system-contract.yaml).
- **Architecture:** [FWIOS v3](architecture/FWIOS_ARCHITECTURE_V3.md) (verify approved vs proposed decisions), [Master System Roadmap](00_SYSTEM_ROADMAP.md), and the **proposed, not implemented** [Value / Entry / Rotation strategy plan](implementation/VALUE_ENTRY_ROTATION_STRATEGY_ROADMAP_20261023.md).
- **Active handoff details:** [Phase-1 dated snapshot](implementation/FWIOS_PHASE1_HANDOVER_20261019.md) and [Daily Performance feature handover](implementation/PHASE1_DAILY_PERFORMANCE_BACKEND_HANDOVER_20261019.md); these are **dated evidence**, not live state.
- **Historical handovers:** [archive index](archive/handovers/README.md); old paths remain short compatibility pointers only.
- **Rules for upkeep:** [Documentation lifecycle](DOCUMENTATION_LIFECYCLE.md).

## On next material change

Record: date/timezone; checked GitHub commit and relevant PR state; verified or unverified live environment; completed scope; open blockers; exact next action; links to source evidence. Avoid numerical pricing or account-value snapshots in this index unless they are necessary and time-stamped.
