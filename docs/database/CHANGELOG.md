# FWIOS Database Documentation Changelog

This changelog records architecture-document and documentation-layout changes. It does not replace Supabase migration history or `docs/CURRENT_STATUS.md`.

## DOC-REV-2 / DB-DOC-LAYOUT-2 — 2026-11-06

**Architecture version:** DB-ARCH-1.0 (unchanged)  
**Type:** Documentation versioning restructure  
**Production schema changed:** No  
**Live verification:** 2026-11-06 10:42:14 UTC  
**Migration head:** `20261103103747_usdthb_fx_identity_v1`

Changed documentation storage from one mutable flat snapshot to:

- `CURRENT.yaml` machine-readable pointer;
- mutable `current/`;
- design-only `planned/`;
- immutable `history/DB-ARCH-X.Y/`.

Archived the original DB-DOC-1.0 baseline as `history/DB-ARCH-1.0/`.

Separated version semantics:
- `DB-ARCH` = production architecture;
- migration version = executed database migration history;
- `DOC-REV` = documentation revision;
- `DB-DOC-LAYOUT` = documentation storage format.

Converted old root architecture documents into compatibility pointers so existing GitHub links remain valid without duplicate mutable sources.

### Data-flow impact

None.

### Production impact

None. No schema, function, trigger, provider, worker, Cron, Vault, Google Sheet, portfolio or trading change.

---

## DB-ARCH-1.0 / legacy label DB-DOC-1.0 — 2026-11-06

**Type:** Initial documentation baseline  
**Production schema changed:** No  
**Live snapshot:** 2026-11-06 10:26:42 UTC

The original text-first database documentation baseline is preserved under `history/DB-ARCH-1.0/`.

Baseline verified: 3 `fwios` tables, 1 identity view, 5 `fwios` functions, 1 append-only trigger, 1 `fwios_quota` table, 4 quota functions, 6 active pg_cron jobs, and 2 active Edge Functions.

### Data-flow impact

None.

---

## Future entry template

### DB-ARCH-X.Y / DOC-REV-N — YYYY-MM-DD

**Type:** Upgrade / Downgrade / Retirement / Correction / Documentation-only  
**Production migration:**  
**PR / commit:**  
**Live verification timestamp:**  

**Added**
- 

**Changed**
- 

**Retired**
- 

**Data-flow impact**
- 

**Authority/ownership impact**
- 

**Rollback/downgrade notes**
- 

**Postflight verification**
- 
