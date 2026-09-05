# Focused Wealth Investment OS — Master System Roadmap

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract: **FWIOS-CONTRACT-0.87.8**  
Last updated: **2026-09-05 Asia/Bangkok**  
Execution mode: **HUMAN EXECUTION ONLY**

## Authority model
Supabase = System of Record / State. GitHub = Logic / Contracts / Tests / Migrations. Google Sheets = View / Compatibility / Reconciliation / Audit / Export. Live state overrides stale docs.

## Current system state
| Item | Current state |
|---|---|
| Foundation | 0.87 |
| Contract | FWIOS-CONTRACT-0.87.8 |
| Portfolio batch | PORTFOLIO-M2-20260905-01 |
| Portfolio review flags | 10 assets / NVDA ~41.25% / crypto ~38.09% |
| M2 Decision Intelligence | PASS |
| M3.1 Opportunity Ranking | PASS / LIVE |
| M3.2 New-Cash Allocation | PASS / LIVE |
| M3.3 Scenario Simulation | PASS / LIVE |
| M3.4 Rebalancing Recommendation | **PASS / LIVE** |
| M3.5 Human Approval / Cutover | **NEXT** |
| Sector automation | PAUSED — M3 priority |
| Next queued sector | Financials |

## M1 — Research Pipeline v2
**CORE HARDENING PASS / PERFORMANCE VALIDATION OPEN.** Performance optimization does not block M3.

## M2 — Decision Intelligence
**PASS.** Revision/Chase active, 16/16 regressions. PINS Promotion PASS / READY - HUMAN REVIEW. RDDT remains Value-Wait because Mispricing FAIL.

## M3.1 — Opportunity Ranking
**PASS / LIVE.** `POL-OPPORTUNITY-RANKING-V1`, 8/8 regressions. PINS Immediate #1; RDDT Value-Wait #1. Priority = Core Score only; max 3 Immediate / 5 Watchlist; no force-fill.

## M3.2 — New-Cash Capital Allocation
**PASS / LIVE.** `POL-NEW-CASH-ALLOCATION-V1`, 20/20 regressions. New cash first, one deployed asset/run, new-position starter cap 5% post-money, residual cash held, no live mutation.

## M3.3 — Portfolio Scenario Simulation
**PASS / LIVE.** `POL-PORTFOLIO-SCENARIO-V1`, 28/28 regressions. Modes: NO_SELL / SOFT_REBALANCE / ACTIVE_REBALANCE. Scenario previews never mutate holdings. Full-portfolio expected upside remains fail-closed until every risk asset has valuation coverage.

### Holding valuation coverage improvement
`SEMIS_MIDCYCLE_DCF_V1::1.0` is now production-live for Semiconductor Designer holdings.

NVDA current production lineage:
- price snapshot `PX-NVDA-20260904` = $230.34;
- FCF LTM $127.006B;
- conservative net cash $23.220B;
- signed Hugging Face purchase consideration $11.9B deducted from equity bridge;
- Bear / Base / Bull / PW FV = $87.0303 / $166.1671 / $273.2095 / $173.1435;
- `REG-SEMIS-V1-NVDA-PARITY` = PASS.

NVDA now has traceable holding expected-return coverage. Current full risk-asset coverage is ~41.25% by portfolio weight, so full-portfolio expected upside still remains `BLOCKED - INCOMPLETE PORTFOLIO VALUATION COVERAGE`. This does not block a changed-assets comparison when every changed asset is covered.

## M3.4 — Rebalancing Recommendation
**PASS / PRODUCTION LIVE.** Policy `POL-REBALANCE-V1`; deterministic regressions **12/12 PASS**.

Production rules:
1. Use new cash before considering a trim.
2. ADD candidate must be active Immediate with Decision Snapshot valuation lineage.
3. Trim source must be a current holding with fresh production valuation; uncovered holdings are excluded, never proxied.
4. v1 active trim requires concentration review (>30%) plus at least 25 percentage points of PW expected-return edge.
5. Recommended trim = min(remaining approved candidate capacity after new cash, source concentration excess above 30%).
6. Do not sell more than can be redeployed into the approved opportunity.
7. 30% is a review threshold, not a forced target.
8. Appreciation-only rationale is forbidden; trim needs explicit economic/risk rationale.
9. Human review + broker price verification remain mandatory. No auto-trading.

Synthetic regression parity only:
| New cash | New-cash ADD to PINS | NVDA trim | Total PINS ADD | Gate |
|---:|---:|---:|---:|---|
| THB 0 | 0 | ~17,045.30 | ~17,045.30 | READY - HUMAN REVIEW |
| THB 10,000 | 10,000 | ~7,545.30 | ~17,545.30 | READY - HUMAN REVIEW |
| THB 50,000 | ~19,545.30 | 0 | ~19,545.30 | NEW_CASH_FIRST / no active trim |

The zero-cash regression has NVDA ~41.25% → ~36.25% and PINS → ~5%. It deliberately does **not** force NVDA to 30%. These are engine parity cases, not trade instructions. No real recommendation run has been materialized during activation.

## M3.5 — Human Approval / Cutover
**NEXT.** M3 exits only when the system can prove end-to-end traceability:
`source transaction → reconciled position → portfolio batch → Decision Snapshot / holding valuation → Opportunity Ranking → allocation → scenario → recommendation → explicit human approval`.

Required exit tests:
- no unexplained quantity/value/cost-basis/realized-P&L differences;
- recommendation source refs remain immutable;
- stale price/valuation invalidates approval;
- approval does not itself place an order;
- rejected/expired recommendations cannot be executed;
- Google Sheets can be reduced to legacy/reporting surface only after cutover passes.

## M4 — Autonomous Investment OS
**PENDING M3.** Event/delta refresh, thesis refresh, opportunity refresh, concentration alerts and blocker recovery remain future work. `system_events` is foundation-only until explicitly activated and regression-tested.

## Remaining side work
Research/model coverage debt remains fail-closed for affected names. Financials remains queued. Completing valuation coverage for other holdings will improve full-portfolio expected-upside analytics but no longer blocks M3.4 changed-assets recommendation logic.

## Immediate next action
**Build M3.5 Human Approval / Cutover.**
1. Define immutable recommendation approval snapshot.
2. Add approve/reject/expire states and stale-input revalidation.
3. Prove no approval action mutates portfolio or submits a broker order.
4. Add end-to-end traceability regressions.
5. Pass cutover, then reduce Google Sheet surface to read-only/legacy reporting as planned.

## Google Sheet rule during remaining M3
Write only `System_Foundation` / audit-status information. Do not add production policy/formula/allocation/rebalancing logic to Sheet tabs.
