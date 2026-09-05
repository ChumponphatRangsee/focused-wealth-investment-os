# Supabase Migration — Focused Wealth Investment OS

Status: **PHASE 3 VALUATION CONTROL PLANE PASS / RPV2.1 HARDENED / M2 NEXT**  
Date: **2026-09-05**  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`  
Execution contract: `FWIOS-CONTRACT-0.87.2`

## Objective

Migrate the Investment OS from spreadsheet-centered architecture to a hybrid architecture without breaking the live decision workflow. Supabase becomes authoritative layer-by-layer only after lineage, gates and regression tests pass. Human execution remains mandatory; no automatic trading.

Project-level status and next-action tracking live in `docs/00_SYSTEM_ROADMAP.md`. This migration document records Supabase/migration state and must not override newer live controller state or the Master Roadmap.

## Phase 1 — Foundation PASS

Private schema `fwios` contains system/model/company/run/source/evidence/metric/candidate/blocker/sync foundations. RLS is enabled; `anon` and `authenticated` have no `fwios` privileges. The schema remains private.

Foundation snapshot began with 41 sector archetypes, 17 valuation contracts and 15 research candidates. Additional valuation contracts/models have since been configured without changing foundation compatibility 0.87.

## Phase 2 — Research data parity PASS

Supabase is authoritative for Evidence → Canonical → Normalized research layers.

Original migration baseline:
- Evidence rows: 181
- Canonical rows: 47
- Normalized rows: 53
- duplicate Evidence IDs: 0
- canonical/evidence/source lineage orphans: 0

Communication Services subsequently expanded the evidence-ready candidate set to 18.

## Research Pipeline v2.1 — CORE HARDENING PASS

Communication Services `SECTOR-CS-FULL-20260905-01` recorded the first staged production pilot:
- Fast Discovery 20 → 8: 235.985 seconds
- Light Research 8 → 5: 188.735 seconds
- Deep Research 5 → 3: 439.009 seconds
- total recorded stage time: 863.729 seconds / 14.4 minutes
- deep Tier-A evidence: RDDT 8, PINS 8, NFLX 9

Post-closeout review found two correctness gaps. RPV2.1 now fixes both:

1. `v_latest_reusable_evidence` recomputes age at read time, requires exact Source Registry provenance, supports deterministic ISO and legacy Google Sheet serial dates, and invalidates older current reporting evidence after a later material reporting event. Historical-reference evidence remains separately eligible.
2. `v_research_pipeline_controller` now allows the current sector to close in `MODEL_FACTORY_AFTER_CURRENT_SECTOR` while blocking a new sector. Under `DISCOVERY`, affected model-debt candidates remain fail-closed without blocking broader discovery.

Behavioral regressions PASS:
- `REG-M1-CACHE-EVENT-20260905`
- `REG-M1-CACHE-AGE-20260905`
- `REG-M1-CACHE-PROV-20260905`
- `REG-M1-DATE-PARSE-20260905`

The hardened reusable-evidence view currently exposes 221 eligible records. Parallel top-candidate execution remains a performance-validation item, not a correctness blocker for M2.

## Phase 3 — Valuation infrastructure PASS

Valuation control-plane structures include:
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

Reusable private kernels:
- `FCF_COMPOUNDER`
- `MIDCYCLE_CASHFLOW`
- `ASSET_NAV`

### SaaS — PASS

Model: `SAAS_EV_FCF_REVERSE_DCF_V1` v1.1 on `FCF_COMPOUNDER`, confidence `PRODUCTION_V1`.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| ADBE | 340.7882 | 489.0870 | 731.7702 | 512.6831 |
| CRM | 156.7065 | 230.0284 | 352.2504 | 242.2534 |

ADBE/CRM canonical and normalized inputs plus independent regressions PASS. Price/mispricing remains downstream; neither candidate was promoted.

### Materials Specialty Chemicals / Industrial Gases — PASS

Model: `MATERIALS_MIDCYCLE_FCF_DCF_V1` v1.0 on `MIDCYCLE_CASHFLOW`, confidence `PRODUCTION_V1`.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| LIN | 115.6977 | 169.5095 | 254.6389 | 177.3389 |
| PPG | 40.4529 | 64.8542 | 98.4271 | 67.1471 |

Independent regressions PASS at absolute tolerance 0.01. `BLK-MAT-CHEM-DEF-001` is CLOSED / PASS.

### IT Services — PASS

Model: `IT_SERVICES_FCF_COMPOUNDER_V1` v1.0 on `FCF_COMPOUNDER`, normalization `NORM_V1-IT-SERVICES`, confidence `PRODUCTION_V1`.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| ACN | 168.3159 | 225.4990 | 312.9248 | 233.0596 |

The active route covers IT Services only. Hardware remains explicitly uncovered and must fail closed if a Hardware candidate enters the pipeline. Regression `REG-ACN-ITSERV-20260905` PASS.

### Mining / Commodities ASSET_NAV — PARTIAL PASS

Model: `MINING_ASSET_NAV_SOTP_V1` v1.0 on `ASSET_NAV`, normalization `NORM_V1-MINING-NAV`, confidence `PRODUCTION_V1`.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| ALB | 84.2957 | 93.6770 | 103.0583 | 93.6770 |

Regression `REG-ALB-MIN-NAV-20260905` PASS. ALB remains `WAIT - PRICE/MISPRICING PENDING`.

MP remains intentionally fail-closed because Mountain Pass project NAV does not cover the material Magnetics business. `BLK-MP-MAGNETICS-NAV-001` remains open. The diagnostic Mountain Pass/balance-sheet floor stored in `raw_payload` is not a production intrinsic value.

### Digital Advertising — PASS

Model: `DIGITAL_ADS_FCF_REVERSE_DCF_V1` v1.0  
Kernel: `FCF_COMPOUNDER`  
Normalization: `NORM_V1-DIGADS`  
Confidence: `PRODUCTION_V1`

RDDT/PINS each have 9/9 normalized inputs PASS:
- revenue LTM
- ad/monetization growth
- engagement growth
- GAAP operating margin
- FCF LTM
- capex LTM
- net cash
- shares outstanding
- SBC / revenue

The v1.0 growth policy blends current ad/monetization growth and engagement growth, caps base long-duration growth at 22%, applies scenario-specific decay/discount/terminal assumptions, and uses GAAP operating margin, capex intensity, positive FCF and SBC/revenue as sanity gates. Forward guidance is a cross-check only and is never extrapolated directly as long-duration growth.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| RDDT | 92.3017 | 142.5985 | 237.7178 | 153.8041 |
| PINS | 25.3199 | 40.6020 | 69.4854 | 44.0023 |

Independent regressions:
- `REG-RDDT-DIGADS-20260905` PASS
- `REG-PINS-DIGADS-20260905` PASS

`BLK-COMM-DADS-MDL-001` is CLOSED / PASS. Both candidates still remain `WAIT - PRICE/MISPRICING PENDING`; current-price/expected-return promotion is intentionally blocked until M2.

## Decision Coverage / Operating Controller

Current live snapshot after Digital Advertising closeout:
- Evidence-ready candidates: **18**
- Valuation-ready candidates: **13**
- Decision Coverage: **72.2%**
- Operating Controller: **`DISCOVERY`**
- Controller action: decision coverage is sufficient to continue discovery
- RPV2.1 `sector_discovery_allowed`: **true**
- Open root model debt: **6**

Remaining model debt by current resolution value:
1. QCOM / Semiconductor Designer — 73.80
2. Streaming / Media — 73.70
3. BALL / Packaging — 73.45
4. AMAT / Semiconductor Equipment / Foundry — 72.00
5. MP Magnetics full-company NAV — 71.55
6. Telecom — 12.00

These remain fail-closed but no longer block broader discovery under the current controller. Main Roadmap priority nevertheless advances to M2 rather than automatically starting the queued Financials sector.

## Portfolio State migration dependency

`Investment Portfolio Tracker - Chumponphat` is the designated source for M2/M3 portfolio-state migration.

Before Portfolio Fit/Rebalancing cutover, Supabase must reconcile at minimum:
- accounts
- transactions
- assets / asset classes
- quantity and net quantity
- trade price, fees, currency and FX
- THB cash flow
- running quantity and cost basis
- average cost
- realized/unrealized state
- holdings/allocation/exposure state
- thesis/action context where available

Do not retire or delete the tracker until transaction, position, cost-basis, realized-P&L and allocation parity pass. After cutover, the intended Sheet role is read-only reconciliation/audit/export/archive.

## Security state

`fwios` remains private. `anon` and `authenticated` remain without `fwios` privileges; RLS remains enabled as defense in depth. Executable kernels remain private/internal. Human execution only; no automatic trading surface exists.

Post-RPV2.1 DDL security advisor showed only expected `RLS Enabled No Policy` INFO notices for private `fwios` tables and no warning/critical exposure.

## Authority state

Supabase is authoritative for:
- Evidence / Canonical / Normalized research data
- RPV2.1 reusable-evidence/controller state
- dependency and model registry state
- blocker/model-debt state
- production valuation snapshots
- executable valuation kernels
- SaaS ADBE/CRM valuation compute
- Materials Specialty Chemicals LIN/PPG valuation compute
- IT Services ACN valuation compute
- Mining ALB valuation compute and fail-closed MP lineage
- Digital Advertising RDDT/PINS intrinsic valuation compute

Google Sheets remains a compatibility/control-room representation during migration. `Investment Portfolio Tracker - Chumponphat` remains the portfolio-state migration source until parity passes. Native market price/mispricing, Portfolio Fit, `Data_Scoring_v2`, `Opportunity_Engine_v2`, Capital Allocation/Rebalancing and final human decision logic remain downstream.

## Roadmap governance cutover

`docs/00_SYSTEM_ROADMAP.md` is the persistent project-status index required by `FWIOS-CONTRACT-0.87.2`.

For material work, AI must read the live foundation/controller plus `AGENTS.md`, `contracts/system-contract.yaml`, `VERSION` and the roadmap. Live state overrides stale documentation; material changes must be synchronized in the same workstream.

## Next milestone

**M2 Decision Intelligence is now the Main Roadmap priority.**

Financials is queued and currently technically eligible under the `DISCOVERY` controller, but is not auto-started in this workstream. M2 begins with Portfolio State migration from `Investment Portfolio Tracker - Chumponphat`, native Market Price/Mispricing, Portfolio Fit and Supabase `Data_Scoring_v2` parity. M3 Rebalancing depends on those M2 outputs.
