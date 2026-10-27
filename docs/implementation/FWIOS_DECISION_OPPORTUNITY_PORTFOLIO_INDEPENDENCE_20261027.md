# FWIOS MVP-1 — Portfolio-independent Decision / Opportunity Cutover

Date: **2026-10-27 Asia/Bangkok**  
Status: **LIVE APPLIED / 35-35 ACCEPTANCE PASS**  
Contract baseline before cutover: `FWIOS-CONTRACT-0.87.23`  
GitHub baseline inspected: `main@7a9f4f98852a25137f7ab7c791ca45c68fb364a2`  
Supabase project: `ysjbmeukwbfnxnwqchuq`  
Live migration: `20261027035558_decision_opportunity_portfolio_independence_v1`

## 1. Why this cutover exists

The scanner/dashboard architecture is portfolio-independent, but the downstream Decision bridge still inherited legacy Portfolio Fit and portfolio-batch requirements. That stale dependency blocked NFLX entirely and caused ACN/EOG audit Decisions to carry stale Portfolio Fit blockers.

The production Opportunity Quality score was already portfolio-independent, but its active read view still required a Portfolio Scenario before final human-review eligibility.

This slice removes those legacy dependencies from the active Decision and Opportunity path without deleting historical portfolio data.

## 2. Production path after cutover

Active research/selection path:

`Evidence → Canonical Metrics → Valuation → Mispricing → Quality Hardening → Scoring → Decision → Opportunity Quality → Human Review`

Portfolio Fit, current holdings, portfolio batch, cash, position size and Portfolio Scenario are not scoring or gating dependencies in this path.

Legacy portfolio tables, historical Portfolio Fit snapshots, historical ranking rows and old functions remain for audit. They were not dropped.

## 3. Policy lifecycle changes

Activated:

- `POL-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT`
- `POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2`
- `POL-OPPORTUNITY-QUALITY-V3-PORTFOLIO-INDEPENDENT`

Retired from the active path:

- `POL-DATA-SCORING-V3-DURABILITY`
- `POL-PORTFOLIO-FIT-V1`
- `POL-DECISION-RANKING-REFRESH-BRIDGE-V1`
- `POL-OPPORTUNITY-QUALITY-V2`

`POL-OPPORTUNITY-RANKING-V2` remains **RETIRED** and was not reactivated.

The backing candidate Portfolio Fit policy `FWB-PORTFOLIO-FIT-V1` is inactive.

## 4. Scoring v4

Legacy Decision scoring was 30% Business Thesis / 30% Expected Return / 25% Portfolio Fit / 15% Downside Risk.

Portfolio Fit is now zero-weight and non-gating. The remaining 30:30:15 proportions are normalized to:

- Business Thesis: **40%**
- Expected Return: **40%**
- Downside Risk: **20%**
- Portfolio Fit: **0%**

Existing non-portfolio semantics are preserved:

- Quality minimum remains **70**
- Chase-risk maximum remains **60**
- Expected Return internal weights remain **60% base / 40% probability-weighted**
- valuation thresholds are unchanged
- Quality Hardening thresholds are unchanged

The legacy `portfolio_fit_min=50` compatibility field is retained in the policy row but is no longer an active gate.

## 5. Schema compatibility

Historical columns remain, but future portfolio-independent Decision rows may set them to NULL:

- `candidate_decision_scores.portfolio_fit_snapshot_id`
- `candidate_decision_scores.portfolio_fit_score`
- `decision_snapshots.portfolio_batch_id`
- `decision_snapshots.portfolio_fit_snapshot_id`

No historical Decision/Score/Portfolio rows were rewritten or deleted.

## 6. Decision Bridge v2

Functions:

- `fwios.preview_decision_refresh_bridge_v2(text)`
- `fwios.apply_decision_refresh_bridge_v2(text, boolean)`

Properties:

- SECURITY INVOKER
- service-role only
- APPLY requires explicit human authorization
- no read of `candidate_portfolio_fit_snapshots`
- no read of `v_latest_portfolio_batch`
- current production valuation required
- current mispricing must align with the current hardening snapshot
- current hardening required
- Revision/Chase reuse existing evidence and fail closed when missing/incomplete
- deterministic IDs and exact-repeat NOOP behavior
- `auto_trade=false`
- no portfolio, approval or execution mutation

## 7. Controlled live Decision results

### ACN

Created:

- Score: `SCORE-DPI-ACN-1b8c0fbb6b0c850e`
- Decision: `DEC-DPI-ACN-1b8c0fbb6b0c850e`

Result:

