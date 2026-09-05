# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.6**  
Foundation compatibility: **0.87**  
Architecture state: **CONSOLIDATION V1 LIVE / M2 PASS / M3.1 + M3.2 LIVE**

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
| Opportunity Ranking v1 | ACTIVE / deterministic |
| New-Cash Allocation v1 | **ACTIVE / deterministic** |
| Rebalance | DRAFT |

### Decision Snapshot boundary
`fwios.decision_snapshots` is the reproducibility boundary between candidate intelligence and downstream portfolio decisions. Each snapshot references exact portfolio, price, valuation, mispricing, Portfolio Fit, Revision, Chase, core score and active policy versions.

Current V2 snapshots:
- PINS: Promotion PASS / READY - HUMAN REVIEW.
- RDDT: WAIT FOR VALUE because Mispricing is insufficient.

## M3 decision-and-capital path
```text
Decision Snapshot
      ↓
Opportunity Ranking v1
      ↓
New-Cash Allocation v1
      ↓
Portfolio Scenario Simulation
      ↓
Rebalancing Recommendation
      ↓
Human Approval
```

### M3.1 Opportunity Ranking
Production objects:
- `fwios.opportunity_ranking_runs`
- `fwios.opportunity_ranked_candidates`
- `fwios.v_latest_decision_snapshots`
- `fwios.v_opportunity_ranking_current`
- `fwios.opportunity_bucket_v1(...)`
- `fwios.opportunity_priority_score_v1(...)`

Policy: `POL-OPPORTUNITY-RANKING-V1`.

Ranking invariants:
- priority = existing Core Score;
- no second weighted investment score;
- Promotion PASS → Immediate;
- Mispricing-only FAIL with all other gates PASS → Value-Wait;
- all other states → Excluded;
- max 3 Immediate / 5 Watchlist; never force-fill.

First production run `OPPRANK-M3-20260905-01`:
- PINS → Immediate rank 1 / priority 87.6000.
- RDDT → Value-Wait rank 1 / priority 72.1500.

M3.1 regressions: 8/8 PASS.

### M3.2 New-Cash Allocation
Policy: `POL-NEW-CASH-ALLOCATION-V1`.

Existing scenario tables are extended rather than duplicated:
- `fwios.capital_allocation_runs`
- `fwios.capital_allocation_actions`
- `fwios.capital_allocation_metrics`

M3.2 adds traceability fields for ranking run, requested/allocated/unallocated cash, gates and ranking-candidate references.

Production functions:
- `fwios.new_cash_capacity_v1(...)`
- `fwios.new_cash_input_gate_v1(...)`
- `fwios.new_cash_current_input_gate_v1(...)`
- `fwios.preview_new_cash_candidates_v1(...)`
- `fwios.preview_new_cash_allocation_v1(...)`
- `fwios.preview_new_cash_metrics_v1(...)`

Current context view:
- `fwios.v_new_cash_allocation_current_context` (`security_invoker=true`).

#### Allocation invariants
1. Input cash must be positive.
2. Latest reconciled portfolio batch must be PASS.
3. Latest ranking run must be PASS and its policy ACTIVE.
4. Ranking portfolio batch must equal latest portfolio batch.
5. Only Immediate candidates may receive capital.
6. v1 supports Stock candidates only; unsupported classes fail closed.
7. Maximum one deployed asset per allocation run.
8. New position starter capacity = 5% post-money portfolio value.
9. Existing position staged add = min(5% post-money value, headroom to 30% single-stock ceiling).
10. Existing position already above 30% gets zero add capacity.
11. Residual cash remains `CASH_THB`; never force-fill the next candidate.
12. Every ADD must reference its ranking candidate and Decision Snapshot.
13. Preview functions are non-mutating and cannot auto-trade.

M3.2 regressions: **20/20 PASS**.

Synthetic production parity:
- 10k new cash → PINS 10k / residual 0.
- 50k → PINS 19,545.30 / residual 30,454.70.
- 100k → PINS 22,045.30 / residual 77,954.70.

RDDT remains zero allocation because Value-Wait cannot bypass Mispricing.

These are regression previews, not trade instructions. No production allocation run is materialized without a real user cash amount or explicit scenario request.

### M3.3+ Scenario boundary
Scenario modes remain:
- `NO_SELL`
- `SOFT_REBALANCE`
- `ACTIVE_REBALANCE`

M3.3 should use the active New-Cash Allocation engine as the `NO_SELL` baseline, then layer explicit scenario math over immutable snapshots.

Required scenario outputs:
- before/after position weights;
- expected portfolio-upside change;
- concentration/theme/crypto/focus effects;
- downside/guardrail changes;
- full source traceability.

No scenario may mutate live holdings and no output may auto-trade. `REBALANCE` remains DRAFT until scenario math and traceability regressions pass.

### Experience / Human Approval
Google Sheets remains view/audit compatibility only. During M3.2–M3.5, only `System_Foundation` / audit status should be written; do not add production allocation formulas, policy config or scoring logic to Sheet tabs.

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
New-Cash Allocation v1
        ↓
Scenario / Rebalancing
        ↓
Human Approval
```

## Security
`fwios` remains private. Allocation preview functions are `SECURITY INVOKER`, pin `search_path` to `pg_catalog, fwios`, and are not `SECURITY DEFINER`. New/current views use `security_invoker=true`. `anon` and `authenticated` do not receive allocation-function privileges.

Security Advisor after M3.2 DDL reports no new WARN/ERROR findings; expected private-schema `RLS Enabled No Policy` INFO notices remain.

## Architectural invariants
1. Web research cannot jump directly to final valuation/allocation.
2. Facts and assumptions remain separate.
3. Portfolio accounting uses reconciled ledger state only.
4. Policy versions and raw lineage reproduce decisions.
5. Missing/stale/unverified promotion inputs fail closed.
6. Revision/Chase cannot override valuation, Mispricing, Portfolio Fit or core gates.
7. Opportunity Ranking cannot change M2 scores or create a second weighted score.
8. Value-Wait candidates cannot receive new cash.
9. Allocation cannot use a stale ranking/portfolio pair.
10. New-cash allocation never force-fills additional assets.
11. Existing >30% stock positions receive zero M3.2 add capacity.
12. Allocation/scenario previews do not mutate live holdings.
13. Human execution only.
14. M4 automation should prefer event/delta refresh over unnecessary full-stack reruns.

See `policies/opportunity/OPPORTUNITY_RANKING_V1.md` and `policies/allocation/NEW_CASH_ALLOCATION_V1.md`.
