# AGENTS.md — Focused Wealth Investment OS

Mandatory execution contract for AI agents and automations.

Contract version: **FWIOS-CONTRACT-0.87.22**  
Compatible live foundation: **0.87**

## 1. Objective
Optimize for aggressive but disciplined capital growth toward the Phase-1 THB 1,000,000 target.

> Focus creates upside. Position sizing creates survival. Valuation creates margin of safety.

Human execution only. Never auto-buy or auto-sell.

## 2. Authority model
- **Supabase = System of Record / State**.
- **GitHub = Logic / Contracts / Tests / Migrations**.
- **Google Sheets = View / Compatibility / Reconciliation / Audit / Export**.
- **AI = Research / interpretation / explanation / controlled orchestration**, not accounting, hidden scoring or trade execution.

Live portfolio/system/controller state overrides stale documentation.


### Core Architecture Redesign v1.0 — MIGRATION ACTIVE / PHASE #37 THESIS MEMORY LIVE

GitHub Epic **#31** defines the planned migration from broad sector/thesis coverage toward a portfolio-native operating loop:

`Universe → Opportunity/Attention → Selective Research → Thesis Memory → Decision → Portfolio`.

The redesign migration is active. **Research Lifecycle v1 is contract-live**, but existing research/decision read paths remain authoritative until their later migration phases are regression-tested and explicitly cut over. `POL-RESEARCH-LIFECYCLE-V1` has `production_read_cutover=false`.

Design constraints for all new work:
- broad market coverage is shallow discovery/screening, not full-thesis coverage;
- Full Thesis is a scarce research state earned through qualification;
- research depth follows capital relevance and expected decision value;
- archetype models are built/reused on demand; do not implement every sector/archetype merely for coverage;
- external data may be rented, but FWIOS owns investment state, decision memory and auditable lineage;
- rejected/deferred ideas retain decision memory and explicit reactivation conditions instead of continuous deep monitoring;
- existing immutable snapshots, fail-closed gates, policy versioning and human-execution-only boundaries remain mandatory throughout migration.

Migration sequence:
`#32 → #33 → #34 → #35/#36 → #37 → #38 → #39`.

Issue #32 is complete at the contract/kernel layer. Until a later phase is explicitly cut over, the current production model and compatibility surfaces remain authoritative.


## 3. Before any investment recommendation
1. Read latest reconciled portfolio state and relevant source transactions.
2. Apply Focused Wealth-Building guardrails.
3. Analyze candidates in portfolio context.
4. Verify current price, financials, valuation inputs and material news.
5. Prefer primary company/SEC/IR evidence for canonical facts.
6. Check concentration and crypto exposure.
7. Challenge FOMO, anchoring, confirmation bias and narrative-driven reasoning.
8. Clear **Quality / Durability Hardening** before treating a candidate as Immediate.
9. Use latest Decision Snapshot, Opportunity Ranking, New-Cash Allocation, Scenario, Rebalance and Human Approval policies where applicable.
10. Broker-verify price before any real trade decision.

## 4. Portfolio guardrails
- Prefer 5–8 meaningful positions.
- Exceptional single-stock allocation ~30% max; above requires explicit review, not forced selling.
- Phase-1 crypto target ~15–20%; deviations require explicit justification.
- Prefer new cash / soft rebalance before selling high-quality winners.
- Never trim merely because a position appreciated.
- Max 5 active watchlist candidates; max 3 immediate buy candidates.
- Actual new purchase per decision cycle is normally 0–1.
- No force-fill: if nothing clears the gates, hold cash.

## 5. Production scoring
Core weights remain exactly:
- Business / Thesis 30%
- Expected Return / Valuation 30%
- Portfolio Fit 25%
- Downside / Thesis Risk 15%

Active scoring policy: `POL-DATA-SCORING-V3-DURABILITY` / `FWB-DATA-SCORING-V3-DURABILITY`.

Expected Return v3 is continuous and confidence-adjusted:
`(60% × base-upside score + 40% × PW-upside score) × valuation confidence`.

`continuous_upside_score(u) = clamp(50 + 100*u, 0, 100)`.

Historical stock return, cost basis, narrative targets, rough multiples or unverified consensus can never substitute for expected return.

