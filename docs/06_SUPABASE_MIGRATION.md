# Supabase Migration — Focused Wealth Investment OS

Status: **PHASE 3 MODEL FACTORY — MATERIALS CHEM PASS**  
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
`SAAS_CONTRACT_V1_1` requires:
- `recurring_growth_yoy`
- `gross_margin`
- `fcf_margin_ltm`
- `revenue_ltm`
- `fcf_ltm`
- `sbc_to_revenue`
- `net_cash`
- `shares_outstanding`

NRR is an optional diagnostic when disclosed. `recurring_growth_yoy` is explicitly a disclosure-normalized recurring-growth proxy, not NRR.

Required input coverage:
- ADBE: **8 / 8 PASS**
- CRM: **8 / 8 PASS**

Model: `SAAS_EV_FCF_REVERSE_DCF_V1`  
Version: **1.1**  
Status: **IMPLEMENTED / PRODUCTION_V1**

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| ADBE | 340.7882 | 489.0870 | 731.7702 | 512.6831 |
| CRM | 156.7065 | 230.0284 | 352.2504 | 242.2534 |

ADBE and CRM regressions pass absolute tolerance 0.01. Their current-price/mispricing gates remain blocked; neither was promoted.

## Phase 3 Model Factory — Materials Specialty Chemicals / Industrial Gases PASS
The second reusable executable kernel is now live:

`fwios.midcycle_cashflow_fv(...)`

Kernel family: `MIDCYCLE_CASHFLOW`  
Kernel state: **IMPLEMENTED**  
Function security: private `fwios` schema; PUBLIC/anon/authenticated EXECUTE revoked; service role only.

### Materials valuation contract v1.0
Model: `MATERIALS_MIDCYCLE_FCF_DCF_V1`  
Version: **1.0**  
Normalization: `NORM_V1-MAT-CHEM`  
Status: **IMPLEMENTED / PRODUCTION_V1**

Required canonical metrics:
- `fcf_ltm`
- `fcf_3y_median`
- `capex_ltm`
- `net_debt`
- `shares_outstanding`
- `organic_sales_growth`

The production starting cash-flow anchor is three-year median reported CFO minus capex. This prevents a single working-capital or capex period from being mistaken for normalized economics.

Subtype policy:
- **Industrial gases (LIN):** tighter scenario bands reflect contracted/on-site durability. Project backlog is a diagnostic and is never capitalized directly into fair value.
- **Coatings (PPG):** wider downside bands reflect cyclical end markets and working-capital volatility. Current LTM cash-flow improvement is a cross-check, not automatically the normalized starting level.
- `net_debt` remains a leverage diagnostic because the kernel discounts equity FCF after interest; subtracting debt again would double count leverage.

Verified normalized anchors:
- LIN normalized mid-cycle FCF: **USD 5.089B**; LTM FCF cross-check: **USD 4.975B**; shares: **460.980163M**.
- PPG normalized mid-cycle FCF: **USD 1.163B**; LTM FCF cross-check: **USD 1.407B**; shares: **222.3M**.

Native valuation outputs:

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| LIN | 115.6977 | 169.5095 | 254.6389 | 177.3389 |
| PPG | 40.4529 | 64.8542 | 98.4271 | 67.1471 |

Independent calculations were performed outside the database kernel and compared against Supabase outputs. Both pass absolute tolerance 0.01:
- LIN regression `REG-LIN-MAT-20260905`: **PASS**
- PPG regression `REG-PPG-MAT-20260905`: **PASS**

`BLK-MAT-CHEM-DEF-001` is now **CLOSED / PASS**.

This does not make LIN or PPG buy candidates. Their current state is:
- intrinsic valuation compute: PASS
- valuation gate: PASS
- expected-return / current-price gate: BLOCKED - PRICE/MISPRICING PENDING
- mispricing gate: BLOCKED - PRICE/MISPRICING PENDING
- promotion gate: BLOCKED
- final decision: WAIT - PRICE/MISPRICING PENDING

No candidate was promoted and no portfolio transaction occurred.

## Decision Coverage / Operating Controller
Decision Coverage is now **60.0% (9/15)**, up from 46.7% after the SaaS pass and 33.3% at the initial model-factory baseline.

Operating Controller: **`MODEL_FACTORY_AFTER_CURRENT_SECTOR`**  
Controller action: **Finish current sector, then run a model sprint.**

Open root blockers: **5**.

Current Model Debt Controller ranking:
1. IT Services / Hardware — **81.05** (`FCF_COMPOUNDER`; ACN)
2. Materials Mining / Commodities — **78.55** (`ASSET_NAV`; ALB + MP)
3. Semiconductor Designer — **73.80** (`MIDCYCLE_CASHFLOW`; QCOM)
4. Materials Packaging — **73.45** (`MIDCYCLE_CASHFLOW`; BALL)
5. Semiconductor Equipment / Foundry — **72.00** (`MIDCYCLE_CASHFLOW`; AMAT)

## Security advisor
Post-change security advisor shows only expected INFO notices `RLS Enabled No Policy` on private `fwios` tables. This remains intentional: RLS is enabled as defense in depth while `anon` and `authenticated` have no schema/table privileges. No new exposed SECURITY DEFINER surface was introduced.

## Authority state
Supabase is authoritative for:
- Evidence / Canonical / Normalized research data,
- dependency and model registry state,
- blocker/model-debt state,
- production valuation snapshots,
- executable `FCF_COMPOUNDER` and `MIDCYCLE_CASHFLOW` kernels,
- SaaS v1.1 intrinsic valuation compute for ADBE/CRM,
- Materials Specialty Chemicals / Industrial Gases v1.0 intrinsic valuation compute for LIN/PPG.

Google Sheets remains the compatibility/control-room representation. Current-price/mispricing integration, `Data_Scoring_v2`, `Opportunity_Engine_v2`, portfolio holdings/transactions/positions and final human decision logic remain downstream.

## Next milestone
1. Follow the live Operating Controller. With Materials research already complete, the next model sprint priority is IT Services / Hardware (`BLK-IT-HW-DEF-001`, ACN), unless live controller state changes.
2. Build current market-price / mispricing gating in Supabase as a separate market-data layer; never mix quote data into reported evidence/canonical facts.
3. Add deterministic stale/missing/conflicting-input tests around executable kernels.
4. Do not migrate `Opportunity_Engine_v2` until native valuation + price/mispricing compute parity is proven.
5. Human execution only; no automatic portfolio trades.
