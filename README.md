# Asset Price Data Service — v1.0.0

**Supported production service:** CoinGecko native USD Crypto prices (BTC, DOGE, ETH, HBAR, SOL, XRP) + Frankfurter USD/THB FX → Supabase `fwios.market_observations` → Google Sheet Investment Portfolio Tracker `_Market_Data`.

Google Sheet is the **sole authoritative source** for Transactions, Holdings, cost basis and portfolio formulas; the price worker reads open holdings without storing transactions or portfolio state. Crypto updates and FX are read back after each Sheet write. Existing four Stock rows in `_Market_Data` are **historical frozen values, not live stock prices**. No scanning, investment research, technical, thesis, valuation, decision, portfolio MTM, auto trading or future roadmap.

## Deployed service

- `supabase/functions/price-market-refresh-v1/index.ts`: authenticated CRYPTO and FX data collection, native quotes, source provenance and canonical observations.
- `supabase/functions/price-sheet-sync-v1/index.ts`: authenticated Crypto-only+FX Sheet synchronization preserving Stock history, formulas and manual overrides.
- Cron #14 (CRYPTO), #15 (FX), #16 (Sheet) are the only three active and registered jobs. The legacy job **names** are misleading; their commands call these price-only endpoints.
- First **naturally scheduled post-cleanup cycle** on 2026-10-30 Asia/Bangkok **passed**: CRYPTO 6/6, FX 1/1, Sheet Sync readback, actual Edge HTTP 200 for all three.

## Database cleanup and retention

Production schema `fwios` contains **5 tables, 1 view and 13 functions**. Historical source data is isolated in private schema `fwios_legacy_archive_20261029` (87 tables, including 58 historical transactions and 1,590 stock closes). This retained archive is **not** a verified independent backup. Supabase project uses the Free plan; do not permanently delete the archive until a verified external logical dump and restore test exist. Two Edge endpoints remain live; 16 retired slugs are deployed with HTTP 410 handlers and cannot be physically undeployed with this connector.

## Repository layout

`contracts/system-contract.yaml`, `docs/CURRENT_STATUS.md`, `docs/PRICE_PIPELINE.md` define the current system. `tests/price/` contains read-only production SQL assertions and offline source checks. `supabase/migrations/20261029*.sql` and `20261030*.sql` are **already-applied historical cutover/cleanup receipts**; they do **not** constitute a clean database bootstrap. Consult `decommission/SOURCE_RETIREMENT_RECEIPT.md` for retired source file inventory and Git recovery.

Avoid replaying applied migrations. No secrets in Git; credentials stay in Supabase Vault. `auto_trade=false`.
