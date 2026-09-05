# Supabase Migration — Focused Wealth Investment OS

Status: **M2 DECISION INTELLIGENCE PASS / M3 READY**  
Date: **2026-09-05**  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`  
Execution contract: `FWIOS-CONTRACT-0.87.4`

## Authority
- Supabase = System of Record / State
- GitHub = System of Logic / Contracts / Tests / Migrations
- Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export

## Completed authority layers

### Research / Evidence — PASS
Supabase owns source/evidence/canonical/normalized state plus RPV2.1 cache/controller behavior. Current snapshot: 18 evidence-ready, 13 valuation-ready, 72.2% decision coverage, DISCOVERY controller, six open model-debt roots.

### Valuation — PASS for implemented routes
Production valuation kernels/routes remain versioned and regression-tested. Digital Advertising RDDT/PINS valuations are live under `DIGITAL_ADS_FCF_REVERSE_DCF_V1`.

### Portfolio State — PASS
Migration source: `Investment Portfolio Tracker - Chumponphat`.
- 29/29 transactions reconciled.
- 16/16 positions reconciled.
- Supabase owns portfolio state used by Portfolio Fit/downstream decision logic.
- Legacy Sheet remains retained for reconciliation/audit/export until M3 traceability passes.

### Market Price / Mispricing — PASS
Native quote/snapshot/mispricing state is live with provenance, session/freshness and fail-closed gates.

### Portfolio Fit — PASS
Uses reconciled portfolio weights/exposures.

### Core Scoring — PASS
Native 30/30/25/15 scoring is live.

## M2 Promotion-Gate Hardening — PASS

New governance/lineage objects:
- `candidate_revision_component_inputs`
- `candidate_chase_component_inputs`
- `decision_policy_regression_runs`

Active deterministic policies:
- `POL-REVISION-SCORE-V1`
- `POL-CHASE-SCORE-V1`

Executable immutable/invoker functions:
- `score_revision_delta_v1`
- `calculate_revision_score_v1`
- `revision_gate_v1`
- `score_chase_excess_v1`
- `score_price_vs_fv_risk_v1`
- `calculate_chase_risk_v1`
- `chase_gate_v1`

Regression status: **16/16 PASS**, including mapping boundaries, missing-data fail-closed tests and PINS/RDDT production parity.

Production snapshots:

| Candidate | Revision | Chase | Mispricing | Promotion / State |
|---|---:|---:|---|---|
| PINS | 60.5531 PASS | 0.0000 PASS | PASS | PASS — READY - HUMAN REVIEW |
| RDDT | 71.4010 PASS | 12.2748 PASS | FAIL insufficient mispricing | GOOD COMPANY - WAIT FOR VALUE |

V2 reproducible decisions:
- `DEC-PINS-M2-20260905-V2`
- `DEC-RDDT-M2-20260905-V2`

RDDT confirms policy separation: positive Revision/Chase cannot bypass the separate Mispricing hard gate.

## Architecture Consolidation v1
Policy registry/version governance and Decision Snapshots are live. Active policy families now include Data Scoring, Mispricing, Portfolio Fit, Revision Score and Chase Score. `REBALANCE` remains DRAFT.

## M3 scenario foundation
Tables already exist:
- `capital_allocation_runs`
- `capital_allocation_actions`
- `capital_allocation_metrics`

Modes: `NO_SELL`, `SOFT_REBALANCE`, `ACTIVE_REBALANCE`.

No allocation run was created during M2 hardening and scenario tables do not mutate live portfolio state.

## M4 event foundation
`system_events` exists but no production trigger/autonomous workflow is enabled.

## Security
`fwios` remains private. New M2 component/regression tables have RLS enabled and `anon`/`authenticated` access revoked. New scoring functions are immutable, not `SECURITY DEFINER`, and have `search_path` explicitly pinned to `pg_catalog, fwios`. Security Advisor after hardening reports no WARN/ERROR findings from the M2 changes; only expected private-schema `RLS Enabled No Policy` INFO notices remain.

## Sheet role
Do not delete/restructure deep tabs until M3 traceability/cutover passes. Google Sheets is a view/compatibility/audit layer; authoritative scoring policy/state resides in Supabase and GitHub.

## Next milestone
**M3 Opportunity & Capital Allocation is READY.**

Next sequence:
1. Define deterministic Opportunity Ranking contract using production Decision Snapshots.
2. Build new-cash deployment first.
3. Build scenario simulation without portfolio mutation.
4. Add trim/add logic only after traceability and scenario regressions pass.
5. Activate Rebalance policy only after M3 regressions pass.

Financials remains queued and sector automation remains manually paused while M3 is the Main Roadmap priority.
