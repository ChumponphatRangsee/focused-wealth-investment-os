# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.11**  
Foundation compatibility: **0.87**  
Architecture state: **CONSOLIDATION V1 LIVE / M3 COMPLETE / QUALITY HARDENING LIVE / DASHBOARD AUTO REFRESH LIVE**

## Authority model
- **Supabase = System of Record / State**
- **GitHub = System of Logic / Contracts / Tests / Migrations**
- **Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export**

AI may research, interpret, explain and orchestrate within policy. Accounting, hardening, scoring, ranking, allocation, scenario, rebalancing and approval gates are deterministic/system-controlled. Human execution only.

## Decision-and-capital architecture
```text
Source / Evidence / Canonical Facts / Normalized Metrics
                         ↓
                    Valuation
                         ↓
         Market Price + Portfolio State/Fit
                         ↓
           Quality / Durability Hardening
        ┌──────────┬──────────┬──────────┬──────────┐
        │Durability│Owner Earn│Value Trap│Robustness│
        └──────────┴──────────┴──────────┴──────────┘
                         ↓
       Core Score + Revision / Chase Gates
                         ↓
                 Decision Snapshot
                         ↓
               Opportunity Ranking v2
                         ↓
              New-Cash Allocation
                         ↓
          Portfolio Scenario Simulation
                         ↓
           Rebalancing Recommendation
                         ↓
                Approval Packet
                         ↓
               Approval Event
                         ↓
           Separate Human Broker Step
```

Quality Hardening is a promotion boundary. Portfolio Fit and apparent cheapness cannot bypass it.

## Production policy state
| Policy | State |
|---|---|
| Data Scoring v3 Durability | ACTIVE |
| Quality / Durability Hardening v1 | ACTIVE |
| Mispricing | ACTIVE |
| Portfolio Fit | ACTIVE |
| Revision Score v1 | ACTIVE |
| Chase Risk v1 | ACTIVE |
| Opportunity Ranking v2 | ACTIVE |
| New-Cash Allocation v1 | ACTIVE |
| Portfolio Scenario v1 | ACTIVE |
| Rebalance v1 | ACTIVE |
| Human Approval v1 | ACTIVE |

Retired/superseded for production: `POL-DATA-SCORING-V2-NATIVE`, `POL-OPPORTUNITY-RANKING-V1`. Their historical snapshots remain immutable audit lineage.

## Quality / Durability Hardening v1
Database object: `fwios.candidate_quality_hardening_snapshots`.

Current view: `fwios.v_candidate_quality_hardening_current` (`security_invoker=true`). Latest Decision Snapshot view now also exposes `hardening_snapshot_id` without changing historical snapshot rows.

Four gates:
1. `business_durability_gate`
2. `owner_earnings_gate`
3. `value_trap_gate`
4. `valuation_robustness_gate`

Overall gate behavior:
- any FAIL → FAIL;
- all PASS → PASS;
- missing critical evidence → BLOCKED;
- otherwise REVIEW.

Confidence factors:
`PASS=1.0`, `REVIEW=0.7`, `BLOCKED=0.4`, `FAIL=0.0`.

`valuation_confidence = mean(gate factors)`.

### Business durability
Point-in-time growth is not a five-year forecast. Default production promotion requires a >=3-year comparable anchor or an explicitly verified alternative.

### Owner earnings
Material SBC/dilution requires owner-economics reconciliation. V1 thresholds:
- <=10% SBC/revenue: clean narrow pass possible;
- >10%: reconciliation required;
- >20%: hard review;
- >30%: fail.

### Value trap
Base/PW modeled upside >=75% triggers explicit counter-thesis evidence. A depressed long-run share chart may trigger review but never directly changes expected return.

### Valuation robustness
Bear downside worse than 30% is review territory; worse than 50% fails v1. Missing durable-growth anchors can BLOCK robustness even if the numerical bear case appears positive.

## Expected Return v3
Old staircase behavior is retired.

`continuous_upside_score(u) = clamp(50 + 100*u, 0, 100)`

`Expected Return = (0.60 × base score + 0.40 × PW score) × valuation_confidence`.

The core weighting remains exactly 30/30/25/15. Hardening changes confidence/eligibility, not the strategic weights.

