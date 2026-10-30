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

The live Price Service retains 5 `fwios` tables, 1 view and 6 required routines. Legacy archive was user-deleted with no backup; do not try to resurrect legacy SQL or 16 retired Edge endpoints (HTTP 410). Provider credentials and server-to-server auth token remain in Vault. Only two active Edge Worker source directories are allowed.

## 2026-10-30 production deployment receipt

`price-market-refresh-v1` **v4** deployed with US_STOCK_EOD; `price-sheet-sync-v1` **v3** deployed with stock-only-if-certified safeguards. Five active Cron jobs: #14/#15/#16 existing and **#17 at 19:00 New York weekdays** / **#18 at 19:30 NY weekdays** newly added.

Authenticated Crypto+FX dry runs HTTP 200. Sheet Worker dry-run HTTP 200 with 6 Crypto, 0 certified Stock. Real Sheet Sync HTTP 200 (#11986), Crypto updated, readback verified, four old Stock quotes untouched. SQL regression **29/29 PASS**.

**Unresolved provider gate:** Alpha Vantage returned HTTP 503 / `ALPHA_VANTAGE_DAILY_RATE_LIMIT` (#11984). No new US Stock observation has yet been written. Existing 2026-10-28 Stock close prices remain until the first successful daily EOD. Automatic schedule will attempt the next eligible market session, but success is unverified. Provider quota is shared with any other Alpha Vantage use of the Vault key.
