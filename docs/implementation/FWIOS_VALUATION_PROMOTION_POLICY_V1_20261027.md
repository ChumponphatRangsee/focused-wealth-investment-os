# FWIOS Valuation Promotion Policy v1

Date: **2026-10-27 (Asia/Bangkok)**  
Live migration: **20261027015027 — valuation_promotion_policy_v1**  
Policy: **POL-VALUATION-PROMOTION-V1**  
Status: **ACTIVE / NON-MUTATING / HUMAN CUTOVER REQUIRED**

## Why this exists

ACN, EOG and NFLX now have validated period-aware v2 shadow valuation runs. Before this policy, each model required a long manual checklist before anyone could decide whether the shadow was safe enough to promote.

Promotion Policy v1 compresses that review into one deterministic result:

- `AUTO_ELIGIBLE`
- `MANUAL_REVIEW`
- `BLOCKED`

The policy does **not** promote a model or valuation by itself.

`AUTO_ELIGIBLE` means the shadow has cleared the standard gates and is ready for a future **single explicit human-approved promotion action**.

## Deterministic gates

A shadow is blocked unless all hard gates pass:

1. shadow run exists and remains `production_eligible=false`;
2. shadow model version is `EXPERIMENTAL`;
3. model regression status is `PASS`;
4. `production_read_cutover=false`;
5. exactly one current production model version exists;
6. shadow version explicitly supersedes the current production version;
7. **100% of required inputs PASS**;
8. every required input is backed by canonical metric observation evidence that is:
   - Tier A,
   - VERIFIED,
   - machine PASS,
   - conflict-free;
9. metric-input lineage is complete for the shadow run;
10. valuation/router/schema/readiness gates all PASS;
11. shadow run has no auto-trade or production-cutover mutation flag;
12. current production run remains available as the rollback target.

## Delta policy

After hard gates pass:

- max absolute Fair Value scenario delta **<= 15%** + same kernel family → `AUTO_ELIGIBLE`;
- otherwise → `MANUAL_REVIEW`;
- delta above **30%** adds a high-delta review reason.

The delta check uses the largest absolute change across Bear, Base, Bull and probability-weighted Fair Value rather than only the PW result.

This is intentionally more conservative than checking only a single Fair Value number.

## Runtime objects

### Preview function

`fwios.preview_valuation_promotion_v1(shadow_run_id)`

Returns:

- promotion status;
- current production and rollback run/version IDs;
- input/evidence/lineage checks;
- Bear/Base/Bull/PW deltas;
- blockers;
- review reasons;
- suggested action.

The function is stable, security-invoker and non-mutating.

Execution is revoked from PUBLIC, anon and authenticated; service role is explicitly allowed.

### Readiness view

`fwios.v_valuation_promotion_readiness_v1`

Shows the latest experimental/non-production shadow candidate per ticker/model and the deterministic promotion result.

The view uses `security_invoker=true` and is service-role-only.

## Current results

| Ticker | Shadow version | Max absolute FV delta | Result |
|---|---|---:|---|
| ACN | IT_SERVICES_FCF_COMPOUNDER_V1::2.0 | 4.04% | **AUTO_ELIGIBLE** |
| EOG | E&P_NORMALIZED_FCF_YIELD_V1::2.0 | ~0.00% | **AUTO_ELIGIBLE** |
| NFLX | STREAMING_FCF_DCF_V1::2.0 | 3.74% | **AUTO_ELIGIBLE** |

All three also pass:

- required-input completeness;
- Tier-A verified/conflict-free evidence;
- complete metric lineage;
- model regression;
- same-kernel check;
- explicit supersedes chain;
- singular current production version;
- mutation safety.

## Safety boundary

Policy configuration explicitly records:

- `auto_apply=false`
- `human_cutover_required=true`
- `portfolio_mutation=false`
- `auto_trade=false`

Therefore the policy simplifies review but does not bypass human authorization or create an automatic trading path.

## Regression

Live Supabase regression:

`FWIOS VALUATION PROMOTION POLICY V1: PASS (12/12, NON-MUTATING)`

Coverage includes:

- active policy configuration;
- unknown-run fail-closed behavior;
- ACN/EOG/NFLX eligibility;
- input/evidence gates;
- lineage;
- unchanged production Dashboard;
- shadow non-production boundary;
- function/view privileges;
- explicit non-mutating result contract.

No GitHub Actions workflow exists for this PR at the time of implementation; this is a live SQL regression result, not a CI claim.

## Simplified workflow after this change

Normal model-refresh path becomes:

`Evidence → Canonical Metrics → Resolver → Shadow Valuation → Promotion Policy`

Then:

- `AUTO_ELIGIBLE` → one explicit promotion action;
- `MANUAL_REVIEW` → inspect delta/method change;
- `BLOCKED` → fix the reported blocker.

This replaces repeated ad-hoc promotion checklists with one versioned deterministic policy.
