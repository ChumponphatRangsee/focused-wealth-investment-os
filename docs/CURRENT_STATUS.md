# Current Production Status — Asset Price Data Service v1.1.0

## 2026-11-09 — Alpha Vantage runtime retirement (AUTHORIZED; rollout in progress)

- **User authorization:** explicitly requested production removal of Alpha Vantage on 2026-11-09, separately from the still-pending broad Multi-Provider Infrastructure strategy approval.
- **DONE in Supabase:** guarded migration `20261109040630_retire_alpha_vantage_cron_v1` amended only Cron #17/#18. Job #17 schedules only Twelve Data at 01:55 America/New_York weekdays (DST-safe GMT 05:55/06:55), and job #18 performs Sheet follow-up at 02:10 ET (GMT 06:10/07:10). Both job IDs remain active. No Alpha-scheduled provider calls.
- **Code cutover:** Market Worker removes the Alpha fetch/parser/dispatch and `US_STOCK_EOD` mode, retaining only CRYPTO, FX and the established Twelve mode. Its deployment/verification must be recorded separately; do not infer deployed status merely from a GitHub commit.
- **Immutable compatibility:** retain historical `ALPHA_VANTAGE_PRICE` market observations, quota receipts, and read-side compatibility. No historical rewrite, deletion, or replay. Do not assume legacy Alpha references in SQL or Sheet validator represent an active API dependency.
- **Pending acceptance:** Wait for a naturally scheduled Twelve Data 4/4 correct-session EOD batch and subsequent Sheet readback, without any manual provider/worker invocation. Only then consider closing Issue #106 or declaring full autonomous E2E acceptance.
- **Unchanged:** CoinGecko, Frankfurter, Cron #14–16 and #19, Transaction/holdings accounting, Manual Overrides, portfolio values, `auto_trade=false`. The separate stale `FWIOS Live Valuation` snapshot problem remains unresolved.
- The 2026-11-06 handoff and older Alpha production notes below are historical; this newest section governs retirement state.



## 2026-11-06 handoff — FWIOS Data Provider Strategy v1 (RESEARCH / DESIGN ONLY)

### Preflight source-of-truth check

- GitHub default branch is `main`; pre-update baseline head was `29eea0f4180e82ddfa6a85251155496f5d944fe8` (`docs: record USDTHB FX identity production pass (#123)`).
- Re-read current `docs/CURRENT_STATUS.md`, `contracts/system-contract.yaml`, and `docs/PRICE_PIPELINE.md` from `main` before this handoff update.
- Live Supabase was inspected read-only at **2026-11-06 17:01 Asia/Bangkok**. No provider/worker was manually invoked and no production data was written.
- Live price state: **11 instruments + 11 symbols**, **1,149 market observations**, append-only observation guard enabled, Edge Workers remain **price-market-refresh-v1 v13** and **price-sheet-sync-v1 v7**, active Cron IDs **14–19** unchanged.
- Current observation mix: **918 CoinGecko USD LIVE_QUOTE**, **120 Twelve Data USD REGULAR_CLOSE**, **97 Alpha Vantage USD REGULAR_CLOSE**, and **14 Frankfurter THB FX** observations.
- `fwios_quota.api_call_ledger` has **24** rows. Current provider-call outcomes: Twelve Data **16 SUCCESS**; Alpha Vantage **2 SUCCESS, 2 PROVIDER_REJECTED, 4 CANCELED**.
- Alpha Vantage still demonstrates the unresolved daily-limit behavior: the 2026-11-03 and 2026-11-04 EOD batches each reached `ALPHA_VANTAGE_DAILY_RATE_LIMIT` after the first successful symbol, causing undispatched remainder reservations to be canceled. **Issue #106 remains OPEN.**
- Twelve Data fallback has continued to pass naturally without operator intervention. Latest verified run: session **2026-11-05**, MSFT/NVDA/TLN/TTWO all **SUCCESS**, pg_net **#12042 HTTP 200**, `database_writes=4`, `portfolio_writes=0`, `auto_trade=false`. Follow-up Sheet sync pg_net **#12043 HTTP 200** returned `stock_count=4`, `crypto_count=6`, and `sheet_write_readback_verified=true`.
- Latest Stock EOD canonical rows for MSFT/NVDA/TLN/TTWO are all Twelve Data `REGULAR_CLOSE`, USD, session **2026-11-05**, `market_status=CLOSED`, `provenance_status=PASS`.
- Existing contract ownership remains unchanged: Supabase owns canonical market-price observations; the Investment Portfolio Tracker Google Sheet owns Transactions, Holdings quantities, Cost Basis, and portfolio accounting.

### Next task: FWIOS Data Provider Strategy v1

**Do not build Multi-Provider Infrastructure yet.** This phase is research and architecture decision only. No implementation, migration, provider deployment, Cron modification, worker invocation, production write, or portfolio-accounting mutation is authorized by this task.

Research and choose providers for these workloads:

1. S&P 500 Universe / Bulk Screening
2. Portfolio + Watchlist EOD Market Data
3. Fundamentals / Financial Statements / Metrics
4. SEC Filings / Primary Evidence
5. News / Catalysts
6. Crypto
7. FX
8. Backup / Secondary providers

For each candidate provider, compare:

