# Supabase Migration — Focused Wealth Investment OS

Status: **PHASE 3 MODEL FACTORY — SAAS KERNEL EXPERIMENTAL PASS**  
Date: 2026-09-05  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`

## Objective
Migrate the Investment OS from spreadsheet-centered architecture to a hybrid architecture without breaking the live decision workflow. Supabase becomes authoritative layer-by-layer only after lineage, gates and regression tests pass. Human execution remains mandatory; no automatic trading.

## Phase 1 — Foundation PASS
Private schema `fwios` created with system/model/company/run/source/evidence/metric/candidate/blocker/sync foundations. RLS is enabled; `anon` and `authenticated` have no `fwios` privileges. The schema remains private.

Foundation snapshot: 41 sector archetypes, 17 valuation contracts, 15 research candidates, 15 blocker records / 7 open root blockers.

## Phase 2 — Research data parity PASS
Supabase became authoritative for Evidence → Canonical → Normalized research layers.

Migration baseline: 181 Evidence rows, 47 canonical rows, 53 normalized rows; zero duplicate Evidence IDs and zero canonical/evidence/source lineage orphans.

## Phase 3 — Valuation infrastructure PASS
Added explicit valuation control-plane structures:
- `metric_dependencies`
- `valuation_kernel_families`
- `valuation_model_versions`
- `valuation_runs`
- `valuation_scenarios`
- `valuation_run_inputs`
- `model_regression_runs`
- `blocker_candidate_map`
- `model_debt_profiles`
- `v_model_debt_controller`
- `v_operating_controller`

Phase 3 baseline: 97 dependency edges, 5 production model versions, 5 migrated production valuation snapshots, 15 scenarios, 40 mapped inputs and 5/5 snapshot regressions PASS. Decision Coverage remains 33.3%, so operating mode remains `MODEL_FACTORY_CRITICAL`.

## Phase 3 Model Factory — SaaS kernel
The first native executable kernel is now live privately in Supabase:

`fwios.fcf_compounder_fv(...)`

Kernel family: `FCF_COMPOUNDER`  
Kernel state: **IMPLEMENTED**  
Function security: private `fwios` schema; PUBLIC/anon/authenticated EXECUTE revoked; service role only.

### SaaS disclosure-contract correction
The original SaaS contract required both `arr_growth_yoy` and `nrr`. Production evidence showed that ADBE and CRM do not provide a consistently comparable NRR field suitable for a universal fail-closed required input. The contract was therefore versioned rather than silently substituting a different metric.

`SAAS_CONTRACT_V1_1` now requires:
- `recurring_growth_yoy`
- `gross_margin`
- `fcf_margin_ltm`
- `revenue_ltm`
- `fcf_ltm`
- `sbc_to_revenue`
- `net_cash`
- `shares_outstanding`

NRR remains an optional diagnostic when disclosed. `recurring_growth_yoy` is explicitly a disclosure-normalized proxy, **not NRR**:
- ADBE: Total Adobe ARR growth YoY proxy.
- CRM: organic subscription/support growth YoY excluding Informatica contribution proxy.

The proxy identity and source metric are preserved in canonical metadata; no semantic equivalence to NRR is asserted.

### SaaS production input path
Verified evidence already present in `Evidence_Ledger` was promoted through the canonical path and normalized as `NORM_V1-SAAS`.

Required input coverage:
- ADBE: **8 / 8 PASS**
- CRM: **8 / 8 PASS**

The evidence remains traceable to first-party/SEC records already stored in `fwios.evidence_records`.

### Experimental native valuation runs
Model version: `SAAS_EV_FCF_REVERSE_DCF_V1::1.1-EXPERIMENTAL`  
Status: **EXPERIMENTAL — NOT PRODUCTION ELIGIBLE**

Native Supabase kernel outputs:

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| ADBE | 340.7882 | 489.0870 | 731.7702 | 512.6831 |
| CRM | 156.7065 | 230.0284 | 352.2504 | 242.2534 |

These values are engineering outputs from the experimental FCF overlay, **not investment recommendations or production valuation signals**.

Scenario policy in the experimental overlay:
- Bear/Base/Bull probabilities = 25% / 50% / 25%.
- Base years 1–5 growth uses the disclosed recurring-growth proxy.
- Bear growth = base minus 4 percentage points with a 3% floor.
- Bull growth = base plus 4 percentage points with a 20% cap.
- Years 6–10 growth fades to 50% of early-stage growth with scenario floors.
- Discount rates = 13% / 12% / 11%.
- Terminal growth = 3.0% / 3.5% / 4.0%.

These are explicit model assumptions and are stored in model-version/scenario metadata, never represented as reported evidence.

## Fail-closed state
The SaaS blocker is **not closed yet**. ADBE and CRM have not been promoted to production valuation-ready status. `production_eligible=false` remains enforced on both experimental runs.

Before promotion the model must pass:
1. candidate valuation sanity/reverse-DCF calibration,
2. sensitivity and permanent-loss checks,
3. current-price/mispricing integration,
4. deterministic rerun/regression checks,
5. blocker-close transition test.

The existing five production valuation snapshots remain unchanged. No portfolio transaction or candidate promotion occurred.

## Security advisor
After the kernel change, the security advisor shows only the expected INFO notices `RLS Enabled No Policy` for private `fwios` tables. This is intentional because anon/authenticated have no schema/table access. No new exposed SECURITY DEFINER surface was introduced.

## Authority state
Supabase is authoritative for research data, canonical/normalized metrics, dependency/model metadata, migrated valuation snapshots, model-debt state and the new experimental kernel state.

Google Sheets `Intrinsic_Valuation_v2` remains the production valuation calculation authority until native compute parity/cutover criteria pass. `Data_Scoring_v2`, `Opportunity_Engine_v2`, portfolio holdings/transactions/positions and control-room presentation also remain downstream/live in Sheets.

## Next milestone
1. Validate/calibrate the experimental SaaS valuation overlay against reverse-DCF and sensitivity bands.
2. Add current market-price ingestion/gating without allowing price data to contaminate reported evidence.
3. Run fail-closed tests for missing/stale/conflicting SaaS inputs.
4. If all tests pass, promote SaaS model version to production and close `BLK-IT-SAAS-MDL-001`.
5. Recompute Decision Coverage; only then decide whether to continue model factory or resume sector discovery.
6. Do not migrate `Opportunity_Engine_v2` until native valuation compute authority is proven.
