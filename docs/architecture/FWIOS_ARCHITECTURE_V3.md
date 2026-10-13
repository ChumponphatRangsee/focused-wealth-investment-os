# FWIOS Architecture Refactor v3 — Quota-Aware Shared Market Data

**Status:** PROPOSED / DOCUMENTATION ONLY — NOT CUT OVER  
**Plan recorded:** 2026-10-13 (Asia/Bangkok)  
**Implementation:** [API Quota Implementation Plan](../implementation/API_QUOTA_IMPLEMENTATION_PLAN.md)  
**Active contract:** [system-contract.yaml](../../contracts/system-contract.yaml)

> This is the **target architecture**, not a claim that the current production architecture has migrated. Retain the active FWIOS 0.87.x paths, historical decision snapshots, market-observation compatibility views, and human-execution-only rules until regression-based cutover.

## 1. Purpose and ownership

Three independent business responsibilities must not become three independent API consumers or duplicate transaction ledgers:

| Responsibility | Owner after explicit cutover | Must not own |
| --- | --- | --- |
| External market prices / FX / S&P 500 universe / fundamentals / provider provenance | **Supabase FWIOS Shared Market Data & Research Layer** | Executed BUY/SELL transactions, portfolio cost basis |
| Portfolio accounting (transactions, accounts, holdings quantity, cost basis, realized/unrealized P&L, portfolio value) | **Investment Portfolio Tracker - Chumponphat** (Google Sheet) | Direct production market-price provider calls |
| Discovery / scanner / selective research / thesis / valuation / investment decisions | **Focused Wealth Dashboard - Chumponphat**, backed by Supabase research state | Transaction Ledger, executed trade history, fees, portfolio accounting |

The Tracker's `Transactions` sheet is the **target sole system of record for trades**; position quantities and cost basis derive from it. The current `portfolio_state.current_authority: Supabase` in the live contract describes *today's operational decision/portfolio read model*, not the desired post-cutover transaction authority. It must remain effective until a verified migration is explicitly approved. A read-only portfolio **summary** may be sent to research/portfolio-fit consumers after cutover; it must not recreate a Supabase trading ledger.

**Current live state (read-only inspection 2026-10-13):**
- Tracker tabs include `Transactions`, `Price Data`, `Holdings`; `_Market_Data` does **not** yet exist. `Price Data` still uses CoinGecko/GoogleFinance/FX formulas.
- Focused Dashboard's `_Data` contains a legacy portfolio summary / refresh integration. It is **not** proof that Research already reads Tracker-owned accounting.
- Supabase already contains `fwios.market_observations`, `fwios.portfolio_market_quote_snapshots`, and `fwios.v_portfolio_market_quote_current`. At inspection this price view had 6 crypto + 4 stocks marked FRESH. Meanwhile `fwios.v_market_price_latest` was stale/blocked; do **not** simply repoint consumers to it.
- Existing quota-related infrastructure includes `decision_refresh_provider_registry`, `decision_refresh_api_quota_policy`, `decision_refresh_api_usage`, `market_daily_close_policy`, `market_daily_close_api_usage`, and quota reservation SQL functions. These are **not yet proven to govern all providers/capabilities uniformly**.
- Confirmed security migration item: credential-bearing URL embedded in a Focused Dashboard sheet cell. Rotate/revoke the old token, remove secret-bearing URLs from readable sheets, and substitute a least-privilege protected import flow. **Never commit the existing URL or token.**

## 2. Target data flow

```text
Investment Portfolio Tracker ─┐
Focused Wealth Dashboard ─────┼──► Trusted FWIOS Market Data read / refresh interface
S&P 500 Scanner ───────────────┤                        │
Research / Valuation ──────────┘                        ▼
                                                Cache + freshness gate
                                                        │ miss
                                                        ▼
                                               Single-flight / job dedupe
                                                        │
                                                        ▼
                                          Priority scheduler + quota manager
                                           (atomic reservation & audit)
                                                        │ allowed
                                                        ▼
                                                 Provider adapters
                                           Twelve Data / CoinGecko / FX
                                                        │
                                                        ▼
                                          Canonical market observations
                                                        │
                                                        ▼
                                          fwios.v_market_price_current
                                              / secure read endpoint
                                                        │
                                   ┌────────────────────┴──────────────────┐
                                   ▼                                       ▼
                          Portfolio Tracker                        Focused Dashboard
                        _Market_Data → Price Data                Scanner / Research
                        Transactions → Holdings                   Thesis / Valuation
                        Accounting/P&L                             Decision support
```

