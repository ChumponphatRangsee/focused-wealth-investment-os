# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.14**  
Foundation compatibility: **0.87**  
Architecture state: **CONSOLIDATION V1 LIVE / M3 COMPLETE / QUALITY FILTER REVALIDATED / FINANCIALS RESEARCH COMPLETE / MODEL DEBT FAIL-CLOSED / DASHBOARD AUTO REFRESH LIVE**

## Authority model
- **Supabase = System of Record / State**
- **GitHub = System of Logic / Contracts / Tests / Migrations**
- **Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export**

AI may research, interpret, explain and orchestrate within policy. Accounting, hardening, scoring, ranking, allocation, scenario, rebalancing and approval gates are deterministic/system-controlled. Human execution only.

## Core Architecture Redesign v1.0 — MIGRATION ACTIVE / PHASE #34 METRICS LIVE

Epic **#31** is now in migration. Research Lifecycle v1 is active as a deterministic contract/kernel, while the current production architecture below remains authoritative for research/decision reads until later phases are implemented, regression-tested and explicitly cut over.

### Target operating loop

```text
External Data / Providers
          ↓
Universal Discovery Layer
          ↓
Opportunity + Attention Layer
          ↓
Selective Research Layer
          ↓
Persistent Thesis / Decision Memory
          ↓
Deterministic Decision Engine
          ↓
Portfolio Context / Capital Allocation
```

### Research-depth principle
Compute, storage and monitoring depth follow capital relevance:

`UNIVERSE → SCREENED → WATCH → RESEARCH_CANDIDATE → FULL_THESIS → PORTFOLIO`

with side states `REJECTED` and `ARCHIVED`.

Full Thesis is not the default state for broad-market coverage. S&P 500 and larger universes are discovery universes; only qualified names receive deep evidence, valuation, Thesis Memory, Revision/Chase and continuous monitoring.

### Model-coverage principle
Sector is classification, not a requirement to build a full model for every sector. Valuation/research models are reusable **archetype packs** built when qualified candidate or portfolio demand justifies them. Unsupported archetypes remain fail-closed for deep decision use.

### Ownership boundary
FWIOS may rent external financial/market data, but must own:
- canonical instrument identity;
- decision-relevant metric observations;
- evidence → metric → decision lineage;
- thesis conditions and decision memory;
- portfolio context;
- immutable decision snapshots and approvals.

### Planned migration
`#32 → #33 → #34 → #35/#36 → #37 → #38 → #39`.

Phase #32 does not cut production reads over to lifecycle storage. Later phases must explicitly prove parity before becoming authoritative.

## Canonical Instrument Identity v1

Policy: `POL-INSTRUMENT-IDENTITY-V1`.

Canonical identity is now additive and live beneath existing symbol-based interfaces:

```text
Asset Entity
    ↓ 1:N
Instrument (immutable instrument_id)
    ↓ 1:N historical labels
Instrument Symbol / Venue / Namespace
    ↓
Legacy ticker / asset_symbol compatibility
```

Current live seed:
- 70 instruments total;
- 64 Stock;
- 6 Crypto;
- 70 current primary symbol rows;
- 70 migration provenance identifiers.

Selected anchor tables now carry nullable/backfilled `instrument_id`:
`companies`, `research_candidates`, `thesis_registry`, `portfolio_assets`, `portfolio_transactions`, `market_daily_closes`, `market_price_quotes`, `market_price_snapshots`.

Rules:
- ticker change retains the same instrument only when the legal/tradable instrument is unchanged;
- share classes and separately tradable exchange listings use distinct instrument IDs and may share one entity;
- delisting retains history rather than rewriting identity;
- crypto symbols are not globally unique and require namespace/durable identifier semantics;
- ambiguous resolution returns NULL rather than guessing;
- legacy ticker/asset-symbol columns are not removed in #33;
- production decision and dashboard read paths remain unchanged.

Identity regressions: **20/20 PASS**.

## Metric Observation Model v2

Policy: `POL-METRIC-OBSERVATION-V2`.

