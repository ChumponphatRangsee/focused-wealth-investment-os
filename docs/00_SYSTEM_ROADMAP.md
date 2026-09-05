# Focused Wealth Investment OS — Master System Roadmap

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract: **FWIOS-CONTRACT-0.87.2**  
Last updated: **2026-09-05 Asia/Bangkok**  
Execution mode: **HUMAN EXECUTION ONLY**

## Purpose

This file is the persistent project-status index for AI agents and automations working on the Focused Wealth Investment OS. It tracks what is complete, what is being built next, what remains blocked, and which tasks are Main Roadmap versus Side Quest.

This roadmap is **not allowed to override live state**. Before acting, always re-read the live sources named below. If this file conflicts with live state, live state wins and this file must be corrected in the same workstream.

## Authority / precedence for operational state

1. Latest portfolio holdings / transactions when an investment decision is involved.
2. `System_Foundation` and `Sector_Run_Control` in the live screener.
3. Supabase `fwios` controller, blocker, evidence, metric and valuation state for layers where Supabase is authoritative.
4. `contracts/system-contract.yaml`, `AGENTS.md` and `VERSION` for execution rules and compatibility.
5. This roadmap as the persistent project-status summary.
6. Migration / implementation notes under `docs/`.

## Current system state

| Item | Current state |
|---|---|
| Foundation | 0.87 |
| Contract | FWIOS-CONTRACT-0.87.2 |
| Research pipeline | RPV2.1 |
| Operating mode | DISCOVERY |
| Evidence-ready candidates | 18 |
| Valuation-ready candidates | 13 |
| Decision coverage | 72.2% |
| Open root model blockers | 6 |
| Current sector | Communication Services |
| Current sector stage | DONE — research closeout |
| Next queued sector | Financials |
| Run lock | IDLE |
| Sector automation | PAUSED — manual control while Main Roadmap advances to M2 |
| Current run ID | none |
| Supabase authority | RESEARCH + VALUATION COMPUTE CONTROL PLANE |
| Portfolio execution | Human only; no auto-buy / auto-sell |

Current valuation/model infrastructure includes reusable private kernels for `FCF_COMPOUNDER`, `MIDCYCLE_CASHFLOW` and `ASSET_NAV`. Digital Advertising is now implemented on `FCF_COMPOUNDER`. Current-price/mispricing integration, portfolio-state cutover, final scoring and opportunity/capital-allocation authority remain incomplete.

### Designated portfolio migration source

`Investment Portfolio Tracker - Chumponphat` is the designated live/legacy migration source for portfolio-state data required by M2/M3. It must **not** be retired, deleted, or treated as disposable legacy output until Supabase portfolio-state parity, transaction reconciliation and downstream rebalancing tests pass.

Migration scope includes at minimum: accounts, transactions, asset / asset class, quantity, price, fees, currency / FX, net quantity, THB cash flow, cost-basis changes, realized P&L, running quantity, running cost basis, average cost, holdings/allocation state, thesis/action context and data-quality lineage where available.

Target authority after cutover:

- **Supabase** = portfolio ledger/state source of truth used by Portfolio Fit, Opportunity, Capital Allocation and Rebalancing engines.
- **GitHub** = schema, migration, contract, regression and decision-engine implementation authority.
- **Investment Portfolio Tracker - Chumponphat** = read-only reconciliation / audit / export / archive layer unless a later roadmap explicitly keeps a live compatibility use case.

---

# MAIN ROADMAP

Main Roadmap work directly advances the system toward a complete research → valuation → portfolio-fit → capital-allocation decision loop. Main Roadmap work takes precedence over Side Quests unless a Side Quest becomes a hard blocker for the active main milestone.

## M1 — Research Pipeline v2

**Status: CORE HARDENING PASS / PERFORMANCE VALIDATION OPEN**

Goal: reduce full-sector discovery/research latency without weakening evidence lineage, source quality or fail-closed behavior.

