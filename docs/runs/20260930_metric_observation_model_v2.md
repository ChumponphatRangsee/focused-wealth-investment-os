# Decision-Relevant Metric Observation Model v2 — 2026-09-30

Issue: #34  
Epic: #31  
Policy: `POL-METRIC-OBSERVATION-V2`  
Contract: `FWIOS-CONTRACT-0.87.14`  
Foundation compatibility: `0.87`

## Scope

Introduced a typed, period-aware metric time-series foundation keyed by canonical `instrument_id`.

This phase is additive:
- existing `company_metrics`, `normalized_metrics`, valuation and Revision consumers remain authoritative;
- `production_read_cutover=false`;
- no portfolio or trade behavior changed.

## Live objects

New:
- `fwios.metric_definitions`
- `fwios.metric_legacy_mappings`
- `fwios.metric_observations`
- `fwios.v_metric_observations_current`
- canonical metric/unit/value/period helper functions

Legacy identity bridge:
- `company_metrics.instrument_id`
- `normalized_metrics.instrument_id`
- `evidence_records.instrument_id`

All current ticker-bearing rows on those layers are backfilled.

## Acceptance state

- **130 metric definitions**
- **449 metric observations**
- **233/233 company_metrics compatibility observations**
- **210/210 normalized_metrics compatibility observations**

Typed invariant: each observation has exactly one canonical numeric/text/boolean value.

Canonical numeric conversions include:
- PCT / percent → ratio
- USD M → USD B
- B shares → M shares

## Period-aware examples

### ADBE
`RECURRING_REVENUE_GROWTH_YOY`
- Q2 FY2026 = 0.125
- Q3 FY2026 = 0.112

The quarter is no longer encoded into the metric identity.

### PINS
`GLOBAL_MAU_GROWTH_YOY`
- Q1 2026 = 0.11
- Q2 2026 = 0.11

`REVENUE_GROWTH_YOY`
- Q1 2026 = 0.18
- Q2 2026 = 0.18

`FREE_CASH_FLOW`
- Q2 2025 = USD 0.196683B
- Q2 2026 = USD 0.269933B
- LTM through Q2 2026 = USD 1.280404B

`GLOBAL_ARPU`
- Q2 2026 = USD 1.86/user from the existing approved PINS thesis baseline

SBC:
- H1 2026 share-based compensation = USD 0.555963B
- LTM SBC/revenue = 0.224282...

## Lineage boundary

Normalized observations retain:
- source observation IDs when resolvable from legacy source metrics;
- evidence IDs otherwise / additionally.

The explicit many-to-many Evidence → Metric → Derivation → Decision graph is intentionally deferred to Issue #35.

No fake one-to-one source links were created for multi-source normalized metrics such as EOG/ALB/BKR derived models.

## Regression

`tests/metrics/test_metric_observation_model_v2.sql`

Result: **15/15 PASS**.

Coverage:
- policy active / no read cutover / no auto trade;
- identity backfill complete;
- company + normalized compatibility counts;
- typed-value exclusivity;
- ADBE Q2/Q3 recurring growth;
- PINS MAU/revenue growth Q1/Q2;
- PINS FCF YoY;
- PINS ARPU and SBC period semantics;
- normalized lineage handles;
- numeric canonical values require no runtime text cast;
- private RLS;
- registered regressions PASS.

## Production parity

Pre/post #34 values were unchanged:

### ADBE valuation
- Bear FV: 326.28869144
- Base FV: 467.01301494
- High FV: 697.21140532
- Fair Value: 489.38153166
- Revision Score: 47.5878
- Revision Gate: `FAIL - NEGATIVE FUNDAMENTAL REVISION`

### PINS valuation
- Bear FV: 25.31993054
- Base FV: 40.60199649
- High FV: 69.48544731
- Fair Value: 44.0023427075
- Revision Score: 60.5531
- Revision Gate: PASS

### Portfolio
- 10 open dashboard rows
- Cost basis THB 335,340.09
- Marked value at parity check THB 353,719.32

No transaction, quantity, cost-basis, approval or trade mutation occurred.

## Advisor / security

Metric v2 tables:
- RLS enabled;
- internal service-role pattern retained;
- no public read cutover.

Supabase advisor identified one uncovered FK on `metric_legacy_mappings.metric_code`; follow-up migration added `metric_legacy_mappings_metric_code_idx`.

Remaining new-index notices are expected fresh-index `unused_index` INFO only.

## Result

Issue #34 acceptance criteria are satisfied at the additive metric-foundation layer.

Next: **#35 — Evidence → Metric → Decision Lineage Graph**.

Issue #36 Unified Market Observation may proceed in parallel.
