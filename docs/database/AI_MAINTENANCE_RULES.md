# AI Database Documentation Maintenance Rules

**Policy version:** AI-DB-DOC-2.0  
**Documentation layout:** DB-DOC-LAYOUT-2

This file is the maintenance contract for any AI or human updating FWIOS database architecture documentation.

## 1. First file to read

Always read `docs/database/CURRENT.yaml` before deciding which architecture files are current.

Never infer the current architecture from the highest-looking folder number, migration name, Git commit order, `planned/`, or `history/`.

## 2. Mandatory preflight

Before changing database documentation:

1. Read current GitHub `main`.
2. Read `docs/database/CURRENT.yaml`.
3. Read `docs/CURRENT_STATUS.md`, `contracts/system-contract.yaml`, `docs/PRICE_PIPELINE.md`, `docs/API_PROVIDER_GUIDE_V1.md`, `docs/database/current/MANIFEST.yaml`, and affected files in `docs/database/current/`.
4. Inspect live Supabase read-only: project/version/status, relations/columns, PK/FK/check constraints as needed, views, behavior-affecting functions, non-internal triggers, active Cron/Edge Functions when relevant, and migration head.
5. Compare live state against `current/`.
6. Do not perform a production write merely to make docs match a planned design.

## 3. Version model

- **DB-ARCH-X.Y** = actual production database architecture.
- **Supabase migration version** = executed PostgreSQL migration history; many migrations may belong to one DB-ARCH.
- **DOC-REV-N** = documentation revision without a production architecture change.
- **DB-DOC-LAYOUT-N** = how architecture documentation is stored/navigated.

## 4. Status locations

- `current/` = verified production architecture only.
- `planned/DB-ARCH-X.Y/` = design only.
- `history/DB-ARCH-X.Y/` = immutable snapshot.
- `CURRENT.yaml` = only machine-readable pointer to the current version.

## 5. Starting a planned architecture

1. Choose a proposed `DB-ARCH-X.Y`.
2. Create `planned/DB-ARCH-X.Y/`.
3. Add `MANIFEST.yaml` with `status: PLANNED`, `production_status: NOT_DEPLOYED`, `based_on`, and approval state.
4. Keep future tables/flows inside that planned folder.
5. Do not add planned objects to current diagrams.

Design approval alone does not promote a version.

## 6. Upgrade / promotion procedure

After implementation is separately approved and deployed:

1. Verify migrations/runtime in live Supabase.
2. Run required regression/postflight checks.
3. Ensure the outgoing current architecture has an immutable snapshot in `history/<old DB-ARCH>/`.
4. Rebuild/reconcile `current/` from verified production.
5. Update `current/MANIFEST.yaml`.
6. Update `CURRENT.yaml`.
7. Update `CHANGELOG.md`.
8. Update `docs/CURRENT_STATUS.md`.
9. Re-read GitHub `main` and confirm `CURRENT.yaml` matches live production.

## 7. Downgrade procedure

A downgrade is production-first, documentation-second.

1. Production downgrade must be separately authorized and executed.
2. Verify live production.
3. Archive the outgoing current version if needed.
4. Reconstruct `current/` from the matching historical snapshot, then reconcile against live state.
5. Update `CURRENT.yaml`.
6. Record the downgrade in `CHANGELOG.md`.
7. Never point `CURRENT.yaml` to an older version while production still runs the newer schema.

## 8. Historical immutability

Files under `history/DB-ARCH-X.Y/` are immutable snapshots. Do not edit them during normal maintenance.

If a historical fact needs correction, record a correction in the global changelog instead of silently rewriting the snapshot.

## 9. Compatibility stubs

The root files `DATABASE_ARCHITECTURE.md`, `DATABASE_ERD.md`, `DATA_FLOW.md`, and `TABLE_CATALOG.md` are compatibility pointers only. Never maintain architecture content there.

## 10. Diagram rules

Mermaid/Markdown is the editable representation. Distinguish physical FK from logical flow, label views as projections, separate platform schemas from FWIOS-owned schemas, and treat later PNG/SVG files as derived artifacts only.

## 11. Safety invariants

Documentation changes never authorize runtime changes. Unless explicitly authorized: no schema write, no provider/worker invocation to manufacture PASS, no Transactions/Holdings quantity/Cost Basis/Manual Override/portfolio-accounting mutation, no automatic trading, no secret exposure, and no deletion/rewrite of immutable evidence.

## 12. Provider retirement rule

If a provider is removed from strategy while live code/constraints/history still reference it, future design must exclude it but current docs must reflect verified runtime truth until an approved cutover removes the live reference. This currently applies to Alpha Vantage.

## 13. Drift handling

If live production and docs disagree: live Supabase is the technical state; contract/safety docs define what is permitted; report the drift explicitly; do not silently edit production; reconcile `current/` only to verified reality; update `CURRENT.yaml` last.
