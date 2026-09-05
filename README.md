# Focused Wealth Investment OS

Operating contract and reconciliation tools for the Portfolio investment system.

**Foundation:** 0.87

**Contract:** FWIOS-CONTRACT-0.87.1

**Project:** ACTIVE — research is operational; decision and allocation cutovers remain incomplete.

> Focus creates upside. Position sizing creates survival. Valuation creates margin of safety.

## Start here

1. [AGENTS.md](AGENTS.md)
2. [Master roadmap](docs/00_SYSTEM_ROADMAP.md)
3. [System contract](contracts/system-contract.yaml) and [VERSION](VERSION)
4. Live `System_Foundation`, `Sector_Run_Control`, and Supabase controller views
5. [Research closeout and recovery](docs/07_RESEARCH_CLOSEOUT.md)

Current live data overrides documentation. The portfolio tracker remains the authority for holdings and transactions. Supabase owns migrated research evidence and valuation compute records; Sheets remains the operational control room and downstream decision compatibility layer. This is not yet a standalone application.

## Latest reconciled run — 2026-09-05

Communication Services `SECTOR-CS-FULL-20260905-01` has completed research:

- Fast Discovery: 20 → 8; Light Research: 8 → 5; Deep Research: 5 → 3.
- RDDT, PINS and NFLX have 25 persisted Tier-A evidence records in total.
- TMUS and WMG remain deferred after light research.
- Measured stage time: 863.729 seconds (14.4 minutes), one run only.
- No new production promotion or immediate-buy candidate.
- Valuation coverage: 11 / 18 evidence-ready candidates (61.1%); seven root model blockers.
- Controller: `MODEL_FACTORY_AFTER_CURRENT_SECTOR`. Finish reconciliation, then model sprint; do not start Financials automatically.

Read [closeout findings](docs/07_RESEARCH_CLOSEOUT.md) for the remaining M1 hardening issues. M2–M4 are still pending. A completed research run does not mean the whole project is complete.

## Verification

Python 3 standard library only:

```bash
python -m unittest discover -s tests -v
python scripts/check_closeout.py /absolute/path/to/private-snapshot.json
```

The checker is read-only and designed for a run with **zero new promotions**. It blocks when evidence, run lineage, history, locks or controller handoff disagree. It does not independently verify financial disclosures, current prices, or investment eligibility. Do not commit live snapshots or private portfolio data.

Human execution only. No automatic buys, sells or portfolio transaction writes.
