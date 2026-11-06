# Planned Database Architectures

This directory contains **design-only** database architectures that are not production.

## Current state

There is currently **no active planned database architecture folder**.

When a new architecture design begins, create a versioned directory such as:

```text
planned/DB-ARCH-2.0/
├── MANIFEST.yaml
├── DATABASE_ARCHITECTURE.md
├── DATABASE_ERD.md
├── DATA_FLOW.md
├── TABLE_CATALOG.md
└── DESIGN_DECISIONS.md
```

The planned manifest must contain:

- `status: PLANNED`
- `production_status: NOT_DEPLOYED`
- the base/current architecture version it evolves from
- approval state
- intended migration/cutover notes when known

## Promotion rule

A planned version must **not** be copied/promoted to `current/` merely because its design is approved.

Promotion happens only after:

1. implementation is separately authorized;
2. migrations/runtime changes are deployed;
3. live Supabase is verified;
4. postflight/regression checks pass;
5. the old current version is archived under `history/`;
6. `CURRENT.yaml` is updated to the verified production version.

This separation prevents AI or human maintainers from confusing design intent with production reality.
