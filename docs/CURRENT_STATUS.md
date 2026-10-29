# Current Live Status — Asset Price Data Service 1.0.0

**Dated 2026-10-29 Asia/Bangkok.** This is a point-in-time receipt; check actual GitHub main, Supabase, and Google Sheet before production changes. **Version 1.0.0 is a documentation scope reset, not certification that all legacy infrastructure has been removed.**

## Scope accepted

Only **CoinGecko native USD crypto quotes + Frankfurter USD/THB FX → `fwios.market_observations` → `_Market_Data` in Investment Portfolio Tracker Google Sheet**. Google Sheets remains the accounting owner. No investment research, scanner, technical analysis, valuation, scoring, decisions or future roadmap.

## Live proof already completed

- `price-market-refresh-v1`: six supported open cryptos BTC, DOGE, ETH, HBAR, SOL, XRP. Manual dry-run and live invoke succeeded; **6 native USD observations** stored in Supabase, **0 Portfolio writes**.
- USD/THB Frankfurter mode: manual dry-run and live invoke succeeded; **1 FX observation** stored.
- `price-sheet-sync-v1`: authenticated live sync to `_Market_Data`, **10 existing open-asset rows**, full Sheet write/readback success, **0 Supabase Portfolio writes**. The Sheet's Price Data and Holdings formulas consume it.
- Cron #14 CRYPTO and #15 FX were rerouted to `price-market-refresh-v1`; #16 rerouted to `price-sheet-sync-v1`; they remained active at audit. The **next naturally scheduled post-cutover run has not been independently verified**.
- **18/18** price-only phase-2 regression assertions passed.
- Old Portfolio MTM and Sheet sync endpoints, Scanner and Decision endpoints were replaced by inert HTTP 410 handlers.

## Legacy still physically present — not supported new features

- After 15 user-approved Legacy table drops, **101 base tables** remained in `fwios` at last live audit. Research/Valuation/Decision schemas and functions are **not yet fully deleted**.
- The old US stock EOD Cron #6/#7 was still enabled. Stock rows in the existing Google Sheet can remain from the former setup. **Stock collection is outside v1.0.0 scope**, not yet fully decommissioned.
- Old stock EOD still depends on decision-named provider/auth configuration; do not remove these before replacing price authentication.
- Supabase retains **58 historical portfolio_transactions**; fewer populated rows were visible in the Sheet Transactions tab and **ledger parity was not demonstrated**. This ledger is retained until verified source-ID reconciliation or recoverable backup.
- Price-only deploy source/SQL receipt exists in **[PR #100](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/100)** (Draft / not merged as of this date). GitHub `main` code may still reference old runtime constructs.

**No future roadmap is maintained in this document.** Current work is only price-service operation and truthful legacy cleanup status. Follow the [Price Pipeline runbook](PRICE_PIPELINE.md).
