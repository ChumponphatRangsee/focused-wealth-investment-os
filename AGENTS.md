# AGENTS.md — Focused Wealth Investment OS

This file is the mandatory execution contract for any AI agent or automation operating on the Portfolio investment system.

Contract version: **FWIOS-CONTRACT-0.87.3**  
Compatible live foundation: **0.87**

## 1. Objective

Optimize for aggressive but disciplined capital growth toward the Phase-1 portfolio target of THB 1,000,000.

Core principle:

> Focus creates upside. Position sizing creates survival. Valuation creates margin of safety.

Human execution only. Never auto-buy or auto-sell.

## 2. Authority model

Architecture Consolidation v1 defines the durable authority split:

- **Supabase = System of Record / State** for reconciled portfolio state, evidence/canonical/normalized research state, market-price/mispricing state, valuation state, Portfolio Fit, scoring state, policy versions, decision snapshots and future capital-allocation scenario state.
- **GitHub = System of Logic / Contracts / Tests / Migrations**.
- **Google Sheets = System of View / Compatibility / Reconciliation / Audit / Export** during and after cutover; it must not silently become a second production source of truth.
- **AI = Research / interpretation / explanation / controlled orchestration**, not accounting, hidden scoring, or trade execution.

Live portfolio/system/controller state overrides stale documentation.

## 3. Before any investment recommendation

The agent MUST:

1. Read the latest reconciled portfolio state and relevant source transactions.
2. Apply Focused Wealth-Building guardrails.
3. Analyze the candidate in portfolio context, never in isolation.
4. Verify current price, financials, valuation inputs and material news from current sources.
5. Prefer primary company filings / IR for canonical financial evidence.
6. Check concentration and crypto exposure.
7. Challenge FOMO, anchoring, confirmation bias and narrative-driven reasoning.
8. Use the latest reproducible decision snapshot when available.

## 4. Portfolio guardrails

- Prefer 5–8 meaningful positions.
- Exceptional single-stock allocation is approximately 30% maximum; above that requires explicit concentration review.
- Phase-1 crypto target is approximately 15–20%; deviations require explicit justification.
- Prefer soft rebalancing with new cash before selling high-quality winners.
- Never trim merely because a position appreciated.
- Maximum 5 active watchlist candidates.
- Maximum 3 immediate buy candidates.
- `Investment Portfolio Tracker - Chumponphat` remains retained for reconciliation/audit/export until M3 traceability tests pass.

## 5. Production scoring contract

Production core weights are exactly:

- Business / Thesis Quality: 30%
- Expected Return / Valuation: 30%
- Portfolio Fit: 25%
- Downside / Thesis Risk: 15%

Revision, catalyst and timing/chase signals are non-core modifiers and hard gates. They may not dominate the core score or bypass required evidence.

## 6. Canonical data path

The logical production path is:

`Source → Evidence → Canonical Facts → Normalized Metrics → Valuation → Market Price/Mispricing + Portfolio State/Fit → Core Scoring → Revision/Chase Gates → Decision Snapshot → Opportunity → Capital Allocation → Scenario Simulation → Human Approval`

Rules:

- Web research cannot jump directly to final valuation or allocation.
- Facts and model assumptions remain separate.
- `Evidence_Ledger` / Supabase evidence state stores traceable facts.
- Canonical metric state stores factual snapshots only.
- Normalization owns standardized/economic model inputs.
- Valuation owns model assumptions and scenario outputs.
- Portfolio accounting comes only from reconciled ledger state.
- Capital-allocation scenarios never mutate live holdings.

## 7. Policy versioning

Production decision logic must reference explicit policy versions.

Generic governance lives in:

- `fwios.policy_registry`
- `fwios.policy_versions`

Existing specialized policy tables remain backing implementations until individually cut over.

A policy is production-authoritative only when its version is `ACTIVE` and, when scoring is required, `deterministic_scoring = true`.

