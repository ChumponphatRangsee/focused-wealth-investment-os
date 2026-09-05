# Focused Wealth Investment OS — Master System Roadmap

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract: **FWIOS-CONTRACT-0.87.3**  
Last updated: **2026-09-05 Asia/Bangkok**  
Execution mode: **HUMAN EXECUTION ONLY**

## Authority model

1. Latest reconciled portfolio/system/controller state.
2. Supabase `fwios` state for authoritative migrated layers.
3. GitHub contracts / logic / tests / migrations.
4. This roadmap as persistent project-status summary.
5. Google Sheets as view / compatibility / reconciliation / audit / export.

Live state overrides stale documentation.

## Current system state

| Item | Current state |
|---|---|
| Foundation | 0.87 |
| Contract | FWIOS-CONTRACT-0.87.3 |
| Research pipeline | RPV2.1 |
| Operating mode | DISCOVERY |
| Evidence-ready candidates | 18 |
| Valuation-ready candidates | 13 |
| Decision coverage | 72.2% |
| Open root model blockers | 6 |
| Current sector | Communication Services — DONE |
| Next queued sector | Financials |
| Sector automation | PAUSED while M2 Promotion hardening finishes |
| Supabase authority | Research + Valuation + Portfolio State + Market Price/Mispricing + Portfolio Fit + Scoring Core + Policy Registry + Decision Snapshot foundation |
| Portfolio execution | Human only |

Portfolio State migration reconciled 29/29 transactions and 16/16 positions. Latest recorded portfolio snapshot is approximately THB 340,906.10. Concentration/guardrail review remains required for NVDA (~41.25%), crypto (~38.09%) and 10 unique open assets versus preferred 5–8. These are review flags, not automatic sell instructions.

---

# MAIN ROADMAP

## M1 — Research Pipeline v2

**Status: CORE HARDENING PASS / PERFORMANCE VALIDATION OPEN**

- [x] Run telemetry.
- [x] Fast Discovery up to 20 → ~8.
- [x] Light Research ~8 → max 5.
- [x] Deep Research strongest ~3 first.
- [x] RPV2.1 evidence cache provenance/freshness/event invalidation hardening.
- [x] Deterministic source routing.
- [x] Model-debt decoupling.
- [x] Fail-closed regressions.
- [ ] Parallel top-candidate performance validation.

M1 performance validation is an optimization item and does not block M2.

## M2 — Decision Intelligence

**Status: CORE LIVE / PROMOTION-GATE HARDENING OPEN**

- [x] Native Market Price / freshness layer.
- [x] Mispricing engine.
- [x] Portfolio State migration and reconciliation.
- [x] Portfolio Fit from reconciled live state.
- [x] Native 30/30/25/15 core scoring.
- [x] Comparable consensus evidence recovered for PINS/RDDT.
- [ ] Version + regression-test Revision raw-evidence → component-score rubric.
- [ ] Version + regression-test Chase raw-data → risk-score rubric.
- [ ] Final fail-closed Promotion parity across stale price, stale earnings, missing portfolio context, incomplete valuation, Revision and Chase.

Current candidate state:

| Candidate | Core | Mispricing | Promotion state |
|---|---:|---|---|
| PINS | 87.60 | PASS | RESEARCH PRIORITY — blocked on Revision/Chase scoring |
| RDDT | 72.15 | FAIL insufficient margin of safety | GOOD COMPANY — WAIT FOR VALUE |

M2 exits only when a production decision can be reproduced from traceable state plus explicit active policy versions.

## Architecture Consolidation v1

**Status: FOUNDATION IMPLEMENTED**

Purpose: prevent M3/M4 from growing on top of dual authority and implicit scoring rules.

- [x] Define authority split: Supabase = State, GitHub = Logic/Contracts/Tests/Migrations, Sheet = View/Audit.
- [x] Add `fwios.policy_registry` and `fwios.policy_versions`.
- [x] Register active Data Scoring, Mispricing and Portfolio Fit policy families.
- [x] Register Revision, Chase and Rebalance policy families as DRAFT until deterministic mappings are implemented.
- [x] Add `fwios.decision_snapshots` reproducibility boundary.
- [x] Bridge current PINS/RDDT decisions into decision snapshots without changing gates.
- [x] Add M3 scenario foundation tables: allocation runs/actions/metrics.
- [x] Add `fwios.system_events` as future M4 event/delta foundation; no trigger enabled.
- [x] Preserve private-schema security model; advisor shows only expected RLS-no-policy INFO notices.
- [ ] Reduce Google Sheet user-facing surface after M3 traceability passes; do not delete tabs now.

Architecture Consolidation v1 is additive and does not bypass M2 Promotion hardening.

## M3 — Opportunity & Capital Allocation

**Status: PENDING M2 PROMOTION HARDENING**

Implementation order:

1. Opportunity Ranking from production Decision Snapshots.
2. Capital Allocation engine.
3. Portfolio Scenario Simulation.
4. Rebalancing Recommendation.
5. Human Approval.

Required scenario modes:

- NO_SELL
- SOFT_REBALANCE
- ACTIVE_REBALANCE

Required outputs include new-cash deployment, trim/add amounts, before/after weights, expected portfolio-upside change, concentration/theme changes and downside/guardrail changes.

M3 cutover requires source-transaction traceability with no unexplained quantity, cost-basis, realized-P&L or allocation differences. Scenario runs may not mutate the live portfolio.

## M4 — Autonomous Investment OS

**Status: PENDING M3**

- [ ] Scheduled sector discovery under controller/run-lock rules.
- [ ] Evidence freshness / delta refresh.
- [ ] Thesis-monitor material-change refresh.
- [ ] Opportunity refresh on material state changes.
- [ ] Concentration/allocation alerts.
- [ ] Blocker recovery.
- [ ] Event-driven/delta orchestration using `system_events` where justified.
- [ ] End-to-end audit trail to human-review recommendation.

---

# Remaining model debt / side quests

Open model debt remains fail-closed but does not block current M2 architecture/promotion work:

1. QCOM Semiconductor Designer — 73.80
2. Streaming / Media — 73.70
3. BALL Packaging — 73.45
4. AMAT Semiconductor Equipment — 72.00
5. MP full-company Magnetics NAV bridge — 71.55
6. Telecom — 12.00

Other side quests: parallel performance validation, dashboard polish, advanced thesis monitoring, AI-bubble/crisis tracking, XRP-specific enhancements and supplemental money-flow/news/sentiment layers.

---

# Immediate next action

**Finish M2 Promotion hardening on top of Architecture Consolidation v1.**

1. Define `REVISION_SCORE_V1` deterministic raw→score rubric and tests.
2. Define `CHASE_SCORE_V1` deterministic raw→risk rubric and tests.
3. Activate those policy versions only after regressions pass.
4. Rebuild PINS/RDDT Decision Snapshots against active policy versions.
5. Run final Promotion parity tests.
6. If M2 exits, begin M3 Opportunity Ranking / Capital Allocation using Decision Snapshots and scenario tables.
7. Keep Financials queued; do not auto-start while M2 remains the Main Roadmap bottleneck.

---

# Documentation/update rule

Before material work read `AGENTS.md`, `contracts/system-contract.yaml`, `VERSION`, this roadmap, `docs/01_SYSTEM_ARCHITECTURE.md`, live `System_Foundation`, and relevant Supabase/Sheet controller state.

After material work synchronize roadmap/architecture/live foundation when authority, capability, blocker, contract, milestone or next action changes.
