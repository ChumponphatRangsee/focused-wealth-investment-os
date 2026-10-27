# FWIOS Clean-Room End-to-End Validation Handover — 2026-10-27

## Purpose

This handover is the entry point for the next chat.

The current FWIOS / S&P500 Scanner core pipeline is functionally assembled and the legacy Portfolio Fit dependency has been removed from the active stock-selection path. The next milestone is **not another ticker-specific repair**. The next milestone is to prove that the system can start from a ticker with no active stock-specific derived state and produce a trustworthy result end to end.

Target validation flow:

`Ticker → Data/Evidence Collection → Canonical Metrics → Validation → Valuation Model Routing → Fair Value → Verified Market Price → Mispricing → Quality Hardening → Revision/Chase → Scoring → Decision → Opportunity Quality`

The clean-room test must fail closed whenever required evidence is missing, stale, conflicting, unsupported or unverified.

---

## 1. Latest verified repository / live baseline

Repository: `ChumponphatRangsee/focused-wealth-investment-os`

Latest verified pre-handover `main`:

`a10c32253cd126f91a0989baf081f293c152c13f`

Active system contract:

`FWIOS-CONTRACT-0.87.26`

Live Supabase project:

`ysjbmeukwbfnxnwqchuq`

Execution policy:

- human execution only
- `auto_trade=false`
- Scanner/Decision/Opportunity path is portfolio-independent
- no portfolio/accounting/approval/execution mutation is allowed during clean-room scanner validation

---

## 2. Major work completed

### 2.1 Valuation period semantics and production v2 cutover

Completed before this handover:

- period-aware valuation input semantics
- canonical metric selectors
- ACN / EOG / NFLX v2 model validation
- shadow valuation runs
- deterministic valuation promotion policy
- controlled production promotion + rollback verification

Current production valuations include:

- ACN: `VAL-PROD-ACN-ITSERV-V2-20261026`
- EOG: `VAL-PROD-EOG-EP-V2-20261026`
- NFLX: `VAL-PROD-NFLX-STREAM-V2-20261026`

No valuation threshold changes were made during the later Decision/Portfolio cleanup work.

### 2.2 Quality Hardening refresh infrastructure

Live controlled refresh exists:

- `fwios.preview_quality_hardening_refresh_v1(text)`
- `fwios.apply_quality_hardening_refresh_v1(text, boolean)`

Properties:

- service-role controlled
- explicit human authorization on APPLY
- verified daily-close source
- fail-closed behavior
- no portfolio mutation
- deterministic/idempotent refresh

Canonical-evidence refresh infrastructure also remains available where applicable.

### 2.3 Portfolio Fit removed from active Decision / Opportunity pipeline

Live migration:

`20261027035558 decision_opportunity_portfolio_independence_v1`

Active production path is now:

`Evidence → Canonical Metrics → Valuation → Mispricing → Quality Hardening → Scoring → Decision → Opportunity Quality → Human Review`

Portfolio Fit is **not** an active scoring/gating dependency.

Decision scoring v4:

- Business Thesis: 40%
- Expected Return: 40%
- Downside Risk: 20%
- Portfolio Fit: 0%

Active policies:

- `POL-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT`
- `POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2`
- `POL-OPPORTUNITY-QUALITY-V3-PORTFOLIO-INDEPENDENT`

`POL-OPPORTUNITY-RANKING-V2` remains RETIRED.

### 2.4 Retired runtime cleanup

Live migration:

`20261027041844 remove_retired_decision_portfolio_runtime_v1`

Removed retired runtime entry points:

- `preview_decision_refresh_bridge_v1`
- `apply_decision_refresh_bridge_v1`
- `preview_opportunity_ranking_refresh_bridge_v1`
- `apply_opportunity_ranking_refresh_bridge_v1`
- `refresh_opportunity_quality_v2`
- `preview_candidate_portfolio_fit_v2`
- `materialize_candidate_portfolio_fit_v2`