- Core score: **70.1952**
- Hardening: **REVIEW**
- Decision: `REVIEW - QUALITY HARDENING`
- Promotion: `BLOCKED - QUALITY HARDENING`
- Portfolio Fit score: NULL
- Portfolio Fit snapshot: NULL
- Portfolio batch: NULL

Required **ACN REVIEW** invariant is preserved.

### EOG

Created:

- Score: `SCORE-DPI-EOG-f20c421e6bd81612`
- Decision: `DEC-DPI-EOG-f20c421e6bd81612`

Result:

- Core score: **68.3469**
- Hardening: **FAIL**
- Decision: `FAIL - QUALITY HARDENING`
- Promotion: `FAIL - QUALITY HARDENING`
- Portfolio Fit score/snapshot/batch: NULL

Required **EOG FAIL** invariant is preserved.

### NFLX

Created:

- Score: `SCORE-DPI-NFLX-65100f7a08581ea9`
- Decision: `DEC-DPI-NFLX-65100f7a08581ea9`

Result:

- Core score: **78.2216**
- Hardening: **REVIEW**
- Decision: `REVIEW - QUALITY HARDENING`
- Promotion: `BLOCKED - QUALITY HARDENING`
- Revision input: missing, explicitly fail-closed
- Chase input: missing, explicitly fail-closed
- Portfolio Fit score/snapshot/batch: NULL

Required **NFLX REVIEW** invariant is preserved without inventing a Portfolio Fit snapshot.

### PINS

No new Decision was created.

The v2 preview fails closed with:

`CURRENT_MISPRICING_NOT_ALIGNED_TO_HARDENING`

Current mispricing is `MIS-PINS-20260910-REFRESH` with `BLOCKED - PRICE CONFLICT`, while the current hardening snapshot still points to `MIS-PINS-QHREVAL-20260906`.

Historical `DEC-PINS-REFRESH-20260911` remains `PRICE CONFLICT`. This is a separate stale-lineage problem and is not hidden by weakening any gate.

## 8. Opportunity Quality v3

`fwios.refresh_opportunity_quality_v3(date,text,boolean)` refreshed **27** candidates for 2026-10-27.

The active `fwios.v_opportunity_quality_current`:

- does not join the latest portfolio batch
- does not join Portfolio Scenario reviews
- keeps compatibility columns, but reports `portfolio_scenario_gate='NOT_APPLICABLE - PORTFOLIO INDEPENDENT'`
- returns `PASS - HUMAN REVIEW ELIGIBLE` directly when all pre-buy research gates pass
- leaves scenario score/add-amount/review timestamp NULL
- does not mutate portfolio or execute trades

For the four audit tickers:

- ACN: VALUE_WAIT; full thesis still required
- EOG: VALUE_WAIT; full thesis still required
- NFLX: VALUE_WAIT; full thesis still required
- PINS: PRICE_VERIFY; blocked by price conflict

## 9. Idempotency and acceptance

Exact repeat Decision APPLY:

- ACN → `NOOP_ALREADY_REFRESHED`
- EOG → `NOOP_ALREADY_REFRESHED`
- NFLX → `NOOP_ALREADY_REFRESHED`

Live regression: **35/35 PASS**.

Acceptance covers policy lifecycle, normalized scoring, nullable legacy fit columns, security/ACLs, removal of active portfolio dependencies, required ACN/EOG/NFLX states, PINS fail-closed behavior, Opportunity Quality v3, retired Ranking v2, lineage and protected counts.

Protected counts remained unchanged:

- `portfolio_transactions = 58`
- `portfolio_source_positions = 32`
- `portfolio_live_holdings_rows_v1 = 15`
- `portfolio_accounts = 3`
- `human_approval_packets = 1`
- `human_approval_events = 0`

## 10. Advisor check

Supabase security/performance advisors were run after DDL.

The new functions are service-role-only, invoker-mode, and the active Opportunity view is `security_invoker=true`. The advisor output continues to show the existing schema-wide RLS-enabled/no-policy INFO backlog plus existing unindexed-FK and unused-index performance notices. No new table or index surface was introduced by this cutover.

Reference: https://supabase.com/docs/guides/database/database-linter

## 11. Next exact work

Portfolio Fit refresh is no longer an MVP-1 dependency.

The next downstream work should focus on non-portfolio evidence freshness:

1. reconcile **PINS hardening ↔ current mispricing/price-conflict lineage**;
2. fill **NFLX Revision/Chase evidence** only if the Decision workflow needs promotion beyond REVIEW;
3. reconcile/retire any remaining docs/tests that still assume Opportunity Ranking v2 is the active production opportunity path.

No portfolio refresh, allocation, rebalance or trade is required by this cutover.