## 6. Quality / Durability Hardening — ACTIVE
Policy: `POL-QUALITY-HARDENING-V1`.

Immediate promotion requires **all four** gates to PASS:
1. **Business Durability** — point-in-time growth cannot be extrapolated into a multi-year valuation without a verified durability anchor. Default anchor is >=3 years of comparable evidence or an explicitly justified alternative.
2. **Owner Earnings** — reported FCF must be reconciled with dilution/SBC economics when SBC is material. <=10% SBC/revenue is a clean narrow pass; >10% requires reconciliation; >20% hard review; >30% fail.
3. **Value Trap** — extreme modeled mispricing (>=75% trigger) requires verified counter-thesis evidence explaining why the market discount is likely wrong. Long-horizon price weakness is only a review trigger.
4. **Valuation Robustness** — assumptions must remain defensible under conservative scenarios. Bear downside worse than 30% triggers review; worse than 50% fails v1.

Gate confidence factors: PASS 1.0 / REVIEW 0.7 / BLOCKED 0.4 / FAIL 0.0. Missing critical hardening evidence => BLOCKED.

AI must never invent durability, owner-earnings, value-trap, robustness or valuation evidence merely to make a candidate pass.

## 7. Production path
`Source → Evidence → Canonical Facts → Normalized Metrics → Valuation → Market Price/Mispricing + Portfolio State/Fit → Quality/Durability Hardening → Core Scoring → Revision/Chase → Decision Snapshot → Opportunity Ranking → New-Cash Allocation → Portfolio Scenario → Rebalancing Recommendation → Human Approval`.

Facts and assumptions stay separate. Preview/scenario/recommendation/approval functions never place orders or mutate live holdings.

## 8. Production-active deterministic policies
- `POL-DATA-SCORING-V3-DURABILITY`
- `POL-QUALITY-HARDENING-V1`
- `POL-REVISION-SCORE-V1`
- `POL-CHASE-SCORE-V1`
- `POL-OPPORTUNITY-RANKING-V2`
- `POL-NEW-CASH-ALLOCATION-V1`
- `POL-PORTFOLIO-SCENARIO-V1`
- `POL-REBALANCE-V1`
- `POL-HUMAN-APPROVAL-V1`
- `POL-RESEARCH-LIFECYCLE-V1` — contract/gating kernel active; no production read cutover
- `POL-CONTROLLED-RESEARCH-INGEST-V1` — service-role-only PREVIEW/APPLY research gateway; 15/15 acceptance PASS
- `POL-RESEARCH-READINESS-V1` — additive deterministic readiness surface; 21/21 acceptance PASS; no scanner read cutover
- `POL-INSTRUMENT-IDENTITY-V1` — canonical identity active; legacy symbol read paths preserved
- `POL-METRIC-OBSERVATION-V2` — typed period-aware metric foundation active; no production read cutover
- `POL-LINEAGE-GRAPH-V1` — append-only evidence→metric→decision lineage active; no production read cutover
- `POL-MARKET-OBSERVATION-V1` — canonical provider/session-aware market observations + dual-write compatibility; no production read cutover
- `POL-THESIS-MEMORY-V1` — normalized thesis conditions/KPI bindings + append-only decision/reactivation memory; no production read cutover
- `POL-VALUATION-PROMOTION-V1` — deterministic shadow→promotion readiness plus service-role-only controlled apply/rollback; preview never cuts over by itself and apply requires explicit human authorization
- `POL-QUALITY-HARDENING-REFRESH-V1` — deterministic service-role-only bridge from current production valuation + accepted canonical daily close to current mispricing/hardening lineage; apply requires explicit human authorization and never retunes hardening thresholds

AI must never retune deterministic gates ad hoc to make a name pass.

### Valuation Promotion Policy — ACTIVE / CONTROLLED APPLY + ROLLBACK

`POL-VALUATION-PROMOTION-V1` standardizes promotion review for validated valuation-model shadow runs.

