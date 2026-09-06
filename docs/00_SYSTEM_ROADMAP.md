# Focused Wealth Investment OS — Master System Roadmap

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract: **FWIOS-CONTRACT-0.87.11**  
Last updated: **2026-09-06 Asia/Bangkok**  
Execution mode: **HUMAN EXECUTION ONLY**

## Authority model
Supabase = System of Record / State. GitHub = Logic / Contracts / Tests / Migrations. Google Sheets = View / Compatibility / Reconciliation / Audit / Export. Live state overrides stale docs.

## Current system state
| Item | Current state |
|---|---|
| Foundation | 0.87 |
| Contract | FWIOS-CONTRACT-0.87.11 |
| Portfolio batch | PORTFOLIO-M2-20260905-01 |
| Portfolio review flags | 10 assets / NVDA ~41.25% / crypto ~38.09% |
| M3.1–M3.5 | **COMPLETE / CUTOVER PASS** |
| Quality / Durability Hardening v1 | **PASS / LIVE — 20/20 + 11/11 verification** |
| Data Scoring | **V3 DURABILITY ACTIVE** |
| Opportunity Ranking | **V2 ACTIVE** |
| Current Immediate candidates | **0** |
| PINS | **WATCHLIST_MODEL_REVIEW — core 69.6** |
| RDDT | **WATCHLIST_VALUE_WAIT — core 66.0782** |
| Dashboard Read Model | PASS / LIVE — 17/17 |
| Dashboard Auto Refresh | PASS / LIVE — 14/14 |
| Monitoring Google Sheet | PRIMARY MONITORING SURFACE / AUTO REFRESH LIVE |
| Sector automation | PAUSED — quality-hardening evidence revalidation priority |
| Next queued sector | Financials |
| Immediate next action | **Collect hardening evidence + revalidate Communication Services** |

## M1 — Research Pipeline v2
**CORE HARDENING PASS / PERFORMANCE VALIDATION OPEN.** Research/model coverage debt remains fail-closed for affected names.

## M2/M3 historical boundary
M2 and M3 cutover remain valid historical system milestones. M3.1–M3.5 are still LIVE, with human execution only.

However, candidate eligibility has been hardened after the PINS audit. Historical PINS snapshots that previously passed remain immutable audit history; they are superseded by new Quality-Hardening snapshots and are not current trade instructions.

## Quality / Durability Hardening v1
**PASS / PRODUCTION LIVE.**

New production path:
`Evidence → Normalization → Valuation/Mispricing → Portfolio Fit → Quality/Durability Hardening → Core Scoring → Revision/Chase → Decision Snapshot → Opportunity Ranking → Allocation/Scenario/Rebalance/Approval`.

Promotion requires four independent gates:
1. Business Durability
2. Owner Earnings
3. Value Trap
4. Valuation Robustness

Missing critical evidence fails closed.

Expected Return v3 removes the old >=30% upside = 100 staircase. It now uses a continuous upside score multiplied by valuation confidence. Core weights remain 30/30/25/15.

Hardening thresholds are intentionally compatible with aggressive Phase 1:
- >=3-year durability anchor by default;
- SBC/revenue >10% requires owner-economics reconciliation; >20% hard review; >30% fail;
- extreme modeled mispricing >=75% requires counter-thesis evidence;
- bear downside worse than 30% reviews, worse than 50% fails.

Historical share-price weakness is a review trigger only, never a substitute for expected return.

## PINS revalidation
Current immutable lineage:
- Hardening: `HARD-PINS-20260906-V1`
- Score: `SCORE-PINS-QH-20260906-V1`
- Decision: `DEC-PINS-QH-20260906-V1`

Result:
- Business / Thesis: 82
- Expected Return: **100 → 40**
- Portfolio Fit: 90
- Downside Risk: 70
- Core Score: **87.6 → 69.6**
- Valuation confidence: **0.40**
- Promotion: **BLOCKED - QUALITY HARDENING**
- Bucket: **WATCHLIST_MODEL_REVIEW**

Reason: current 18% revenue / 11% MAU growth is not a verified multi-year durability anchor; SBC/revenue ~22.43% lacks owner-earnings/dilution reconciliation; extreme modeled upside lacks canonical counter-thesis evidence; valuation still depends on an insufficiently anchored five-year growth assumption.

This is not a conclusion that Pinterest has no future. It is a conclusion that the current evidence is insufficient for an Immediate allocation signal.

## RDDT revalidation
Current lineage:
- Hardening: `HARD-RDDT-20260906-V1`
- Score: `SCORE-RDDT-QH-20260906-V1`
- Decision: `DEC-RDDT-QH-20260906-V1`

Result:
- Expected Return: **24.7607**
- Core: **66.0782**
- Mispricing: FAIL - INSUFFICIENT MISPRICING
- Bucket: **WATCHLIST_VALUE_WAIT**

Hardening evidence is also incomplete, so even a future valuation improvement cannot create Immediate status until hardening clears.

## Opportunity Ranking v2
Current run: `OPPRANK-QH-20260906-01`.

Current board:
- Immediate: **none**
- RDDT: `WATCHLIST_VALUE_WAIT`
- PINS: `WATCHLIST_MODEL_REVIEW`

No force-fill. Max 3 Immediate / 5 Watchlist remains unchanged.

## Capital Allocation effect
`POL-NEW-CASH-ALLOCATION-V1` remains unchanged and consumes only Immediate candidates.

Production verification with THB 50,000 new cash now returns:
**HOLD CASH THB 50,000 — NO ALLOCATABLE IMMEDIATE CANDIDATE.**

No allocation run, scenario run, rebalancing recommendation, approval event or portfolio mutation was created by the hardening activation.

## M3.3 Scenario / M3.4 Rebalance / M3.5 Approval
All remain LIVE and non-mutating until explicit human request boundaries are crossed.

The old synthetic NVDA→PINS parity remains regression history only. Because PINS is no longer Immediate, it is not a current eligible ADD candidate.

## Dashboard
Read Model v1: **17/17 PASS**. Auto Refresh v1: **14/14 PASS**.

Current payload after hardening:
- refresh gate PASS;
- Current Action = `NO_ACTIONABLE_OPPORTUNITY`;
- PINS = `WATCHLIST_MODEL_REVIEW`;
- RDDT = `WATCHLIST_VALUE_WAIT`;
- portfolio/account KPIs unchanged.

The Dashboard remains downstream/read-only for investment logic.

## Immediate next action
**Collect Quality-Hardening Evidence + Revalidate Communication Services.**

Priority evidence:
- multi-year comparable revenue/user/monetization and margin/FCF durability;
- SBC, dilution, buyback and owner-earnings reconciliation;
- documented structural/value-trap counter-thesis for large modeled discounts;
- conservative valuation sensitivity / robustness.

After evidence is collected:
1. create new immutable hardening snapshots;
2. recompute Expected Return v3 and Core Score;
3. create new Decision Snapshots;
4. rerank;
5. only then decide whether any candidate becomes Immediate.

Financials remains queued and sector automation remains PAUSED until this revalidation is completed. Legacy reduction is temporarily secondary to scoring integrity.

## M4 — Autonomous Investment OS
Future priority: event/delta research refresh, thesis monitoring, opportunity refresh, concentration alerts and blocker recovery. Autonomous monitoring must never bypass Quality Hardening or human execution.

## Legacy Google Sheets
The new monitoring Dashboard remains primary. Legacy Sheets remain available for research/audit/reconciliation. Do not remove historical evidence while the Communication Services hardening revalidation is underway.
