# Supabase Migration — Focused Wealth Investment OS

Status: **PHASE 3 MODEL FACTORY — SAAS PASS**  
Date: 2026-09-05  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`

## Objective
Migrate the Investment OS from spreadsheet-centered architecture to a hybrid architecture without breaking the live decision workflow. Supabase becomes authoritative layer-by-layer only after lineage, gates and regression tests pass. Human execution remains mandatory; no automatic trading.

## Phase 1 — Foundation PASS
Private schema `fwios` created with system/model/company/run/source/evidence/metric/candidate/blocker/sync foundations. RLS is enabled; `anon` and `authenticated` have no `fwios` privileges. The schema remains private.

Foundation snapshot: 41 sector archetypes, 17 valuation contracts, 15 research candidates.

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

Initial Phase 3 baseline: 97 dependency edges, 5 migrated production model versions, 5 production valuation snapshots, 15 scenarios, 40 mapped inputs and 5/5 snapshot regressions PASS.

## Phase 3 Model Factory — SaaS PASS
The first reusable executable valuation kernel is live privately in Supabase:

`fwios.fcf_compounder_fv(...)`

Kernel family: `FCF_COMPOUNDER`  
Kernel state: **IMPLEMENTED**  
Function security: private `fwios` schema; PUBLIC/anon/authenticated EXECUTE revoked; service role only.

### SaaS disclosure-contract v1.1
The original SaaS contract required both `arr_growth_yoy` and `nrr`. Production evidence showed that ADBE and CRM do not provide a consistently comparable NRR field suitable for a universal fail-closed required input. The contract was therefore versioned rather than silently substituting a different metric.

`SAAS_CONTRACT_V1_1` requires:
- `recurring_growth_yoy`
- `gross_margin`
- `fcf_margin_ltm`
- `revenue_ltm`
- `fcf_ltm`
- `sbc_to_revenue`
- `net_cash`
- `shares_outstanding`

NRR is an optional diagnostic when disclosed. `recurring_growth_yoy` is explicitly a disclosure-normalized recurring-growth proxy, **not NRR**:
- ADBE: Total Adobe ARR growth YoY proxy.
- CRM: organic subscription/support growth YoY excluding Informatica contribution proxy.

The proxy identity and source metric remain preserved in canonical metadata.

### SaaS production input path
Verified evidence already present in `fwios.evidence_records` was promoted through the canonical path and normalized as `NORM_V1-SAAS`.

Required input coverage:
- ADBE: **8 / 8 PASS**
- CRM: **8 / 8 PASS**

### Native valuation runs and regression
Model: `SAAS_EV_FCF_REVERSE_DCF_V1`  
Version: **1.1**  
Status: **IMPLEMENTED / PRODUCTION_V1**

Native Supabase kernel outputs:

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| ADBE | 340.7882 | 489.0870 | 731.7702 | 512.6831 |
| CRM | 156.7065 | 230.0284 | 352.2504 | 242.2534 |

Independent regression anchors were calculated outside the database kernel and compared against Supabase outputs. Both candidates pass absolute tolerance 0.01:
- ADBE regression: **PASS**
- CRM regression: **PASS**

Scenario policy:
- Bear/Base/Bull probabilities = 25% / 50% / 25%.
- Base years 1–5 growth uses the disclosed recurring-growth proxy.
- Bear growth = base minus 4 percentage points with a 3% floor.
- Bull growth = base plus 4 percentage points with a 20% cap.
- Years 6–10 growth fades to 50% of early-stage growth with scenario floors.
- Discount rates = 13% / 12% / 11%.
- Terminal growth = 3.0% / 3.5% / 4.0%.

These growth/discount/terminal parameters are explicit valuation assumptions, not reported evidence.

## Fail-closed state after SaaS implementation
`BLK-IT-SAAS-MDL-001` is now **CLOSED / PASS** because the missing model implementation itself is resolved.

This does **not** mean ADBE or CRM are buy candidates. Their current state is:
- intrinsic valuation compute: PASS
- valuation gate: PASS
- expected-return / current-price gate: BLOCKED - PRICE/MISPRICING PENDING
- mispricing gate: BLOCKED - PRICE/MISPRICING PENDING
- promotion gate: BLOCKED
- final decision: WAIT - PRICE/MISPRICING PENDING

No candidate was promoted and no portfolio transaction occurred.

## Decision Coverage / Operating Controller
Decision Coverage improved from **33.3% (5/15)** to **46.7% (7/15)** because ADBE and CRM are now valuation-ready.

Operating Controller moved from `MODEL_FACTORY_CRITICAL` to **`MODEL_FACTORY`**.

Current policy action: prioritize model factory before additional sector breadth.

Open root blockers: **6**.

Current Model Debt Controller ranking:
1. Materials Specialty Chemicals / Industrial Gases — **87.30**
2. IT Services / Hardware — **81.05**
3. Materials Mining / Commodities — **78.55**
4. Semiconductor Designer — **73.80**
5. Materials Packaging — **73.45**
6. Semiconductor Equipment / Foundry — **72.00**

## Security advisor
Post-change security advisor shows only expected INFO notices `RLS Enabled No Policy` on private `fwios` tables. This is intentional: RLS is enabled as defense in depth while `anon` and `authenticated` have no schema/table privileges. No new exposed SECURITY DEFINER surface was introduced.

## Authority state
Supabase is authoritative for:
- Evidence / Canonical / Normalized research data,
- dependency and model registry state,
- blocker/model-debt state,
- production valuation snapshots,
- the executable `FCF_COMPOUNDER` kernel,
- SaaS v1.1 intrinsic valuation compute for ADBE/CRM.

Google Sheets remains the compatibility/control-room representation. Current-price/mispricing integration, `Data_Scoring_v2`, `Opportunity_Engine_v2`, portfolio holdings/transactions/positions and final human decision logic remain downstream.

## Next milestone
1. Build the next highest-value reusable valuation route, led by Materials Specialty Chemicals / Industrial Gases or IT Services / Hardware.
2. Integrate current market-price / mispricing gating into Supabase without contaminating evidence/canonical layers.
3. Add deterministic stale/missing/conflicting-input tests around executable kernels.
4. Do not migrate `Opportunity_Engine_v2` until native valuation + price/mispricing compute parity is proven.
5. Human execution only; no automatic portfolio trades.
