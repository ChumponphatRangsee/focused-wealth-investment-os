# FWIOS Valuation Model Audit + Period-Aware Input Resolver v1

Date: **2026-10-26 (Asia/Bangkok)**  
Status: **Design + read-only prototype complete; no production cutover**

## Why this exists

MVP-1 exposed a semantic rollover problem in ACN: current SEC facts can be newer than the valuation model's period-specific input names. A model can therefore receive new data while still carrying old-period meaning.

The target invariant is already present in Metric Observation Model v2:

> **metric identity is stable; period identity is separate**

The missing piece is applying the same invariant at the valuation-input boundary.

## Live audit result

Live Supabase currently has:

- 20 implemented valuation models;
- 21 rows marked as production model versions;
- 28 tickers with production-eligible valuation history.

### Period-identity RED

Three implemented models encode fiscal year/quarter inside required metric IDs:

| Model | Current ticker | Period-encoded required inputs |
|---|---|---|
| `IT_SERVICES_FCF_COMPOUNDER_V1` | ACN | `book_to_bill_q3`, `fy2026_revenue_growth_guidance_lc_mid`, `gross_margin_q3`, `operating_margin_q3` |
| `E&P_NORMALIZED_FCF_YIELD_V1` | EOG | `fcf_fy2025` |
| `STREAMING_FCF_DCF_V1` | NFLX | `fcf_guidance_fy2026` |

These contracts must not silently roll to a new fiscal period.

### Temporal-anchor AMBER

Several models use generic required metrics but retain FY/quarter-specific context inside non-required contract fields, policy text or candidate assumptions. These are not automatically wrong, but they need an expiry/revalidation rule so historical evidence anchors cannot masquerade as current evidence.

Current examples include Aerospace/Defense, Machinery/Electrification, Mining/SOTP, OFS, Restaurant and Semicap.

### Version-governance RED

Two independent governance anomalies were found:

- `SEMIS_MIDCYCLE_DCF_V1` has two model-version rows marked `PRODUCTION` simultaneously (`1.0` and `1.1`).
- `SAAS_EV_FCF_REVERSE_DCF_V1` registry says model version `1.1`, while the only production-status version row is `1.1-EXPERIMENTAL`.

A resolver must never guess which production model version to use.

## Best-practice contract

Do not create a new database table for v1. Reuse `valuation_model_versions.input_contract` JSONB and move toward selectors shaped conceptually as:

```json
{
  "input_selectors": [
    {
      "input_key": "operating_margin",
      "metric_code": "OPERATING_MARGIN",
      "period_rule": "LATEST_QUARTER",
      "required": false
    },
    {
      "input_key": "fcf_guidance_midpoint",
      "metric_code": "FCF_GUIDANCE_MIDPOINT",
      "period_rule": "NEXT_FY_GUIDANCE",
      "required": true
    }
  ]
}
```

The metric code identifies **what the number means**. The selector identifies **which observation is valid for this valuation run**.

## Resolver rules

The read-only prototype implements the following principles:

1. resolve by canonical `metric_code`, never by a year/quarter embedded in the metric name;
2. filter observations by explicit period semantics;
3. respect valuation `as_of` time;
4. require next-FY guidance after a fiscal year closes;
5. require balance/share/LTM inputs not to predate the latest closed fiscal period when the contract says so;
6. prefer explicit normalized/derived/reported lineage deterministically;
7. block undefined canonical metric identities;
8. block missing/stale/wrong-period required inputs;
9. optional diagnostics may remain blocked without being silently substituted;
10. model-version ambiguity is a separate fail-closed governance blocker.

## ACN PREVIEW result

For ACN after FY2026 closed on 2026-08-31, the prototype correctly blocks the current canonical set:

- FY2026 FCF guidance low/mid/high -> `BLOCKED_WRONG_FISCAL_PERIOD`;
- current canonical FCF LTM -> `BLOCKED_STALE_PERIOD`;
- current canonical net cash -> `BLOCKED_STALE_PERIOD`;
- current canonical shares outstanding -> `BLOCKED_STALE_PERIOD`;
- proposed generic `REVENUE_GROWTH_GUIDANCE_LC_MID` -> `BLOCKED_METRIC_CODE_NOT_DEFINED`;
- proposed generic `BOOK_TO_BILL` diagnostic -> `BLOCKED_METRIC_CODE_NOT_DEFINED`;
- current Q3 margins -> stale diagnostics relative to FY2026 close.

This is intentional. PR #76's FY2026 actual revenue/FCF are PREVIEW-only and have not been APPLYed to canonical metrics.

## Canonical identity debt

Metric Observation v2 already converts:

- `gross_margin_q3` -> `GROSS_MARGIN`;
- `operating_margin_q3` -> `OPERATING_MARGIN`.

The following still need a controlled semantic migration before cutover:

- `book_to_bill_q3` -> proposed generic `BOOK_TO_BILL`;
- `fy2026_revenue_growth_guidance_lc_mid` -> proposed generic `REVENUE_GROWTH_GUIDANCE_LC_MID`;
- `fcf_fy2025` -> `FREE_CASH_FLOW` + YEAR period identity;
- `fcf_guidance_fy2026` -> generic FCF-guidance identity + GUIDANCE fiscal-year identity.

Do not perform these mappings by string replacement alone. Confirm economic definition compatibility per source/model first.

## Recommended migration order

**Phase A — governance/read-only**

- keep this audit + resolver PREVIEW in read-only mode;
- resolve the SEMIS/SAAS production-version anomalies;
- review RED model semantics for ACN, EOG and NFLX.

**Phase B — canonical semantic cleanup**

- add only the missing generic metric definitions/mappings needed by approved model contracts;
- preserve legacy observations/mappings for audit;
- do not rewrite historical evidence.

**Phase C — model contract versions**

- create period-aware model versions for ACN/EOG/NFLX;
- keep formulas/assumptions versioned separately from refreshed observations;
- avoid copying reported guidance values into assumptions.

**Phase D — resolver regression**

Regression must prove:

- latest correct-period observation is selected deterministically;
- stale/old-FY guidance blocks;
- missing semantic metric blocks;
- multiple production model versions block;
- no input is silently substituted by a semantically different metric;
- valuation runs snapshot exact resolved observation keys.

**Phase E — production cutover**

Only after separate authorization:

- migrate production valuation reads to the resolver;
- create new immutable valuation runs;
- compare outputs with prior runs;
- validate existing Valuation Map;
- preserve human-only execution and no automatic trading.

## Files in this slice

- `queries/valuation_model_period_audit_v1.sql`
- `queries/valuation_input_resolver_preview_v1.sql`
- `tests/valuation/test_valuation_input_resolver_v1.sql`

Live regression result: **7/7 PASS (READ-ONLY)**.

## Production boundary

This slice does **not**:

- APPLY research metrics;
- alter metric definitions/mappings;
- modify model rows/version status;
- change schema;
- create valuation runs;
- cut over a production read path;
- change Dashboard/Valuation Map logic;
- change cron/workers;
- trade.
