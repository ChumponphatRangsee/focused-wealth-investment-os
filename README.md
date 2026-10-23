# Focused Wealth Investment OS (FWIOS)

Repository for deterministic investment research/decision contracts, Supabase-backed state and integration services, migrations and regression tests.

- **Contract:** `FWIOS-CONTRACT-0.87.19` (see [system contract](contracts/system-contract.yaml) and [VERSION](VERSION); version is not a deployment receipt).
- **Compatible foundation:** `0.87`.
- **Safety:** Human execution only; no auto-buy/sell. Portfolio transactions/accounting remain under the designated Investment Portfolio Tracker; scanner research does not change holdings, quantities or cash.
- **Current operational truth:** Verify live Supabase, Google Sheets, GitHub PR/commit and relevant scheduled functions independently. Historical snapshots in this repository must never be assumed to describe today's production state.

## Start here — one living entrypoint

1. [AGENTS.md](AGENTS.md) — mandatory execution guardrails.
2. [Current project status](docs/CURRENT_STATUS.md) — dated navigation index to active workstreams, next steps and blockers; **not** a replacement for live verification.
3. [System contract](contracts/system-contract.yaml), [VERSION](VERSION), and [master roadmap](docs/00_SYSTEM_ROADMAP.md).
4. Read only the relevant [implementation plan/runbook](docs/implementation/) or [architecture reference](docs/01_SYSTEM_ARCHITECTURE.md); check the associated PR/Issue and production state before executing.
5. [Documentation lifecycle](docs/DOCUMENTATION_LIFECYCLE.md) governs archival and when to create a new chat handover.

## Scope and ownership

- **Supabase:** FWIOS state, deterministic pricing/research foundations, market data, orchestration and related read models.
- **GitHub:** contracts, logic, migrations, tests, source code, decision history.
- **Investment Portfolio Tracker (Google Sheets):** transaction and accounting source of truth for the current Phase-1 workflow; do not create a duplicate transaction ledger.
- **Focused Wealth Dashboard:** portfolio-independent scanner/research presentation; coverage and scoring eligibility must be verified from the live scanner backend.

The architecture has evolved beyond the original September 2026 sector-first baseline. Research readiness, S&P 500 expansion, pricing and performance features have their own scoped documents; use the [current index](docs/CURRENT_STATUS.md) to find them rather than a dated chat handover.

## Tests and historical evidence

A limited legacy read-only closeout checker remains:

```bash
python -m unittest discover -s tests -v
python scripts/check_closeout.py /absolute/path/to/private-snapshot.json
```

These commands do **not** constitute a full production acceptance or current trading signal. Never commit private portfolio snapshots, service credentials or tokens.

Historical evidence: [September research closeout](docs/07_RESEARCH_CLOSEOUT.md), [Financials sector run](docs/runs/20260906_financials_sector_run.md), and [archived chat handovers](docs/archive/handovers/README.md).

## Change history

See [CHANGELOG.md](CHANGELOG.md), the exact merged GitHub PRs and [documentation audit](docs/DOCUMENTATION_AUDIT_20261020.md). A merged PR does not prove that corresponding Supabase/Sheet deployment checks passed.
