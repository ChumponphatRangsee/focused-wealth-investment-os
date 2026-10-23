# FWIOS — Value, Entry Timing & Portfolio Rotation Strategy Roadmap

**Planning date:** 2026-10-23 (Asia/Bangkok)  
**Status:** PROPOSED / ANALYSIS AND DOCUMENTATION ONLY / NOT APPROVED FOR PRODUCTION  
**Scope:** Strategy design and future sequencing; **no** implementation, live scheduler activation, automated investment recommendation, trade, portfolio/accounting write, Supabase migration, policy change, or cutover is authorized by this document.  
**Reference:** [Master Roadmap](../00_SYSTEM_ROADMAP.md) · [Current Status](../CURRENT_STATUS.md) · [AGENTS](../../AGENTS.md) · [System Contract](../../contracts/system-contract.yaml)

## 1. Investor objective and decision model

The owner wants to (1) discover businesses trading materially below well-supported intrinsic value, (2) wait for attractive entry conditions, (3) take profits or rebalance as the expected reward/risk and portfolio opportunity set changes, and (4) redeploy capital into more compelling qualified ideas. This is a value-led, risk-aware **position / swing rotation** approach, *not* short-horizon price prediction or guaranteed price-target realization.

The proposed operating loop is:

1. **Universe & shallow discovery:** canonical instrument membership + inexpensive price/fundamental screens.
2. **Research attention:** rank which names are worth deeper work, including existing positions and reactivation candidates.
3. **Selective evidence-backed research:** source material, business model, financial drivers, counter-thesis, risks and catalysts.
4. **Deterministic valuation:** point-in-time assumptions; bear/base/bull + probability-weighted intrinsic values; explicit model availability and uncertainty.
5. **Opportunity & entry review:** valuation discount, existing production hard gates, price/technical context and portfolio fit.
6. **Portfolio decision:** hold/add/defer/trim/exit/rotate *recommendations* with human approval; prioritize new cash/soft rebalance before selling quality winners.
7. **Evaluation & learning:** immutable signal/decision versions; compare later market outcomes and realized portfolio impacts net of costs; improve only after reviewed backtests.

**Key distinction:** intrinsic value is a model-based estimate, not a promised stock price by a fixed date. Proposed trading horizon (e.g., 1–6 months) is a hypothesis for test cohorts, not a production policy. A trade may remain unattractive despite apparent value if the evidence, model, quality or risk gate is blocked.

## 2. Fit with existing, authoritative FWIOS architecture

Do **not** create a competing scanner, ledger, score, thesis store, or AI-controlled investment engine.

