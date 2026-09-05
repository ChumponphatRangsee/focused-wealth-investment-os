# Focused Wealth Investment OS — Master System Roadmap

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract: **FWIOS-CONTRACT-0.87.10**  
Last updated: **2026-09-05 Asia/Bangkok**  
Execution mode: **HUMAN EXECUTION ONLY**

## Authority model
Supabase = System of Record / State. GitHub = Logic / Contracts / Tests / Migrations. Google Sheets = View / Compatibility / Reconciliation / Audit / Export. Live state overrides stale docs.

## Current system state
| Item | Current state |
|---|---|
| Foundation | 0.87 |
| Contract | FWIOS-CONTRACT-0.87.10 |
| Portfolio batch | PORTFOLIO-M2-20260905-01 |
| Portfolio review flags | 10 assets / NVDA ~41.25% / crypto ~38.09% |
| M2 Decision Intelligence | PASS |
| M3.1 Opportunity Ranking | PASS / LIVE |
| M3.2 New-Cash Allocation | PASS / LIVE |
| M3.3 Scenario Simulation | PASS / LIVE |
| M3.4 Rebalancing Recommendation | PASS / LIVE |
| M3.5 Human Approval / Cutover | PASS / LIVE |
| M3 overall | **COMPLETE / CUTOVER PASS** |
| Dashboard Read Model v1 | **PASS / LIVE — 17/17** |
| Monitoring Google Sheet | **CREATED / HANDOFF PASS** |
| Sector automation | PAUSED — dashboard refresh/handoff priority |
| Next queued sector | Financials |
| Immediate next action | **Verify controlled dashboard refresh workflow + plan legacy reduction** |

## M1 — Research Pipeline v2
**CORE HARDENING PASS / PERFORMANCE VALIDATION OPEN.** Performance optimization remains side work and does not invalidate M2/M3 production capabilities.

## M2 — Decision Intelligence
**PASS.** Revision/Chase active, 16/16 regressions. PINS Promotion PASS / READY - HUMAN REVIEW. RDDT remains Value-Wait because Mispricing FAIL.

## M3.1 — Opportunity Ranking
**PASS / LIVE.** `POL-OPPORTUNITY-RANKING-V1`, 8/8 regressions. PINS Immediate #1; RDDT Value-Wait #1. Priority = Core Score only; max 3 Immediate / 5 Watchlist; no force-fill.

## M3.2 — New-Cash Capital Allocation
**PASS / LIVE.** `POL-NEW-CASH-ALLOCATION-V1`, 20/20 regressions. New cash first, one deployed asset/run, new-position starter cap 5% post-money, residual cash held, no live mutation.

## M3.3 — Portfolio Scenario Simulation
**PASS / LIVE.** `POL-PORTFOLIO-SCENARIO-V1`, 28/28 regressions. Modes: NO_SELL / SOFT_REBALANCE / ACTIVE_REBALANCE. Scenario previews never mutate holdings. Full-portfolio expected upside remains fail-closed until every risk asset has valuation coverage.

### Holding valuation coverage
`SEMIS_MIDCYCLE_DCF_V1::1.0` is production-live for Semiconductor Designer holdings. NVDA has traceable expected-return coverage through `VAL-NVDA-SEMIS-20260905`; full risk-asset coverage remains incomplete, but changed-assets NVDA↔PINS comparison is valid because both changed assets are covered.

## M3.4 — Rebalancing Recommendation
**PASS / LIVE.** `POL-REBALANCE-V1`, **12/12 PASS**.

Key behavior:
1. New cash is consumed before trim.
2. ADD must be active Immediate + Decision Snapshot valuation lineage.
3. Trim source must be current, valuation-covered and concentration-review eligible.
4. Minimum PW expected-return edge = 25pp.
5. Trim is capped by both remaining candidate capacity and concentration excess above 30%.
6. 30% is a review threshold, not a forced sell target.
7. Appreciation-only rationale is forbidden.
8. Human review + broker price verification remain required.

Synthetic examples remain regression parity only, never trade instructions.