Rules:
- Results are only `AUTO_ELIGIBLE`, `MANUAL_REVIEW`, or `BLOCKED`.
- `AUTO_ELIGIBLE` means ready for one explicit human-approved production promotion; it is **not** automatic cutover.
- Required inputs must be 100% PASS and backed by Tier-A, VERIFIED, conflict-free evidence.
- Metric-input lineage must be complete; model regression and valuation/router/schema gates must PASS.
- Exactly one current production model version must exist and the shadow version must explicitly supersede it.
- Same kernel family plus max absolute Bear/Base/Bull/PW Fair Value delta <=15% is required for `AUTO_ELIGIBLE`.
- Larger deltas or kernel changes require `MANUAL_REVIEW`; hard gate failures return `BLOCKED`.
- Current production run/version are retained as rollback targets.
- Policy preview is service-role-only, non-mutating, `auto_apply=false`, `auto_trade=false`, and never mutates holdings/transactions/cash.
- After explicit human authorization, `fwios.apply_valuation_promotion_v1(shadow_run_id)` may cut over only an `AUTO_ELIGIBLE` shadow. It creates a new production run; it never flips the shadow run in place.
- The prior production run/version must be retained as an explicit rollback target. Exact repeat apply calls must be idempotent `NOOP_ALREADY_PROMOTED`.
- `fwios.rollback_valuation_promotion_v1(production_run_id)` may only roll back a currently active run created by Promotion Policy v1; rollback is never automatic.
- Apply/rollback are service-role-only, human-execution-only, and must not mutate holdings, transactions, cash, accounting, approval, or trade execution.

### Quality Hardening Refresh Bridge — ACTIVE / CONTROLLED APPLY

`POL-QUALITY-HARDENING-REFRESH-V1` repairs stale post-valuation-cutover hardening lineage without changing `POL-QUALITY-HARDENING-V1`.

Rules:
- PREVIEW selects the latest production-eligible valuation and latest readiness-accepted canonical daily close.
- APPLY requires explicit human authorization and is service-role-only.
- Compatibility market-price/mispricing snapshots may only be derived from existing canonical market observations plus an existing PASS verification set; no external price refetch is required.
- Business Durability and Owner Earnings may only carry forward from still-fresh prior production hardening evidence and can never be auto-upgraded.
- Value Trap and Valuation Robustness are recomputed from current valuation/current price.
- Missing production hardening evidence remains BLOCKED; shadow evidence cannot directly create a production PASS.
- Exact repeat APPLY is idempotent `NOOP_ALREADY_REFRESHED`.
- No holdings, transactions, cash, accounting, approval, execution or trading mutation. `auto_trade=false`; human execution only.

Production refresh receipt on 2026-10-27: ACN = REVIEW, EOG = FAIL, NFLX = BLOCKED; all three hardening snapshots now reference their current v2 production valuation and none is investment-review-ready.

### Controlled ChatGPT Research Ingestion — ACTIVE

All ChatGPT-originated production research ingestion must use:

`Research Payload → fwios.preview_research_ingest_v1() → validation → fwios.apply_research_ingest_v1()`.

Rules:
- PREVIEW is non-mutating.
- APPLY requires explicit user write intent and `mode=APPLY`.
- ChatGPT must not bypass the gateway with direct writes to `evidence_records`, `metric_observations`, or `research_candidates`.
- Critical reported facts must satisfy existing primary/Tier-A source-routing rules.
- Unknown metric codes, invalid unit/currency/period context, unresolved evidence conflicts, and conflicting VERIFIED observations fail closed.
- Deterministic `evidence_id`, `observation_key`, and payload fingerprints enforce idempotency.
- Existing evidence/metric rows are never overwritten by the gateway.
- Risks, guidance context, and research summaries may be retained in the ingest receipt, but do not directly create production scores.
- The gateway does not mutate lifecycle state, scanner score/rank, valuation, holdings, transactions, cash, approval, or execution.
- RPC access is service-role only; `auto_trade=false`; human execution only.



### Research Readiness & Fail-Closed Gates — ACTIVE ADDITIVE

PR4 readiness is exposed by `fwios.v_research_readiness_current_v1` under `POL-RESEARCH-READINESS-V1`.

