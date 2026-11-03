# Price Pipeline v1.1.0 — held US Stock EOD + Crypto + USD/THB FX

## Current live architecture (verified 2026-11-03)

### Legacy cleanup receipt — 2026-11-03

The live Stock price read model is now **EOD-only**: verified `TWELVE_DATA` / `ALPHA_VANTAGE_PRICE` `REGULAR_CLOSE` rows. Historical `TWELVE_DATA_QUOTE` live-quote support was retired and its rows were permanently removed with the other retired providers. The cleanup deleted **5,113** retired provider observations and **19,004** run-history rows from retired Cron IDs while preserving the 10 current asset price reads exactly. `fwios.market_observation_type_v1` and `instruments.legacy_seed_key` were also removed. Current schema remains 3 canonical price tables, 1 identity view and now **5** `fwios` functions; `fwios_quota` remains separate and unchanged.


Google Sheet OPEN Holdings → Alpha Vantage `TIME_SERIES_DAILY` EOD 19:00 ET → **Twelve Data `/time_series?interval=1day&adjust=none` fallback 01:55 ET on next NY weekday if no certified EOD** → atomic 4/4 `fwios.market_observations` → Google Sheet `_Market_Data` via Sheet Worker at 19:30 ET / 02:10 ET → existing Price Data and Holdings formulas. The fallback is **live**. On 2026-11-03 Twelve Data returned 2026-11-02 closes for MSFT/NVDA/TLN/TTWO; Collector HTTP 200 `database_writes=4` (#12017) and Sheet HTTP 200 `stock_count=4`, `sheet_write_readback_verified=true` (#12018). Crypto CoinGecko and FX Frankfurter routines unchanged.

The private `fwios_quota.api_call_ledger` reserves each provider's full stock batch atomically before HTTP. The first live Twelve run used 4 calls and all ended `SUCCESS`. The existing five **price-service** Cron jobs (#14–#18) are retained unchanged; Cron **#19** is a separate operational-maintenance job that prunes completed `cron.job_run_details` older than 30 days. No automatic trading or portfolio accounting writes. The latest Source of Truth is `docs/CURRENT_STATUS.md` (not the historical deployment notes below).

**Production provenance compatibility note:** Four initial 2026-11-02 Twelve EOD observations have `raw_payload` encoded as a JSONB string scalar by a bug in the first collector version. Their prices, provider, session and identity are valid. Do not mutate append-only observation history. Both Collector and Sheet Sync read and validate these via strict read-only JSONB normalization; future EOD rows use native `jsonb_build_object` metadata. See tests and status receipt for details.


```text
Google Sheet Holdings (OPEN positions; read only)
  ├─ Crypto BTC/DOGE/ETH/HBAR/SOL/XRP → CoinGecko native USD
  ├─ US Stock MSFT/NVDA/TLN/TTWO → Alpha Vantage TIME_SERIES_DAILY raw 4.close
  └─ FX USD/THB → Frankfurter
           ↓
   fwios.market_observations
           ↓
   price-sheet-sync-v1
           ↓
   Google Sheet _Market_Data → Price Data → Holdings
```

Google Sheet owns transaction ledger, holdings, cost basis and calculations. No Stock Scanner, company research, valuations, decisions or trades. `auto_trade=false`.

## US stock close contract

US session regular close is 16:00 America/New_York (13:00 on designated half-days). Fetch current **unadjusted** EOD close, no live/after-hours or adjusted-close substitution. Alpha Vantage `TIME_SERIES_DAILY` returns session dates and `4. close`. Keep the provider key private in Supabase Vault; stored `source_url` deliberately has **no API key**.

At 19:00 US Eastern on weekdays (DST protected, 06:00/07:00 next day Bangkok), collector reads Sheet Holdings and fetches EOD for unique OPEN Stock tickers, currently MSFT/NVDA/TLN/TTWO. Reject invalid key, bad source identity, nonpositive prices, missing close, mixed sessions; when the current NY session is not available (holiday/slow publication), **skip without writing**, never mislabel a previous day's close as current. All observations persist atomically through `fwios.ensure_market_observation_v1` as `REGULAR_CLOSE`, USD, `ALPHA_VANTAGE_PRICE`, `source_tier='A'`, `market_status='CLOSED'`, and provenance `price_only_stock_eod=true`. `observed_at` is the real collection time, not an invented 16:00 exchange timestamp. Duplicate reruns are idempotent on observation key.

19:30 New York weekday Sheet follow-up syncs ONLY EOD rows bearing that collector provenance and eligible native USD close status; if no certified new stock observation exists, preserve frozen Stock rows. Crypto+FX sync (#16) remains daily at 17:20 Eastern. Keep existing per-row USD/THB formula and readback. Never clear ranges or touch Transactions, cost basis or manual overrides.

**Potential provider limits:** Alpha Vantage lists 25 free requests/day; four held stocks require four API calls per run. Any unrelated use of the same Vault API key contributes to that shared allowance. Additional held symbols must honor the 15-symbol cap or use a different appropriately licensed plan.

## Existing schedules

- Cron #14 Crypto (17:10 ET); #15 FX (17:10 ET, weekdays); #16 Sheet Sync (17:20 ET).
- New Stock EOD and follow-up Sheet jobs were **installed live** as Cron #17 and #18 via `20261030120000_schedule_held_us_stock_eod_v1.sql` on 2026-10-30. The source-validation gate was passed, but Alpha Vantage quota has not yet allowed a successful same-session price response.
- Operational maintenance Cron #19 runs at **03:15 GMT daily (10:15 Bangkok)** and deletes only `cron.job_run_details` rows whose `end_time` is older than 30 days. It is not part of the price collection/sync flow.
- Run a real post-close EOD test and verify the date, symbols, canonical observations, Google Sheet readback and formula integrity before certifying production.

## Security and retention

The live Price Service retains 3 `fwios` tables, 1 identity view and 5 `fwios` functions. Legacy archive was user-deleted with no backup; do not try to resurrect legacy SQL or 16 retired Edge endpoints (HTTP 410). Provider credentials and server-to-server auth token remain in Vault. Only two active Edge Worker source directories are allowed.

`cron.job_run_details` is operational logging, not canonical price history. Production Cron #19 (`fwios-cron-run-details-retention-v1`) runs daily at 03:15 GMT and keeps approximately 30 days by deleting only rows with `end_time` older than 30 days; null `end_time` rows are intentionally retained. This policy must never be applied to `fwios.market_observations`.

`fwios.market_observations` is **not age-pruned**, but explicitly retired legacy source/currency data may be removed by a separately authorized, guarded migration. On 2026-11-03 the obsolete `COINGECKO / LIVE_QUOTE / THB` set was removed exactly: **12,462 rows**, reducing the table from **13,576 to 1,114 rows** while preserving 900 active CoinGecko USD rows, 205 active Stock EOD rows and 9 active Frankfurter FX rows. All 10 current native-USD reads were required to match before/after exactly. This does not create a general retention rule.

Known FX identity debt: the current Frankfurter USD/THB observations use the MSFT instrument UUID as a carrier identity inherited from the earlier model. Runtime reads remain correct because the FX path filters by observation type and USD/THB currencies, but the identity is semantically incorrect. Do not remove the current FX history until a dedicated FX identity/read-path migration is designed and verified.

`fwios_quota.api_call_ledger` has a separate policy: **retain indefinitely / no automatic prune**. Although quota calculations use only 60-second and rolling-24-hour windows, the ledger also preserves provider-call audit evidence and deterministic batch identity (`EOD_V1:<provider>:<session_date>`). Removing old rows would weaken old-session duplicate-batch protection. Live sizing on 2026-11-03 was only 4 rows / 64 KiB; projected growth is roughly 1,008 rows per 252-session year for one four-symbol provider batch, or about 2,016 rows/year in a conservative two-provider case. Any future purge requires an idempotency-preserving redesign first.

`net._http_response` uses **pg_net built-in retention**, not a project cleanup job. Live pg_net 0.20.4 reports `pg_net.ttl = 6 hours` from the default config; the table is UNLOGGED and current rows are being pruned within that window. Treat these responses as short-lived debugging evidence only: response IDs documented in production receipts are not expected to remain queryable indefinitely. Do not `DELETE`, `TRUNCATE`, add triggers to, or otherwise repurpose the pg_net system response table. The project role currently cannot change `pg_net.ttl`; if a longer diagnostic window is ever needed, use the supported system-parameter path and worker restart rather than a custom retention Cron.

## 2026-10-30 production deployment receipt

`price-market-refresh-v1` **v4** deployed with US_STOCK_EOD; `price-sheet-sync-v1` **v3** deployed with stock-only-if-certified safeguards. Five active Cron jobs: #14/#15/#16 existing and **#17 at 19:00 New York weekdays** / **#18 at 19:30 NY weekdays** newly added.

Authenticated Crypto+FX dry runs HTTP 200. Sheet Worker dry-run HTTP 200 with 6 Crypto, 0 certified Stock. Real Sheet Sync HTTP 200 (#11986), Crypto updated, readback verified, four old Stock quotes untouched. SQL regression **29/29 PASS**.

**Unresolved provider gate:** Alpha Vantage returned HTTP 503 / `ALPHA_VANTAGE_DAILY_RATE_LIMIT` (#11984). No new US Stock observation has yet been written. Existing 2026-10-28 Stock close prices remain until the first successful daily EOD. Automatic schedule will attempt the next eligible market session, but success is unverified. Provider quota is shared with any other Alpha Vantage use of the Vault key.

## Three-table price identity simplification (2026-10-30)

Production keeps only `fwios.instruments`, `fwios.instrument_symbols` and `fwios.market_observations`, with the existing `fwios.v_instrument_identity_current` view and six SQL price functions. The unnecessary legacy identifier table and separate asset entity table were retired via migration `20261030140000_reduce_price_identity_to_three_tables_v1.sql`. Entity metadata for all 70 existing identities was preserved under `instruments.metadata.retired_entity`; historical `entity_id` and canonical `instrument_id` UUIDs were not rekeyed. The legacy seed-only identifier records were intentionally retired. No scanner/portfolio tables were revived.

Post-migration 36/36 SQL assertions PASS. Crypto (6 USD writes), USD/THB FX (1 write) and Google Sheet `_Market_Data` end-to-end price readback all returned HTTP 200 (11989–11991), with zero Supabase portfolio writes. The separate US Stock EOD API provider quota issue remains unresolved; stock prices must not be claimed refreshed without an actual successful market-session result.

## Permanent removal of unheld stock identities — 2026-10-30

The authoritative Investment Portfolio Tracker Google Sheet `Holdings` was read live before deletion. Exactly **MSFT, NVDA, TLN, TTWO** remain OPEN-held Stock symbols; BTC/DOGE/ETH/HBAR/SOL/XRP remain OPEN-held Crypto symbols. The user explicitly authorized deleting all **60 other Stock instruments** and their **1,789 historic market observation rows**. Migration `20261030160000_purge_unheld_60_us_stocks_and_observations_v1.sql` validates the expected source universe and row counts, disables the named append-only guard only within the transaction, deletes prices/symbols/instruments in dependency order, re-enables the guard and verifies all ten retained instrument identities, symbols, price links, and unchanged five Cron jobs. A failure aborts the entire transaction. No deleted price-row backup was made by the migration.

**Actual result:** 70 → 10 instruments and symbols; 20,441 → 18,652 price observations at commit, with 1,789 stock price observations permanently deleted. Post-cleanup Crypto/FX collection appended seven genuine observations (18,659 rows), and Google Sheet `_Market_Data` actual sync returned 200 with readback PASS. Four retained historical Stock quote rows were unchanged. Production SQL suite **44/44 PASS**. Old 16 Edge functions were already removed by the user; only the two price workers remain.

**Important for future new holdings:** the collector does not automatically create new instrument identities. If the user buys a stock absent from the surviving ten, register its canonical `instruments` and `instrument_symbols` entries safely before expecting price collection, or the worker will fail closed. This cleanup does not provide an automatic asset registration pathway.

The US Stock EOD Alpha Vantage daily quota blocker is unrelated; do not claim a new Stock EOD price was successfully ingested yet.


## Twelve Data EOD fallback — PR #112 (LIVE, 2026-11-03)

**This section documents the active fail-closed behavior and historical release steps.**

### Intended behavior
- Current `US_STOCK_EOD` (Alpha Vantage) remains at 19:00 New York business-day time; the existing Atomic 4/4 USD closing-price validation and no-stale-backdating remain mandatory.
- If not yet certified, `TWELVE_STOCK_EOD_FALLBACK` checks on the **next New York business day at 01:55 ET**, only after historical daily bars are expected to be published. For **Friday's** close this means **Monday at 01:55 ET**, not Saturday; Twelve Data explicitly describes availability on the next trading day. The date must be the previous New York weekday and must actually occur in the provider response. If a US market holiday means no bar for that target, **fail closed**; the current implementation does not invent a holiday calendar.
- Provider Twelve Data `/time_series` uses `interval=1day`, `adjust=none`, currency USD, New York exchange timezone, latest unique session date and positive close. `parseTwelveDailyEod` validates this **inside** the provider-call receipt before it can be marked `SUCCESS` in the quota ledger. Neither parsed bar nor previous-session data is accepted without exact session match.
- Price observation provenance uses `TWELVE_DATA`, source tier A, `REGULAR_CLOSE`, USD, `price_only_stock_eod=true`, `adjustment=none`, `close_kind=UNADJUSTED`. The Alpha/Twelve certified-observation guards check these markers, and Sheet Sync admits only strict provider/adjustment-specific certified observations. Existing crypto, FX, price formulas, and portfolio accounting must remain unchanged.

### Private operational quota
- `fwios_quota.api_call_ledger` and 4 SQL functions are already installed **but inert** in Production until the Price Worker is deployed with the new code. These are operational objects outside the 3 canonical `fwios` price tables. `anon`/`authenticated` cannot use the schema, and `service_role` cannot query the ledger.
- Rolling 24h internal budget: Alpha 20 requests, Twelve 700 credits (conservative; external provider account usage is **unknown**). Minute batch checks: Alpha 4; Twelve 6. This is a local budget, **not** the provider's confirmed remaining credits.
- Entire held-stock batch is reserved atomically before the first provider request. Only definitely `RESERVED` but not dispatched rows may be canceled. `DISPATCHED`, timeout `UNKNOWN`, rejected and completed requests conservatively consume the local budget.
- A batch key is unique per provider and NY session; duplicate runs fail closed. An incomplete batch is not automatically retried under the same key. Do not bypass this by changing request IDs.

### Manual no-write provider entitlement check

The repository includes `tests/price/manual_twelve_provider_probe.ts`. This is an **opt-in operator tool**, **not** part of CI, Cron or the deployed Edge runtime. It only makes up to four read-only Twelve Data HTTP calls; it does **not** write Supabase, GitHub or Google Sheets. It will run only during 01:15–01:59 on a New York weekday, targeting the previous US weekday's EOD. For a Friday close, this is normally Monday at 01:55 ET. All four must pass exact session, symbol, USD and timezone checks.

Set `TWELVE_DATA_API_KEY` securely in a local process environment (do not paste it into chat, code, GitHub or shell history), then run:

```bash
deno run --allow-env=TWELVE_DATA_API_KEY --allow-net=api.twelvedata.com \
  tests/price/manual_twelve_provider_probe.ts
```

Expected safe output: `mode=READ_ONLY_MANUAL_NO_DATABASE_WRITES`, `all_valid=true`, `attempted=4`, one verified `VALID_EOD` per stock, plus numeric provider credit headers when supplied. The probe prints **no key, raw response or full request URL**. It intentionally stops on the first rejection or validation failure. This consumes up to four credits; do not loop or schedule the probe. **The agent has not run this script against the user's API key.** The command only typechecks as part of CI. Delete the locally set environment variable after finishing.

### Release evidence and operational rollback checklist
1. **Verified live:** The authenticated 2026-11-03 production Twelve EOD run validated all four symbols, USD currency, New York exchange timezone, `adjust=none`, and same 2026-11-02 session. Provider/key entitlement is proven by this successful batch; a separate no-write probe is optional. Never record the API key or query string.
2. **Verified in GitHub CI:** Python contracts, Deno typecheck, 8 Deno fixture cases, and `tests/price/quota_postgres_integration.py` against a disposable PostgreSQL 16 service. Concurrent independent DB sessions verified a single winner for the same batch; separate batches cannot both reserve 4 slots against the same 4-request minute budget. Also tested cancellation of exactly never-dispatched slots, unreleased dispatched calls and private access. Production rollback SQL smoke previously passed. These tests use no provider requests.
3. Confirm Supabase `fwios_quota` permissions and availability (1 table, 4 functions), and original source/cron drift expectations.
4. Deploy only the current two Edge Workers **with every imported source file**. The Market Collector deployment must upload `index.ts`, **`twelve-eod-guards.ts`**, and `deno.json`; Sheet Sync must upload `index.ts` and `deno.json`. Keep the existing server-side automation-token authentication.
5. With no provider traffic, test both `US_STOCK_EOD` and `TWELVE_STOCK_EOD_FALLBACK` in `dry_run=true` at an eligible New York window. Expected `provider_requests_attempted=0`, `database_writes=0` and `fwios_quota.api_call_ledger` unchanged.
6. **Applied:** The guarded `20261103103000_schedule_twelve_eod_fallback_v1.sql` migration **altered existing Cron IDs 17 and 18** rather than creating new jobs. Ensure New York time guards invoke Alpha at 19:00 and Twelve at 01:55, and follow-up Sheet Sync at 19:30 and 02:10, with DST correctness.
7. **Accepted 2026-11-03:** Provider returned all 4 **same-session** closes, Collector atomically created 4 EOD observations, and price-sheet-sync-v1 returned `stock_count=4` with exact readback. Regression remains 44/44 PASS; Holdings quantities, Transactions, Cost Basis, manual overrides, and account valuations must not change except as a direct consequence of verified new prices.

### Rollback
If deployment or certification fails, restore the original Worker sources from the tracked `main` reference preceding PR #112 and the prior Cron #17/#18 schedule/command snapshot. Leave the operational quota ledger **inert** and retained for audit; never hard-delete price history, mutate portfolio accounting, or claim provider availability without verification. Keep Issue #106 OPEN until EOD E2E PASS.
