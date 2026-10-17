# FWIOS v3 — API Quota, Caching & Architecture Implementation Plan

**Status:** PROPOSED — planned PR sequence, **no implementation or production cutover**  
**Recorded:** 2026-10-13 (Asia/Bangkok)  
**Target architecture:** [FWIOS Architecture Refactor v3](../architecture/FWIOS_ARCHITECTURE_V3.md)  
**Source requirements:** Architecture Refactor v2 + API Quota, Caching & Provider Usage Requirements (user-supplied).

## 0. Scope, rules and baseline

### Intended outcomes

1. Both Portfolio Tracker and Focused Dashboard/Scanner/Research use *one* trusted Supabase market-observation/price service, not independent price-provider integrations.
2. **Investment Portfolio Tracker - Chumponphat** is the post-cutover sole transaction/accounting authority: trade history, quantities, cost basis, realized P&L, valuations and holdings. Supabase retains market/research history; it does not become a second transaction ledger.
3. No production external call occurs without `cache → freshness → single-flight → atomic quota reservation → provider call → usage finalization`.
4. Holdings price refresh capacity survives Scanner pressure; low quota reduces *breadth before critical holdings data*.
5. Old portfolio tables and functions are *decommissioned last*, and no auto-trade or silent data deletion occurs.

### Current-state inspection (2026-10-13, descriptive only)

| Area | Verified existing piece | Delta to build or verify |
| --- | --- | --- |
| Price observations | `fwios.market_observations`, `portfolio_market_quote_snapshots`, `v_portfolio_market_quote_current` | Expose secure shared canonical price; don't use stale `v_market_price_latest` blindly |
| Provider policies | `decision_refresh_provider_registry` (5 rows), `decision_refresh_api_quota_policy` (Alpha Vantage group), `market_daily_close_policy` (Twelve Data) | One effective provider/plan budget across all capabilities, windows and consumers |
| Usage logs | `decision_refresh_api_usage` (353 rows), `market_daily_close_api_usage` (3,232 rows) | Common audit model including credits/reservation/retries/cache metrics |
| Reservation functions | `reserve_decision_refresh_api_call_v1`, `reserve_market_daily_close_api_call_v1` | Harden/adapt atomic quota boundaries, support endpoint cost and reset, reject unconfigured policy |
| Existing application limits | Twelve Data daily-close policy: 8/min and 700/day; Alpha Vantage decision refresh: 25/day, price=15, validator=2, reserve=3 | Treat as *application-configured policies*, not proof of vendor entitlements; verify actual plan/endpoint terms |
| Dashboard cache | `dashboard_refresh_cache` exists | Distinguish dashboard payload caching from market-price caching |
| Tracker | `Transactions`, `Price Data`, `Holdings`; `_Market_Data` absent | Add authorized import + shadow cutover; do not change transaction math |
| Focused Dashboard | Old portfolio-value/P&L surface and protected-link concern in `_Data` | Rotate credential, separate accounting surfaces, keep research/decision features |

**Known blocker:** `reserve_decision_refresh_api_call_v1` returns `allowed=true` for missing provider policy (`UNLIMITED_OR_UNCONFIGURED`). Mandatory production behaviour is **deny-by-default**. Do not delete/replace the routine abruptly: inventory callers first, add compatibility + regression test, switch consumers and then retire old path.

**Historical note:** Existing Alpha Vantage class budgets above do not sum to the full daily limit; reconcile any unallocated capacity before authorizing it. Provider rate-limit reset clocks differ; avoid assuming midnight Bangkok, UTC or ET globally.

## 1. Priorities and milestones

### P0 — Release A: Quota-safe foundation (blocking)

**PR 1 — Architecture Contract v3 + Inventory + Security**
- Document current vs target authority, current production compatibility and explicit `cutover=false`.
- Inventory Edge Functions, cron jobs, apps, Sheets, provider credentials, providers, endpoint classes and every external-call path.
- Baseline open holdings and portfolio values for Best, Loan Money, Mom, ALL; also API usage, active jobs and current price view.
- Security action: rotate token embedded in Focused Dashboard `_Data` and implement safer authenticated read access; never commit URL/secret.
- Acceptance: inventory covers every production external provider call; old production paths unchanged; owner and rollback named.

