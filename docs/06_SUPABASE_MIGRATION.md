# Supabase Migration — Focused Wealth Investment OS

Status: **PHASE 3 VALUATION INFRASTRUCTURE PASS**  
Date: 2026-09-05  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`

## Objective

Migrate the Investment OS from a spreadsheet-centered architecture to a hybrid architecture without breaking the live Google Sheets decision workflow.

Target operating model:

- **Supabase**: canonical backend, lineage, dependencies, model registry, blocker state, valuation versions/runs, run history and automation state.
- **Google Sheets**: dashboard, control room, human review and temporary compatibility/calculation layer until compute parity passes.
- **Human execution only**: no automatic portfolio trading.

## Migration strategy

Use a strangler migration. Do not perform a big-bang cutover. A layer becomes authoritative in Supabase only after row-count, lineage, gate and regression parity pass.

## Phase 1 — Foundation PASS

Private schema: `fwios`

Core foundation tables include:

- `system_state`
- `sector_archetypes`
- `valuation_models`
- `companies`
- `sector_runs`
- `sources`
- `evidence_records`
- `company_metrics`
- `normalized_metrics`
- `research_candidates`
- `blockers`
- `sync_runs`

Foundation snapshot:

- Sector archetypes: **41**
- Configured valuation contracts: **17**
- Implemented production models: **5**
- Research candidates: **15**
- Total blocker records: **15**
- Open root blockers: **7**
- Decision Coverage: **33.3%**

Security posture:

- RLS enabled on all `fwios` tables.
- `anon` and `authenticated` have no schema/table privileges.
- `fwios` is not the public client-facing API surface.
- Existing `public.rls_auto_enable()` execution permission was revoked from PUBLIC/anon/authenticated after the Supabase security advisor flagged it.

## Phase 2 — Research data parity PASS

The three dependency-ordered research layers are fully migrated and authoritative in Supabase:

1. `Evidence_Ledger → fwios.evidence_records`
2. `Company_Metrics_v2 → fwios.company_metrics`
3. `Normalized_Metrics_v1 → fwios.normalized_metrics`

Parity result:

- Evidence rows: **181 / 181**
- Evidence Machine Status PASS: **181 / 181**
- Evidence Verification Status VERIFIED: **181 / 181**
- Canonical metric rows: **47 / 47**
- Canonical Metric Status PASS: **47 / 47**
- Normalized metric rows: **53 / 53**
- Normalization Gate PASS: **53 / 53**
- Duplicate Evidence IDs: **0**
- Canonical → Evidence orphan references: **0**
- Normalized → Evidence orphan references: **0**
- Evidence → Source orphan references: **0**

## Phase 3 — Valuation infrastructure PASS

Phase 3 moved the valuation control-plane and current production valuation snapshots into Supabase without changing economic/model logic.

New tables:

- `metric_dependencies`
- `valuation_kernel_families`
- `valuation_model_versions`
- `valuation_runs`
- `valuation_scenarios`
- `valuation_run_inputs`
- `model_regression_runs`
- `blocker_candidate_map`
- `model_debt_profiles`

New views:

- `v_model_debt_controller`
- `v_operating_controller`

Phase 3 snapshot:

- Dependency edges: **97**
- Production model versions: **5**
- Valuation runs migrated: **5**
- Scenario rows: **15**
- Model run inputs mapped: **40**
- Regression checks PASS: **5 / 5**

Reference valuation regressions:

- ISRG Bear/Base/Bull/PW = **176.72 / 257.98 / 395.05 / 271.93**
- EOG Bear/Base/Bull/PW = **43.55440384 / 170.2097883 / 294.1920388 / 169.5415048**
- BKR Bear/Base/Bull/PW = **33.89226734 / 41.38798041 / 49.21109197 / 41.46983003**
- CAVA Bear/Base/Bull/PW = **16.0499411 / 31.53068159 / 58.71340713 / 34.45617785**
- TPR Bear/Base/Bull/PW = **69.01945407 / 100.305089 / 133.9789403 / 100.9021431**

All five Supabase regression snapshots exactly match the current live `Intrinsic_Valuation_v2` reference values within the configured absolute tolerance of 0.01.

## Valuation Kernel architecture

The reusable kernel families are now represented explicitly in Supabase:

- `FCF_COMPOUNDER`
- `MIDCYCLE_CASHFLOW`
- `ASSET_NAV`
- `NORMALIZED_EARNINGS`
- `RNPV`
- `CONTRACTED_YIELD`

Existing production models are also mapped to their current implemented kernels/policies:

- `MEDTECH_INSTALLED_BASE_DCF_V1`
- `E&P_NORMALIZED_FCF_YIELD_V1`
- `OFS_MIDCYCLE_EV_EBITDA_FCF_V1`
- `RESTAURANT_UNIT_ECONOMICS_DCF_V1`
- `BRANDED_RETAIL_FCF_YIELD_V1`

The kernel architecture is ready for new overlays, but no missing model has been falsely marked implemented.

## Model Debt Controller

`v_model_debt_controller` ranks the seven current root blockers using system-development factors including current candidate quality, portfolio fit, evidence readiness, candidate breadth, cross-sector reusability, implementation readiness and complexity penalty.

Current ranking:

1. `SAAS_EV_FCF_REVERSE_DCF_V1` — **90.45** — unlocks ADBE + CRM
2. Materials Specialty Chemicals / Industrial Gases definition — **87.30** — LIN + PPG
3. IT Services / Hardware definition — **81.05** — ACN
4. Materials Mining / Commodities definition — **78.55** — ALB + MP
5. `SEMIS_MIDCYCLE_DCF_V1` — **73.80** — QCOM
6. Materials Packaging definition — **73.45** — BALL
7. `SEMICAP_MIDCYCLE_FCF_V1` — **72.00** — AMAT

These scores prioritize engineering/model-development work; they are not stock investment scores.

`v_operating_controller` currently reports:

- Evidence-ready candidates: **15**
- Valuation-ready candidates: **5**
- Decision Coverage: **33.3%**
- Operating mode: **MODEL_FACTORY_CRITICAL**
- Action: pause new sector discovery and resolve highest-value model debt first.

## Authority state after Phase 3

Supabase is authoritative for:

- Evidence records
- Canonical metrics
- Normalized metrics
- Model registry/version metadata
- Dependency graph
- Current migrated valuation snapshots and regression records
- Model debt prioritization/control state

Google Sheets remains authoritative for **valuation calculation execution** until the formulas/kernel are recomputed natively in Supabase and parity-tested. Specifically, `Intrinsic_Valuation_v2` remains the live calculation engine for now.

Google Sheets also remains authoritative for:

- `Data_Scoring_v2`
- `Opportunity_Engine_v2`
- portfolio holdings / transactions / positions
- control-room presentation

Do not retire `Intrinsic_Valuation_v2` yet.

## Fail-closed state preserved

The seven root blockers remain OPEN. No blocked candidate was promoted during Phase 3.

In particular, `SAAS_EV_FCF_REVERSE_DCF_V1` is now the highest-priority model debt, but ADBE and CRM remain blocked until their required production canonical/normalized metrics are collected, verified and then the SaaS model is implemented and regression-tested.

## Next milestone

Next development milestone:

1. Build the executable reusable `FCF_COMPOUNDER` valuation kernel in Supabase.
2. Implement `SAAS_EV_FCF_REVERSE_DCF_V1` as the first overlay.
3. Collect/fill production metric contracts for ADBE and CRM through the canonical evidence path.
4. Regression-test ADBE/CRM and prove fail-closed behavior for missing/stale inputs.
5. Once Supabase can recompute the five existing reference valuations plus SaaS correctly, move valuation calculation authority from Google Sheets to Supabase.
6. Only after valuation-compute parity passes should `Data_Scoring_v2` / `Opportunity_Engine_v2` migration begin.

Communication Services remains queued, but the current operating controller is `MODEL_FACTORY_CRITICAL`, so model factory work takes precedence while Decision Coverage remains below 35%.
