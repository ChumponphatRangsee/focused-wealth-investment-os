# Agent Instructions — Asset Price Data Service v1.0.0

**This contract replaces the old FWIOS investment agent instructions.** Current project purpose: **Crypto + USD/THB FX prices → Supabase → Google Sheet**. Never initiate or revive Stock Discovery, technical screening, thesis research, fair-value calculation, investment decisions, portfolio analytics, stock rankings or automated trading.

## Authority

- **Google Sheets:** authoritative transactions, open holdings, cost basis, portfolio value and formulas. Read open crypto symbols; never copy transactions or Holdings into a Supabase ledger.
- **Supabase:** canonical price/FX observations with provider, timestamps, source identity and validation.
- **GitHub:** source code, active contract, tests and database migration history.
- **Live deployments and readbacks take precedence** over dated docs or draft PRs.

## Allowed work

1. Collect supported native USD CoinGecko crypto prices and a valid USD/THB FX quote; fail closed for missing, malformed, stale or ambiguous inputs.
2. Persist only market price/FX observations in the approved gateway.
3. Write only the designated `_Market_Data` price/FX range and read it back; preserve other Google Sheet tabs and all formulas.
4. Maintain authentication, Vault secrets, source provenance, quota/freshness, service health and regression tests necessary for those features.

## Forbidden work

No research, valuation, decision, thesis, trading, securities discovery, portfolio MTM, portfolio ledger updates, manual price overrides, or future roadmap. No broker orders; `auto_trade=false`. Do not add unrelated scope.

Never commit credentials, service-account JSON or access tokens. Use Vault. Before dropping legacy tables, functions, views, triggers or schedules, inspect live Dependencies and retain price ingestion dependencies; never use blind `CASCADE`. Preserve any uniquely held historical accounting data until Sheet source-ID parity or verified recoverable backup is confirmed.

A manually invoked HTTP 200 does not prove the next scheduled Cron succeeded. Report tests separately: provider → Supabase observation → Sheet write/readback → formula use, plus any active legacy services. Some old Edge slugs are inert 410 tombstones despite their ACTIVE deployment metadata.

Always read `contracts/system-contract.yaml`, `docs/CURRENT_STATUS.md`, and `docs/PRICE_PIPELINE.md` before execution.
