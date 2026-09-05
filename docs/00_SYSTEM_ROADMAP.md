# Focused Wealth Investment OS — Master System Roadmap

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract: **FWIOS-CONTRACT-0.87.9**  
Last updated: **2026-09-05 Asia/Bangkok**  
Execution mode: **HUMAN EXECUTION ONLY**

## Authority model
Supabase = System of Record / State. GitHub = Logic / Contracts / Tests / Migrations. Google Sheets = View / Compatibility / Reconciliation / Audit / Export. Live state overrides stale docs.

## Current system state
| Item | Current state |
|---|---|
| Foundation | 0.87 |
| Contract | FWIOS-CONTRACT-0.87.9 |
| Portfolio batch | PORTFOLIO-M2-20260905-01 |
| Portfolio review flags | 10 assets / NVDA ~41.25% / crypto ~38.09% |
| M2 Decision Intelligence | PASS |
| M3.1 Opportunity Ranking | PASS / LIVE |
| M3.2 New-Cash Allocation | PASS / LIVE |
| M3.3 Scenario Simulation | PASS / LIVE |
| M3.4 Rebalancing Recommendation | PASS / LIVE |
| M3.5 Human Approval / Cutover | **PASS / LIVE** |
| M3 overall | **COMPLETE / CUTOVER PASS** |
| Sector automation | PAUSED — dashboard/read-model priority |
| Next queued sector | Financials |
| Immediate next action | **Dashboard Read Model + Monitoring Google Sheet** |

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

### Production architecture
`Immutable Recommendation Snapshot → Immutable Approval Packet → Append-only Approval Event`

Approval rules:
- only `PRODUCTION_USER_REQUESTED` packets can be approved;
- `CUTOVER_VALIDATION` and `SYNTHETIC_TEST` are non-actionable;
- APPROVED/REJECTED require HUMAN actor;
- EXPIRED/STALE require SYSTEM actor;
- approval requires fresh price/valuation lineage, unchanged reconciled portfolio batch, unchanged active ranking and matching recommendation fingerprint;
- stale/expired packets require a new packet;
- terminal packets cannot transition again;
- approval itself cannot submit an order or mutate portfolio accounting.

### Cutover proof
Reference validation objects:
- recommendation: `REBAL-M3-CUTOVER-20260905-01` (`CUTOVER_VALIDATION`)
- approval packet: `APPROVAL-M3-CUTOVER-20260905-01` (`VALIDATION_ONLY`)
- cutover certificate: `CUTOVER-M3-20260905-01` PASS before final GitHub handshake; final merge-SHA certificate is created during cutover sync.

End-to-end traceability layers: **9/9 PASS**
1. Source transactions — 29/29 reconciled
2. Source positions — 16/16 reconciled
3. Portfolio batch
4. Candidate Decision Snapshot
5. Opportunity Ranking
6. Source holding valuation
7. Immutable recommendation fingerprint
8. Immutable approval packet
9. Execution isolation

Additional invariants at cutover:
- production-user recommendation runs = 0
- human approval events = 0
- allocation runs = 0
- scenario runs = 0
- system events = 0
- current portfolio remains ~THB 340,906.10
- no broker order and no portfolio mutation were created by M3.5.

## M3 exit
**M3 = COMPLETE / CUTOVER PASS.**

The complete production chain is now:
`source transaction → reconciled position → portfolio batch → valuation / Decision Snapshot → Opportunity Ranking → New-Cash Allocation → Scenario → Rebalancing Recommendation → Human Approval`.

Human Approval is still not trade execution. A later approved packet requires a separate human broker action and broker-price verification.

## Post-M3 — Dashboard Read Model + Monitoring Google Sheet
**NEXT / USER PRIORITY.**

Build stable Supabase read models first, then create a new Google Sheet as the primary monitoring surface. Proposed read models:
- portfolio / Phase-1 progress
- opportunities / watchlist
- valuation & expected upside
- new-cash allocation
- rebalancing recommendation
- human approval state
- freshness / blockers / system health

The new Sheet must consume read models only. Do not duplicate production scoring, allocation, scenario, rebalance or approval logic in Sheets.

After the new dashboard is verified, reduce the existing `US_Stock_Sector_Business_Model_Screener` and legacy Portfolio Tracker to the minimum research/audit/reconciliation surface needed.

## M4 — Autonomous Investment OS
**PENDING DASHBOARD HANDOFF / FUTURE PRIORITY.** Event/delta refresh, thesis refresh, opportunity refresh, concentration alerts and blocker recovery remain future work. `system_events` remains foundation-only until explicitly activated and regression-tested.

## Remaining side work
Research/model coverage debt remains fail-closed for affected names. Financials remains queued. Completing valuation coverage for other holdings improves full-portfolio expected-upside analytics but does not invalidate the completed M3 changed-assets path.

## Google Sheet rule
Until the new monitoring dashboard is created and verified, the current Sheet remains view/audit/research compatibility. Do not add new production logic to it. M3 cutover now permits planned legacy-surface reduction after dashboard handoff.