Metric v2 separates semantic metric identity from period identity:

```text
Instrument
   ↓
Metric Definition
   ↓
Metric Observation
   ├─ typed canonical value
   ├─ observation layer
   ├─ fiscal / period identity
   ├─ as-of / reported / effective time
   ├─ raw source value + unit
   └─ evidence / source-observation handles
```

Current live acceptance state:
- 130 metric definitions;
- 449 observations;
- all 233 current `company_metrics` rows represented;
- all 210 current `normalized_metrics` rows represented;
- ADBE recurring growth Q2/Q3 stored under `RECURRING_REVENUE_GROWTH_YOY`;
- PINS Q1/Q2 MAU and revenue-growth series stored by period;
- PINS Q2 2025 / Q2 2026 FCF stored under `FREE_CASH_FLOW`;
- PINS ARPU/SBC baselines carry explicit period semantics;
- canonical numeric observations no longer require runtime text casts.

Canonical unit examples:
- PCT/percent → ratio;
- USD M → USD B;
- B shares → M shares.

The model intentionally does not mirror complete statements. Only decision-relevant metrics are promoted.

`metric_legacy_mappings` preserves compatibility with current metric IDs. Existing valuation/Revision consumers still read legacy tables until later explicit cutover.

Full evidence/derivation graph normalization belongs to Issue #35.

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

Business quality, valuation attractiveness, model readiness and portfolio fit are separate dimensions. Missing model infrastructure blocks production Expected Return; it does not lower business-quality classification.

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
| Research Lifecycle v1 | ACTIVE CONTRACT / NO READ CUTOVER |
| Instrument Identity v1 | ACTIVE FOUNDATION / LEGACY READS PRESERVED |
| Metric Observation Model v2 | ACTIVE FOUNDATION / TYPED PERIOD-AWARE / NO READ CUTOVER |

Retired/superseded for production: `POL-DATA-SCORING-V2-NATIVE`, `POL-OPPORTUNITY-RANKING-V1`. Historical snapshots remain immutable audit lineage.

## Quality / Durability Hardening v1
Database object: `fwios.candidate_quality_hardening_snapshots`.

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

Point-in-time growth cannot become a multi-year forecast without a verified durability anchor. Material SBC/dilution requires owner-economics reconciliation. Extreme modeled mispricing requires counter-thesis evidence. Conservative downside must be tested before promotion.

## Communication Services acceptance — 8/8 PASS
Current production lineage remains:
- PINS: Business 82 / Expected Return 77.5 / Core 80.85 / Hardening REVIEW / `WATCHLIST_MODEL_REVIEW`.
- RDDT: Business 88 / Expected Return 41.6431 / Core 71.1429 / `WATCHLIST_VALUE_WAIT`.
- NFLX: Business / Quality 94 / Evidence PASS / valuation model unavailable.

This proves business quality is not equivalent to buy eligibility or model availability.

## Financials research architecture — COMPLETE / FAIL-CLOSED
Run: `SECTOR-FIN-FULL-20260906-01`.

Research controller:
```text
20-name Financials universe
        ↓ Fast Discovery
8 names
        ↓ Light Research
5-name focused shortlist
[JPM, V, CB, SPGI, BLK]
        ↓ Top-3-first Deep Research
[JPM, V, CB]
        ↓ Tier-A Evidence Gate
27 verified Tier-A rows / 3 candidates PASS
        ↓
Financials Valuation Router
        ↓
0 production-ready models for these archetypes
        ↓
BLOCKED — Expected Return remains NULL
        ↓
0 Immediate candidates
```

Deep Research quality state:
- JPM — Business / Quality 96; 9 Tier-A rows.
- V — Business / Quality 96; 9 Tier-A rows.
- CB — Business / Quality 94; 9 Tier-A rows.

SPGI and BLK remain Light-Research shortlist names. Research budget did not force deep research across all five archetypes.

