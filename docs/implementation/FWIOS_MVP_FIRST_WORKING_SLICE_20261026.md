# FWIOS — MVP-First Delivery & End-to-End Read-Only Audit

Date: **2026-10-26 (Asia/Bangkok)**  
Status: **Owner-approved reprioritization; roadmap/audit only — runtime MVP not yet accepted**  
Contract: `FWIOS-CONTRACT-0.87.19` (unchanged)  
Supabase project: `focused-wealth-investment-os` (`ysjbmeukwbfnxnwqchuq`)  
Baseline inspected: GitHub `main` `298fbb8e7aa09126c049cf218036e811f40444cd`. Live Supabase was read-only inspected on 2026-10-26.

## 2026-10-28 owner decision — Phase 1 pilot scope LOCKED

**Only three Phase 1 business pilot tickers: ACN, ADBE, PINS.** The owner explicitly declined expanding the financial-data or Fair Value review to all 28 currently valued tickers in this phase. Even if the three pilots pass, **do not automatically begin a 28-stock, 64-stock or S&P 500 fundamental/valuation audit**. A later explicit scope decision is required; do not pre-authorize expansion in this plan.

Phase 1 execution order (one scoped, reviewed step at a time):

1. **ACN / financial data reliability (first):** Read-only compare latest SEC/issuer release and required metric inputs against canonical evidence/metrics, period, currency, unit and report dates. Record exact missing, stale or conflicting fields. Then preview any corrected ingest; production APPLY and a new eligible valuation require separate explicit authorization and tested gateway controls.
2. **ADBE / valuation-to-hardening lineage:** Compare latest eligible valuation run and referenced Quality Hardening run, price/mispricing links, as-of fields, and reason codes. Fix only an evidenced shared problem in a separately reviewed PR; do not overwrite historical snapshots.
3. **PINS / quality and decision blockers:** Verify current canonical price → mispricing → hardening → Decision links and genuine owner-earnings/value-trap/robustness REVIEW. Preserve fail-closed behavior and production thresholds.
4. **Three-ticker acceptance:** For **each** of ACN/ADBE/PINS, verify current primary-source freshness or an explicit stale-data block, model-required input inventory, reproducible source-backed Fair Value when supported, timestamps/run IDs, clear reason codes, and parity on the existing Valuation Map. No forced BUY/PASS; other stocks remain outside the deep-audit pilot.

**Scope distinction:** Existing 64-stock EOD market-price collection/monitoring and previously observed 28-row dashboard parity checks are operating context, **not** approval to deepen analysis, revalue, or refresh fundamentals for all those symbols. The separate MA clean-room proof may continue as an engineering/regression workstream, but MA does not become a fourth Phase 1 product pilot. Keep Phase 2–4 and broad clean-room scaling deferred.

## MVP-1 scope correction — DATA RELIABILITY, no new Dashboard (2026-10-26)

**LATEST OWNER DECISION: the existing Google Sheet `Valuation Map` is the user-facing surface.** Do not build a new report, tab, dashboard, new research-attention schema or an autonomous research engine for MVP-1. Historical report/UI instructions further down are superseded wherever they suggest developing another user-facing view. The previous SQL pilot remains a **diagnostic** only.

**MVP-1 goal:** verify, repair and prove the *existing* data pipeline:

