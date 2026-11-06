# FWIOS Database Documentation

**Layout version:** DB-DOC-LAYOUT-2  
**Current architecture:** DB-ARCH-1.0  
**Current documentation revision:** DOC-REV-2  
**Production schema changed by this restructure:** No

This directory separates **current production architecture**, **future design**, and **immutable historical snapshots** so AI and human maintainers do not confuse versions.

## Read this first

The machine-readable pointer is:

- [CURRENT.yaml](CURRENT.yaml)

An AI handling any database task must read `CURRENT.yaml` before opening architecture files.

## Directory structure

```text
docs/database/
├── CURRENT.yaml
├── README.md
├── current/
│   ├── MANIFEST.yaml
│   ├── DATABASE_ARCHITECTURE.md
│   ├── DATABASE_ERD.md
│   ├── DATA_FLOW.md
│   └── TABLE_CATALOG.md
├── planned/
│   └── README.md
├── history/
│   └── DB-ARCH-1.0/
│       ├── MANIFEST.yaml
│       ├── DATABASE_ARCHITECTURE.md
│       ├── DATABASE_ERD.md
│       ├── DATA_FLOW.md
│       └── TABLE_CATALOG.md
├── AI_MAINTENANCE_RULES.md
└── CHANGELOG.md
```

## Version types

These identifiers are intentionally separate.

| Identifier | Meaning | Changes when |
|---|---|---|
| `DB-ARCH-X.Y` | Actual database architecture | Structural/domain/authority architecture changes |
| Supabase migration version | Executed PostgreSQL migration history | A migration is applied |
| `DOC-REV-N` | Documentation revision | Docs change without changing production architecture |
| `DB-DOC-LAYOUT-N` | Documentation storage/layout format | Versioning/document organization changes |

Example: restructuring these files changed `DOC-REV-1 -> DOC-REV-2` and layout to `DB-DOC-LAYOUT-2`, while the production architecture remains `DB-ARCH-1.0`.

## Source-of-truth order

When sources disagree:

1. **Live Supabase production state**
2. `contracts/system-contract.yaml`
3. `docs/CURRENT_STATUS.md`
4. `docs/PRICE_PIPELINE.md`
5. `docs/database/CURRENT.yaml`
6. `docs/database/current/*`
7. provider/design documentation
8. historical migrations and `history/*`

Migration history proves what once ran; it does not prove an old object still exists.

## Current

The only mutable documentation representing verified production is under:

- [current/](current/)

Do not create version-numbered subfolders inside `current/`. `CURRENT.yaml` supplies the version.

## Planned

Future designs belong under:

- [planned/](planned/)

Every planned architecture must use its own version directory, for example `planned/DB-ARCH-2.0/`.

A planned object must never appear in the current ERD/catalog as though it exists in production.

## History

Retired current snapshots belong under:

- [history/](history/)

Historical version folders are immutable. Do not edit them to make old architecture look like the current system.

## Compatibility paths

The old files at the root of `docs/database/` are retained as pointer stubs so existing GitHub links do not break. They are **not** the editable current architecture.

## Maintenance

Read [AI_MAINTENANCE_RULES.md](AI_MAINTENANCE_RULES.md) before any upgrade, downgrade, retirement, promotion or documentation reconciliation.

## Safety boundary

Documentation maintenance never authorizes runtime changes. Transactions, Holdings quantities, Cost Basis, Manual Overrides and portfolio accounting remain outside database-documentation writes, and automatic trading remains disabled.
