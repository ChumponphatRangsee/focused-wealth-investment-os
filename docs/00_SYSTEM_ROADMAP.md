# Focused Wealth Investment OS — Master System Roadmap

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract: **FWIOS-CONTRACT-0.87.2**  
Last updated: **2026-09-05 Asia/Bangkok**  
Execution mode: **HUMAN EXECUTION ONLY**

## Purpose

This file is the persistent project-status index for AI agents and automations working on the Focused Wealth Investment OS. It tracks what is complete, what is being built next, what remains blocked, and which tasks are Main Roadmap versus Side Quest.

This roadmap is not allowed to override live state. Live portfolio state, `System_Foundation`, `Sector_Run_Control`, and authoritative Supabase state win when conflicts exist.

## Authority / precedence for operational state

1. Latest portfolio holdings / transactions when an investment decision is involved.
2. `System_Foundation` and `Sector_Run_Control` in the live screener.
3. Supabase `fwios` controller, portfolio, evidence, metric, valuation and decision state for layers where Supabase is authoritative.
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
| Sector automation | PAUSED — manual control while M2 promotion hardening finishes |
| Current run ID | none |
| Supabase authority | RESEARCH + VALUATION + PORTFOLIO STATE + MARKET PRICE/MISPRICING + PORTFOLIO FIT + SCORING CORE |
| Portfolio execution | Human only; no auto-buy / auto-sell |

M2.1–M2.4 core layers are live. Portfolio migration reconciled **29/29 transactions** and **16/16 positions** into private Supabase state. The latest reconciled portfolio snapshot is approximately **THB 340,906.10**. Current guardrail reviews include NVDA at approximately **41.25%**, crypto at approximately **38.09%**, and **10** unique open assets versus the preferred 5–8 meaningful positions. These are review flags, not automatic sell instructions.

### Portfolio migration / authority

`Investment Portfolio Tracker - Chumponphat` was the designated migration source for M2/M3. Supabase now holds the reconciled portfolio ledger/state used by Portfolio Fit and downstream decision logic. The Sheet remains retained as reconciliation / audit / export / archive compatibility until downstream M3 rebalancing traceability tests pass.

Target authority:

- **Supabase** = portfolio ledger/state source of truth used by Portfolio Fit, Opportunity, Capital Allocation and Rebalancing engines.
- **GitHub** = schema, migration, contract, regression and decision-engine implementation authority.
- **Investment Portfolio Tracker - Chumponphat** = retained reconciliation / audit / export / archive layer until final cutover criteria pass.

---

# MAIN ROADMAP

## M1 — Research Pipeline v2

**Status: CORE HARDENING PASS / PERFORMANCE VALIDATION OPEN**

- [x] Research Run Telemetry.
- [x] Fast Discovery up to 20 → approximately 8 candidates.
- [x] Light Research approximately 8 → maximum 5 candidates.
- [x] Deep Research strongest approximately 3 first.
- [x] Evidence cache / delta refresh with exact provenance, read-time age, legacy date parsing and later-material-event invalidation.
- [x] Deterministic Source Router.
- [x] Model-debt decoupling at the controller boundary.
- [x] Fail-closed regression / acceptance checks.
- [ ] Parallel top-candidate execution/performance validation where dependency ordering permits it.

Communication Services completed the recorded 20→8→5→3 funnel in 863.729 seconds. RPV2.1 cache/controller correctness passes; parallel-worker speedup remains optimization work and does not block M2.

## M2 — Decision Intelligence

**Status: CORE LIVE / PROMOTION-GATE HARDENING OPEN**

Goal: answer whether a company is attractive at the current price and suitable for the reconciled live portfolio, while keeping missing decision evidence fail-closed.

- [x] Native Market Price layer with quote timestamp/session freshness handling.
- [x] Mispricing engine: current price vs Bear/Base/Bull/PW fair value, upside/downside and margin-of-safety classification.
- [x] Portfolio State migration from `Investment Portfolio Tracker - Chumponphat` into private Supabase with transaction and position reconciliation.
- [x] Portfolio Fit Engine using reconciled live portfolio weights/exposures rather than generic diversification bonuses.
- [x] Native Supabase 30/30/25/15 scoring core: Business/Thesis 30%, Expected Return/Valuation 30%, Portfolio Fit 25%, Downside Risk 15%.
- [ ] Version and regression-test the `Revision_Data_v2` raw-evidence → component-score rubric.
- [ ] Version and regression-test the Chase raw-data → component-score rubric.
- [ ] Complete final fail-closed promotion parity for stale price, stale earnings, missing portfolio context, incomplete valuation, incomplete Revision and incomplete Chase data.

### Current M2 candidate state