- Coverage
- Free/Paid quota
- Rate limit
- Batch / multi-symbol support
- Cost
- Data freshness
- Historical depth
- Fundamental-data quality
- Reliability
- Licensing / redistribution constraints
- API complexity
- Suitability for approximately 500-stock universe vs 5–50 stock watchlist/portfolio

Required deliverables:

1. Provider comparison matrix
2. Recommended Primary + Fallback per workload
3. Explain which workloads should use bulk providers vs focused providers
4. Decide whether Alpha Vantage should be retired, retained as secondary, or reassigned
5. Estimate daily/monthly API usage and cost for FWIOS
6. Recommend final **Provider Strategy v1**

### 2026-11-06 database documentation versioning restructure — DB-DOC-LAYOUT-2

- Database documentation was reorganized to prevent architecture-version confusion as FWIOS evolves.
- Production architecture remains **DB-ARCH-1.0**; this restructure is **DOC-REV-2** only and made **no production schema/runtime change**.
- Added machine-readable `docs/database/CURRENT.yaml`. AI/human maintainers must read this first; it points to the only mutable verified-production documentation under `docs/database/current/`.
- Added version-separated roots:
  - `docs/database/current/` — verified production mirror;
  - `docs/database/planned/` — design-only future architectures;
  - `docs/database/history/DB-ARCH-X.Y/` — immutable snapshots.
- Archived the original flat DB-DOC-1.0 baseline under `history/DB-ARCH-1.0/`. This is an **ARCHIVED_BASELINE**, not evidence that DB-ARCH-1.0 is retired; DB-ARCH-1.0 is still current production.
- Old root files `DATABASE_ARCHITECTURE.md`, `DATABASE_ERD.md`, `DATA_FLOW.md`, and `TABLE_CATALOG.md` are now compatibility pointers only so existing links continue working without creating duplicate mutable sources.
- Version semantics are now separated:
  - `DB-ARCH-X.Y` = actual production database architecture;
  - Supabase migration version = executed PostgreSQL history;
  - `DOC-REV-N` = documentation-only revision;
  - `DB-DOC-LAYOUT-N` = documentation storage/navigation format.
- Live read-only preflight at **2026-11-06 10:42:14 UTC** still matched the baseline: 3 `fwios` tables, 1 view, 5 `fwios` functions, 1 `fwios_quota` table, 4 quota functions, 6 active Cron jobs, 11 instruments, 11 symbols, 1,149 market observations, and 24 quota-ledger rows. Migration head remains `20261103103747_usdthb_fx_identity_v1`.
- No migration, schema write, Edge deployment, Cron change, provider call, Vault change, Google Sheet accounting change, portfolio mutation, or trading behavior change occurred.

### 2026-11-06 database documentation baseline — DB-DOC-1.0

- Created a text-first, AI-maintainable database documentation set under `docs/database/`: `README.md`, `DATABASE_ARCHITECTURE.md`, `DATABASE_ERD.md`, `DATA_FLOW.md`, `TABLE_CATALOG.md`, `AI_MAINTENANCE_RULES.md`, and `CHANGELOG.md`.
- Baseline was verified against live Supabase **read-only** at **2026-11-06 10:26:42 UTC** before documentation writes.
- Current live application structure documented: **3 `fwios` tables + 1 identity view + 5 `fwios` functions + 1 append-only trigger**, plus **1 `fwios_quota` table + 4 quota functions**.
- Current operational flow documents **6 active pg_cron jobs**, pg_net queue/response receipts, Vault as credential storage, and Edge Functions `price-market-refresh-v1 v13` + `price-sheet-sync-v1 v7`.
- Mermaid/Markdown is the canonical editable diagram representation. Any future PNG/SVG is derived only; AI should update the text source first.
- Maintenance contract: live Supabase is the technical truth; PLANNED objects must never appear as CURRENT; every approved schema upgrade/downgrade must update table catalog, ERD, data flow when affected, changelog, and this handoff after production verification.
- Alpha Vantage is excluded from the future provider strategy, but live runtime constraints/functions that still mention Alpha are documented as legacy transition debt until a separately approved cutover removes them. Historical evidence remains immutable.
- Supabase catalog tooling flags `fwios_quota.api_call_ledger` because RLS is disabled. Direct privilege verification at this baseline found **no schema USAGE** for `anon`, `authenticated`, or `service_role`, and **no direct table grants** to those roles or `PUBLIC`; no RLS/security change was made in this documentation task.
- This was **documentation-only**: no migration, schema write, provider invocation, Edge deployment, Cron change, Vault change, Google Sheet accounting change, portfolio mutation, or trading behavior change.

### 2026-11-06 provider-set revision — Alpha Vantage removed from strategy