- [x] Research Run Telemetry: persist stage `started_at`, `completed_at`, `duration_seconds`, candidates in/out, sources checked, evidence created/reused, cache-hit rate and failure reason.
- [x] Fast Discovery stage: universe up to 20 → approximately 8 candidates using only high-signal screening data.
- [x] Light Research stage: approximately 8 → maximum 5 candidates using Business Quality, Growth, rough Valuation, Downside and Portfolio Fit.
- [x] Deep Research stage: production-grade evidence collection for the strongest approximately 3 candidates first; expand to candidates 4–5 only when justified.
- [x] Evidence cache / delta refresh core: exact registry provenance, read-time age recomputation, legacy Sheet date parsing and later-material-event invalidation are live in RPV2.1.
- [x] Deterministic Source Router: route filings, guidance, balance-sheet facts, technical reports, market quotes and material news to defined source classes.
- [x] Model-debt decoupling: affected candidates remain fail-closed while sector completion/new-sector permission follows the Operating Controller boundary.
- [ ] Parallel top-candidate execution/performance validation where source/dependency ordering permits it.
- [x] Regression/acceptance checks proving cache aging, later-event invalidation, provenance failure and date parsing fail closed correctly.

Communication Services completed the recorded 20→8→5→3 funnel in 863.729 seconds (14.4 minutes). RPV2.1 then repaired the two closeout defects found by review:

- `v_latest_reusable_evidence` now recomputes current-evidence age, validates exact Source Registry provenance, parses ISO and supported legacy Sheet serial dates, and invalidates older current reporting evidence after a later material reporting event.
- `v_research_pipeline_controller` now permits current-sector completion in `MODEL_FACTORY_AFTER_CURRENT_SECTOR` while keeping new-sector discovery blocked until the controller returns `DISCOVERY`.

Behavioral regressions `REG-M1-CACHE-EVENT-20260905`, `REG-M1-CACHE-AGE-20260905`, `REG-M1-CACHE-PROV-20260905` and `REG-M1-DATE-PARSE-20260905` all PASS. Current reusable-evidence count is 221. RDDT/PINS/NFLX current Tier-A sets are eligible under the hardened cache rules.

Parallel-worker speedup is still an optimization/measurement item; it no longer blocks progression to M2 because correctness and fail-closed M1 hardening criteria now pass.

### M1 exit criteria

- [x] Stage timings are measured rather than estimated.
- [x] Sector discovery can finish even when a candidate creates Model Debt when the live controller permits it.
- [x] Fresh evidence is reused deterministically and fails closed on provenance/age/event invalidation.
- [x] No production candidate is promoted without evidence / valuation / current-price / portfolio-fit gates.
- [x] Communication Services data is compatible with the hardened RPV2.1 cache/controller behavior without breaking the recorded run closeout.

## M2 — Decision Intelligence

**Status: NEXT / ACTIVE PRIORITY**

Goal: answer not only whether a company is good, but whether it is attractive at the current price and suitable for the live portfolio.

- [ ] Native Market Price layer with quote timestamp, session status and freshness gate.
- [ ] Mispricing engine: current price vs Bear/Base/Bull/PW fair value, upside/downside and margin-of-safety classification.
- [ ] **Portfolio State migration from `Investment Portfolio Tracker - Chumponphat` into Supabase**, with reconciled accounts, transactions, positions, cost basis, realized/unrealized state, allocation and exposure inputs. The Sheet remains authoritative/retained until parity and reconciliation pass.
- [ ] Portfolio Fit Engine: live position weight, sector/theme dependency, concentration, crypto exposure, thesis overlap and opportunity-cost context.
- [ ] Supabase parity for `Data_Scoring_v2` using the production weights: Business/Thesis 30%, Expected Return/Valuation 30%, Portfolio Fit 25%, Downside Risk 15%.
- [ ] Fail-closed parity tests for stale price, stale earnings, missing portfolio context and incomplete valuation.

### M2 exit criteria

The system can state, with traceable inputs: **good business + current valuation + expected return + portfolio fit + downside risk**, using reconciled live portfolio state rather than a manually copied snapshot.

## M3 — Opportunity & Capital Allocation

**Status: PENDING M2**

Goal: rank where the next unit of capital should go and simulate portfolio changes without auto-trading.

- [ ] Supabase parity / cutover for `Opportunity_Engine_v2`.
- [ ] Global candidate ranking with maximum 5 active watchlist candidates and maximum 3 immediate buy candidates.
- [ ] New-cash deployment logic.
- [ ] Soft-rebalancing sequence: new cash → reduce DCA → reassess thesis/valuation → allow weights to normalize → hard trim only when justified.
- [ ] Rebalancing signal engine with trim/add amounts and before/after portfolio exposure, using the migrated `Investment Portfolio Tracker - Chumponphat` portfolio ledger/state as the portfolio-side input.
- [ ] Trim/Add simulation with estimated change in portfolio expected return and concentration risk.
- [ ] Scenario outputs for **No-Sell / Soft Rebalance / Active Rebalance**, including recommended trim amount, destination asset(s), before/after position weights, concentration/theme effects and expected portfolio-upside change.
- [ ] Explicit concentration review for exceptional single-stock weights above approximately 30%.
- [ ] Explicit Phase-1 crypto exposure review around the approximately 15–20% target.

