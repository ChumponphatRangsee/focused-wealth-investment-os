# AGENTS.md — Focused Wealth Investment OS

Mandatory execution contract for AI agents and automations.

Contract version: **FWIOS-CONTRACT-0.87.10**  
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
8. Use latest Decision Snapshot, Opportunity Ranking, New-Cash Allocation, Scenario, Rebalance and Human Approval policies where applicable.
9. Broker-verify price before any real trade decision.

## 4. Portfolio guardrails
- Prefer 5–8 meaningful positions.
- Exceptional single-stock allocation ~30% max; above requires explicit review, not forced selling.
- Phase-1 crypto target ~15–20%; deviations require explicit justification.
- Prefer new cash / soft rebalance before selling high-quality winners.
- Never trim merely because a position appreciated.
- Max 5 active watchlist candidates; max 3 immediate buy candidates.
- Actual new purchase per decision cycle is normally 0–1.
- M3 cutover is PASS. Legacy Sheets may be reduced only after the new monitoring dashboard/read-model handoff preserves required audit access.

## 5. Production scoring
Core weights are exactly 30/30/25/15: Business/Thesis 30%, Expected Return/Valuation 30%, Portfolio Fit 25%, Downside/Thesis Risk 15%.
Revision/catalyst/timing/chase are non-core and cannot override hard gates.

## 6. Production path
`Source → Evidence → Canonical Facts → Normalized Metrics → Valuation → Market Price/Mispricing + Portfolio State/Fit → Core Scoring → Revision/Chase → Decision Snapshot → Opportunity Ranking → New-Cash Allocation → Portfolio Scenario Simulation → Rebalancing Recommendation → Human Approval`

Facts and assumptions stay separate. Preview/scenario/recommendation/approval functions never place orders or mutate live holdings.

## 7. Production-active deterministic policies
- `POL-REVISION-SCORE-V1`
- `POL-CHASE-SCORE-V1`
- `POL-OPPORTUNITY-RANKING-V1`
- `POL-NEW-CASH-ALLOCATION-V1`
- `POL-PORTFOLIO-SCENARIO-V1`
- `POL-REBALANCE-V1`
- `POL-HUMAN-APPROVAL-V1`

AI must never invent or retune scoring, ranking, allocation, scenario, trim or approval gates to make a candidate pass.

## 8. M2 exit
M2 PASS with 16/16 decision-policy regressions. PINS Promotion PASS / READY - HUMAN REVIEW. RDDT Mispricing FAIL / GOOD COMPANY - WAIT FOR VALUE. READY never means auto-execution.

## 9. M3.1 Opportunity Ranking — PASS / LIVE
`POL-OPPORTUNITY-RANKING-V1`; 8/8 regressions. Priority = Core Score only. PINS Immediate #1; RDDT Value-Wait #1. Max 3 Immediate / 5 Watchlist; never force-fill.

## 10. M3.2 New-Cash Allocation — PASS / LIVE
`POL-NEW-CASH-ALLOCATION-V1`; 20/20 regressions. New cash first, Immediate Stock candidates only, max one deployed asset/run, new-position starter cap 5% post-money, existing-position staged add capped by 30% ceiling, residual `CASH_THB`, non-mutating.

## 11. M3.3 Portfolio Scenario Simulation — PASS / LIVE
`POL-PORTFOLIO-SCENARIO-V1`; 28/28 regressions. Modes: `NO_SELL`, `SOFT_REBALANCE`, `ACTIVE_REBALANCE`. ADD traces to active ranking + Decision Snapshot. TRIM must target a current holding, stay within current value and carry explicit economic/risk rationale. Appreciation-only trim rationale is forbidden. Full-portfolio expected upside fails closed when coverage is incomplete.

## 12. Semiconductor Designer valuation v1 — production live
Model: `SEMIS_MIDCYCLE_DCF_V1::1.0`, kernel `FCF_COMPOUNDER`.
NVDA reference parity: Bear 87.03032203 / Base 166.16708908 / Bull 273.20947981 / PW 173.14349500 at `PX-NVDA-20260904`; `REG-SEMIS-V1-NVDA-PARITY` PASS. This is an opportunity-cost input, not a standalone trim instruction.

## 13. M3.4 Rebalancing Recommendation — PASS / LIVE
Policy: `POL-REBALANCE-V1`; 12/12 regressions PASS.
- consume new cash before trim;
- ADD must be active Immediate with Decision Snapshot valuation;
- trim source must be a current holding with fresh production valuation and concentration review;
- minimum PW expected-return edge = 25 percentage points;
- trim = min(remaining approved candidate capacity, source concentration excess above 30%);
- never sell more than can be redeployed;
- 30% is review threshold, not forced target;
- appreciation-only rationale forbidden;
- human review + broker price verification required.

