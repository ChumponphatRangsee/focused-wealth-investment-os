# Decision-Relevant Metric Observation Model v2

Policy: `POL-METRIC-OBSERVATION-V2`  
Epic: #31  
Issue: #34  
Production read-path cutover: **NO**

## Purpose

Replace current-state/text-heavy metric storage with a typed, period-aware observation model keyed by immutable `instrument_id`.

FWIOS is **not** becoming a full financial-data warehouse. A metric enters this layer only when it materially supports screening, thesis monitoring, valuation, revision, risk or portfolio decisions.

## Model

### metric_definitions
Defines the semantic metric once:
- stable `metric_code`
- display name
- typed value kind
- canonical unit
- allowed decision uses

Period is **not** encoded in the metric code.

Example:
`FREE_CASH_FLOW`

not:
`fcf_q2`, `fcf_q2_prior_year`, `fcf_h1_2026`

### metric_observations
Each period/value is its own immutable observation identity.

Core dimensions:
- `instrument_id`
- `metric_code`
- `observation_layer`
- typed canonical value
- fiscal year / quarter
- period type / label
- as-of / report / effective timestamps
- source/evidence references
- normalization / derivation metadata

### metric_legacy_mappings
Maps existing curated `company_metrics` and `normalized_metrics` identifiers to v2 semantic metric codes.

Legacy tables remain authoritative until explicit cutover.

## Typed values

Every observation must have exactly one:
- `value_numeric`
- `value_text`
- `value_boolean`

Raw source value/unit are also retained.

Current normalizations include:
- PCT / percent → ratio
- USD M → USD B
- B shares → M shares
- M shares variants → M shares

No runtime consumer should need to cast migrated canonical values from text once it switches to v2.

## Period semantics

Supported:
- QUARTER
- YEAR
- YTD
- LTM
- INSTANT
- GUIDANCE
- STRUCTURAL
- SCENARIO
- MATERIAL_EVENT
- OTHER

Period identity is separate from metric identity.

This enables:
- ADBE recurring growth Q2 FY26 and Q3 FY26 under one metric code;
- PINS Q1/Q2 MAU and revenue-growth history;
- PINS Q2 2025/Q2 2026 FCF comparison;
- future quarterly ARPU/SBC accumulation without new metric IDs.

## Observation layers

- REPORTED
- DERIVED
- NORMALIZED
- GUIDANCE
- ESTIMATE
- SCENARIO
- STRUCTURED

A normalized observation can reference one or more source observation IDs. Issue #35 will replace array-style transitional lineage with the explicit Evidence → Metric → Decision graph.

## Migration scope

Backfilled:
- all current `company_metrics`;
- all current `normalized_metrics`;
- `instrument_id` into company_metrics / normalized_metrics / evidence_records;
- selective historical ADBE/PINS evidence required by current Revision/Thesis workflows.

Selective extra history:
- ADBE ARR/recurring growth Q2 FY26;
- PINS MAU growth Q1 FY26;
- PINS revenue growth Q1 FY26;
- PINS FCF Q2 2025;
- PINS Q2 2026 Global ARPU approved thesis baseline;
- PINS H1 2026 SBC evidence.

## Compatibility boundary

Existing deterministic valuation, Revision, Hardening and dashboard logic still reads legacy tables.

`production_read_cutover=false`.

Issue #34 proves the v2 data foundation and parity only. Switching consumers belongs to later migration phases after lineage and regression coverage are complete.

## Non-goals

- no SEC/XBRL warehouse;
- no mirror of every financial-statement line;
- no removal of company_metrics / normalized_metrics;
- no rewrite of valuation formulas;
- no rewrite of Revision/Chase;
- no trade or portfolio mutation.
