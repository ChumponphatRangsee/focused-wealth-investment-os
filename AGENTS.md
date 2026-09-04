# AGENTS.md — Focused Wealth Investment OS

This file is the **mandatory execution contract** for any AI agent or automation operating on the Portfolio investment system.

Contract version: **FWIOS-CONTRACT-0.87.0**  
Compatible live foundation: **0.87**

## 1. Non-negotiable objective

Optimize for aggressive but disciplined capital growth toward the Phase-1 portfolio target of **THB 1,000,000**.

Core principle:

> Focus creates upside. Position sizing creates survival. Valuation creates margin of safety.

Do not optimize for maximum diversification or maximum capital preservation. Preserve upside while controlling permanent-loss risk.

## 2. Before any investment recommendation

The agent MUST:

1. Read the latest portfolio holdings, allocation and transactions when available.
2. Apply the Focused Wealth-Building rules.
3. Analyze the candidate in portfolio context, never in isolation.
4. Verify current price, financials, valuation inputs and material news from current sources.
5. Prefer primary company filings / IR for canonical financial evidence.
6. Check concentration and crypto exposure before suggesting allocation.
7. Challenge FOMO, anchoring, confirmation bias and narrative-driven reasoning.

Current portfolio data always overrides older assumptions.

## 3. Portfolio construction guardrails

- Prefer **5–8 meaningful positions**.
- Exceptional single-stock allocation is approximately **30% maximum**; above that requires explicit concentration review.
- Phase-1 crypto target is approximately **15–20%**; deviations require explicit justification.
- Prefer soft rebalancing with new cash before selling high-quality winners.
- Never recommend trimming merely because a position appreciated.
- Maximum **5 active watchlist candidates**.
- Maximum **3 immediate buy candidates**.
- Human execution only. Never auto-buy or auto-sell.

## 4. Production scoring contract

The production core is exactly:

- Business / Thesis Quality: **30%**
- Expected Return / Valuation: **30%**
- Portfolio Fit: **25%**
- Downside / Thesis Risk: **15%**

Revision, catalyst and timing/chase signals are **non-core modifiers** and may not dominate the core score or bypass hard gates.

Every new candidate must pass the four conceptual gates:

1. Business Quality
2. Growth
3. Valuation
4. Portfolio Fit

## 5. Canonical data path

The allowed production path is:

`Sector_Criteria → AI collection/staging → Source_Registry → Evidence_Ledger → Company_Metrics_v2 → Normalized_Metrics_v1 → Intrinsic_Valuation_v2 → Data_Scoring_v2 → Opportunity_Engine_v2`

Rules:

- Never write web values directly into production valuation formulas without evidence lineage.
- `Evidence_Ledger` stores traceable source facts.
- `Company_Metrics_v2` stores factual/canonical metric snapshots only.
- Forecast/model assumptions are prohibited in `Company_Metrics_v2`.
- `Normalized_Metrics_v1` is the standardized/economic-normalization layer.
- `Intrinsic_Valuation_v2` owns model assumptions and scenario outputs.
- `Opportunity_Engine_v2` owns final formula-driven decision logic.

## 6. Fail-closed rule

Missing, stale, conflicting, schema-invalid, unverified or provenance-free critical data must become **BLOCKED**.

Do not guess values to make a model pass.
Do not use AI-only valuation as verified valuation.
Do not promote a candidate on Quality Score alone.
Do not force-fill a shortlist.

If an archetype model is configured but not implemented, status must remain:

`BLOCKED - MODEL NOT IMPLEMENTED`

until a model is explicitly implemented and regression-tested.

## 7. Evidence requirements

For production evidence, record when applicable:

- exact source URL
- source tier
- evidence class
- metric ID
- reported/derived status
- formula/method for derived facts
- input lineage
- period/date
- confidence / verification state

Use primary company/SEC/IR evidence for canonical financial metrics where available.

## 8. Facts vs assumptions

Never mix factual source evidence with valuation assumptions.

Examples:

- Reported revenue, FCF, debt and shares → evidence/canonical layers.
- Target FCF yield, discount rate, terminal assumptions, probability weights → valuation layer.
- Cycle-normalized commodity deck → normalization/valuation methodology with explicit provenance and version.

## 9. Autonomous sector-run rules

- One full sector per scheduled run.
- If a sector is incomplete or RUNNING, resume it before starting another.
- Maximum universe per sector: **20**.
- Maximum sector shortlist: **5**, never force-fill.
- Compare sector winners against existing active candidates; retain the best **5 overall**.
- Missing/stale/conflicting/unverified data → BLOCKED and resume later.
- Production score requires traceable Tier A/B evidence; model contracts may require Tier A specifically.
- Current next sector in the live queue is Materials, but live sheet state must be re-read before execution.

## 10. Blocked Resolution Orchestrator

All root blockers must be represented in the persistent queue in `Data_Quality_Gates` columns R:AJ.

The orchestrator must respect:

- dependency block IDs
- retry mode
- retry frequency
- next eligible check
- resolver type
- orchestrator state

Allowed orchestrator states are conceptually:

- READY
- WAIT_DEPENDENCY
- WAIT_RETRY
- CLOSED

Never create ad-hoc per-ticker retry logic when the central queue can represent the dependency.

## 11. Documentation handshake

Before mutating the live system:

1. Read `System_Foundation` and confirm live foundation version.
2. Read this repository's `contracts/system-contract.yaml` and `VERSION`.
3. Confirm the live foundation is compatible with the contract.
4. If versions are incompatible or the handshake status is BLOCKED, do not run a new sector or change production logic.
5. After a material system change, update both the live foundation and this repository in the same workstream.

## 12. Regression discipline

Any change to normalization, valuation routing, scoring, gates or formulas must preserve or deliberately update regression checks.

Current Phase 0.87 reference regressions include ISRG, EOG, BKR, CAVA and TPR.

A changed output is acceptable only if the economic/model logic was intentionally changed and the change is documented.

## 13. Forbidden shortcuts

Do not:

- bypass the evidence path;
- silently relabel company-specific metrics as standardized metrics;
- extrapolate peak-cycle economics as normalized economics;
- treat positive company news as automatic investment attractiveness;
- override portfolio-fit rules because a standalone stock score is high;
- auto-execute trades;
- modify portfolio holdings/transactions during screener/system work unless explicitly instructed.

## 14. Source precedence

1. Latest portfolio data
2. Focused Wealth-Building rules
3. Personal Investment Strategist framework
4. Screener/system outputs
5. Current primary-source research
6. Wall Street consensus
7. News/social narratives

When conflict exists, use the higher-priority source.
