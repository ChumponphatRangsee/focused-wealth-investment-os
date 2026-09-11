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
| Immediate next action | **Implement Financials valuation models starting Payment Network** |

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

## Next implementation phase — Financials Valuation Model Sprint
Priority:
1. **Payment Network** — implement `PAYMENT_NETWORK_FCF_DCF_V1` first because its contract is already defined.
2. **Bank** — define/implement `BANK_ROTCE_TBV_V1` with ROTCE/TBV/CET1/NII/credit-cycle normalization.
3. **Insurance** — define/implement `INSURANCE_BOOK_VALUE_ROE_V1` with underwriting/book-value/ROE normalization.
4. **Data / Ratings / Exchange** — define/implement `FIN_DATA_PLATFORM_FCF_DCF_V1`.
5. **Asset Manager** — define/implement `ASSET_MANAGER_FRE_AUM_V1` if shortlist value justifies further work.

Every model must:
- preserve reported facts vs assumptions;
- use archetype-correct normalized economics;
- pass deterministic regressions;
- fail closed before activation;
- rerun affected candidates through valuation → hardening → scoring → ranking after activation.

Only after that should the system determine whether JPM, V, CB, SPGI or BLK deserve Value-Wait, Model-Review or Immediate status.

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