| Existing contract / capability | Reuse / boundary |
| --- | --- |
| [Redesign Epic #31](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/31) | Universe → Attention → Selective Research → Thesis Memory → Decision → Portfolio remains the target; existing production reads stay authoritative until explicit parity cutover. |
| [Issue #38](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/38) | Research-attention budgets, promotion/demotion, refresh cadences, resource priority and candidate queue; design it before independent schedule loops. |
| [Issue #39](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/39) | Read cutover, compatibility, retention and cleanup only after proven parity and separate authorization. |
| [ChatGPT Research Workflow v1](CHATGPT_RESEARCH_WORKFLOW_V1.md) and controlled-ingest/readiness plans | Research defaults to PREVIEW; production facts require verified canonical sources, gateway validation and explicit APPLY intent. Research never directly writes scores, valuation, lifecycle, holdings or scanner. |
| Existing valuation/quality/scoring/ranking/approval policies | Reuse production policy versions and immutable outputs, not newly invented weights or fixed buy/sell cutoffs. Production score remains Business/Thesis 30%, Expected Return/Valuation 30%, Portfolio Fit 25%, Downside/Thesis Risk 15%. Timing remains a bounded non-core modifier and cannot overrule failed gates. |
| Shared market observations / quota controls | Prices, FX, sessions and freshness must come from canonical data services; web-researched quotes do not become production market prices. |
| Phase-1 portfolio and scanner boundaries | Investment Portfolio Tracker remains the current transaction/accounting authority; scanner and Focused Wealth Dashboard are portfolio-independent presentations. Portfolio Decision reads reconciled holdings via existing approved interfaces; no second ledger. S&P 500 membership expansion (U1) remains PAUSED pending explicit resumption. |

The repository contract is [FWIOS-CONTRACT-0.87.19](../../contracts/system-contract.yaml) at this documentation review. Do not increment it, modify deterministic thresholds, or assert live deployment from this proposal.

## 3. Research universe, lifecycle and refresh policy (proposed)

Use existing canonical states: UNIVERSE, SCREENED, WATCH, RESEARCH_CANDIDATE, FULL_THESIS, PORTFOLIO, REJECTED, ARCHIVED. **No new competing lifecycle enum.**

- **UNIVERSE:** S&P 500 membership *as verified by the authoritative membership feed when U1 is resumed*; cheap discovery, not comprehensive intrinsic valuation.
- **SCREENED/WATCH:** limited financial/price filters and periodic updates; a watchlist is an attention budget, not an instruction to buy.
- **RESEARCH_CANDIDATE:** promote for high expected decision value and evidence/model feasibility; queue structured research.
- **FULL_THESIS:** reserve for high-conviction prospects with primary evidence, valuation readiness and a current decision question.
- **PORTFOLIO:** prioritize monitoring for reconciled held instruments regardless of whether a broad scanner still ranks them highly.
- **REJECTED/ARCHIVED:** retain append-only decision and reactivation conditions; avoid continual deep refresh.

**Research priority proposal:** decision relevance (holding exposure, potential risk-adjusted opportunity, approaching catalyst, critical stale evidence and material thesis change) relative to expected research/API cost. All factors and caps require an explicitly versioned policy and regression testing under #38. Do not treat a fixed 10–20-stock shortlist or new arbitrary screening weights as active production rules; preserve current maximum five active watchlist candidates and three immediate candidates unless a contract change is approved.

Promotion/demotion should have minimum dwell/cool-down and hysteresis to avoid churn, but exact durations remain TBD; demotion never deletes historical thesis or decision lineage. Missing archetype valuation routes fail closed, not replaced with rough sector multiples as production intrinsic value.

## 4. Data, AI, valuation and source controls

**Evidence layer:** preserve URL, issuer/source tier, filing or release date, financial period, retrieval timestamp, reporting currency/units, instrument identity, verification and contradiction state. Prefer SEC, company filings and investor relations for critical financial facts; mark conflicts and unavailable data rather than guessing.

**AI research layer:** summarize business economics, competitive positioning, thesis and counter-thesis, risks, catalysts and open questions; emit structured PREVIEW payloads to the existing controlled-ingest interface. AI text must not directly manufacture quality scores, fair values, canonical prices or execution orders. A future scheduled research-to-database APPLY path requires **separate owner authorization, service identity, access design, audit and tested gateway controls**; a generic ChatGPT Schedule does not implicitly have production-write permission.

**Valuation layer:** reuse routed, supported archetype models and production valuation snapshots. Record assumptions, sources, model version, input as-of, actual vs forecasts, bear/base/bull and probability-weighted estimates, discount-rate sensitivities, owner-earnings/SBC treatment, confidence and hardening lineage. Valuation and market price are distinct snapshots; a price move alone must not mechanically rewrite intrinsic value.

**Canonical state / derived views:** prefer existing evidence records, metric observations, valuation runs, thesis memory, market observation, decision snapshots and ranking interfaces. Before any migration, inventory field-level gaps; only add versioned schema where genuinely missing. Any new analysis table is proposed, not deployed by this document. Never create a parallel holdings/transactions ledger.

## 5. Entry, hold, exit and rotation decisions (proposed)

The sequence is **eligible valuation and quality → margin-of-safety/risk review → entry-timing context → portfolio opportunity comparison → human decision**.

- **Entry:** classify WAIT / REVIEW ENTRY / READY FOR HUMAN REVIEW (conceptually), using verified mispricing, model uncertainty, price freshness, thesis condition and bounded chase/extension checks. Technical support/RSI/trend confirmation can refine timing but must not override production hard gates or be relabeled as intrinsic value.
- **Sizing:** evaluate current concentration, correlation/factor exposure, downside scenarios, liquidity, cash constraints and risk budget under existing portfolio policies; no forced trade if nothing qualifies.
- **Hold/update:** review thesis and expected return relative to the current price. A change in forecast evidence matters more than unrealized gain/loss on cost basis.
- **Take profit/trim:** consider reducing when market price approaches defensible intrinsic value, thesis deteriorates, portfolio concentration becomes unacceptable, or a materially superior *after-cost, risk-adjusted* candidate appears. Do **not** trim simply because the price rose or a fixed profit percentage was reached.
- **Rotation:** compare HOLD A versus TRIM A → BUY B versus HOLD CASH and add-to-existing-position scenarios; account for taxes, commissions, spreads, liquidity, execution slippage, foreign currency exposure and switching error. Show incremental portfolio effect and what evidence would invalidate the proposed rotation.
- **Execution:** advisory/non-mutating output only; human confirms and executes externally. No auto-buy/sell, no hidden order routing, no write to accounting/holdings.

Any numerical stop, profit-taking, risk-per-trade, margin-of-safety or minimum expected-upside setting must be proposed, tested, reviewed and policy-versioned before becoming operational. Existing contract thresholds remain authoritative.

## 6. Research / revaluation / evaluation cadence (planning hypothesis)

| Trigger | Intended action | Non-negotiable guardrail |
| --- | --- | --- |
| Each completed US trading session | Update canonical market close/freshness; recompute **derived** mispricing and observation alerts | Reuse quota-aware canonical provider path; no full-universe AI deep research or auto-trade |
| Weekly or budget-driven | Review current holdings, watched opportunities and stale / event-impacted research queue | Research-attention allocation from #38; PREVIEW by default |
| Company filing / earnings / guidance / material event | Open a targeted refresh and potential intrinsic revaluation | First verify publication timestamp and Tier-A financial evidence; model/hardening gates apply |
| Monthly (proposed) | Re-rank research attention, monitor churn and concentration, review deferred/reactivation states | No automatic lifecycle cutover; respect scarcity and hysteresis |
| Quarterly or fundamental-change driven | Update financial assumptions and issue an immutable valuation revision | Never copy previous model targets without source and version lineage |
| Evaluation after 1/3/6/12 months (test cohorts) | Check signal calibration, benchmark-relative performance and subsequent drawdown | No look-ahead/survivorship leakage; keep outcomes separate from ex-ante estimates |

**Scheduling implementation decision is deferred.** Potential orchestrators (ChatGPT scheduled research versus backend jobs/queues) require a capability, cost, provenance and write-permission design review. No new Scheduled Task or Supabase Cron is created by this plan.

## 7. Backtest / decision evaluation requirements

Before promoting a strategy to production decision support:

1. Freeze point-in-time investment universe, company actions, source publication/availability time, financial releases, FX and market-price sessions.
2. Replay valuation model/version, evidence, missing-data blocks, research eligibility, attention budget, entry signal, decision time and execution assumptions.
3. Compare against relevant investable benchmarks (e.g., S&P 500 total return in a matched base currency), passive holds and no-rotation baseline.
4. Report net return, annualized return where meaningful, maximum drawdown, downside capture, volatility, risk-adjusted metrics, turnover, fees/tax/slippage sensitivity and signal coverage.
5. Evaluate calibration of bear/base/bull valuation ranges **separately** from directional/timing performance; do not treat an unrealized future fair value as a realized price target.
6. Use walk-forward/out-of-sample windows, regime changes, sector stratification and parameter stability checks. Record rejected runs as well as winning tests.
7. Shadow/paper-trade with immutable decision logs and compare suggested vs actually executable entry/rotation results before any broader rollout.

Do not optimize thresholds solely on one cohort, and do not claim a profitable strategy without sufficient evidence.

## 8. Delivery plan / dependencies — NO IMPLEMENTATION AUTHORIZED

| Track | Proposed deliverable | Dependencies | Acceptance before next track |
| --- | --- | --- | --- |
| **D0 — Document and gap audit (now)** | Reconcile current roadmap/contract, catalog existing decision/valuation/scheduling features and define unresolved product questions | Current GitHub docs and live-state verification for any production work | Documentation-only PR reviewed; no runtime changes |
| **D1 — Research attention and policy design** | Finish Issue #38 design: triage, workload queue, promotion/demotion, cost-aware refresh and existing lifecycle interface | #31/#32–#37 and current production parity | Versioned spec with failed-data handling and traceable research priorities |
| **D2 — Institutional research & valuation quality** | Research source/ingest, factor/quality/risk and model/uncertainty gap audit; selectively support high-priority archetypes | Controlled-ingest/readiness contracts; D1; existing valuation models | Immutable source-backed valuation samples and gate parity |
| **D3 — Entry timing & opportunity compare** | Technical-context proposal, reason codes, non-core timing separation, side-by-side candidate evaluation | D2 and canonical market observations | No bypass of hard gates; deterministic replay |
| **D4 — Portfolio rotation decision support** | Hold/add/trim/exit/rotate/cash scenario comparisons; costs, exposure and human confirmation | D3, reconciled read-only portfolio state, existing scenario/rebalance policies | Advisory-only; no accounting writes; reproducible opportunity-cost comparison |
| **D5 — Evaluation & shadow research cadence** | Point-in-time backtests, walk-forward/paper evaluation, schedule/orchestration and ingestion-permission design | D1–D4, quota/access review; #39 only when parity and owner approval permit | No look-ahead, clear benchmark, reliable evidence and no unauthorized writes |
| **D6 — Separate production proposal (later)** | Policy versions, releases, migration/cutover checklist and rollback if results justify | D5 acceptance, explicit owner sign-off | New, separately scoped implementation PR(s), live validation and human execution guardrails |

This is an **overlay** on the ongoing Redesign #31/Issue #38/#39 and Phase-1 functionality, not a declaration that any numbered track is deployed. Do not reorder or close existing GitHub Issues solely because this plan was drafted.

## 9. Decisions remaining open

- Target holding period and turnover limit: medium-term value realization versus shorter position swings.
- Investment universe: current supported set versus later explicit U1 S&P 500 expansion.
- Whether research cadence should prioritize event deltas, time-based refresh or a hybrid, and whether ChatGPT Tasks remain a manual research channel rather than system writer.
- Authorized market/fundamental provider plan and precise API quota budget.
- Approved archetype coverage and how model uncertainty controls the required discount.
- Cost/tax treatment, benchmark base currency and acceptable drawdown.
- Definition of a qualified rotation versus retaining a concentrated high-quality winner.

**Owner decision required before implementation:** review this strategy overlay, decide priorities and authorize a specifically scoped next feature. Until then, research and trading remain governed by existing production contracts.