### Model-debt boundary
Canonical root blockers:
- `BLK-FIN-PAYNET-MDL-001` — Payment Network / HIGH
- `BLK-FIN-BANK-MDL-001` — Commercial / Universal Bank / HIGH
- `BLK-FIN-INS-MDL-001` — Insurance / HIGH
- `BLK-FIN-DATA-MDL-001` — Exchange / Index / Ratings / Data / MEDIUM
- `BLK-FIN-ASSET-MDL-001` — Asset Manager / MEDIUM

Payment Network already has criteria contract `PAYMENT_NETWORK_FCF_DCF_V1`, but no registered production implementation/version exists. The other four routes require archetype-correct model definition and implementation.

Architectural invariant: **rough P/E, P/B or P/FCF used in Fast/Light Research can never populate production fair value, Expected Return, Mispricing, Decision Snapshot or Opportunity Ranking.**

Therefore Financials is allowed to say:
- JPM / V / CB are high-quality businesses;
- valuation is unavailable;
- production Expected Return is null;
- no candidate is Immediate.

It is not allowed to infer a buy signal from quality score + rough multiple.

### Focused portfolio-fit behavior
Current portfolio has no Financials exposure, but zero exposure is only a fit input. It cannot create a candidate by itself.

MA was deferred despite elite quality because it materially overlaps Visa and lacked a clear marginal advantage at the rough-triage stage. FISV was rejected on weak current quality/growth rather than rescued by a cheaper-looking valuation. This confirms no diversification force-fill.

### Financials regression proof
`REG-FIN-QF-01` through `REG-FIN-QF-08`: **8/8 PASS**.

Coverage:
- run COMPLETE;
- focused 20→5→3 funnel;
- JPM/V/CB high-quality despite model block;
- Expected Return stays null;
- five canonical model blockers exist;
- zero valuation-ready / zero Immediate.

Reproducible SQL: `tests/decision/test_financials_quality_filter_acceptance_v1.sql`.
Run manifest: `docs/runs/20260906_financials_sector_run.md`.

## Expected Return v3
`continuous_upside_score(u) = clamp(50 + 100*u, 0, 100)`

`Expected Return = (0.60 × base score + 0.40 × PW score) × valuation_confidence`.

The core weighting remains exactly 30/30/25/15. If a valid intrinsic valuation does not exist, Expected Return must remain blocked/null rather than using a rough multiple proxy.

## Opportunity Ranking v2
Current production run remains `OPPRANK-QH-REVAL-20260906-02`.

Financials does not enter Ranking v2 yet because its valuation-ready count is zero.

Rules remain:
- Promotion PASS + Hardening PASS → Immediate;
- mispricing insufficient with required gates passing → Value-Wait;
- mispricing PASS but Hardening not PASS → Model-Review;
- no force-fill.

Current production Immediate count = **0**.

## Downstream capital boundary
`POL-NEW-CASH-ALLOCATION-V1` accepts only `IMMEDIATE_BUY_CANDIDATE`.

Financials research created no allocation run, scenario run, rebalancing recommendation, approval event, broker order or portfolio mutation.

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

Architecture remains:
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

Current Action remains `NO_ACTIONABLE_OPPORTUNITY`. Financials research/model debt belongs to controller/system-health surfaces, not the capital-opportunity table until valuation-ready.

Dashboard read-model regressions remain 17/17 PASS; auto-refresh regressions remain 14/14 PASS.

## Legacy Google Sheets reduction
Legacy screener remains compatibility/reconciliation/audit/research, not production authority.

Visible operational tabs remain six:
- `Sector_Scan`
- `Sector_Run_Control`
- `Thesis Monitor`
- `System_Foundation`
- `Evidence_Ledger`
- `Data_Quality_Gates`

Financials current shortlist, model debt and controller state are synchronized into these legacy surfaces. No historical data was deleted.

The `Autonomous Sector Documentation Gate` was corrected to treat any `System_Foundation` status beginning with `PHASE 0.87 OPERATIONAL` as operational while still requiring documentation-handshake PASS and run-lock IDLE. This fixes exact-string drift without weakening the gate.

