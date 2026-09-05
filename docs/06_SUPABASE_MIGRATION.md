# Supabase Migration — Focused Wealth Investment OS

Status: **PHASE 1 FOUNDATION IN PROGRESS**  
Date: 2026-09-05  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`

## Objective

Migrate the Investment OS from a spreadsheet-centered architecture to a hybrid architecture without breaking the live Google Sheets decision workflow.

Target operating model:

- **Supabase**: canonical backend, lineage, dependencies, model registry, blocker state, run history and automation state.
- **Google Sheets**: dashboard, control room, human review and temporary compatibility layer.
- **Human execution only**: no automatic portfolio trading.

## Migration strategy

Use a strangler migration. Do not perform a big-bang cutover.

Google Sheets remains the upstream production source until a layer has passed parity checks in Supabase. A migrated layer becomes authoritative only after row-count, state, lineage and regression parity are verified.

## Phase 1 foundation created

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

Security posture:

- RLS enabled on all `fwios` tables.
- `anon` and `authenticated` have no schema/table privileges.
- `fwios` is not the public client-facing API surface.
- Existing `public.rls_auto_enable()` execution permission was revoked from PUBLIC/anon/authenticated after the Supabase security advisor flagged it.

## Phase 1 migrated state

Parity snapshot after initial seed:

- Sector archetypes: **41**
- Configured valuation contracts: **17**
- Implemented production models: **5**
- Research candidates: **15**
- Total blocker records: **15**
- Open root blockers: **7**
- Evidence-ready candidates: **15**
- Valuation-ready candidates: **5**
- Decision Coverage: **33.3%**

Open model/definition debt remains the same seven live blockers from Google Sheets:

- Materials Mining / Commodities definition
- Materials Packaging definition
- Materials Specialty Chemicals / Industrial Gases definition
- Information Technology IT Services / Hardware definition
- `SAAS_EV_FCF_REVERSE_DCF_V1`
- `SEMIS_MIDCYCLE_DCF_V1`
- `SEMICAP_MIDCYCLE_FCF_V1`

## Authority state

Supabase is **not yet the sole system of record**.

Current authority:

- Google Sheets remains authoritative for live historical evidence, canonical metrics, normalized metrics, intrinsic valuation formulas and opportunity formulas.
- Supabase currently owns the new database foundation and a verified parity snapshot for model registry, candidates, blocker state and system state.

Do not remove or rewrite the live Google Sheets formulas during Phase 1.

## Deferred migration layers

The following are intentionally deferred until ETL parity is verified:

1. Full `Evidence_Ledger` history → `fwios.evidence_records`
2. Full `Company_Metrics_v2` → `fwios.company_metrics`
3. Full `Normalized_Metrics_v1` → `fwios.normalized_metrics`
4. Intrinsic valuation run/version history
5. Sector run history
6. Portfolio accounts / transactions / positions
7. Incremental earnings refresh dependencies

## Cutover rule

For each data layer:

1. Copy from the live Sheet without changing the Sheet.
2. Verify row counts and primary keys.
3. Verify lineage and fail-closed statuses.
4. Compare reference regressions: ISRG, EOG, BKR, CAVA and TPR where applicable.
5. Mark the Supabase layer authoritative only after parity passes.
6. Then convert the corresponding Google Sheet tab into a presentation/control view or retire it.

## Next migration milestone

Phase 2 should migrate the three core research-data layers in dependency order:

`Evidence_Ledger → Company_Metrics_v2 → Normalized_Metrics_v1`

Only after those three layers pass parity should new Model Debt Controller / Valuation Kernel work be implemented primarily on Supabase.

Communication Services remains READY in the sector queue, but system-development work may temporarily take precedence while database parity is being established.
