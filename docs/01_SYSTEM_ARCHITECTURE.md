# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.11**  
Foundation compatibility: **0.87**  
Architecture state: **CONSOLIDATION V1 LIVE / M3 COMPLETE / QUALITY FILTER REVALIDATED / LEGACY SURFACE REDUCED / DASHBOARD AUTO REFRESH LIVE**

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

Quality Hardening is a promotion boundary. Business quality, valuation attractiveness and model availability are separate dimensions.

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

Retired/superseded for production: `POL-DATA-SCORING-V2-NATIVE`, `POL-OPPORTUNITY-RANKING-V1`. Historical snapshots remain immutable audit lineage.

## Quality / Durability Hardening v1
Database object: `fwios.candidate_quality_hardening_snapshots`.

Current view: `fwios.v_candidate_quality_hardening_current` (`security_invoker=true`). Latest Decision Snapshot view exposes `hardening_snapshot_id` without mutating historical rows.

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

Confidence factors: `PASS=1.0`, `REVIEW=0.7`, `BLOCKED=0.4`, `FAIL=0.0`.
`valuation_confidence = mean(gate factors)`.

### Business durability
Point-in-time growth is not a five-year forecast. Default promotion anchor is >=3 years of comparable evidence. An explicitly verified alternative anchor is allowed when the business does not yet have a full three-year public history but durable operating performance is directly evidenced; the AI cannot invent such an alternative.

### Owner earnings
Material SBC/dilution requires owner-economics reconciliation. V1 thresholds remain <=10% clean narrow pass possible, >10% reconciliation required, >20% hard review, >30% fail.

### Value trap
Base/PW modeled upside >=75% triggers explicit counter-thesis evidence. A depressed share chart may trigger review but never directly changes expected return.

### Valuation robustness
Bear downside worse than 30% is review territory; worse than 50% fails v1.

## Communication Services quality-filter acceptance — 8/8 PASS
The acceptance target is not “make a candidate pass.” The target is to correctly separate:
- a quality business from an attractive valuation;
- a durable business with unresolved owner economics from an Immediate candidate;
- missing valuation-model coverage from low business quality;
- high model upside from verified buy eligibility.

### PINS — durable business, unresolved economics/valuation confidence
Current lineage:
- `HARD-PINS-20260906-V2`
- `SCORE-PINS-QH-20260906-V2`
- `DEC-PINS-QH-20260906-V2`

State:
- Business 82
- Durability PASS
- Owner Earnings REVIEW
- Value Trap REVIEW
- Robustness REVIEW
- Confidence 0.775
- Expected Return 77.5000
- Core 80.8500
- Bucket `WATCHLIST_MODEL_REVIEW`

The new evidence includes FY2022–FY2025 comparable revenue history, sustained user-growth evidence, H1 2026 SBC/FCF, share-count change and buyback economics. PINS is therefore no longer blocked for missing durability evidence, but extreme DCF upside is still not enough for Immediate promotion.

### RDDT — high-quality business, valuation not attractive
Current lineage:
- `HARD-RDDT-20260906-V2`
- `SCORE-RDDT-QH-20260906-V2`
- `DEC-RDDT-QH-20260906-V2`

State:
- Business 88
- Durability PASS via explicitly verified 8-quarter alternative anchor
- Owner Earnings PASS
- Value Trap PASS
- Robustness REVIEW
- Confidence 0.925
- Expected Return 41.6431
- Core 71.1429
- Bucket `WATCHLIST_VALUE_WAIT`
- Mispricing `FAIL - INSUFFICIENT MISPRICING`

The system now explicitly says “good company, wait for value” instead of confusing quality with buy eligibility.

### NFLX — quality/model-availability separation
Current research state:
- Business / Quality 94
- Evidence PASS
- Valuation `BLOCKED - MODEL NOT IMPLEMENTED`

This is an acceptance anchor: lack of a Streaming/Media valuation model blocks promotion/valuation but does not downgrade NFLX business quality.

## Expected Return v3
`continuous_upside_score(u) = clamp(50 + 100*u, 0, 100)`

`Expected Return = (0.60 × base score + 0.40 × PW score) × valuation_confidence`.

The core weighting remains exactly 30/30/25/15. Hardening changes confidence/eligibility, not strategic weights.

## Opportunity Ranking v2
Current run: `OPPRANK-QH-REVAL-20260906-02`.

Rules:
- Promotion PASS + Hardening PASS → Immediate;
- mispricing insufficient with other gates passing → Value-Wait;
- mispricing PASS but Hardening not PASS → Model-Review;
- no force-fill.

Current Immediate count = **0**.

## Downstream capital boundary
`POL-NEW-CASH-ALLOCATION-V1` accepts only `IMMEDIATE_BUY_CANDIDATE`.

Verified THB 50,000 behavior:
`CASH_THB / HOLD / 50,000 / PASS - HOLD CASH / NO ALLOCATABLE IMMEDIATE CANDIDATE`.

No auto-trade, broker order, portfolio mutation, recommendation or approval event is created by this path.

## M3 state
M3.1–M3.5 remain COMPLETE / CUTOVER PASS:
- New-Cash Allocation v1: 20/20 PASS
- Portfolio Scenario v1: 28/28 PASS
- Rebalance v1: 12/12 PASS
- Human Approval v1: 30/30 PASS
- Cutover traceability: 9/9 PASS

The historical synthetic NVDA↔PINS scenario remains regression-only and is not a current recommendation.

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

Current Action remains `NO_ACTIONABLE_OPPORTUNITY`. Dashboard read-model regressions remain 17/17 PASS; auto-refresh regressions remain 14/14 PASS.

## Legacy Google Sheets reduction
Legacy screener: `US_Stock_Sector_Business_Model_Screener`.

It is retained as a compatibility/reconciliation/audit/research surface, not production authority. No data was deleted.

Visible tabs are now reduced from 15 to **6**:
- `Sector_Scan`
- `Sector_Run_Control`
- `Thesis Monitor`
- `System_Foundation`
- `Evidence_Ledger`
- `Data_Quality_Gates`

Duplicate production/config surfaces are hidden. Existing formulas and historical evidence remain available behind the reduced surface. The separate Focused Wealth Dashboard remains the primary monitoring surface.

## Regression proof
- Base Quality-Hardening suite: **20/20 PASS**
- Production downstream verification: **11/11 PASS**
- Communication Services quality-filter acceptance: **8/8 PASS**

Acceptance coverage includes PINS durability/owner nuance, RDDT durability/owner quality, RDDT Value-Wait separation, PINS Model-Review separation, NFLX quality/model separation and zero-Immediate no-force-fill behavior.

## Security
`fwios` remains private. Hardening tables retain RLS and private service-role access pattern. No client-side production authority is introduced by legacy reduction.

## Architectural invariants
- live reconciled state outranks stale docs;
- missing/stale/unverified critical hardening inputs fail closed;
- apparent DCF upside cannot bypass durability/owner-economics review;
- business quality does not equal valuation attractiveness;
- missing valuation model does not imply low business quality;
- historical return cannot substitute expected return;
- no AI-invented numeric gate evidence;
- no force-fill;
- new cash precedes trim;
- recommendation/approval snapshots remain immutable;
- approval never places orders or mutates holdings;
- Dashboard contains no production policy logic;
- human execution only.

## Next architecture action
**HOLD. Part 1 Quality Revalidation and Part 2 Legacy Reduction are complete. Financials remains queued and PAUSED until an explicit user instruction resumes Part 3.**
