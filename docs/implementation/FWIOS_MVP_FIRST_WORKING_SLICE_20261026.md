# FWIOS — MVP-First Delivery & End-to-End Read-Only Audit

Date: **2026-10-26 (Asia/Bangkok)**  
Status: **Owner-approved reprioritization; roadmap/audit only — runtime MVP not yet accepted**  
Contract: `FWIOS-CONTRACT-0.87.19` (unchanged)  
Supabase project: `focused-wealth-investment-os` (`ysjbmeukwbfnxnwqchuq`)  
Baseline inspected: GitHub `main` `298fbb8e7aa09126c049cf218036e811f40444cd`. Live Supabase was read-only inspected on 2026-10-26.

## Owner's product decision

**Make the existing core workflow usable before adding complexity.** Do not build the proposed five-table Research Attention schema, autonomous research orchestration, scanner-wide deep research, portfolio rotation or backtesting in Phase 1. Existing research foundations and deterministic investment gates stay in force.

Product promise: choose one supported stock and get a **source-/model-traceable Fair Value + verified price context + research/valuation/quality/readiness status + explicit blockers**, without a fabricated BUY signal.

Phase 1 can use an **existing read-only report/view/dashboard surface**, not a new database or frontend platform.

### Do now: Phase 1 — Working MVP

- Select **1–3 supported tickers**; pilot **ACN (positive readiness control), ADBE (valuation/hardening lineage issue), PINS (hardening and price-gate issue)**. These are regression cases, **not buy recommendations**.
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
