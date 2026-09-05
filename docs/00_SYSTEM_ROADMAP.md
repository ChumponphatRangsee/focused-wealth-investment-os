# Focused Wealth Investment OS — Master System Roadmap

Status: **ACTIVE**  
Live foundation: **0.87**  
Execution contract: **FWIOS-CONTRACT-0.87.1**  
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
| Contract | FWIOS-CONTRACT-0.87.1 |
| Operating mode | MODEL_FACTORY_AFTER_CURRENT_SECTOR |
| Evidence-ready candidates | 18 |
| Valuation-ready candidates | 11 |
| Decision coverage | 61.1% |
| Open root model blockers | 7 |
| Current sector | Communication Services |
| Current sector stage | DONE — research closeout |
| Run lock | IDLE |
| Sector automation | PAUSED — controller-required model work |
| Current run ID | none |
| Supabase authority | RESEARCH + VALUATION COMPUTE CONTROL PLANE |
| Portfolio execution | Human only; no auto-buy / auto-sell |

Current valuation/model infrastructure includes reusable private kernels for `FCF_COMPOUNDER`, `MIDCYCLE_CASHFLOW` and `ASSET_NAV`. Price/mispricing integration, final scoring cutover and final opportunity/capital-allocation authority are not yet complete.

---

# MAIN ROADMAP

Main Roadmap work directly advances the system toward a complete research → valuation → portfolio-fit → capital-allocation decision loop. Main Roadmap work takes precedence over Side Quests unless a Side Quest becomes a hard blocker for the current main milestone.

## M1 — Research Pipeline v2

**Status: RESEARCH RUN COMPLETE / HARDENING OPEN**

Goal: reduce full-sector discovery/research latency without weakening evidence lineage, source quality or fail-closed behavior.

- [x] Research Run Telemetry: persist stage `started_at`, `completed_at`, `duration_seconds`, candidates in/out, sources checked, evidence created/reused, cache-hit rate and failure reason.
- [x] Fast Discovery stage: universe up to 20 → approximately 8 candidates using only high-signal screening data.
- [x] Light Research stage: approximately 8 → maximum 5 candidates using Business Quality, Growth, rough Valuation, Downside and Portfolio Fit.
- [x] Deep Research stage: production-grade evidence collection for the strongest approximately 3 candidates first; expand to candidates 4–5 only when justified.
- [ ] Evidence cache / delta refresh: reuse fresh verified evidence and refresh only stale, missing, conflicting or materially changed inputs.
- [x] Deterministic Source Router: route filings, guidance, balance-sheet facts, technical reports, market quotes and material news to defined source classes.
- [ ] Model-debt decoupling: a missing valuation model must create/update persistent Model Debt and mark valuation pending, but must not stop the rest of sector discovery while the Operating Controller remains `DISCOVERY`.
- [ ] Parallel top-candidate research where source/dependency ordering permits it.
- [ ] Add regression/acceptance checks proving the staged funnel does not bypass Tier A/B evidence requirements or fail-closed gates.

Target after instrumentation: **approximately 12–20 minutes per normal full-sector discovery/research run when reusable models exist**. This is a target, not a guaranteed SLA; telemetry must replace estimates once enough runs are measured.

### Closeout findings — 2026-09-05

Communication Services completed the recorded 20→8→5→3 funnel in 863.729 seconds. Six stored pipeline checks and eleven stored model regressions report PASS. This is recorded evidence, not a fresh independent retest of every model. Cache hits were zero; no live reuse speedup or parallel-execution benefit was measured.

Two M1 implementation gaps remain before a full completion claim:

- `v_latest_reusable_evidence` relies on persisted freshness labels and does not recompute age or detect a later earnings event. Implement deterministic date parsing (including legacy Sheet serial dates), source provenance checks, age/event invalidation and behavioral negative tests before enabling unattended reuse.
- `v_research_pipeline_controller` reports `model_debt_blocks_sector_completion=true` for `MODEL_FACTORY_AFTER_CURRENT_SECTOR`, whereas the operating controller says to finish the current sector first. Correct the boundary and test coverage crossing below 70% during a run; new-sector discovery must remain blocked.

The source router and parallelizability flags are configured. Parallel worker behavior and enforcement are not proven merely by those flags. See [closeout report](07_RESEARCH_CLOSEOUT.md).

### M1 exit criteria