**PR 2 — Shared Provider Registry + Quota Policy**
- Extend existing registry/policies rather than multiplying `api_provider_registry` tables.
- Model `provider_key + plan + endpoint/capability`, active/readiness, credit model, limits per minute/hour/day/concurrent, timezone/reset, protected reserve, warning/critical levels and provider-specific retry rules.
- Configure Twelve Data, CoinGecko, FX and any existing Alpha Vantage uses based on **verified** plans; avoid hard-coded provider limits in Edge Functions.
- Budget by capability (MARKET_PRICE, FX, DAILY_CLOSE, FUNDAMENTALS, EARNINGS, PROFILE, ANALYST_DATA, RESEARCH_ENRICHMENT) and runtime priority.
- Acceptance: one normalized policy lookup path; unconfigured/blocked provider returns DENY; configs validated against actual vendor entitlements.

**PR 3 — Atomic Reservation + Unified Usage**
- Build/extend a single logical ledger (may use compatibility views and existing tables while migrating). Capture: request/usage id, provider/plan/endpoint/capability, consumer, run id, instrument, request signature, credit estimate, reserved/actual billable cost, timestamps, status/http response, provider reset clock, cache flag and error reason.
- Guard reservation with a database-atomic transaction/lock that checks *all* applicable minute/hour/day/capability/reserve windows and concurrent leases.
- Ensure idempotency: one external attempt links to one reservation, retries are counted per provider billing rules, a canceled/expired reservation cannot be spent twice.
- Finalize outcomes SUCCESS, BILLABLE_FAILURE, QUOTA_BLOCKED, PROVIDER_ERROR, RELEASED/EXPIRED as applicable. HTTP 429 respects `Retry-After`/reset; no immediate retry loop.
- Acceptance: N concurrent workers with one credit left create at most one permitted billable call; no overruns at daily/minute boundaries; blocked calls do not silently invoke providers; accounting survives crashes.

**PR 4 — Cache First + Single-flight + Scheduler**
- Cache key: canonical instrument identity + provider/endpoint/capability + parameters/currency + session/adjusted semantics (not ticker alone).
- On FRESH cache hit, return observation ID with **zero** new external calls. On identical in-flight request, join the existing refresh/result; use distributed leases/expiry/recovery.
- Introduce prioritization P0 held assets, P1 focused opportunities, P2 active research, P3 watchlist, P4 broad scanner. Preserve protected capacity for P0 and emergencies; manual refresh never bypasses quota.
- Centralize worker dispatch; no direct external calls in new production consumers.
- Acceptance: 20 simultaneous requests for identical eligible quote result in `<=1` provider call per compatible batch/request key; P4 cannot consume protected reserve; quota-low state degrades cleanly.

**Release A exit gates:** every migrated provider path is observed and gated; global quota/race tests pass; authorization secrets stay server-side; basic usage/remaining/reset/failure telemetry visible. **Do not cut over new consumers yet.**

### P1 — Release B: Market data and portfolio (after Release A)

**PR 5 — Canonical Market Price Service**
- Reuse `market_observations` and `v_portfolio_market_quote_current` legacy compatibility where verified.
- Expose `fwios.v_market_price_current` or a safe service contract with `instrument_id, asset_symbol, asset_class, price_usd, currency='USD', provider, source_tier, observation_id, observed_at, valid_until, market_status, freshness_status, provenance_status, price_gate`. Do not return THB-valued asset prices as authoritative. Preserve original raw-source currency observations for audit, never overwrite historical THB with USD labels.
- Cover **all** investable instruments with native USD canonical market prices: ingest CoinGecko six-crypto batch using `vs_currencies=usd` through the verified provider quota; US stock/ETF observations already mostly USD. Keep USDTHB only as a distinct FX reference for display/accounting conversion in Google Sheets. A missing native USD quote returns blocked/missing, not stale FX-derived USD promoted to production.
- Respect exchange sessions; after-hours and last-close are explicit, not faked LIVE. Batch requests when provider credit semantics permit.
- Keep exposed views secured (view-RLS implications, least-privilege role access) and service credentials out of Sheets/frontends.
- Acceptance: same asset price/observation ID across participating consumers, source provenance readable, stale candidate decision blocked.

