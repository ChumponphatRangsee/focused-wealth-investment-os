# Focused Wealth Investment OS — Master System Roadmap

> **Roadmap with dated operational snapshots, not live controller authority.** Market, portfolio, phase and queue counts inside this document describe the verification dates recorded there. Start from [CURRENT_STATUS.md](CURRENT_STATUS.md), the merged contract and current Supabase/Sheet readback before selecting a task.

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract (GitHub docs review): **FWIOS-CONTRACT-0.87.19**  
Last delivery-priority review: **2026-10-26 Asia/Bangkok** (September operational snapshots and 2026-10-23 strategy overlay retained as historical/proposed)  
Execution mode: **HUMAN EXECUTION ONLY**

## Authority model
Supabase = System of Record / State. GitHub = Logic / Contracts / Tests / Migrations. Google Sheets = View / Compatibility / Reconciliation / Audit / Export. Live state overrides stale docs.

## 2026-10-26 owner decision — MVP FIRST / active delivery priority

**Approved now: simplify the roadmap and audit the existing end-to-end workflow. NOT authorized by this documentation PR: production schema changes, production research APPLY, changes to scoring/gates, market-data cutover, portfolio writes, cron/tasks, or trading.**

**Immediate priority: Phase 1 — Working MVP**, using the existing `Data → Research → Valuation → Decision/Readiness → Read-only Report` path for 1–3 stock examples. See the [MVP-first working-slice plan and live audit](implementation/FWIOS_MVP_FIRST_WORKING_SLICE_20261026.md) for the acceptance checklist and observed blockers.

| Delivery phase | Priority / scope | Gate before advancing |
| --- | --- | --- |
| **1 — Working MVP (NOW)** | Reuse existing Supabase read models and current scanner/report surface. Show verified price, source/model-backed Fair Value, quality, readiness, blockers and timestamps on ACN/ADBE/PINS. Fix only reproduced E2E mismatches; manual PREVIEW by default. | One trustworthy human-readable, fail-closed report with positive and negative test cases; no new tables or workers. |
| **2 — Basic automation (LATER)** | Reuse existing EOD price data and a limited alert/report refresh only when manual workflow succeeds and quota/permissions are proven. | Manual acceptance, reliability and quota budgets verified; separate authorization. |
| **3 — Research selection/attention (DEFERRED)** | Issue #38 policy/priority/work queue and any new Research Attention schema only after observed volume/cost justifies it. | Measured need, minimal design, regression, separate authorization. |
| **4 — Rotation/backtesting (FUTURE)** | Portfolio advisory and point-in-time evaluation, with #39 compatibility cutover only after approved parity. | Tested data/decision path, portfolio accounting boundary preserved. |

**Do not mistake scanner ranking for investment eligibility:** live read-only checks on 2026-10-26 found 64 instruments, 27 research/valuation-ready and only 1 investment-review-ready. Scanner v1 currently scores 27 and must not be presented as BUY eligibility. ACN is the positive readiness regression; ADBE and PINS expose real blocked paths.

The older Epic #31 migration sequence and D0–D6 strategy tracks below are **future architecture/backlog references**, not the next execution sequence. No big-bang rewrite; retain all existing contracts and safety gates.

## Historical system snapshot — September 2026 (not a live-state readback)

