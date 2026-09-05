# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.7**  
Foundation compatibility: **0.87**  
Architecture state: **CONSOLIDATION V1 LIVE / M2 PASS / M3.1 + M3.2 + M3.3 LIVE**

## Authority model
- **Supabase = System of Record / State**
- **GitHub = System of Logic / Contracts / Tests / Migrations**
- **Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export**

AI may research, interpret, explain and orchestrate within policy. Accounting, scoring math, ranking gates, allocation math, scenario math and portfolio mutation remain deterministic/system-controlled.

## Layered architecture
```text
Experience / Human Approval
          ↑
Rebalancing Recommendation
          ↑
Scenario & Capital Allocation
          ↑
Intelligence
          ↑
Domain State
          ↑
Knowledge / Evidence
          ↑
Orchestration / Events
```

### Knowledge / Evidence
`Source → Evidence → Canonical Facts → Normalized Metrics`

Research provenance is mandatory. Facts and model assumptions remain separate.

### Domain State
Owns reconciled portfolio/company/market state. Portfolio accounting comes from private Supabase ledger state. Current portfolio is reconciled at 29/29 transactions and 16/16 positions.

### Intelligence
Owns valuation, mispricing, Portfolio Fit, Core Score, Revision and Chase.

Current policy state:
| Policy | State |
|---|---|
| Data Scoring 30/30/25/15 | ACTIVE |
| Mispricing | ACTIVE |
| Portfolio Fit | ACTIVE |
| Revision Score v1 | ACTIVE |
| Chase Risk v1 | ACTIVE |
| Opportunity Ranking v1 | ACTIVE |
| New-Cash Allocation v1 | ACTIVE |
| Portfolio Scenario v1 | **ACTIVE** |
| Rebalance | **DRAFT** |

## Decision-and-capital path
```text
Decision Snapshot
      ↓
Opportunity Ranking v1
      ↓
New-Cash Allocation v1
      ↓
Portfolio Scenario Simulation v1
      ↓
Rebalancing Recommendation (coverage-gated)
      ↓
Human Approval
```

### Decision Snapshot boundary
`fwios.decision_snapshots` remains the reproducibility boundary between candidate intelligence and downstream capital decisions. Every ADD must trace through an exact production Decision Snapshot.

### M3.1 Opportunity Ranking
Policy: `POL-OPPORTUNITY-RANKING-V1`.
- priority = existing Core Score;
- Promotion PASS → Immediate;
- Mispricing-only FAIL → Value-Wait;
- max 3 Immediate / 5 Watchlist; never force-fill;
- 8/8 regressions PASS.

First production run `OPPRANK-M3-20260905-01`:
- PINS → Immediate #1 / priority 87.6000.
- RDDT → Value-Wait #1 / priority 72.1500.

### M3.2 New-Cash Allocation
Policy: `POL-NEW-CASH-ALLOCATION-V1`.

Key production objects:
- `fwios.capital_allocation_runs`
- `fwios.capital_allocation_actions`
- `fwios.capital_allocation_metrics`
- `fwios.v_new_cash_allocation_current_context`
- `fwios.preview_new_cash_candidates_v1(...)`
- `fwios.preview_new_cash_allocation_v1(...)`
- `fwios.preview_new_cash_metrics_v1(...)`

Invariants:
1. Portfolio batch must match ranking batch.
2. Immediate candidates only.
3. Max one deployed asset per run.
4. New-position starter cap 5% post-money.
5. Existing stock >30% has zero add capacity.
6. Residual capital is held as cash.
7. No live mutation.

M3.2 regressions: 20/20 PASS.

### M3.3 Portfolio Scenario Simulation
Policy: `POL-PORTFOLIO-SCENARIO-V1`.

New private snapshot objects:
- `fwios.portfolio_scenario_runs`
- `fwios.portfolio_scenario_actions`
- `fwios.portfolio_scenario_positions`
- `fwios.portfolio_scenario_metrics`

Preview/gate functions:
- `fwios.portfolio_scenario_structural_gate_v1(...)`
- `fwios.portfolio_scenario_current_input_gate_v1(...)`
- `fwios.preview_portfolio_scenario_actions_v1(...)`
- `fwios.preview_portfolio_scenario_positions_v1(...)`
- `fwios.preview_portfolio_scenario_metrics_v1(...)`

All preview functions are `SECURITY INVOKER`, pin `search_path` to `pg_catalog, fwios`, and are not executable by `anon` or `authenticated`.

#### Mode semantics
`NO_SELL`
- requires positive new cash;
- no TRIM allowed;
- consumes the same active ranking/capacity path as M3.2.