## Regression proof
- Base Quality-Hardening suite: **20/20 PASS**
- Production downstream verification: **11/11 PASS**
- Communication Services quality-filter acceptance: **8/8 PASS**
- Financials quality-filter acceptance: **8/8 PASS**

## Security
`fwios` remains private. No client-side production authority is introduced by Financials research or legacy-sheet synchronization.

## Architectural invariants
- live reconciled state outranks stale docs;
- business quality does not equal valuation attractiveness;
- missing model infrastructure does not imply low business quality;
- missing production valuation keeps Expected Return null/blocked;
- rough multiples are triage only;
- historical return cannot substitute expected return;
- no AI-invented valuation assumptions merely to make a candidate pass;
- no diversification force-fill;
- no ranking/allocation force-fill;
- recommendation/approval snapshots remain immutable;
- approval never places orders or mutates holdings;
- Dashboard contains no production policy logic;
- human execution only.

## Controller state
- Current / last completed sector: Financials
- Current stage: DONE
- Run lock: IDLE
- Next queued sector: Industrials
- Automation: PAUSED
- Pause reason: `FINANCIALS_MODEL_DEBT_REVIEW`
- Auto-resume: false

## Next architecture action
**Issue #35 — Evidence → Metric → Decision Lineage Graph.**

Metric Observation Model v2 is complete at the migration-foundation layer:
- 130 definitions / 449 observations at acceptance;
- 233/233 company metric compatibility rows;
- 210/210 normalized metric compatibility rows;
- typed-value invariant PASS;
- period-aware ADBE/PINS history PASS;
- normalized observations retain evidence/source-observation handles;
- 15/15 metric regressions PASS;
- ADBE/PINS valuation and Revision outputs remained unchanged;
- portfolio accounting remained unchanged.

Issue #35 should convert transitional arrays/handles into explicit graph edges from source evidence through observations/derivations to decision snapshots. Issue #36 Market Observation may proceed in parallel.

## 2026-09-11 architecture delta — Auto Decision Refresh v1 Shadow

Routine Decision Refresh initiation now has a Supabase-native shadow control plane:

```text
pg_cron
   ↓
start_decision_refresh_shadow()
   ↓
PGMQ
   ↓
decision-refresh-worker-v1
   ├─ SEC submissions + compact XBRL Company Facts — READY
   ├─ Twelve Data price — DORMANT / NOT APPROVED
   └─ Alpha Vantage price + consensus — DORMANT / NOT APPROVED
   ↓
decision_refresh_shadow_evidence
   ↓
validation only; no production decision writes
```

New private runtime objects:
- `fwios.decision_refresh_provider_registry`
- `fwios.decision_refresh_runs`
- `fwios.decision_refresh_jobs`
- `fwios.decision_refresh_shadow_evidence`
- `fwios.decision_refresh_automation_access`

Core invariants:
- SHADOW runs are database-constrained to `authoritative_write=false`;
- provider use requires secret + `active=true` + `readiness_status='READY'` + Tier A;
- external provider secrets can be resolved from Edge Function env or Supabase Vault and are never stored in GitHub;
- market-price crosscheck requires a common completed session and <=0.5% divergence;
- deterministic missing-provider states are BLOCKED rather than retried;
- transient failures can RETRY and then DEAD_LETTER through PGMQ;
- sector automation remains logically separate and is not auto-resumed by Decision Refresh infrastructure;
- no production Decision Snapshot, Opportunity Ranking, allocation, rebalancing, approval or portfolio mutation occurs in Shadow mode;
- human execution only remains unchanged.

Live acceptance evidence: 27 candidates / 81 jobs → SEC 27 PASS, provider-gated 54 BLOCKED, 0 retry, 0 dead-letter after queue-ack correction. Worker v3+ ADBE SEC/XBRL smoke collected 30 recent relevant filing records plus 11 compact Company Facts tags. Automation infrastructure regression is 11/11 PASS.

See `docs/08_AUTO_DECISION_REFRESH_SHADOW.md`. Live Supabase state remains authoritative over older point-in-time sector/ranking snapshots in this document.
