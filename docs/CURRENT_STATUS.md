# Current Production Status — Asset Price Data Service v1.1.0


## 2026-11-03 Twelve Data EOD fallback + private quota ledger — PR #112 (DRAFT, not activated)

- **Production activation status:** NOT YET LIVE. GitHub draft PR #112 contains quota-gated Alpha/Twelve collector code, certified Twelve Sheet readback support, and an optional existing-Cron (#17/#18) schedule migration. None of the new collector or Sheet Worker code, fallback modes, or Cron scheduling changes have been deployed. Current Production Market Worker **v10** source equals existing `main` (no Twelve probe mode); Sheet Worker **v4** remains unchanged. A prior temporary no-write probe invocation was denied before it reached Twelve Data, so the live key/plan/response semantics **remain unverified**.
- **Operational quota schema staged in Production:** Applied migration `price_provider_quota_ledger_v1` in dedicated **private** `fwios_quota` schema (1 table, 4 functions), separate from the three `fwios` core price tables. This is **inert until workers opt in**. No exposed anon/authenticated schema usage, no service_role table read; no raw provider keys stored. An isolated PL/pgSQL exception-subtransaction test validated atomic 4-slot reservation, duplicate rejection, minute budget refusal, provider dispatch/result recording, daily cooldown, and cancellation of precisely 3 never-dispatched slots, with automatic rollback; ledger row count remained **0**, five Crons still active and no certified EOD rows added. No Holdings/Transactions/Cost Basis/Portfolio Accounting changes.
- **Open release gates:** Twelve Data 4-stock no-write live entitlement confirmation (`adjust=none`, USD, `America/New_York`, exact trading session), concurrent-invocation tests, post-midnight fallback dry-run with zero provider calls, CI, a controlled real 4/4 EOD plus Google Sheet certification. Twelve Data historical EOD begins only after midnight ET on the next trading day; do **not** use 19:00 ET Twelve fallback. The existing Cron schedule should not be changed until all gates pass. Existing Issue #106 remains open.


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
