# FWIOS MVP-1 — SEC Shadow Facts → Canonical Financial Metrics Handover

**Prepared:** 2026-10-26 Asia/Bangkok  
**Status:** Read-only investigation completed; implementation **NOT started**; no new scheduler or production writes deployed  
**GitHub main starting baseline:** `da3ee7264b86930da66394a945200da9d58359fc` (merged PR #73; re-verify before any edit)  
**Repo:** [ChumponphatRangsee/focused-wealth-investment-os](https://github.com/ChumponphatRangsee/focused-wealth-investment-os)  
**Supabase project:** `ysjbmeukwbfnxnwqchuq`  
**Existing Google Sheet:** [Focused Wealth Dashboard - Chumponphat](https://docs.google.com/spreadsheets/d/17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8/edit) → **`Valuation Map`** tab (retain; no new dashboard)  
**Source of truth order:** live Supabase / deployed code > GitHub active contracts > dated implementation docs > historical handovers.

## 1. Owner intent and exactly what to solve next

Owner wants a **working MVP before any extra features**. Existing `Valuation Map` is sufficient as the only user-facing display. Priority is **complete, correct, up-to-date source-backed prices and financials persisted in Supabase, then current Fair Value**, not new dashboards, five Research Attention tables, auto-trading, backtesting or full S&P 500 expansion.

The key question was: **“If a SEC schedule already exists, why aren't new financial numbers in the Valuation Map?”**

**Verified answer:** SEC data **is fetched** each workday, but the current worker **only records compact SEC submissions + company facts to SHADOW evidence**. It does **not normalize these facts into the authoritative `metric_observations`, does not issue an approved production ingest receipt, and does not re-run valuation.** The current refresh is intentionally `SHADOW`, `authoritative_write=false`. There is no justification for another duplicate SEC polling schedule at this stage.

## 2. Live system verification — 2026-10-26 (read-only)

| Area | Evidence observed | Interpretation |
| --- | --- | --- |
| EOD market close | Oct 19–23 `fwios.market_daily_close_runs` daily PASS, each **64/64** of currently tracked 64 stocks. Oct 23 is last completed U.S. market session before Monday Oct 26 U.S. open. | Existing price schedule works for current supported universe, **not full S&P 500**. |
| Price provenance / independent check | Oct 23 Twelve Data 64 regular-close observations, source tier A, provenance PASS, source URLs; Alpha Vantage overlapping 13 stocks showed 0–0.0261% differences. | Strong subset check; **51 stocks were not independently cross-provider validated** in that comparison. |
| Sheet ↔ database | All 28 rows in Google Sheets `Valuation Map` equal `fwios.v_dashboard_valuation_map` on ticker, close/session, bear/base/high/PW FV and upside to display precision. | UI parity is not the priority bug. |
| Valuation age | `v_dashboard_valuation_map` existing 28 valuation model as-of dates fall **Sep 4–11, 2026**. | Updating stock prices does **not** refresh intrinsic valuations. |
| Canonical financial metrics | `fwios.metric_observations`: **453 rows**, **28 of 64** current tracked stock instruments, **131 distinct metric codes**, latest insert Sep 30, newest `reported_at` Sep 10. | Canonical metrics lack recent reporting periods for several names. |
| SEC polling | `fwios.decision_refresh_jobs`: `SEC_SUBMISSIONS` jobs PASS including ACN, JPM, NFLX on **Oct 26**; `fwios.v_thesis_sec_filing_current` refreshed same day. | SEC identification/fetch works. |
| SEC evidence destination | `fwios.decision_refresh_shadow_evidence` contains `SEC_SUBMISSIONS` and `SEC_COMPANY_FACTS` from `SEC_EDGAR`; ACN, JPM, NFLX observed on Oct 26. | Raw/compact facts are **already in the DB**, but in separate SHADOW store. |
| Production write protection | `fwios.decision_refresh_runs.mode='SHADOW'`, `authoritative_write=false`; latest overall run may be `BLOCKED` due other capability jobs despite SEC-specific PASS. `fwios.research_ingest_receipts_v1` had **0 rows**. | No authorized canonical research APPLY from current scheduled SEC worker. |
| Latest primary filings detected | ACN **10-K filed Oct 16**, NFLX **10-Q filed Oct 21**, JPM latest filing view **8-K Oct 20** (not necessarily its latest relevant quarterly financial statements). | Detection is not the same as period-aware source-validation/metric ingestion; inspect appropriate filing per needed metric. |

**Examples of stale canonical metrics:** ACN latest `metric_observations.reported_at` June 18 (company reported Q4 FY2026 Oct 1); JPM July 14 (Q3 reported Oct 13); NFLX July 16 (Q3 reported Oct 20). These new releases were not reflected in canonical metric observations as of this audit.

### Exact existing cron paths (observed)

- `fwios-shadow-decision-refresh-enqueue`: **`10 6 * * 1-5`** (database cron interpreted in UTC; re-confirm deployment timezone before modifying).
- `fwios-shadow-decision-refresh-worker`: **`*/5 * * * *`**, polls queue. SEC and selective price/consensus jobs share this shadow run.
- `fwios-market-daily-close-enqueue`: **`5 20,21 * * 1-5`** plus New York time guards around **16:05 U.S. Eastern**.
- `fwios-market-daily-close-worker`: **`*/2 20-22 * * 1-5`** with NY market-close time guards.

**Do not add another SEC fetch Cron until the existing raw→canonical path is audited and one complete manual refresh is proven.** Do not confuse Cron runner frequency with a guarantee that every call ingests an updated accounting period.

### Verified implementation boundary

File: [supabase/functions/decision-refresh-worker-v1/index.ts](../../supabase/functions/decision-refresh-worker-v1/index.ts)

- `processSec(job)` fetches SEC `/submissions/CIK...json` and `/api/xbrl/companyfacts/CIK...json`.
- `compactFacts()` takes a **small explicit list** of `us-gaap` tags (revenue, net income, operating cash flow, capex, cash/debt, SBC, diluted shares, diluted EPS), truncating each unit's facts to its latest 12 source rows. It does **not** claim complete statement coverage or complete company-specific extension tags.
- `put()` stores `SEC_SUBMISSIONS` and `SEC_COMPANY_FACTS` inside `fwios.decision_refresh_shadow_evidence`.
- No path in this worker commits those SEC facts to `fwios.metric_observations`, updates the valuation engine, or grants investment eligibility.
- Worker response explicitly declares `mode:'SHADOW'` and `authoritative_write:false`.

Controlled ingestion contract: [PR2 Controlled Research Ingest](PR2_CONTROLLED_RESEARCH_INGEST_V1.md) and [AGENTS.md](../../AGENTS.md) require validated `fwios.preview_research_ingest_v1(jsonb)` before separately authorized `fwios.apply_research_ingest_v1(jsonb)`. The research gateway is **service-role only**; do not circumvent with direct inserts into `evidence_records`, `metric_observations` or `research_candidates`.

## 3. Target MVP-1 data path (proposed, not implemented)

```text
Existing SEC Scheduled Fetch (KEEP)
  ├─ SEC_SUBMISSIONS              ┐
  └─ SEC_COMPANY_FACTS           ├─> decision_refresh_shadow_evidence (already live)
                                 │
            [MISSING MVP BRIDGE] │
                                 └─> Select material/new filing & exact reporting period
                                         ↓
                                     Normalize model-required metric codes, units, currency
                                         ↓
                                     Source / fiscal-period / conflict / completeness gates
                                         ↓
                                     Controlled PREVIEW (read-only)
                                         ↓   (separate explicit owner authorization)
                                     Controlled APPLY (service-role, idempotent)
                                         ↓
                                     evidence_records + metric_observations + ingest receipt
                                         ↓   (separately verified model update)
                                     new production-eligible valuation run + hardening lineage
                                         ↓
                                     EXISTING Valuation Map; check freshness & no false BUY
```

**Critical distinction:** getting XBRL source data into a SHADOW table is not equivalent to automatically approving it for valuation. Safe promotion needs model-specific normalization with exact `form`, `filed`, `start/end`, `fy/fp`, currency/unit, accession reference, conflict resolution, and source availability time. Avoid pulling the wrong `FY` versus `Q` frame or comparing cumulative YTD cash flow to a standalone quarter. The current `compactFacts` last-12-per-unit selection can omit required historical periods.

## 4. Next chat — step-by-step execution (start at Step A)

**A. Read and reverify (read-only first).** Read `AGENTS.md`, `contracts/system-contract.yaml`, `docs/CURRENT_STATUS.md`, this handover, [MVP-first plan](FWIOS_MVP_FIRST_WORKING_SLICE_20261026.md), [research ingest contract](PR2_CONTROLLED_RESEARCH_INGEST_V1.md), current `decision-refresh-worker-v1` source; confirm latest `main`, cron jobs and actual SEC/CANONICAL rows in live Supabase. Do not assume any doc alone proves production state.

**B. Choose one pilot: ACN.** Read latest ACN SEC 10-K (Oct 16) SHADOW evidence, select only the model-required accounting inputs, compare with current `metric_observations` and `valuation_runs`, list missing/obsolete inputs with forms, accession, fiscal-period, source unit, source URL, and contradictions. Include annual and Q4 date semantics; check financial arithmetic against primary source and required historical comparisons.

**C. Design the smallest converter using existing structures.** Produce a deterministic, testable **SHADOW → validated canonical research payload** mapper. Extend tag coverage only for **actual missing model inputs** and keep source URLs/filing/report dates. For missing company-specific data, mark BLOCKED / MANUAL PRIMARY EVIDENCE; never infer. Decide how to prevent repeated work when a filing/accession fingerprint is unchanged. Prefer existing idempotency in the ingest gateway; do **not** add five Research Attention tables or an unrelated queue.

**D. Test PREVIEW without writes.** Validate typed metrics via `fwios.preview_research_ingest_v1`; assert provenance, period, source precedence, exact unit/currency and conflict semantics, plus idempotent retry. Write tests for fiscal YTD/quarter mix, repeated accession, unverified source, unsupported model. Preserve explicit failures.

**E. Only after explicit future authorization:** attempt controlled `APPLY` with service-role through the existing gateway. Verify one new audit receipt, accepted evidence and metrics, no overwrite, and point-in-time lineage. Then rerun production-eligible valuation only through its approved/versioned route after model inputs are complete and validated. **Current handover request does not grant this write authorization.**

**F. Recheck existing Valuation Map.** Compare Sheet with backend on price session, existing model-as-of, bear/base/high/PW FV, eligibility/blockers; ensure a new market price does not mask an old valuation. Then repeat for JPM and NFLX.

**G. Decide scheduling later.** Once **manual end-to-end ingestion + revaluation** works, propose a **minimal** post-SEC-collection normalization/validation trigger keyed by new accession + needed metrics. Never poll all financial API data repeatedly by default, create duplicate EOD stock jobs, or auto-APPLY unverified source.

## 5. Scope and release/DoD

- One company ACN can produce reproducible, source-cited, period/unit-correct PREVIEW metrics for **new** filings; accepted and rejected inputs recorded.
- Proven one-shot successful production ingestion and valuation *only when separately authorized*, with immutable receipt/lineage, current model version, no duplicate canonical writes.
- `Valuation Map` remains the sole user-facing view, and valuation freshness/blocked state is honest. No new tab/dashboard.
- Existing 64-stock EOD price capture and Google Sheet compatibility do not regress.
- Research Attention #38, new schema, broad S&P500 universe, auto trade, second portfolio ledger, live-score policy changes and shadow→production read cutover remain **out of scope**.
- No cron/Edge/schema/Sheet/trading data was changed by creating this handover.

## 6. Links / provenance

- [Previous merged data-reliability scope PR #73](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/73)
- [Previous MVP-first roadmap PR #72](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/72)
- [Current navigation/status](../CURRENT_STATUS.md)
- [Master roadmap](../00_SYSTEM_ROADMAP.md)
- [Source/ingest contract](PR2_CONTROLLED_RESEARCH_INGEST_V1.md)
- [Current worker implementation](../../supabase/functions/decision-refresh-worker-v1/index.ts)
- [Shadow decision refresh design](../08_AUTO_DECISION_REFRESH_SHADOW.md)

**Safe new-chat kickoff (paste as the first prompt):**

> Continue FWIOS MVP-1 Data Reliability from `docs/implementation/FWIOS_MVP1_SEC_TO_METRICS_HANDOVER_20261026.md` in `ChumponphatRangsee/focused-wealth-investment-os`. Read `AGENTS.md`, `contracts/system-contract.yaml`, `docs/CURRENT_STATUS.md`, the handover and current `decision-refresh-worker-v1`; verify the latest live Supabase state read-only. No new dashboard: existing Valuation Map stays. The SEC schedule already fetches SHADOW SEC_SUBMISSIONS/SEC_COMPANY_FACTS; canonical metric_observations and valuation have not refreshed. Start with ACN; audit the SEC 10-K Oct 16 against required valuation metrics, propose the minimal SHADOW→PREVIEW normalized payload bridge, and implement/test only non-production PREVIEW changes through a scoped GitHub PR. Do not run APPLY, change cron, write production, enable automation or merge a cutover without separately discussing the exact change and authorization.
