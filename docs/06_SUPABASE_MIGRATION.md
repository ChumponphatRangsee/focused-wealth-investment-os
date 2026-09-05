# Supabase Migration — Focused Wealth Investment OS

Status: **PHASE 3 MODEL FACTORY — MINING ASSET_NAV PARTIAL PASS / DISCOVERY ENABLED**  
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

Model: `SAAS_EV_FCF_REVERSE_DCF_V1` v1.1. ADBE and CRM canonical/normalized inputs and independent regressions are PASS. Their price/mispricing gates remain blocked and neither candidate was promoted.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| ADBE | 340.7882 | 489.0870 | 731.7702 | 512.6831 |
| CRM | 156.7065 | 230.0284 | 352.2504 | 242.2534 |

## Phase 3 Model Factory — Materials Specialty Chemicals / Industrial Gases PASS
The second reusable executable kernel is live:

`fwios.midcycle_cashflow_fv(...)`

Kernel family: `MIDCYCLE_CASHFLOW`  
Kernel state: **IMPLEMENTED**

Model: `MATERIALS_MIDCYCLE_FCF_DCF_V1` v1.0. LIN and PPG use three-year median reported CFO less capex as the mid-cycle starting FCF. Industrial-gas and coatings subtype assumptions remain separate. Project backlog is diagnostic and is not capitalized directly; current LTM cash flow is a cross-check rather than an automatic normalized starting level.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| LIN | 115.6977 | 169.5095 | 254.6389 | 177.3389 |
| PPG | 40.4529 | 64.8542 | 98.4271 | 67.1471 |

LIN and PPG independent regressions pass absolute tolerance 0.01. `BLK-MAT-CHEM-DEF-001` is CLOSED / PASS. Price/mispricing remains downstream and neither candidate was promoted.

## Phase 3 Model Factory — IT Services PASS
The original `IT Services / Hardware` archetype mixed two economically different business models. The model factory therefore decomposed the scope rather than forcing one valuation contract across both.

Current production archetype: **IT Services**  
Model: `IT_SERVICES_FCF_COMPOUNDER_V1`  
Version: **1.0**  
Kernel: `FCF_COMPOUNDER`  
Normalization: `NORM_V1-IT-SERVICES`  
Status: **IMPLEMENTED / PRODUCTION_V1**

Hardware is **not** covered by this model. Any future hardware candidate must fail closed until a separate hardware valuation route exists.

### ACN canonical / normalized contract
Required production metrics:
- `fcf_guidance_low`
- `fcf_guidance_midpoint`
- `fcf_guidance_high`
- `fy2026_revenue_growth_guidance_lc_mid`
- `book_to_bill_q3`
- `operating_margin_q3`
- `gross_margin_q3`
- `fcf_ltm`
- `net_cash`
- `shares_outstanding`

Additional diagnostics include ex-federal revenue-growth guidance, FCF margin, DSO and bookings.

Verified ACN anchors:
- LTM revenue through 2026-05-31: **USD 73.100594B**.
- LTM FCF: **USD 12.581688B**.
- FY2026 company FCF guidance: **USD 10.8B–11.5B**; midpoint **USD 11.15B**.
- FY2026 local-currency revenue-growth guidance midpoint: **3.5%**; ex estimated U.S. federal impact midpoint: **4.5%**.
- Q3 bookings / revenue ratio: **1.032**, treated economically as approximately 1.0 / neutral rather than an acceleration signal.
- Q3 gross margin: **32.8%**; operating margin: **17.0%**; DSO: **48 days**.
- Conservative net cash: **USD 5.029302B**.
- Shares outstanding: approximately **612M**.

The model intentionally does **not** use elevated LTM FCF as the starting cash flow because current LTM cash flow exceeds the company's FY2026 FCF guidance range and can be distorted by working-capital timing. Starting FCF is scenario-anchored to the company's current FY2026 guidance:
- Bear: USD 10.8B
- Base: USD 11.15B
- Bull: USD 11.5B

Scenario probabilities are 25% / 50% / 25%. Growth, discount and terminal parameters remain explicit valuation assumptions, never reported evidence.

