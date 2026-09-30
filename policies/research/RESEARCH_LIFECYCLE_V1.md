# Research Lifecycle v1

Policy version: `POL-RESEARCH-LIFECYCLE-V1`  
Epic: #31  
Implementation task: #32  
Production read-path cutover: **NO**

## Purpose

Make research attention a scarce, policy-controlled resource. Broad market coverage is shallow by default; deep research is selective and must be justified by opportunity and capital relevance.

This policy does not replace valuation, Quality Hardening, Revision/Chase, portfolio reconciliation or Human Approval. It does not place trades or mutate holdings.

## Lifecycle

Primary pipeline:

`UNIVERSE → SCREENED → WATCH → RESEARCH_CANDIDATE → FULL_THESIS → PORTFOLIO`

Side states:

- `REJECTED` — prior research is retained with explicit decision memory and reactivation conditions; continuous deep monitoring stops.
- `ARCHIVED` — inactive audit state; no scheduled deep refresh.

The policy is a gate, not a force-fill mechanism. A name may remain in its current state indefinitely.

## Attention tiers

| State | Tier | Resource mode | Refresh mode |
|---|---:|---|---|
| UNIVERSE | 0 | BROAD_BATCH | LOW_COST_BATCH |
| SCREENED | 1 | SIGNAL_MONITOR | PERIODIC_SIGNAL |
| WATCH | 1 | WATCH_MONITOR | EVENT_OR_PERIODIC |
| RESEARCH_CANDIDATE | 2 | TARGETED_RESEARCH | ON_DEMAND_PLUS_EVENTS |
| FULL_THESIS | 3 | DEEP_THESIS | MATERIAL_EVENT_PLUS_PERIODIC |
| PORTFOLIO | 4 | CAPITAL_CRITICAL | CONTINUOUS_MATERIAL_EVENT |
| REJECTED | 0 | TRIGGER_ONLY | REACTIVATION_TRIGGER_ONLY |
| ARCHIVED | 0 | DORMANT | NONE_EXCEPT_MANUAL_REACTIVATION |

Tier is research depth, not investment attractiveness.

## Archetype coverage

- `GENERIC` — universal research coverage is available. Deep promotion may proceed, but all downstream model/valuation gates remain independent and fail-closed.
- `ARCHETYPE_SUPPORTED` — a validated reusable archetype pack exists.
- `CUSTOM` — a validated company-specific model/research pack exists.
- `UNSUPPORTED` — no validated deep model exists.

`UNSUPPORTED` **does not imply REJECTED**. It blocks promotion into `FULL_THESIS` or `PORTFOLIO` until coverage improves.

## Legal transitions

| From | Allowed To |
|---|---|
| UNIVERSE | SCREENED, ARCHIVED |
| SCREENED | UNIVERSE, WATCH, REJECTED, ARCHIVED |
| WATCH | SCREENED, RESEARCH_CANDIDATE, REJECTED, ARCHIVED |
| RESEARCH_CANDIDATE | WATCH, FULL_THESIS, REJECTED, ARCHIVED |
| FULL_THESIS | RESEARCH_CANDIDATE, WATCH, PORTFOLIO, REJECTED, ARCHIVED |
| PORTFOLIO | FULL_THESIS, WATCH |
| REJECTED | SCREENED, WATCH, ARCHIVED |
| ARCHIVED | UNIVERSE, SCREENED |

Same-state requests are idempotent `PASS - NOOP`.

Additional fail-closed requirements:

1. Promotion into `FULL_THESIS` or `PORTFOLIO` is blocked when archetype coverage is `UNSUPPORTED`.
2. Entering `REJECTED` requires persistent decision memory.
3. Reactivation from `REJECTED` or `ARCHIVED` to an active state requires an explicit reactivation trigger.
4. Entering `PORTFOLIO` requires an already reconciled portfolio holding.
5. Leaving `PORTFOLIO` is blocked while the asset is still reconciled as held.
6. Lifecycle transitions never place orders and never mutate portfolio accounting.

## Required active data by state

### UNIVERSE
Identity, classification, basic market metadata and universal screen snapshot only.

### SCREENED
Screen result/reason and selected canonical metrics needed to justify the screen.

### WATCH
Watch rationale, review trigger, next-review context and limited valuation/signal state.

### RESEARCH_CANDIDATE
Research hypothesis, targeted evidence, selected decision-relevant metrics, archetype coverage and open research blockers.

### FULL_THESIS
Thesis statement, Must-Remain-True conditions, monitoring KPIs, invalidation rules, valuation state, Revision/Chase, Quality Hardening and auditable evidence lineage.

### PORTFOLIO
Full-Thesis state plus reconciled portfolio linkage, position risk, mark-to-market and capital-decision state.

### REJECTED
Decision memory, rejection reasons, decision context and explicit reactivation conditions.

### ARCHIVED
Archive reason, prior-state reference and immutable audit lineage.

## Retention invariant

Lifecycle demotion changes active refresh obligations, **not historical truth**.

Do not delete prior evidence, thesis, valuation, decision, approval or portfolio audit lineage merely because a company moves to a shallower state.

## Market-coverage boundary

S&P 500 or a broader universe may be present in `UNIVERSE` without:
- Full Thesis,
- archetype-specific valuation,
- continuous deep monitoring,
- complete historical financial replication.

Archetype packs are built on demand when qualified candidates or portfolio relevance justify the research cost.

## Current migration boundary

Issue #32 activates the lifecycle **contract and deterministic gate only**.

It does not:
- backfill all current companies into new lifecycle storage;
- change current ADBE/PINS decision outputs;
- change the live portfolio;
- replace current thesis tables;
- cut production dashboards over to the new lifecycle.

Those belong to later Epic #31 tasks, beginning with #33 Canonical Instrument Identity.
