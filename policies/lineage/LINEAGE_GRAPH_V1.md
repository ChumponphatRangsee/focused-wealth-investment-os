# Evidence → Metric → Decision Lineage Graph v1

Policy: `POL-LINEAGE-GRAPH-V1`  
Epic: #31  
Issue: #35  
Production read-path cutover: **NO**

## Purpose

Turn FWIOS provenance from scattered arrays/prose into explicit, queryable, append-only graph edges.

Target trace:

`Source → Evidence → Metric Observation → Derived Metric → Revision / Valuation / Hardening → Decision`

The graph explains existing outputs. It does not change those outputs.

## Data model

### lineage_artifacts
Registry of immutable nodes that point at existing system objects.

Types:
- SOURCE
- SOURCE_REFERENCE
- EVIDENCE
- EVIDENCE_REFERENCE
- METRIC_OBSERVATION
- REVISION_COMPONENT
- REVISION_SNAPSHOT
- VALUATION_RUN
- HARDENING_SNAPSHOT
- DECISION_SNAPSHOT

`REFERENCE_ONLY` artifacts explicitly represent unresolved legacy references.

This is preferable to pretending the referenced source/evidence exists.

### lineage_edges
Typed append-only relations between artifacts.

Core edge types:
- SOURCE_SUPPORTS_EVIDENCE
- EVIDENCE_SUPPORTS_METRIC
- METRIC_DERIVES_METRIC
- EVIDENCE_SUPPORTS_REVISION_COMPONENT
- METRIC_SUPPORTS_REVISION_COMPONENT
- REVISION_COMPONENT_CONTRIBUTES_TO_REVISION
- METRIC_INPUT_TO_VALUATION
- VALUATION_SUPPORTS_HARDENING
- EVIDENCE_SUPPORTS_HARDENING
- METRIC_SUPPORTS_HARDENING
- REVISION_SUPPORTS_DECISION
- HARDENING_SUPPORTS_DECISION
- VALUATION_SUPPORTS_DECISION

## Append-only rule

Artifacts and edges may be inserted, but not updated or deleted.

Database triggers reject UPDATE and DELETE even for privileged internal execution.

If an unresolved reference later becomes canonical, create a new resolved artifact/edge relationship in a later migration rather than rewriting historical lineage.

## Legacy arrays normalized

Issue #35 materializes explicit edges from:
- `metric_observations.evidence_ids`
- `metric_observations.source_observation_ids`
- `candidate_revision_component_inputs.evidence_ids`
- `candidate_revision_snapshots.component_input_ids`
- `valuation_run_inputs.source_key`
- explicit Decision Snapshot FKs

Legacy arrays remain for compatibility, but audit-critical traversal no longer depends on parsing them.

## ADBE Revision example

`REV-ADBE-Q3-2026-FINALIST-V2-COMPLETE`

Revision Score: **47.5878**

The graph has exactly four component nodes:
- GUIDANCE
- CONSENSUS
- KPI_ACCELERATION
- MARGIN_FCF

Each component has explicit evidence edges.

The two Zacks consensus IDs currently referenced by the accepted Revision component do not have canonical `evidence_records` rows. They are therefore represented as `EVIDENCE_REFERENCE / REFERENCE_ONLY` nodes.

This exposes the data-quality gap instead of inventing URLs or hiding the references inside an array.

## PINS Hardening example

`HARD-PINS-20260906-V2` remains REVIEW.

Owner-economics lineage explicitly includes:
- H1 FCF
- H1 SBC
- H1 share repurchases
- Q2 2025 shares
- Q2 2026 shares
- LTM SBC / revenue

The lineage graph therefore makes the owner-economics REVIEW explainable without parsing `evidence_payload` prose.

## Query surfaces

### v_lineage_edges_resolved
Flat resolved edge view suitable for audits and deterministic tests.

### lineage_trace_v1
Recursive upstream/downstream traversal.

Example concept:

`lineage_trace_v1('DECISION:DEC-PINS-QH-20260906-V2','UPSTREAM',8)`

walks from the decision to hardening/valuation, then to metrics/evidence/source references.

## Security

- RLS enabled
- anon/authenticated privileges revoked
- service-role select/insert only
- append-only triggers block update/delete

## Boundary

This phase does not:
- alter Revision or Hardening formulas;
- alter valuation formulas;
- replace current decision consumers;
- auto-trade;
- delete legacy provenance fields.

It adds an auditable explanation graph beneath current production outputs.