- User decision: **Alpha Vantage is removed completely from FWIOS Provider Strategy v1.** It will not be a future primary, fallback, tertiary validator, scheduled dependency, or active Provider Registry member.
- This decision updates future architecture only. The currently deployed price runtime still contains the historical Alpha path until a separately approved implementation/cutover phase removes it safely. Historical observations and receipts remain immutable evidence.
- Provider Strategy was updated in `docs/DATA_PROVIDER_STRATEGY_V1.md`.
- New provider reference document created: `docs/API_PROVIDER_GUIDE_V1.md`.
- The API guide defines provider responsibilities, authentication, endpoint roles, quotas/rate limits, batch behavior, freshness/history, licensing constraints, FWIOS-specific validation rules, and cost baseline for **Massive, Twelve Data, SEC EDGAR, CoinGecko and Frankfurter**.
- Recommended v1 recurring provider cost remains approximately **$29/month** for personal/internal use, driven by Massive Financials & Ratios; current free/public tiers cover the other approved providers under the stated workload assumptions.
- No production provider calls, Supabase schema, Edge Worker, Cron, Vault credential, Google Sheet accounting, portfolio state or trading behavior changed during this documentation update.
- Issue #106 should remain historical/open until the runtime Alpha path is actually removed or superseded in an approved implementation phase; do not close it merely because the strategy document changed.

### Provider Strategy research draft — 2026-11-06

- Research-only Provider Strategy draft is now recorded in `docs/DATA_PROVIDER_STRATEGY_V1.md`.
- Recommended lean stack: Massive for bulk US equity EOD + normalized financials/ratios, Twelve Data for focused 5–50 stock EOD, SEC EDGAR for primary filings/evidence, CoinGecko for Crypto, and Frankfurter for FX. Alpha Vantage is excluded completely from the future provider strategy.
- Estimated recurring provider cost for the lean personal/internal configuration is approximately **$29/month**, driven by Massive Financials & Ratios; other recommended v1 providers can remain on current/free tiers under the stated workload assumptions.
- This is **DRAFT / PENDING USER APPROVAL**. No Multi-Provider Data Infrastructure design or implementation is authorized yet.
- No Supabase schema, Edge Worker, Cron, provider credential, Google Sheet accounting, portfolio state, or trading behavior changed during this research/documentation phase.

### Approval gate

Only after **Provider Strategy v1 is explicitly approved** may the next phase design **Multi-Provider Data Infrastructure v1**, including concepts such as Provider Registry, Capability Registry, Quota/Rate-Limit Policy, API Call Ledger, Raw Provider Data, Normalization, Canonical Data, Validation/Quality, and provider failover.

Until that approval:

- do not implement provider abstractions or new infrastructure;
- do not add or rotate provider keys;
- do not change provider schedules, Cron, workers, database schemas, or canonical price behavior;
- do not manually invoke provider/worker flows to manufacture a PASS;
- keep `auto_trade=false`;
- do not modify Transactions, Holdings quantities, Cost Basis, Manual Overrides, or portfolio accounting.

## 2026-11-03 USD/THB FX identity normalization — Production E2E PASS (PR #121 / #122)

- **Dedicated FX identity is live.** Migration `usdthb_fx_identity_v1` created canonical symbol **`USDTHB`** with `asset_class=FX`, `instrument_type=CURRENCY_PAIR`, venue `FX`, namespace `FX_PAIR`, and primary venue `FRANKFURTER`.
- Canonical identities are now **11 total = 10 held assets + 1 FX support identity**. The Google Sheet holdings universe remains exactly 4 Stocks + 6 Crypto; `USDTHB` is not a portfolio holding.
- The migration did **not rewrite or delete** the 9 historical Frankfurter FX rows that used MSFT as a carrier identity. Those rows remain immutable legacy evidence. Instead, it seeded the latest verified 33.76 USD/THB observation for session 2026-11-02 under the new FX identity with explicit lineage back to the source observation.
- Market Worker **v13** now resolves `USDTHB/FX/FX/FX_PAIR` directly and no longer derives the FX instrument from whichever historical FX row is latest. Sheet Worker **v7** accepts only the canonical `USDTHB` FX identity for the current FX rate.
- Dry-run receipts: pg_net **#12019 HTTP 200** for FX with `fx_symbol=USDTHB`, `database_writes=0`; **#12020 HTTP 200** for Sheet with 10 assets, 6 Crypto, 4 Stocks and zero writes.
- Live verification: pg_net **#12021 HTTP 200** wrote one new Frankfurter FX observation under `USDTHB` at **33.76**, session 2026-11-02; legacy MSFT-carried FX rows remained **9**. pg_net **#12022 HTTP 200** then completed Google Sheet sync with `sheet_write_readback_verified=true`, `database_writes=0`, and `auto_trade=false`.
- Live state after verification: **1,116 market observations**, **2 normalized USDTHB FX observations**, **9 immutable legacy MSFT-carried FX observations**, append-only trigger enabled, active Cron IDs **14–19** unchanged.
- Production regression is now **50/50 PASS**. A syntax defect in the newly extended read-only regression assertion was caught before worker deployment, fixed in PR #122, and the corrected suite passed both before and after the live E2E verification.
- No Transactions, Holdings quantities, Cost Basis, Manual Overrides or portfolio-accounting rows were mutated; automatic trading remains disabled.

## 2026-11-03 targeted market-observation cleanup — Production PASS (PR #119)

