# Asset Price Data Service v1.0.0

**Production scope:** CoinGecko native USD Crypto prices + Frankfurter USD/THB FX → Supabase `fwios.market_observations` → Google Sheet Investment Portfolio Tracker `_Market_Data`. Google Sheet exclusively owns Holdings, Transactions, cost basis and portfolio accounting. No scanner/research/valuation/decision/stock ingest or trading. `auto_trade=false`.

Only two supported workers: `price-market-refresh-v1` (Crypto/FX, v2) and `price-sheet-sync-v1` (Google Sheet price/FX readback, v2). Cron #14 Crypto, #15 FX and #16 Sheet Sync are the **only three active jobs**. Both natural scheduled cycle and post-cleanup manual end-to-end Crypto 6/6 / FX / Sheet write-readback have passed (HTTP 200).

**Database cleanup:** `fwios` now has **five price/identity tables**, **one identity view**, **six SQL functions**. The historical 87-table archive was permanently deleted **at the user's explicit direction without a backup**; seven orphaned functions were then retired using `RESTRICT`. Existing six Crypto prices continue updating. The four Sheet Stock quote rows are frozen historical values, not live stock prices.

**Remaining:** Sixteen old Edge Function deployments still exist, but their handlers return HTTP 410 and do not execute retired legacy workflows. See [manual Edge decommission steps](decommission/RETIRED_EDGE_FUNCTION_REMOVAL.md). The connected Supabase app cannot delete these physical deployments; do **not** delete the two supported price-only workers.

See [system contract](contracts/system-contract.yaml), [live production status](docs/CURRENT_STATUS.md), [pipeline and tests](docs/PRICE_PIPELINE.md), and [historical deletion receipt](decommission/USER_AUTHORIZED_ARCHIVE_REMOVAL_RECEIPT.md). Source history is preserved in Git; deleted database rows are not. Supabase migrations under `supabase/migrations` are already-applied receipts, not a fresh-database bootstrap. No credentials in Git.