| Candidate | Price snapshot | Business | Expected Return | Portfolio Fit | Downside | Core Score | Current decision |
|---|---:|---:|---:|---:|---:|---:|---|
| PINS | $20.28 (2026-09-04 close) | 82 | 100 | 90 | 70 | 87.60 | RESEARCH PRIORITY — MISPRICING; Promotion blocked |
| RDDT | $154.79 (2026-09-04 close) | 88 | 45 | 90 | 65 | 72.15 | GOOD COMPANY — WAIT FOR VALUE |

PINS intrinsic value remains Bear $25.3199 / Base $40.6020 / Bull $69.4854 / PW $44.0023. Its current mispricing gate passes strongly. RDDT intrinsic value remains Bear $92.3017 / Base $142.5985 / Bull $237.7178 / PW $153.8041; at $154.79 it does not clear the required margin of safety.

Comparable consensus evidence has now been recovered for both candidates using same-provider, same-metric, same-fiscal-period snapshots:

- PINS FY2026 EPS consensus: **$1.92 pre-earnings → $2.05 post/current**, revision **+6.7708%**.
- RDDT FY2026 EPS consensus: **$4.85 pre-earnings → $5.27 post/current**, revision **+8.6598%**.

The consensus evidence gate therefore passes. However, the production configuration defines Revision component weights and Chase component weights but does **not** yet define a versioned mapping from raw evidence/data into 0–100 component scores. The system must not invent those scores. Therefore Revision remains `BLOCKED - COMPONENT SCORING INCOMPLETE`, Chase remains fail-closed, and no candidate may bypass Promotion Gate.

### M2 exit criteria

M2 exits only when the system can state, with traceable inputs: **good business + current valuation + expected return + portfolio fit + downside risk + versioned Promotion evidence**, with stale/missing inputs deterministically blocked.

## M3 — Opportunity & Capital Allocation

**Status: PENDING M2 PROMOTION HARDENING**

Goal: rank where the next unit of capital should go and simulate portfolio changes without auto-trading.

- [ ] Supabase parity / cutover for `Opportunity_Engine_v2`.
- [ ] Global candidate ranking with maximum 5 active watchlist candidates and maximum 3 immediate buy candidates.
- [ ] New-cash deployment logic.
- [ ] Soft-rebalancing sequence: new cash → reduce DCA → reassess thesis/valuation → allow weights to normalize → hard trim only when justified.
- [ ] Rebalancing signal engine with trim/add amounts and before/after portfolio exposure.
- [ ] Trim/Add simulation with estimated change in portfolio expected return and concentration risk.
- [ ] Scenario outputs for **No-Sell / Soft Rebalance / Active Rebalance**.
- [ ] Explicit concentration review for exceptional single-stock weights above approximately 30%.
- [ ] Explicit Phase-1 crypto exposure review around approximately 15–20% target.

### M3 exit criteria

The system can answer: **“If new capital is available today, where should it go; if new cash is insufficient, should anything be reduced, by how much, where should those proceeds move, and what changes in expected portfolio outcome?”** Human approval/execution remains mandatory.

M3 cutover requires traceability back to reconciled Supabase source transactions without unexplained quantity, cost-basis, realized-P&L or allocation differences.

## M4 — Autonomous Investment OS

**Status: PENDING M3**

- [ ] Scheduled sector discovery under run-lock/controller rules.
- [ ] Evidence freshness / delta-refresh scheduler.
- [ ] Thesis-monitor refresh and material-change alerts.
- [ ] Opportunity ranking refresh on material price/earnings/thesis/portfolio changes.
- [ ] Portfolio concentration / allocation alerts.
- [ ] Recovery logic for failed/blocked runs using the central blocker orchestrator.
- [ ] End-to-end audit trail from source evidence to final human-review recommendation.

---

# VALUATION MODEL COVERAGE / SIDE QUESTS

## Digital Advertising — PASS

`DIGITAL_ADS_FCF_REVERSE_DCF_V1` v1.0 is implemented on the reusable `FCF_COMPOUNDER` kernel with normalization `NORM_V1-DIGADS`.

RDDT and PINS each have 9/9 required normalized inputs PASS and independent valuation regressions pass at absolute tolerance 0.01.

| Ticker | Bear FV | Base FV | Bull FV | Probability-weighted FV | M2 state |
|---|---:|---:|---:|---:|---|
| RDDT | 92.3017 | 142.5985 | 237.7178 | 153.8041 | GOOD COMPANY — WAIT FOR VALUE |
| PINS | 25.3199 | 40.6020 | 69.4854 | 44.0023 | MISPRICING PASS; Promotion blocked on Revision/Chase scoring |

## Remaining open model debt

