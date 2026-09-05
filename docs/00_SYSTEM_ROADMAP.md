# Focused Wealth Investment OS — Master System Roadmap

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract: **FWIOS-CONTRACT-0.87.6**  
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
| Contract | FWIOS-CONTRACT-0.87.6 |
| Research pipeline | RPV2.1 |
| Operating mode | DISCOVERY |
| Evidence-ready / valuation-ready | 18 / 13 |
| Decision coverage | 72.2% |
| Open root model blockers | 6 |
| Current sector | Communication Services — DONE |
| Next queued sector | Financials |
| Sector automation | PAUSED — M3 Main Roadmap priority |
| M2 Decision Intelligence | PASS |
| M3.1 Opportunity Ranking | PASS / PRODUCTION LIVE |
| M3.2 New-Cash Allocation | **PASS / PRODUCTION LIVE** |
| M3.3 Scenario Simulation | **NEXT** |
| Portfolio execution | Human only |

Portfolio migration remains reconciled at 29/29 transactions and 16/16 positions. Current review flags remain: 10 open assets, max single-stock weight ~41.25%, crypto ~38.09%. These are review flags, not automatic sell instructions.

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
- [x] `POL-REVISION-SCORE-V1` deterministic policy.
- [x] `POL-CHASE-SCORE-V1` deterministic policy.
- [x] 16/16 decision-policy regressions PASS.
- [x] V2 Decision Snapshots live.

Reference decisions:
- PINS: Promotion PASS / READY - HUMAN REVIEW.
- RDDT: Mispricing FAIL / GOOD COMPANY - WAIT FOR VALUE.

## Architecture Consolidation v1
**Status: LIVE / M2 + M3.1 + M3.2 INTEGRATED**

- [x] Supabase = State; GitHub = Logic/Contracts/Tests/Migrations; Sheets = View/Audit.
- [x] Generic policy registry/version governance.
- [x] Decision Snapshot reproducibility boundary.
- [x] Active Data Scoring, Mispricing, Portfolio Fit, Revision, Chase, Opportunity Ranking and New-Cash Allocation policies.
- [x] M3 scenario foundation tables.
- [x] M4 event foundation table, no production triggers.
- [ ] Reduce user-facing Sheet surface only after M3 traceability/cutover passes.

## M3 — Opportunity & Capital Allocation
**Status: IN PROGRESS**

### M3.1 Opportunity Ranking
**Status: PASS / PRODUCTION LIVE**

- [x] `POL-OPPORTUNITY-RANKING-V1` ACTIVE / deterministic.
- [x] Priority = existing Core Score; no second weighted score.
- [x] Promotion PASS → Immediate.
- [x] Mispricing-only FAIL → Value-Wait.
- [x] Max 3 Immediate / max 5 Watchlist / never force-fill.
- [x] 8/8 regressions PASS.
- [x] `OPPRANK-M3-20260905-01` PASS.

Current ranking:
- PINS → `IMMEDIATE_BUY_CANDIDATE`, rank 1, priority 87.6000.
- RDDT → `WATCHLIST_VALUE_WAIT`, rank 1, priority 72.1500.

### M3.2 New-Cash Capital Allocation
**Status: PASS / PRODUCTION LIVE**

Active policy: `POL-NEW-CASH-ALLOCATION-V1`.

Production behavior:
- consumes latest active Opportunity Ranking + latest reconciled portfolio batch;
- portfolio batch and ranking batch must match;
- only Immediate candidates can receive capital;
- v1 supports Stock candidates only;
- max one deployed asset per allocation run;
- new position starter cap = 5% post-money portfolio value;
- existing position staged add = min(5% post-money, headroom to 30% stock ceiling);
- existing stock above 30% gets zero add capacity;
- residual cash is held as `CASH_THB`;
- no force-fill into the second-ranked candidate;
- no sells/trims and no live portfolio mutation;
- concentration, crypto and position-count effects are surfaced as metrics.

Regression status: **20/20 PASS**.

Synthetic production-parity previews only:

| Requested new cash | PINS ADD | CASH_THB HOLD |
|---:|---:|---:|
| THB 10,000 | THB 10,000.00 | THB 0.00 |
| THB 50,000 | THB 19,545.30 | THB 30,454.70 |
| THB 100,000 | THB 22,045.30 | THB 77,954.70 |

RDDT receives zero because Value-Wait cannot bypass Mispricing.

No real `capital_allocation_run` has been materialized because no real user new-cash amount was supplied for this implementation step.

### M3.3 Portfolio Scenario Simulation
**Status: NEXT**

Required modes:
- `NO_SELL`
- `SOFT_REBALANCE`
- `ACTIVE_REBALANCE`

Required outputs:
- before/after weights;
- expected portfolio-upside change;
- concentration/theme/crypto/focus effects;
- downside/guardrail changes;
- source portfolio batch + Decision Snapshot + ranking + allocation traceability;
- zero live-portfolio mutation.

M3.3 should reuse the active New-Cash Allocation engine for the `NO_SELL` baseline before introducing soft/hard rebalance math.

### M3.4 Rebalancing Recommendation
**Status: PENDING M3.3**

Exact trim/add amounts require explicit economic/risk rationale. Never trim merely because a winner appreciated. `REBALANCE` policy remains DRAFT until scenario math and traceability regressions pass.

### M3.5 Human Approval / Cutover
**Status: PENDING**

M3 exits only when recommendations trace from source transactions → positions → portfolio batch → Decision Snapshot → Opportunity Ranking → allocation/scenario → human-review recommendation with no unexplained quantity, cost-basis, realized-P&L or allocation differences.

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

**Build M3.3 Portfolio Scenario Simulation on the live New-Cash Allocation engine.**

1. Define immutable scenario snapshot/input lineage.
2. Implement `NO_SELL` scenario using `POL-NEW-CASH-ALLOCATION-V1`.
3. Compute before/after position weights and guardrails.
4. Add expected portfolio-upside math from traceable valuation/Decision Snapshot inputs.
5. Add SOFT_REBALANCE and ACTIVE_REBALANCE only after the NO_SELL baseline passes.
6. Keep `REBALANCE` DRAFT and all scenarios non-mutating.

---

# Google Sheet rule during remaining M3
Google Sheets stays view/audit only. During M3.2–M3.5, write only `System_Foundation` / audit-status information; do not add new production policies, formulas or allocation logic to Sheet tabs.

---

# Documentation/update rule
Before material work read `AGENTS.md`, `contracts/system-contract.yaml`, `VERSION`, this roadmap, `docs/01_SYSTEM_ARCHITECTURE.md`, live `System_Foundation`, and relevant Supabase/Sheet controller state. After material work synchronize roadmap/architecture/live foundation when authority, capability, blocker, contract or next action changes.