Native valuation outputs:

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| ACN | 168.3159 | 225.4990 | 312.9248 | 233.0596 |

Independent Decimal/Python calculation was performed outside the database kernel. Regression `REG-ACN-ITSERV-20260905` is **PASS** at absolute tolerance 0.01.

`BLK-IT-HW-DEF-001` is now **CLOSED / PASS** for its active ACN dependency, with the resolution explicitly recording that hardware is not covered.

ACN state:
- intrinsic valuation compute: PASS
- valuation gate: PASS
- expected-return / current-price gate: BLOCKED - PRICE/MISPRICING PENDING
- mispricing gate: BLOCKED - PRICE/MISPRICING PENDING
- promotion gate: BLOCKED
- final decision: WAIT - PRICE/MISPRICING PENDING

No candidate was promoted and no portfolio transaction occurred.

## Phase 3 Model Factory — Mining ASSET_NAV PARTIAL PASS
A third reusable executable valuation kernel is now live privately in Supabase:

`fwios.asset_nav_fv(...)`

Kernel family: `ASSET_NAV`  
Kernel state: **IMPLEMENTED**  
Function security: private `fwios` schema; PUBLIC/anon/authenticated EXECUTE revoked; service role only.

Model: `MINING_ASSET_NAV_SOTP_V1`  
Version: **1.0**  
Normalization: `NORM_V1-MINING-NAV`  
Status: **IMPLEMENTED / PRODUCTION_V1**

The kernel values common equity from explicit components:

`core asset NAV + other asset value + cash - debt - other claims`

The model contract requires qualified-person / reserve NAV or another explicit normalized asset-value anchor, a full-company SOTP/replacement-cost bridge, and a non-overlapping balance-sheet bridge. Missing material business components fail closed. Peak spot commodity prices and future capex cannot be capitalized mechanically.

### ALB — full-company bridge PASS
Current qualified-person technical reports provide attributable post-tax NAV anchors for Greenbushes, Wodgina and Salar de Atacama. These technical-report values remain evidence/normalization inputs rather than canonical reported financial facts.

Normalized base resource NAV:
- Greenbushes attributable NPV10: **USD 3.3B**
- Wodgina attributable NPV10: **USD 1.6B**
- Salar de Atacama NPV10: **USD 1.4793B**
- Total selected resource QP NAV: **USD 6.3793B**

The FY2025 gross-asset replacement proxy for the same selected assets is USD 3.9144B. Current Albemarle shareholders' equity is USD 10.275169B, leaving an **other-equity bridge of USD 6.360769B** after removing those selected resource gross assets. That residual already contains corporate cash, liabilities, Specialties, Silver Peak and other assets, so cash/debt/other claims are zeroed in the kernel call to prevent double counting. Silver Peak receives no stale technical-report NAV uplift and remains inside the residual bridge.

ALB uses FY2026 diluted-share guidance of **136M shares**. Resource NAV is sensitized by ±20% for Bear/Base/Bull while the residual bridge remains constant.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| ALB | 84.2957 | 93.6770 | 103.0583 | 93.6770 |

Independent component-NAV calculation was performed outside the database kernel. Regression `REG-ALB-MIN-NAV-20260905` is **PASS** at absolute tolerance 0.01.

ALB state:
- intrinsic valuation compute: PASS
- valuation gate: PASS
- expected-return / current-price gate: BLOCKED - PRICE/MISPRICING PENDING
- mispricing gate: BLOCKED - PRICE/MISPRICING PENDING
- promotion gate: BLOCKED
- final decision: WAIT - PRICE/MISPRICING PENDING

### MP — full-company valuation intentionally fail-closed
The current Mountain Pass technical report supports an after-tax project NPV at 6% of approximately **USD 5.8B** for the Materials operation. Current balance-sheet facts are also available, but MP's Magnetics segment is material and is not fully represented by that Mountain Pass project NAV.

The 10X project has material future investment and a contractual EBITDA floor, but assigning current fair value from those data alone would require a remaining-capex/timing/incentive bridge and a non-overlapping value for Independence. Capitalizing announced future spend one-for-one would risk double counting.

