# FWIOS — AI Research Manager / Phase 1 Handover (2026-10-28)

**Purpose:** New-chat handover, ownership decisions, verified read-only baseline and proposed smallest next work. **Status:** documentation/architecture decision; runtime implementation **NOT** authorized by this change. This document supersedes earlier suggestions that ChatGPT should be the primary data collector.

**Repository:** `ChumponphatRangsee/focused-wealth-investment-os`  
**Source precedence:** Live Supabase/deployed contracts and current GitHub `main` > dated handover snapshots. Recheck on every new chat.

## 1. Owner decisions — binding delivery scope

1. **Phase 1 business pilot = ACN, ADBE, PINS only.** Do not automatically audit/refresh fundamentals or Fair Values for the other 28 valued stocks, the existing 64 tracked stocks or the full S&P 500, even after these three pass. Broader coverage needs a *separate* owner decision. Keep the existing 64-ticker EOD price collector operating.
2. Use the **existing Google Sheet Valuation Map** as the user-facing surface. No new dashboard, report tab or separate portfolio ledger.
3. **Division of responsibility:** API/Workers = quantitative data collectors; Supabase = canonical state, provenance and deterministic policy authority; ChatGPT = **Research Manager** (prioritize proposed stock-research tasks and explain gaps/deltas); Valuation Engine = model-based Fair Value; Decision Engine = fail-closed investment eligibility. ChatGPT must not manufacture financial facts, decide S&P 500 membership from opinion, independently promote/demote authoritative lifecycle state, or produce actionable buy/auto-trade instructions.
4. **State-first, delta-based** workflow. Inspect what is already stored (filing identity, fiscal periods, evidence, canonical metrics, valuation run/model version) before asking for new documents. Compare with new SEC filing metadata/fingerprints. `NO_CHANGE` = no deep research. New/amended/restated filing, missing model input or verified conflict = tightly scoped proposed work.
5. **Controlled writes:** structured evidence + metric JSON → deterministic `PREVIEW` / verification → separate authorization for `APPLY` → append-only verified observations → eligible valuation → existing Quality/Revision-Chase/Scoring/Decision gates. A JSON-format PASS is **not** proof that a financial fact is accurate or economically current.
6. Full Research Attention, broad new-stock screening/selection and portfolio rotation/backtesting remain **future/deferred** (Issue #38 and related plans). A three-ticker design/diagnostic pilot does not authorize an autonomous stock manager or a new production scheduler.

## 2. Architecture, ownership and boundaries

| Component | Primary responsibility | Must not do |
|---|---|---|
| Tracked universe / existing lifecycle | Authoritative ticker identity and scope | Automatically expand Phase 1 |
| Research State Resolver (proposed read-only query/view/function) | Report stored filing identity, fiscal periods, required valuation inputs, evidence IDs, metric versions, current run and gaps | Declare external filings current without checking SEC |
| SEC EDGAR / XBRL collector | Check published filings, amendments and machine-readable company facts; use accession/form/CIK/fingerprint | Rewrite canonical observations on its own |
| Twelve Data + Alpha Vantage | EOD stock prices and controlled independent verification | Substitute price freshness for financial-statement freshness |
| Supabase Cron/Workers | Reliable low-cost scheduling, quotas, retries, evidence transport | Automatically bypass validation, owner approvals or quota policy |
| ChatGPT Research Manager (proposal only) | Prioritize specific work for old/new candidate stocks; recommend `NOOP`, `COLLECT_DATA`, `RESEARCH_EXCEPTION`, `REVALUE_CANDIDATE` or `HUMAN_REVIEW` with reasons | Override policies, become trusted source for numeric facts, auto-change authoritative universe |
| `fwios.preview_research_ingest_v1` | Validate evidence/metric payload without production mutation | Claim all economic correctness is proven by schema PASS |
| Controlled `APPLY`, canonical metrics and valuation | Authorized immutable persistence, versioned model/run lineage | Silent overwrite, hard delete, auto-trading |

**Intended narrow sequence**

1. Read Supabase `Research State` for one approved pilot ticker.
2. Inspect latest SEC submission/accession/fact metadata (prefer existing shadow evidence, verify freshness).
3. Compare source identities and accounting periods; return `NO_CHANGE` without Deep Research if nothing materially new.
4. For verified changes/gaps, ChatGPT proposes a bounded research task. Deterministic APIs collect quantitative facts; AI handles prioritization and difficult qualitative exceptions.
5. Produce the existing `chatgpt_research_payload_v1` (actual verified evidence and metrics), run `fwios.preview_research_ingest_v1(p_payload jsonb)`.
6. `BLOCKED` → precise reason codes / review queue. `PASS` → an *eligible preview*, **not automatic production permission**.
7. After **separately explicitly authorized** controlled `APPLY`, generate eligible valuation with source/model lineage, validate price/mispricing/quality and existing Valuation Map parity.

### Identity / freshness rules

- Filing: ticker/CIK, SEC accession, form (10-K, 10-Q, 8-K and applicable amendments), submitted/published dates, document URL, payload fingerprint.
- Accounting metric: canonical metric code, source value + unit/currency, fiscal year/quarter, period type/start/end, `reported_at`, associated evidence IDs, normalization version and conflicts.
- Valuation: model ID/version, run ID, required input identities, source observations, as-of date, production eligibility.
- **Never treat the latest ingestion timestamp or latest EOD market price as proof that company fundamentals are fresh.** A newer 10-Q does not replace an entire previous annual period; amendments/restatements require explicit supersession semantics and preserved history.
- Distinguish `FAIR_VALUE_AVAILABLE` from `INVESTMENT_ACTIONABLE`. A justified Quality/Risk/Chase REVIEW or BLOCKED is an acceptable result, not a requirement to loosen policy.

## 3. Read-only baseline checked 2026-10-28 (not perpetual truth)

- GitHub `main` SHA at this check: `f3b96b3e6b869151c1bf388ff527f02373b2d471`. **PR #92 (MA Clean-Room E2E)** remains OPEN/unmerged; MA is a separate technical proof, **not** a fourth Phase 1 business pilot.
- **PR #93**, `docs/phase1-pilot-scope-lock-20261028`, is OPEN/unmerged and carries this three-ticker owner scope lock and handover changes. Do not state that changes are on `main` until merged.
- `fwios.market_daily_closes` has 64 records for each of 2026-10-23, 26 and 27. Continue the established EOD close jobs and provider verification; this is not an all-64 fundamentals-research approval.
- `fwios.metric_observations`: **506** rows across **29** instruments, including 53 observations inserted Oct 26–27. These inserts are not evidence of a general-purpose autonomous canonical fundamental refresh.
- SEC shadow collector stores `SEC_SUBMISSIONS` and `SEC_COMPANY_FACTS` in `fwios.decision_refresh_shadow_evidence`; latest Oct 28 shadow run: **46/46 jobs PASS**, 27 candidates, `authoritative_write=false`. An evidence collector succeeding does not mean current canonical model inputs were refreshed.
- `fwios.preview_research_ingest_v1(p_payload jsonb)` checks `schema_version=chatgpt_research_payload_v1`, requested mode, ticker, evidence URLs and tiers, source/fiscal dates, metric definitions/units/periods and conflicts. `fwios.apply_research_ingest_v1(p_payload jsonb)` requires `mode=APPLY` and a passing preview, with idempotent fingerprint receipt. Existing gateway and existing schema are to be **reused**, not replaced without evidence.
- **Confirmed ops bug (separate lane):** active Cron `fwios-opportunity-quality-refresh` (jobid 10) failed Oct 27 and 28; it calls retired `fwios.refresh_opportunity_quality_v2(date,text)`, while live `fwios.refresh_opportunity_quality_v3(date,text,boolean)` exists. Do not merely substitute names/arguments; check required human authorization, invocation semantics and tests before a separately approved production change.
- The scheduled ChatGPT → Supabase write path is **not verified** for unattended runs; a manually connected Supabase tool is not proof that every ChatGPT Scheduled Task can call it or that it should receive privileged writes. If permission/workflow unsupported, consider Supabase Cron → OpenAI API → controlled validation as an **alternative design requiring approval and cost review**, not an authorized deployment.

## 4. Phase 1 ordered task backlog

| Order | Priority | Task | Read-only acceptance or separately authorized next gate |
|---|---|---|---|
| 0 | P0 | Verify `main`, PR #92/#93, `contracts/system-contract.yaml` and live Supabase | Capture timestamped sources; distinguish deployed vs merged |
| 1 | P0 | **ACN financial data gap audit** | Source/issuer filing and SEC facts vs existing canonical metric values; reporting period, units, source IDs, model-required input inventory and actual missing/stale/conflicting fields |
| 2 | P0 | Design **Research State Resolver** reusing existing tables/views | One ticker returns stored source/version/fiscal periods, authoritative inputs, valuation run, explicit gaps. Start SELECT-only; no extra tables by default |
| 3 | P0 | Design **Filing Delta Detection** reusing current SEC collector/fingerprints | `NO_CHANGE`, `NEW_FILING`, `AMENDED`, `MISSING_METRIC`, `CONFLICT`, `REVIEW_REQUIRED` with traceable reasons; handle restatements |
| 4 | P1 | Restricted AI Research Task Proposal contract for **ACN/ADBE/PINS only** | Ticker, trigger identity, action, priority, reasons, source references and expected API work; no state mutation |
| 5 | P1 | API-led data ingest integration with existing JSON `PREVIEW` | Exact supported evidence/metric structure, unit and fiscal identity, duplicates/conflicts, independent primary-source verification, no automatic APPLY |
| 6 | P1 | **ACN** controlled end-to-end revaluation when separately approved | Current evidence or explicit stale block, immutable model/run lineage, deterministic Fair Value and existing Valuation Map parity |
| 7 | P1 | **ADBE** valuation-to-hardening lineage then **PINS** price/mispricing/Quality/Decision blockers | Exact current source/run identities, legitimate gates preserved, regressions and reason codes |
| 8 | P1 | Three-ticker MVP acceptance and quota/cost/error taxonomy | Stable, reproducible results for ACN/ADBE/PINS, no forced BUY/PASS, **no 28-stock expansion** |
| Ops | Separate | Diagnose stale Opportunity Quality Cron job #10 | Read-only inspect cron target/contract/regressions; propose minimal approved fix |
| Future | Deferred | Full Research Attention lifecycle / broad AI-managed stock queue, #38 | Owner authorization needed; not Phase 1 |

### Minimal next action

**Read-only ACN audit + existing-object inventory.** Do not build a new AI scheduler or write a new DB table first. Show precise evidence gaps, the smallest State Resolver SELECT contract, and Delta Detection inputs/output. Use the findings to decide whether a narrow reviewed implementation PR is justified. If any code or production data change becomes necessary, request a separate task/approval.

## 5. Safety, acceptance and handover instructions

- Preserve historical evidence, metric observations, valuation runs, snapshot/lineage IDs; **no hard deletes or silent overwrites**.
- No weakening valuation, Quality Hardening, revision/chase, core scoring, price verification, risk or decision thresholds.
- `auto_trade=false`; no broker orders, account balances, holdings/transactions, approvals or portfolio accounting mutations.
- Phase 1 explicitly excludes full autonomous Research Attention, all-28 valuation review, all-S&P500 work, new dashboard, speculative new resource infrastructure and portfolio rotation/backtesting.
- Existing Production `APPLY` and valuation promotion are **not** approved merely by writing this document.
- If source facts and stored metrics disagree, show `BLOCKED/REVIEW` and source identities; do not invent a corrected value.

### Paste into a new chat

> Continue the **Focused Wealth Investment OS / S&P500 Scanner** project using `docs/implementation/FWIOS_AI_RESEARCH_MANAGER_HANDOVER_20261028.md` in the latest appropriate branch, plus `docs/CURRENT_STATUS.md`, `docs/00_SYSTEM_ROADMAP.md` and the active contract. Verify live GitHub `main`, PR #92 and #93 and live Supabase first; do not treat dated docs as current live truth. **Read-only analysis only.**
>
> Owner scope: **Phase 1 ACN, ADBE, PINS only**, no other 28-valued-stock/full-index financial research. Existing 64-stock EOD feed continues. Architecture direction: **APIs/Workers collect source facts; ChatGPT manages proposed research tasks; Supabase/Policies verify, store and decide; Valuation Engine computes Fair Value**. Use state-first, delta-based checks. Full Research Attention #38 and production automation remain deferred.
>
> **First task:** ACN canonical financial source/period/metric gap audit, inventory existing read-only objects, and propose a minimal Research State Resolver SELECT plus SEC Filing Delta Detector output and acceptance criteria. Then outline ADBE/PINS lineage/blocker cases. Flag failed Opportunity Quality Cron #10 separately. **Do not** create schedules, mutate Supabase, APPLY research, deploy migrations, merge PRs, change policy thresholds, or trade without separate authorization.

## 6. References

- [Current Status](../CURRENT_STATUS.md)
- [Master Roadmap](../00_SYSTEM_ROADMAP.md)
- [MVP First Working Slice](FWIOS_MVP_FIRST_WORKING_SLICE_20261026.md)
- [Clean-Room E2E Handover (separate MA technical proof)](FWIOS_CLEAN_ROOM_E2E_HANDOVER_20261027.md)
- [PR #92 — Clean Room](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/92)
- [PR #93 — Phase 1 scope / this handover](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/93)
- [Issue #38 — Research Attention (deferred)](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/38)