Rules:
- Readiness is deterministic and backend-owned. ChatGPT must not subjectively promote a stock.
- States are hierarchical: `DISCOVERY_READY → RESEARCH_READY → VALUATION_READY → QUALITY_HARDENED → INVESTMENT_REVIEW_READY`.
- Research readiness has two deterministic compatibility routes: legacy candidates require the existing evidence gate plus policy freshness; controlled-ingest receipts require validated evidence, at least one canonical metric, verified primary/Tier-A evidence, and at least one metric whose reported/as-of/period-end date is within the research freshness window. Ingest time alone never makes old research fresh.
- Valuation readiness selects the latest `production_eligible=true` valuation run first, then requires readiness/router/valuation/schema gates to pass; a newer shadow/non-production run cannot displace the production valuation.
- Quality Hardened requires `overall_gate=PASS` and the hardening snapshot must reference the latest valuation run; stale hardening lineage fails closed.
- Price readiness uses only the canonical FWIOS daily-close path with accepted verification/provenance and policy-bounded freshness.
- `scanner_score_eligible=true` only when `investment_review_ready=true`.
- PR5 Scanner v2 must emit `scanner_score=NULL` and `scan_rank=NULL` whenever `scanner_score_eligible=false`; PR4 does not modify `v_scanner_current_v1`.
- `POL-RESEARCH-LIFECYCLE-V1` still has `production_read_cutover=false`; PR4 therefore exposes lifecycle gating as `DEFERRED_NO_PRODUCTION_READ_CUTOVER` instead of pretending a canonical per-stock lifecycle gate is active.
- The readiness layer does not mutate lifecycle state, evidence, metrics, valuation, hardening snapshots, holdings, transactions, cash, approval or execution.
- `auto_trade=false`; human execution only.

Live acceptance: **21/21 PASS**. Review hardening covers empty controlled metrics, stale source-period data, fresh controlled metrics, newer non-production valuation isolation, and explicit lifecycle-gate deferral. Current active Stock universe: 64; Research Ready: 27; Valuation Ready: 27; Quality Hardened: 1; Investment Review Ready: 1.



## 9. Current Communication Services decision state — REVALIDATED
Base Quality-Hardening suite remains **20/20 PASS**; downstream production verification remains **11/11 PASS**; Communication Services quality-filter acceptance is **8/8 PASS**.

PINS current immutable lineage:
- Hardening: `HARD-PINS-20260906-V2`
- Score: `SCORE-PINS-QH-20260906-V2`
- Decision: `DEC-PINS-QH-20260906-V2`
- Business / Thesis: 82
- Expected Return: **77.5000**
- Core: **80.8500**
- Valuation confidence: **0.7750**
- Durability: PASS
- Owner Earnings / Value Trap / Valuation Robustness: REVIEW
- Bucket: `WATCHLIST_MODEL_REVIEW`

RDDT current lineage:
- Hardening: `HARD-RDDT-20260906-V2`
- Score: `SCORE-RDDT-QH-20260906-V2`
- Decision: `DEC-RDDT-QH-20260906-V2`
- Business / Thesis: 88
- Expected Return: **41.6431**
- Core: **71.1429**
- Valuation confidence: **0.9250**
- Durability / Owner Earnings / Value Trap: PASS
- Valuation Robustness: REVIEW
- Bucket: `WATCHLIST_VALUE_WAIT`
- Mispricing: `FAIL - INSUFFICIENT MISPRICING`

NFLX remains the quality/model-availability regression anchor: Business / Quality 94, Evidence PASS, Valuation `BLOCKED - MODEL NOT IMPLEMENTED`.

Current production Immediate count remains **0**. New-cash preview continues to HOLD CASH rather than force-fill.

## 10. Financials Sector Loop — RESEARCH COMPLETE / PRODUCTION FAIL-CLOSED
Manual user-requested run: `SECTOR-FIN-FULL-20260906-01`.

Acceptance suite: **8/8 PASS**.

Research funnel:
`20 universe → 8 Fast Discovery → 5 shortlist → 3 Deep Research`.

Current Financials shortlist:
1. JPM
2. V
3. CB
4. SPGI
5. BLK

Deep Research names and quality state:
- **JPM** — Business / Quality 96, 9 Tier-A verified evidence rows, valuation `BLOCKED - MODEL NOT IMPLEMENTED`.
- **V** — Business / Quality 96, 9 Tier-A verified evidence rows, valuation `BLOCKED - MODEL NOT IMPLEMENTED`.
- **CB** — Business / Quality 94, 9 Tier-A verified evidence rows, valuation `BLOCKED - MODEL NOT IMPLEMENTED`.

