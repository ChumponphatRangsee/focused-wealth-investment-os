# Asset Price Data Service v1.1.0

Production scope: CoinGecko Crypto USD, Alpha Vantage **US Stock unadjusted daily close** and Frankfurter USD/THB FX → Supabase `fwios.market_observations` → Investment Portfolio Tracker Google Sheet `_Market_Data`.

Google Sheet alone owns Holdings, Transactions, cost basis and Portfolio calculations. No Scanner, Research, Valuation, automated trading or other legacy workflows. `auto_trade=false`.

## Production

Two active supported Edge Functions:
- `price-market-refresh-v1` **v4**: Crypto, FX and US_STOCK_EOD for OPEN held stock symbols, currently MSFT, NVDA, TLN, TTWO. Alpha Vantage `TIME_SERIES_DAILY` supplies raw `4. close`; require current NY session date, store certified provenance and fail closed on stale/quota error.
- `price-sheet-sync-v1` **v3**: Crypto prices, USD/THB FX and only collector-certified Stock EOD prices; protects all unverified historical Stock rows and verifies Sheet readback.

Five live Crons: #14 Crypto 17:10 New York every day, #15 FX weekdays 17:10, #16 Crypto/FX Sheet 17:20 daily; **#17 US Stock EOD 19:00 NY weekdays** and **#18 stock Sheet follow-up 19:30 NY weekdays**. Timezone guard handles DST and UTC day rollover.

**Current EOD status: scheduled but no successful stock refresh yet.** Alpha Vantage returned `ALPHA_VANTAGE_DAILY_RATE_LIMIT` (HTTP 503) on provider test. Zero stock writes. Existing MSFT/NVDA/TLN/TTWO rows in Sheet retain old 2026-10-28 closing prices. The new job will attempt the next session, but provider quota and timely data must succeed before fresh stock prices appear.

Crypto/FX collector dry-run passed HTTP 200; real Sheet sync passed HTTP 200, Crypto6+FX updated, Stock0, Sheet readback PASS. Updated live SQL regression 29/29 PASS.

Database retained: 5 price tables, 1 view, 6 SQL functions. The 87-table legacy archive was permanently removed manually at user request without backup. Sixteen retired Edge Functions remain inert HTTP 410 until manual deletion: [Issue #104](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/issues/104). Do not delete the two active price-only workers.

See [current live status](docs/CURRENT_STATUS.md), [pipeline](docs/PRICE_PIPELINE.md), [system contract](contracts/system-contract.yaml).
