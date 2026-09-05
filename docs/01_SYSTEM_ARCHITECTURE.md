# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.4**  
Foundation compatibility: **0.87**  
Architecture state: **CONSOLIDATION V1 LIVE / M2 PROMOTION HARDENED**

## Authority model
- **Supabase = System of Record / State**
- **GitHub = System of Logic / Contracts / Tests / Migrations**
- **Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export**

AI may research, interpret, explain and orchestrate within policy. Accounting, scoring math, hard gates and portfolio mutation remain deterministic/system-controlled.

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

### Orchestration / Events
Owns run/controller state, blockers, dependencies and future event/delta refresh. `fwios.system_events` remains foundation-only; no production event trigger is enabled.

### Knowledge / Evidence
`Source → Evidence → Canonical Facts → Normalized Metrics`

Research provenance is mandatory; facts cannot contain valuation forecasts; derived facts require methods/input lineage; normalization cannot overwrite reported evidence.

### Domain State
Owns reconciled portfolio/company/market state. Portfolio accounting comes from private Supabase ledger state. Market state carries quote provenance, session/freshness and conflict gates.

### Intelligence
Owns valuation, mispricing, Portfolio Fit, core scoring, Revision and Chase.

Generic policy governance:
- `fwios.policy_registry`
- `fwios.policy_versions`
- `fwios.decision_policy_regression_runs`

Current policy state:

| Policy | State |
|---|---|
| Data Scoring 30/30/25/15 | ACTIVE |
| Mispricing | ACTIVE |
| Portfolio Fit | ACTIVE |
| Revision Score v1 | **ACTIVE / deterministic** |
| Chase Risk v1 | **ACTIVE / deterministic** |
| Rebalance | DRAFT |

Revision/Chase raw-input lineage is stored in:
- `fwios.candidate_revision_component_inputs`
- `fwios.candidate_chase_component_inputs`

Their component maps are defined in GitHub policy documents and executable SQL functions. Missing critical components remain fail-closed.

### Decision & Capital Allocation
`fwios.decision_snapshots` is the reproducibility boundary between candidate intelligence and portfolio allocation. A decision snapshot references exact portfolio, price, valuation, mispricing, Portfolio Fit, Revision, Chase, core score and policy versions.

Current V2 snapshots:
- PINS: `READY - HUMAN REVIEW`, Promotion PASS.
- RDDT: `GOOD COMPANY - WAIT FOR VALUE`, Promotion fails only because Mispricing remains insufficient.

M3 remains separated into:
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

Scenario modes: `NO_SELL`, `SOFT_REBALANCE`, `ACTIVE_REBALANCE`. Scenario runs cannot mutate live portfolio state and cannot auto-trade.

### Experience / Human Approval
Google Sheets remains the human-readable view/control compatibility layer. Long-term target is a smaller set of views such as Dashboard, Portfolio, Candidates, Research, System Status and Audit/Export after M3 traceability/cutover passes.

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
Revision Score v1 + Chase Risk v1
        ↓
Decision Snapshot
        ↓
Opportunity / Allocation / Scenario
        ↓
Human Approval
```

## Revision Score v1
Weights: Guidance 30%, Consensus 25%, KPI Acceleration 25%, Margin/FCF 20%.

Common component map: `clamp(50 + 5 × delta, 0, 100)`. Full coverage required; total score >=50 passes. Guidance uses forward guide-vs-consensus surprise; consensus uses comparable estimate revision; KPI uses QoQ acceleration of comparable YoY growth rates; Margin/FCF uses same-quarter YoY margin changes.

## Chase Risk v1
Weights: Price Extension 25%, Price vs Revision 30%, Multiple Expansion 25%, Price vs FV 20%. Full coverage required; total risk <=60 passes.

Anchor = last regular-session close before earnings. Price-vs-FV uses `min(Base FV, PW FV)` as conservative reference. Extension/revision/multiple components only penalize positive excess; price-vs-FV uses explicit piecewise breakpoints.

## M2 exit state
- 16/16 decision-policy regressions PASS.
- PINS: Core 87.60, Revision 60.5531 PASS, Chase 0.0000 PASS, Mispricing PASS, Promotion PASS.
- RDDT: Core 72.15, Revision 71.4010 PASS, Chase 12.2748 PASS, Mispricing FAIL, WAIT FOR VALUE.
- M2 Decision Intelligence: **PASS**.
- M3 Opportunity & Capital Allocation: **READY / NEXT**.

## Security
`fwios` remains private. New component/regression tables have RLS enabled and `anon`/`authenticated` privileges revoked. Scoring functions are immutable/invoker functions and are not `SECURITY DEFINER`.

## Architectural invariants
1. Web research cannot jump directly to final valuation/allocation.
2. Facts and assumptions remain separate.
3. Portfolio accounting uses reconciled ledger state only.
4. Policy versions and raw component lineage must reproduce decisions.
5. Missing/stale/unverified promotion inputs fail closed.
6. Revision/Chase cannot override valuation, Mispricing, Portfolio Fit or core gates.
7. Decision Snapshots bridge intelligence into allocation.
8. Scenario simulations do not mutate live holdings.
9. Human execution only.
10. M4 automation should prefer event/delta refresh over unnecessary full-stack reruns.

See `policies/revision/REVISION_SCORE_V1.md` and `policies/chase/CHASE_RISK_V1.md` for policy calibration.