1. **Availability/completeness:** every in-scope tracked stock has the required latest canonical market close, verified source/provenance and a persisted record. For the **three locked valuation pilot names (ACN, ADBE, PINS)**, inventory model-required financial facts (revenue, margins, shares/SBC, FCF/debt/cash, guidance as applicable), filing date/period/currency, evidence and explicit missing fields. Do not assume every stock needs identical metrics or a valuation model.
2. **Correctness:** cross-check prices with an independent authorized provider when possible; reconcile key financial facts to primary issuer IR/SEC releases, accounting period, unit/currency and normalization. Reject contradictory observations; no guessed metric, silent overwrite or unversioned change to valuation assumptions.
3. **Freshness:** after the last completed US trading session, accepted EOD prices should be present for 100% of the **current 64-stock tracked universe** by the next Bangkok morning (respect market holidays). Fundamental freshness is based on the **most recent published company filing or earnings release**, not a price timestamp or ingestion timestamp. Set a narrowly approved refresh expectation (proposal: review/ingest material primary financial updates within two business days after release, then revalue if model inputs changed); do not imply that a 2026-09 valuation became fresh when the price updated in October.
4. **Valuation:** an immutable production-eligible valuation run is tied to source-backed current-period metrics, versioned assumptions and as-of date; revaluation after materially new validated metrics must be explicit, with lineage/quality gates preserved. `Valuation Map` may remain unchanged but must not describe an old model as up-to-date. No forced `BUY`.
5. **Presentation parity:** the **existing** `Valuation Map` values must match `fwios.v_dashboard_valuation_map` (price/session, bear/base/bull/PW fair value and upside within display rounding). The existing `Entry View=Attractive` is a price classification **only**, not an investable decision; do not silently promote a blocked name.

### Verified read-only diagnostic snapshot (2026-10-26)

| Area | Result and qualification |
| --- | --- |
| Price fetch/store | Scheduled `TWELVE_DATA` EOD close runs **PASS 64/64** for each US trading session **Oct 19–23, 2026**; market observations show `source_tier=A`, `provenance_status=PASS`, non-null URLs and positive values for all 64 on Oct 23. This establishes **tracked-universe** coverage, not the full S&P 500. |
| Latest completed session | Valuation Map's session is **2026-10-23**, expected on Monday Oct 26 before the US close. |
| Independent price check | 13 of 64 stocks also had `ALPHA_VANTAGE_PRICE` EOD observations on Oct 23; differences vs Twelve Data ranged **0–0.0261%**. Remaining 51 lack this particular independent comparison; correctness of every price has **not** been proven. |
| Google Sheet vs database | `Valuation Map` 28 rows matched all 28 `v_dashboard_valuation_map` rows on ticker, session, current price, Bear/Base/Bull/PW Fair Value and upside within display precision. No user-facing Sheet edit necessary. |
| Financial metric coverage | `fwios.metric_observations`: **453 rows, 28/64 instruments**, 131 distinct metric codes; latest metric insertion **2026-09-30**, newest metric `reported_at` **2026-09-10**. A stored observation is **not** proof it is the issuer's latest filing. |
| Existing valuation age | The 28 Valuation Map rows all have model dates in the **2026-09-04 to 2026-09-11** range, despite fresh Oct 23 stock prices. |
| Confirmed material release gaps | ACN latest stored metric report **Jun 18**, but issuer announced **Q4 FY26 Oct 1**: https://newsroom.accenture.com/news/2026/accenture-reports-fourth-quarter-and-full-year-fiscal-2026-results ; JPM latest stored **Jul 14**, issuer announced **Q3 Oct 13**: https://jpmorganchaseco.gcs-web.com/news-releases/news-release-details/jpmorganchase-reports-third-quarter-2026-financial-results/ ; NFLX latest stored **Jul 16**, issuer issued **Q3 Oct 20**: https://ir.netflix.net/files/doc_financials/2026/q3/FINAL-Q3-26-Shareholder-Letter.pdf . These companies have **newer published financials not represented in the canonical metric_observations rows**. |
| Research-to-action gate | Readiness: **27 research/valuation-ready, 1 investment-review-ready**; price-based `Attractive` must never be equated with `BUY`. |
| Automated fundamental ingest | The 10 active inspected `cron.job` schedules include EOD prices and several validation/refresh services, but no independently verified scheduled `metric_observations` primary-financials ingestion. Existing `PREVIEW → validated APPLY` remains separately permissioned. |

**Primary blocker = Financial data ingestion and subsequent model valuation freshness, not a missing Dashboard.** Price ingestion is relatively healthy; remaining work is verifying core fundamental facts against source, filling post-September gaps safely, then recalculating eligible valuations where material. Do not deploy automatic APPLY without separate authorization.

### Revised MVP-1 acceptance checklist

