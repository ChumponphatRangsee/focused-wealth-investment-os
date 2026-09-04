# Focused Wealth Investment OS

Canonical documentation and execution contract for the **Portfolio investment** project.

**Live foundation:** Phase **0.87**  
**Source system:** `US_Stock_Sector_Business_Model_Screener`  
**Strategy:** Focused Wealth-Building  
**Primary Phase-1 objective:** grow the portfolio toward **THB 1,000,000** through aggressive but disciplined capital growth.

> Focus creates upside. Position sizing creates survival. Valuation creates margin of safety.

## What this repository is

This repository is the durable operating contract for AI-assisted investment research. It documents how the live Google Sheet system is allowed to collect evidence, canonicalize metrics, normalize data, run model-specific valuation, score opportunities, resolve blockers, and progress through sector research.

It is **not** a replacement for live portfolio data or live market data. Current portfolio holdings, transactions, prices, financials and material news must still be read from their live sources before any investment decision.

## Mandatory read order for an AI executor

1. [`AGENTS.md`](AGENTS.md) — hard execution contract.
2. [`docs/01_SYSTEM_ARCHITECTURE.md`](docs/01_SYSTEM_ARCHITECTURE.md) — source-of-truth and data flow.
3. [`docs/02_SCORING_AND_GATES.md`](docs/02_SCORING_AND_GATES.md) — Focused Wealth-Building scoring and fail-closed rules.
4. [`docs/03_VALUATION_CONTRACTS.md`](docs/03_VALUATION_CONTRACTS.md) — archetype model registry and model boundaries.
5. [`docs/04_BLOCKED_ORCHESTRATOR.md`](docs/04_BLOCKED_ORCHESTRATOR.md) — root-cause resolution protocol.
6. [`docs/05_AUTONOMOUS_SECTOR_LOOP.md`](docs/05_AUTONOMOUS_SECTOR_LOOP.md) — sector-run state machine.
7. [`docs/06_CHANGE_MANAGEMENT.md`](docs/06_CHANGE_MANAGEMENT.md) — versioning and regression requirements.
8. [`contracts/system-contract.yaml`](contracts/system-contract.yaml) — machine-readable system contract.

## Phase 0.87 live state

The live foundation currently reports **PHASE 0.87 OPERATIONAL** with:

- canonical evidence path through `Evidence_Ledger` and `Company_Metrics_v2`;
- model-input normalization through `Normalized_Metrics_v1`;
- 17 configured archetype valuation contracts;
- production valuation routes currently live for MEDTECH, E&P, Restaurant, Branded Retail and OFS;
- dependency-aware `Blocked Resolution Queue` / orchestrator;
- Focused Wealth-Building production scoring **30 / 30 / 25 / 15**;
- fail-closed Chase/FOMO gating;
- maximum 5 active candidates and maximum 3 immediate buy candidates;
- human execution only — the system never auto-buys or auto-sells.

### Latest sector snapshot

Materials run `SECTOR-MAT-FULL-20260904-01` completed with a 20-name universe and five deep-research names: **BALL, ALB, LIN, MP, PPG**. Research evidence passed, but production expected return remains fail-closed because all three Materials archetypes still lack explicit production valuation contracts. Three root definition blockers are recorded in the central queue. No Materials name was promoted as an actionable opportunity.

The next queued autonomous sector is **Information Technology**. Before any sector run, the executor must confirm the documentation handshake in `System_Foundation` is PASS and re-read the live sheet; this repository never overrides newer live system state.

## Source precedence

1. Latest portfolio holdings / transactions / allocation
2. Focused Wealth-Building rules
3. Personal Investment Strategist framework
4. Screener / system contract
5. Current primary-source research
6. Wall Street consensus
7. News / social narratives

If current portfolio data conflicts with an older assumption or document, **current portfolio data wins**.

## Repository version

Documentation contract version: **FWIOS-CONTRACT-0.87.0**  
Live foundation compatibility: **0.87**  
Snapshot date: **2026-09-04 Asia/Bangkok**
