# FWIOS Database Documentation

**Documentation version:** DB-DOC-1.0  
**Architecture status:** CURRENT PRODUCTION BASELINE  
**Verified against live Supabase:** 2026-11-06 10:26:42 UTC  
**Supabase project:** `focused-wealth-investment-os`  
**Implementation changes authorized by this documentation:** No

This directory is the maintainable, text-first database architecture reference for FWIOS.

The objective is simple: when the production database is upgraded or downgraded, an AI or human maintainer must be able to read the live state, compare it with these files, update the diagrams and catalog, and leave an auditable record of what changed.

## Source-of-truth order

When sources disagree, use this order:

1. **Live Supabase production state** — what actually exists now.
2. `contracts/system-contract.yaml` — supported ownership and safety contract.
3. `docs/CURRENT_STATUS.md` — latest operational handoff and production receipts.
4. `docs/PRICE_PIPELINE.md` — current price-pipeline behavior.
5. `docs/API_PROVIDER_GUIDE_V1.md` and `docs/DATA_PROVIDER_STRATEGY_V1.md` — selected provider strategy.
6. Files in this directory — human-readable architecture mirror of the verified live state.
7. Historical migrations — evidence of how the database reached the current state, not proof that old objects still exist.

**Never infer current production architecture from migration history alone.**

## Files

| File | Purpose |
|---|---|
| [DATABASE_ARCHITECTURE.md](DATABASE_ARCHITECTURE.md) | Current schemas, ownership boundaries, runtime components and database invariants |
| [DATABASE_ERD.md](DATABASE_ERD.md) | Mermaid entity/relationship diagrams generated from the current live schema |
| [DATA_FLOW.md](DATA_FLOW.md) | Current end-to-end data flow through providers, workers, database and Google Sheet |
| [TABLE_CATALOG.md](TABLE_CATALOG.md) | Purpose, ownership, writers/readers, keys, retention and lifecycle for each current table/view |
| [AI_MAINTENANCE_RULES.md](AI_MAINTENANCE_RULES.md) | Required procedure for AI-driven upgrade/downgrade documentation updates |
| [CHANGELOG.md](CHANGELOG.md) | Durable architecture-document history |

## Status vocabulary

Every architecture object must be described using one of these states:

- **CURRENT** — verified to exist and be supported in live production.
- **PLANNED** — design only; not deployed.
- **TRANSITION** — live temporarily during an approved cutover.
- **RETIRED** — no longer part of current architecture; retained only as historical context.
- **PLATFORM** — Supabase/Postgres operational object managed outside the FWIOS application schema.

Planned objects must never be drawn inside the CURRENT ERD as if they already exist.

## Maintenance invariant

The diagram is not the source of truth. The diagram is a reviewable representation of the live database.

For every approved schema upgrade or downgrade:

`live database -> verify -> update catalog -> update ERD -> update data flow -> update changelog -> verify again`

Do not manually edit a generated picture and treat it as canonical. Mermaid/Markdown remains the editable source so AI maintainers can update it through normal Git diffs.

## Current ownership boundary

- Supabase owns canonical instrument identity and market-price observations.
- The Investment Portfolio Tracker Google Sheet owns Transactions, Holdings quantities, Cost Basis, Manual Overrides and portfolio accounting.
- FWIOS database/provider work must not directly mutate those accounting-owned values.
- Automatic trading remains disabled.

## Current provider-strategy boundary

Alpha Vantage is excluded from the future Provider Strategy v1. Historical observations, quota receipts, constraints and functions that still mention Alpha Vantage are **current runtime legacy state**, not approval to use Alpha in future architecture. They must remain documented until an approved runtime cutover removes them.