- [ ] Audited pilot-company *required model input inventory* (not all 64/500 symbols), with verified latest primary financial filing vs canonical metric/evidence dates, explicit missing data and reasons.
- [x] EOD ingest/store coverage for the 64 tracked tickers on Oct 19–23 and independent comparison for the 13 overlapping provider prices recorded.
- [x] Current `Valuation Map` matches its source view for all 28 valued stocks at display precision.
- [ ] At least one company with a **new earnings release** has primary evidence + relevant metrics validated and, **only after separate user APPLY authorization**, ingested through the controlled gateway and revalued with repeatable, auditable model inputs. Merely previewing research does not count as a database refresh.
- [ ] No material current issuer filings remain untriaged in the **pilot scope**; any stale/missing data remains explicitly blocked or flagged.
- [ ] Confirm repeatable operational freshness checks after the *next completed* US market session and next material earnings event; do not add new jobs unless the existing workflow demonstrably cannot cover it.

**Phase 2 and later:** only after real manual data refresh is accepted consider a minimal filing-release alert, scheduling or widening instrument coverage. No new tables by default, no full-index deep research, no auto-trade, no second accounting ledger.

## Owner's product decision

**Make the existing core workflow usable before adding complexity.** Do not build the proposed five-table Research Attention schema, autonomous research orchestration, scanner-wide deep research, portfolio rotation or backtesting in Phase 1. Existing research foundations and deterministic investment gates stay in force.

Product promise: choose one supported stock and get a **source-/model-traceable Fair Value + verified price context + research/valuation/quality/readiness status + explicit blockers**, without a fabricated BUY signal.

Phase 1 can use an **existing read-only report/view/dashboard surface**, not a new database or frontend platform.

### Do now: Phase 1 — Working MVP

- Select **exactly three supported tickers**: **ACN (financial freshness / Valuation input control), ADBE (valuation-to-hardening lineage mismatch), PINS (quality / price / Decision blockers)**. These are scoped regression cases, **not buy recommendations**; the historical ACN positive-readiness result is dated and must not substitute for a current live gate readback.
- Read from already deployed, authorized Supabase sources: `fwios.v_research_readiness_current_v1` for deterministic readiness, `fwios.v_dashboard_valuation_map` for fair-value/market context, `fwios.v_scanner_current_v1` for current scanner compatibility, and existing valuation/evidence/decision lineage as needed. Do not replace these as authoritative without an explicitly tested cutover.
- Produce one compact user-facing result: ticker, latest verified canonical price and session, bear/base/bull/PW fair value (when available), valuation model and run ID/as-of, research readiness, valuation readiness, quality-hardening gate, investment-review readiness, decision price/mispricing gates and **specific blocker**. A scanner rank/score is **not** a buy signal.
- Show **BLOCKED / WAIT / REVIEW / DATA MISSING** rather than inventing a missing metric or forcing a recommendation. Separate “valuation exists” from “investment actionable”; preserve `auto_trade=false`.
- Price freshness must come from the existing canonical market-data gates; broker verification remains required before any real transaction. Keep the scanner portfolio-independent and keep transactions/accounting in the Investment Portfolio Tracker.
- Use manual/on-demand PREVIEW research where necessary; `fwios.apply_research_ingest_v1` requires a separately explicit APPLY instruction, service-role access and the existing validation gateway. Do **not** enable a new cron, queue, scheduled ChatGPT task, data migration, or provider subscription.
- Fix only a proven P0 end-to-end blocker in a separately scoped code PR, with existing deterministic regression parity and read-only/rollback acceptance.

### Phase 1 acceptance / Definition of Done