Historical tables, policy versions, snapshots, migrations and lineage were intentionally retained for audit/FK integrity.

No destructive `CASCADE` cleanup was used.

### 2.5 PINS stale-lineage repair

PINS was used to prove the repaired downstream lineage.

Current verified daily close used:

- date: 2026-10-26
- close: USD 21.22
- verification gate: PASS

Created/current lineage:

- price: `PX-DCL-PINS-20261026-9ea8129c68`
- mispricing: `MIS-QHR-PINS-20261026-59a4494e51`
- hardening: `HARD-QHR-PINS-20261026-3b737f3fd20c`
- Decision: `DEC-DPI-PINS-a77877e1ac450268`

PINS now has:

- current price gate = PASS
- current mispricing gate = PASS
- Hardening = REVIEW
- Decision = REVIEW - QUALITY HARDENING
- Opportunity state = MISPRICED_CANDIDATE

It still fails closed on risk/chase/Owner Earnings review and is **not a buy signal**.

---

## 3. Current audited Decision results

| Ticker | Core score | Decision | Main current blocker |
| --- | ---: | --- | --- |
| ACN | 70.1952 | REVIEW - QUALITY HARDENING | Quality Hardening / incomplete Chase |
| EOG | 68.3469 | FAIL - QUALITY HARDENING | Quality Hardening FAIL |
| NFLX | 78.2216 | REVIEW - QUALITY HARDENING | Quality Hardening / Revision snapshot missing |
| PINS | 83.8000 | REVIEW - QUALITY HARDENING | Quality Hardening / risk / incomplete Chase |

All current Decision rows above are portfolio-independent:

- `portfolio_batch_id = NULL`
- `portfolio_fit_snapshot_id = NULL`

---

## 4. Verification / regression results

### Portfolio-independent Decision / Opportunity regression

`tests/decision/test_decision_opportunity_portfolio_independence_v1.sql`

Result:

**35/35 PASS**

Covers:

- scoring v4 active
- Portfolio Fit retired
- Decision bridge v2 active
- Opportunity Quality v3 active
- Opportunity Ranking v2 remains retired
- new Decision rows have no Portfolio Fit / portfolio batch dependency
- ACN / EOG / NFLX / PINS current states
- protected accounting/approval counts unchanged
- `auto_trade=false`

### Retired-runtime cleanup regression

`tests/decision/test_remove_retired_decision_portfolio_runtime_v1.sql`

Result:

**10/10 PASS**

Covers:

- retired runtime functions removed
- active v2/v3 runtime remains
- historical audit rows preserved
- retired Ranking remains invisible

### PINS current-lineage regression

`tests/decision/test_pins_current_lineage_repair_v1.sql`

Result:

**18/18 PASS**

Covers:

- verified current price
- current mispricing/hardening alignment
- portfolio-independent PINS Decision
- explicit valuation → hardening → Decision lineage
- PINS remains fail-closed at remaining gates
- historical price-conflict Decision preserved

### Idempotency

Verified:

- repeated ACN / EOG / NFLX Decision APPLY → `NOOP_ALREADY_REFRESHED`
- repeated PINS Hardening APPLY → `NOOP_ALREADY_REFRESHED`
- repeated PINS Decision APPLY → `NOOP_ALREADY_REFRESHED`

### Protected state

Last verified protected counts:

- `portfolio_transactions = 58`
- `portfolio_source_positions = 32`
- `portfolio_live_holdings_rows_v1 = 15`
- `portfolio_accounts = 3`
- `human_approval_packets = 1`
- `human_approval_events = 0`

No scanner/Decision work changed those counts.

---

## 5. What is ready now

The following pieces are sufficiently implemented to begin clean-room validation:

1. canonical instrument identity foundation
2. controlled research ingest
3. canonical metric observations / lineage foundation
4. valuation routing/models for supported archetypes
5. period-aware valuation input resolution
6. verified market-price / daily-close infrastructure
7. mispricing calculation
8. Quality Hardening
9. portfolio-independent scoring v4
10. Decision bridge v2
11. Opportunity Quality v3
12. fail-closed downstream gating
13. lineage tracing and immutable historical audit