Synthetic parity remains regression-only; it is never a live trade instruction.

## 14. M3.5 Human Approval / Cutover — PASS / LIVE
Policy: `POL-HUMAN-APPROVAL-V1`; **30/30 regressions PASS**.

Architecture:
`Immutable Recommendation Snapshot → Immutable Approval Packet → Append-only Approval Event`.

Rules:
- only `PRODUCTION_USER_REQUESTED` packets are approvable;
- `CUTOVER_VALIDATION` and `SYNTHETIC_TEST` can never be approved;
- APPROVED/REJECTED require HUMAN actor; EXPIRED/STALE require SYSTEM actor;
- approval requires fingerprint integrity, same current portfolio batch, same active ranking and fresh changed-asset price/valuation lineage;
- terminal states are APPROVED / REJECTED / EXPIRED / STALE;
- stale or expired packets require a new recommendation/packet;
- approval events constrain `broker_order_created=false` and `portfolio_mutation_applied=false`.

Cutover validation:
- 29/29 transactions PASS;
- 16/16 positions PASS;
- 9/9 end-to-end traceability layers PASS;
- validation recommendation `REBAL-M3-CUTOVER-20260905-01` is `CUTOVER_VALIDATION` only;
- validation packet `APPROVAL-M3-CUTOVER-20260905-01` is `VALIDATION_ONLY`;
- production-user recommendation count at cutover = 0;
- human approval-event count at cutover = 0;
- M3 cutover certificate = PASS.

## 15. M3 boundary — COMPLETE
1. Opportunity Ranking — PASS / LIVE
2. New-Cash Allocation — PASS / LIVE
3. Portfolio Scenario Simulation — PASS / LIVE
4. Rebalancing Recommendation — PASS / LIVE
5. Human Approval / Cutover — PASS / LIVE

M3 is complete. A later real approval still does not execute a trade; broker execution remains an explicit human step outside the approval ledger.

## 16. Dashboard Read Model v1 — PASS / LIVE
Supabase exposes six private `security_invoker` monitoring views:
- `fwios.v_dashboard_holdings`
- `fwios.v_dashboard_account_summary`
- `fwios.v_dashboard_opportunities`
- `fwios.v_dashboard_current_action`
- `fwios.v_dashboard_alerts`
- `fwios.v_dashboard_system_health`

Regression parity is **17/17 PASS**. The monitoring Sheet is **Focused Wealth Dashboard - Chumponphat** (`17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8`). It has one visible `Dashboard` tab and one hidden `_Data` snapshot tab.

Account View may change only Portfolio Value, P&L and Holdings display. Risk, Portfolio Fit, concentration, crypto and rebalancing decisions always use the consolidated portfolio. Total P&L means latest-batch realized P&L + current open-position unrealized P&L. Google Sheets must not recalculate production scoring, allocation, rebalancing or approval rules.

The current Sheet refresh mode is controlled snapshot export; do not claim a direct live database connection until a refresh workflow is explicitly implemented and verified.

## 17. Fail-closed rule
Missing, stale, conflicting, schema-invalid, unverified, provenance-free or policy-incomplete critical data => BLOCKED. Never substitute historical return, cost basis, narrative target or unverified consensus for missing expected-return valuation. Never force-fill or bypass hard gates. Rejected, expired, stale or non-actionable approval packets cannot execute.

## 18. Research/controller
Communication Services complete; Financials queued. Sector automation remains manually PAUSED while dashboard refresh/handoff work is the explicit priority. `fwios.system_events` remains M4 foundation only.

## 19. Post-M3 next action
**Verify Dashboard Refresh Workflow + Plan Legacy Reduction.**
- Keep Supabase as source of truth.
- Keep the new monitoring Sheet read-only/display-only.
- Define and verify controlled Supabase → Sheet refresh behavior before calling the Sheet real-time/live-connected.
- Preserve legacy audit/reconciliation access until a reduction plan is explicitly verified; do not delete history automatically.

## 20. Documentation handshake
Before material work read live `System_Foundation`, this file, `contracts/system-contract.yaml`, `VERSION`, roadmap, architecture and relevant live Supabase/Sheet state. Resolve drift first. After material changes synchronize roadmap/architecture/live foundation.

## 21. Regression discipline
Changes to normalization, valuation, policies, Decision Snapshots, ranking, allocation, scenario, rebalancing, approval or dashboard read-model semantics require deterministic regressions. Reference tickers include ISRG, EOG, BKR, CAVA, TPR, RDDT, PINS and NVDA.

## 22. Source precedence
1. Latest reconciled portfolio data
2. Focused Wealth-Building rules
3. Personal Investment Strategist framework
4. Production system outputs
5. Current primary-source research
6. Wall Street consensus
7. News/social narratives

Use the higher-priority source when conflicts occur; fail closed when material conflicts remain unresolved.