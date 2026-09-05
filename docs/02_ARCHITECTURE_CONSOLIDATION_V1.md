# Architecture Consolidation v1

Status: **IMPLEMENTED FOUNDATION / M2 PROMOTION HARDENING STILL OPEN**  
Date: **2026-09-05**  
Foundation compatibility: **0.87**  
Execution mode: **HUMAN EXECUTION ONLY**

## Objective

Consolidate the Investment OS into a durable three-authority model without rewriting working M1/M2 logic:

- **Supabase = System of Record / State**
- **GitHub = System of Logic / Contracts / Tests / Migrations**
- **Google Sheets = System of View / Compatibility / Audit / Export**
- **ChatGPT / AI = Research, interpretation, explanation and controlled orchestration; not accounting or trade execution**

This consolidation is additive. Existing M1/M2 tables remain live. No portfolio transaction or holding is changed by this work.

## Target layered architecture

```text
Experience / Human Approval
          ↑
Decision & Capital Allocation
          ↑
Intelligence (Valuation / Scoring / Fit / Revision / Chase)
          ↑
Domain State (Portfolio / Company / Market)
          ↑
Knowledge (Sources / Evidence / Canonical / Normalized)
          ↑
Orchestration (Runs / Controllers / Blockers / Events)
```

## Architectural invariants

1. A web fact cannot jump directly to a decision or valuation output.
2. Facts, normalization and model assumptions remain separate.
3. Portfolio accounting is deterministic and comes from the reconciled Supabase ledger.
4. Scoring and gate policies must be explicitly versioned before they can become production-authoritative.
5. Missing raw-to-score mappings remain fail-closed; AI must not invent component scores.
6. A candidate decision must be reproducible from immutable input snapshot identifiers.
7. Capital-allocation scenarios simulate changes; they never mutate the live portfolio.
8. Human approval/execution remains mandatory.
9. Google Sheets may display/compatibly mirror state but may not silently become a second source of truth after cutover.
10. New automation should become event/delta driven where possible rather than rerunning the entire research stack.

## New Supabase foundation

### Policy Registry

Tables:

- `fwios.policy_registry`
- `fwios.policy_versions`

Purpose: separate a policy family from a particular version and record whether its scoring behavior is deterministic and production-ready.

Seeded policy families:

- `DATA_SCORING` — ACTIVE
- `MISPRICING` — ACTIVE
- `PORTFOLIO_FIT` — ACTIVE
- `REVISION_SCORE` — DRAFT
- `CHASE_SCORE` — DRAFT
- `REBALANCE` — DRAFT

The Revision and Chase versions intentionally store `raw_to_score_map = UNDEFINED` until a deterministic rubric is designed and regression-tested.

### Decision Snapshot

Table: `fwios.decision_snapshots`

One row represents one reproducible candidate decision context and references:

- portfolio batch
- market-price snapshot
- valuation run
- mispricing snapshot
- Portfolio Fit snapshot
- Revision snapshot
- Chase snapshot
- core scoring snapshot
- policy versions

Initial bridge snapshots were created for PINS and RDDT. Both remain fail-closed on Promotion because Revision/Chase scoring policies are still drafts.

### Capital Allocation Scenario Foundation

Tables:

- `fwios.capital_allocation_runs`
- `fwios.capital_allocation_actions`
- `fwios.capital_allocation_metrics`

Supported run modes are deliberately constrained to:

- `NO_SELL`
- `SOFT_REBALANCE`
- `ACTIVE_REBALANCE`

These tables are foundation only. No allocation run was created in Architecture Consolidation v1.

### Event Foundation

Table: `fwios.system_events`

Purpose: future M4 delta/event orchestration for events such as price changes, earnings releases, consensus changes, portfolio changes, thesis changes and valuation changes.

No triggers or automatic workflows are enabled in v1.

## Existing layers retained

Architecture Consolidation v1 does not replace the working M1/M2 domain tables. Existing specialized policy tables remain authoritative backing tables until individual policies cut over through tested versions.

Examples:

- `data_scoring_policies`
- `mispricing_policies`
- `portfolio_fit_policies`
- `candidate_revision_snapshots`
- `candidate_chase_snapshots`
- `candidate_decision_scores`
- `portfolio_import_batches`
- `market_price_snapshots`
- `valuation_mispricing_snapshots`

The generic registry sits above these layers and provides version/governance metadata rather than duplicating production math.

## M3 design boundary

M3 must be split into distinct responsibilities:

```text
Decision Snapshots
      ↓
Opportunity Ranking
      ↓
Capital Allocation
      ↓
Portfolio Scenario Simulation
      ↓
Rebalancing Recommendation
      ↓
Human Approval
```

A standalone high stock score must never imply an automatic portfolio action.

Each simulated action must be traceable to a decision snapshot and a reconciled portfolio batch. Expected-return, concentration, crypto, theme and downside changes should be stored as scenario metrics before human review.

## Google Sheets end-state

Do not delete tabs as part of this consolidation. After M3 traceability passes, reduce the user-facing workbook toward a view-oriented surface such as:

- Dashboard
- Portfolio
- Candidates
- Research
- System Status
- Audit / Export

Deep evidence, policy, run-history and internal scoring state should progressively remain in Supabase rather than being maintained as duplicated writable Sheet state.

## Security

All new tables remain inside private schema `fwios`, have RLS enabled, and `anon` / `authenticated` privileges revoked. Security Advisor returned only the existing expected `RLS Enabled No Policy` INFO notices under the private service-role architecture; no new warning/critical issue was introduced.

## Next action

Architecture consolidation does **not** skip the remaining M2 Promotion hardening dependency.

Next:

1. Define/version `REVISION_SCORE_V1` raw evidence → component scoring rubric.
2. Define/version `CHASE_SCORE_V1` raw data → risk scoring rubric.
3. Regression-test fail-closed boundaries.
4. Rebuild PINS/RDDT Decision Snapshots from production policy versions.
5. Only then begin live M3 Opportunity / Capital Allocation implementation.