**PR 6 — Tracker Market Data Import + Shadow Comparison**
- Add hidden `_Market_Data` tab and authorized import of `price_usd`, currency USD, observation identity, timestamps and price_gate from the canonical price service; no provider keys in cells, no duplicate Supabase-calculated THB asset-price feed. Google Sheets owns USDTHB conversion and must mark invalid/stale FX rather than silently accepting a fixed fallback.
- Leave `Transactions` and `Holdings` accounting formulas intact; calculate side-by-side old vs new `Price Data` values.
- Include cash/fixed-value treatment and every open instrument, not merely symbols present in scanner or old price view.
- Capture snapshots across Best / Loan Money / Mom / ALL, including source row integrity and timestamps.
- Acceptance: all open holdings have valid price or explicit missing/stale state; parity report and differences signed off.

**PR 7 — Portfolio Valuation Cutover**
- Gate `Price Data` → `Holdings` → `Portfolio Value` / `Unrealized P&L` on approved canonical **USD** quote observations and separately validated USDTHB conversion within the Tracker; continue calculating quantity and cost basis only from Tracker transactions.
- Reconcile within `<= THB 0.01` for sums using the same exact observation set and agreed rounding; do not use price drift from mismatched timestamps as accounting defects.
- Preserve last known value with a visible STALE/QUOTA_BLOCKED status when necessary, but never authorize investment decisions from blocked prices.
- Remove direct production CoinGecko/GOOGLEFINANCE price calls *after* parity and monitoring tests, not before.
- Acceptance: no trading records changed, no forced rebalance, no automated execution, rollback via feature flag verified.

### P2 — Release C: Research and scanner (after protected service operates)

**PR 8 — Focused Dashboard Ownership Cleanup**
- Remove trade-entry/transaction ledger and portfolio accounting UI/refresh dependencies.
- Retain Market Overview, S&P 500 Opportunity Scanner, Valuation, Research Lifecycle, Thesis Monitoring and Decision Support.
- Optional portfolio context is read-only/summarized from Tracker with explicitly limited scope; no parallel Supabase ledger.
- Preserve FWIOS quality/hardening, thesis-memory, decision, approval and no-auto-trade regression behaviour.
- Acceptance: account-agnostic scanner remains functional; no BUY/SELL records or cost-basis math in Focused Dashboard.

**PR 9 — Quota-Aware Tiered Scanner**
- Stage 1: low-cost cached/batched universe (~500); Stage 2: optional enrichment for top ~100; Stage 3: selective deeper research of ~20–50 and narrower FULL_THESIS candidates.
- Implement pre-run request **and credit** estimation per endpoint, active reservation/remaining quota check, degradation plan and resume/retry checkpoints.
- Prioritize holdings and focused opportunities; P4 broad scan cannot borrow emergency reserve.
- Acceptance: run refuses or shrinks when estimated credits exceed available discretionary budget; scanner executes without starving holdings.

### P3 — Release C completion: Observability and legacy retirement

**PR 10 — Advanced Observability + Legacy Deprecation**
- Display provider status, limit, used, reserved, remaining, reset time, hit ratio, fail/429 rate, latency, freshness coverage, run-level cost and per-consumer spend; alerts at configured 70/90/100% plus anomaly thresholds.
- After PR 7–9 compatibility and regression sign-off, stop new writes to legacy Supabase portfolio accounting tables/jobs; keep historical snapshots/rollback support.
- Remove obsolete API integrations, views and functions only with a verified dependency inventory and separate cleanup authorization.
- Acceptance: no live accounting writer left, no silently stale prices, historical records not deleted.

## 2. Dependency graph

```text
PR1 Contract & inventory
  → PR2 Provider/policy
  → PR3 Atomic reservation/usage
  → PR4 Cache + single-flight + priority
     ├→ PR5 Canonical price
     │   → PR6 Tracker shadow
     │      → PR7 Tracker cutover
     │         → PR8 Dashboard cleanup ─┐
     └────────────────→ PR9 Scanner ◄─PR5
                                        ├→ PR10 Observability/retirement
     PR7 ────────────────────────────────┘
```

Basic quota telemetry belongs to PR 3–4 (P0); PR 10 covers enhanced UI, alerting and deprecation. PR 8 and PR 9 can be parallel after their stated prerequisites.

## 3. Detailed runtime and capability policy

| Runtime P | Capability/consumer | Scarcity behaviour |
| --- | --- | --- |
| P0 | Owned holdings price/FX, critical recovery | Highest protected allocation; best available *verified* price, explicit freshness |
| P1 | Immediate/focused opportunities | Preserve where possible after P0 |
| P2 | Active research / thesis / earnings | Defer optional enrichment |
| P3 | Watchlist | Extend cache use / throttle |
| P4 | Broad S&P 500 discovery | Reduce breadth first |