### M3 exit criteria

The system can answer: **“If new capital is available today, where should it go; if new cash is insufficient, should anything be reduced, by how much, where should those proceeds move, and what changes in expected portfolio outcome?”** Human approval/execution remains mandatory.

The M3 cutover is not complete until recommendations are generated from the reconciled Supabase portfolio ledger and can be traced back to source transactions from `Investment Portfolio Tracker - Chumponphat` without unexplained quantity, cost-basis, realized-P&L or allocation differences.

## M4 — Autonomous Investment OS

**Status: PENDING M3**

Goal: automate monitoring and research refresh while keeping final portfolio execution human-controlled.

- [ ] Scheduled sector discovery under run-lock/controller rules.
- [ ] Evidence freshness / delta-refresh scheduler.
- [ ] Thesis-monitor refresh and material-change alerts.
- [ ] Opportunity ranking refresh when price, earnings, thesis or portfolio state changes materially.
- [ ] Portfolio concentration / allocation alerts.
- [ ] Recovery logic for failed/blocked runs using the central blocker orchestrator.
- [ ] End-to-end audit trail from source evidence to final human-review recommendation.

---

# VALUATION MODEL COVERAGE / SIDE QUESTS

## Digital Advertising — PASS

`DIGITAL_ADS_FCF_REVERSE_DCF_V1` v1.0 is implemented on the reusable `FCF_COMPOUNDER` kernel with normalization `NORM_V1-DIGADS`.

RDDT and PINS each have 9/9 required normalized inputs PASS. The model blends current monetization/ad growth with engagement growth and caps long-duration extrapolation; GAAP operating margin, capex intensity, positive FCF and SBC/revenue are sanity gates. Independent regressions pass at absolute tolerance 0.01.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV |
|---|---:|---:|---:|---:|
| RDDT | 92.3017 | 142.5985 | 237.7178 | 153.8041 |
| PINS | 25.3199 | 40.6020 | 69.4854 | 44.0023 |

These are intrinsic-value outputs only. Both candidates remain `WAIT - PRICE/MISPRICING PENDING`; no Buy/Ready promotion is allowed until M2 provides a fresh price/mispricing layer.

## Remaining open model debt

The live controller is now `DISCOVERY`, so these are fail-closed coverage tasks rather than blockers to the next Main Roadmap milestone. Priority values are model-resolution values, not investment scores.

| Rank | Blocker | Scope | Resolution value |
|---|---|---|---:|
| 1 | BLK-IT-SEMI-MDL-001 | QCOM semiconductor designer | 73.80 |
| 2 | BLK-COMM-STREAM-DEF-001 | Streaming / Media | 73.70 |
| 3 | BLK-MAT-PACK-DEF-001 | BALL packaging | 73.45 |
| 4 | BLK-IT-SEMICAP-MDL-001 | AMAT semiconductor equipment | 72.00 |
| 5 | BLK-MP-MAGNETICS-NAV-001 | MP full-company NAV bridge | 71.55 |
| 6 | BLK-COMM-TELCO-DEF-001 | Telecom | 12.00 |

## Other side quests

- [ ] Parallel top-candidate performance validation / speed measurement.
- [ ] Dashboard/UI polish after decision logic stabilizes.
- [ ] Further Google Sheet tab simplification when it does not disrupt live controls.
- [ ] Advanced thesis-monitor enhancements.
- [ ] Specialist crisis/regime trackers such as AI-bubble monitoring.
- [ ] XRP-specific thesis/dashboard enhancements.
- [ ] Supplemental money-flow, news-sentiment and Wall Street comparison layers; these may inform decisions but may not override core evidence/valuation/portfolio-fit gates.
- [ ] Additional archetype-specific valuation models when live candidates justify the work.

---

# CURRENT EXECUTION QUEUE

## Immediate next action

**Begin M2 Decision Intelligence.**

