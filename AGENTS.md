# AGENTS.md — Focused Wealth Investment OS

Mandatory execution contract for AI agents and automations.

Contract version: **FWIOS-CONTRACT-0.87.8**  
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
8. Use latest Decision Snapshot, Opportunity Ranking, New-Cash Allocation, Scenario and Rebalance policies where applicable.
9. Broker-verify price before any real trade decision.

## 4. Portfolio guardrails
- Prefer 5–8 meaningful positions.
- Exceptional single-stock allocation ~30% max; above requires explicit review, not forced selling.
- Phase-1 crypto target ~15–20%; deviations require explicit justification.
- Prefer new cash / soft rebalance before selling high-quality winners.
- Never trim merely because a position appreciated.
- Max 5 active watchlist candidates; max 3 immediate buy candidates.
- Actual new purchase per decision cycle is normally 0–1.
- Legacy portfolio Sheet remains retained for reconciliation/audit/export until M3 traceability/cutover passes.

## 5. Production scoring
Core weights are exactly 30/30/25/15: Business/Thesis 30%, Expected Return/Valuation 30%, Portfolio Fit 25%, Downside/Thesis Risk 15%.
Revision/catalyst/timing/chase are non-core and cannot override hard gates.

## 6. Production path
`Source → Evidence → Canonical Facts → Normalized Metrics → Valuation → Market Price/Mispricing + Portfolio State/Fit → Core Scoring → Revision/Chase → Decision Snapshot → Opportunity Ranking → New-Cash Allocation → Portfolio Scenario Simulation → Rebalancing Recommendation → Human Approval`

Facts and assumptions stay separate. Preview/scenario/recommendation functions never mutate live holdings.

## 7. Production-active deterministic policies
- `POL-REVISION-SCORE-V1`
- `POL-CHASE-SCORE-V1`
- `POL-OPPORTUNITY-RANKING-V1`
- `POL-NEW-CASH-ALLOCATION-V1`
- `POL-PORTFOLIO-SCENARIO-V1`
- `POL-REBALANCE-V1`

AI must never invent or retune scoring, ranking, allocation, scenario or trim math to make a candidate pass.

## 8. M2 exit
M2 PASS with 16/16 decision-policy regressions. PINS Promotion PASS / READY - HUMAN REVIEW. RDDT Mispricing FAIL / GOOD COMPANY - WAIT FOR VALUE. READY never means auto-execution.

## 9. M3.1 Opportunity Ranking — PASS / LIVE
`POL-OPPORTUNITY-RANKING-V1`; 8/8 regressions. Priority = Core Score only. PINS Immediate #1; RDDT Value-Wait #1. Max 3 Immediate / 5 Watchlist; never force-fill.

## 10. M3.2 New-Cash Allocation — PASS / LIVE
`POL-NEW-CASH-ALLOCATION-V1`; 20/20 regressions. New cash first, Immediate Stock candidates only, max one deployed asset/run, new-position starter cap 5% post-money, existing-position staged add capped by 30% ceiling, residual `CASH_THB`, non-mutating.

## 11. M3.3 Portfolio Scenario Simulation — PASS / LIVE
`POL-PORTFOLIO-SCENARIO-V1`; 28/28 regressions. Modes: `NO_SELL`, `SOFT_REBALANCE`, `ACTIVE_REBALANCE`. ADD traces to active ranking + Decision Snapshot. TRIM must target a current holding, stay within current value and carry explicit economic/risk rationale. Appreciation-only trim rationale is forbidden. Full-portfolio expected upside fails closed when coverage is incomplete.

Holding valuation coverage may come from fresh production holding valuation lineage. Current NVDA route `SEMIS_MIDCYCLE_DCF_V1::1.0` is production-live, so NVDA↔PINS changed-assets expected-value comparison is now covered. Other uncovered holdings remain blocked; no proxy is allowed.

