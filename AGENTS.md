# AGENTS.md — Focused Wealth Investment OS

Mandatory execution contract for AI agents and automations.

Contract version: **FWIOS-CONTRACT-0.87.6**  
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
8. Use the latest reproducible Decision Snapshot, active Opportunity Ranking and active allocation policy where applicable.
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
`Source → Evidence → Canonical Facts → Normalized Metrics → Valuation → Market Price/Mispricing + Portfolio State/Fit → Core Scoring → Revision/Chase Gates → Decision Snapshot → Opportunity Ranking → New-Cash Allocation → Scenario Simulation → Rebalancing Recommendation → Human Approval`

Facts and model assumptions remain separate. Web research cannot jump directly to valuation/allocation. Portfolio accounting comes only from reconciled ledger state. Preview/scenario functions never mutate live holdings.

## 7. Policy versioning
Production policy governance lives in `fwios.policy_registry` and `fwios.policy_versions`.

Production-active deterministic policies include:
- `POL-REVISION-SCORE-V1`
- `POL-CHASE-SCORE-V1`
- `POL-OPPORTUNITY-RANKING-V1`
- `POL-NEW-CASH-ALLOCATION-V1`

`REBALANCE` remains DRAFT until M3 scenario/rebalancing design and regressions pass.

AI must never invent or retune component scores, ranking weights, allocation math or trim logic to make a candidate pass.

## 8. Decision Snapshots
`fwios.decision_snapshots` is the reproducibility boundary for downstream allocation. It must reference exact portfolio batch, price, valuation, mispricing, Portfolio Fit, Revision, Chase, core score and policy versions.

Missing/incomplete critical references or non-active required policies => BLOCKED.

## 9. M2 exit state
M2 Promotion hardening is PASS with 16/16 decision-policy regressions.

- PINS: core 87.60; Revision PASS; Chase PASS; Mispricing PASS; Promotion PASS; `READY - HUMAN REVIEW`.
- RDDT: core 72.15; Revision PASS; Chase PASS; Mispricing FAIL; `GOOD COMPANY - WAIT FOR VALUE`.

READY never means auto-execution.

## 10. M3.1 Opportunity Ranking — production live
Policy: `POL-OPPORTUNITY-RANKING-V1`.

Rules:
- consume only latest production Decision Snapshot per ticker;
- `priority_score = core_score`; no second weighted investment score;
- tie-break: Expected Return → Portfolio Fit → Downside → Business/Thesis → ticker;
- Promotion PASS + input integrity PASS → `IMMEDIATE_BUY_CANDIDATE`;
- only insufficient Mispricing with every other hard gate PASS → `WATCHLIST_VALUE_WAIT`;
- all other states → `EXCLUDED`;
- max 3 Immediate / max 5 Watchlist; never force-fill.

M3.1 regressions: **8/8 PASS**. First production run: `OPPRANK-M3-20260905-01`.

## 11. M3.2 New-Cash Capital Allocation — production live
Policy: `POL-NEW-CASH-ALLOCATION-V1`.

Rules:
- positive new cash only;
- latest reconciled portfolio batch must match the ranking run portfolio batch;
- only `IMMEDIATE_BUY_CANDIDATE` may receive capital;
- v1 supports Stock candidates only; unsupported asset classes fail closed;
- maximum 1 deployed asset per allocation run;
- highest-ranked candidate with positive allocation capacity wins;
- new position starter cap = 5% of post-money portfolio value;
- existing position staged-add cap = min(5% of post-money value, headroom to 30% stock ceiling);
- existing stock already above 30% receives zero add capacity;
- residual cash remains `CASH_THB`; never force-fill the next candidate;
- allocation previews report concentration, crypto and focus effects;
- existing review deviations remain visible and never auto-trigger sales.

M3.2 regressions: **20/20 PASS**.

Current synthetic parity previews on `PORTFOLIO-M2-20260905-01` / `OPPRANK-M3-20260905-01`:
- THB 10k → PINS 10k / cash 0.
- THB 50k → PINS 19,545.30 / cash 30,454.70.
- THB 100k → PINS 22,045.30 / cash 77,954.70.

These are regression previews only, not a trade instruction. No production allocation run exists until the user supplies a real new-cash amount or explicitly asks to materialize a scenario.

## 12. M3 boundary
Current order:
1. Opportunity Ranking — **PASS / LIVE**
2. New-Cash Capital Allocation — **PASS / LIVE**
3. Portfolio Scenario Simulation — **NEXT**
4. Rebalancing Recommendation
5. Human Approval

Scenario modes: `NO_SELL`, `SOFT_REBALANCE`, `ACTIVE_REBALANCE`.

Each ADD must trace to active Opportunity Ranking + production Decision Snapshot. Each TRIM must trace to reconciled portfolio state and explicit economic/risk rationale. No scenario may mutate live holdings.

## 13. Fail-closed rule
Missing, stale, conflicting, schema-invalid, unverified, provenance-free or policy-incomplete critical data => BLOCKED.

Never guess values/scores, use AI-only valuation as verified valuation, promote on quality alone, force-fill a shortlist/allocation, bypass Portfolio Fit/Mispricing, convert a non-mispricing hard failure into Value-Wait, or modify live holdings during system work unless explicitly instructed.

## 14. Evidence requirements
Production evidence should carry exact URL, source tier/class, metric ID where applicable, reported/derived status, derivation inputs, period/date, confidence and verification state.

RPV2.1 reusable evidence must match Source Registry provenance, recompute age at read time, invalidate older current evidence after later material events, and keep historical references separate from current aging rules.

## 15. Research/controller rules
- One full sector per scheduled run; resume incomplete run first.
- Max universe 20; max sector shortlist 5; never force-fill.
- Max 5 global active candidates.
- Model debt remains fail-closed for affected candidates.
- Communication Services is complete; Financials is queued.
- Sector automation remains manually PAUSED while M3 is the Main Roadmap priority unless live controller/roadmap explicitly changes.

## 16. Orchestration
Root blockers remain persistent and dependency-aware. `fwios.system_events` is M4 foundation only; no event trigger is production-active merely because the table exists.

## 17. Documentation handshake
Before material work read:
1. live `System_Foundation`
2. `AGENTS.md`
3. `contracts/system-contract.yaml`
4. `VERSION`
5. `docs/00_SYSTEM_ROADMAP.md`
6. `docs/01_SYSTEM_ARCHITECTURE.md`
7. relevant Supabase/Sheet controller state

Resolve drift before changing production logic. After material changes synchronize live foundation plus repository roadmap/architecture when capability, authority, blocker, contract or next action changes.

Google Sheets should receive only System_Foundation/Audit status during M3.2–M3.5; do not add new production logic/config there.

## 18. Regression discipline
Changes to normalization, valuation, policies, scoring, gates, Decision Snapshots, Opportunity Ranking, allocation or scenario logic require deterministic regressions.

Reference tickers include ISRG, EOG, BKR, CAVA, TPR, RDDT and PINS.

## 19. Source precedence
1. Latest reconciled portfolio data
2. Focused Wealth-Building rules
3. Personal Investment Strategist framework
4. Production system outputs
5. Current primary-source research
6. Wall Street consensus
7. News/social narratives

Use the higher-priority source when conflicts occur; fail closed when material conflicts remain unresolved.
