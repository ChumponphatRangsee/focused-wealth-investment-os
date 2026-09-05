# AGENTS.md — Focused Wealth Investment OS

Mandatory execution contract for AI agents and automations.

Contract version: **FWIOS-CONTRACT-0.87.7**  
Compatible live foundation: **0.87**

## 1. Objective
Optimize for aggressive but disciplined capital growth toward the Phase-1 THB 1,000,000 target.

> Focus creates upside. Position sizing creates survival. Valuation creates margin of safety.

Human execution only. Never auto-buy or auto-sell.

## 2. Authority model
- **Supabase = System of Record / State**.
- **GitHub = Logic / Contracts / Tests / Migrations**.
- **Google Sheets = View / Compatibility / Reconciliation / Audit / Export**.
- **AI = Research / interpretation / explanation / controlled orchestration**, not accounting, hidden scoring or trade execution.

Live portfolio/system/controller state overrides stale documentation.

## 3. Before any investment recommendation
1. Read latest reconciled portfolio state and relevant source transactions.
2. Apply Focused Wealth-Building guardrails.
3. Analyze candidates in portfolio context.
4. Verify current price, financials, valuation inputs and material news.
5. Prefer primary company/SEC/IR evidence for canonical facts.
6. Check concentration and crypto exposure.
7. Challenge FOMO, anchoring, confirmation bias and narrative-driven reasoning.
8. Use the latest reproducible Decision Snapshot, active Opportunity Ranking, New-Cash Allocation and Scenario policies where applicable.
9. Broker-verify price before any real trade decision.

## 4. Portfolio guardrails
- Prefer 5–8 meaningful positions.
- Exceptional single-stock allocation ~30% max; above requires explicit review.
- Phase-1 crypto target ~15–20%; deviations require explicit justification.
- Prefer new cash / soft rebalance before selling high-quality winners.
- Never trim merely because a position appreciated.
- Max 5 active watchlist candidates; max 3 immediate buy candidates.
- Actual new purchase per decision cycle is normally 0–1.
- Legacy portfolio Sheet remains retained for reconciliation/audit/export until M3 traceability passes.

## 5. Production scoring
Core weights are exactly 30/30/25/15:
- Business / Thesis 30%
- Expected Return / Valuation 30%
- Portfolio Fit 25%
- Downside / Thesis Risk 15%

Revision/catalyst/timing/chase are non-core and cannot override hard gates.

## 6. Production path
`Source → Evidence → Canonical Facts → Normalized Metrics → Valuation → Market Price/Mispricing + Portfolio State/Fit → Core Scoring → Revision/Chase Gates → Decision Snapshot → Opportunity Ranking → New-Cash Allocation → Portfolio Scenario Simulation → Rebalancing Recommendation → Human Approval`

Facts and model assumptions remain separate. Web research cannot jump directly to valuation/allocation. Portfolio accounting comes only from reconciled ledger state. Preview/scenario functions never mutate live holdings.

## 7. Policy versioning
Production-active deterministic policies include:
- `POL-REVISION-SCORE-V1`
- `POL-CHASE-SCORE-V1`
- `POL-OPPORTUNITY-RANKING-V1`
- `POL-NEW-CASH-ALLOCATION-V1`
- `POL-PORTFOLIO-SCENARIO-V1`

`REBALANCE` remains DRAFT until M3.4 recommendation logic and traceability/valuation gates pass.

AI must never invent or retune component scores, ranking weights, allocation math, scenario math or trim logic to make a candidate pass.

## 8. Decision Snapshots
`fwios.decision_snapshots` is the reproducibility boundary for downstream allocation/scenario work. Missing or incomplete critical references or inactive required policies => BLOCKED.

## 9. M2 exit state
M2 Promotion hardening is PASS with 16/16 decision-policy regressions.
- PINS: Promotion PASS / `READY - HUMAN REVIEW`.
- RDDT: Mispricing FAIL / `GOOD COMPANY - WAIT FOR VALUE`.
READY never means auto-execution.

## 10. M3.1 Opportunity Ranking — production live
Policy: `POL-OPPORTUNITY-RANKING-V1`.
- Priority = Core Score; no second weighted investment score.
- Promotion PASS + integrity PASS → Immediate.
- Only insufficient Mispricing with other hard gates PASS → Value-Wait.
- Max 3 Immediate / max 5 Watchlist; never force-fill.
- 8/8 regressions PASS.
- `OPPRANK-M3-20260905-01`: PINS Immediate #1; RDDT Value-Wait #1.

## 11. M3.2 New-Cash Capital Allocation — production live
Policy: `POL-NEW-CASH-ALLOCATION-V1`.
- Positive new cash only.
- Latest portfolio/ranking batches must match.
- Immediate candidates only; v1 supports Stock candidates.
- Max one deployed asset per run.
- New-position starter cap 5% post-money.
- Existing-position staged add = min(5% post-money, headroom to 30%).
- Existing stock already >30% gets zero add capacity.
- Residual capital remains `CASH_THB`; never force-fill.
- Preview is non-mutating.
- 20/20 regressions PASS.