Therefore MP remains:
- valuation readiness: BLOCKED
- valuation gate: BLOCKED - MAGNETICS NAV INCOMPLETE
- production eligible: false
- full-company fair value: NULL
- promotion gate: BLOCKED
- final decision: DATA BLOCKED - MAGNETICS NAV

The blocked diagnostic run stores a **Mountain Pass + current balance-sheet floor excluding Magnetics of approximately USD 32.71/share** in `raw_payload`. It is explicitly **not** a production intrinsic value and must not be used for a buy/sell decision.

The generic Mining definition blocker `BLK-MAT-MIN-DEF-001` is CLOSED / PASS because the reusable ASSET_NAV kernel and Mining model contract now exist. MP has been moved to a narrower blocker: `BLK-MP-MAGNETICS-NAV-001`.

No candidate was promoted and no portfolio transaction occurred.

## Decision Coverage / Operating Controller
Decision Coverage is now **73.3% (11/15)**, up from 66.7% after IT Services, 60.0% after Materials Specialty Chemicals / Industrial Gases, 46.7% after SaaS and 33.3% at the initial model-factory baseline.

Operating Controller: **`DISCOVERY`**  
Controller action: **Valuation support is healthy enough for broader sector discovery.**

The 70% discovery threshold has been crossed without forcing MP through an incomplete valuation.

Open root blockers remain **4** because the generic Mining blocker was replaced by the focused MP Magnetics blocker:
1. Semiconductor Designer — **73.80** (`MIDCYCLE_CASHFLOW`; QCOM)
2. Materials Packaging — **73.45** (`MIDCYCLE_CASHFLOW`; BALL)
3. Semiconductor Equipment / Foundry — **72.00** (`MIDCYCLE_CASHFLOW`; AMAT)
4. MP Magnetics full-company NAV — **28.35** (`ASSET_NAV`; MP)

These model-debt items remain in the queue but no longer block broader sector discovery while coverage remains at or above the controller threshold.

## Security state
`fwios` remains a private schema. `anon` and `authenticated` remain without `fwios` privileges; RLS remains enabled as defense in depth. `FCF_COMPOUNDER`, `MIDCYCLE_CASHFLOW` and `ASSET_NAV` executable kernels remain private/internal and no automatic trading surface exists.

Post-change security advisor shows only the expected `RLS Enabled No Policy` INFO notices for private `fwios` tables. No new warning/critical issue or exposed privileged function was introduced.

## Authority state
Supabase is authoritative for:
- Evidence / Canonical / Normalized research data,
- dependency and model registry state,
- blocker/model-debt state,
- production valuation snapshots,
- executable `FCF_COMPOUNDER`, `MIDCYCLE_CASHFLOW` and `ASSET_NAV` kernels,
- SaaS v1.1 intrinsic valuation compute for ADBE/CRM,
- Materials Specialty Chemicals / Industrial Gases v1.0 intrinsic valuation compute for LIN/PPG,
- IT Services v1.0 intrinsic valuation compute for ACN,
- Mining ASSET_NAV v1.0 full-company compute for ALB,
- fail-closed diagnostic lineage for MP while Magnetics SOTP remains incomplete.

Google Sheets remains the compatibility/control-room representation. Current-price/mispricing integration, `Data_Scoring_v2`, `Opportunity_Engine_v2`, portfolio holdings/transactions/positions and final human decision logic remain downstream.

## Next milestone
1. Follow the live Operating Controller and run-lock contract. `Sector_Run_Control` currently shows **Communication Services** as the current sector, **READY** stage, **IDLE** run lock and no current run ID; Supabase also has no Communication Services run record. Therefore the next discovery action is to **start** the Communication Services full-sector run, not resume an existing run.
2. Keep QCOM, BALL, AMAT and MP Magnetics model debt in the persistent queue. They do not need to be force-cleared before discovery while decision coverage remains >=70%.
3. Build current market-price / mispricing gating in Supabase as a separate market-data layer; never mix quote data into reported evidence/canonical facts.
4. Add deterministic stale/missing/conflicting-input tests around executable kernels.
5. Do not migrate `Opportunity_Engine_v2` until native valuation + price/mispricing compute parity is proven.
6. Human execution only; no automatic portfolio trades.
