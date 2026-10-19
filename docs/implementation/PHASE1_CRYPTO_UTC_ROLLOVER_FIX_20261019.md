# Phase-1 crypto UTC rollover fix — 2026-10-19

## Scope
Fix the confirmed false-`STALE` classification in `fwios.pr5_native_usd_price_shadow_v1` after UTC midnight.

## Root cause
The crypto branch required both:
1. `observed_at >= now() - interval '30 hours'`, and
2. `session_date = current UTC date`.

The second condition invalidated a still-recent 24x7 CoinGecko snapshot at 00:00 UTC even though its 30-hour validity window had not expired.

## Change
Remove only the crypto current-UTC-calendar-date equality from the status decision. Keep:
- CoinGecko provider provenance;
- native USD only;
- positive price;
- provenance PASS;
- observed_at not in the future;
- 30-hour maximum age;
- stock selection/freshness behavior unchanged;
- `trading_eligible=false`.

The observation selector still rejects future session dates with `session_date <= current UTC date`.

## Guardrails
No change to Transactions, Cost Basis, realized P&L, cash, source Holdings quantities/formulas, provider dispatch, quota policy, cron cadence, or the deferred exact-US-stock-session freshness gate. `auto_trade=false` remains required.

## Rollback
Restore the prior function definition from `migrations/20261015_pr5_native_usd_read_shadow_v1.sql`.

## Acceptance
- recent crypto snapshot remains `FRESH` across UTC midnight;
- crypto older than 30 hours remains `STALE`;
- all six currently held crypto assets become valuation-eligible while within age;
- stock outputs remain `LAST_CLOSE`/`FRESH` under existing logic;
- live ALL-account valuation returns zero unpriced positions and `PASS` when no other pricing blocker exists;
- trading eligibility remains false.
