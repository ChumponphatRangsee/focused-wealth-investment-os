# AGENTS.md — Focused Wealth Investment OS

Mandatory execution contract for AI agents and automations.

Contract version: **FWIOS-CONTRACT-0.87.11**  
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
8. Clear **Quality / Durability Hardening** before treating a candidate as Immediate.
9. Use latest Decision Snapshot, Opportunity Ranking, New-Cash Allocation, Scenario, Rebalance and Human Approval policies where applicable.
10. Broker-verify price before any real trade decision.

## 4. Portfolio guardrails
- Prefer 5–8 meaningful positions.
- Exceptional single-stock allocation ~30% max; above requires explicit review, not forced selling.
- Phase-1 crypto target ~15–20%; deviations require explicit justification.
- Prefer new cash / soft rebalance before selling high-quality winners.
- Never trim merely because a position appreciated.
- Max 5 active watchlist candidates; max 3 immediate buy candidates.
- Actual new purchase per decision cycle is normally 0–1.
- No force-fill: if nothing clears the gates, hold cash.

## 5. Production scoring
Core weights remain exactly:
- Business / Thesis 30%
- Expected Return / Valuation 30%
- Portfolio Fit 25%
- Downside / Thesis Risk 15%

Active scoring policy: `POL-DATA-SCORING-V3-DURABILITY` / `FWB-DATA-SCORING-V3-DURABILITY`.

Expected Return v3 is continuous and confidence-adjusted:
`(60% × base-upside score + 40% × PW-upside score) × valuation confidence`.

`continuous_upside_score(u) = clamp(50 + 100*u, 0, 100)`.

Historical stock return, cost basis, narrative targets or unverified consensus can never substitute for expected return.

## 6. Quality / Durability Hardening — ACTIVE
Policy: `POL-QUALITY-HARDENING-V1`.

Immediate promotion requires **all four** gates to PASS:
1. **Business Durability** — point-in-time growth cannot be extrapolated into a multi-year valuation without a verified durability anchor. Default anchor is >=3 years of comparable evidence or an explicitly justified alternative.
2. **Owner Earnings** — reported FCF must be reconciled with dilution/SBC economics when SBC is material. <=10% SBC/revenue is a clean narrow pass; >10% requires reconciliation; >20% hard review; >30% fail.
3. **Value Trap** — extreme modeled mispricing (>=75% trigger) requires verified counter-thesis evidence explaining why the market discount is likely wrong. Long-horizon price weakness is only a review trigger.
4. **Valuation Robustness** — assumptions must remain defensible under conservative scenarios. Bear downside worse than 30% triggers review; worse than 50% fails v1.

Gate confidence factors: PASS 1.0 / REVIEW 0.7 / BLOCKED 0.4 / FAIL 0.0. Missing critical hardening evidence => BLOCKED.

AI must never invent durability, owner-earnings, value-trap or robustness evidence merely to make a candidate pass.

## 7. Production path
`Source → Evidence → Canonical Facts → Normalized Metrics → Valuation → Market Price/Mispricing + Portfolio State/Fit → Quality/Durability Hardening → Core Scoring → Revision/Chase → Decision Snapshot → Opportunity Ranking → New-Cash Allocation → Portfolio Scenario → Rebalancing Recommendation → Human Approval`.

Facts and assumptions stay separate. Preview/scenario/recommendation/approval functions never place orders or mutate live holdings.

## 8. Production-active deterministic policies
- `POL-DATA-SCORING-V3-DURABILITY`
- `POL-QUALITY-HARDENING-V1`
- `POL-REVISION-SCORE-V1`
- `POL-CHASE-SCORE-V1`
- `POL-OPPORTUNITY-RANKING-V2`
- `POL-NEW-CASH-ALLOCATION-V1`
- `POL-PORTFOLIO-SCENARIO-V1`
- `POL-REBALANCE-V1`
- `POL-HUMAN-APPROVAL-V1`

AI must never retune deterministic gates ad hoc to make a name pass.

## 9. Current Communication Services decision state
Quality-hardening regressions: **20/20 PASS**; live verification: **11/11 PASS**.

PINS is no longer Immediate:
- Hardening snapshot: `HARD-PINS-20260906-V1`
- Expected Return score: 100 → **40**
- Core score: 87.6 → **69.6**
- Hardening: **BLOCKED**
- Bucket: **WATCHLIST_MODEL_REVIEW**
- Reason: durability, owner-earnings/dilution, extreme-mispricing counter-thesis and valuation-robustness evidence are incomplete.

RDDT remains:
- Expected Return score: **24.7607**
- Core score: **66.0782**
- Bucket: **WATCHLIST_VALUE_WAIT**
- Mispricing remains insufficient; hardening is also incomplete before any future Immediate promotion.

Current Immediate count = **0**. New-cash preview with no Immediate candidate must HOLD CASH.