1. A single supported ticker can be selected and returns one coherent, inspectable report from canonical existing views.
2. ACN's existing `investment_review_ready=true` is accurately shown as **review readiness**, never an execution instruction, and any independent legacy price/decision gate disagreements are visible.
3. ADBE and PINS remain accurately blocked until their actual lineage, model/quality and price issues are resolved; “large apparent upside” never overrides a blocked gate.
4. Report shows as-of/session timestamps, model/run identity, relevant evidence/source references or a clear unavailable marker, and deterministic reason codes; no unsourced facts.
5. Missing, stale, contradictory, unsupported and null inputs fail closed. Report does not invent targets, quality scores, revisions or a trading recommendation.
6. Existing production ADBE/PINS score/rank/valuation and scanner/portfolio read compatibility do not regress; no portfolio write, new schema, new schedule, or auto trade.
7. At least three read-only E2E regression cases are documented, including one success-state and two expected blocks. Where live end-user presentation still needs implementation, explicitly state **not complete**, even if SQL queries succeed.

## Live read-only gap audit — 2026-10-26

Data sources: `fwios.v_research_readiness_current_v1`, `fwios.v_dashboard_valuation_map`, `fwios.v_scanner_current_v1`, `fwios.v_latest_decision_snapshots`, `fwios.v_candidate_quality_hardening_current`, and `fwios.v_valuation_mispricing_current`.

| Check | Observed | MVP implication |
| --- | --- | --- |
| Active stocks in readiness view | 64 | Not full S&P 500. No U1 expansion. |
| Research ready | 27 / 64 | A functioning subset already exists. |
| Valuation ready | 27 / 64 | Reuse models/runs; do not build an all-sector model registry. |
| Quality hardened | 1 / 64 | Core bottleneck after valuation. |
| Investment review ready | 1 / 64 | Investment review readiness != permission to buy. |
| Scanner v1 scored / ranked | 27 / 64 | Current scanner presentation may rank a name that is not investment-review ready; label accordingly. |
| Research controlled APPLY receipts | 0 at previous inspection | Do not claim ChatGPT production ingestion acceptance based on old legacy research. |

### Three E2E regression cases

- **ACN — positive readiness control:** `RESEARCH_READY=true`, `VALUATION_READY=true`, `QUALITY_HARDENED=true`, `INVESTMENT_REVIEW_READY=true`, `blocking_reason=NULL` in the readiness view (2026-10-23 price session). **However**, `v_dashboard_valuation_map.system_signal='PRICE VERIFY'` even while its readiness gate is ready; these are different product semantics. Report both without inferring BUY or silently normalizing them.
- **ADBE — expected block:** research/valuation ready; newest production-eligible valuation in readiness is `VAL-ADBE-SAAS-Q3-20260911`, while latest hardening snapshot references `VAL-SUPA-ADBE-SAAS-20260905`. The hardening snapshot has an overall `PASS`, yet the latest-valuation lineage gate yields `QUALITY_HARDENING_FAIL`; **do not call this a newly failed fundamental quality check**. Decision snapshot also shows revision/chase evidence blocked. Old mispricing snapshot's price is stale; a newer canonical market price alone does not rewrite historical mispricing/decision snapshots.
- **PINS — expected block:** research/valuation ready, quality-hardening snapshot `REVIEW` (owner-earnings/value-trap/robustness), investment-review readiness blocked. Its existing mispricing/decision path also carries a historical price-conflict/staleness block. Keep the new verified daily close and legacy decision price gate separate until appropriately refreshed and reconciled.

**Do not trade from this audit.** Numeric valuation and price outputs are not repeated here; re-read authoritative source/session and model/version when actually viewing the report.

### Runnable MVP-1 read-only query — validated

The [runnable pilot report](../../queries/mvp_readonly_fair_value_status_v1.sql) is a **plain SELECT**, not a deployed view/function. On 2026-10-26 it returned **3/3 pilot rows** in live read-only Supabase inspection:
- ACN: `REVIEW_READY_NOT_TRADE`, with an **independent legacy decision/price gate disagreement** to display and resolve before any actionable claim.
- ADBE: `QUALITY_OR_LINEAGE_REVIEW`, latest hardening-to-valuation run mismatch.
- PINS: `QUALITY_OR_LINEAGE_REVIEW`, no fabricated promotion despite existing Fair Value.

This validates an existing-view **data report slice only**. It does **not** yet establish a usable deployed end-user interface, refreshed price-dependent Decision Snapshot or full manual research APPLY acceptance.

