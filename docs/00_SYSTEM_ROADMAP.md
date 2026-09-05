# Focused Wealth Investment OS — Master System Roadmap

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract: **FWIOS-CONTRACT-0.87.4**  
Last updated: **2026-09-05 Asia/Bangkok**  
Execution mode: **HUMAN EXECUTION ONLY**

## Authority model
1. Latest reconciled portfolio/system/controller state.
2. Supabase `fwios` authoritative state.
3. GitHub logic / contracts / tests / migrations.
4. This roadmap as persistent status summary.
5. Google Sheets as view / compatibility / reconciliation / audit / export.

Live state overrides stale documentation.

## Current system state

| Item | Current state |
|---|---|
| Foundation | 0.87 |
| Contract | FWIOS-CONTRACT-0.87.4 |
| Research pipeline | RPV2.1 |
| Operating mode | DISCOVERY |
| Evidence-ready / valuation-ready | 18 / 13 |
| Decision coverage | 72.2% |
| Open root model blockers | 6 |
| Current sector | Communication Services — DONE |
| Next queued sector | Financials |
| Sector automation | PAUSED — manual Main Roadmap control |
| Supabase authority | Research + Valuation + Portfolio + Price/Mispricing + Portfolio Fit + Core Scoring + active Revision/Chase policies + Decision Snapshots |
| Portfolio execution | Human only |

Portfolio migration remains reconciled at 29/29 transactions and 16/16 positions. Existing concentration/crypto/focus deviations remain review flags, not automatic sell instructions.

---

# MAIN ROADMAP

## M1 — Research Pipeline v2
**Status: CORE HARDENING PASS / PERFORMANCE VALIDATION OPEN**

- [x] Run telemetry and 20→8→5→3 funnel.
- [x] RPV2.1 provenance/freshness/event-invalidation hardening.
- [x] Deterministic source routing.
- [x] Model-debt decoupling and fail-closed behavior.
- [ ] Parallel top-candidate performance validation.

Performance validation is an optimization and does not block M3.

## M2 — Decision Intelligence
**Status: PASS — PRODUCTION PROMOTION GATES LIVE**

- [x] Native Market Price / freshness.
- [x] Mispricing engine.
- [x] Portfolio migration/reconciliation.
- [x] Portfolio Fit from reconciled state.
- [x] Native 30/30/25/15 core scoring.
- [x] Comparable consensus evidence for PINS/RDDT.
- [x] `POL-REVISION-SCORE-V1` deterministic raw→score policy.
- [x] `POL-CHASE-SCORE-V1` deterministic raw→risk policy.
- [x] 16/16 decision-policy regressions PASS, including missing-data fail-closed boundaries and PINS/RDDT production parity.
- [x] V2 Decision Snapshots rebuilt against ACTIVE policy versions.

### M2 reference decisions

| Candidate | Core | Revision | Chase | Mispricing | Promotion / State |
|---|---:|---:|---:|---|---|
| PINS | 87.60 | 60.5531 PASS | 0.0000 PASS | PASS | **PASS — READY - HUMAN REVIEW** |
| RDDT | 72.15 | 71.4010 PASS | 12.2748 PASS | FAIL — insufficient mispricing | **GOOD COMPANY - WAIT FOR VALUE** |

PINS READY means the system gates pass on the recorded decision snapshot; it is not an instruction to trade. Broker price verification and live portfolio reread are still mandatory before any real investment recommendation/execution decision.

M2 exit criteria are satisfied: decisions are reproducible from traceable inputs and active deterministic policy versions, while missing/incomplete critical inputs fail closed.

## Architecture Consolidation v1
**Status: LIVE / M2 POLICY HARDENING INTEGRATED**

- [x] Supabase = State; GitHub = Logic/Contracts/Tests/Migrations; Sheets = View/Audit.
- [x] Generic policy registry/version governance.
- [x] Decision Snapshot reproducibility boundary.
- [x] Active Data Scoring, Mispricing, Portfolio Fit, Revision and Chase policy families.
- [x] M3 scenario foundation tables.
- [x] M4 event foundation table, no production triggers.
- [ ] Reduce user-facing Sheet surface only after M3 traceability/cutover passes.

## M3 — Opportunity & Capital Allocation
**Status: READY — NEXT MAIN MILESTONE**

Implementation order:
1. Supabase-native Opportunity Ranking sourced only from production Decision Snapshots.
2. New-cash Capital Allocation engine.
3. Portfolio Scenario Simulation.
4. Rebalancing Recommendation.
5. Human Approval workflow/output.

Required scenario modes:
- `NO_SELL`
- `SOFT_REBALANCE`
- `ACTIVE_REBALANCE`

Required outputs:
- where new cash should go;
- exact trim/add amounts when justified;
- before/after weights;
- expected portfolio-upside change;
- concentration/theme/crypto/focus effects;
- downside/guardrail changes;
- source Decision Snapshot and portfolio-batch traceability.

M3 rules:
- new cash first;
- soft rebalance before hard trim;
- never trim only because a winner appreciated;
- scenario runs never mutate live holdings;
- no auto-trading;
- hard trim requires explicit economic/risk justification;
- M3 cutover requires transaction/position/cost-basis/allocation traceability with no unexplained differences.

## M4 — Autonomous Investment OS
**Status: PENDING M3**

Future work includes scheduled/delta research refresh, thesis/material-change refresh, opportunity refresh, concentration alerts, blocker recovery and event-driven orchestration. `system_events` remains foundation-only until explicitly activated and regression-tested.

---

# Remaining model debt / side quests

Fail-closed coverage debt remains separate from M3 readiness:
1. QCOM Semiconductor Designer — 73.80
2. Streaming / Media — 73.70
3. BALL Packaging — 73.45
4. AMAT Semiconductor Equipment — 72.00
5. MP Magnetics full-company NAV — 71.55
6. Telecom — 12.00

Financials remains queued; sector automation stays manually paused while M3 is the Main Roadmap priority unless live controller/roadmap is explicitly changed.

---

# Immediate next action

**Begin M3 Opportunity Ranking / Capital Allocation foundation on production Decision Snapshots.**

1. Define Opportunity Ranking contract and deterministic rank inputs.
2. Ensure only Promotion PASS candidates can enter immediate-buy ranking; WAIT/FAIL/BLOCKED candidates remain separately visible.
3. Build new-cash deployment first.
4. Build scenario simulation without portfolio mutation.
5. Add trim/add logic only after scenario math and portfolio traceability regressions pass.
6. Keep Rebalance policy DRAFT until those tests pass.

---

# Documentation/update rule
Before material work read `AGENTS.md`, `contracts/system-contract.yaml`, `VERSION`, this roadmap, `docs/01_SYSTEM_ARCHITECTURE.md`, live `System_Foundation`, and relevant Supabase/Sheet controller state. After material work synchronize roadmap/architecture/live foundation when authority, capability, blocker, contract, milestone or next action changes.
