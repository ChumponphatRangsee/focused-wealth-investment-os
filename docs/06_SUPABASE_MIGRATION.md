# Supabase Migration — Focused Wealth Investment OS

Status: **M2 PASS / M3.1 OPPORTUNITY RANKING LIVE / M3.2 NEXT**  
Date: **2026-09-05**  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`  
Execution contract: `FWIOS-CONTRACT-0.87.5`

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
Active deterministic policies:
- `POL-REVISION-SCORE-V1`
- `POL-CHASE-SCORE-V1`

Regression status: **16/16 PASS**.

Reference decisions:
- PINS → Promotion PASS / READY - HUMAN REVIEW.
- RDDT → Mispricing FAIL / GOOD COMPANY - WAIT FOR VALUE.

V2 snapshots:
- `DEC-PINS-M2-20260905-V2`
- `DEC-RDDT-M2-20260905-V2`

## M3.1 Opportunity Ranking — PASS / LIVE

New private objects:
- `opportunity_ranking_runs`
- `opportunity_ranked_candidates`
- `v_latest_decision_snapshots`
- `v_opportunity_ranking_current`
- `opportunity_bucket_v1(...)`
- `opportunity_priority_score_v1(...)`

Active deterministic policy:
- `POL-OPPORTUNITY-RANKING-V1`

Ranking rule:
- priority = existing Core Score only;
- no second weighted investment score;
- Promotion PASS + input-integrity PASS → Immediate;
- only insufficient Mispricing while all other M2 hard gates PASS → Value-Wait;
- all other states → Excluded;
- max 3 Immediate / max 5 Watchlist / never force-fill.

Regression status: **8/8 PASS**, consisting of six boundary/fail-closed tests plus live PINS/RDDT V2 parity.

First production ranking run:
- `OPPRANK-M3-20260905-01`
- portfolio batch `PORTFOLIO-M2-20260905-01`
- status `PASS`

Current ranked output:
- PINS → `IMMEDIATE_BUY_CANDIDATE`, rank 1, priority 87.6000.
- RDDT → `WATCHLIST_VALUE_WAIT`, rank 1, priority 72.1500.

This layer only ranks eligibility for downstream allocation; it does not allocate capital or instruct a trade.

## M3.2 Capital Allocation foundation
Existing tables:
- `capital_allocation_runs`
- `capital_allocation_actions`
- `capital_allocation_metrics`

Current allocation run count after M3.1 activation: **0**.

Next implementation must consume active Opportunity Ranking output, use latest reconciled portfolio state, allocate new cash first, remain non-mutating, and keep `REBALANCE` DRAFT.

## M4 event foundation
`system_events` exists but no production trigger/autonomous workflow is enabled.

## Security
`fwios` remains private. Opportunity Ranking tables have RLS enabled. `anon` and `authenticated` have no `fwios` schema usage. Ranking views use `security_invoker=true`; ranking functions are immutable/invoker, not `SECURITY DEFINER`, and pin `search_path` to `pg_catalog, fwios`.

Security Advisor after M3.1 activation reports no M3.1 WARN/ERROR findings; only expected private-schema `RLS Enabled No Policy` INFO notices remain.

## Sheet role
Do not delete/restructure deep tabs until M3 traceability/cutover passes. Google Sheets remains the view/compatibility/audit layer.

## Next milestone
**M3.2 New-Cash Capital Allocation Engine.**

Next sequence:
1. Define deterministic allocation policy and required inputs.
2. Consume latest reconciled portfolio batch + active Opportunity Ranking run.
3. Allocate new cash before any trim logic.
4. Regression-test candidate caps, concentration, crypto exposure, cash-hold behavior and traceability.
5. Keep allocation/scenario outputs non-mutating.
6. Keep `REBALANCE` DRAFT until M3.3/M3.4 regressions pass.

Financials remains queued and sector automation remains manually paused while M3 is the Main Roadmap priority.