Total Tier-A verified Financials evidence: **27 rows**.

The research loop correctly separates quality from valuation readiness. Rough P/E/PB/PFCF references are triage-only and must never populate Expected Return, Mispricing or Immediate eligibility.

Five canonical Financials model blockers are open:
- `BLK-FIN-PAYNET-MDL-001` — Payment Network / HIGH; `PAYMENT_NETWORK_FCF_DCF_V1` contract exists but production implementation/version is missing.
- `BLK-FIN-BANK-MDL-001` — Commercial / Universal Bank / HIGH.
- `BLK-FIN-INS-MDL-001` — Insurance / HIGH.
- `BLK-FIN-DATA-MDL-001` — Exchange / Index / Ratings / Data / MEDIUM.
- `BLK-FIN-ASSET-MDL-001` — Asset Manager / MEDIUM.

Current Financials production state:
- Evidence Gate PASS: 3
- Valuation-ready: **0**
- Expected Return for JPM/V/CB: **NULL / fail-closed**
- Immediate Buy Candidates: **0**
- No force-fill
- No portfolio mutation
- No auto trade

MA was deferred despite elite quality because it substantially overlaps Visa and did not offer a clear marginal fit/valuation advantage at the rough-triage stage. FISV was rejected on current business/growth deterioration rather than promoted because of a cheaper-looking multiple. This behavior is intentional.

See `docs/runs/20260906_financials_sector_run.md` and `tests/decision/test_financials_quality_filter_acceptance_v1.sql`.

## 11. Opportunity Ranking v2 — PASS / LIVE
Policy `POL-OPPORTUNITY-RANKING-V2`.
- Promotion PASS + Hardening PASS → `IMMEDIATE_BUY_CANDIDATE`
- Mispricing insufficient + other required gates pass → `WATCHLIST_VALUE_WAIT`
- Mispricing PASS but Hardening not PASS → `WATCHLIST_MODEL_REVIEW`
- Otherwise → EXCLUDED
- Priority remains Core Score; max Immediate 3 / Watchlist 5; no force-fill.

Current production ranking remains `OPPRANK-QH-REVAL-20260906-02`; Financials has not created a ranking candidate because valuation readiness is zero.

## 12. M3.2 New-Cash Allocation — PASS / LIVE
`POL-NEW-CASH-ALLOCATION-V1`; 20/20 regressions. New cash first, Immediate Stock candidates only, max one deployed asset/run, starter cap 5% post-money, residual cash held, non-mutating.

With the current zero-Immediate ranking, allocation preview holds all new cash rather than forcing a candidate.

## 13. M3.3 Portfolio Scenario — PASS / LIVE
`POL-PORTFOLIO-SCENARIO-V1`; 28/28 regressions. NO_SELL / SOFT_REBALANCE / ACTIVE_REBALANCE. ADD requires active ranking + Decision Snapshot. Appreciation-only trim rationale is forbidden. Full-portfolio expected upside fails closed when valuation coverage is incomplete.

## 14. Holding valuation / M3.4 Rebalancing
Semiconductor Designer model `SEMIS_MIDCYCLE_DCF_V1::1.0` remains production-live for NVDA lineage.

`POL-REBALANCE-V1`; 12/12 PASS:
- new cash before trim;
- ADD requires active Immediate + traceable Decision Snapshot valuation;
- source trim requires current valuation-covered concentration-review holding;
- minimum PW expected-return edge 25pp;
- 30% is a review threshold, not forced target;
- appreciation-only trim forbidden;
- human review + broker price verification required.

Because the current ranking has no Immediate candidate, the prior synthetic NVDA→PINS path is not a current actionable path.

## 15. M3.5 Human Approval / Cutover — PASS / LIVE
`POL-HUMAN-APPROVAL-V1`; 30/30 PASS.

`Immutable Recommendation Snapshot → Immutable Approval Packet → Append-only Approval Event`.
Only `PRODUCTION_USER_REQUESTED` is approvable. Validation/test scopes are never actionable. Approval does not place broker orders or mutate portfolio accounting.

Cutover proof remains 29/29 transactions, 16/16 positions and 9/9 traceability layers PASS.