The live controller remains `DISCOVERY`; these stay fail-closed coverage tasks rather than blockers to M2 completion.

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
- [ ] Supplemental money-flow, news-sentiment and Wall Street comparison layers; these may inform but not override core evidence/valuation/portfolio-fit gates.
- [ ] Additional archetype-specific valuation models when live candidates justify the work.

---

# CURRENT EXECUTION QUEUE

## Immediate next action

**Finish M2 Promotion-Gate Hardening.**

1. Preserve the completed Communication Services run; do not repeat it.
2. Keep Financials queued and eligible under `DISCOVERY`, but do not auto-start it while M2 is the active Main Roadmap priority.
3. Version the `Revision_Data_v2` component-score rubric for Guidance 30% / Consensus 25% / KPI Acceleration 25% / Margin-FCF 20%.
4. Version the Chase component-score rubric for Price Extension 25% / Price vs Revision 30% / Multiple Expansion 25% / Price vs FV 20%, with Chase Risk Max 60.
5. Use already traceable consensus/earnings/valuation/price evidence plus explicitly defined Chase raw inputs; do not invent missing scores.
6. Recompute PINS/RDDT immutable Revision/Chase/decision snapshots and run fail-closed regressions.
7. If M2 Promotion parity passes, advance to M3 Opportunity & Capital Allocation; otherwise keep the affected candidate blocked and record the exact unresolved dependency.

The six remaining model-debt items remain fail-closed and can be resolved opportunistically or when the controller/bottleneck promotes them again.

---

# AI ROADMAP UPDATE CONTRACT

Every AI agent or automation performing a material system change must:

### Before work

1. Read `AGENTS.md`.
2. Read `contracts/system-contract.yaml`.
3. Read `VERSION`.
4. Read this file.
5. Read live `System_Foundation` and relevant controller state.
6. Resolve documentation drift before changing production logic.

### After work

Update this roadmap when milestone status, capability, blockers, authority/cutover state, next action, sector-run state, or contract/foundation compatibility materially changes.

### Drift rule

Live state wins. If a conflict cannot be resolved safely, use `BLOCKED - DOCUMENTATION DRIFT` rather than guessing.

---

# Change Log

## 2026-09-05 — M2.1–M2.4 core live / consensus evidence recovered

- Reconciled 29/29 portfolio transactions and 16/16 positions into private Supabase portfolio state; snapshot approximately THB 340,906.10.
- Activated native Market Price / Mispricing, reconciled Portfolio Fit, and native 30/30/25/15 core scoring.
- PINS core score = 87.60 and Mispricing Gate PASS; RDDT core score = 72.15 and remains GOOD COMPANY — WAIT FOR VALUE.
- Added traceable same-provider FY2026 EPS consensus snapshots: PINS +6.7708% and RDDT +8.6598%; consensus evidence gate now passes.
- Preserved fail-closed behavior: Revision remains blocked until a versioned component-score rubric exists; Chase remains blocked until its raw-data definitions and score mapping are versioned and populated.
- Synchronized `Revision_Data_v2` and `System_Foundation` to reflect M2.1–M2.4 core-live state and the narrowed Promotion blocker.
- No trades were executed.

## 2026-09-05 — M1 core hardening PASS / Digital Ads model PASS

- Upgraded research pipeline controller/cache semantics to RPV2.1.
- Added exact provenance validation, read-time freshness aging, legacy Sheet date parsing and later-material-event invalidation.
- Corrected `MODEL_FACTORY_AFTER_CURRENT_SECTOR` completion boundary and added behavioral negative regressions.
- Implemented `DIGITAL_ADS_FCF_REVERSE_DCF_V1` v1.0 for RDDT/PINS on `FCF_COMPOUNDER`; 9/9 normalized metrics and regressions PASS.
- Decision coverage improved from 61.1% to 72.2%; open root model debt fell from seven to six.
- Advanced Main Roadmap priority to M2. Financials remains queued, not automatically started.

## 2026-09-05 — Portfolio tracker migration dependency recorded

- Designated `Investment Portfolio Tracker - Chumponphat` as the portfolio-side migration source for M2/M3.
- Added Supabase Portfolio State migration before Portfolio Fit / Rebalancing cutover.
- Added M3 No-Sell / Soft Rebalance / Active Rebalance scenario requirement with trim/add and expected-upside comparison.
- Added retirement guard for the portfolio tracker until reconciliation/cutover criteria pass.

## 2026-09-05 — Recover Communication Services closeout

- Reconciled completed Supabase research with the previously RUNNING Sheets controller.
- Restored the 20-name universe, run history and Communication Services blockers.
- Added read-only closeout checker and failure-case tests.

## 2026-09-05 — Master roadmap introduced

- Created persistent Main Roadmap / Side Quest tracker.
- Added mandatory roadmap read/update governance.