The table below preserves the originally recorded operational snapshot, including the **0.87.17 contract at that snapshot date**. For current decisions, use the active **0.87.19** contract, [CURRENT_STATUS.md](CURRENT_STATUS.md), live runtime verification, and the latest merged PR state. A documentation review is not a production validation.
| Item | State recorded in historical snapshot |
|---|---|
| Foundation | 0.87 |
| Research Lifecycle v1 | **ACTIVE CONTRACT / NO READ CUTOVER / 17/17 PASS** |
| Canonical Instrument Identity v1 | **ACTIVE FOUNDATION / 70 INSTRUMENTS / 20/20 PASS / LEGACY READS PRESERVED** |
| Metric Observation Model v2 | **ACTIVE FOUNDATION / 130 DEFINITIONS / 449 OBSERVATIONS / 15/15 PASS / NO READ CUTOVER** |
| Evidence → Metric → Decision Lineage v1 | **ACTIVE FOUNDATION / 1,156 ARTIFACTS / 1,423 EDGES / 16/16 PASS / APPEND-ONLY / NO READ CUTOVER** |
| Unified Market Observation v1 | **ACTIVE FOUNDATION / 4,489 OBSERVATIONS / 340 VERIFICATION SETS / 14/14 PASS / DUAL-WRITE / NO READ CUTOVER** |
| Thesis Memory + Reactivation v1 | **ACTIVE FOUNDATION / 6 COMPLETE BASELINES / 73 CONDITIONS / 37 KPI BINDINGS / 8 METRIC LINKS / 15/15 PASS / NO READ CUTOVER** |
| Contract | FWIOS-CONTRACT-0.87.17 |
| Portfolio batch | PORTFOLIO-M2-20260905-01 |
| Portfolio review flags | 10 assets / NVDA ~41.25% / crypto ~38.09% |
| M3.1–M3.5 | **COMPLETE / CUTOVER PASS** |
| Quality / Durability Hardening v1 | **PASS / LIVE** |
| Communication Services quality-filter acceptance | **8/8 PASS** |
| Financials quality-filter acceptance | **8/8 PASS** |
| Data Scoring | **V3 DURABILITY ACTIVE** |
| Opportunity Ranking | **V2 ACTIVE** |
| Current production Immediate candidates | **0** |
| PINS | **WATCHLIST_MODEL_REVIEW — core 80.85 / confidence 0.775** |
| RDDT | **WATCHLIST_VALUE_WAIT — core 71.1429 / confidence 0.925** |
| Financials research | **COMPLETE — 20→8→5→3 / 27 Tier-A verified** |
| Financials valuation-ready | **0** |
| Financials Immediate | **0** |
| Financials top quality | **JPM 96 / V 96 / CB 94** |
| Financials model blockers | **5 canonical archetype blockers** |
| Legacy Screener surface | **6 visible tabs / no data deleted** |
| Sector automation | **PAUSED — FINANCIALS_MODEL_DEBT_REVIEW** |
| Next queued sector | Industrials |
| Immediate next action (superseded by 2026-10-26 MVP-first decision) | **Phase 1 MVP read-only report + E2E blocker repair** |

## Core Architecture Redesign v1.0 — MIGRATION ACTIVE / PHASE #37 COMPLETE

Epic: **#31 — Migrate FWIOS to Attention → Research → Thesis → Decision → Portfolio architecture**.

### Product boundary
FWIOS is not intended to become a full-market financial-data warehouse or maintain a Full Thesis for every S&P 500 company.

Target allocation of research depth:
- **UNIVERSE** — broad, cheap, shallow discovery;
- **SCREENED / WATCH** — selective signals and limited monitoring;
- **RESEARCH_CANDIDATE** — deeper evidence/model work;
- **FULL_THESIS** — scarce, high-conviction research state;
- **PORTFOLIO** — deepest continuous monitoring;
- **REJECTED / ARCHIVED** — retain decision memory and reactivation conditions without continuous deep research.

Target loop:

```text
External Data
    ↓
Universe / Screening
    ↓
Opportunity + Attention Allocation
    ↓
Selective Research
    ↓
Thesis Memory
    ↓
Decision Engine
    ↓
Portfolio Engine
```

### Migration sequence
1. **#32 COMPLETE** Research Lifecycle + Architecture Contract — `POL-RESEARCH-LIFECYCLE-V1`, 17/17 PASS, no production read cutover
2. **#33 COMPLETE** Canonical Instrument Identity v1 — `POL-INSTRUMENT-IDENTITY-V1`, 70 instruments, 20/20 PASS, legacy symbol reads preserved
3. **#34 COMPLETE** Decision-Relevant Metric Observation Model v2 — typed period-aware observations, 15/15 PASS, no production read cutover
4. **#35 COMPLETE** Evidence → Metric → Decision Lineage — append-only graph, 1,156 artifacts / 1,423 edges, 16/16 PASS, no read cutover
5. **#36 COMPLETE** Unified Market Observation Layer — canonical provider/session-aware observations, dual-write compatibility, 14/14 PASS, no read cutover
6. **#37 COMPLETE** Thesis Memory + Reactivation Rules — 6 complete baselines normalized, 73 conditions / 37 KPI bindings / 8 metric links, 15/15 PASS, no read cutover
7. **#38 DEFERRED — future backlog** Research Attention + Promotion/Demotion Engine (retains its original dependency order; not the immediate MVP priority)
8. **#39** Compatibility Cutover / Index / Retention / Legacy Cleanup

