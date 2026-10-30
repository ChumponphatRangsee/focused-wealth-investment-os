# Price Pipeline v1.1.0 — held US Stock EOD + Crypto + USD/THB FX

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
- Run a real post-close EOD test and verify the date, symbols, canonical observations, Google Sheet readback and formula integrity before certifying production.

## Security and retention

The live Price Service retains 3 `fwios` tables, 1 view and 6 required routines. Legacy archive was user-deleted with no backup; do not try to resurrect legacy SQL or 16 retired Edge endpoints (HTTP 410). Provider credentials and server-to-server auth token remain in Vault. Only two active Edge Worker source directories are allowed.

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
