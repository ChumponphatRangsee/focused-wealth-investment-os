# Focused Wealth Investment OS — Master System Roadmap

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract: **FWIOS-CONTRACT-0.87.7**  
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
| Contract | FWIOS-CONTRACT-0.87.7 |
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
| M3.2 New-Cash Allocation | PASS / PRODUCTION LIVE |
| M3.3 Scenario Simulation | **PASS / PRODUCTION LIVE** |
| M3.4 Rebalancing Recommendation | **NEXT / VALUATION-COVERAGE GATED** |
| Portfolio execution | Human only |

Portfolio migration remains reconciled at 29/29 transactions and 16/16 positions. Current review flags: 10 open assets, max single-stock weight ~41.25%, crypto ~38.09%. These are review flags, not automatic sell instructions.

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
**Status: LIVE / M2 + M3.1 + M3.2 + M3.3 INTEGRATED**

- [x] Supabase = State; GitHub = Logic/Contracts/Tests/Migrations; Sheets = View/Audit.
- [x] Generic policy registry/version governance.
- [x] Decision Snapshot reproducibility boundary.
- [x] Active Data Scoring, Mispricing, Portfolio Fit, Revision, Chase, Opportunity Ranking, New-Cash Allocation and Portfolio Scenario policies.
- [x] Non-mutating scenario tables/functions.
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

Key behavior:
- active ranking + latest reconciled portfolio only;
- Immediate candidates only;
- max one deployed asset per run;
- new-position starter cap 5% post-money;
- existing add bounded by 5% staged increment and 30% stock ceiling;
- residual cash held; no force-fill;
- no sells/trims and no live mutation.

Regression status: **20/20 PASS**.

Synthetic parity only:
| Requested new cash | PINS ADD | CASH_THB HOLD |
|---:|---:|---:|
| THB 10,000 | THB 10,000.00 | THB 0.00 |
| THB 50,000 | THB 19,545.30 | THB 30,454.70 |
| THB 100,000 | THB 22,045.30 | THB 77,954.70 |

No real allocation run exists because no real user cash amount was supplied for materialization.

### M3.3 Portfolio Scenario Simulation
**Status: PASS / PRODUCTION LIVE**

Active policy: `POL-PORTFOLIO-SCENARIO-V1`.

Production behavior:
- `NO_SELL`: positive new cash; no trim; reuses M3.2 allocation logic.
- `SOFT_REBALANCE`: no trim in v1; one-time new-cash math intentionally equals NO_SELL until recurring DCA/redirection state exists.
- `ACTIVE_REBALANCE`: accepts hypothetical trim inputs for simulation only; it does not select which asset should be trimmed.
- trim must target current holding, stay within current value and include explicit economic/risk rationale.
- appreciation-only trim rationale is forbidden.
- ADD remains constrained by active ranking + Decision Snapshot + allocation capacity.
- before/after position weights, concentration, crypto, focus, residual cash and valuation coverage are surfaced.
- previews do not mutate holdings or create orders.

Regression status: **28/28 PASS**.

#### Expected-upside coverage gate
Current holdings expected-upside valuation coverage at activation = **0%**.

Therefore:
- full portfolio probability-weighted expected upside is **BLOCKED - INCOMPLETE PORTFOLIO VALUATION COVERAGE**;
- no cost-basis return, historical performance or narrative target is substituted;
- PINS ADD-side expected value is computable from exact `DEC-PINS-M2-20260905-V2 → MIS-PINS-20260904` lineage;
- an ACTIVE scenario trimming an uncovered holding such as NVDA blocks the net expected-value comparison.

This is a current-data coverage gate, not a scenario-engine regression failure.

Synthetic reference NO_SELL 50k:
- PINS ADD THB 19,545.30; cash THB 30,454.70.
- PINS post-money weight ~5%.
- max single stock ~41.25% → ~35.98%.
- crypto ~38.09% → ~33.22%.
- full portfolio expected upside remains blocked.

Synthetic ACTIVE input example only:
- hypothetical NVDA trim THB 10,000 + new cash 0 → simulator can route THB 10,000 to PINS under current capacity;
- concentration ~41.25% → ~38.32%;
- net expected-value change is blocked because NVDA lacks traceable expected-return valuation;
- this is **not** a trim recommendation.

No real `portfolio_scenario_run` has been materialized during implementation.

### M3.4 Rebalancing Recommendation
**Status: NEXT / VALUATION-COVERAGE GATED**

Before producing exact economic trim/add recommendations:
1. close traceable current valuation / expected-return coverage for relevant trim candidates;
2. start with NVDA as a coverage priority because it is the largest concentration review item — this prioritizes modeling only and does not imply it should be sold;
3. compare retained expected return vs candidate expected return using reproducible valuations;
4. combine opportunity cost, concentration, theme, crypto/focus and downside effects;
5. only then allow deterministic trim-size recommendation regressions.

`REBALANCE` remains DRAFT. Never recommend trimming merely because a winner appreciated.

### M3.5 Human Approval / Cutover
**Status: PENDING M3.4**

M3 exits only when recommendations trace from source transactions → positions → portfolio batch → Decision Snapshot → Opportunity Ranking → allocation → scenario → recommendation → human approval with no unexplained quantity, cost-basis, realized-P&L or allocation differences.

## M4 — Autonomous Investment OS
**Status: PENDING M3**

Future work includes scheduled/delta research refresh, thesis/material-change refresh, opportunity refresh, concentration alerts, blocker recovery and event-driven orchestration. `system_events` remains foundation-only until explicitly activated and regression-tested.

---

# Remaining model debt / side quests

Fail-closed research/model coverage debt remains separate from M3 engine readiness:
1. QCOM Semiconductor Designer — 73.80
2. Streaming / Media — 73.70
3. BALL Packaging — 73.45
4. AMAT Semiconductor Equipment — 72.00
5. MP Magnetics full-company NAV — 71.55
6. Telecom — 12.00

New M3.4 decision-coverage dependency:
- current holdings expected-upside coverage is 0%; relevant potential trim holdings need traceable valuation before recommendation math can compare opportunity cost.

Financials remains queued; sector automation stays paused while M3 is Main Roadmap priority.

---

# Immediate next action

**Close M3.4 trim-candidate valuation coverage, then build Rebalancing Recommendation v1.**

1. Define the holdings-valuation coverage contract required for trim comparison.
2. Prioritize NVDA valuation coverage due to concentration relevance, without presuming a trim.
3. Build reproducible current expected-return inputs for any other holding eligible for trim comparison.
4. Re-run scenario net expected-value math once changed-asset coverage exists.
5. Build deterministic recommendation/ranking of NO_SELL vs soft vs active options.
6. Keep `REBALANCE` DRAFT until recommendation regressions and traceability pass.

---

# Google Sheet rule during remaining M3
Google Sheets stays view/audit only. During M3.2–M3.5, write only `System_Foundation` / audit-status information; do not add production policies, formulas or allocation/scenario logic to Sheet tabs.

---

# Documentation/update rule
Before material work read `AGENTS.md`, `contracts/system-contract.yaml`, `VERSION`, this roadmap, `docs/01_SYSTEM_ARCHITECTURE.md`, live `System_Foundation`, and relevant Supabase/Sheet controller state. After material work synchronize roadmap/architecture/live foundation when authority, capability, blocker, contract, milestone or next action changes.
