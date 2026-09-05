# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.5**  
Foundation compatibility: **0.87**  
Architecture state: **CONSOLIDATION V1 LIVE / M2 PASS / M3.1 LIVE**

## Authority model
- **Supabase = System of Record / State**
- **GitHub = System of Logic / Contracts / Tests / Migrations**
- **Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export**

AI may research, interpret, explain and orchestrate within policy. Accounting, scoring math, ranking gates, allocation math and portfolio mutation remain deterministic/system-controlled.

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
| Revision Score v1 | ACTIVE / deterministic |
| Chase Risk v1 | ACTIVE / deterministic |
| Opportunity Ranking v1 | **ACTIVE / deterministic** |
| Rebalance | DRAFT |

### Decision Snapshot boundary
`fwios.decision_snapshots` remains the reproducibility boundary between candidate intelligence and downstream portfolio decisions. Each snapshot references exact portfolio, price, valuation, mispricing, Portfolio Fit, Revision, Chase, core score and active policy versions.

Current V2 snapshots:
- PINS: Promotion PASS / READY - HUMAN REVIEW.
- RDDT: WAIT FOR VALUE because Mispricing is insufficient.

### M3.1 Opportunity Ranking
Opportunity Ranking is now a separate deterministic layer after Decision Snapshot:

```text
Decision Snapshot
      ↓
Opportunity Ranking v1
      ↓
Capital Allocation
      ↓
Portfolio Scenario Simulation
      ↓
Rebalancing Recommendation
      ↓
Human Approval
```

Production objects:
- `fwios.opportunity_ranking_runs`
- `fwios.opportunity_ranked_candidates`
- `fwios.v_latest_decision_snapshots`
- `fwios.v_opportunity_ranking_current`
- `fwios.opportunity_bucket_v1(...)`
- `fwios.opportunity_priority_score_v1(...)`

Policy: `POL-OPPORTUNITY-RANKING-V1`.

#### Ranking design
`priority_score = core_score`.

No second weighted investment score is allowed because Core already includes Business / Thesis 30%, Expected Return / Valuation 30%, Portfolio Fit 25%, and Downside / Thesis Risk 15%.

Tie-break order:
1. Expected Return score DESC
2. Portfolio Fit score DESC
3. Downside Risk score DESC
4. Business / Thesis score DESC
5. ticker ASC

Buckets:
- `IMMEDIATE_BUY_CANDIDATE`: input integrity PASS + Promotion PASS.
- `WATCHLIST_VALUE_WAIT`: only Mispricing is `FAIL - INSUFFICIENT MISPRICING`, every other M2 hard gate PASS.
- `EXCLUDED`: all other states or candidates above bucket caps.

Caps: max 3 Immediate, max 5 Watchlist; never force-fill.

First production run `OPPRANK-M3-20260905-01` on `PORTFOLIO-M2-20260905-01` is PASS:
- PINS → Immediate rank 1 / priority 87.6000.
- RDDT → Value-Wait rank 1 / priority 72.1500.

M3.1 regression suite: **8/8 PASS**, including production V2 parity.

The ranking layer does not mutate M2 scores/gates, does not allocate capital, and is not a trade instruction.

### M3.2+ Capital Allocation boundary
Existing scenario foundation tables:
- `fwios.capital_allocation_runs`
- `fwios.capital_allocation_actions`
- `fwios.capital_allocation_metrics`

M3.2 must consume active Opportunity Ranking output and the latest reconciled portfolio batch. New-cash allocation is implemented before any trim logic.

Scenario modes remain:
- `NO_SELL`
- `SOFT_REBALANCE`
- `ACTIVE_REBALANCE`

No scenario may mutate live holdings and no output may auto-trade. `REBALANCE` remains DRAFT until scenario math and traceability regressions pass.

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
Opportunity Ranking v1
        ↓
Capital Allocation / Scenario
        ↓
Human Approval
```

## Security
`fwios` remains private. Opportunity Ranking tables have RLS enabled and `anon`/`authenticated` schema access remains revoked. Ranking views use `security_invoker=true`. Ranking functions are immutable/invoker and not `SECURITY DEFINER`.

Security Advisor after activation reports no WARN/ERROR findings attributable to M3.1; expected `RLS Enabled No Policy` INFO notices remain consistent with private service-role/internal execution.

## Architectural invariants
1. Web research cannot jump directly to final valuation/allocation.
2. Facts and assumptions remain separate.
3. Portfolio accounting uses reconciled ledger state only.
4. Policy versions and raw component lineage must reproduce decisions.
5. Missing/stale/unverified promotion inputs fail closed.
6. Revision/Chase cannot override valuation, Mispricing, Portfolio Fit or core gates.
7. Opportunity Ranking cannot change M2 scores or create a second weighted score.
8. Non-mispricing hard-gate failures cannot enter the value watchlist.
9. Decision Snapshots bridge intelligence into Opportunity Ranking.
10. Allocation/scenario runs do not mutate live holdings.
11. Human execution only.
12. M4 automation should prefer event/delta refresh over unnecessary full-stack reruns.

See `policies/opportunity/OPPORTUNITY_RANKING_V1.md` for M3.1 calibration and production behavior.
