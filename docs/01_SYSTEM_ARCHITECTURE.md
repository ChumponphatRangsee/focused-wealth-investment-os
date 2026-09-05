# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.3**  
Foundation compatibility: **0.87**  
Architecture state: **CONSOLIDATION V1 LIVE**

## Authority model

The Investment OS now uses a three-authority model:

- **Supabase = System of Record / State**
- **GitHub = System of Logic / Contracts / Tests / Migrations**
- **Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export**

AI may research, interpret, explain and orchestrate within policy, but accounting, scoring math, gates and portfolio mutation must remain deterministic/system-controlled.

## Layered architecture

```text
Experience / Human Approval
          ↑
Decision & Capital Allocation
          ↑
Intelligence
          ↑
Domain State
          ↑
Knowledge / Evidence
          ↑
Orchestration / Events
```

### 1. Orchestration / Events

Owns run/controller state, blockers, dependency ordering and future event/delta refresh.

Current foundations include research-stage/run state, operating/model-debt controllers, blocker queue and `fwios.system_events`.

`system_events` is foundation only in v1; no automatic event trigger is enabled.

### 2. Knowledge / Evidence

Logical flow:

`Source → Evidence → Canonical Facts → Normalized Metrics`

Rules:

- research provenance is mandatory;
- facts cannot contain valuation forecasts;
- derived facts need deterministic methods and input lineage;
- normalization may standardize definitions/units or perform evidenced economic normalization but never overwrite reported evidence.

### 3. Domain State

Owns current portfolio/company/market state.

Portfolio accounting comes from the reconciled private Supabase ledger. Portfolio transactions, positions, cost basis, allocation and exposure are deterministic state, not AI memory.

Market state includes quote provenance, session date, freshness and conflict gates.

### 4. Intelligence

Owns valuation, mispricing, Portfolio Fit, core scoring, Revision and Chase logic.

Existing specialized policy tables remain live backing implementations. Architecture Consolidation v1 adds generic governance:

- `fwios.policy_registry`
- `fwios.policy_versions`

A numeric scoring policy may become production-authoritative only when its version is ACTIVE and deterministic.

Current policy state:

| Policy | State |
|---|---|
| Data Scoring 30/30/25/15 | ACTIVE |
| Mispricing | ACTIVE |
| Portfolio Fit | ACTIVE |
| Revision Score | DRAFT — raw→score map undefined |
| Chase Risk | DRAFT — raw→score map undefined |
| Rebalance | DRAFT |

### 5. Decision & Capital Allocation

`fwios.decision_snapshots` is the reproducibility boundary between candidate intelligence and portfolio allocation.

A decision snapshot references the exact portfolio batch, price snapshot, valuation run, mispricing snapshot, Portfolio Fit snapshot, Revision snapshot, Chase snapshot, core score snapshot and policy versions.

Initial Decision Snapshots exist for PINS and RDDT. Both preserve current fail-closed Promotion state.

M3 is deliberately separated into:

```text
Decision Snapshot
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

Foundation tables:

- `fwios.capital_allocation_runs`
- `fwios.capital_allocation_actions`
- `fwios.capital_allocation_metrics`

Allowed scenario modes:

- NO_SELL
- SOFT_REBALANCE
- ACTIVE_REBALANCE

No scenario may mutate the live portfolio and no output may auto-trade.

### 6. Experience / Human Approval

Google Sheets remains the current human-readable control/view layer while deeper production state moves to Supabase.

Long-term user-facing Sheet target is a smaller set of views such as Dashboard, Portfolio, Candidates, Research, System Status and Audit/Export. Deep evidence, policy, scoring and run state should not remain duplicated writable Sheet data after cutover.

## Production decision flow

```text
Sector Criteria / Discovery
        ↓
Source Registry / Evidence
        ↓
Canonical Facts
        ↓
Normalized Metrics
        ↓
Intrinsic Valuation
        ↓
Market Price → Mispricing
        ↓
Portfolio State → Portfolio Fit
        ↓
30/30/25/15 Core Score
        ↓
Revision + Chase hard gates
        ↓
Decision Snapshot
        ↓
Opportunity / Allocation / Scenario
        ↓
Human Approval
```

## Current live M2 state

- Portfolio State migration: PASS — 29/29 transactions and 16/16 positions reconciled.
- Native Market Price / Mispricing: PASS infrastructure.
- Portfolio Fit: PASS.
- Native 30/30/25/15 core scoring: LIVE.
- Revision comparable consensus evidence: present for PINS/RDDT.
- Revision scoring policy: DRAFT / BLOCKED until raw→score rubric is versioned.
- Chase scoring policy: DRAFT / BLOCKED until raw→score rubric and component data are complete.
- Promotion Gate: fail-closed.

## Security

The `fwios` schema remains private. New consolidation tables have RLS enabled and `anon` / `authenticated` privileges revoked. Service-role/internal execution remains the intended model.

## Architectural invariants

1. Web research cannot jump directly to final valuation or allocation.
2. Facts and model assumptions remain separate.
3. Portfolio accounting uses reconciled ledger state only.
4. Policy versions are explicit and immutable enough to reproduce decisions.
5. Draft/undefined raw→score policies cannot pass production gates.
6. Decision Snapshots bridge intelligence into allocation.
7. Scenario simulations do not mutate live holdings.
8. Human execution only.
9. New system gaps enter a persistent blocker/policy queue rather than undocumented exceptions.
10. Future M4 automation should prefer event/delta refresh over unnecessary full-stack reruns.

See `docs/02_ARCHITECTURE_CONSOLIDATION_V1.md` for the implementation record.
