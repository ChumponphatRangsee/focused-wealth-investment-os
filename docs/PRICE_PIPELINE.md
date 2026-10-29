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
| Cron #16 | `price-sheet-sync-v1` | Read eligible Supabase price observations; write `_Market_Data` price rows and FX; verify row values and session/fx readback |

Only these price-oriented jobs are supported in v1.0.0. Legacy Cron #6/#7 (stock EOD) remained active at last verification but is **out of new scope**. Do not treat legacy stock collection as part of the approved feature or delete it without auditing market price dependencies.

## Source, storage, authorization

- CoinGecko: supported USD pairs for `BTC, DOGE, ETH, HBAR, SOL, XRP`, dynamically limited by OPEN Crypto Holdings. Reject missing/negative or provider timestamp older than 2h.
- Frankfurter: USD/THB, positive valid rate, source date no older than 5 days. Currency conversion remains in Google Sheet formulas.
- Supabase: store via `fwios.ensure_market_observation_v1` in `fwios.market_observations`, with provider, source, observed-at, date, currency, status and provenance. Preserve market price history, identity and required security controls.
- Auth: approved server-to-server token from Supabase Vault. Never put tokens in GitHub source, logs, query parameters or user-visible links.
- Google Sheet: read open symbols from Holdings without saving their quantities/accounts to Supabase. Write only the dedicated `_Market_Data` price/FX cells. Existing `Price Data` and `Holdings` formulas own downstream calculations.
- No position/cost basis/transaction writes, MTM, signals, scoring or auto trade.

## Validation checklist

A successful change should prove (1) authenticated provider read and freshness, (2) Supabase price/FX observation persisted, (3) 10-row existing Sheet `_Market_Data` write/readback parity, (4) `Price Data` and Holdings formulas are nonempty/correct, (5) no portfolio DB mutation and (6) scheduled job configuration correct.

**Verified 2026-10-29:** manual CRYPTO HTTP 200, six quote writes; manual FX HTTP 200, one observation write; manual Sheet sync HTTP 200 with 10/10 rows/readback, no DB portfolio writes; 18/18 read-only regression PASS. This **does not** prove next scheduled Cron execution.

Fail closed when a source, credentials, quote, FX, market observation, symbol or readback is missing/stale/invalid. Do not silently substitute data or claim success based on a Cron trigger alone. Earlier code/deployment receipt is in [PR #100](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/100).
