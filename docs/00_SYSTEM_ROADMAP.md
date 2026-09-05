# Focused Wealth Investment OS — Master System Roadmap

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract: **FWIOS-CONTRACT-0.87.5**  
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
| Contract | FWIOS-CONTRACT-0.87.5 |
| Research pipeline | RPV2.1 |
| Operating mode | DISCOVERY |
| Evidence-ready / valuation-ready | 18 / 13 |
| Decision coverage | 72.2% |
| Open root model blockers | 6 |
| Current sector | Communication Services — DONE |
| Next queued sector | Financials |
| Sector automation | PAUSED — M3 Main Roadmap priority |
| M2 Decision Intelligence | PASS |
| M3.1 Opportunity Ranking | **PASS / PRODUCTION LIVE** |
| M3.2 Capital Allocation | **NEXT** |
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
- [x] `POL-REVISION-SCORE-V1` deterministic policy.
- [x] `POL-CHASE-SCORE-V1` deterministic policy.
- [x] 16/16 decision-policy regressions PASS.
- [x] V2 Decision Snapshots rebuilt against ACTIVE policies.

Reference decisions:
- PINS: Core 87.60 / Revision PASS / Chase PASS / Mispricing PASS / Promotion PASS / READY - HUMAN REVIEW.
- RDDT: Core 72.15 / Revision PASS / Chase PASS / Mispricing FAIL / GOOD COMPANY - WAIT FOR VALUE.

## Architecture Consolidation v1
**Status: LIVE / M2 + M3.1 POLICY HARDENING INTEGRATED**

- [x] Supabase = State; GitHub = Logic/Contracts/Tests/Migrations; Sheets = View/Audit.
- [x] Generic policy registry/version governance.
- [x] Decision Snapshot reproducibility boundary.
- [x] Active Data Scoring, Mispricing, Portfolio Fit, Revision, Chase and Opportunity Ranking policy families.
- [x] M3 scenario foundation tables.
- [x] M4 event foundation table, no production triggers.
- [ ] Reduce user-facing Sheet surface only after M3 traceability/cutover passes.

## M3 — Opportunity & Capital Allocation
**Status: IN PROGRESS**

### M3.1 Opportunity Ranking
**Status: PASS / PRODUCTION LIVE**

- [x] Supabase-native ranking sourced only from latest production Decision Snapshots.
- [x] `POL-OPPORTUNITY-RANKING-V1` ACTIVE / deterministic.
- [x] Priority score = existing Core Score; no second weighted investment score.
- [x] Deterministic tie-break order: Expected Return → Portfolio Fit → Downside → Business/Thesis → ticker.
- [x] Promotion PASS + integrity PASS → Immediate candidate.
- [x] Only insufficient Mispricing with every other hard gate PASS → Value-Wait watchlist.
- [x] Max 3 Immediate / max 5 Watchlist / never force-fill.
- [x] 8/8 regressions PASS, including live PINS/RDDT production parity.
- [x] First production run `OPPRANK-M3-20260905-01` PASS.

Current ranking snapshot:

| Bucket | Rank | Ticker | Priority | Source Decision Snapshot |
|---|---:|---|---:|---|
| IMMEDIATE_BUY_CANDIDATE | 1 | PINS | 87.6000 | DEC-PINS-M2-20260905-V2 |
| WATCHLIST_VALUE_WAIT | 1 | RDDT | 72.1500 | DEC-RDDT-M2-20260905-V2 |

This is ranking eligibility only, not a trade or allocation recommendation.

### M3.2 Capital Allocation Engine
**Status: NEXT**

Build new-cash allocation first.

Required behavior:
- consume only active Opportunity Ranking output;
- prioritize new cash before trims;
- support example new-cash amounts such as THB 10k / 50k / 100k without hardcoding those amounts;
- produce exact THB allocation per eligible candidate;
- respect max 3 immediate candidates;
- include portfolio concentration, crypto and position-count effects;
- keep cash when no candidate clears the allocation policy;
- never mutate live holdings;
- no auto-trading.

### M3.3 Portfolio Scenario Simulation
**Status: PENDING M3.2**

Modes:
- `NO_SELL`
- `SOFT_REBALANCE`
- `ACTIVE_REBALANCE`

Outputs must include before/after weights, expected portfolio-upside change, concentration/theme/crypto/focus effects, downside/guardrail changes and full source traceability.

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

**Build M3.2 New-Cash Capital Allocation Engine on active Opportunity Ranking v1.**

1. Define deterministic allocation policy and fail-closed inputs.
2. Use latest reconciled portfolio batch + active ranking run.
3. Compute new-cash allocations before any trim logic.
4. Add allocation regressions for caps, concentration, crypto exposure, no-eligible-candidate cash hold and traceability.
5. Keep `REBALANCE` DRAFT and allocation/scenario outputs non-mutating.

---

# Documentation/update rule
Before material work read `AGENTS.md`, `contracts/system-contract.yaml`, `VERSION`, this roadmap, `docs/01_SYSTEM_ARCHITECTURE.md`, live `System_Foundation`, and relevant Supabase/Sheet controller state. After material work synchronize roadmap/architecture/live foundation when authority, capability, blocker, contract, milestone or next action changes.