- **User-authorized targeted cleanup completed:** permanently removed exactly **12,462** retired `COINGECKO / LIVE_QUOTE / THB` observations. This was a source/currency-specific legacy cleanup, **not age-based retention**.
- `fwios.market_observations` decreased **13,576 → 1,114 rows**. Postflight preserved exactly **900 CoinGecko Crypto USD**, **205 Alpha/Twelve Stock EOD USD**, and **9 Frankfurter USD/THB FX** observations.
- The migration held an exclusive lock only for the guarded delete window, disabled only the named append-only trigger, restored it before commit, and failed closed unless the target count was exactly 12,462.
- The migration snapshotted all 10 current native-USD price reads before and after and required an exact match on price, status, provider, session, observation UUID and quote kind. Current price behavior therefore remained unchanged.
- Live postflight: legacy CoinGecko THB rows **0**, append-only trigger enabled, active Cron IDs **14–19** unchanged, and migration history contains `purge_legacy_coingecko_thb_v1`.
- No age-based retention was added to canonical price history. Active-architecture price observations remain append-only and retained; any future targeted retirement requires explicit authorization plus a guarded migration.
- Relation allocation is still about **19 MB** immediately after deletion because PostgreSQL does not shrink the relation file on ordinary DELETE. No `VACUUM FULL` was introduced; free space can be reused by PostgreSQL without a blocking table rewrite.
- **Known data-model debt:** current Frankfurter USD/THB FX rows are associated with the MSFT instrument UUID as a carrier identity. Runtime filtering still reads them correctly by FX type/currency, but the identity is semantically wrong and should be normalized in a separate guarded migration before any future FX-history cleanup.

## 2026-11-03 pg_net HTTP receipt retention — BUILT-IN 6H / no custom cleanup

- **Decision:** keep Supabase/pg_net built-in response retention at the current **6 hours** and do **not** add another cleanup Cron for `net._http_response`.
- Live preflight: pg_net **0.20.4**, `pg_net.ttl = 6 hours` from the default source, response table is **UNLOGGED**, request queue is empty, and the current response window contains **6 rows / 278,528 bytes total relation size**.
- The oldest live response was about **5h48m** old and there were **0 rows older than 6 hours**, confirming the built-in worker is already pruning expired responses during normal request processing.
- Current six-response sample: **5 HTTP 2xx**, **1 HTTP 503**, **0 timeouts**, **0 pg_net error rows**. The 503 is the already-documented Alpha Vantage EOD failure receipt; current Twelve fallback and Sheet follow-up receipts are HTTP 200.
- `net._http_response` is an **ephemeral diagnostic buffer, not durable audit history**. Historical response IDs recorded in this document are production receipts observed at the time, but the live rows are expected to disappear after the pg_net TTL.
- Project `postgres` currently lacks permission to `SET pg_net.ttl`. Supabase documents that changing this parameter is a system-level operation and may require Support-granted parameter privilege plus a pg_net worker restart.
- Keep the default 6h for now because storage pressure is negligible and duplicate cleanup would add unnecessary operational complexity. If next-day incident investigation later proves 6h insufficient, prefer either a Support-approved TTL extension (for example 24h) or a separate redacted durable run-receipt design rather than modifying the pg_net system table directly.
- No Supabase schema, Cron, Edge Worker, Vault, Google Sheet, quota-ledger, canonical price history or trading behavior changed in this inspection.

## 2026-11-03 quota-ledger retention decision — RETAIN / no automatic prune

- **Decision:** `fwios_quota.api_call_ledger` is retained indefinitely for now; no scheduled DELETE/retention Cron is added.
- Live preflight found only **4 rows / 64 KiB total relation size**, all from one successful Twelve Data batch for session 2026-11-02. There are **0 unresolved calls**, **0 active cooldowns**, and no rows older than 30/90/180/365 days.
- The quota algorithm itself reads only the recent **60-second** and **24-hour** windows plus active `blocked_until`, but the table also provides durable provider-call audit evidence and enforces deterministic old-session duplicate protection through batch identity.
- Current deterministic batch IDs use `EOD_V1:<provider>:<session_date>`. Deleting old ledger rows would eventually allow an old batch identity to be reserved again, weakening that protection even though the canonical price history remains append-only.
- Measured average row size is about **168 bytes**. At four provider-call rows per normal stock session this is roughly **1,008 rows/year**; even a conservative two-provider worst case is about **2,016 rows/year** and ~0.34 MB/year of raw tuple payload before indexes. Storage pressure does not justify destructive retention now.
- Any future purge must first redesign or preserve permanent batch/idempotency evidence, then re-evaluate audit requirements. This decision does not change the 24-hour quota calculation, provider limits, credentials, price data, Cron jobs, Google Sheet accounting or trading behavior.

## 2026-11-03 operational log retention — Production PASS (PR #115)

- **30-day pg_cron retention is live.** Migration `cron_job_run_details_retention_v1` created Cron **#19 `fwios-cron-run-details-retention-v1`** at **03:15 GMT daily (10:15 Asia/Bangkok)**.
- Retention deletes only rows where `end_time < now() - interval '30 days'`. Runs with no `end_time` are retained, so active/incomplete-run diagnostics fail safe rather than being pruned.
- Production postflight immediately after migration: **109 → 109** `cron.job_run_details` rows, **0** eligible rows older than 30 days, **0** running rows, **0** rows with null `end_time`. Existing jobs **14–18 were unchanged**; active Cron inventory is now five price-service jobs plus one maintenance job.
- Preflight verified Supabase Postgres **17.6**, pg_cron **1.6.4**, cron timezone **GMT**, DELETE privilege for the migration role, and no prior cleanup/retention job. GitHub PR #115 CI passed Python contract tests, Deno typecheck, Twelve EOD guard tests and isolated PostgreSQL quota concurrency tests before merge.
- After the earlier 19,004-row cleanup, `cron.job_run_details` still had about **14.9 MB** allocated despite only 109 live tuples; autovacuum completed with **0 dead tuples**. No `VACUUM FULL` or table rewrite was added because the goal is to prevent regrowth without introducing unnecessary locking.
- This retention policy applies only to disposable pg_cron operational receipts. It **does not apply to `fwios.market_observations`** and does not change `fwios_quota.api_call_ledger`, provider credentials, Edge Functions, Google Sheet holdings/accounting, or automatic trading.

