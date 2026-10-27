# FWIOS Valuation Promotion Policy v1

Date: **2026-10-27 (Asia/Bangkok)**  
Live migration: **20261027015027 — valuation_promotion_policy_v1**  
Policy: **POL-VALUATION-PROMOTION-V1**  
Status: **ACTIVE / CONTROLLED APPLY + ROLLBACK / HUMAN AUTHORIZATION REQUIRED**

## Why this exists

ACN, EOG and NFLX now have validated period-aware v2 shadow valuation runs. Before this policy, each model required a long manual checklist before anyone could decide whether the shadow was safe enough to promote.

Promotion Policy v1 compresses that review into one deterministic result:

- `AUTO_ELIGIBLE`
- `MANUAL_REVIEW`
- `BLOCKED`

The preview policy does **not** promote a model or valuation by itself.

`AUTO_ELIGIBLE` means the shadow has cleared the standard gates and may be passed to the service-role-only `apply_valuation_promotion_v1()` function **only after explicit human authorization**.

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

### Apply function

`fwios.apply_valuation_promotion_v1(shadow_run_id)`

- requires the preview result to be `AUTO_ELIGIBLE`;
- never mutates the shadow run in place;
- creates a new deterministic `VAL-PROD-...` run with exact Fair Value parity to the approved shadow;
- copies scenarios, inputs and resolved lineage;
- promotes the v2 model version and retires the prior production version;
- retains the prior production run/version as rollback metadata;
- exact repeat calls return `NOOP_ALREADY_PROMOTED`;
- service-role-only and human-authorized; no portfolio or trade mutation.

### Rollback function

`fwios.rollback_valuation_promotion_v1(production_run_id)`

- only rolls back a run created by Promotion Policy v1;
- requires that promoted run to still be the current Dashboard production run;
- disables only the promoted production eligibility;
- restores the prior production model version and model-registry metadata;
- verifies the Dashboard returns to the recorded rollback run;
- service-role-only and never automatic.

### Readiness view

`fwios.v_valuation_promotion_readiness_v1`

Shows the latest experimental/non-production shadow candidate per ticker/model and the deterministic promotion result.

The view uses `security_invoker=true` and is service-role-only.

## Current results

ACN, EOG and NFLX were evaluated as `AUTO_ELIGIBLE` and subsequently promoted with explicit human authorization on 2026-10-27.

| Ticker | Production v2 run | PW Fair Value | Current production version |
|---|---|---:|---|
| ACN | `VAL-PROD-ACN-ITSERV-V2-20261026` | 240.71425210 | `IT_SERVICES_FCF_COMPOUNDER_V1::2.0` |
| EOG | `VAL-PROD-EOG-EP-V2-20261026` | 169.54150480 | `E&P_NORMALIZED_FCF_YIELD_V1::2.0` |
| NFLX | `VAL-PROD-NFLX-STREAM-V2-20261026` | 76.45212237 | `STREAMING_FCF_DCF_V1::2.0` |

The original shadow runs remain non-production approval artifacts. The prior v1 production runs remain available as rollback targets.

## Safety boundary

Policy configuration explicitly records:

- `auto_apply=false`
- `human_cutover_required=true`
- `portfolio_mutation=false`
- `auto_trade=false`

Therefore the policy simplifies review and provides controlled apply/rollback mechanics, but still does not bypass human authorization or create an automatic trading path.

## Regression

Live Supabase regression:

`FWIOS VALUATION PROMOTION POLICY V1: PASS (12/12, POST-CUTOVER)`

Coverage includes:

- active policy configuration;
- unknown-run fail-closed behavior;
- post-cutover fail-closed preview behavior;
- idempotent re-apply behavior;
- v2 production authority;
- shadow non-production boundary;
- Dashboard v2 cutover;
- function/view privileges;
- explicit non-mutating result contract.

No GitHub Actions workflow exists for this PR at the time of implementation; this is a live SQL regression result, not a CI claim.

## Simplified workflow after this change

Normal model-refresh path becomes:

`Evidence → Canonical Metrics → Resolver → Shadow Valuation → Promotion Policy`

Then:

- `AUTO_ELIGIBLE` → one explicit service-role promotion action after human authorization;
- `MANUAL_REVIEW` → inspect delta/method change;
- `BLOCKED` → fix the reported blocker.

This replaces repeated ad-hoc promotion checklists with one versioned deterministic policy.
