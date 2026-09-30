# Evidence → Metric → Decision Lineage Graph v1 — 2026-09-30

Issue: #35  
Epic: #31  
Policy: `POL-LINEAGE-GRAPH-V1`  
Foundation compatibility: `0.87`  
Production read-path cutover: **NO**

## Scope

Implemented the additive audit graph required by Core Architecture Redesign v1.0:

`Source → Evidence → Metric Observation → Derived Metric → Revision / Valuation / Hardening → Decision`

This phase explains existing outputs and preserves current valuation, Revision, Hardening, portfolio and human-execution semantics.

## Live migrations

- `20260930051135 lineage_graph_v1`
- `20260930051317 lineage_graph_v1_legacy_revision_reference_fix`
- `20260930062633 lineage_graph_v1_regression_registry_fix`

## Live objects

New:
- `fwios.lineage_artifacts`
- `fwios.lineage_edges`
- `fwios.v_lineage_edges_resolved`
- `fwios.lineage_trace_v1(...)`

Policy:
- `POL-LINEAGE-GRAPH-V1`

Security:
- RLS enabled
- public / anon / authenticated revoked
- service-role select/insert only
- UPDATE / DELETE rejected by append-only triggers

## Acceptance state

Live verification after the registry repair:
- **16/16 lineage regression checks PASS**
- 1,156 lineage artifacts
- 1,423 lineage edges
- 39 explicit `REFERENCE_ONLY` artifacts
- 82 explicit `REFERENCE_ONLY` edges

Reference-only nodes are intentional fail-closed representations of unresolved legacy references; they are not fabricated evidence.

## ADBE Revision acceptance

Snapshot:
- `REV-ADBE-Q3-2026-FINALIST-V2-COMPLETE`
- Revision Score: **47.5878**
- Gate: `FAIL - NEGATIVE FUNDAMENTAL REVISION`

Exactly four component nodes are explicit:
1. GUIDANCE — 48.9035
2. CONSENSUS — 51.6454
3. KPI_ACCELERATION — 43.5
4. MARGIN_FCF — 45.6519

Underlying evidence is explicit. The two legacy Zacks consensus IDs currently lack canonical `evidence_records` rows and are therefore represented as `EVIDENCE_REFERENCE / REFERENCE_ONLY` nodes rather than invented source records.

## PINS Hardening acceptance

Snapshot:
- `HARD-PINS-20260906-V2`
- overall gate: **REVIEW**
- owner-earnings gate: **REVIEW**
- valuation confidence: **0.775**

Owner-economics lineage explicitly includes five resolved evidence paths:
- H1 FCF
- H1 SBC
- H1 share repurchases
- Q2 2025 shares
- Q2 2026 shares

Typed metric paths for FCF, SBC and buybacks are explicit, and `lineage_trace_v1('DECISION:DEC-PINS-QH-20260906-V2','UPSTREAM',8)` reaches the underlying FCF and SBC evidence.

## Compatibility boundary

Preserved:
- legacy provenance arrays for compatibility
- existing valuation consumers
- existing Revision / Chase logic
- existing Hardening logic
- portfolio accounting
- approval / execution isolation
- `auto_trade=false`
- human execution only

No production decision read-path cutover was performed.
