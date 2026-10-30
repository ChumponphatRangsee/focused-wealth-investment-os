# Asset Price Data Service — v1.1.0 (US Stock EOD Extension)

**Scope:** Daily CoinGecko native USD Crypto, **US Stock regular-session unadjusted closing prices** (Alpha Vantage `TIME_SERIES_DAILY`, held symbols from Google Sheet only), Frankfurter USD/THB FX → Supabase `fwios.market_observations` → Google Sheet `_Market_Data`. The Sheet remains authoritative for transactions, holdings, cost basis, manual overrides and portfolio calculations. No research, scanner, valuation, automatic trading or stock discovery; `auto_trade=false`.

## Workers
- `price-market-refresh-v1`: CRYPTO, FX and new US_STOCK_EOD collection; validates close-date and source credentials, saves the four currently held US Stocks without synthetic quote timestamps or adjusted prices.
- `price-sheet-sync-v1`: writes six Crypto symbols, certified new stock closing prices and FX metadata; refuses to overwrite unverified historic Stock rows, checks price/formula readback.
- Existing three Crons #14 Crypto, #15 FX and #16 Crypto/FX Sheet Sync remain. The proposed new schedules are **19:00 New York time** for US EOD and **19:30** for stock Sheet Sync, weekdays, with timezone/DST guards. See SQL migration `20261030120000_schedule_held_us_stock_eod_v1.sql`.

**Deployment note:** Code and migration may be merged separately from live deployment. Until Stock EOD provider validation and schedule activation are explicitly confirmed in `docs/CURRENT_STATUS.md`, do not claim stock price refresh is live.

Current holdings observed in Sheet: MSFT, NVDA, TLN and TTWO, plus six Crypto symbols. Pre-extension historical US stock rows in Sheet reflect the 2026-10-28 close; never recast them as a new session.

Database: five `fwios` tables, one identity view and six price functions. The old 87-table archive was permanently deleted without backup by explicit user direction on 2026-10-30. Sixteen old inactive Edge tombstones return HTTP 410 and await manual physical deletion. Only two active Price Worker endpoints are supported.

See [current production status](docs/CURRENT_STATUS.md), [pipeline](docs/PRICE_PIPELINE.md), [contract](contracts/system-contract.yaml), and [Edge cleanup issue](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/104).
