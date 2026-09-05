# Supabase Migration — Focused Wealth Investment OS

Status: **PHASE 3 MODEL FACTORY — MINING ASSET_NAV PARTIAL PASS / DISCOVERY ENABLED**  
Date: **2026-09-05**  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`  
Execution contract: `FWIOS-CONTRACT-0.87.1`

## Objective

Migrate the Investment OS from spreadsheet-centered architecture to a hybrid architecture without breaking the live decision workflow. Supabase becomes authoritative layer-by-layer only after lineage, gates and regression tests pass. Human execution remains mandatory; no automatic trading.

Project-level status and next-action tracking now live in `docs/00_SYSTEM_ROADMAP.md`. This migration document records Supabase/migration state and must not override newer live controller state or the Master Roadmap.

## Phase 1 — Foundation PASS

Private schema `fwios` created with system/model/company/run/source/evidence/metric/candidate/blocker/sync foundations. RLS is enabled; `anon` and `authenticated` have no `fwios` privileges. The schema remains private.

Foundation snapshot: 41 sector archetypes, 17 valuation contracts, 15 research candidates.

## Phase 2 — Research data parity PASS

Supabase is authoritative for Evidence → Canonical → Normalized research layers.

Migration baseline:
- Evidence rows: 181
- Canonical rows: 47
- Normalized rows: 53
- duplicate Evidence IDs: 0
- canonical/evidence/source lineage orphans: 0

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

## Reusable production valuation infrastructure

### SaaS — PASS

Private kernel: `fwios.fcf_compounder_fv(...)`  
Kernel family: `FCF_COMPOUNDER`  
Model: `SAAS_EV_FCF_REVERSE_DCF_V1` v1.1  
Status: `PRODUCTION_V1`

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| ADBE | 340.7882 | 489.0870 | 731.7702 | 512.6831 |
| CRM | 156.7065 | 230.0284 | 352.2504 | 242.2534 |

ADBE/CRM canonical and normalized inputs plus independent regressions PASS. Price/mispricing remains downstream; neither candidate was promoted.

### Materials Specialty Chemicals / Industrial Gases — PASS

Private kernel: `fwios.midcycle_cashflow_fv(...)`  
Kernel family: `MIDCYCLE_CASHFLOW`  
Model: `MATERIALS_MIDCYCLE_FCF_DCF_V1` v1.0  
Status: `PRODUCTION_V1`

LIN and PPG use three-year median reported CFO less capex as the mid-cycle starting FCF. Industrial-gas and coatings subtype assumptions remain separate. Project backlog is diagnostic and is not capitalized directly; current LTM cash flow is a cross-check rather than an automatic normalized starting level.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| LIN | 115.6977 | 169.5095 | 254.6389 | 177.3389 |
| PPG | 40.4529 | 64.8542 | 98.4271 | 67.1471 |

Independent regressions PASS at absolute tolerance 0.01. `BLK-MAT-CHEM-DEF-001` is CLOSED / PASS.

### IT Services — PASS

The former `IT Services / Hardware` archetype mixed economically different businesses. The production route now covers **IT Services** only; future Hardware candidates fail closed until a separate route exists.

Model: `IT_SERVICES_FCF_COMPOUNDER_V1` v1.0  
Kernel: `FCF_COMPOUNDER`  
Normalization: `NORM_V1-IT-SERVICES`  
Status: `PRODUCTION_V1`

ACN verified anchors include:
- LTM revenue through 2026-05-31: USD 73.100594B
- LTM FCF: USD 12.581688B
- FY2026 FCF guidance: USD 10.8B–11.5B; midpoint USD 11.15B
- FY2026 local-currency revenue-growth guidance midpoint: 3.5%
- Q3 bookings/revenue: 1.032, treated as approximately neutral
- Q3 gross margin: 32.8%
- Q3 operating margin: 17.0%
- DSO: 48 days
- conservative net cash: USD 5.029302B
- shares outstanding: approximately 612M

The model uses company FY2026 FCF guidance rather than elevated LTM FCF as the starting cash flow.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| ACN | 168.3159 | 225.4990 | 312.9248 | 233.0596 |

Regression `REG-ACN-ITSERV-20260905` PASS at absolute tolerance 0.01. `BLK-IT-HW-DEF-001` is CLOSED / PASS for the active ACN dependency, explicitly excluding Hardware.

ACN remains `WAIT - PRICE/MISPRICING PENDING`; no promotion occurred.

### Mining / Commodities ASSET_NAV — PARTIAL PASS

Private kernel: `fwios.asset_nav_fv(...)`  
Kernel family: `ASSET_NAV`  
Model: `MINING_ASSET_NAV_SOTP_V1` v1.0  
Normalization: `NORM_V1-MINING-NAV`  
Status: `PRODUCTION_V1`

The model values common equity from:

`core asset NAV + other asset value + cash - debt - other claims`

It requires a qualified-person/reserve NAV or another explicit normalized asset-value anchor, a full-company SOTP/replacement-cost bridge and a non-overlapping balance-sheet bridge. Missing material business components fail closed. Peak spot commodity prices and future capex cannot be capitalized mechanically.

#### ALB — full-company bridge PASS

Selected normalized resource NAV anchors:
- Greenbushes attributable NPV10: USD 3.3B
- Wodgina attributable NPV10: USD 1.6B
- Salar de Atacama NPV10: USD 1.4793B
- selected resource QP NAV: USD 6.3793B

Selected FY2025 gross-asset replacement proxy: USD 3.9144B. Current Albemarle shareholders' equity: USD 10.275169B. Other-equity bridge after removing selected resource gross assets: USD 6.360769B. Because the residual already includes corporate cash, liabilities and other assets, cash/debt/other claims are zeroed in the kernel call to prevent double counting. Silver Peak remains in the residual bridge instead of receiving a stale technical-report NAV uplift.

Shares: 136M. Resource NAV is sensitized ±20% for Bear/Base/Bull.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| ALB | 84.2957 | 93.6770 | 103.0583 | 93.6770 |

Regression `REG-ALB-MIN-NAV-20260905` PASS at absolute tolerance 0.01. ALB remains `WAIT - PRICE/MISPRICING PENDING`.

#### MP — full-company valuation intentionally fail-closed

The Mountain Pass technical report supports an after-tax project NPV at 6% of approximately USD 5.8B for Materials, but MP's Magnetics segment is material and is not fully represented by that project NAV.

The 10X project has material future investment and a contractual EBITDA floor, but a production current fair value requires a remaining-capex/timing/incentive bridge plus a non-overlapping value for Independence. Capitalizing announced future spend one-for-one would risk double counting.

MP therefore remains:
- valuation readiness: BLOCKED
- valuation gate: `BLOCKED - MAGNETICS NAV INCOMPLETE`
- production eligible: false
- full-company fair value: NULL
- promotion gate: BLOCKED
- final decision: `DATA BLOCKED - MAGNETICS NAV`

The blocked diagnostic run stores a Mountain Pass + current balance-sheet floor excluding Magnetics of approximately **USD 32.71/share** in `raw_payload`. It is explicitly not a production intrinsic value and must not drive a buy/sell decision.

The generic Mining blocker `BLK-MAT-MIN-DEF-001` is CLOSED / PASS. MP's focused blocker is `BLK-MP-MAGNETICS-NAV-001`.

## Decision Coverage / Operating Controller

Decision Coverage: **73.3% (11/15)**  
Operating Controller: **`DISCOVERY`**  
Controller action: valuation support is sufficient for broader sector discovery.

Open root model blockers:
1. Semiconductor Designer / QCOM — **73.80** — `BLK-IT-SEMI-MDL-001`
2. Materials Packaging / BALL — **73.45** — `BLK-MAT-PACK-DEF-001`
3. Semiconductor Equipment / Foundry / AMAT — **72.00** — `BLK-IT-SEMICAP-MDL-001`
4. MP Magnetics full-company NAV — **71.55** — `BLK-MP-MAGNETICS-NAV-001`

These model-debt items remain fail-closed but do not block broader discovery while coverage remains at or above the controller threshold.

## Security state

`fwios` remains private. `anon` and `authenticated` remain without `fwios` privileges; RLS remains enabled as defense in depth. `FCF_COMPOUNDER`, `MIDCYCLE_CASHFLOW` and `ASSET_NAV` executable kernels remain private/internal. Human execution only; no automatic trading surface exists.

Post-change security advisor state from the Mining workstream showed only expected `RLS Enabled No Policy` INFO notices for private `fwios` tables and no new warning/critical exposure.

## Authority state

Supabase is authoritative for:
- Evidence / Canonical / Normalized research data
- dependency and model registry state
- blocker/model-debt state
- production valuation snapshots
- executable `FCF_COMPOUNDER`, `MIDCYCLE_CASHFLOW` and `ASSET_NAV` kernels
- SaaS ADBE/CRM valuation compute
- Materials Specialty Chemicals / Industrial Gases LIN/PPG valuation compute
- IT Services ACN valuation compute
- Mining full-company ALB valuation compute
- fail-closed diagnostic lineage for MP while Magnetics SOTP remains incomplete

Google Sheets remains the compatibility/control-room representation. Current-price/mispricing integration, `Data_Scoring_v2`, `Opportunity_Engine_v2`, portfolio holdings/transactions/positions and final human decision logic remain downstream.

## Roadmap governance cutover

`docs/00_SYSTEM_ROADMAP.md` is now the persistent project-status index required by `FWIOS-CONTRACT-0.87.1`.

For material work, AI must read:
1. live `System_Foundation` and relevant run/controller state
2. `AGENTS.md`
3. `contracts/system-contract.yaml`
4. `VERSION`
5. `docs/00_SYSTEM_ROADMAP.md`

Live state overrides a stale roadmap. Material changes that alter capability, milestone status, blockers, authority/cutover or next action must update the roadmap in the same workstream.

## Next milestone

Communication Services research is complete under RPV2.0. The recorded 20→8→5→3 run took 14.4 minutes and added three model blockers. Coverage is 11/18 (61.1%), so the live controller requires model work before another sector.

The [master roadmap](00_SYSTEM_ROADMAP.md) and [closeout report](07_RESEARCH_CLOSEOUT.md) track the two remaining M1 hardening gaps. Implement Digital Advertising valuation after those corrections; price/mispricing and final opportunity cutover remain pending. Keep research completion separate from investment readiness.