## 2026-11-03 session handoff — ready for new chat

### Completed in this session
- Production price pipeline upgraded and verified with **Alpha Vantage primary + Twelve Data EOD fallback**. PR #112 merged to `main`; current Stock EOD fallback is live and fail-closed.
- Verified live Twelve Data batch for **2026-11-02**: MSFT 507.12, NVDA 202.059998, TLN 332.98999, TTWO 192.10001 USD; Collector and Google Sheet readback both passed.
- Existing Cron jobs retained. Stock flow: Alpha at **19:00 New York**, Twelve fallback at **01:55 next New York weekday**, Sheet follow-up at **02:10**.
- Private `fwios_quota` quota ledger is active for provider-call reservation/accounting; current quota guard and concurrency tests pass.
- Legacy database cleanup completed in Production and merged via PR #113:
  - deleted **5,113** retired provider observations;
  - deleted **19,004** run-history rows from retired Cron jobs;
  - removed stale `TWELVE_DATA_QUOTE` read support;
  - dropped unused `fwios.market_observation_type_v1(text,text)`;
  - removed unused `fwios.instruments.legacy_seed_key` and its unique constraint/index.
- Current canonical state after cleanup: **3 `fwios` tables, 1 identity view, 5 `fwios` functions, 13,576 market observations, 10 current assets, 5 active Cron jobs**. Append-only observation trigger remains enabled.
- Production regression after cleanup: **48/48 PASS**. Current price reads for all 10 assets were preserved exactly through the cleanup.
- No automatic trading and no direct writes to Transactions, Cost Basis, Holdings quantities, Manual Overrides, or portfolio accounting.

### Current schemas that matter
- `fwios`: canonical instrument identity + price observations/read model.
- `fwios_quota`: operational API quota ledger.
- `cron`: current scheduled jobs and run receipts.
- `net`: pg_net HTTP dispatch/response receipts.
- `vault`: API keys and service credentials.
- Supabase-managed schemas such as `auth`, `storage`, `realtime`, `extensions`, `graphql_public`, and `supabase_migrations` are platform infrastructure and should not be treated as FWIOS legacy data.

### Recommended next task for the next chat
No immediate structural cleanup is required.
- Monitor the next natural FX Cron + Sheet sync cycle to confirm the recurring path continues writing/reading the canonical `USDTHB` identity without intervention.
- Keep the 9 MSFT-carried FX rows as immutable legacy evidence; do not rewrite or delete them merely to make history visually uniform.
- Operational retention remains settled: Cron receipts 30 days, pg_net responses 6 hours, quota ledger retained, active market history not age-pruned.
- Any future market-history retirement should remain source/semantics-specific and explicitly authorized, never age-based by default.

### New-chat starting point
Read, in order:
1. `docs/CURRENT_STATUS.md`
2. `contracts/system-contract.yaml`
3. `docs/PRICE_PIPELINE.md`
4. current GitHub `main`
5. live Supabase state before any write

The next chat should treat this section as the latest handoff unless newer production receipts are added above it.



## 2026-11-03 legacy database cleanup — Production PASS (PR #113)

- **User-authorized permanent cleanup applied:** removed **5,113** retired `fwios.market_observations` rows from providers no longer produced by the live pipeline: `TWELVE_DATA_FX` 2,572, `TWELVE_DATA_QUOTE` 2,486, `FWIOS_DAILY_CLOSE_SYNC` 40, `GOOGLE_SHEETS_MARKET_SEED` 10, `TWELVE_DATA_DAILY_CLOSE_FALLBACK` 3, `StockAnalysis` 1 and `Yahoo Finance` 1. Canonical observations decreased **18,689 → 13,576**; all 10 held instruments still retain linked price history.
- **Read-model retirement:** removed stale Stock live-quote support for `TWELVE_DATA_QUOTE` from `pr5_native_usd_price_shadow_v1`. The migration snapshot the exact price/status/provider/session/observation UUID for all 10 current assets before and after this code change and failed closed on any difference. Post-cleanup reads are unchanged: crypto remains CoinGecko and Stock remains Twelve Data/Alpha verified EOD.
- **Schema cleanup:** dropped unused `fwios.market_observation_type_v1(text,text)`; `fwios` now has **5 functions**. Removed unused `fwios.instruments.legacy_seed_key` and its unique constraint/index. `entity_id` and `metadata.retired_entity` were deliberately retained because `v_instrument_identity_current` still uses them.
- **Cron history cleanup:** deleted **19,004** `cron.job_run_details` rows belonging to retired Cron IDs. Current jobs 14–18 remain active and their **109** current run receipts are retained. Supabase documents that pg_cron does not automatically prune historical run details and recommends cleaning unnecessary rows.
- **Safety/verification:** the append-only observation trigger was disabled only inside an exclusive-lock deletion window and restored before commit. No `CASCADE`, no current Provider/API key/Cron/Edge Function changes, no Google Sheet or portfolio accounting mutation. Postflight: retired provider rows=0, retired Cron logs=0, active Cron jobs=5, legacy seed column=0, append-only trigger enabled=1. Production regression expanded and passed **48/48**.


