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

## ACN current-period primary evidence PREVIEW

The remaining required current-period inputs were closed from primary sources and submitted to the existing controlled research PREVIEW. No APPLY was executed.

Reviewed input set:

| Input | PREVIEW value | Period |
|---|---:|---|
| FREE_CASH_FLOW | 11.620598 USD B | FY2026 / LTM ended 2026-08-31 |
| NET_CASH | 2.726011 USD B | 2026-08-31 |
| SHARES_OUTSTANDING | 596.1 M shares | 2026-08-31 |
| FCF_GUIDANCE_LOW | 11.0 USD B | FY2027 guidance |
| FCF_GUIDANCE_MIDPOINT | 11.4 USD B | FY2027 guidance |
| FCF_GUIDANCE_HIGH | 11.8 USD B | FY2027 guidance |
| REVENUE_GROWTH_GUIDANCE_LC_MID | 4.5% | FY2027 guidance |

Net cash is derived consistently with the existing model convention:

`cash + short-term investments - current debt/bank borrowings - long-term debt`

= `12.831471 + 0.006298 - 0.113069 - 9.998689 = 2.726011 USD B`.

Primary sources:

- Accenture Q4/FY2026 earnings release/presentation dated 2026-10-01;
- Accenture FY2026 Form 10-K, accession `0001467373-26-000049`.

Controlled PREVIEW result:

- overall status: **PASS**;
- evidence: **2/2 PASS**, Tier A;
- metrics: **7/7 PASS**;
- blockers: **0**;
- warnings: **0**;
- production changes: **NONE**;
- payload fingerprint: `d7f54abe68b06e654f6ce58b20910c19`.

The production canonical store still contains the older ACN rows because APPLY has not been authorized/executed. Therefore the production resolver remains fail-closed; the complete current set exists only in the reviewed PREVIEW payload.

## Read-only ACN v2 shadow valuation

Using the reviewed PREVIEW values, ACN v2 model assumptions, and the same 10-year FCF DCF kernel behavior as production v1:

| Scenario | Production v1 FV | Shadow v2 FV | Change |
|---|---:|---:|---:|
| Bear | 168.31587961 | 171.98535827 | +2.18% |
| Base | 225.49896206 | 232.65156828 | +3.17% |
| Bull | 312.92478576 | 325.56851356 | +4.04% |
| Probability-weighted | 233.05964737 | 240.71425210 | +3.28% |

Using the current dashboard price of 249.415, shadow v2 probability-weighted upside is approximately **-3.49%**. This is a valuation comparison only, not a BUY/SELL recommendation.

Regression `tests/valuation/test_acn_current_inputs_shadow_v2.sql` returned:

`FWIOS ACN CURRENT INPUTS + SHADOW V2: PASS (8/8, READ-ONLY)`

It verifies deterministic PREVIEW, no research-state mutation, exact shadow outputs, unchanged production v1 and absence of any v2 valuation run.

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

The evidence/metric payload and shadow valuation are now review-complete.

The next state-changing step is **controlled research APPLY of the exact PREVIEW payload**. That step would create canonical evidence/metric observations and must remain separately authorized under the current production boundary.

After an authorized APPLY:

1. verify receipt/idempotency and exact observation keys;
2. rerun the contract-driven v2 resolver against canonical observations;
3. require all 7 required selectors to PASS;
4. create a new immutable **shadow/non-production** v2 valuation run first;
5. compare v1/v2 lineage and Fair Value;
6. consider production model/read cutover only as a later separate decision.