## Current Communication Services production state
### PINS
- Hardening: `HARD-PINS-20260906-V1`
- Score: `SCORE-PINS-QH-20260906-V1`
- Decision: `DEC-PINS-QH-20260906-V1`
- Business 82 / Expected Return 40 / Fit 90 / Downside 70
- Core **69.6**
- Hardening **BLOCKED**
- Bucket `WATCHLIST_MODEL_REVIEW`

PINS is no longer capital eligible. The old core 87.6 / Expected Return 100 snapshot remains historical audit evidence only.

### RDDT
- Hardening: `HARD-RDDT-20260906-V1`
- Score: `SCORE-RDDT-QH-20260906-V1`
- Decision: `DEC-RDDT-QH-20260906-V1`
- Expected Return **24.7607** / Core **66.0782**
- Bucket `WATCHLIST_VALUE_WAIT`

## Opportunity Ranking v2
Current run: `OPPRANK-QH-20260906-01`.

Rules:
- Promotion PASS + Hardening PASS → Immediate;
- mispricing insufficient with other gates passing → Value-Wait;
- mispricing PASS but Hardening not PASS → Model-Review;
- no force-fill.

Current Immediate count = **0**.

## Downstream capital boundary
`POL-NEW-CASH-ALLOCATION-V1` still accepts only `IMMEDIATE_BUY_CANDIDATE`.

Verified behavior with THB 50,000 new cash and zero Immediate candidates:
`CASH_THB / HOLD / 50,000 / PASS - HOLD CASH / NO ALLOCATABLE IMMEDIATE CANDIDATE`.

Thus hardening automatically prevents scenario/rebalance capital from flowing to PINS without changing allocation policy.

No auto-trade, broker order, portfolio mutation, recommendation or approval event is created by this path.

## M3 state
M3.1–M3.5 remain COMPLETE / CUTOVER PASS:
- New-Cash Allocation v1: 20/20 PASS
- Portfolio Scenario v1: 28/28 PASS
- Rebalance v1: 12/12 PASS
- Human Approval v1: 30/30 PASS
- Cutover traceability: 9/9 PASS

The historical synthetic NVDA↔PINS scenario remains regression-only and is not a current recommendation. Current ADD eligibility is governed by Ranking v2.

## Dashboard Read Model + Auto Refresh
Monitoring Sheet: **Focused Wealth Dashboard - Chumponphat**  
Sheet ID: `17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8`

Architecture:
```text
Supabase System of Record
        ↓
private dashboard read models
        ↓
dashboard_refresh_payload_v1()
        ↓
dashboard-refresh-csv-v1 Edge Function
        ↓
Google Sheets IMPORTDATA
        ↓
hidden _Data
        ↓
Dashboard
```

After Quality Hardening activation:
- payload gate remains PASS;
- opportunities contain RDDT Value-Wait and PINS Model-Review;
- Current Action = `NO_ACTIONABLE_OPPORTUNITY`;
- portfolio/account KPIs are unchanged;
- Google Sheet remains display-only for production logic.

Dashboard read-model regressions: 17/17 PASS. Auto-refresh regressions: 14/14 PASS.

## Regression proof
Stored Quality-Hardening suite: **20/20 PASS**.
Production downstream verification: **11/11 PASS** including:
- confidence mapping;
- fail-closed overall gate;
- continuous expected-return curve;
- PINS Expected Return 40;
- PINS Model-Review bucket;
- RDDT Value-Wait bucket;
- zero Immediate current production state;
- THB 50k cash hold/no force-fill;
- core weights unchanged.

## Security
`fwios` remains private. New hardening table has RLS enabled and anon/authenticated revoked. Security Advisor reports no new WARN/ERROR; private service-role tables retain expected `rls_enabled_no_policy` INFO notices.

## Architectural invariants
- live reconciled state outranks stale docs;
- missing/stale/unverified hardening inputs fail closed;
- apparent DCF upside cannot bypass durability/owner-economics review;
- historical return cannot substitute expected return;
- no AI-invented numeric gate evidence;
- no force-fill;
- new cash precedes trim;
- recommendation/approval snapshots remain immutable;
- approval never places orders or mutates holdings;
- Account View never changes consolidated decision context;
- Dashboard contains no production policy logic;
- human execution only.

## Next architecture action
**Collect Quality-Hardening Evidence and revalidate Communication Services before resuming Financials or legacy reduction.**

See `policies/quality/QUALITY_HARDENING_V1.md` and `tests/decision/test_quality_durability_hardening_v1.sql`.
