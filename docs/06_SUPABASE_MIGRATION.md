# Supabase Migration — Focused Wealth Investment OS

Status: **M2 PASS / M3.1 + M3.2 LIVE / M3.3 NEXT**  
Date: **2026-09-05**  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`  
Execution contract: `FWIOS-CONTRACT-0.87.6`

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
- authoritative portfolio value snapshot ~THB 340,906.10.
- current review flags: 10 open assets, NVDA ~41.25%, crypto ~38.09%.
- legacy Sheet remains retained for reconciliation/audit/export until M3 traceability passes.

### Market Price / Mispricing — PASS
Native quote/snapshot/mispricing state is live with provenance, session/freshness and fail-closed gates.

### Portfolio Fit — PASS
Uses reconciled portfolio state and preserves concentration/crypto/focus review flags.

### Core Scoring — PASS
Native 30/30/25/15 scoring is live.

## M2 Promotion-Gate Hardening — PASS
Active deterministic policies:
- `POL-REVISION-SCORE-V1`
- `POL-CHASE-SCORE-V1`

Regression status: **16/16 PASS**.

Reference decisions:
- PINS → Promotion PASS / READY - HUMAN REVIEW.
- RDDT → Mispricing FAIL / GOOD COMPANY - WAIT FOR VALUE.

## M3.1 Opportunity Ranking — PASS / LIVE

Active policy:
- `POL-OPPORTUNITY-RANKING-V1`

Production run:
- `OPPRANK-M3-20260905-01`
- portfolio batch `PORTFOLIO-M2-20260905-01`
- status PASS

Current output:
- PINS → Immediate rank 1 / priority 87.6000.
- RDDT → Value-Wait rank 1 / priority 72.1500.

Regression status: **8/8 PASS**.

## M3.2 New-Cash Capital Allocation — PASS / LIVE

Active policy:
- `POL-NEW-CASH-ALLOCATION-V1`

Existing scenario tables were extended rather than duplicated:
- `capital_allocation_runs`
- `capital_allocation_actions`
- `capital_allocation_metrics`

Added traceability/state fields:
- ranking run reference;
- ranking candidate reference on ADD actions;
- requested / allocated / unallocated new cash;
- input-integrity and allocation gates;
- ADD traceability constraint requiring ranking + Decision Snapshot references.

Production functions:
- `new_cash_capacity_v1(...)`
- `new_cash_input_gate_v1(...)`
- `new_cash_current_input_gate_v1(...)`
- `preview_new_cash_candidates_v1(...)`
- `preview_new_cash_allocation_v1(...)`
- `preview_new_cash_metrics_v1(...)`

Context view:
- `v_new_cash_allocation_current_context` with `security_invoker=true`.

### Allocation behavior
- only active Immediate candidates may receive new cash;
- v1 supports Stock candidates only;
- max one deployed asset per run;
- new position starter cap = 5% post-money;
- existing position staged-add cap = min(5% post-money, headroom to 30%);
- existing stock above 30% receives zero add capacity;
- Value-Wait candidates receive zero;
- residual cash stays `CASH_THB`;
- never force-fill the second-ranked candidate;
- previews are non-mutating and human-review only.

Regression status: **20/20 PASS**.

Synthetic parity previews:
- THB 10k → PINS THB 10,000 / cash THB 0.
- THB 50k → PINS THB 19,545.30 / cash THB 30,454.70.
- THB 100k → PINS THB 22,045.30 / cash THB 77,954.70.

These are regression previews, not investment instructions.

Current real allocation-run count after M3.2 activation: **0**. No real amount was invented or materialized.

## M3.3 Scenario Simulation — NEXT
Build immutable/non-mutating scenarios using the active new-cash engine as the `NO_SELL` baseline before adding `SOFT_REBALANCE` or `ACTIVE_REBALANCE` math.

Required outputs include before/after weights, expected portfolio-upside change, concentration/theme/crypto/focus effects, downside/guardrail effects and full traceability.

`REBALANCE` remains DRAFT.

## M4 event foundation
`system_events` exists but no production trigger/autonomous workflow is enabled.

## Security
`fwios` remains private. Allocation functions are invoker functions with `search_path` pinned to `pg_catalog, fwios`; views use `security_invoker=true`; no allocation function uses `SECURITY DEFINER`; anon/authenticated execution privileges are revoked.

Security Advisor after M3.2 reports no new WARN/ERROR findings; expected private-schema `RLS Enabled No Policy` INFO notices remain. Reference: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy

## Sheet role
During M3.2–M3.5, Google Sheets receives only `System_Foundation` / audit-status synchronization. No new production policy/config/allocation logic should be written into Sheet tabs.

## Next milestone
**M3.3 Portfolio Scenario Simulation.**

1. Define immutable scenario snapshot and lineage.
2. Build `NO_SELL` baseline from active New-Cash Allocation.
3. Add before/after weights and guardrail math.
4. Add expected portfolio-upside change from traceable valuation/Decision Snapshot inputs.
5. Regression-test non-mutation and traceability.
6. Add SOFT_REBALANCE / ACTIVE_REBALANCE only after NO_SELL passes.

Financials remains queued and sector automation remains manually paused while M3 is the Main Roadmap priority.