This means the system is ready to **attempt** a clean-room ticker test.

It does **not** mean the full autonomous scanner is proven end to end.

---

## 6. What is NOT yet proven

The single biggest unproven requirement is:

> Starting with only a ticker and no active ticker-specific derived state, can FWIOS independently collect the required evidence, validate it, create canonical metrics, route to the correct valuation model, calculate Fair Value, verify current price, evaluate mispricing/quality/risk and produce a deterministic Decision?

This has not yet been demonstrated from zero in one controlled run.

Important gaps to validate:

### 6.1 Clean-room isolation

Current database contains historical/legacy stock data.

A clean-room test must prove that the selected ticker does not silently reuse old stock-specific evidence, metrics, price snapshots, valuations, hardening or Decision state.

Do **not** hard-delete all historical data first.

Preferred approach:

- preserve immutable history
- create an isolated test run / namespace / batch or explicit ticker reset boundary
- make active test inputs visible
- verify every downstream artifact points only to evidence intentionally admitted into the clean-room run

### 6.2 Ticker-only orchestration

The project has components for ingest, metrics, valuation, price, hardening and Decision, but the complete orchestration from only a ticker has not been proven as one workflow.

The clean-room test must identify any missing orchestration glue instead of manually patching the selected stock stage by stage.

### 6.3 Research/data collection completeness

The selected test ticker must prove that required primary evidence can actually be obtained and mapped into canonical metrics.

If data is missing or unsupported, the correct result is BLOCKED with an explicit reason.

No synthetic evidence should be created merely to make the test pass.

### 6.4 Model coverage

There are production valuation models for multiple archetypes, but model support is not equivalent to complete S&P 500 coverage.

The first clean-room ticker should use an archetype/model that is already supported.

After one successful ticker, test additional valuation archetypes one at a time.

### 6.5 Remaining compatibility/read-cutover surfaces

Several foundation systems remain intentionally additive / compatibility-oriented rather than universal production read authority, including research lifecycle / metric-observation / market-observation compatibility surfaces.

The clean-room test must record exactly which path supplied every active input and expose any accidental legacy fallback.

### 6.6 API/quota automation

The broader quota/cache/singleflight architecture is not the current clean-room acceptance target and should not be redesigned during the first ticker test unless it is proven to block the test.

Avoid expanding scope.

---

## 7. Decision on deleting existing stock data

Do **not** delete all stock data before the first clean-room test.

Reason:

- historical state is needed as an audit/control sample
- destructive deletion can hide stale-dependency bugs instead of revealing them
- historical lineage/FK records remain useful for regression
- the objective is to prove the new run does not depend on prior stock state

Correct strategy:

`Archive/preserve historical state → isolate active test state → run ticker from zero → verify lineage → compare with old results`

Only after clean-room acceptance should destructive cleanup of truly obsolete tables/rows be considered separately.

---

## 8. Next milestone — Clean-Room E2E Test #1

This is the next task for the new chat.

### Goal

Prove one supported stock can travel from **ticker-only input** to a deterministic, auditable valuation/Decision result without relying on legacy ticker-specific derived state.

### Recommended test sequence

1. Start read-only.
2. Re-verify latest GitHub `main`, active contract and live Supabase.
3. Read this handover and `docs/CURRENT_STATUS.md`.
4. Inventory every table/view/function the selected ticker would read/write.
5. Design the smallest non-destructive clean-room boundary.
6. Choose one supported valuation archetype for Test #1.
7. Record all pre-test ticker-specific active rows.
8. Execute only the intended collection/ingest path.
9. Verify primary-source evidence and canonical metric identity.
10. Verify required valuation inputs all resolve.
11. Create/preview valuation and validate Fair Value output.
12. Verify current market price independently through the canonical price path.
13. Calculate current mispricing.
14. Run Quality Hardening.
15. Run Revision/Chase if required.
16. Run scoring v4.
17. Run Decision v2.
18. Refresh Opportunity Quality v3.
19. Trace every important lineage edge back to admitted clean-room evidence.
20. Confirm no historical ticker data was silently used.
21. Repeat exact run and require deterministic NOOP/idempotent behavior.
22. Confirm no protected portfolio/accounting/approval/execution state changed.

