# FWIOS Database Documentation Changelog

This changelog records architecture-document changes. It does not replace Supabase migration history or `docs/CURRENT_STATUS.md`.

## DB-DOC-1.0 — 2026-11-06

**Type:** Initial documentation baseline  
**Production schema changed by this entry:** No  
**Live snapshot:** 2026-11-06 10:26:42 UTC

Created the maintainable database documentation set:

- `README.md`
- `DATABASE_ARCHITECTURE.md`
- `DATABASE_ERD.md`
- `DATA_FLOW.md`
- `TABLE_CATALOG.md`
- `AI_MAINTENANCE_RULES.md`
- `CHANGELOG.md`

Baseline verified against live Supabase:

- 3 current `fwios` tables;
- 1 current `fwios` identity view;
- 5 current `fwios` functions;
- 1 current `fwios` append-only trigger;
- 1 current `fwios_quota` table;
- 4 current `fwios_quota` functions;
- 6 active pg_cron jobs;
- 2 active Edge Functions.

Recorded current runtime legacy debt:

- future Provider Strategy excludes Alpha Vantage;
- live quota constraints/functions and native USD read code still contain Alpha Vantage references pending an approved implementation cutover;
- historical Alpha observations/receipts remain valid historical evidence.

Recorded security context:

- Supabase catalog advisor reports RLS disabled on `fwios_quota.api_call_ledger`;
- direct privilege verification at this baseline found no `fwios_quota` schema USAGE and no direct table grants for `anon`, `authenticated`, `service_role` or `PUBLIC`;
- no security/runtime change was made as part of this documentation baseline.

### Data-flow impact

None. Documentation mirrors the current runtime.

### Rollback

Documentation-only change. Reverting the docs does not alter production database state.

---

## Entry template for future changes

### DB-DOC-X.Y — YYYY-MM-DD

**Type:** Upgrade / Downgrade / Retirement / Correction  
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