## 2026-11-03 production E2E PASS — Twelve Data unadjusted EOD fallback + Quota Guard (PR #112)

- **Live integration:** Authenticated post-New York-midnight Twelve Data fallback ran via Cron #17 at **01:55 EST** (**13:55 Bangkok**) on 2026-11-03. pg_net response **#12017 HTTP 200**: `mode=TWELVE_STOCK_EOD_FALLBACK`, `asset_count=4`, `session_date=2026-11-02`, `provider_requests_attempted=4`, `database_writes=4`, `portfolio_writes=0`, `auto_trade=false`. Four private quota ledger rows show `TWELVE_DATA` `SUCCESS` (one per ticker) with no API key exposure.
- **Verified USD regular close for 2026-11-02:** MSFT **507.12**, NVDA **202.059998**, TLN **332.98999**, TTWO **192.10001**. Source `TWELVE_DATA`, Tier A, `REGULAR_CLOSE`, USD, `market_status=CLOSED`, `provenance_status=PASS`. All four quotes match the requested NY session; validated unadjusted via `adjust=none`.
- **Immutable provenance compatibility fix:** In the first live collector deployment, four `raw_payload` values were JSONB **string scalars** due to accidental double serialization. Price values and row identity were correct, but plain `raw_payload->>` filters could not certify them. **Do not modify/delete these append-only observation rows.** Both Collector and Sheet Sync now decode only on read using `CASE WHEN jsonb_typeof(raw_payload)='string' THEN (raw_payload #>> '{}')::jsonb ELSE raw_payload END`, and still require exact provider, source tier, session, close kind and adjustment. The updated Collector writes future EOD metadata using SQL `jsonb_build_object` to ensure typed JSONB objects. This fix is live in Market Worker **v12** and Sheet Worker **v6**.
- **Google Sheet end-to-end:** Cron #18 fired at **02:10 EST** (**14:10 Bangkok**). pg_net **#12018 HTTP 200**, `stock_count=4`, `crypto_count=6`, `asset_count=10`, `sheet_write_readback_verified=true`, `database_writes=0`. Live `Investment Portfolio Tracker - Chumponphat` `_Market_Data` readback verified exactly the four prices, `provider=TWELVE_DATA`, `status=LAST_CLOSE`, 2026-11-02 session and canonical observation UUIDs; `Price Data` audit notes also show Twelve Data and 2026-11-02. Open Holdings quantities unchanged; calculated USD/THB values and P&L updated by existing formulas as intended.
- **Recurring schedule:** Existing **5** active Cron jobs retained. Cron #17 invokes Alpha Vantage at 19:00 New York weekdays and Twelve Data fallback at **01:55 on next New York weekday** only if the intended EOD session is not already certified. Cron #18 runs Sheet follow-ups at 19:30 and **02:10** New York weekdays. New York wall-clock guards protect daylight savings. Saturday/Sunday runs are skipped; a Friday close is eligible for Twelve historical EOD on the following Monday at 01:55 New York time.
- **Safety:** Private `fwios_quota.api_call_ledger` separate from the three canonical price tables; 4 provider successes in this batch, atomic reservation and no concurrent duplicate dispatch; fail closed for incomplete/mixed or wrong-session EOD. No Trades, Transactions, Cost Basis, Holdings quantities, or Portfolio Accounting data writes by Collector or Sync, `auto_trade=false`. GitHub CI Python contracts, 8 fixture-based Deno EOD tests, 5 PostgreSQL quota/concurrency integration tests and Deno typecheck passed. Production SQL regression using fallback-aware Cron assertions **44/44 PASS**.
- **Remaining issue:** Alpha Vantage's shared key still has an unresolved daily-limit classification (Issue #106); this does **not** prevent verified Twelve Data fallback now. Continue monitoring provider quota, future sessions and missed Cron/Sheet runs. The old standalone no-write probe was blocked, but an **authorized actual live read/write Price-only EOD run** now independently proves Twelve key entitlement and bar response.

## Historical receipts below (superseded by the verified E2E status above)

## 2026-11-03 production fix — provider diagnostics and STALE stock Sheet metadata (PR #111)

