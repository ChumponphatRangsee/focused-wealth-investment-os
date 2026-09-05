# Supabase Migration — Focused Wealth Investment OS

Status: **M2 PASS / M3.1 + M3.2 + M3.3 LIVE / M3.4 COVERAGE-GATED**  
Date: **2026-09-05**  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`  
Execution contract: `FWIOS-CONTRACT-0.87.7`

## Authority
- Supabase = System of Record / State
- GitHub = System of Logic / Contracts / Tests / Migrations
- Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export

## Completed authority layers

### Research / Evidence — PASS
Supabase owns source/evidence/canonical/normalized state plus RPV2.1 cache/controller behavior. Current snapshot: 18 evidence-ready, 13 valuation-ready, 72.2% decision coverage, DISCOVERY controller, six open model-debt roots.

### Portfolio State — PASS
- 29/29 transactions reconciled.
- 16/16 positions reconciled.
- authoritative portfolio value snapshot ~THB 340,906.10.
- current review flags: 10 open assets, NVDA ~41.25%, crypto ~38.09%.

### M2 Decision Intelligence — PASS
Active deterministic policies:
- `POL-REVISION-SCORE-V1`
- `POL-CHASE-SCORE-V1`

Regression status: **16/16 PASS**.

Reference decisions:
- PINS → Promotion PASS / READY - HUMAN REVIEW.
- RDDT → Mispricing FAIL / GOOD COMPANY - WAIT FOR VALUE.

## M3.1 Opportunity Ranking — PASS / LIVE
Active policy: `POL-OPPORTUNITY-RANKING-V1`.

Production run `OPPRANK-M3-20260905-01` on `PORTFOLIO-M2-20260905-01`:
- PINS → Immediate rank 1 / priority 87.6000.
- RDDT → Value-Wait rank 1 / priority 72.1500.

Regression status: **8/8 PASS**.

## M3.2 New-Cash Capital Allocation — PASS / LIVE
Active policy: `POL-NEW-CASH-ALLOCATION-V1`.

Production functions:
- `new_cash_capacity_v1(...)`
- `new_cash_input_gate_v1(...)`
- `new_cash_current_input_gate_v1(...)`
- `preview_new_cash_candidates_v1(...)`
- `preview_new_cash_allocation_v1(...)`
- `preview_new_cash_metrics_v1(...)`

Allocation behavior:
- Immediate Stock candidates only;
- max one deployed asset per run;
- new-position starter cap 5% post-money;
- existing add bounded by 5% staged increment + 30% stock ceiling;
- Value-Wait receives zero;
- residual capital stays `CASH_THB`;
- no force-fill / no mutation.

Regression status: **20/20 PASS**.

Synthetic parity only:
- 10k → PINS 10,000 / cash 0.
- 50k → PINS 19,545.30 / cash 30,454.70.
- 100k → PINS 22,045.30 / cash 77,954.70.

Real allocation-run count remains **0**.

## M3.3 Portfolio Scenario Simulation — PASS / LIVE
Active policy: `POL-PORTFOLIO-SCENARIO-V1`.

New private tables:
- `portfolio_scenario_runs`
- `portfolio_scenario_actions`
- `portfolio_scenario_positions`
- `portfolio_scenario_metrics`

All have RLS enabled and anon/authenticated access revoked.

Production preview/gate functions:
- `portfolio_scenario_structural_gate_v1(...)`
- `portfolio_scenario_current_input_gate_v1(...)`
- `preview_portfolio_scenario_actions_v1(...)`
- `preview_portfolio_scenario_positions_v1(...)`
- `preview_portfolio_scenario_metrics_v1(...)`

Functions are SECURITY INVOKER, pin `search_path` to `pg_catalog, fwios`, and anon/authenticated EXECUTE is revoked.

### Scenario modes
- `NO_SELL`: positive new cash; no trim; exact M3.2 allocation/capacity path.
- `SOFT_REBALANCE`: no trim in v1; one-time cash arithmetic intentionally equals NO_SELL until recurring DCA/redirection state exists.
- `ACTIVE_REBALANCE`: hypothetical trim inputs are allowed for simulation only; M3.3 does not select the trim.

Trim input gates:
- current holding required;
- amount cannot exceed current position value;
- explicit economic/risk rationale required;
- appreciation-only rationale forbidden.

Scenario outputs include before/after position values and weights, max-stock concentration, crypto weight, position count, residual cash, exact ADD Decision/Mispricing lineage, candidate downside score, valuation coverage and expected-value metrics.

Regression status: **28/28 PASS**.

### Valuation-coverage gate
At activation, current holdings expected-upside valuation coverage = **0%**.

Therefore:
- `full_portfolio_pw_upside` is `BLOCKED - INCOMPLETE PORTFOLIO VALUATION COVERAGE`;
- no historical return, cost basis or narrative target substitutes for missing expected return;
- PINS ADD-side expected value is available from `DEC-PINS-M2-20260905-V2 → MIS-PINS-20260904`;
- ACTIVE trim of an uncovered holding such as NVDA blocks net expected-value comparison.

This is an evidence-coverage gate, not an engine regression failure.

Synthetic NO_SELL 50k parity:
- PINS ADD 19,545.30; cash 30,454.70.
- max-stock weight ~41.25% → ~35.98%.
- crypto ~38.09% → ~33.22%.
- full portfolio expected upside remains blocked.

Synthetic ACTIVE input only:
- NVDA trim 10,000 + new cash 0 can simulate PINS ADD 10,000.
- concentration ~41.25% → ~38.32%.
- net expected-value comparison BLOCKED because NVDA has no current traceable expected-return valuation.
- this is not a trim recommendation.

Real scenario-run count remains **0**; implementation used preview/regression paths only.

## M3.4 Rebalancing Recommendation — NEXT / COVERAGE-GATED
`REBALANCE` remains DRAFT.

Before exact trim/add recommendation is legal:
1. relevant source holding must have traceable current valuation / expected return;
2. retained expected return must be comparable with the candidate opportunity;
3. concentration/theme/crypto/focus/downside changes must be evaluated through M3.3;
4. recommendation-size and traceability regressions must pass.

NVDA is the first valuation-coverage priority because it is the largest concentration review item; this is modeling prioritization, not a recommendation to sell NVDA.

## M4 event foundation
`system_events` exists but no production trigger/autonomous workflow is enabled.

## Security
Security Advisor after M3.3 reports no new WARN/ERROR findings attributable to scenario DDL. Expected private-schema `RLS Enabled No Policy` INFO notices remain. Reference: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy

## Sheet role
During M3.2–M3.5, Google Sheets receives only `System_Foundation` / audit-status synchronization. No new production policy/config/allocation/scenario logic should be written into Sheet tabs.

## Next milestone
**Close trim-candidate valuation coverage, then build M3.4 Rebalancing Recommendation v1.**

1. Define holdings-valuation coverage contract for trim comparison.
2. Prioritize NVDA modeling coverage due concentration relevance.
3. Re-run changed-asset expected-value scenario math after coverage is available.
4. Build deterministic recommendation logic over NO_SELL / soft / active scenarios.
5. Keep `REBALANCE` DRAFT until recommendation regressions pass.

Financials remains queued and sector automation remains manually paused while M3 is Main Roadmap priority.