Synthetic parity only: 10k → PINS 10k; 50k → PINS 19,545.30 + cash 30,454.70; 100k → PINS 22,045.30 + cash 77,954.70.

## 12. M3.3 Portfolio Scenario Simulation — production live
Policy: `POL-PORTFOLIO-SCENARIO-V1`.

Modes:
- `NO_SELL`: positive new cash, no TRIM, reuses M3.2 allocation math.
- `SOFT_REBALANCE`: no TRIM in v1; one-time new-cash arithmetic intentionally equals NO_SELL until recurring DCA/redirection state exists.
- `ACTIVE_REBALANCE`: accepts hypothetical trim inputs for simulation but does not decide which holding should be trimmed.

Scenario invariants:
- every ADD traces to active ranking + Decision Snapshot;
- every TRIM must target a current holding, stay within current value and carry explicit economic/risk rationale;
- `PRICE_APPRECIATION_ONLY` / `APPRECIATION_ONLY` trim rationale is forbidden;
- RDDT Value-Wait cannot receive capital;
- residual cash is held;
- full portfolio expected upside requires valuation coverage for all risk assets;
- missing valuation on a changed asset blocks net expected-value comparison;
- no preview materializes a trade or mutates live holdings.

M3.3 regressions: **28/28 PASS**.

Current data-coverage state at activation:
- existing holdings expected-upside valuation coverage = **0%**;
- therefore `full_portfolio_pw_upside` is `BLOCKED - INCOMPLETE PORTFOLIO VALUATION COVERAGE`;
- PINS ADD-side expected value can still be calculated from exact `DEC-PINS-M2-20260905-V2 → MIS-PINS-20260904` lineage;
- an ACTIVE scenario that trims NVDA cannot calculate net expected-value improvement until NVDA has traceable valuation.

This coverage blocker does not invalidate the scenario engine; it gates M3.4 economic trim recommendation.

## 13. M3 boundary
Current order:
1. Opportunity Ranking — **PASS / LIVE**
2. New-Cash Capital Allocation — **PASS / LIVE**
3. Portfolio Scenario Simulation — **PASS / LIVE**
4. Rebalancing Recommendation — **NEXT / VALUATION-COVERAGE GATED**
5. Human Approval / Cutover

Before M3.4 recommends any trim, relevant trim candidates must have traceable current valuation/expected-return coverage. Prioritize coverage work based on portfolio relevance; concentration review may prioritize NVDA for modeling, but that is not itself a trim recommendation.

## 14. Fail-closed rule
Missing, stale, conflicting, schema-invalid, unverified, provenance-free or policy-incomplete critical data => BLOCKED.
Never substitute historical return, cost basis, narrative target or unverified consensus for missing expected-return valuation. Never force-fill allocation, bypass hard gates, or modify live holdings during system work unless explicitly instructed.

## 15. Evidence requirements
Production evidence should carry exact source/provenance, metric/period, reported-vs-derived status, derivation lineage, confidence and verification state. RPV2.1 reusable evidence must recompute freshness and invalidate older current evidence after later material events.

## 16. Research/controller rules
- One full sector per scheduled run; resume incomplete run first.
- Max universe 20; max sector shortlist 5; never force-fill.
- Max 5 global active candidates.
- Model debt remains fail-closed for affected candidates.
- Communication Services is complete; Financials is queued.
- Sector automation remains manually PAUSED while M3 is Main Roadmap priority.

## 17. Orchestration
`fwios.system_events` remains M4 foundation only; no event trigger is production-active merely because the table exists.

## 18. Documentation handshake
Before material work read live `System_Foundation`, this file, `contracts/system-contract.yaml`, `VERSION`, roadmap, architecture and relevant live Supabase/Sheet state. Resolve drift first. After material work synchronize roadmap/architecture/live foundation when capability, authority, blocker, contract or next action changes.

Google Sheets should receive only `System_Foundation` / audit-status updates during M3.2–M3.5; do not add production logic/config there.

## 19. Regression discipline
Changes to normalization, valuation, policies, scoring, Decision Snapshots, ranking, allocation, scenario or rebalancing logic require deterministic regressions. Reference tickers include ISRG, EOG, BKR, CAVA, TPR, RDDT and PINS.

## 20. Source precedence
1. Latest reconciled portfolio data
2. Focused Wealth-Building rules
3. Personal Investment Strategist framework
4. Production system outputs
5. Current primary-source research
6. Wall Street consensus
7. News/social narratives

Use the higher-priority source when conflicts occur; fail closed when material conflicts remain unresolved.