- **Code and deployment:** PR #111 merged, GitHub CI Python contract tests and Deno typecheck PASS. Live `price-market-refresh-v1` **v8** and `price-sheet-sync-v1` **v4**, runtime source matches `main`; 2 Edge workers only, 5 Crons still active. No migration, schema/cron/legacy/backend/trading changes.
- **Provider diagnosis (actual post-close retry):** After quota-free preflights HTTP 200 (#12013 collector with `provider_requests_attempted=0`; #12014 sync with `stale_status_candidates=4`), a single controlled real US EOD retry returned **HTTP 503** (#12015) `ALPHA_VANTAGE_DAILY_RATE_LIMIT_SYMBOL_NVDA_ATTEMPT_2`. The MSFT response passed source validation, but NVDA (second provider attempt) rejected; **zero** new Stock EOD records committed because the existing 4-of-4 atomic write remains intact. This confirms provider-side daily-limit-classified response, not who else used the key. The parser now distinguishes daily/frequency, key/plan, non-JSON and unexpected response shape with safe error codes; it does not reveal the API key, URL, or raw payload.
- **Google Sheet metadata reconciliation:** Worker #12016 **HTTP 200** `stale_status_updated=4`, `stock_count=0`, `sheet_write_readback_verified=true`. `_Market_Data!F6,F7,F9,F10` changed **LAST_CLOSE → STALE** only, after verified observation ID/provider/type/price lineage. `Price Data` audit messages now show **STALE** for MSFT/NVDA/TLN/TTWO (all 2026-10-28). Price USD `_Market_Data!D`, observation IDs `I`, valuation eligibility `O` and `Price Data` numeric prices unchanged. **Column O remains true intentionally to avoid altering existing Portfolio valuation formulas**; this is a visual status correction, not a valuation eligibility cutover.
- **Postflight:** held Stock quantities and numeric P&L snapshot matched baseline, Crypto 6/6 `FRESH`, USDTHB **33.76**, 10 instruments, 18,685 observations, 5 active Crons, append-only guard enabled, SQL regression **44/44 PASS**, and **0** certified Stock EOD observations for 2026-11-02. No changes to Transactions, Cost Basis, Holdings or Portfolio Accounting.
- **Open blocker (#106):** Provider key still hits a daily limit at the second request during a 4-symbol run; shared key usage external to current Worker remains unmeasured. Do not claim US Stock EOD E2E PASS until genuine HTTP 200 collector `database_writes=4`, session-matched certified close rows 4/4, and follow-up HTTP 200 Sheet `stock_count=4`. Consider dedicated API key/account plan only after provider-side usage/entitlement investigation; no automatic repeated retries.


## 2026-10-31 production remediation — EOD API quota protection (PR #110)

- **Root operational blocker remains:** first natural held-US-stock Cron #17 at 2026-10-30 19:00 America/New_York dispatched, but **actual** `net._http_response` #12000 was HTTP **503** with `ALPHA_VANTAGE_DAILY_RATE_LIMIT`. Cron #18 at 19:30 ET returned HTTP **200** (#12001) but `stock_count=0` — **US Stock EOD E2E FAIL**, despite successful dispatch and crypto sync.
- **Fix merged & deployed:** PR #110 merged to `main`, `price-market-refresh-v1` **v5** deployed 2026-10-31 Asia/Bangkok. When the exact current NY session already has certified `price_only_stock_eod` closes for all OPEN-held stock symbols, skip Alpha Vantage entirely; any partial certified set fails closed with zero requests; `US_STOCK_EOD dry_run=true` is now a **quota-free structural preflight** and cannot prove provider availability. HTTP 429 is explicitly sanitized as `ALPHA_VANTAGE_RATE_LIMIT`.
- **Safe production smoke:** `net._http_response` #12002 HTTP **200** `US_MARKET_WEEKEND`, `database_writes=0`, `portfolio_writes=0`, `auto_trade=false`; this did **not** query Alpha Vantage. GitHub CI Python contract tests + Deno typecheck **PASS**; post-deploy SQL regression **44/44 PASS**.
- **Postflight:** 10 instruments, 10 symbol mappings, **18,666** market observations, append-only trigger enabled, all five Crons active, only two Edge workers. Google Sheet `_Market_Data` and `Price Data` still preserve old Stock session **2026-10-28** for MSFT/NVDA/TLN/TTWO; latest USDTHB **33.73**, Holdings OPEN stocks intact, no portfolio accounting writes or Sheet modifications by this remediation.
- **Unresolved external dependency:** Alpha Vantage free key limits 25/day **shared across callers**. Current credentials were already present since 2026-09-11; FWIOS only has one scheduled stock EOD collector daily and cannot infer external key usage or reset a provider quota. A fresh dedicated/key-plan with sufficient quota may be necessary (store only in Vault; never include key in repo/logs). Do not claim EOD success until a real eligible market session returns Collector HTTP 200, `database_writes=4`, 4 current-session certified observations and Sheet Sync HTTP 200 with `stock_count=4`. Next expected US session 2026-11-02; post-DST Bangkok times 2026-11-03 **07:00 collector / 07:30 sync**. Issue #106 remains open.


**Latest 2026-10-30 cleanup receipt:** User authorized permanent deletion of 60 US Stock identities not OPEN-held in Google Sheet and their **1,789** associated price observations. Migration `purge_unheld_60_us_stocks_and_observations_v1` completed in a transaction; stock/crypto remaining: **4/6** (10 instrument identities, 10 symbol mappings). 20,441 observations before deletion; 18,652 after deletion (18,659 after live E2E refresh). Original append-only trigger re-enabled. Updated SQL test **44/44 PASS**. Crypto+FX write and Google Sheet readback E2E HTTP 200. All 16 deprecated Edge deployments already removed from Supabase by user, verified only two price workers. This historical purge is permanent and no backup of deleted rows was produced by the migration.



Verified 2026-10-30 Asia/Bangkok. **Two Price Edge Workers**, three core `fwios` tables, one identity view, six SQL functions, five active Cron registrations. The old 87-table archive was permanently deleted on user instruction without backup. All 16 retired Edge deployments were deleted manually by the user; live Supabase inventory confirms only the two supported price workers remain.

## Supported scope

CoinGecko native USD Crypto, Alpha Vantage unadjusted US Stock regular close for holdings listed OPEN in Google Sheet (MSFT, NVDA, TLN, TTWO), and Frankfurter USD/THB FX. Prices persist in `fwios.market_observations` and update the Investment Portfolio Tracker `_Market_Data`. Google Sheet alone owns Transactions, Holdings quantities, cost basis, manual overrides and portfolio computations. No scanner, research, valuation, portfolio accounting backend or trading; `auto_trade=false`.

## Deployed workers

- `price-market-refresh-v1` v5 (PR #110): CRYPTO / FX / US_STOCK_EOD collection; USD provider close date must match current New York market session. Nonpositive, stale, mixed or unknown quotes fail closed. Key remains in Supabase Vault.
- `price-sheet-sync-v1` v3: six Crypto rows + FX, and Stock EOD rows **only** when the new observation has certified `price_only_stock_eod` provenance. Old unverified stock rows are protected.

## Active schedules (New York local time; daylight-saving safe)

| Job | Time | Purpose |
| --- | --- | --- |
| #14 | 17:10 daily | Crypto collection |
| #15 | 17:10 weekdays | FX |
| #16 | 17:20 daily | Existing Crypto/FX Sheet sync |
| #17 | 19:00 weekdays | New US Stock EOD collector |
| #18 | 19:30 weekdays | New follow-up Sheet sync |

The EOD job runs 06:00 or 07:00 next morning Bangkok; Sheet follow-up 06:30 or 07:30 depending on US daylight saving. On weekends or US market holidays the collector does not invent a quote.

## Verification and current blocker

- Both workers deployed, jobs #17/#18 active; **first natural 2026-10-30 EOD run failed provider quota (actual HTTP 503 #12000); Sheet follow-up HTTP 200 #12001 but stock_count=0**. See the 2026-10-31 remediation status above.
- Existing Crypto/FX collector dry runs passed HTTP 200 (#11982/#11983). Sheet Worker dry run passed HTTP 200, `crypto_count=6` and `stock_count=0` (#11985).
- Real Sheet Sync after deploy passed HTTP 200 (#11986), six Crypto prices updated, Google Sheet write/readback verified, no portfolio writes. Four historic Stock rows remained unchanged (last close dated 2026-10-28).
- **US Stock EOD is not yet confirmed operational.** The current Alpha Vantage key returned daily quota rejection `ALPHA_VANTAGE_DAILY_RATE_LIMIT` (HTTP 503, #11984). No new Stock observations were inserted. Scheduled job #17 will attempt the next eligible session; success depends on restored shared API quota and current-session source data. Do not claim US stock prices are updating until a full EOD + Sheet cycle returns HTTP 200 and four certified stock rows have refreshed.
- After schedule activation, read-only SQL regression **29/29 PASS**. Supabase security remains fail-closed.

Source: PR #105. To verify post-close run: check `cron.job_run_details` and actual `net._http_response` status for #17/#18, `fwios.market_observations` current session `REGULAR_CLOSE` for all held Stock symbols, and Sheet readback. Cron 'succeeded' alone only indicates dispatch.

## 2026-10-30 permanent three-table price identity cleanup — applied and verified

Applied `reduce_price_identity_to_three_tables_v1` to live Supabase after preflight comparison of the original view and proposed source projection **70/70 matching identities**. `fwios.asset_entities` and `fwios.instrument_identifiers` were retired using RESTRICT after copying all 70 entity records to `fwios.instruments.metadata.retired_entity` and updating the sole identity view. The original `instrument_id`, `instrument_symbols` mappings, `instruments.entity_id` provenance UUIDs, all observation rows and all six price SQL functions are retained. Supabase price schema now has **3 tables** (`instruments`, `instrument_symbols`, `market_observations`) plus **1 view, 6 SQL functions, 5 scheduled Cron jobs**.

Read-only postflight: 70 instrument identities and symbol mappings preserved, **20,434 pre-refresh market observations** preserved with 70 distinct linked instruments, and exact sample name and instrument UUID checks for BTC/ETH/XRP/MSFT/NVDA/TLN/TTWO. Production price-only SQL regression updated to the three-table schema: **36/36 PASS**.

Post-migration direct E2E: `price-market-refresh-v1` CRYPTO (request 11989) HTTP **200**, 6 new live USD Crypto observation writes and zero portfolio writes; FX (11990) HTTP **200**, 1 Frankfurter USD/THB observation and zero portfolio writes. `price-sheet-sync-v1` (11991) HTTP **200**, six Crypto quotes plus shared USD/THB FX written to `_Market_Data`, **write/readback verified**, `stock_count=0`, no database or portfolio writes. Historic unverified Stock rows remain protected. This confirms active core pipeline works with only three SQL tables.

**US Stock EOD provider issue is independent and still open:** The last verified Alpha Vantage dry-run was rate-limited. The scheduled stock job remains registered; no new successful US stock EOD quote was confirmed by this cleanup. Issue #106 tracks EOD provider completion. All 16 inactive Edge deployments were removed by the user and verified absent from Supabase.