## 16. M3 boundary
M3.1–M3.5 remain **COMPLETE / CUTOVER PASS**. Quality hardening changes candidate eligibility, not the human-execution boundary.

## 17. Focused Wealth Dashboard Scanner — PASS / LIVE
Monitoring Sheet: **Focused Wealth Dashboard - Chumponphat** (`17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8`).

Active user-facing surface:
- `S&P500 Scanner`
- `Valuation Map`

`fwios.v_scanner_current_v1` is the active portfolio-independent scanner read model. It may use canonical stock market data, thesis/research quality, resilience inputs, valuation and probability-weighted fair value, but it must not use holdings, account ownership, portfolio weight/fit/scenario, position sizing, cash, portfolio P&L, approval state or execution state.

`scanner-refresh-csv-v1` is the active Sheet feed. The hidden `_Scanner_Data` helper imports from a scanner-specific hidden configuration source and has no dependency on legacy `_Data`.

Current backend universe is **64 ACTIVE Stock instruments**, not full S&P 500 coverage. The UI must state actual coverage until full constituent ingestion exists.

Legacy hidden `Dashboard`, `Thesis Tracker`, `Opportunity Quality`, `_Data`, `dashboard-refresh-csv-v1`, and `fwios.dashboard_refresh_payload_v1()` are rollback-only compatibility components and are not the active Focused Dashboard read model. Do not delete shared thesis/research/valuation services that still support the scanner.

Portfolio accounting remains owned by **Investment Portfolio Tracker - Chumponphat**. Focused Wealth Dashboard must never become a second transaction/cost-basis/cash/holdings accounting system. `auto_trade=false`; human execution only.

## 18. Legacy Google Sheets surface — REDUCED
`US_Stock_Sector_Business_Model_Screener` is retained for compatibility/audit/research but is no longer a parallel production authority.

Visible operational tabs remain:
- `Sector_Scan`
- `Sector_Run_Control`
- `Thesis Monitor`
- `System_Foundation`
- `Evidence_Ledger`
- `Data_Quality_Gates`

Financials current research view and five canonical model blockers are synchronized into the legacy surface. Historical evidence, formulas and reconciliation lineage remain available.

## 19. Fail-closed rule
Missing, stale, conflicting, schema-invalid, unverified, provenance-free, policy-incomplete, model-unimplemented **or quality-hardening-incomplete** critical data => BLOCKED.

Never force-fill. Rough valuation multiples and historical return cannot substitute expected return. Rejected/expired/stale/non-actionable approval packets cannot execute.

## 20. Research/controller
Research Lifecycle v1, Canonical Instrument Identity v1, Metric Observation Model v2 and Evidence → Metric → Decision Lineage Graph v1 are live migration foundations.

Metric v2 state:
- 130 semantic metric definitions;
- 449 typed metric observations at acceptance;
- 233/233 company_metrics compatibility rows;
- 210/210 normalized_metrics compatibility rows;
- all ticker-bearing company_metrics / normalized_metrics / evidence_records mapped to `instrument_id`;
- ADBE recurring growth Q2/Q3 coexist under one metric code;
- PINS MAU/revenue growth Q1/Q2 and quarterly FCF history coexist by period;
- PINS ARPU and SBC baselines use explicit period semantics;
- normalized observations retain source-observation/evidence lineage handles for compatibility;
- legacy metric/valuation/Revision read paths remain authoritative.

Lineage v1 state:
- 1,156 explicit lineage artifacts / 1,423 typed edges at acceptance;
- 39 unresolved legacy references are explicit REFERENCE_ONLY artifacts and 82 edges are REFERENCE_ONLY rather than fabricated provenance;
- ADBE Revision 47.5878 traces through exactly four explicit components to resolved evidence or explicit reference artifacts;
- PINS Hardening REVIEW traces through FCF, SBC, buybacks and share-count evidence plus typed owner-economics metric paths;
- `fwios.v_lineage_edges_resolved` and `fwios.lineage_trace_v1` provide audit/AI query surfaces;
- append-only triggers reject UPDATE/DELETE;
- 16/16 lineage regressions PASS;
- production_read_cutover=false and legacy provenance fields remain compatibility-only inputs.

Broad-universe ingestion remains selective and decision-relevant. Do not mirror full financial statements by default.

