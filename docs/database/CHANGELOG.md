# FWIOS Database Documentation Changelog

## DOC-REV-4 / Crypto daily price refresh Cron identity — 2026-11-09

**Architecture version:** DB-ARCH-1.0 (canonical price/accounting architecture unchanged)  
**Type:** Cron operational name/ID correction + current production documentation reconciliation  
**Production migration:** `20261109045146_rename_crypto_daily_snapshot_cron_to_price_refresh_v1`  
**Live verification:** 2026-11-09 04:54:08 UTC  
**Migration head:** `20261109045146_rename_crypto_daily_snapshot_cron_to_price_refresh_v1`

### Changed

- Replaced active Crypto Cron #14 `fwios-portfolio-crypto-daily-snapshot` with the accurate name `fwios-crypto-price-daily-refresh`, active Cron **#20**; Supabase requires recreation because job names are immutable.
- The replacement retained exactly the original `CRYPTO` Edge Worker dispatch command, UTC schedule `10 21,22 * * *`, database, owner and Vault-based authentication.
- Exactly six jobs remain active: #15–#20. The 46 historical #14 run receipts remain in `cron.job_run_details`.
- Current document pointers, table/catalog/ERD metadata, Contract and Data Flow updated to reflect actual live job IDs.

### Preserved / not changed

- CoinGecko canonical price observations (936) and Twelve Data canonical stock EOD observations (120) are preserved, append-only.
- No active Portfolio Valuation Snapshot; old hidden Sheet snapshot is historical evidence only. No new snapshot table or portfolio backend.
- No modifications to held quantities, Transactions, Cost Basis, Manual Overrides, price Workers, provider calls or trading (`auto_trade=false`).
- Stock/Fx/Sheet/retention jobs #15–19 untouched. The first scheduled execution of new Crypto job #20 remains subject to natural monitoring.

---


## DOC-REV-3 / Alpha Vantage runtime retirement — 2026-11-09

**Architecture version:** DB-ARCH-1.0 (no schema/authority change)  
**Type:** Production provider runtime retirement + current documentation reconciliation  
**Production migrations:** `20261109040630_retire_alpha_vantage_cron_v1`, `20261109041640_retire_alpha_vantage_vault_credential_v1`  
**GitHub PR:** #124 (CI PASS; merged)  
**Live verification:** 2026-11-09 04:16:58 UTC  
**Migration head:** `20261109041640_retire_alpha_vantage_vault_credential_v1`

### Changed

- Cron #17 is Twelve-only at 01:55 New York weekdays; Cron #18 follows up at 02:10. Both preserve active job identity and DST guarding.
- Edge `price-market-refresh-v1` v14 removes Alpha fetch, parser, mode dispatch, URL and credential access; Sheet Worker remains v7.
- Supabase Vault no longer holds `ALPHA_VANTAGE_API_KEY`; Twelve Data credential remains.
- Updated `CURRENT.yaml`, manifest, verified-production architecture and data flow.

### Retained / excluded

- No active Alpha dispatch. Historic Alpha market observations (97) and quota calls (12) stay immutable; SQL/read compatibility retaining Alpha identifiers is **not** an active provider.
- The three canonical price tables, identity view, quota ledger/table/functions, Cron #14–16/#19, and database authority remain unchanged.
- No Transactions, Holdings quantities, Cost Basis, Manual Overrides or portfolio-accounting mutations; `auto_trade=false`.

### Acceptance limitation

A naturally scheduled Twelve 4/4 same-session EOD + Google Sheet readback has **not yet been observed after this cutover**. Do not mark complete autonomous acceptance or close Issue #106 until it occurs, and do not manually trigger a provider/worker to manufacture PASS.

---


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
