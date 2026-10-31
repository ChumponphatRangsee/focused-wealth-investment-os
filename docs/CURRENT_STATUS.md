# Current Production Status — Asset Price Data Service v1.1.0

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
