# Thesis Memory + Reactivation v1 — 2026-09-30

Issue: #37  
Epic: #31  
Policy: `POL-THESIS-MEMORY-V1`  
Foundation compatibility: `0.87`  
Production read-path cutover: **NO**

## Live migrations

- `20260930081407 thesis_memory_reactivation_v1_foundation`
- `20260930081550 thesis_memory_reactivation_v1_backfill`
- `20260930081718 thesis_memory_reactivation_v1_functions`
- `20260930082113 thesis_memory_reactivation_v1_index_hardening`
- `20260930082147 thesis_memory_reactivation_v1_regression_registry`

## Acceptance

Regression suite: **15/15 PASS**.  
Registered regressions: **15 / 0 failures**.

Initial normalized state:
- 6 COMPLETE thesis baselines normalized
- 73 thesis conditions
  - 27 Must-Remain-True
  - 22 Catalysts
  - 24 Invalidations
- 37 KPI bindings
- 8 explicit condition → metric-observation links
- 2 real current decision-memory anchors
- 0 reactivation rules
- 0 reactivation events

No artificial REJECTED record or synthetic reactivation event was inserted merely to populate the new tables.

## Baseline compatibility

All six COMPLETE theses reconstruct their legacy JSON arrays with no drift.

ADBE retained its pre-migration hashes for:
- thesis statement
- Must-Remain-True
- monitoring KPIs
- catalysts
- invalidation criteria

PINS retained the same five pre-migration hashes.

Current production outputs also remain unchanged:
- ADBE: `WAIT - POST-EVENT PRICE / REVISION-CHASE`; promotion blocked for material-event revalidation; thesis health WEAKENING / 86.5
- PINS: `PRICE CONFLICT`; promotion blocked by price conflict; thesis health WATCH / 87

## Canonical metric binding

PINS has explicit KPI/metric links for revenue growth, MAU growth, Global ARPU, adjusted EBITDA margin, free cash flow, SBC/revenue and share repurchases.

Mappings whose semantics do not fully match are marked PARTIAL. KPIs with no safe canonical semantic match remain UNMAPPED.

Eight threshold/operator links are explicit for ADBE/PINS invalidation conditions.

## Decision memory + reactivation

Current normalized memory:
- ADBE: DEFER
- PINS: WATCH

A future REJECT created by `record_thesis_decision_memory_v1` must carry an explicit reactivation rule.

Reactivation:
- source state must be REJECTED or ARCHIVED;
- explicit trigger + complete decision memory required;
- target may be only UNIVERSE, SCREENED or WATCH;
- lifecycle legality is delegated to Research Lifecycle v1;
- successful evaluation records append-only audit history;
- no function automatically mutates production lifecycle;
- no direct FULL_THESIS / PORTFOLIO / buy promotion is allowed.

## Boundary

Legacy thesis JSON remains authoritative.

No valuation, Revision, Hardening, opportunity ranking, portfolio, approval or execution semantics changed.

`production_read_cutover=false`, `auto_trade=false`, human execution only.