### Acceptance criteria

A clean-room ticker passes only if:

- the required evidence was collected or explicitly BLOCKED
- no unknown metric identity was silently accepted
- no stale price passes a price-sensitive gate
- required valuation inputs have explicit current lineage
- valuation model selection is deterministic
- Fair Value is reproducible
- Decision is deterministic
- missing data fails closed
- no Portfolio Fit/portfolio batch is required
- no portfolio/accounting mutation occurs
- exact repeat is idempotent
- all active artifacts can be traced to admitted test evidence

The test may legitimately end in REVIEW / FAIL / BLOCKED. The goal is pipeline correctness, **not** forcing a PASS or BUY.

---

## 9. Expansion plan after Test #1

Do not jump directly to 500 stocks.

Recommended progression:

1. **1 ticker** — complete clean-room E2E
2. **1 ticker per major supported valuation archetype**
3. **5–10 ticker mixed-archetype batch**
4. **50-stock batch**
5. **100-stock batch**
6. full S&P 500 only after coverage, failure taxonomy, quota and observability are proven

Every scale-up should track:

- successful E2E count
- BLOCKED count by reason
- unsupported-model count
- missing-primary-evidence count
- stale/conflicting price count
- valuation failures
- hardening REVIEW/FAIL counts
- deterministic repeat failures
- API usage/cost

---

## 10. Scope guardrails for the next chat

Do not:

- delete all historical stock data
- restore Portfolio Fit into scoring
- reactivate Opportunity Ranking v2
- change valuation thresholds to make tests pass
- weaken Quality Hardening
- weaken risk or Chase gates
- synthesize missing primary evidence
- mutate portfolio accounting
- place or execute trades
- redesign unrelated quota/portfolio infrastructure unless it is a demonstrated blocker

Keep:

- `auto_trade=false`
- human execution only
- append-only/auditable evidence where possible
- fail-closed behavior
- minimal deterministic fixes

---

## 11. Suggested exact prompt for the new chat

> Continue FWIOS from `docs/implementation/FWIOS_CLEAN_ROOM_E2E_HANDOVER_20261027.md`. Start read-only. Verify latest GitHub main and live Supabase. Do not continue ticker-specific patching first. Design and execute Clean-Room E2E Test #1 to prove that one supported stock can start from ticker-only input and flow through evidence collection, canonical metrics, validation, valuation/Fair Value, verified market price, mispricing, Quality Hardening, Revision/Chase, scoring, Decision and Opportunity Quality without silently reusing legacy stock-specific derived data. Do not hard-delete historical data. Preserve all valuation/hardening/risk thresholds, keep Portfolio Fit retired, keep Opportunity Ranking v2 retired, keep auto_trade=false and do not mutate portfolio/accounting/approval/execution state. First determine the safest isolated clean-room boundary and select a supported valuation archetype; then perform the minimum deterministic work needed to run and verify the pipeline end to end.

---

## 12. Reference receipts

Read these only as needed:

- `docs/implementation/FWIOS_DECISION_OPPORTUNITY_PORTFOLIO_INDEPENDENCE_20261027.md`
- `docs/implementation/FWIOS_PINS_CURRENT_LINEAGE_REPAIR_20261027.md`
- `tests/decision/test_decision_opportunity_portfolio_independence_v1.sql`
- `tests/decision/test_remove_retired_decision_portfolio_runtime_v1.sql`
- `tests/decision/test_pins_current_lineage_repair_v1.sql`

The next chat should treat this handover as the current milestone entry point, while live Supabase and current merged contract remain the operational authority.