## 10. Opportunity Ranking v2 — PASS / LIVE
Policy `POL-OPPORTUNITY-RANKING-V2`.
- Promotion PASS + Hardening PASS → `IMMEDIATE_BUY_CANDIDATE`
- Mispricing insufficient + other required gates pass → `WATCHLIST_VALUE_WAIT`
- Mispricing PASS but Hardening not PASS → `WATCHLIST_MODEL_REVIEW`
- Otherwise → EXCLUDED
- Priority remains Core Score; max Immediate 3 / Watchlist 5; no force-fill.

Current run: `OPPRANK-QH-20260906-01`.

## 11. M3.2 New-Cash Allocation — PASS / LIVE
`POL-NEW-CASH-ALLOCATION-V1`; 20/20 regressions. New cash first, Immediate Stock candidates only, max one deployed asset/run, starter cap 5% post-money, residual cash held, non-mutating.

With the current zero-Immediate ranking, allocation preview holds all new cash rather than forcing a candidate.

## 12. M3.3 Portfolio Scenario — PASS / LIVE
`POL-PORTFOLIO-SCENARIO-V1`; 28/28 regressions. NO_SELL / SOFT_REBALANCE / ACTIVE_REBALANCE. ADD requires active ranking + Decision Snapshot. Appreciation-only trim rationale is forbidden. Full-portfolio expected upside fails closed when valuation coverage is incomplete.

## 13. Holding valuation / M3.4 Rebalancing
Semiconductor Designer model `SEMIS_MIDCYCLE_DCF_V1::1.0` remains production-live for NVDA lineage.

`POL-REBALANCE-V1`; 12/12 PASS:
- new cash before trim;
- ADD requires active Immediate + traceable Decision Snapshot valuation;
- source trim requires current valuation-covered concentration-review holding;
- minimum PW expected-return edge 25pp;
- 30% is a review threshold, not forced target;
- appreciation-only trim forbidden;
- human review + broker price verification required.

Because the current ranking has no Immediate candidate, the prior synthetic NVDA→PINS path is not a current actionable path.

## 14. M3.5 Human Approval / Cutover — PASS / LIVE
`POL-HUMAN-APPROVAL-V1`; 30/30 PASS.

`Immutable Recommendation Snapshot → Immutable Approval Packet → Append-only Approval Event`.
Only `PRODUCTION_USER_REQUESTED` is approvable. Validation/test scopes are never actionable. Approval does not place broker orders or mutate portfolio accounting.

Cutover proof remains 29/29 transactions, 16/16 positions and 9/9 traceability layers PASS.

## 15. M3 boundary
M3.1–M3.5 remain **COMPLETE / CUTOVER PASS**. Quality hardening changes candidate eligibility, not the human-execution boundary.

## 16. Dashboard + Auto Refresh — PASS / LIVE
Monitoring Sheet: **Focused Wealth Dashboard - Chumponphat** (`17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8`).

Supabase private dashboard read models remain the source; Google Sheet is downstream/display-only. Account View may change Value/P&L/Holdings display only; risk/fit/rebalancing remain consolidated.

Auto-refresh:
`dashboard read models → dashboard_refresh_payload_v1() → dashboard-refresh-csv-v1 → IMPORTDATA → _Data → Dashboard`.

Dashboard read-model regressions 17/17 PASS; auto-refresh 14/14 PASS. Current refresh payload remains PASS and Current Action is `NO_ACTIONABLE_OPPORTUNITY`.

Do not describe auto-pull as guaranteed realtime or 24/7 closed-file streaming.

## 17. Fail-closed rule
Missing, stale, conflicting, schema-invalid, unverified, provenance-free, policy-incomplete **or quality-hardening-incomplete** critical data => BLOCKED.

Never force-fill. Historical return cannot substitute expected return. Rejected/expired/stale/non-actionable approval packets cannot execute.

## 18. Research/controller
Communication Services remains completed, but its decision layer is under hardened evidence revalidation. Financials stays queued and sector automation stays PAUSED while this work has priority.

## 19. Immediate next action
**Collect Quality-Hardening Evidence + Revalidate Communication Services.**

For PINS/RDDT collect verified:
- >=3-year durable growth / KPI anchors;
- SBC, dilution, buyback and owner-earnings reconciliation;
- value-trap / structural counter-thesis evidence where required;
- conservative valuation robustness evidence.

Then generate new immutable hardening/score/Decision Snapshots and rerank. Only after this should we resume Financials or return to legacy reduction.

## 20. Documentation handshake
Before material work read live `System_Foundation`, this file, `contracts/system-contract.yaml`, `VERSION`, roadmap, architecture and relevant live Supabase/Sheet state. Resolve drift first. After material changes synchronize roadmap/architecture/live foundation.

## 21. Regression discipline
Changes to normalization, valuation, hardening, scoring, Decision Snapshots, ranking, allocation, scenario, rebalancing, approval or dashboard semantics require deterministic regressions. Reference names include ISRG, EOG, BKR, CAVA, TPR, RDDT, PINS and NVDA.

## 22. Source precedence
1. Latest reconciled portfolio data
2. Focused Wealth-Building rules
3. Production policy/hardening state
4. Current primary-source research
5. Wall Street consensus
6. News/social narratives

Use the higher-priority source when conflicts occur; fail closed when material conflicts remain unresolved.