### Minimal read-only SQL diagnostic

```sql
SELECT
  r.ticker,
  r.readiness_state,
  r.research_ready,
  r.valuation_ready,
  r.quality_hardened,
  r.investment_review_ready,
  r.blocking_reason,
  r.price_as_of AS readiness_price_session,
  r.valuation_run_id AS readiness_valuation_run_id,
  v.price_session_date AS report_price_session,
  v.current_price,
  v.bear_fv,
  v.base_fv,
  v.high_fv,
  v.fair_value,
  v.valuation_as_of,
  v.valuation_run_id AS report_valuation_run_id,
  v.price_gate,
  v.mispricing_gate,
  v.system_signal,
  s.scan_status,
  s.scanner_score
FROM fwios.v_research_readiness_current_v1 AS r
LEFT JOIN fwios.v_dashboard_valuation_map AS v ON v.ticker = r.ticker
LEFT JOIN fwios.v_scanner_current_v1 AS s ON s.ticker = r.ticker
WHERE r.ticker IN ('ACN', 'ADBE', 'PINS')
ORDER BY r.ticker;
```

This diagnostic **only compares** existing read models. It does not unify their semantics or grant production execution authority. For a deployed report, inspect each view's access contract and prefer the existing authorized backend/Sheet boundary.

## Next implementation slice — one PR at a time

**2026-10-28 ordering:** First complete ACN's read-only financial-metric gap audit, then ADBE's lineage reconciliation, then PINS's blocker reconciliation, followed by the three-ticker Final Acceptance. The earlier numbered MVP-1/2/3 steps below describe reusable implementation mechanics, **not** authorization to widen the pilot.

1. **MVP-1: Read-only report/Surface.** Wire one minimal report using existing views and show both canonical freshness and independent deterministic gates. First deliverable: reproducible ACN, ADBE and PINS outputs with no false actionable signals. If no code is needed, document which existing screen already meets the requirement and close this step only after user-facing acceptance.
2. **MVP-2: Focused blocker repair.** Fix the first reproduced high-impact mismatch (e.g., ADBE stale hardening-to-valuation lineage or legacy price-gate interpretation) through a separate tested PR. Do **not** mutate a gate merely to make a name eligible.
3. **MVP-3: Manual working usage.** Validate one real end-to-end research refresh in PREVIEW, review provenance, then only with explicit separate authorization use the controlled APPLY path; verify report/readiness after it. This is **not** an automation or cutover approval.

**Stop scope:** No new tables; no market provider expansion; no S&P500-U1 resumption; no autonomous research scheduling; no lifecycle cutover; no portfolio rotation; no backtest build; no automatic trading.

## Later phases (not authorized to implement by this docs PR)

- **Phase 2 — Basic automation:** reuse existing market-close updates; add narrowly scheduled **derived alert/report refresh only if** manual report acceptance proves usefulness and quotas are verified. No novel research scheduler by default.
- **Phase 3 — Research attention:** return to [Issue #38](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/38) and versioned lifecycle/resource policy **only when** observed volume/cost requires it. The five-table Research Attention schema is **deferred**, not approved.
- **Phase 4 — Rotation and backtesting:** owner-scoped advisory and point-in-time evaluation, [Issue #39](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/39) cutover only after parity and separate authorization.

## Source authority and safeguards

- [AGENTS.md](../../AGENTS.md), [system contract](../../contracts/system-contract.yaml) remain authoritative and unchanged.
- [Master roadmap](../00_SYSTEM_ROADMAP.md) now gives the MVP workstream priority; historical numbered migration sequence is retained for context, **not** an instruction to build Issue #38 next.
- [Proposed strategy overlay](VALUE_ENTRY_ROTATION_STRATEGY_ROADMAP_20261023.md) remains a future feature catalogue, not a prerequisite for this minimum read-only report.
- No Supabase schema/data/RLS/provider/cron modification, no Sheet/accounting change, no new billable resource and no executable trade were performed in this documentation/audit phase.
