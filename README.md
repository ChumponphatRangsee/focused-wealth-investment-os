# Asset Price Data Service

**Version 1.0.0 (documentation baseline)** · **Scope: Crypto + USD/THB FX → Supabase → Google Sheet.**

This repository is being repurposed from the former Focused Wealth Investment OS into a narrowly scoped **asset price ingestion and synchronization service**. The only approved features for this version are:

- Read supported *open cryptocurrency symbols* from the Investment Portfolio Tracker Google Sheet (read-only).
- Fetch native USD cryptocurrency quotes via CoinGecko and USD/THB via Frankfurter; validate price, timestamp, provider and freshness.
- Store verified price/FX observations in Supabase `fwios.market_observations`.
- Publish eligible quotes and FX to the Google Sheet tab `_Market_Data` and verify its contents by reading them back. Existing `Price Data` and `Holdings` formulas consume that tab.

## Operating architecture

```text
Google Sheet Holdings (symbols only; read-only)
      │
      ├─ CoinGecko → crypto prices in USD ─┐
      └─ Frankfurter → USD/THB FX ─────────┤
                                          ▼
                              Supabase market_observations
                                          ▼
                                 price-sheet-sync-v1
                                          ▼
                           Google Sheet _Market_Data
                                          ▼
                         Price Data → Holdings formulas
```

**Not in scope:** Stock Discovery, Technical Screening, Thesis, Fundamental Research, Valuation, Scoring, Decision, Rankings, Portfolio MTM, database accounting or trades. Google Sheets remains the sole authority for transactions, holdings, cost basis and portfolio computations. **No future roadmap exists for v1.0.0.**

## Documents

[System Contract](contracts/system-contract.yaml) · [Current Live Status](docs/CURRENT_STATUS.md) · [Price Pipeline & Validation](docs/PRICE_PIPELINE.md) · [Agent Instructions](AGENTS.md) · [Version](VERSION) · [Changelog](CHANGELOG.md)

## Read this before using production

This **documentation reset does not yet delete all legacy source code and database objects**. As of 2026-10-29, the former system's stock EOD Cron and Research/Decision database objects still existed; they are **not** new supported features. The price-only workers and Sheet readback have passed manual E2E tests. For exact live state and outstanding cleanup risks, see [Current Live Status](docs/CURRENT_STATUS.md). Cutover implementation under review: [PR #100](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/100).

Old roadmap, policies, implementation handovers and investment strategy documents were deliberately deleted from the current Git tree; earlier commits retain standard Git history.