## M3.5 — Human Approval / Cutover
**PASS / PRODUCTION LIVE.** Policy `POL-HUMAN-APPROVAL-V1`; deterministic regressions **30/30 PASS**.

Architecture: `Immutable Recommendation Snapshot → Immutable Approval Packet → Append-only Approval Event`.
Only `PRODUCTION_USER_REQUESTED` packets are actionable; approval does not place broker orders or mutate portfolio accounting.

Cutover proof remains **9/9 PASS** with 29/29 transactions and 16/16 positions reconciled. Validation objects are non-actionable and no production-user recommendation, human approval event, allocation run or scenario run was created by cutover.

## M3 exit
**M3 = COMPLETE / CUTOVER PASS.**

The production chain is:
`source transaction → reconciled position → portfolio batch → valuation / Decision Snapshot → Opportunity Ranking → New-Cash Allocation → Scenario → Rebalancing Recommendation → Human Approval`.

Human Approval is still not trade execution. A later approved packet requires a separate human broker action and broker-price verification.

## Post-M3 — Dashboard Read Model + Monitoring Google Sheet
**PASS / LIVE — HANDOFF COMPLETE.**

Supabase now exposes six stable private `security_invoker` read models:
- `fwios.v_dashboard_holdings`
- `fwios.v_dashboard_account_summary`
- `fwios.v_dashboard_opportunities`
- `fwios.v_dashboard_current_action`
- `fwios.v_dashboard_alerts`
- `fwios.v_dashboard_system_health`

Dashboard regressions: **17/17 PASS**. Security Advisor shows no new WARN/ERROR; only existing INFO `rls_enabled_no_policy` notices for the private service-role design.

Monitoring surface:
- Google Sheet: **Focused Wealth Dashboard - Chumponphat**
- Sheet ID: `17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8`
- visible tab: `Dashboard`
- hidden data snapshot tab: `_Data`
- Account View: All Accounts / Best / Loan Money / Mom

Account View affects only Portfolio Value, Total P&L, Unrealized P&L, Realized P&L and Holdings display. Portfolio risk, Portfolio Fit, concentration, crypto and rebalancing always use consolidated exposure.

Current consolidated dashboard parity:
- Portfolio Value ~THB 340,906.10
- Total P&L ~+THB 27,360.05
- Unrealized P&L ~+THB 5,566.00
- Realized P&L ~+THB 21,794.05
- Phase-1 progress ~34.1%
- Largest position NVDA ~41.3% — REVIEW
- Crypto ~38.1% — ABOVE TARGET
- PINS Immediate #1 / RDDT Value-Wait #1

The Sheet contains display/filter formulas only. Production scoring, allocation, scenario, rebalance and approval logic remain in Supabase/GitHub.

### Refresh boundary
The Google Sheet currently uses a **controlled snapshot export**, not a direct live database connection. It displays source observed-at/batch status and must not be described as real-time until a refresh workflow is implemented and verified.

## Immediate next action
**Verify controlled Supabase → Sheet refresh workflow, then plan legacy-surface reduction.**
Do not delete legacy audit/reconciliation history automatically. The legacy `US_Stock_Sector_Business_Model_Screener` and Portfolio Tracker remain available until the refresh and reduction plan are explicitly accepted.

## M4 — Autonomous Investment OS
**PENDING REFRESH/HANDOFF FOLLOW-THROUGH / FUTURE PRIORITY.** Event/delta refresh, thesis refresh, opportunity refresh, concentration alerts and blocker recovery remain future work. `system_events` remains foundation-only until explicitly activated and regression-tested.

## Remaining side work
Research/model coverage debt remains fail-closed for affected names. Financials remains queued. Completing valuation coverage for other holdings improves full-portfolio expected-upside analytics but does not invalidate the completed M3 changed-assets path.

## Google Sheet rule
The new monitoring Dashboard is now the preferred monitoring surface. Google Sheets remains downstream and read-only from a production-logic perspective. Legacy reduction is permitted after handoff, but deletion/restructuring requires explicit verification of the controlled refresh workflow and retained audit access.
