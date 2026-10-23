# FWIOS — Current Status / New-Chat Entry Point

> **Navigation index, not operational authority.** GitHub docs-only strategy review **2026-10-23 (Asia/Bangkok)** based on `main` commit `be59ab3348b3955be1f6584ff6c8aa8ebc1d9e85`. The legacy Dashboard runtime receipts below reflect their own earlier verification times; this review did **not** repeat Supabase or Sheet verification. The legacy Dashboard subset of Supabase/Google Sheets/cron/Edge state was re-checked and partially retired on 2026-10-23 (see execution receipt). **Other workstreams and current performance were not comprehensively re-verified**; re-check relevant systems before acting. Update this index when workstream state materially changes; do not treat its PR state as live indefinitely.

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

## Workstreams (verified GitHub status versus older feature snapshots)

| Stream | GitHub state at index creation | Next source to read / validation |
| --- | --- | --- |
| **Portfolio native pricing / Phase 1** | PRs #49–#57 documented as merged by the 2026-10-19 receipt; current live pricing and autonomous E2E acceptance **not checked here** | [Phase-1 snapshot](implementation/FWIOS_PHASE1_HANDOVER_20261019.md), [acceptance](implementation/PHASE1_P3_P4_P5_ACCEPTANCE_20261017.md). Check current scheduled US-close outcomes first. |
| **Daily Performance Backend / historical backfill** | Dedicated plan/handover exists; **do not infer feature is deployed** without live verification | [Feature plan](implementation/PHASE1_DAILY_PERFORMANCE_BACKEND_HANDOVER_20261019.md); start schema/writer/reconciliation only after checking actual Supabase/Sheets state and relevant PRs. |
| **Focused Dashboard / S&P 500 expansion** | Scanner separation PR [#59](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/59) and cleanup PR [#60](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/60) merged. Prior 2026-10-19 evidence listed **64 stock instruments**, not full S&P 500; not independently checked today. | [Universe expansion plan](implementation/SP500_UNIVERSE_EXPANSION_PLAN_20261019.md); check membership/source-of-truth design and live row counts before U1 implementation. |
| **Controlled Research / Scanner v2** | PR [#61](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/61), [#62](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/62), and research-readiness PR [#63](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/63) are merged. PR #63 completed **21/21** readiness acceptance before merge; Scanner v2 is not part of this cleanup. | [Research workflow](implementation/CHATGPT_RESEARCH_WORKFLOW_V1.md), [controlled ingest](implementation/PR2_CONTROLLED_RESEARCH_INGEST_V1.md), [PR4 readiness](implementation/PR4_RESEARCH_READINESS_FAIL_CLOSED_V1.md). Next feature step after documentation cleanup: Scanner v2; keep U1/full S&P 500 expansion paused unless explicitly resumed. |
| **Value / Entry Timing / Portfolio Rotation strategy — PROPOSED** | **Documentation only; no code, policy, schedule or production behavior change.** Target objective: find evidence-backed undervaluation, enter only after price/risk review, and compare holding with risk-adjusted rotation opportunities. The plan reuses current hard gates and human approval; it is not a new automated investment engine. | [Strategy roadmap](implementation/VALUE_ENTRY_ROTATION_STRATEGY_ROADMAP_20261023.md), [Master roadmap](00_SYSTEM_ROADMAP.md). Design dependencies: [#31](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/31) / [#38](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/38); do not activate schedules or implement until separately approved. |
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