Providers must be called **once per canonical observation** where plan and endpoint permit sharing. Consumers read the same immutable observation reference and are not allowed to trigger uncontrolled external calls.

## 3. Mandatory external-call invariant

Every production external-provider call follows this sequence:

1. Normalize `instrument_id` and request identity; check canonical cache and data-type/market-session TTL.
2. Reuse an existing in-flight refresh if the request is equivalent; never double-spend for overlapping jobs.
3. Determine capability, consumer priority, endpoint-specific credit cost, provider readiness, allowed concurrency, and minute/hour/day/reset windows.
4. **Atomically reserve** available quota across *all* applicable provider/plan and protected-capability budgets. Unconfigured or disabled policy => **DENY**, never `UNLIMITED_OR_UNCONFIGURED` in production.
5. Call the provider from a server-only adapter; persist usage and outcome, including billable failures/retries under provider-specific billing rules.
6. Validate and persist observation provenance and market-session semantics, then publish a canonical cache value.
7. Return `FRESH`, explicit `LAST_CLOSE`, `STALE`, `FALLBACK`, `QUOTA_BLOCKED`, `PROVIDER_ERROR`, or `MISSING` — never silently label stale data LIVE.

A **cache hit** is a consumer event, not another external provider request. Log it separately or distinguish it clearly from billable provider usage.

No Google Sheet, Dashboard, scanner, or research worker may bypass the common quota path in production. Manual diagnostics are isolated/non-production and must not influence valuation results.

## 4. Unified provider/quota model

Reuse existing schema where possible; logical components are `provider_registry`, `api_quota_policy`, `api_usage`, `api_reservations`, `market_observations`, `v_market_price_current`. Do not create duplicate authority tables merely to match these example names.

Registry/policy must support:
- Provider + plan identity, readiness, active flag, endpoint/capability eligibility, server-side secret reference; **no stored plaintext secret**.
- Requests/minute, hour, day; credits and endpoint-specific pricing; concurrency; reset timezone and provider reset boundary.
- Reserved/committed/released credits, expiration/lease and idempotency, request/retry/429 outcomes.
- Configurable warning/critical thresholds (suggested 70% / 90%), daily protected reserve, capability budgets and overrides with audit.
- Provider failover (e.g. primary FX → approved secondary) with independent quota and provenance checks.

Atomic reservation must be concurrency-safe across workers and windows; an abandoned reservation requires a defined reconciliation/expiry policy. A quota failure returns an explicit blocked state, not a loop of immediate retries.

## 5. Consumer priority and protected capacity

| Runtime priority | Consumer | Behaviour during scarcity |
| --- | --- | --- |
| P0 | Actually held instruments / critical portfolio refresh | Preserve capacity longest; cache/last-close clearly identified |
| P1 | Focused actionable investment candidates | Preserve after holdings |
| P2 | Active research / thesis | Throttle enrichment |
| P3 | Watchlist | Throttle / use cache |
| P4 | Broad S&P 500 scanner | Reduce universe, skip work, defer first |

Illustrative **policy starting point**, not a verified provider allocation: Holdings 25%, Opportunities 25%, Research 20%, Scanner 20%, Emergency Reserve 10%. Configure by real provider plan, endpoint cost, hold-count and coverage; watchlist shares the discretionary pool. P4 never consumes the protected reserve. Manual refresh outranks background work but **never bypasses** quota or current holdings protection.

Distinguish **implementation priority** (P0 prerequisite PRs) from **runtime consumer priority** (P0 holdings).

## 6. Cache and schedule rules

| Data | Default target TTL / policy |
| --- | --- |
| Crypto | 5–15 minutes, 24/7 |
| Stocks, market open | 5–15 minutes, exchange-local session aware |
| Stocks, market closed | Reuse last verified close until next relevant session; label `LAST_CLOSE` not live quote |
| FX | 15–60 minutes |
| Daily close | Trading-session scoped |
| Fundamentals | 24 hours+; event-driven after filings/earnings |
| Company metadata | 7–30 days |
| S&P 500 constituents | Daily or weekly |

