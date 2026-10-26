# FWIOS Valuation Period Semantics v2

Date: **2026-10-26 (Asia/Bangkok)**  
Live migration: **20261026101318 — valuation_period_semantics_v2**  
Status: **LIVE foundation change / no valuation cutover**

## What changed

This slice implements the first approved follow-up to the valuation-model audit.

### 1. Version authority is now deterministic

Two governance anomalies were resolved without rewriting historical valuation runs:

- `SEMIS_MIDCYCLE_DCF_V1::1.0` -> `RETIRED`
- `SEMIS_MIDCYCLE_DCF_V1::1.1` remains the only `PRODUCTION` version
- `SAAS_EV_FCF_REVERSE_DCF_V1::1.1-EXPERIMENTAL` -> `RETIRED`
- a canonical `SAAS_EV_FCF_REVERSE_DCF_V1::1.1` production row was created as an exact policy/input/assumption clone of the prior row

Historical valuation runs keep their original model-version IDs. No run was rewritten.

After migration:

- implemented models: 20
- production model-version rows: 20
- each implemented model has exactly one production version whose `version_label` matches `valuation_models.model_version`

### 2. Period identity was separated from metric identity

Three generic semantic metric definitions were added:

- `BOOK_TO_BILL`
- `REVENUE_GROWTH_GUIDANCE_LC_MID`
- `FREE_CASH_FLOW_GUIDANCE`

Legacy rows remain intact.

New mapping version `METRIC_PERIOD_AWARE_V1` maps:

- ACN `book_to_bill_q3` -> `BOOK_TO_BILL` + quarter metadata
- ACN `fy2026_revenue_growth_guidance_lc_mid` -> `REVENUE_GROWTH_GUIDANCE_LC_MID` + guidance fiscal-year metadata
- EOG `fcf_fy2025` -> existing `FREE_CASH_FLOW` + YEAR/FY2025 metadata
- NFLX `fcf_guidance_fy2026` -> `FREE_CASH_FLOW_GUIDANCE` + GUIDANCE/FY2026 metadata

Four canonical semantic-alias observations were inserted from existing normalized observations with explicit `source_observation_ids`. Historical evidence/legacy observations were not mutated.

### 3. ACN period-aware contract v2 is registered

New model-version row:

`IT_SERVICES_FCF_COMPOUNDER_V1::2.0`

State:

- `EXPERIMENTAL`
- `production_read_cutover=false`
- supersedes production v1 conceptually, but does not replace it yet
- no valuation run uses v2 yet

Required semantic inputs:

- `FCF_GUIDANCE_LOW`
- `FCF_GUIDANCE_MIDPOINT`
- `FCF_GUIDANCE_HIGH`
- `REVENUE_GROWTH_GUIDANCE_LC_MID`
- `FREE_CASH_FLOW`
- `NET_CASH`
- `SHARES_OUTSTANDING`

Optional diagnostics:

- `BOOK_TO_BILL`
- `OPERATING_MARGIN`
- `GROSS_MARGIN`

The contract stores explicit `input_selectors` and relative period rules such as:

- `NEXT_FISCAL_YEAR_GUIDANCE`
- `LATEST_AT_OR_AFTER_CLOSED_FISCAL_PERIOD`
- `LATEST_PERIOD_END_SHARE_COUNT_AT_OR_AFTER_CLOSED_FISCAL_PERIOD`
- `LATEST_REPORTED_QUARTER`

No FY2026/Q3 identifier exists in the v2 required metric identity.

### 4. Reported guidance values were removed from assumptions

ACN v1 embedded:

- 10.8B
- 11.15B
- 11.5B

as `starting_fcf_b` assumption values.

ACN v2 does not copy those reported facts into assumptions. Starting FCF must come from resolved metric observations. Only true valuation assumptions remain in `assumptions`:

- scenario growth
- discount rate
- terminal growth

## Current ACN resolver result

With FY2026 closed on 2026-08-31, ACN v2 correctly remains **BLOCKED**.

Required inputs currently blocked:

| Input | Current result |
|---|---|
| FCF guidance low | old FY2026 guidance |
| FCF guidance midpoint | old FY2026 guidance |
| FCF guidance high | old FY2026 guidance |
| Revenue-growth guidance midpoint | old FY2026 guidance |
| FCF LTM | latest canonical row ends 2026-05-31 |
| Net cash | latest canonical row is 2026-05-31 |
| Shares outstanding | latest canonical row is Q3 FY2026 / 2026-05-31 |

Required inputs passing: **0/7**.

Optional generic `BOOK_TO_BILL`, `OPERATING_MARGIN` and `GROSS_MARGIN` resolve successfully to the latest available quarter, but they cannot bypass missing required inputs.

This is the intended fail-closed behavior.

## Live verification

Before production apply, the migration was executed inside a transaction and rolled back. Result:

`VALUATION_PERIOD_SEMANTICS_V2_DRY_RUN_PASS`

After live apply:

`FWIOS VALUATION PERIOD SEMANTICS V2: PASS (12/12)`

The existing Valuation Map values/run IDs for ACN, EOG and NFLX were compared before and after migration and remained unchanged.

No new valuation run was created.

## Production boundary

This migration **does change live governance/semantic foundation state**, but it does not cut over valuation production reads.

It does not:

- APPLY the ACN SEC FY2026 PREVIEW payload from PR #76;
- ingest FY2027 ACN guidance;
- create a new ACN valuation run;
- replace ACN production v1 with v2;
- change EOG/NFLX production model contracts;
- change Scanner/Valuation Map formulas;
- place trades or mutate portfolio/accounting state.

## Next exact step

Close ACN's remaining required current-period inputs using primary evidence:

1. FY2026 actual FCF canonical observation from the already-tested SEC PREVIEW;
2. FY2026 year-end net-cash/debt bridge;
3. FY2026 period-end shares outstanding;
4. FY2027 FCF guidance low/mid/high;
5. FY2027 revenue-growth guidance midpoint.

Then rerun the v2 resolver. Only when all required selectors pass should a **shadow/new immutable valuation run** be considered. Production cutover remains a separate decision.
