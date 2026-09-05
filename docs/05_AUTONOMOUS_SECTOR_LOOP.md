# 05 — Autonomous Sector Research Loop

Contract version: **FWIOS-CONTRACT-0.87.0**

Live state controller: `Sector_Run_Control`.

The loop is sector-first and stateful. AI may discover and research; production gates determine trust and promotion.

## Core run rules

- One **full sector** per scheduled run.
- If `Run Lock = RUNNING`, resume the existing sector; do not start another concurrently.
- Maximum universe per sector: **20**.
- Maximum sector shortlist: **5**.
- Maximum global active candidates: **5**.
- Maximum immediate buy candidates: **3**.
- Do not force-fill a shortlist.
- Human execution only; never auto-buy or auto-sell.

## Run sequence

```text
Select first eligible QUEUED sector
  ↓
Build sector universe
  ↓
Map every company to a Sector_Criteria archetype
  ↓
Collect screening evidence
  ↓
Apply quality / evidence screens
  ↓
Create sector shortlist (≤5)
  ↓
Deep evidence collection
  ↓
Canonical metrics
  ↓
Normalization
  ↓
Archetype-correct intrinsic valuation
  ↓
Focused Wealth-Building scoring
  ↓
Compare against existing global active candidates
  ↓
Close run and append history
```

## Evidence rule

No production score without traceable approved evidence.

If a required metric is missing, stale, conflicting or unverified:

1. mark the affected production path BLOCKED;
2. create/update a root blocker in the central queue when needed;
3. preserve the company in the auditable sector universe;
4. continue research on other names when safe;
5. resume unresolved work on a later run rather than inventing data.

## Sector universe audit

`Sector_Universe` must preserve discovered, rejected and blocked companies so the system can explain why a company did or did not progress.

Rejected and blocked names must not be used merely to fill empty shortlist ranks.

## Global candidate policy

After a sector shortlist is researched, compare qualifying candidates with the existing active candidate set. Retain the best **5 overall** using expected return and portfolio fit, not novelty or sector diversification for its own sake.

A new candidate must compete against:

- existing candidates;
- adding to an existing holding;
- waiting for a better price / holding cash.

## Portfolio-fit overlay

Before promotion, re-read the current portfolio.

This matters especially for sectors that overlap heavily with existing exposures. A strong standalone candidate can still become `AVOID ADD - PORTFOLIO` when it worsens concentration materially.

## Current queue snapshot

At the latest Phase 0.87 snapshot:

1. Consumer Discretionary — COMPLETE
2. Health Care — COMPLETE
3. Energy — COMPLETE
4. Materials — COMPLETE
5. Information Technology — COMPLETE
6. Communication Services — research COMPLETE / DONE (2026-09-05)
7. Financials — QUEUED / READY
8. Industrials — QUEUED / READY
9. Real Estate — QUEUED / READY
10. Utilities — QUEUED / READY
11. Consumer Staples — QUEUED / READY

The live sheet must always be checked again before executing. This snapshot is documentation, not a substitute for current state.

## Historical Materials run

Run ID: `SECTOR-MAT-FULL-20260904-01`

Materials completed a 20-name full-sector screen across:

- Mining / Commodities
- Packaging
- Specialty Chemicals / Industrial Gases

Deep research / sector shortlist:

1. BALL
2. ALB
3. LIN
4. MP
5. PPG

The run produced **no actionable opportunity** because all three Materials archetypes still lack explicit production valuation contracts. The system therefore failed closed rather than using generic P/E, current commodity prices, or an unsupported AI fair-value estimate.

Root definition blockers created:

- `BLK-MAT-MIN-DEF-001` — Mining / Commodities valuation contract
- `BLK-MAT-PACK-DEF-001` — Packaging valuation contract
- `BLK-MAT-CHEM-DEF-001` — Specialty Chemicals / Industrial Gases valuation contract

These are `MANUAL` system-development blockers. Scheduled blocker automation must not redesign the production model registry automatically.

## Historical Information Technology run

Run ID: `SECTOR-IT-FULL-20260904-01`

Information Technology completed a 20-name full-sector screen across:

- IT Services / Hardware
- SaaS / Application Software
- Semiconductor Designer
- Semiconductor Equipment / Foundry

Deep research / sector shortlist:

1. ADBE
2. ACN
3. CRM
4. QCOM
5. AMAT

Each shortlisted name has five fresh, verified Tier-A evidence rows and passes the research evidence gate. The run produced **no actionable opportunity** because production valuation is not available for any of the four IT routes:

- IT Services / Hardware — production valuation contract is incomplete / undefined.
- SaaS / Application Software — `SAAS_EV_FCF_REVERSE_DCF_V1` is configured but not implemented.
- Semiconductor Designer — `SEMIS_MIDCYCLE_DCF_V1` is configured but not implemented.
- Semiconductor Equipment / Foundry — `SEMICAP_MIDCYCLE_FCF_V1` is configured but not implemented.

The system failed closed rather than using a generic P/E, EV/EBITDA, FCF yield, or unsupported AI fair-value estimate.

Root blockers created:

- `BLK-IT-HW-DEF-001` — IT Services / Hardware valuation contract definition
- `BLK-IT-SAAS-MDL-001` — SaaS valuation model implementation
- `BLK-IT-SEMI-MDL-001` — Semiconductor Designer valuation model implementation
- `BLK-IT-SEMICAP-MDL-001` — Semiconductor Equipment / Foundry valuation model implementation

These are `MANUAL` system-development blockers. Scheduled blocker automation must skip them until an explicit production-model development run is requested.

### Historical portfolio-fit result

The live portfolio was re-read before promotion. The run observed concentrated AI / mega-cap exposure. Exact private allocations must be read from the portfolio tracker, not retained in this public repository. Correlated AI / mega-cap / semiconductor names were therefore explicitly penalized. NVDA remains a stop-add concentration case rather than a new-capital candidate, and MSFT was not promoted merely because it belongs to a high-quality IT archetype.

No IT name entered the immediate-buy set. The global active research set remains:

- ISRG
- EOG
- BKR
- CAVA
- TPR

No portfolio holdings or transactions were changed.

## Historical Communication Services start requirements

Before starting Communication Services:

1. documentation handshake must be PASS;
2. live foundation must be compatible with the current `VERSION`;
3. central blocker queue must be read;
4. current portfolio must be re-read before portfolio-fit promotion;
5. each Communication Services archetype must use its current `Sector_Criteria` contract exactly as defined;
6. any missing or unimplemented valuation model must fail closed rather than falling back to a generic multiple.

Current Communication Services archetypes in the live queue include:

- Digital Advertising Platform
- Streaming / Media
- Telecom

The live `Sector_Criteria` model/metric contracts must be re-read when the run begins. Documentation must not assume implementation status from memory.

## Run completion

A run is complete only when:

- run lock is released;
- run stage is DONE/COMPLETE;
- sector universe is auditable;
- shortlist counts are accurate;
- root blockers are queued where required;
- global active candidates are reconciled;
- `Sector_Run_History` has a final row;
- no portfolio holdings or transactions were changed as part of screener research.

## Completed Communication Services research and recovery

See [07_RESEARCH_CLOSEOUT.md](07_RESEARCH_CLOSEOUT.md). Research completion and cross-system closeout are separate: persist the universe, blockers and append-only history, verify the unchanged global active set, then release the matching run lock. A new-sector handoff must follow the live operating controller. At 61.1% coverage, finish the current run and do model work before Financials. Never clear a lock belonging to a different run.