Market Observation v1 state:
- canonical `market_observations` supports REGULAR_CLOSE, LIVE_QUOTE, PRE_MARKET, AFTER_HOURS and FX;
- 4,489 observations / 4,489 legacy links / 340 verification sets at acceptance;
- current Decision Price, Daily Close and Portfolio MTM rows all reference canonical observation IDs;
- four dual-write triggers keep future legacy writes synchronized;
- PINS Sep-4 verified price remains PASS at $20.28;
- PINS Sep-10 remains BLOCKED - PRICE CONFLICT at 1.2597% divergence;
- target-session decision-refresh plan parity PASS;
- legacy market-price/mispricing readers remain authoritative;
- production_read_cutover=false.

Thesis Memory v1 state:
- all 6 COMPLETE thesis baselines are normalized while legacy JSON remains authoritative;
- 73 explicit conditions: 27 Must-Remain-True / 22 Catalysts / 24 Invalidations;
- 37 KPI bindings and 8 explicit condition→metric links at acceptance;
- unresolved KPI semantics remain UNMAPPED or PARTIAL rather than fabricated;
- ADBE/PINS thesis text and baseline JSON hashes remain byte-stable;
- current ADBE/PINS production decisions and thesis-health outputs remain unchanged;
- append-only decision memory is live with 2 real current anchors and no fabricated REJECTED rows;
- future REJECT memory requires an explicit reactivation rule;
- REJECTED/ARCHIVED reactivation requires trigger + memory and may return only to UNIVERSE/SCREENED/WATCH review;
- no direct FULL_THESIS, PORTFOLIO or buy promotion;
- 15/15 thesis-memory regressions PASS;
- production_read_cutover=false.

## 21. Immediate next action
**Implement Issue #38 — Research Attention + Promotion/Demotion Engine.**

Issue #37 is complete at the additive thesis-memory foundation layer. #38 should allocate research effort by lifecycle/resource tier and expected decision value, preserve explicit no-force-fill behavior, keep unsupported archetypes fail-closed, and never create a trade automatically.

## 22. Documentation handshake
Before material work read live `System_Foundation`, this file, `contracts/system-contract.yaml`, `VERSION`, roadmap, architecture and relevant live Supabase/Sheet state. Resolve drift first. After material changes synchronize roadmap/architecture/live foundation.

### 22.1 Documentation lifecycle and new-chat handoff
- Start with [docs/CURRENT_STATUS.md](docs/CURRENT_STATUS.md) to locate the relevant active feature, PR, runbook and blockers. This index is a **dated navigation snapshot**, never a replacement for current GitHub/Supabase/Sheet inspection.
- Use `AGENTS.md` and `contracts/system-contract.yaml` for execution constraints; current live state and merged source override stale snapshot claims.
- Track implementation progress and outstanding work in the relevant GitHub PR/Issue plus its feature specification. Update the Current Status index after a material PR merge, production cutover, or workstream change.
- Create a new dated handover only when an actual interruption needs extra non-reconstructible operational details; prefer updating the living status index and feature docs when only changing Chat.
- Keep historical evidence and decisions in durable implementation docs, runbooks, ADRs, PRs and Git history. Archive superseded chat handovers with a non-authoritative banner, retaining short compatibility pointers if old links are used.
- Archived handovers are audit/history ONLY. Never execute their outdated 'next-chat' instructions without checking live state; do not blindly delete referenced files or rewrite historical verification receipts.
- See `docs/DOCUMENTATION_LIFECYCLE.md` for classification, archival and review procedure. Documentation-only cleanup never authorizes database, worker, trading or portfolio-accounting changes.

## 23. Regression discipline
Changes to normalization, valuation, hardening, scoring, Decision Snapshots, ranking, allocation, scenario, rebalancing, approval or dashboard semantics require deterministic regressions. Reference names include ISRG, EOG, BKR, CAVA, TPR, RDDT, PINS, JPM, V, CB and NVDA.

## 24. Source precedence
1. Latest reconciled portfolio data
2. Focused Wealth-Building rules
3. Production policy/hardening state
4. Current primary-source research
5. Wall Street consensus
6. News/social narratives

Use the higher-priority source when conflicts occur; fail closed when material conflicts remain unresolved.