These are **configuration defaults subject to provider availability and quota**, not guarantees of fresh prices.

Deduplication key must include canonical instrument identity, provider/endpoint, capability, request parameters, currency, adjusted/unadjusted semantics and market/session scope. Use single-flight locks/leases with retry-safe ownership; do not use ticker alone where instrument identity is ambiguous.

Use batch endpoints where supported **and where published provider credit cost makes it beneficial** (e.g. multi-asset CoinGecko). Record both request count and provider billable credits.

## 7. Scanner design (progressive enrichment)

```text
S&P 500 universe (~500)
  → Stage 1: cheap cached/batched screening
  → shortlist ~100
  → Stage 2: controlled additional enrichment
  → shortlist ~20–50
  → Stage 3: selective deep research and Full Thesis
```

Before each run, estimate provider requests **and credits**, account for already reserved budget and priority reserve, then choose: proceed, shrink universe, reuse cache, skip optional enrichment or defer. Never launch an unbounded `500 stocks × 5 endpoints` run. Preserve existing FWIOS selective-research lifecycle, quality/hardening, deterministic scoring, decision/approval gates and historical lineage.

## 8. Portfolio Tracker and decision boundaries

- Add protected/hidden `_Market_Data` as an import-only projection from the canonical price read endpoint: instrument_id, symbol, class, native price/currency, THB price, provider, observed_at, freshness, price_gate.
- Keep `Transactions` unchanged; derive holdings quantity, cost basis, realized P&L and all account summaries in the Tracker.
- Convert `Price Data` from production provider caller to presentation/audit layer **only after shadow reconciliation**. Preserve historical prices and manual overrides for audited diagnostics, not undisclosed fallback valuation.
- Treat `CASH` and other fixed-price special rows explicitly; do not waste provider quota on them.
- Focused Dashboard's Research/Scanner/Decision surfaces can use only a **read-only portfolio context summary** where authorized; never trade-entry or accounting writes.
- Supabase portfolio ledger tables, MTM accounting jobs and legacy decision-consumer dependencies remain available for compatibility until confirmed cutover; then block new accounting writes, retain history for rollback, and remove only after further approval.

## 9. Cutover gates and rollback

**Gate A — Quota Safe:** all external calls go through common reservation/logging, unconfigured provider fails closed, correct plan reset and credit costs, concurrency tests prove no overspend, cache hits do not bill.

**Gate B — Cache Safe:** simultaneous requests dedupe, provider 429 and retries are bounded, market-close/FX/crypto TTL are correct, stale data is labeled and blocked for price-sensitive decisions.

**Gate C — Portfolio Safe:** all live Holdings instruments covered; compare `Best`, `Loan Money`, `Mom`, and `ALL`. Quantity, transaction history, cost basis, realized P&L unchanged. `Portfolio Value = sum(Holdings Market Value)` within THB 0.01 at the **same observation set**.

**Gate D — Scanner Safe:** pre-run credit estimator and priority reserve protection; degraded mode continues to work under low quota; no background scan starves P0.

**Gate E — Research/Legacy Safe:** selective-research/decision tests pass, no accounting mutation or automated broker action, no production consumer depends on deprecated writes.

Roll out behind feature flags: observe current state → parallel shadow prices → reconcile → explicit production read cutover → stop duplicate API calls → deprecate old ledger writers. On error, restore the **previous verified read path**, retain all historical transactions/observations and report data freshness honestly. Never drop ledgers in the same release as cutover.

## 10. Release milestones

- **Release A / P0:** Contract, inventory/security; unified provider registry and quota policies; atomic reservation + usage; cache/single-flight/priority scheduler.
- **Release B / P1:** Canonical market view, secure read endpoint, Tracker `_Market_Data`, shadow reconciliation, portfolio valuation cutover.
- **Release C / P2–P3:** Research dashboard cleanup, quota-aware tiered scanner, advanced health/alerts and legacy retirement.

See the [implementation plan](../implementation/API_QUOTA_IMPLEMENTATION_PLAN.md) for PR dependencies, acceptance tests and ownership. This document **does not authorize** production writes or automatic trading.