1. Preserve the completed Communication Services run; do not repeat it.
2. Keep Financials queued and eligible under the live `DISCOVERY` controller, but do not auto-start it while the Main Roadmap is advancing to M2.
3. Migrate Portfolio State from `Investment Portfolio Tracker - Chumponphat` into private Supabase tables with transaction/position/cost-basis/allocation reconciliation and fail-closed parity checks.
4. Implement the native Market Price freshness layer and Mispricing engine.
5. Build Portfolio Fit from reconciled live portfolio weights/exposures.
6. Cut over `Data_Scoring_v2` to Supabase parity with 30/30/25/15 weights.
7. Re-read portfolio/controller state before any investment recommendation or new sector execution.

The six remaining model-debt items stay fail-closed and can be resolved opportunistically or when the controller/bottleneck promotes them again. M3 Rebalancing depends on M2 portfolio-state, price, mispricing and portfolio-fit outputs.

---

# AI ROADMAP UPDATE CONTRACT

Every AI agent or automation performing a **material system change** must:

### Before work

1. Read `AGENTS.md`.
2. Read `contracts/system-contract.yaml`.
3. Read `VERSION`.
4. Read this file, `docs/00_SYSTEM_ROADMAP.md`.
5. Read the live `System_Foundation` and relevant run/controller state.
6. Confirm compatibility and resolve any drift before changing production logic.

### After work

Update this roadmap in the same workstream when the change materially affects any of the following:

- milestone or task status;
- current system capability;
- current bottleneck / blocker;
- authority or cutover state;
- current execution queue / next action;
- sector-run state where it changes the project’s next action;
- contract/foundation compatibility;
- completed implementation that changes what the next AI should do.

Do **not** update this file for trivial wording changes or routine evidence refreshes that do not change project status.

### Drift rule

If live state conflicts with this roadmap:

- live state wins;
- do not silently keep the stale roadmap value;
- correct the roadmap during the same material workstream;
- if the conflict cannot be resolved safely, mark the affected action `BLOCKED - DOCUMENTATION DRIFT` rather than guessing.

---

# Change Log

## 2026-09-05 — M1 core hardening PASS / Digital Ads model PASS

- Upgraded research pipeline controller/cache semantics to RPV2.1.
- Added exact provenance validation, read-time freshness aging, legacy Sheet date parsing and later-material-event invalidation.
- Corrected the `MODEL_FACTORY_AFTER_CURRENT_SECTOR` completion boundary and added behavioral negative regressions.
- Removed five legacy `#VALUE!` errors in `Sector_Universe` without inventing missing scores; incomplete numeric inputs now remain blank/fail-closed.
- Implemented `DIGITAL_ADS_FCF_REVERSE_DCF_V1` v1.0 for RDDT/PINS on `FCF_COMPOUNDER`; 9/9 normalized metrics and independent regressions PASS.
- Closed `BLK-COMM-DADS-MDL-001` while preserving current-price/mispricing as a downstream M2 gate.
- Decision coverage improved from 61.1% (11/18) to 72.2% (13/18); controller returned to `DISCOVERY`; open root model debt fell from seven to six.
- Advanced Main Roadmap priority to M2 Decision Intelligence. Financials remains queued, not automatically started.

## 2026-09-05 — Portfolio tracker migration dependency recorded

- Designated `Investment Portfolio Tracker - Chumponphat` as the portfolio-side migration source for M2/M3.
- Added Supabase Portfolio State migration before Portfolio Fit / Rebalancing cutover.
- Added M3 No-Sell / Soft Rebalance / Active Rebalance scenario requirement with trim/add and expected-upside comparison.
- Added a retirement guard: do not delete/retire the portfolio tracker until transaction/position/cost-basis/allocation reconciliation passes.
- Target post-cutover role for the Sheet is read-only reconciliation / audit / export / archive.

## 2026-09-05 — Recover Communication Services closeout

- Reconciled completed Supabase research with the previously RUNNING Sheets controller.
- Restored the 20-name universe, run history and three Communication Services blockers.
- Corrected coverage to 61.1%, root blockers to seven and next action to controller-required model work.
- Added a read-only closeout checker and failure-case tests.
- Kept M1 hardening, M2, M3 and M4 open; no claim of whole-project completion.

## 2026-09-05 — Master roadmap introduced

- Created a persistent Main Roadmap / Side Quest tracker.
- Made Research Pipeline v2 the immediate main priority before Communication Services.
- Recorded live 73.3% decision coverage and DISCOVERY operating mode.
- Recorded four current root model-debt side quests.
- Added mandatory AI roadmap read/update governance.
