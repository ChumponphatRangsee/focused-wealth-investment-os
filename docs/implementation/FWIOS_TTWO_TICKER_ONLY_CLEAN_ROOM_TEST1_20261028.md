# TTWO — Ticker-Only Clean-Room E2E Test #1

**Date:** 2026-10-28 (Asia/Bangkok). **Current status:** SEC SOURCE → METRIC PREVIEW PASS; downstream **BLOCKED_MODEL_ROUTING**. **Full E2E NOT COMPLETE.**

## Owner direction and freeze

The owner has explicitly **PAUSED** the ACN/ADBE/PINS closure checklist (A1–A5) and chosen **TTWO as the sole new clean-room pilot ticker**. This supersedes the earlier three-ticker pilot limit **only for the new experiment**; it does not close or resolve their prior defects. No 28/64/500-company deep-research expansion is authorized. Continue the existing 64-ticker EOD feed. PRs #92–#95 are separate open work, not automatically merged; legacy Cron #10 remains inactive after the previous mitigation. Do not undo any safety protection on unrelated instruments.

Adhere to **FWIOS-CONTRACT-0.87.26**, `auto_trade=false`, human execution only, retired Portfolio Fit and retired Opportunity Ranking v2, no accounting/approval/execution mutation, no hard deletes. Legacy TTWO `thesis_registry` is a **pre-existing baseline** (COMPLETE); it is not admitted as new canonical evidence for the clean-room run.

## Live zero-state / source preflight

- Instrument: TTWO = active primary NASDAQ Stock; `instrument_id=4930e480-cb82-40b7-89a7-9ea55e190244`.
- **Before this test:** 0 `fwios.evidence_records`, 0 `fwios.metric_observations`, 0 `fwios.valuation_runs`, 0 `fwios.decision_snapshots`, 0 `fwios.research_ingest_receipts_v1` for TTWO.
- Readiness: `DISCOVERY_READY`, `research_ready=false`, `valuation_ready=false`, `investment_review_ready=false`, `RESEARCH_NOT_READY`.
- **Already collected:** 98 TTWO `fwios.decision_refresh_shadow_evidence` records (SEC submissions/companyfacts and market prices). Source bytes are collector-shadow input, **not canonical metrics**.
- As checked 2026-10-28, SEC CIK **0000946581**, most recent stored **10-Q**: accession `0001628280-26-054870`, filed 2026-08-07, reporting period ending 2026-06-30. **10-K**: accession `0001628280-26-037434`, filed 2026-05-22, fiscal year ending 2026-03-31. Later 8-K entries include 2026-09-30 (Item 1.01) and 2026-09-22. Material-event effects must be reviewed before debt/cash valuation inputs.
- Latest verified canonical EOD: **2026-10-27 $201.25**, Twelve Data primary and **$201.28** Alpha Vantage independent price, `verification_status=VERIFIED`, `provenance_status=PASS`. This is a dated session close, not live trading price. 64 stocks remained present for that EOD session.

## Controlled SEC→Metric PREVIEW — executed successfully

File: `queries/ttwo_clean_room_sec_to_metrics_preview_v1.sql` (**SELECT-only; no HTTP calls, no INSERT, no APPLY**). It reads the most recent stored SEC `COMPANY_FACTS` and `SUBMISSIONS` shadows, restricts to exact form/accession/fiscal period start/end/USD denomination, requires exactly 8 distinct period/metric matches, constructs 2 Tier-A SEC evidence items and 8 canonical candidate observations, then runs `fwios.preview_research_ingest_v1` with `mode=PREVIEW`.

**Verified response on 2026-10-28:** `overall_status=PASS`, `evidence_count=2`, `metric_count=8`, `blocker_count=0`, `warning_count=0`, `production_changes=NONE`. This validates payload shape and observed source context, **not automatic financial economic correctness or production eligibility**.

| Metric (USD B) | FY2026 YEAR: Apr 1 2025–Mar 31 2026 | Q1 FY2027 QUARTER: Apr 1–Jun 30 2026 |
|---|---:|---:|
| `REVENUE` | 6.6564 | 1.5339 |
| `OPERATING_CASH_FLOW` | 0.6243 | −0.1688 |
| `CAPEX_PROPERTY_EQUIPMENT` | 0.1628 | 0.0250 |
| `SHARE_BASED_COMPENSATION` | 0.3053 | 0.0860 |

**Cash-flow cross-check:** FY2026 CFO − CapEx = $0.4615B. This is an unadjusted CFO-minus-PPE-capex proxy, **not a TTWO normalized owner-earnings or Fair Value input by itself**; game-development economics, release timing and working capital require separate treatment. Q1 FY2027 CFO is negative.

