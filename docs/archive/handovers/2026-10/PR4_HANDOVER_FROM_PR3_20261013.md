> **ARCHIVED HANDOVER — HISTORY ONLY (archived 2026-10-20).** Describes the state as documented on its original date; **not** an instruction to execute today. Start at [Current Status](../../../CURRENT_STATUS.md) and verify live services before further work.

# FWIOS v3 — PR4 Handover from PR2/PR3
**Prepared:** 2026-10-13 (Asia/Bangkok)  
**Next task:** PR4 — Cache First + Single-flight + Priority Scheduler  
**GitHub repo:** `ChumponphatRangsee/focused-wealth-investment-os`  
**Supabase project (owner-approved Production-as-test):** `ysjbmeukwbfnxnwqchuq`  
**New chat context:** Start a new chat in the **Investment project**, provide this document path and instructions. This handover itself does NOT start PR4.

## 1. Architectural decisions that MUST survive chat handoff

- No separate Local Supabase CLI, Docker Staging, or additional paid Supabase project at this point. The OWNER EXPLICITLY AUTHORIZED using the existing Supabase Production project as a TEST environment. It is **not isolated**, so use QA fixtures, read-only checks, and transaction-rollback tests when possible; require careful approval and cleanup for persistent QA tests. Do not describe Production-as-test as safe by default.
- Reuse the live `fwios` schema, price observations, provider registry, quota policies, and historical usage tables. **No duplicate ledger, provider registry, or generic market-data cache table without clear proof it is necessary.**
- Investment Portfolio Tracker - Chumponphat (Google Sheets) remains the **single transaction/accounting source of truth** in the target architecture. Supabase handles provider market data/API limits/shared research; Focused Wealth Dashboard - Chumponphat is for stock scanning/research. External APIs are used across both consumers. Do not move or duplicate Google Sheets transaction writes.
- Preserve all production price/usage/portfolio/transaction history; no broker trades, no automatic trading; do not replace data in real holdings with synthetic data.
- New provider route/paid API dispatch **fail-closed** unless plan, reset timezone, endpoint credit cost, concurrency constraints and active-policy flags are verified. Never infer paid entitlement from an internal config string or from historical usage.

## 2. Pull requests and current real deployment (verified October 13)