`SOFT_REBALANCE`
- no TRIM allowed in v1;
- for a one-time new-cash event, numerical output intentionally equals NO_SELL;
- future differentiation requires real recurring DCA/redirection state; the system must not invent one.

`ACTIVE_REBALANCE`
- accepts hypothetical trim inputs for simulation;
- does not choose which asset should be trimmed;
- trim must reference a current holding, remain within current value and carry explicit economic/risk rationale;
- appreciation-only rationale is forbidden;
- proceeds can be reallocated only through active Immediate-candidate capacity.

#### Position/metric outputs
The simulator produces:
- before/delta/after THB values;
- before/after weights;
- concentration and crypto effects;
- position-count/focus effect;
- residual cash;
- exact ADD Decision Snapshot/Mispricing lineage;
- candidate downside score lineage;
- valuation coverage;
- partial covered expected-upside contribution;
- full portfolio expected upside only when coverage is complete;
- net modeled expected-value change only when every changed non-cash asset is valuation-covered.

#### Valuation coverage boundary
At M3.3 activation, current holdings expected-upside coverage is **0%**. Consequently:
- full portfolio expected upside is fail-closed;
- PINS ADD-side expected value is computable because its chain is traceable;
- trimming an uncovered holding such as NVDA blocks the net expected-value comparison;
- cost basis, historical return or narrative targets cannot fill the gap.

This prevents the simulator from appearing more precise than its evidence.

M3.3 regressions: **28/28 PASS**.

Reference synthetic NO_SELL 50k:
- PINS ADD 19,545.30; residual cash 30,454.70;
- max stock ~41.25% → ~35.98%;
- crypto ~38.09% → ~33.22%;
- PINS lineage `DEC-PINS-M2-20260905-V2 → MIS-PINS-20260904`;
- full portfolio expected upside BLOCKED because existing holdings lack valuation coverage.

Reference synthetic ACTIVE input only:
- NVDA trim 10k → PINS ADD 10k can be simulated;
- concentration ~41.25% → ~38.32%;
- net expected-value comparison BLOCKED due missing NVDA valuation;
- this is not a recommendation to trim NVDA.

### M3.4 Rebalancing Recommendation boundary
M3.4 is **valuation-coverage gated**.

Recommendation logic may not select an economic trim until the relevant source holding has traceable current expected-return valuation. Coverage work may prioritize NVDA because it is the largest concentration review item, but prioritizing valuation coverage is not equivalent to recommending a sale.

Required comparison path:
```text
Holding current valuation / expected return
        + concentration / theme / downside context
        ↓
Opportunity candidate valuation / expected return
        + Portfolio Fit / downside / ranking
        ↓
Scenario delta from M3.3
        ↓
Deterministic trim/add recommendation
        ↓
Human approval
```

`REBALANCE` remains DRAFT until this path and regressions pass.

### Experience / Human Approval
Google Sheets remains view/audit compatibility only. During M3.2–M3.5, only `System_Foundation` / audit status should be written; do not add production allocation/scenario formulas or policy config to Sheet tabs.

## Security
`fwios` remains private. Scenario tables use RLS defense-in-depth; `anon`/`authenticated` privileges remain revoked. Security Advisor after M3.3 reports no new WARN/ERROR findings attributable to scenario DDL; expected private-schema `RLS Enabled No Policy` INFO notices remain.

## Architectural invariants
1. Web research cannot jump directly to final valuation/allocation/recommendation.
2. Facts and assumptions remain separate.
3. Portfolio accounting uses reconciled ledger state only.
4. Policy versions and raw lineage reproduce decisions.
5. Missing/stale/unverified promotion inputs fail closed.
6. Revision/Chase cannot override valuation/Mispricing/Portfolio Fit/core gates.
7. Opportunity Ranking cannot create a second weighted score.
8. Value-Wait candidates cannot receive capital.
9. Allocation cannot use a stale ranking/portfolio pair.
10. New-cash allocation never force-fills additional assets.
11. Scenario previews do not mutate live holdings.
12. Scenario simulation does not choose a trim; recommendation is a separate layer.
13. Appreciation alone cannot justify a trim.
14. Missing holding valuation blocks full expected portfolio upside.
15. Missing valuation on a changed asset blocks net expected-value comparison.
16. Human execution only.
17. M4 automation remains foundation-only until explicitly activated/tested.

See:
- `policies/opportunity/OPPORTUNITY_RANKING_V1.md`
- `policies/allocation/NEW_CASH_ALLOCATION_V1.md`
- `policies/scenario/PORTFOLIO_SCENARIO_V1.md`
