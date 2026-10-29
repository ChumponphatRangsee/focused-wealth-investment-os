# Current Live Status — Asset Price Data Service 1.0.0

**Dated 2026-10-29 Asia/Bangkok.** This is a point-in-time receipt; check actual GitHub main, Supabase, and Google Sheet before production changes. **Version 1.0.0 is a documentation scope reset, not certification that all legacy infrastructure has been removed.**

## Scope accepted

Only **CoinGecko native USD crypto quotes + Frankfurter USD/THB FX → `fwios.market_observations` → `_Market_Data` in Investment Portfolio Tracker Google Sheet**. Google Sheets remains the accounting owner. No investment research, scanner, technical analysis, valuation, scoring, decisions or future roadmap.

## Live proof already completed

- `price-market-refresh-v1`: six supported open cryptos BTC, DOGE, ETH, HBAR, SOL, XRP. Manual dry-run and live invoke succeeded; **6 native USD observations** stored in Supabase, **0 Portfolio writes**.
- USD/THB Frankfurter mode: manual dry-run and live invoke succeeded; **1 FX observation** stored.
- `price-sheet-sync-v1`: authenticated live sync to `_Market_Data`, **10 existing open-asset rows**, full Sheet write/readback success, **0 Supabase Portfolio writes**. The Sheet's Price Data and Holdings formulas consume it.
- Cron #14 CRYPTO and #15 FX were rerouted to `price-market-refresh-v1`; #16 rerouted to `price-sheet-sync-v1`; they remained active at audit. The **next naturally scheduled post-cutover run has not been independently verified**.
- **18/18** price-only phase-2 regression assertions passed; assertions 04/05 were updated and rerun after Stock EOD Cron #6/#7 were disabled.
- Old Portfolio MTM and Sheet sync endpoints, Scanner and Decision endpoints were replaced by inert HTTP 410 handlers.

## Legacy still physically present — not supported new features

- After 15 user-approved Legacy table drops, **101 base tables** remained in `fwios` at last live audit. Research/Valuation/Decision schemas and functions are **not yet fully deleted**.
- US stock EOD Cron #6 and #7 are now **disabled** after independent Crypto-only Sheet-sync verification. The 1,590 historical closes for 64 symbols were preserved. Four existing Stock rows in `_Market_Data` are frozen historical values, not an ongoing stock price service.
- Legacy provider validator Cron #5 was **disabled** on 2026-10-29 after verifying the price-only workers do not use the legacy decision provider registry. Decision-named provider/auth SQL and old Edge endpoints remain pending dependency-safe retirement. The current Crypto/FX workers use direct CoinGecko/Frankfurter and Vault token auth.
- Supabase retains **58 historical portfolio_transactions**; fewer populated rows were visible in the Sheet Transactions tab and **ledger parity was not demonstrated**. This ledger is retained until verified source-ID reconciliation or recoverable backup.
- Price-only deploy source/SQL receipt exists in **[PR #100](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/100)** (Draft / not merged as of this date). GitHub `main` code may still reference old runtime constructs.

**No future roadmap is maintained in this document.** Current work is only price-service operation and truthful legacy cleanup status. Follow the [Price Pipeline runbook](PRICE_PIPELINE.md).


## Verified production update — 2026-10-29 (post-PR #101)

- `price-sheet-sync-v1` **v2 deployed** with Crypto-only price updates. It no longer requires live stock quote eligibility and preserves the pre-existing four Stock rows in `_Market_Data` without overwriting their price/observation IDs or clearing stale rows. FX cell readback is still enforced.
- Authenticated dry-run HTTP 200 (Crypto **6** / DB writes **0** / Sheet writes **0**), then live sync HTTP 200 (Crypto **6** / Sheet readback verified / DB writes **0**). The tab still has ten assets: six Crypto and four historic Stock.
- After deployment, all four Stock price+observation IDs remained unchanged. `Price Data` had positive prices for all ten assets with no checked formula errors; checked `Holdings` also had no formula errors.
- New migration `20261029101252_disable_legacy_stock_eod_cron_v1` **disabled** #6 and #7; #14/#15/#16 remain active. Historic `market_daily_closes` retained **1,590 rows / 64 symbols**. **No naturally scheduled post-cutover price-only run yet independently verified**.
- Ledger read-only reconciliation: 58 Supabase entries are two imports of 29 unique source IDs, all represented in the Sheet; nine critical fields per entry (522 checks) showed zero differences. Sheet contains SRC-0030/SRC-0031 in addition. Retain Supabase ledger until a recoverability/raw-payload review has been finalized.
- Remaining: 101 base tables, 127 SQL functions, 39 views, 16 triggers, 160 FKs at audit; full cleanup not complete. Provider validator #5 remains active; historical stock price rows will become stale and must not be advertised as current market prices.

### Legacy provider validator retirement verified — 2026-10-29

- Inspected the deployed `decision-refresh-provider-validator-v1` worker: it reads/writes `decision_refresh_*` provider registry, validator run and quota records and old `system_state`; price-only Crypto and Sheet workers do **not** call it or depend on its provider validation/promotion routines.
- Disabled its standalone Cron **#5** via live-applied migration `20261029101711_disable_legacy_provider_validator_cron_v1`. Cron #5/#6/#7 are inactive, while only #14/#15/#16 remain active. Provider registry, logs, SQL procedures and Edge endpoint are retained for explicit dependency-ordered cleanup, not deleted.
- Updated phase-2 read-only SQL regression to assert this state; **20/20 PASS**. No new naturally scheduled price-only cycle has yet been independently proven.
