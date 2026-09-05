# Supabase Migration — Focused Wealth Investment OS

Status: **M2 PASS / M3.1 + M3.2 + M3.3 + M3.4 LIVE / M3.5 NEXT**  
Date: **2026-09-05**  
Supabase project ref: `ysjbmeukwbfnxnwqchuq`  
Execution contract: `FWIOS-CONTRACT-0.87.8`

## Authority
- Supabase = System of Record / State
- GitHub = System of Logic / Contracts / Tests / Migrations
- Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export

## Portfolio state
29/29 transactions and 16/16 source positions reconciled. Current value ~THB 340,906.10; 10 open assets; NVDA ~41.25%; crypto ~38.09%. These are review flags, not automatic sell instructions.

## M2 Decision Intelligence — PASS
Revision/Chase active; 16/16 regressions. PINS Promotion PASS; RDDT Value-Wait due Mispricing FAIL.

## M3.1 Opportunity Ranking — PASS / LIVE
`POL-OPPORTUNITY-RANKING-V1`; 8/8 regressions. `OPPRANK-M3-20260905-01`: PINS Immediate #1; RDDT Value-Wait #1.

## M3.2 New-Cash Allocation — PASS / LIVE
`POL-NEW-CASH-ALLOCATION-V1`; 20/20 regressions. New cash first, Stock Immediate candidates only, max one deployed asset/run, new-position cap 5% post-money, residual cash held, no mutation. Real allocation-run count remains 0.

## M3.3 Portfolio Scenario — PASS / LIVE
`POL-PORTFOLIO-SCENARIO-V1`; 28/28 regressions. NO_SELL / SOFT_REBALANCE / ACTIVE_REBALANCE. Preview functions are non-mutating; ADD traces to active Decision Snapshot; TRIM requires current holding + explicit rationale; appreciation-only rationale forbidden.

Full-portfolio expected upside stays fail-closed while any risk asset lacks valuation coverage.

## M3.4 Semiconductor Designer holding valuation coverage
Production model `SEMIS_MIDCYCLE_DCF_V1::1.0` is now IMPLEMENTED / regression PASS.

New/updated production objects:
- `semis_midcycle_dcf_fv_v1(...)`
- `v_holding_valuation_coverage_current`
- NVDA source/evidence/canonical/normalized valuation inputs
- `PX-NVDA-20260904`
- `VAL-NVDA-SEMIS-20260905`

NVDA parity:
- FCF LTM $127.006B
- conservative net cash $23.220B
- signed Hugging Face purchase consideration $11.9B deducted from equity bridge
- Bear/Base/Bull/PW FV $87.0303 / $166.1671 / $273.2095 / $173.1435
- Sep 4 price $230.34
- `REG-SEMIS-V1-NVDA-PARITY` PASS

NVDA now supplies traceable holding expected-return coverage. Current full risk-asset coverage is ~41.25%, so full-portfolio expected upside remains blocked; changed-assets NVDA↔PINS comparison is valid because both changed assets are covered.

## M3.4 Rebalancing Recommendation — PASS / LIVE
Policy `POL-REBALANCE-V1`; regressions **12/12 PASS**.

New private objects:
- `rebalancing_recommendation_runs`
- `rebalancing_recommendation_actions`
- `rebalancing_recommendation_metrics`
- `preview_rebalancing_recommendation_v1(...)`

Rules:
- new cash before trim;
- ADD = active Immediate + Decision Snapshot valuation;
- trim source = current valuation-covered holding + concentration review in v1;
- minimum PW expected-return edge 25pp;
- trim = min(remaining candidate capacity, concentration excess above 30%);
- never trim more than can be redeployed;
- 30% is review threshold, not forced target;
- appreciation-only rationale forbidden;
- uncovered holdings excluded, never proxied;
- human review and broker verification required; no auto-trade.

Synthetic parity only:
- cash 0 → NVDA trim ~17,045.30 → PINS add ~17,045.30;
- cash 10k → use 10k first, NVDA trim ~7,545.30;
- cash 50k → PINS cap funded by new cash, NVDA trim 0.

No real recommendation run is materialized by activation.

## Security
New recommendation tables use RLS defense-in-depth and anon/authenticated access is revoked. New holding coverage view is security-invoker. New functions pin search path and are not SECURITY DEFINER. Security Advisor reports no new WARN/ERROR from M3.4; expected private-schema `RLS Enabled No Policy` INFO notices remain. Reference: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy

## Google Sheet rule
During remaining M3, only `System_Foundation` / audit-status synchronization is allowed. Do not add production valuation/rebalancing logic to Sheet tabs.

## Next milestone — M3.5 Human Approval / Cutover
Build immutable approve/reject/expire state, stale-input revalidation and end-to-end traceability. Approval must not itself mutate portfolio state or submit a broker order. After M3.5 passes, reduce Google Sheet to legacy/read-only reporting surface as planned.

Financials remains queued and sector automation remains paused while M3 is Main Roadmap priority.