#35 and #36 may proceed in parallel after their foundations are stable.

### Migration invariants
- no big-bang rewrite;
- existing production path stays authoritative until explicit cutover;
- ADBE/PINS, portfolio state and existing deterministic gates must not change solely because of schema migration;
- broad universe coverage must not imply full-model/full-thesis coverage;
- archetype models are created/reused on demand;
- no force-fill and no auto-trading;
- compatibility views remain until downstream consumers migrate.

## 2026-10-23 Strategy overlay — Value + Entry Timing + Portfolio Rotation (PROPOSED ONLY)

**Status: DOCUMENTATION / ANALYSIS ONLY — NOT IMPLEMENTED OR PRODUCTION APPROVED.** See [Value, Entry & Rotation Strategy Roadmap](implementation/VALUE_ENTRY_ROTATION_STRATEGY_ROADMAP_20261023.md) for the complete proposal, dependency chain, acceptance criteria and open decisions.

### Investment objective

Focus on verified **intrinsic-value discounts**, defensible entry conditions, and disciplined **hold/add/trim/exit/rotate/cash** comparisons. A fair-value estimate is not a guaranteed market price within a trading horizon. Optimizing for expected after-cost, risk-adjusted capital allocation matters more than mechanical profit-taking.

### Reuse before building

- Keep Redesign [Epic #31](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/31) as the future operating loop; [Issue #38](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/38) attention design is now **deferred** while Phase 1 proves manual, read-only research/valuation/report usage. No new research scheduling is authorized. [Issue #39](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/39) remains gated on proven compatibility parity.
- Reuse existing evidence, controlled ChatGPT ingestion, typed metrics, thesis memory, valuation models, hardening/scoring, market-data observations, Decision Snapshot, opportunity ranking, portfolio scenario, rebalancing and human approval.
- Do not introduce parallel AI-generated production scores, unconstrained price targets, a duplicate trading ledger, or high-frequency deep research across the S&P 500.
- Preserve current 30/30/25/15 production core score, valuation/quality hard gates, human execution only, and timing as a bounded non-core modifier. Any replacement thresholds require an explicitly reviewed policy version.
- Keep U1 S&P 500 membership expansion paused unless the owner reactivates it separately; the current instrument subset must not be described as full-index coverage.
- Existing Research Workflow defaults to PREVIEW. A future automatic research-to-database APPLY pipeline requires separate explicit authority, controlled gateway permissions and audit acceptance; **no ChatGPT Task, Supabase Cron, schema change, trade or portfolio write is authorized by this roadmap update**.

### Historical 2026-10-23 D0–D6 strategy proposal (superseded for near-term delivery by MVP-first)

| Planning track | Scope | Major dependency |
| --- | --- | --- |
| **D0 — Roadmap / feature gap analysis** | Reconcile current production policies and feature inventory; document constraints and evaluation criteria | This documentation review |
| **D1 — Research attention design** | Priority queue, lifecycle promotion/demotion, resource budget and refresh policy | Existing Redesign #38 |
| **D2 — Institutional research / valuation** | Canonical sourced financial facts, valuation sensitivity/confidence, selective archetype coverage | D1 + controlled ingest/readiness |
| **D3 — Entry and opportunity comparison** | Risk-aware entry timing, fair-value discount context and deterministic reason codes | D2 + canonical market observations |
| **D4 — Portfolio rotation advisory** | Compare retain/add/trim/exit/rotate/cash, costs, portfolio impact and human approval | D3 + reconciled holdings |
| **D5 — Strategy evaluation and shadow cadence** | Point-in-time backtest, benchmark, walk-forward, paper/shadow evaluation and scheduling governance | D1–D4; no cutover |
| **D6 — Separate production authorization** | Versioned requirements, phased release plan and rollback (only if validated and approved) | Explicit owner approval and #39 parity where relevant |

**Current delivery priority is the Phase 1 MVP**, not Issue #38 or an all-new Scanner v2. The D0–D6 table above remains historical proposal/backlog context. Scanner v2 and U1 full-universe expansion are separately deferred; consult [CURRENT_STATUS.md](CURRENT_STATUS.md).

## M1 — Research Pipeline v2
**CORE HARDENING PASS / PERFORMANCE VALIDATION OPEN.** Research/model coverage debt remains fail-closed for affected names.

Research budgets remain focused:
- max universe per sector: 20;
- max sector shortlist: 5;
- deep research top-3-first when enough high-quality candidates exist;
- no category quota / no diversification force-fill.

## M2/M3 historical boundary
M2 and M3 cutover remain valid historical system milestones. M3.1–M3.5 remain LIVE with human execution only.

Historical snapshots remain immutable audit history. New evidence creates new hardening/score/Decision Snapshots rather than overwriting prior conclusions.

## Part 1 — Communication Services Quality Revalidation — COMPLETE
Acceptance: **8/8 PASS**.

Current state:
- PINS: Durability PASS; Owner Earnings / Value Trap / Robustness REVIEW; confidence .775; Expected Return 77.5; Core 80.85; `WATCHLIST_MODEL_REVIEW`.
- RDDT: Durability / Owner Earnings / Value Trap PASS; Robustness REVIEW; confidence .925; Expected Return 41.6431; Core 71.1429; `WATCHLIST_VALUE_WAIT`.
- NFLX: Business / Quality 94, Evidence PASS, valuation model unavailable — proves quality classification is separate from model availability.

Current production Immediate count remains 0. New cash remains HOLD when nothing clears all gates.

## Part 2 — Legacy Reduction — COMPLETE
`US_Stock_Sector_Business_Model_Screener` remains a research/audit/compatibility surface rather than production authority.

Visible operational tabs remain six:
1. `Sector_Scan`
2. `Sector_Run_Control`
3. `Thesis Monitor`
4. `System_Foundation`
5. `Evidence_Ledger`
6. `Data_Quality_Gates`

No data was deleted. The separate **Focused Wealth Dashboard - Chumponphat** remains primary monitoring.

## Part 3 — Financials Sector Loop — RESEARCH COMPLETE / PRODUCTION FAIL-CLOSED
Run: `SECTOR-FIN-FULL-20260906-01`.

### Funnel
`20 universe → 8 Fast Discovery → 5 Light shortlist → 3 Deep Research`.

Shortlist:
1. JPM
2. V
3. CB
4. SPGI
5. BLK

Deep Research:
- JPM — Business / Quality 96; 9 Tier-A verified evidence rows.
- V — Business / Quality 96; 9 Tier-A verified evidence rows.
- CB — Business / Quality 94; 9 Tier-A verified evidence rows.

Total: **27 Tier-A verified evidence rows**.

### Quality-filter behavior
The filter passed its Financials acceptance suite **8/8**:
- high business quality survives missing valuation infrastructure;
- rough multiples do not populate Expected Return;
- research narrows by merit rather than one-name-per-archetype quotas;
- missing production models fail closed;
- no Immediate candidate is force-filled.

MA was deferred despite elite quality because it overlaps Visa and offered no clear marginal portfolio/valuation advantage at the rough-triage stage. FISV was rejected on deteriorating current business/growth evidence rather than promoted because of a cheaper-looking multiple.

### Model debt
All five Financials archetypes currently fail production valuation readiness:
1. Payment Network — `BLK-FIN-PAYNET-MDL-001` / HIGH
2. Commercial / Universal Bank — `BLK-FIN-BANK-MDL-001` / HIGH
3. Insurance — `BLK-FIN-INS-MDL-001` / HIGH
4. Exchange / Index / Ratings / Data — `BLK-FIN-DATA-MDL-001` / MEDIUM
5. Asset Manager — `BLK-FIN-ASSET-MDL-001` / MEDIUM

`PAYMENT_NETWORK_FCF_DCF_V1` already exists as a criteria contract but lacks a registered production implementation/version. The other routes require archetype-specific definitions/implementation.

Current Financials production result:
- Evidence Gate PASS: 3
- Valuation-ready: **0**
- Expected Return for JPM/V/CB: **NULL**
- Immediate: **0**
- No force-fill
- No allocation / scenario / portfolio mutation created by this sector research run

Rough P/E, P/B and P/FCF references are research triage only, never production fair value.

See `docs/runs/20260906_financials_sector_run.md` and `tests/decision/test_financials_quality_filter_acceptance_v1.sql`.

## Quality / Durability Hardening v1
Production promotion still requires all four gates:
1. Business Durability
2. Owner Earnings
3. Value Trap
4. Valuation Robustness

Expected Return v3 remains continuous and confidence-adjusted. Core weights remain exactly 30/30/25/15. Historical returns, narrative targets and rough multiples cannot replace expected return.

## Opportunity Ranking / Capital Allocation
Current production ranking remains `OPPRANK-QH-REVAL-20260906-02` because Financials is not valuation-ready.

Current board:
- Immediate: none
- RDDT: `WATCHLIST_VALUE_WAIT`
- PINS: `WATCHLIST_MODEL_REVIEW`

`POL-NEW-CASH-ALLOCATION-V1` still consumes only Immediate candidates. No force-fill.

## M3.3 Scenario / M3.4 Rebalance / M3.5 Approval
All remain LIVE and non-mutating until explicit human request boundaries are crossed.

The historical synthetic NVDA→PINS scenario remains regression history only and is not a current recommendation.

## Dashboard
Read Model v1: **17/17 PASS**. Auto Refresh v1: **14/14 PASS**.

Current Action remains `NO_ACTIONABLE_OPPORTUNITY`. Dashboard is downstream/read-only for investment logic.

## Controller after Financials
- Last completed sector: **Financials**
- Current stage: DONE
- Run lock: IDLE
- Next queued sector: **Industrials**
- Automation: **PAUSED**
- Pause reason: `FINANCIALS_MODEL_DEBT_REVIEW`
- Auto-resume: false

Industrials must not auto-start while Financials model debt is the explicit priority.

## Superseded immediate priority — Financials Valuation Model Sprint
The September 6 Financials model sprint is retained as historical roadmap context and reusable archetype work, but it is **no longer the global immediate next action**.

Under Core Architecture Redesign v1.0:
- existing Financials valuation/model work remains reusable archetype infrastructure;
- future Bank / Insurance / Data / Asset Manager / other archetype work is demand-driven by qualified candidates or portfolio relevance;
- the system must not require complete model coverage across every sector before progressing;
- unsupported archetypes fail closed for deep decision use rather than forcing generic valuation confidence.

Research Lifecycle #32, Canonical Instrument Identity #33, Metric Observation Model #34, Evidence → Metric → Decision Lineage #35, Unified Market Observation #36 and Thesis Memory + Reactivation #37 are complete at their migration-foundation layers. After the 2026-10-26 owner reprioritization, **Issue #38 is future backlog**, not the immediate execution item. Phase 1 MVP audit and report acceptance are first. Existing production research/decision consumers remain authoritative until explicit later cutover.

## M4 — Autonomous Investment OS
Future priority remains event/delta research refresh, thesis monitoring, opportunity refresh, concentration alerts and blocker recovery. Autonomous monitoring must never bypass Quality Hardening, model readiness or human execution.

## 2026-09-11 automation delta — Auto Decision Refresh v1

The infrastructure slice of M4 is now **SHADOW ACTIVE / FAIL-CLOSED**. This is an additive monitoring capability and does not auto-resume sector research or alter human-execution boundaries.

Implemented:
- Supabase `pg_cron` scheduler;
- `pgmq` queue/retry layer;
- `pg_net` internal worker invocation;
- `decision-refresh-worker-v1` Edge Function;
- isolated shadow run/job/evidence tables;
- SEC filings + compact XBRL Company Facts collector;
- dormant dual-provider market-price adapter;
- dormant analyst-consensus adapter;
- provider registry requiring secret + active + READY + Tier A before use;
- Vault-backed internal worker authentication and provider-secret lookup;
- 11/11 automation infrastructure regression.

First full shadow acceptance: 27 candidates / 81 jobs → 27 SEC PASS, 54 provider-gated BLOCKED, 0 retry, 0 dead-letter after queue acknowledgement fix. Worker v3+ SEC/XBRL smoke also passed. `authoritative_write=false` is enforced in the database for SHADOW runs.

Production Decision Refresh cutover remains blocked until market/consensus provider keys are configured, providers are independently Tier-A validated, and multiple completed market sessions pass shadow comparison. See `docs/08_AUTO_DECISION_REFRESH_SHADOW.md`.

Live Supabase state remains authoritative where older roadmap sector/ranking snapshots above have since moved forward.
