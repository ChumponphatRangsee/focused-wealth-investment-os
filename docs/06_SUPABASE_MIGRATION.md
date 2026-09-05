# Supabase Migration — Focused Wealth Investment OS

Status: **M2 CORE LIVE / ARCHITECTURE CONSOLIDATION V1 FOUNDATION LIVE**  
Date: **2026-09-05**  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`  
Execution contract: `FWIOS-CONTRACT-0.87.3`

## Objective

Move the Investment OS from spreadsheet-centered operation to a durable hybrid architecture without breaking evidence lineage, fail-closed gates or human-only execution.

Authority after Architecture Consolidation v1:

- Supabase = System of Record / State
- GitHub = System of Logic / Contracts / Tests / Migrations
- Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export

## Completed migration layers

### Research / Evidence — PASS

Supabase is authoritative for source/evidence/canonical/normalized research state and RPV2.1 controller/cache behavior.

Current research snapshot:

- Evidence-ready candidates: 18
- Valuation-ready candidates: 13
- Decision Coverage: 72.2%
- Operating Controller: DISCOVERY
- Open root model debt: 6

### Valuation — PASS for implemented routes

Reusable private kernels remain:

- FCF_COMPOUNDER
- MIDCYCLE_CASHFLOW
- ASSET_NAV

Implemented production routes include MEDTECH, E&P, Restaurant, Branded Retail, OFS, SaaS, Materials Specialty Chemicals/Industrial Gases, IT Services, Mining NAV partial route and Digital Advertising.

RDDT/PINS Digital Advertising intrinsic values remain validated under `DIGITAL_ADS_FCF_REVERSE_DCF_V1`.

### M2 Portfolio State — PASS

Source: `Investment Portfolio Tracker - Chumponphat`.

Reconciliation:

- 29/29 transactions PASS
- 16/16 positions PASS
- latest recorded snapshot ≈ THB 340,906.10

Supabase now owns the reconciled portfolio ledger/state used by Portfolio Fit and downstream decision logic. The original Sheet remains retained for reconciliation/audit/export until M3 traceability tests pass.

### M2 Market Price / Mispricing — PASS infrastructure

Native quote/snapshot and mispricing structures are live with provenance, session/freshness and fail-closed gates.

### M2 Portfolio Fit — PASS

Portfolio Fit uses reconciled portfolio weights/exposures rather than generic diversification bonuses.

### M2 Core Scoring — LIVE

Production core is 30/30/25/15:

- Business/Thesis 30%
- Expected Return/Valuation 30%
- Portfolio Fit 25%
- Downside Risk 15%

PINS core 87.60 with Mispricing PASS. RDDT core 72.15 with insufficient Mispricing / WAIT FOR VALUE.

## Architecture Consolidation v1

Applied additively to private schema `fwios`.

### Policy governance

New tables:

- `policy_registry`
- `policy_versions`

Seeded families:

- DATA_SCORING — ACTIVE
- MISPRICING — ACTIVE
- PORTFOLIO_FIT — ACTIVE
- REVISION_SCORE — DRAFT
- CHASE_SCORE — DRAFT
- REBALANCE — DRAFT

Draft Revision/Chase policies deliberately record `raw_to_score_map = UNDEFINED`; missing policy logic remains BLOCKED.

### Decision reproducibility

New table:

- `decision_snapshots`

Initial snapshots:

- `DEC-PINS-M2-20260905-V1`
- `DEC-RDDT-M2-20260905-V1`

Both preserve existing fail-closed Promotion state. No gate was relaxed.

### M3 scenario foundation

New tables:

- `capital_allocation_runs`
- `capital_allocation_actions`
- `capital_allocation_metrics`

Allowed modes:

- NO_SELL
- SOFT_REBALANCE
- ACTIVE_REBALANCE

No allocation run exists yet. These tables are foundation only.

### M4 event foundation

New table:

- `system_events`

No event trigger or autonomous workflow is enabled yet.

## Security state

`fwios` remains private. New consolidation tables have RLS enabled and `anon` / `authenticated` privileges revoked.

Security Advisor after the migration reports only expected `RLS Enabled No Policy` INFO notices consistent with the private service-role/internal architecture; no warning/critical exposure was introduced.

Supabase's 2026 platform change that new tables are not automatically exposed to Data/GraphQL APIs does not require public grants here because these tables intentionally remain private/internal.

## Sheet cutover role

Do not delete/restructure user-facing Sheet tabs during M2 Promotion hardening.

After M3 traceability passes, reduce Google Sheets toward view-oriented surfaces and avoid duplicated writable production state. Deep evidence, policies, scoring and internal run state should remain in Supabase.

## Remaining M2 blocker

Comparable PINS/RDDT consensus evidence is present, but Promotion remains blocked because Revision and Chase raw→score mappings are not yet deterministic production policy versions.

Next:

1. Define/version Revision scoring rubric.
2. Define/version Chase scoring rubric.
3. Regression-test fail-closed boundaries.
4. Activate policy versions only after tests pass.
5. Rebuild Decision Snapshots.
6. Complete M2 Promotion parity.
7. Begin M3 on the scenario foundation only after M2 exits.
