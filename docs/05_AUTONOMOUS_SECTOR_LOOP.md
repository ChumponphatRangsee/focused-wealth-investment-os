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
5. Information Technology — QUEUED / READY
6. Communication Services — QUEUED / READY
7. Financials — QUEUED / READY
8. Industrials — QUEUED / READY
9. Real Estate — QUEUED / READY
10. Utilities — QUEUED / READY
11. Consumer Staples — QUEUED / READY

The live sheet must always be checked again before executing. This snapshot is documentation, not a substitute for current state.

## Latest Materials run

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

## Information Technology next-run requirement

Before starting Information Technology:

1. documentation handshake must be PASS;
2. live foundation must still be compatible with contract 0.87.0;
3. central blocker queue must be read;
4. current portfolio must be re-read because NVDA/MSFT exposure makes portfolio-fit gating especially important;
5. each IT archetype must use its current `Sector_Criteria` contract exactly as defined;
6. any missing or unimplemented valuation model must fail closed rather than falling back to a generic multiple.

Current Information Technology archetypes in the live queue include:

- IT Services / Hardware
- SaaS / Application Software
- Semiconductor Designer
- Semiconductor Equipment / Foundry

Configured model IDs exist for SaaS, Semiconductor Designer and Semiconductor Equipment / Foundry, but those routes are not listed among the Phase 0.87 implemented production models. Discovery and evidence collection may proceed, while production promotion must remain blocked until model readiness is explicitly implemented and regression-tested. Any archetype without a complete model/metric contract must create a root definition blocker instead of receiving an improvised valuation.

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
