# Thesis Memory + Reactivation v1

Policy: `POL-THESIS-MEMORY-V1`  
Epic: #31  
Issue: #37  
Production read-path cutover: **NO**

## Purpose

Normalize machine-actionable thesis state without replacing the current `thesis_registry` JSON read path.

The foundation separates:
- thesis conditions;
- monitoring KPI bindings;
- condition → canonical metric-observation links;
- append-only decision memory;
- explicit reactivation rules and events.

Legacy thesis JSON remains authoritative during transition.

## Condition model

Supported condition types:
- `MUST_REMAIN_TRUE`
- `CATALYST`
- `INVALIDATION`

Each normalized condition retains its original JSON payload and a payload hash. This allows the compatibility view to reconstruct the original baseline arrays exactly.

Initial acceptance normalized all six `baseline_status=COMPLETE` theses:
- ADBE
- MSFT
- NVDA
- PINS
- TLN
- TTWO

Initial counts:
- 73 conditions
  - 27 Must-Remain-True
  - 22 Catalysts
  - 24 Invalidations
- 37 monitoring KPI bindings
- 8 explicit condition → metric links

## KPI binding rule

A KPI is mapped only when canonical semantics already exist.

Mapping states:
- `RESOLVED` — metric and matching baseline observation are explicit;
- `PARTIAL` — canonical metric covers only part of the thesis KPI or period semantics differ;
- `METRIC_ONLY` — canonical metric definition exists but no exact baseline observation exists;
- `UNMAPPED` — no safe canonical mapping exists yet.

Unmapped KPIs remain explicit. The migration does not invent metric definitions or observations merely to increase coverage.

PINS examples:
- Revenue growth → `REVENUE_GROWTH_YOY` — RESOLVED
- Global MAUs → `GLOBAL_MAU_GROWTH_YOY` — PARTIAL because the canonical observation represents growth, not the absolute 640M user count
- Global ARPU → `GLOBAL_ARPU` — RESOLVED
- Adjusted EBITDA margin → `ADJUSTED_EBITDA_MARGIN` — RESOLVED
- Free cash flow → `FREE_CASH_FLOW` — RESOLVED
- SBC / revenue → `SBC_TO_REVENUE` — PARTIAL because the linked canonical value is LTM while the thesis baseline text is quarterly
- Share repurchases → `SHARE_REPURCHASES` — RESOLVED
- US & Canada ARPU / Rest of World ARPU remain UNMAPPED rather than fabricated.

## Machine-actionable condition links

Threshold/operator semantics are explicit where canonical metrics support them.

Examples:
- PINS revenue growth <10% AND MAU growth <5% for two periods;
- PINS Global ARPU direction down for two YoY periods;
- PINS adjusted EBITDA margin <20% AND revenue growth <12% for two periods;
- PINS SBC / revenue >30% plus no share-count decline;
- ADBE recurring-revenue growth <7% for two periods, with the AI-first ARR clause retained as text-only/partial.

## Decision memory

Decision classes:
- `REJECT`
- `DEFER`
- `WATCH`
- `PROMOTE`

Current live acceptance records only real decision anchors:
- ADBE — DEFER
- PINS — WATCH

No fake REJECTED decision-memory row or reactivation event is inserted because no current production name needed one at migration time.

Decision memory is append-only.

## REJECT + reactivation invariant

A new REJECT memory created through `record_thesis_decision_memory_v1` requires an explicit reactivation rule in the same operation.

Dormant states retain Research Lifecycle v1 semantics:
- REJECTED attention tier = 0;
- REJECTED refresh mode = `REACTIVATION_TRIGGER_ONLY`;
- prior research history is retained.

Reactivation:
- requires explicit trigger;
- requires complete decision memory;
- may reopen only to `UNIVERSE`, `SCREENED`, or `WATCH`;
- delegates final legality to `research_lifecycle_transition_gate_v1`;
- records an append-only reactivation event;
- does **not** mutate the production lifecycle automatically.

It cannot jump directly into `FULL_THESIS`, `PORTFOLIO`, an Immediate Buy bucket, or any broker action.

## Reactivation trigger types

- `METRIC_THRESHOLD`
- `THESIS_EVENT`
- `MATERIAL_CHANGE`
- `MANUAL_REVIEW`

Metric thresholds use canonical `metric_observations`, require `provenance_status=PASS`, and may require N consecutive distinct periods.

## Compatibility and parity

`fwios.v_thesis_memory_normalized_compat` reconstructs normalized arrays in legacy order.

At acceptance:
- all six COMPLETE baselines reconstruct with no JSON drift;
- ADBE thesis statement and four baseline arrays retain their pre-migration hashes;
- PINS thesis statement and four baseline arrays retain their pre-migration hashes;
- ADBE production final decision remains `WAIT - POST-EVENT PRICE / REVISION-CHASE`;
- PINS production final decision remains `PRICE CONFLICT`;
- thesis health and promotion gates are unchanged.

## Safety boundary

- `production_read_cutover=false`
- legacy thesis JSON remains authoritative
- no lifecycle mutation in backfill
- no portfolio mutation
- no automatic promotion to buy
- `auto_trade=false`
- human execution only