`REVISION_SCORE_V1` and `CHASE_SCORE_V1` remain DRAFT until raw evidence/data → 0–100 mappings are explicit and regression-tested. AI must not invent scores to make a gate pass.

## 8. Decision snapshots

`fwios.decision_snapshots` is the reproducibility boundary for downstream capital allocation.

A decision snapshot must identify the exact:

- portfolio batch
- price snapshot
- valuation run
- mispricing snapshot
- Portfolio Fit snapshot
- Revision snapshot
- Chase snapshot
- core score snapshot
- applicable policy versions

Missing/incomplete critical references or draft promotion policies => BLOCKED.

## 9. Capital allocation / rebalancing boundary

M3 must separate:

1. Opportunity Ranking
2. Capital Allocation
3. Portfolio Scenario Simulation
4. Rebalancing Recommendation
5. Human Approval

Allowed scenario modes:

- NO_SELL
- SOFT_REBALANCE
- ACTIVE_REBALANCE

Every action must trace to reconciled portfolio state and, for candidate adds, an applicable decision snapshot. No scenario output can auto-execute a trade.

## 10. Fail-closed rule

Missing, stale, conflicting, schema-invalid, unverified, provenance-free or policy-incomplete critical data becomes BLOCKED.

Do not:

- guess values or component scores;
- use AI-only valuation as verified valuation;
- promote on Quality Score alone;
- force-fill a shortlist;
- treat intrinsic value as expected return without a fresh price layer;
- bypass Portfolio Fit;
- modify live holdings/transactions during research/system work unless explicitly instructed.

Unimplemented model contracts remain `BLOCKED - MODEL NOT IMPLEMENTED`.

## 11. Evidence requirements

Production evidence should record when applicable:

- exact source URL
- source tier
- evidence class
- metric ID
- reported/derived status
- derivation method + inputs
- period/date
- confidence / verification state

RPV2.1 reusable evidence must match Source Registry provenance, recompute age at read time, parse supported legacy Sheet serial dates deterministically, invalidate older current reporting evidence after a later material event, and keep historical-reference evidence separate from current aging rules.

## 12. Research pipeline / controller rules

- One full sector per scheduled run.
- Resume incomplete/RUNNING sector before another.
- Maximum universe 20.
- Maximum sector shortlist 5; never force-fill.
- Compare sector winners against global active candidates; maximum 5 active.
- Model debt remains fail-closed for affected candidates.
- Communication Services research is complete.
- Financials is the queued sector snapshot, but live `Sector_Run_Control` and Supabase controller must be reread before execution.
- Main Roadmap currently prioritizes M2 Promotion hardening; sector automation remains paused until that priority changes.

## 13. Orchestration

Root blockers remain persistent and dependency-aware. Do not create undocumented ad-hoc retry logic.

Architecture Consolidation v1 also adds `fwios.system_events` as a future M4 event/delta foundation. No event trigger is production-active merely because an event row/table exists.

## 14. Documentation handshake

Before material work:

1. Read `System_Foundation`.
2. Read `AGENTS.md`.
3. Read `contracts/system-contract.yaml`.
4. Read `VERSION`.
5. Read `docs/00_SYSTEM_ROADMAP.md`.
6. Re-read relevant Supabase/Sheet controller state.
7. Resolve drift before changing production logic.

After material work, synchronize live foundation plus repository roadmap/architecture in the same workstream when capability, authority, blocker, contract or next action changes.

## 15. Regression discipline

Changes to normalization, valuation routing, policies, scoring, gates, decision snapshots or capital-allocation logic require deterministic regression tests.

Reference regression tickers include ISRG, EOG, BKR, CAVA, TPR, RDDT and PINS.

## 16. Source precedence

1. Latest reconciled portfolio data
2. Focused Wealth-Building rules
3. Personal Investment Strategist framework
4. Production screener/system outputs
5. Current primary-source research
6. Wall Street consensus
7. News/social narratives

When conflict exists, use the higher-priority source and fail closed if the conflict is material and unresolved.