**Source documents**:
- FY2026 SEC 10-K: https://www.sec.gov/Archives/edgar/data/946581/000162828026037434/ttwo-20260331.htm
- Q1 FY2027 SEC 10-Q: https://www.sec.gov/Archives/edgar/data/946581/000162828026054870/ttwo-20260630.htm
- FY2027 outlook/company report (Aug 7): https://www.take2games.com/ir/news/take-two-interactive-software-inc-reports-results-fiscal-first-6

**Upcoming material source refreshes as of 2026-10-28:** Q2 FY2027 earnings planned **2026-11-09** (company IR); GTA VI launch stated **2026-11-19** (issuer/Rockstar). Do not treat forward guidance as realized cash flows; reassess when published.

## Regression receipt — 18/18 PASS

File: `tests/research/test_ttwo_clean_room_baseline_v1.sql`. Checks active TTWO instrument, pre-existing thesis baseline, zero canonical/evidence/valuation/decision, exact SEC submissions, 8 XBRL facts, FY26 and Q1 FY27 Revenue/CFO, EOD price crosscheck, `DISCOVERY_READY`, missing exact model archetype, preserved 64-stock price coverage and zero APPLY receipts. **These are pre-APPLY baseline checks; expect the zero-row assertions to change only after separately authorized ingest.**

## Hard blocker: valuation model coverage

The TTWO thesis archetype is `Premium Interactive Entertainment and Live Services`. The **20 currently implemented model families have no exact, reviewed Production mapping to this archetype**. `STREAMING_FCF_DCF_V1` is calibrated to a streaming/content accounting selector (requires `CONTENT_CASH_TO_AMORTIZATION` guidance) and must not be silently reused for interactive game IP. A generic SaaS/retail DCF is likewise not an approved TTWO model.

**Router result = `BLOCKED_UNSUPPORTED_ARCHETYPE`.** No Fair Value, Mispricing, Quality Hardening, Revision/Chase, Scoring v4, Decision v2 or Opportunity Quality v3 may be treated as completed or actionable. A source research PREVIEW PASS does not override this blocker.

Propose a **separately reviewed** `INTERACTIVE_ENTERTAINMENT_IP_DCF_V1` model design before implementation:
- Separate **Net Bookings** vs GAAP revenue/deferred recognition.
- Normalize multi-year publisher cash flows across GTA VI pre-launch, launch and live-service tail; stress scenarios for delay/unit sales/attach rate/monetization.
- Explicitly classify game-development cash investments/capitalization, working capital, DLC/live services and franchise concentration.
- Anchor future forecasts to primary FY2027 guidance (issuer at Aug 7 states Net Bookings $8.0–$8.2B, operating cash flow expected >$1B and CapEx approx $0.29B), distinguish estimates from actual facts.
- Reconcile cash/debt/investments, diluted shares, SBC dilution, acquisitions and current 8-K material obligations.
- Approve required metric codes, period-aware selectors, conservative scenario probabilities, robustness tests and sensitivity; only then assign a production model version, compute deterministic Fair Value and test downstream integrity.
- No fabricated price targets or threshold loosening.

## Exact next execution gates

| Gate | Requirement | Status |
|---|---|---|
| Identity / source preflight | One active TTWO, exact filings/periods and clean-room boundary | **PASS** |
| Typed primary-evidence candidate | 2 SEC Evidence + 8 metric PREVIEW validations | **PASS (PREVIEW ONLY)** |
| Canonical persist | Separate explicit owner authorization for `APPLY`, source review, idempotency/re-run, immutable evidence and metric lineage | **NOT AUTHORIZED / NOT DONE** |
| Valuation model routing | Reviewed TTWO-specific archetype and production model version | **BLOCKED_UNSUPPORTED_ARCHETYPE** |
| Valuation, Fair Value | Complete required validated model inputs, deterministic cases and reproducible run | **NOT DONE** |
| Verified price | Session-close canonical price verified independently for Oct 27 | **PASS (SOURCE ONLY)** |
| Mispricing / Hardening / Revision-Chase / Score / Decision / Opportunity | Trace same run/session IDs, fail-closed and no BUY from unverified analysis | **NOT DONE** |
| E2E repeat + protected-state invariants | All active artifacts from admitted clean-room evidence, repeat NOOP, no protected mutations | **NOT DONE** |

**Next recommended action:** review and approve the TTWO model-design contract; separately authorize the controlled metrics `APPLY` if desired. Do not equate this GitHub draft PR with a completed E2E test. Keep ACN/ADBE/PINS closure paused rather than merging/expanding it by accident.
