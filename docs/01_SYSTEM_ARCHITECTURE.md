# 01 — System Architecture

Contract version: **FWIOS-CONTRACT-0.87.0**

## System of record

The live research engine is the Google Sheet `US_Stock_Sector_Business_Model_Screener`. This repository documents its operating contract; it does not replace the live sheet.

The separate `Investment Portfolio Tracker - Chumponphat` remains the source of truth for current holdings, allocation and transaction state.

## Production data flow

```text
Sector_Criteria
  ↓
Sector_Universe / AI Discovery Staging
  ↓
Source_Registry
  ↓
Evidence_Ledger
  ↓
Company_Metrics_v2
  ↓
Normalized_Metrics_v1
  ↓
Intrinsic_Valuation_v2
  ↓
Data_Scoring_v2
  ↓
Opportunity_Engine_v2
```

### 1. Sector_Criteria
Defines business-model archetypes, mandatory KPIs, quality thresholds, red flags, preferred valuation methods, cycle sensitivity, valuation model IDs, required metric IDs, freshness and source-tier requirements.

### 2. Sector_Universe / AI Discovery Staging
Research intake and triage. These layers may contain AI interpretation but are not trusted as production valuation evidence by themselves.

### 3. Source_Registry
Defines approved evidence-source policy and provenance expectations.

### 4. Evidence_Ledger
Traceable source facts. A production-relevant fact should carry enough provenance to be independently checked.

Derived facts require a deterministic method and input lineage.

### 5. Company_Metrics_v2
Canonical factual snapshot by `Ticker × Metric ID`.

This layer is **not** allowed to contain model forecasts or valuation assumptions.

### 6. Normalized_Metrics_v1
Standardized model-input layer. It may:

- convert percentages to ratios;
- standardize definitions and units;
- create explicitly derived balance-sheet bridges;
- perform economic/cycle normalization where the methodology is evidenced and versioned.

It must never overwrite reported evidence.

### 7. Intrinsic_Valuation_v2
Model layer. Owns:

- bear/base/bull assumptions;
- target yields/multiples;
- discount rates;
- terminal assumptions;
- probability weights;
- model-specific fair value;
- model readiness and sanity gates.

### 8. Data_Scoring_v2
Transforms verified valuation and research inputs into production scores and mispricing classification.

### 9. Opportunity_Engine_v2
Final formula-driven decision engine. Quality is necessary but insufficient. The final decision also depends on evidence, valuation, expected return, chase/FOMO, portfolio fit and mispricing gates.

## Write ownership

| Layer | Ownership |
|---|---|
| Portfolio holdings/allocation | Portfolio Tracker — read-only for screener work |
| Market Data Refresh | system/formula |
| AI Discovery Staging | AI research intake in permitted columns |
| Evidence_Ledger | AI collector / research write under evidence policy |
| Company_Metrics_v2 | formula/system canonicalization |
| Normalized_Metrics_v1 | system/research normalization with explicit versioning |
| Intrinsic_Valuation_v2 | research/model inputs + system formulas |
| Data_Scoring_v2 | formula/system |
| Opportunity_Engine_v2 | formula/system |
| Sector_Run_History | append-only run record |
| Data_Quality_Gates R:AJ | persistent root-cause blocker queue |

## Machine statuses

- **PASS** — all required inputs valid.
- **READY** — all decision gates passed; still human execution only.
- **WAIT** — valid data, but setup/valuation is not actionable.
- **STALE** — input exists but is too old for decision use.
- **BLOCKED** — missing, stale, invalid, conflicting or unverified critical input.
- **REJECT** — thesis, quality or risk gate failed.

## Freshness contract

- Stock market data: latest market session acceptable for screening; broker verification before trade.
- Fundamental evidence: latest reported quarter; block if new earnings occurred after research.
- Consensus revisions: comparable post-event evidence required; never guess missing deltas.
- Catalysts: must be future-dated to support READY.

## Phase 0.87 production state

Live foundation currently reports:

- `Normalized_Metrics_v1`: LIVE.
- 17 archetype valuation contracts configured.
- Production routes live for MEDTECH, E&P, Restaurant, Branded Retail and OFS.
- Blocked Resolution Queue: live and dependency-aware.
- Focused Wealth-Building 30/30/25/15 core scoring: live.
- Chase/FOMO fail-closed regression: live.
- Current foundation status: `PHASE 0.87 OPERATIONAL`.

## Architectural invariants

1. Web research cannot jump directly to final valuation.
2. Facts and model assumptions must remain separate.
3. Unimplemented model contracts fail closed.
4. No system output may auto-execute a trade.
5. Portfolio context must be re-read before a recommendation.
6. New system gaps must enter the central blocker queue rather than becoming undocumented manual exceptions.