## 12. Semiconductor Designer valuation v1 — production live
Model: `SEMIS_MIDCYCLE_DCF_V1::1.0`, kernel `FCF_COMPOUNDER`.
Required inputs: revenue LTM, gross margin, inventory days, direct-customer concentration, FCF LTM, conservative net cash, shares outstanding, plus signed pending acquisition consideration when applicable.

NVDA 2026-09-05 production parity:
- Bear FV 87.03032203
- Base FV 166.16708908
- Bull FV 273.20947981
- PW FV 173.14349500
- Price snapshot `PX-NVDA-20260904` = 230.34
- model regression `REG-SEMIS-V1-NVDA-PARITY` = PASS.

The valuation is an opportunity-cost input, not a standalone trim instruction.

## 13. M3.4 Rebalancing Recommendation — PASS / LIVE
Policy: `POL-REBALANCE-V1`; 12/12 regressions PASS.

Rules:
- consume new cash before considering a trim;
- ADD must be active Immediate candidate with Decision Snapshot valuation;
- trim source must be a current holding with fresh production valuation and concentration review in v1;
- minimum PW expected-return edge = 25 percentage points;
- recommended trim = min(remaining approved candidate capacity after new cash, source concentration excess above 30%);
- never sell more than can be redeployed into the approved opportunity;
- 30% is a review threshold, not a mandatory target;
- `PRICE_APPRECIATION_ONLY` / appreciation-only rationale is forbidden;
- uncovered holdings are excluded, not proxied;
- full-portfolio valuation coverage is not required for a changed-assets comparison when every changed non-cash asset is covered;
- all outputs require human review and broker price verification before any real trade.

Synthetic parity only:
- THB 0 new cash → NVDA trim ~17,045.30 → PINS add ~17,045.30.
- THB 10k new cash → use 10k first, then NVDA trim ~7,545.30 to fill PINS starter capacity.
- THB 50k new cash → PINS starter cap funded by new cash; NVDA trim = 0.

These are regression previews, not live trade instructions. No recommendation run has been materialized by activation.

## 14. M3 boundary
1. Opportunity Ranking — PASS / LIVE
2. New-Cash Allocation — PASS / LIVE
3. Portfolio Scenario Simulation — PASS / LIVE
4. Rebalancing Recommendation — PASS / LIVE
5. Human Approval / Cutover — **NEXT**

M3.5 must prove end-to-end traceability from source transaction → position → portfolio batch → Decision Snapshot / holding valuation → ranking → allocation/scenario → recommendation → explicit human approval, with no unexplained quantity, value, cost basis or realized-P&L differences.

## 15. Fail-closed rule
Missing, stale, conflicting, schema-invalid, unverified, provenance-free or policy-incomplete critical data => BLOCKED. Never substitute historical return, cost basis, narrative target or unverified consensus for missing expected-return valuation. Never force-fill or bypass hard gates.

## 16. Research/controller
Communication Services complete; Financials queued. Sector automation remains manually PAUSED while M3 is Main Roadmap priority. `fwios.system_events` remains M4 foundation only.

## 17. Documentation handshake
Before material work read live `System_Foundation`, this file, `contracts/system-contract.yaml`, `VERSION`, roadmap, architecture and relevant live Supabase/Sheet state. Resolve drift first. After material changes synchronize roadmap/architecture/live foundation.

During remaining M3, Google Sheets receives only `System_Foundation` / audit-status updates; do not add production logic/config there.

## 18. Regression discipline
Changes to normalization, valuation, policies, Decision Snapshots, ranking, allocation, scenario or rebalancing logic require deterministic regressions. Reference tickers include ISRG, EOG, BKR, CAVA, TPR, RDDT, PINS and NVDA.

## 19. Source precedence
1. Latest reconciled portfolio data
2. Focused Wealth-Building rules
3. Personal Investment Strategist framework
4. Production system outputs
5. Current primary-source research
6. Wall Street consensus
7. News/social narratives

Use the higher-priority source when conflicts occur; fail closed when material conflicts remain unresolved.
