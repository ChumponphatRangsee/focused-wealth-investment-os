# AI Database Documentation Maintenance Rules

**Policy version:** AI-DB-DOC-1.0  
**Applies to:** `docs/database/*`

This file is the maintenance contract for any AI or human agent updating FWIOS database architecture documentation.

## 1. Mandatory preflight

Before changing database documentation:

1. Read current GitHub `main`.
2. Read:
   - `docs/CURRENT_STATUS.md`
   - `contracts/system-contract.yaml`
   - `docs/PRICE_PIPELINE.md`
   - `docs/API_PROVIDER_GUIDE_V1.md`
   - all current files under `docs/database/`
3. Inspect live Supabase **read-only**:
   - project/version/status;
   - current relations and columns;
   - PK/FK/check constraints as needed;
   - views;
   - functions affecting data behavior;
   - non-internal triggers;
   - active cron jobs when data flow depends on them;
   - live Edge Functions when data flow depends on them.
4. Compare live state against the current docs.
5. Do not perform a production write merely to make documentation match an intended design.

## 2. Classification rule

For every object, explicitly classify it:

- `CURRENT`
- `PLANNED`
- `TRANSITION`
- `RETIRED`
- `PLATFORM`

**Never describe PLANNED as CURRENT.**

A design document may discuss planned tables, but the CURRENT ERD and CURRENT table catalog must contain only objects verified in production.

## 3. Upgrade procedure

After an approved schema upgrade has been deployed:

1. Verify the migration is present in live migration history.
2. Query live schema state.
3. Verify expected constraints/relationships/triggers/functions.
4. Run the approved regression/postflight checks.
5. Update `TABLE_CATALOG.md`.
6. Update `DATABASE_ERD.md`.
7. Update `DATA_FLOW.md` if the logical path changed.
8. Update `DATABASE_ARCHITECTURE.md` if ownership/domain boundaries changed.
9. Add a `CHANGELOG.md` entry with:
   - date;
   - architecture-doc version;
   - migration/PR/commit if available;
   - objects added/changed/retired;
   - data-flow impact;
   - rollback/downgrade implications.
10. Update `docs/CURRENT_STATUS.md` with the verified production outcome.
11. Re-read the committed docs and confirm they describe the live database, not the intended migration.

## 4. Downgrade / retirement procedure

When a current object is removed or a feature is downgraded:

1. Verify the object is actually absent/inactive in production before removing it from CURRENT docs.
2. Remove it from the current ERD.
3. Remove or mark it RETIRED in the current catalog, depending on whether historical context is necessary.
4. Remove obsolete flow arrows from `DATA_FLOW.md`.
5. Record the retirement in `CHANGELOG.md`.
6. Preserve historical facts in changelog/handoff documentation.
7. Do not rewrite immutable production evidence merely because a provider/table/function is no longer current.
8. Verify no live reader/writer still depends on the retired object.

## 5. Column-level changes

Update the ERD/catalog when a column affects:

- PK/FK identity;
- uniqueness/idempotency;
- lifecycle/status;
- provider lineage;
- canonical value semantics;
- currency/session/time semantics;
- retention;
- security/ownership;
- data-flow routing.

A purely incidental column may remain catalog-only if putting it in the ERD would reduce readability, but the catalog must stay accurate.

## 6. Diagram rules

- Mermaid source in Markdown is the editable canonical diagram representation.
- Keep diagrams readable; do not dump every Postgres system table.
- Distinguish physical FK relationships from logical data-flow relationships.
- Never draw a logical correlation as an FK.
- Views must be labeled as views/projections.
- Platform schemas must be visually separated from FWIOS-owned schemas.
- Any PNG/SVG generated later is a derived artifact, not the source of truth.

## 7. Data-flow rules

Update `DATA_FLOW.md` whenever a change affects:

- who writes a table;
- who reads a table;
- provider routing;
- normalization/canonicalization stages;
- durable evidence/lineage;
- quota/failover behavior;
- Google Sheet boundary;
- accounting ownership;
- trading behavior.

## 8. Safety invariants

Documentation changes never authorize runtime changes.

Unless an approved implementation task explicitly says otherwise:

- do not mutate Transactions;
- do not mutate Holdings quantities;
- do not mutate Cost Basis;
- do not mutate Manual Overrides;
- do not mutate portfolio accounting;
- keep `auto_trade=false`;
- do not manually invoke a provider/worker merely to manufacture PASS evidence;
- do not expose provider secrets;
- do not hard-delete immutable history to make diagrams cleaner.

## 9. Provider retirement rule

If a provider is removed from strategy but still appears in live constraints/functions/history:

- document the strategy decision separately from live runtime truth;
- do not pretend the runtime reference has already disappeared;
- mark the live reference as transition/legacy debt;
- remove it from CURRENT runtime documentation only after verified cutover.

This rule currently applies to Alpha Vantage.

## 10. Drift handling

If live production and docs disagree:

- treat live production as the current technical state;
- treat contract/safety documents as the authority for what behavior is permitted;
- report the drift explicitly;
- do not silently reconcile by editing production;
- update docs only to VERIFIED reality, or mark the mismatch as unresolved.

## 11. Versioning

Use documentation versions:

- patch: wording/non-structural corrections;
- minor: table/relationship/flow changes that preserve overall architecture;
- major: domain/authority redesign or major structural cutover.

Example:

`DB-DOC-1.0 -> DB-DOC-1.1 -> DB-DOC-2.0`

This version tracks documentation architecture, not PostgreSQL/Supabase migration version numbers.