Proposed budget categories: Holdings 25%, Focused 25%, Research 20%, Broad Scan 20%, Emergency 10%, **subject to actual plans**. Watchlist shares applicable discretionary buckets; no implied extra 5%. Per-capability budgets coexist with global provider limits and must not sum beyond available credits. Protect enough reserve for existing holdings and manual recovery; emergency eligibility is **audited**, not a bypass.

Recommended TTL defaults: crypto 5–15m (24/7), equities while open 5–15m, equities closed until next relevant exchange session, FX 15–60m, daily close one session, fundamentals 24h+ or after material filings, company metadata 7–30d, constituents daily/weekly.

Failures: distinguish `FRESH`, `LAST_CLOSE`, `STALE`, `FALLBACK`, `QUOTA_BLOCKED`, `PROVIDER_ERROR`, `MISSING`. A cached value can be displayed for orientation with timestamp but never pass a freshness-dependent trade/decision gate. No quote provider retry on 429 until allowed by provider reset/Retry-After; paid retries must also reserve credits.

## 4. Regression test matrix and Definition of Done

| Test ID | Scenario | Expected |
| --- | --- | --- |
| Q-01 | Provider not in registry / missing policy / inactive | Deny and log; no external call |
| Q-02 | Minute, hourly, daily, endpoint and capability ceilings | None exceeded by concurrent workers |
| Q-03 | Last available credit concurrently requested by workers A/B | At most one billable call allowed |
| Q-04 | Reservation crashes / stale worker lease | Safe recovery; no duplicate spending |
| Q-05 | Repeated requests for one fresh observation | Zero additional provider calls; unchanged observation ID |
| Q-06 | 20 identical concurrent requests | Single-flight: at most one compatible provider request |
| Q-07 | Provider 429 / 5xx / timeout | Bounded retries; correct credits/logging; no rate-limit spin |
| Q-08 | Provider-specific reset at non-Bangkok midnight | Correct window accounting across DST/UTC offsets |
| Q-09 | Batch pricing vs per-symbol credit schedule | Optimal valid batching; request and billable credit counts correct |
| Q-10 | P4 scan when little quota left | Shrink, cache or defer, preserving P0 reserve |
| Q-11 | 500 stocks × many endpoints estimate exceeds balance | No full run starts; clear estimated cost |
| Q-12 | Equity market closed, crypto 24/7, FX fallback | TTL/session/provenance correct; no false LIVE |
| Q-13 | Same NVDA quote consumed by Sheet/Scanner/Research | Same canonical observation; no duplicate provider call |
| P-01 | Best, Loan Money, Mom, ALL holdings reconciled | Quantity, cost basis, realized P&L unchanged |
| P-02 | Portfolio Value vs SUM(Holdings Value) | Difference <= THB 0.01 for same observation set |
| P-03 | Missing price / exhausted quota during valuation | Last-known value labeled, decisions fail closed, no crash |
| S-01 | Old trade APIs / Supabase ledger deprecation | No new writes only after verified cutover; rollback intact |
| SEC-01 | Sheet/API secret exposure and backend access | No secrets in Sheet or repository; least-privilege access |
| D-01 | Approval/decision / no-auto-trade compatibility | Historical decision and human-execution gates unchanged |

**DoD:** no provider call without cache, quota reservation and logging; one fetched observation serves many downstream consumers; P0 remains protected; scanner fails gracefully; both Sheets consume canonical prices after explicitly signed-off cutover; transaction SoT is exactly the Tracker; no irreversible legacy deletion.

## 5. Operational ownership and rollback

- **GitHub:** contracts, migration code, deterministic tests and PR review history.
- **Supabase:** shared market observations, cache, provider/quota/usage infrastructure, research and decision state.
- **Portfolio Tracker:** executed trades, holdings quantities, cost basis and realized/unrealized accounting after explicit cutover.
- **Focused Dashboard:** discovery/research/decision and optional authorized read-only portfolio summary, not transaction accounting.
- **Operator:** confirm provider plan limits, approve credential rotation, verify account reconciliations and approve each production cutover.

On any gate failure: stop new background jobs, preserve or restore last verified production read path, label stale prices, retain all transaction/observation history, and investigate the failing reservation/capability boundary before resuming.

**Review policy:** This document PR is documentation-only. It does not perform a quota migration, Sheet formula change, Edge Function deploy, token rotation, or active-authority switch.