| Work | GitHub | Production Supabase database | Cutover |
|---|---|---|---|
| PR2 Registry + quota policy | [PR #49](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/49) | Migration APPLIED | OFF |
| PR3 Atomic + unified logical usage | [PR #50](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/50) | TWO migrations APPLIED | OFF |
| PR4 Cache first/single-flight/priority | **not started** | No PR4 changes | OFF |

Both PR #49 and #50 are **DRAFT, open, NOT MERGED**. PR #50 targets the PR2 branch, `feat/pr2-unified-provider-quota-policy`; its head is `feat/pr3-atomic-unified-quota`. Do not make PR4 against `main` without checking stacked-branch dependency. Recommended PR4 base before PR2/3 merge: `feat/pr3-atomic-unified-quota`. Rebase after parent merges.

Supabase applied migrations:
1. `fwios_pr2_unified_provider_registry_quota_policy_v1`
2. `fwios_pr3_unified_usage_atomic_reservation_v1`
3. `fwios_pr3_legacy_quota_reservation_bridge_v1`

Existing provider sources: `fwios.decision_refresh_provider_registry`, `fwios.market_daily_close_policy` (Twelve), `fwios.decision_refresh_api_quota_policy` (Alpha). Unified read-only logical ledger: `fwios.v_api_usage_unified_v1`, over `fwios.decision_refresh_api_usage` and `fwios.market_daily_close_api_usage`. PR3 DB functions:
- `fwios.reserve_api_quota_unified_v1`
- `fwios.mark_api_quota_dispatched_v1`
- `fwios.finalize_api_quota_usage_v1`
- PR3 legacy compatibility replacements of `reserve_decision_refresh_api_call_v1` and `reserve_market_daily_close_api_call_v1` use the same provider-group advisory lock.

**Production verification 2026-10-13:** historical usage Alpha Vantage **353**, Twelve Data **3,232**; QA test provider rows **0**, QA usage rows **0**. These are a checked snapshot, not guaranteed future live counts.

Old production Cron schedules and Edge Function code were not redeployed when PR3 database migrations were installed. In particular, the real `portfolio-mtm-refresh-v1` can call CoinGecko and Frankfurter without centralized quota reservation. **DO NOT assert end-to-end quota safety or claim full PR3 rollout.**

## 3. PR3 tests: actual results, not aspirational checkboxes

- PR2 read-only resolver policy + access tests: **PASS** on Production-as-test.
- PR3 rollback-only synthetic SQL regression: **PASS** (fail-closed, idempotency, credits, DISPATCHED gate, refund-before-dispatch, HTTP 429 Retry-After, compatibility). All transaction-bound synthetic data rolled back.
- Five separate concurrent Supabase DB calls against a fake `QA_` provider with just 1 credit: **PASS: 1 allowed, 4 denied, 0 errors**. Fake QA rows removed and 0 remaining.
- Mock offline provider fixture suite: **PASS 9/9** in [GitHub Actions run 38345362134](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/actions/runs/38345362134), using no database access, secrets, or provider HTTP calls. Its adapter is **standalone**; it is NOT the deployed Edge Worker code.
- **20 concurrent independent database sessions: NOT PASSED/NOT VERIFIED.** A connector limit interrupted the earlier orchestration, and that QA data was cleaned to zero. Do not report 20/20 pass.
- Edge Worker Mock Transport parity/E2E: **NOT IMPLEMENTED**.
- Provider true plan limits, endpoint billing, reset/DST and all caller quota cutover: **NOT VERIFIED**.
- PR #50 remains draft for these reasons.

Available files:
- `docs/implementation/API_QUOTA_IMPLEMENTATION_PLAN.md` (canonical roadmap)
- `docs/architecture/FWIOS_ARCHITECTURE_V3.md` (architecture)
- `docs/implementation/PR3_ATOMIC_QUOTA_UNIFIED_USAGE.md` (PR3 implementation/results)
- `tests/market/test_unified_api_quota_pr3_staging.sql` (rollback-only tests also authorized for Production-as-test)
- `tests/market/pr3_atomic_concurrency_staging.py` (independent 20-session stress; guard currently requires STAGING, not directly runnable against Production without redesign)
- `tests/market/fixtures/pr3_mock_provider_scenarios_v1.json` (deterministic fake fixtures)
- `tests/market/pr3_mock_provider_harness.py` (standalone offline mock adapter)
- `.github/workflows/pr3-mock-harness.yml` (CI)

## 4. PR4 exact scope

**Goal:** reuse a fetched observation across Portfolio/Scanner/Research, avoid duplicate external API requests, preserve highest-priority held-asset refreshes under scarce API credits, and integrate with the PR3 atomic reservation lifecycle. Scope covers **cache freshness, deduplication/single-flight, job priority, retry-aware failover and observability**, without importing transaction ledger work or prematurely cutting over market-data consumers.

Proposed ordered request flow:
1. Normalize the canonical instrument ID (NOT ticker alone), provider, endpoint/capability, adjusted semantics, period/session, currency, request parameters and effective consumer.
2. Check existing canonical market observations/snapshots (not generic dashboard payload cache). Fresh response => return observation ID, source, timestamp and freshness with **zero** provider HTTP and quota reservations.
3. If no fresh compatible record, join/await an existing **same-key** in-flight request (single-flight with bounded lease, ownership, expiry, timeout/crash recovery; no duplicate external dispatch). Preserve correct provider reset/billing semantics on failure.
4. If no in-flight owner, evaluate priority: P0 actually held instruments and portfolio price/FX, P1 focused actionable ideas, P2 active research, P3 watchlist, P4 broad scanner. Ensure non-P0 workloads cannot consume an explicitly configured, verified protected P0 reserve; no guessed budget or double subtraction of Twelve Data historical 100/day headroom.
5. Before HTTP, use PR3 protocol **reserve -> mark DISPATCHED -> exactly one provider network attempt -> finalize** (success/error/429 actual billable credits), with stable idempotency, no unlimited provider fallback. On cache hit no new quota usage. Vendor/account effective limits apply across all consumers and active workers. Manual refresh never bypasses quota.
6. Validate and publish *canonical* observation and provenance, then release waiting requests. Return explicit `FRESH`, `LAST_CLOSE`, `STALE`, `FALLBACK`, `QUOTA_BLOCKED`, `PROVIDER_ERROR` or `MISSING`; no stale data may masquerade as live or be permitted for freshness-dependent decision/valuation gates.
7. On low quota, degrade P4 scope, delay enrichment, respect 429 Retry-After, and always retain the approved P0 protection. A fallback provider also needs independent policy, freshness and quota check.

**Existing infrastructure to inspect and reuse**:
- `fwios.market_observations` (canonical record candidates)
- `fwios.portfolio_market_quote_snapshots`, `fwios.v_portfolio_market_quote_current` (current quote paths)
- `fwios.dashboard_refresh_cache` (dashboard payload cache **NOT identical to market quote cache**)
- job tables/pgmq/cron used by `market-daily-close-worker-v1`, `decision-refresh-worker-v1`, `portfolio-mtm-refresh-v1`, provider validators and scanners
- PR2 provider policy and PR3 quota/usage protocol above.

## 5. Guardrails / design hazards

- One Supabase **Production** DB is shared with active real workers and cron. NEVER insert fake ticker/holding/trade rows into real canonical portfolio/price tables without strict isolated test identity and full recovery; prefer controlled QA-only synthetic provider accounts and rollback.
- Introduce no real provider HTTP calls during mock tests. Do not store live vendor API secrets in fixtures, logs, GitHub or PR comments.
- Shared cache identity must encode all semantics; do not merge adjusted/unadjusted, currency, timeframe or session values accidentally.
- Make cache TTL explicit per asset/type/exchange/session; do not mark old daily close as real-time spot; honor closed markets and weekends. Separate stale-while-revalidate display from freshness-critical investment decision permission.
- Distributed single-flight must work across independent Edge Workers/DB connections; an in-memory map alone is insufficient.
- Distinguish request-key replay from *joining* an existing live single-flight result. PR3 returns `allowed=false` for replay; PR4 should wait/read the existing observation, not start a second HTTP call.
- Be wary of existing legacy workers bypassing new three-step gate. An additive PR4 is not a production cutover until all provider routes are inventoried and gated.
- Two providers share no entitlement by implication. Validate Alpha budgets 25/day (PRICE 15/VALIDATOR 2/RESERVE 3), Twelve worker 8/min + 700/day with a separate 100/day headroom; these are **existing operational config**, not verified vendor guarantees.
- Use service-only RPC/functions in private `fwios`; anon/authenticated must not gain execute rights. Rollback any synthetic test fixtures. Never merge PR2/3/4 without explicit acceptance.
- Google Sheets tracker remains transaction authority. External APIs service both Portfolio Tracker and Focused Dashboard via shared market data, not two accounting ledgers.

## 6. PR4 tests / acceptance criteria

A. **Cache**: fresh canonical observation returns same source/observation ID with 0 new HTTP calls and 0 new quota reservations; stale/missing route correctly to a refresh or explicit blocked/fallback result.
B. **Single-flight**: 20 simultaneously arriving identical quote requests, using *independent sessions*, generate **at most 1 compatible provider dispatch** and one published observation; retries and crash recovery do not double bill. Tests should use a provider-neutral mock, no live API.
C. **Isolation**: requests with different canonical instrument, currency, adjusted flags, endpoint or session do NOT coalesce or return an incompatible observation.
D. **Priority**: P0 protected credit reservation holds even under aggressive P4 scanner pressure; low-quota P4 shrinks or defers. Deliberate missing/unverified P0 reserve should fail-closed rather than silently permit P4.
E. **Resilience**: HTTP 429, 5xx, provider timeout, lease expiry, DST/reset boundary, stale cache, worker retry and cancel-before-dispatch are deterministic and bounded; no rapid retry storm.
F. **E2E**: mock transport runs through the **same adapter/business logic as actual Edge Function**; standalone Python normalizer does not by itself satisfy E2E.
G. **Security/cleanup**: 0 leaked QA records, no service credentials in frontend/fixtures, no real transaction/holding writes, no unforeseen extra API credits.
H. **Release gate**: PR3 20-session atomic stress and verified vendor-plan settings remain OPEN blockers for *full production cutover*; implementation can proceed in draft without activating consumers.

## 7. Handover request to next chat

> Work in the **Investment project**. Read `docs/implementation/PR4_HANDOVER_FROM_PR3_20261013.md` on GitHub branch `feat/pr3-atomic-unified-quota`, then `docs/implementation/API_QUOTA_IMPLEMENTATION_PLAN.md` and `docs/architecture/FWIOS_ARCHITECTURE_V3.md`. 
>
> Implement **PR4 Cache First + Distributed Single-flight + Priority Scheduler** using existing Supabase infrastructure. First inspect actual live schema, Edge Functions, queues, cron jobs and vendor policy. Avoid creating duplicate tables and do not use Local Supabase CLI or a new Staging project. Use the existing Supabase production project **only as the user-authorized test environment** with QA-isolated mocked network responses and careful cleanup. Create a **draft stacked GitHub PR targeting `feat/pr3-atomic-unified-quota`** while PR2/3 remain unmerged. Write functional, concurrency, no-credit-on-cache-hit, P0-vs-P4, 429/stale/failover and E2E parity tests, execute what is safe, and report actual passes vs pending blockers. Don't cut over workers or merge PRs until explicit release gates pass; preserve Sheets' transaction authority and existing production history.
