# Supabase Migration — Focused Wealth Investment OS

Status: **PHASE 2 RESEARCH DATA PARITY PASS**  
Date: 2026-09-05  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`

## Objective

Migrate the Investment OS from a spreadsheet-centered architecture to a hybrid architecture without breaking the live Google Sheets decision workflow.

Target operating model:

- **Supabase**: canonical backend, lineage, dependencies, model registry, blocker state, run history and automation state.
- **Google Sheets**: dashboard, control room, human review and compatibility/presentation layer.
- **Human execution only**: no automatic portfolio trading.

## Migration strategy

Use a strangler migration. Do not perform a big-bang cutover. A layer becomes authoritative in Supabase only after row-count, lineage, gate and regression parity pass.

## Phase 1 — Foundation PASS

Private schema: `fwios`

Core tables:

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

Views:

- `v_decision_coverage`
- `v_open_model_debt`

Foundation snapshot:

- Sector archetypes: **41**
- Configured valuation contracts: **17**
- Implemented production models: **5**
- Research candidates: **15**
- Total blocker records: **15**
- Open root blockers: **7**
- Evidence-ready candidates: **15**
- Valuation-ready candidates: **5**
- Decision Coverage: **33.3%**

Security posture:

- RLS enabled on all `fwios` tables.
- `anon` and `authenticated` have no schema/table privileges.
- `fwios` is not the public client-facing API surface.
- Existing `public.rls_auto_enable()` execution permission was revoked from PUBLIC/anon/authenticated after the Supabase security advisor flagged it.

## Phase 2 — Research data parity PASS

The three dependency-ordered research layers are now fully migrated:

`Evidence_Ledger → fwios.evidence_records`

`Company_Metrics_v2 → fwios.company_metrics`

`Normalized_Metrics_v1 → fwios.normalized_metrics`

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

Reference ticker parity:

- ISRG canonical: **10**; normalized: **11**
- EOG canonical: **8**; normalized: **11**
- BKR canonical: **6**; normalized: **5**
- CAVA canonical: **16**; normalized: **19**
- TPR canonical: **7**; normalized: **7**

Key regression anchors preserved:

- ISRG normalized net cash = **8.6255 USD B**
- EOG normalized FCF Bear/Base/Bull = **2.0561 / 6.696 / 10.0303 USD B**
- BKR normalized EBITDA Bear/Base/Bull = **5.9783 / 6.1408 / 6.3033 USD B**
- BKR pro-forma net debt proxy = **14.182425 USD B**
- CAVA normalized pre-growth FCF = **0.137998 USD B**
- CAVA normalized pre-growth FCF margin = **0.100440416**
- TPR normalized FCF LTM = **1.86 USD B**

Seven `#ERROR!` values found in the source Evidence_Ledger `Direction` metadata for Materials were preserved exactly during migration. They do not affect canonical value, verification status or production metric gates and must not be silently rewritten as part of migration.

## Authority state after Phase 2

Supabase is now authoritative for these research-data layers:

1. `fwios.evidence_records`
2. `fwios.company_metrics`
3. `fwios.normalized_metrics`

Google Sheets remains the active dashboard/control and compatibility representation of those layers until downstream cutover is complete.

Google Sheets remains authoritative for the still-unmigrated downstream execution layers:

- `Intrinsic_Valuation_v2`
- `Data_Scoring_v2`
- `Opportunity_Engine_v2`
- sector run/control presentation
- portfolio holdings / transactions / positions

Do not delete the three Google Sheet research tabs yet. Keep them as parity/reference views until read/write synchronization direction is explicitly implemented and tested.

## Open model debt unchanged

The seven live blockers remain:

- Materials Mining / Commodities definition
- Materials Packaging definition
- Materials Specialty Chemicals / Industrial Gases definition
- Information Technology IT Services / Hardware definition
- `SAAS_EV_FCF_REVERSE_DCF_V1`
- `SEMIS_MIDCYCLE_DCF_V1`
- `SEMICAP_MIDCYCLE_FCF_V1`

No blocked candidate was promoted during migration.

## Next milestone

Phase 3 should move the decision-computation layer toward Supabase in this order:

1. Create explicit metric/dependency graph records.
2. Create valuation model/version/run tables and migrate current `Intrinsic_Valuation_v2` regression state.
3. Implement Model Debt Controller on the database foundation.
4. Build the reusable Valuation Kernel / archetype overlay architecture.
5. Implement the first high-ROI missing route: SaaS (`SAAS_EV_FCF_REVERSE_DCF_V1`).
6. Only after valuation parity passes, migrate Opportunity Engine state and Best Use of Next Capital logic.

Communication Services remains READY in the sector queue. System-development work may temporarily take precedence while valuation/model infrastructure is being upgraded.