- Stage timings are measured rather than estimated.
- Sector discovery can finish even when one candidate creates Model Debt.
- Fresh evidence is reused deterministically.
- No production candidate is promoted without the existing evidence / valuation / portfolio-fit gates.
- Communication Services can run under the new pipeline without breaking prior regressions.

## M2 — Decision Intelligence

**Status: PENDING M1 FOUNDATION**

Goal: answer not only whether a company is good, but whether it is attractive at the current price and suitable for the live portfolio.

- [ ] Native Market Price layer with quote timestamp, session status and freshness gate.
- [ ] Mispricing engine: current price vs Bear/Base/Bull/PW fair value, upside/downside and margin-of-safety classification.
- [ ] Portfolio Fit Engine: live position weight, sector/theme dependency, concentration, crypto exposure, thesis overlap and opportunity-cost context.
- [ ] Supabase parity for `Data_Scoring_v2` using the production weights: Business/Thesis 30%, Expected Return/Valuation 30%, Portfolio Fit 25%, Downside Risk 15%.
- [ ] Fail-closed parity tests for stale price, stale earnings, missing portfolio context and incomplete valuation.

### M2 exit criteria

The system can state, with traceable inputs: **good business + current valuation + expected return + portfolio fit + downside risk**.

## M3 — Opportunity & Capital Allocation

**Status: PENDING M2**

Goal: rank where the next unit of capital should go and simulate portfolio changes without auto-trading.

- [ ] Supabase parity / cutover for `Opportunity_Engine_v2`.
- [ ] Global candidate ranking with maximum 5 active watchlist candidates and maximum 3 immediate buy candidates.
- [ ] New-cash deployment logic.
- [ ] Soft-rebalancing sequence: new cash → reduce DCA → reassess thesis/valuation → allow weights to normalize → hard trim only when justified.
- [ ] Rebalancing signal engine with trim/add amounts and before/after portfolio exposure.
- [ ] Trim/Add simulation with estimated change in portfolio expected return and concentration risk.
- [ ] Explicit concentration review for exceptional single-stock weights above approximately 30%.
- [ ] Explicit Phase-1 crypto exposure review around the approximately 15–20% target.

### M3 exit criteria

The system can answer: **“If new capital is available today, where should it go; should anything be reduced first; and what changes in expected portfolio outcome?”** Human approval/execution remains mandatory.

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

# SIDE QUESTS

Side Quests improve coverage, ergonomics or specialist depth but should not interrupt the active Main Roadmap unless the Operating Controller or a hard dependency explicitly promotes one into the main path.

## Current model debt — promoted to the main execution queue

The live controller has promoted model work ahead of additional discovery. Priority values are snapshots of the controller, not investment scores.

| Rank | Blocker | Scope | Resolution value |
|---|---|---|---:|
| 1 | BLK-COMM-DADS-MDL-001 | RDDT / PINS digital advertising | 88.40 |
| 2 | BLK-IT-SEMI-MDL-001 | QCOM semiconductor designer | 73.80 |
| 3 | BLK-COMM-STREAM-DEF-001 | Streaming / Media | 73.70 |
| 4 | BLK-MAT-PACK-DEF-001 | BALL packaging | 73.45 |
| 5 | BLK-IT-SEMICAP-MDL-001 | AMAT semiconductor equipment | 72.00 |
| 6 | BLK-MP-MAGNETICS-NAV-001 | MP full-company NAV bridge | 71.55 |
| 7 | BLK-COMM-TELCO-DEF-001 | Telecom | 12.00 |

All remain fail-closed. A configured model or existing generic kernel cannot close a blocker without normalized inputs, explicit assumptions and model regressions.

## Other side quests

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

**Repair the two M1 hardening gaps, then execute the controller-required model sprint, starting with Digital Advertising.**

1. Preserve Communication Services research completion and its central blockers; do not repeat the sector.
2. Make cache eligibility recompute freshness and invalidate evidence after a later material event.
3. Correct the current-sector completion boundary without allowing a new sector below the coverage threshold.
4. Complete the Digital Advertising normalization/model contract for RDDT/PINS with independent regression anchors; keep production valuation blocked until every requirement passes.
5. Recompute coverage and re-read the controller. Financials stays queued until discovery is permitted.
6. Implement M2 price/mispricing and portfolio-fit parity, then M3 and M4 against their exit criteria.

The closeout utility checks recorded no-promotion run consistency; it is not a substitute for the remaining implementation or independent investment-source verification.

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
- Corrected project-direction drift away from the stale Materials next-sector snapshot; current live sector remains Communication Services, READY / IDLE / no run ID.
