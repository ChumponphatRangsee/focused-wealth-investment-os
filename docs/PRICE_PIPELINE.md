# Price Pipeline & Operations — v1.0.0

**Only feature:** Crypto + USD/THB FX → Supabase → Google Sheets. No new investment project roadmap.

```text
Investment Portfolio Tracker — Holdings (OPEN crypto symbols, READ ONLY)
    │
    ├─ CoinGecko → native USD crypto prices ─┐
    └─ Frankfurter → USD/THB FX rate ────────┤
                                             ▼
                                fwios.market_observations
                                      │
                                price-sheet-sync-v1
                                      ▼
                                 _Market_Data
                                      ▼
                                Price Data → Holdings
                                    formulas
```

## Active price-only workers

| Job | Deployed Edge Function | Operation |
|---|---|---|
| Cron #14 | `price-market-refresh-v1` CRYPTO | Read supported open cryptocurrency symbols from Sheet; fetch positive native USD quotes and recent timestamps from CoinGecko; persist validated observations |
| Cron #15 | `price-market-refresh-v1` FX | Fetch USD/THB from Frankfurter; reject invalid/stale source date; persist canonical FX observation |
| Cron #16 | `price-sheet-sync-v1` v2 | Read verified open Crypto prices only; update Crypto rows and FX in `_Market_Data`, preserve historic Stock rows and verify readback |

Only these price-oriented jobs are supported in v1.0.0. Legacy Stock EOD Cron #6/#7 were **disabled on 2026-10-29** after a verified Crypto-only sync deployment. Historical closes and existing Stock rows in `_Market_Data` remain retained but are **not continuously refreshed**. Never present frozen stock prices as current.

## Source, storage, authorization

- CoinGecko: supported USD pairs for `BTC, DOGE, ETH, HBAR, SOL, XRP`, dynamically limited by OPEN Crypto Holdings. Reject missing/negative or provider timestamp older than 2h.
- Frankfurter: USD/THB, positive valid rate, source date no older than 5 days. Currency conversion remains in Google Sheet formulas.
- Supabase: store via `fwios.ensure_market_observation_v1` in `fwios.market_observations`, with provider, source, observed-at, date, currency, status and provenance. Preserve market price history, identity and required security controls.
- Auth: approved server-to-server token from Supabase Vault. Never put tokens in GitHub source, logs, query parameters or user-visible links.
- Google Sheet: read open symbols from Holdings without saving their quantities/accounts to Supabase. Write only the dedicated `_Market_Data` price/FX cells. Existing `Price Data` and `Holdings` formulas own downstream calculations.
- No position/cost basis/transaction writes, MTM, signals, scoring or auto trade.

## Validation checklist

A successful change should prove (1) authenticated provider read and freshness, (2) Supabase price/FX observation persisted, (3) six current Crypto price rows and four preserved historic Stock rows in the ten-row Sheet `_Market_Data`, plus FX readback parity, (4) `Price Data` and Holdings formulas are nonempty/correct, (5) no portfolio DB mutation and (6) scheduled job configuration correct.

**Verified 2026-10-29:** manual CRYPTO HTTP 200, six quote writes; manual FX HTTP 200, one observation write; manual Sheet sync HTTP 200 with 10/10 rows/readback, no DB portfolio writes; 18/18 read-only regression PASS. This **does not** prove next scheduled Cron execution.

Fail closed when a source, credentials, quote, FX, market observation, symbol or readback is missing/stale/invalid. Do not silently substitute data or claim success based on a Cron trigger alone. Earlier code/deployment receipt is in [PR #100](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/100).

## Verified price-only sync and legacy Stock EOD retirement — 2026-10-29

- Deployed `price-sheet-sync-v1` **version 2** to production. Reads only OPEN Crypto symbols from Holdings (without writing holdings/accounts to Supabase); updates existing Crypto quote rows by symbol, preserves all four existing Stock price rows and their observation IDs, updates the existing FX cells, and checks readback. No full-range clear.
- Production smoke tests: authenticated dry-run **HTTP 200 (6 cryptos, zero DB or Sheet writes)**; authenticated live sync **HTTP 200 (6 cryptos, Sheet readback verified, zero DB writes)**. Independent Google Sheet inspection confirmed all ten assets still present, four Stock price/observation IDs unchanged, all ten Price Data rows priced, no formula errors in checked Price Data and Holdings ranges.
- Stock EOD Cron #6/#7 disabled via live-applied migration `20261029101252_disable_legacy_stock_eod_cron_v1`; the historical `fwios.market_daily_closes` table remains at **1,590 observations for 64 symbols**. Price-only Cron #14/#15/#16 remain active. **A naturally scheduled post-cutover run has not yet been independently verified**; one-off HTTP 200 and a successful database enqueue do not establish scheduled continuity.
- Legacy provider-validator Cron #5 remains active pending full dependency audit. No wholesale legacy table/function/view cleanup yet; preserve provenance, canonical identity and historical transaction records until independently proven safe.
