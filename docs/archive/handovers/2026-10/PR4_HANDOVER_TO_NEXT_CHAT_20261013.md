> **ARCHIVED HANDOVER — HISTORY ONLY (archived 2026-10-20).** Describes the state as documented on its original date; **not** an instruction to execute today. Start at [Current Status](../../../CURRENT_STATUS.md) and verify live services before further work.

# FWIOS v3 — PR4 Implementation Handover to Next Chat

**Prepared:** 2026-10-13 (Asia/Bangkok)  
**Repository:** `ChumponphatRangsee/focused-wealth-investment-os`  
**Project:** `Investment project`  
**Current head branch:** `feat/pr4-cache-singleflight-priority`  
**Stacked PR:** [Draft #51](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/51) **base =** `feat/pr3-atomic-unified-quota`  
**Parent PRs:** [Draft #50 / PR3](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/50) base = `feat/pr2-unified-provider-quota-policy`; [Draft #49 / PR2](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/49) base = `main`.  
**Supabase:** Existing **Production-as-test** project `ysjbmeukwbfnxnwqchuq` (no new Staging Project or Local Supabase CLI).

> **NON-NEGOTIABLE:** All 3 PRs remain open, DRAFT, UNMERGED; production worker dispatch/cutover OFF. Never merge, change live Cron, redeploy existing production worker paths, activate unverified provider settings, or modify actual transactions/holdings. Production database PR2–4 migrations ARE APPLIED; do not claim that the database was left unchanged.

## 1. Work completed in PR4

- Inspected live `fwios` schema, `cron.job`, PGMQ, Edge Functions, provider registry/policies and PR3 reserve/dispatch/finalize RPC signatures.
- Reused existing `fwios.market_observations` as canonical market-price storage; `fwios.v_api_usage_unified_v1` + original two usage tables for quota history. Did NOT create another usage ledger or transaction ledger. `fwios.dashboard_refresh_cache` is unrelated to quote identity.
- Added **one internal flight-coordination table**, `fwios.market_refresh_flights_v1`, because existing decision/daily-close job tables cannot represent a cross-consumer SHA-256 request key, lease, owner, and published observation. This is job-state metadata, not a price cache.
- Implemented strict cache match (canonical instrument, provider, endpoint/capability semantics in SHA key, adjustment, period, session, currency, request params), tagged immutable observation reuse, short bounded TTL, `FRESH` vs `LAST_CLOSE`.
- Distributed flight JOIN / claim, `SELECT ... FOR UPDATE SKIP LOCKED`, priority **P0 Holdings > P1 Focused Opportunities > P2 Research > P3 Watchlist > P4 Scanner**. Non-QA P0 requires a verified current holding; standalone FX P0 handling still needs design review before cutover.
- Shared TS orchestration: **Cache → Join/Queue → Claim → PR3 Reserve → Mark DISPATCHED → one injected provider transport attempt → Finalize → publish immutable observation**. Cache hit never reserves quota. Denied quota never calls provider. 429/timeout/5xx, conservative credit charge, Retry-After, provider-specific fallback; expired-dispatched lease becomes `UNCERTAIN` rather than auto-retry.
- QA-only Edge Adapter source exists but is **NOT DEPLOYED**. Separate token and `FWIOS_PR4_MOCK_ONLY` gate; no live provider adapter/calls.
- Implemented QA isolation: scoped `pr4_claim_market_refresh_v1(worker_uuid, true)`, scoped service_role grant, old unscoped service_role EXECUTE revoked; anon/authenticated denied.
- Added rollback-only SQL regressions; GitHub Actions same-core deterministic mock E2E suite; guarded independent-session cloud `psql` harness (not executed).

## 2. Files to read FIRST in the new chat (on PR4 head branch)

1. `docs/implementation/PR4_HANDOVER_TO_NEXT_CHAT_20261013.md` (this file)
2. `docs/implementation/PR4_CACHE_FIRST_SINGLEFLIGHT_SCHEDULER.md` (full PR4 implementation + receipts)
3. `docs/implementation/PR4_HANDOVER_FROM_PR3_20261013.md` and `docs/implementation/PR3_ATOMIC_QUOTA_UNIFIED_USAGE.md`
4. `docs/implementation/API_QUOTA_IMPLEMENTATION_PLAN.md` and `docs/architecture/FWIOS_ARCHITECTURE_V3.md`
5. `migrations/20261013_pr4_cache_singleflight_scheduler_v1.sql`
6. `migrations/20261013_pr4_qa_scoped_claim_hardening_v1.sql`
7. `supabase/functions/_shared/pr4_core.ts` and `supabase/functions/market-refresh-orchestrator-v1/index.ts`
8. `tests/market/test_pr4_cache_singleflight_rollback.sql`
9. `tests/market/pr4_mock_e2e_test.ts`
10. `tests/market/pr4_independent_20_session_qa.py` and `.github/workflows/pr4-mock-e2e.yml`

## 3. Verified execution receipt at handover

| Check | Result |
| --- | --- |
| PR49 / PR50 / PR51 state | **Open, DRAFT, UNMERGED** — verified via GitHub |
| Parent/base | PR51 → PR3 branch; PR50 → PR2 branch; PR49 → main — verified |
| PR2 DB | migration `20261013034243` already applied |
| PR3 DB | migrations `20261013034324`, `20261013034509` already applied |
| PR4 DB | `fwios_pr4_cache_singleflight_scheduler_v1` **APPLIED** (`20261013043447`) |
| PR4 hardening DB | `fwios_pr4_qa_scoped_claim_hardening_v1` **APPLIED** (`20261013044037`) |
| SQL regression | **PASS** in one `BEGIN ... ROLLBACK` session; rerun after scope hardening PASS |
| Security | Service role scoped claim allowed; unscoped service claim denied; anon denied; RLS enabled |
| QA cleanup | **PASS: 0 QA providers, 0 QA flights, 0 QA instruments, 0 QA observations, 0 QA usage rows** (post-rollback read-back in prior turn) |
| Actions same-core TS mock test | **PASS 10/10**, 0 failures |
| Actions latest at handover | [Run 38347915951](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/actions/runs/38347915951) **SUCCESS** at then-current head `a09ba3bdcbfe5a9a959b362be40b873733475799` |
| Python independent-session harness | **Syntax compiled in CI only**; NOT executed against DB |
| 20 independent DB connections | **NOT VERIFIED** (PR3 and PR4) |
| Edge HTTP Mock E2E | **NOT IMPLEMENTED/EXECUTED on deployed Edge**; adapter source exists |
| Vendor plans / real credit rules / reset/DST / 429 | **UNVERIFIED** |
| Existing cron and workers | No PR4 cutover or schedule changes; eight existing cron jobs active at end of previous turn |

**Important test precision:** The 20 simultaneous requests in TS mock tests share an in-process mock gateway. They are **NOT** 20 PostgreSQL connections, and offline shared TS code is not proof of actual deployed Edge-worker parity. The earlier PR3 5-call smoke did pass 1 grant/4 denials; its attempted 20-call connector run was inconclusive. Earlier initial PR4 CI failures were fixed; cite latest PASS only with the precise scope.

## 4. REQUIRED next tasks, in order

### A. Validate PR4 source and address safety/correctness blockers
- Review both applied migrations and source adapter for proper QA-only fencing, privilege/RLS, cache-key canonicalization, observation freshness/session semantics, priority authenticity, lease/retry/crash race conditions and observation publication idempotency.
- Review especially live-P0 FX refresh authorization, attempts in `UNCERTAIN`, stale/last-close valuation gates, provider policy verification, quota side effects and fallback policy gating. Do **not** activate live dispatch to find out.
- Check that `market_refresh_flights_v1` has no actual portfolio/transaction identifiers beyond canonical instrument and work metadata, and that deployed workers remain unchanged.
- Run read-only advisors and schema/permission checks; treat informational existing RLS-without-policy notices in context, do not open frontend access.

### B. Complete PR3 + PR4 20 independent-session QA tests
- Use the existing authorized **Production Supabase as Test**; QA identity isolated, mock provider and fake instrument, **NO vendor HTTP**. No Local Supabase CLI and no new Staging Project.
- Script **already authored**: `tests/market/pr4_independent_20_session_qa.py`. It uses 20 independent `psql` subprocesses from an ephemeral runner, guarded by `FWIOS_PR4_PRODUCTION_AS_TEST=YES`, `FWIOS_EXPECTED_SUPABASE_REF=ysjbmeukwbfnxnwqchuq`, and secure `FWIOS_QA_DATABASE_URL`. **Never put credentials in GitHub, logs, PR comments or messages.** No DB stress has actually been run.
- Validate that QA provider settings mimic a strictly synthetic 1-credit account and cannot alter live vendor registry or real usage. Review retry behavior and cleanup `finally` before executing. Report exact connection count, result breakdown, actual usage rows, lease/dispatch results, and verified cleanup. If secure authorized credential delivery is unavailable, leave PENDING, do not invent a PASS.
- PR3 has a separate older staging-only runner `tests/market/pr3_atomic_concurrency_staging.py` which requires redesign/approval if used against Production-as-test; do not bypass its guards by lying about staging.

### C. Deployed Edge Mock E2E (QA ONLY)
- Before any deployment, review the Edge adapter, JWT and separate automation token, mock-only flag, explicit QA-only claim, and any risk of interaction with old Cron/Workers.
- Only test actual deployed Edge transport after securely provisioned QA auth and verified data-isolation gates. Current mock adapter source alone does **NOT** fulfill this acceptance.
- Measure real DB Reserve→Dispatch→Finalize, cache-hit 0 additional provider reservations, 20 coalesced requests, 429, timeout, stale, fallback, crash recovery and zero QA cleanup. Never route to real vendor HTTP.

### D. Release criteria before any live cutover
- Verify provider plan/account sharing, endpoint-specific credit/billing, minute/hour/day/concurrency windows, P0 protected capacity, vendor reset timezone/DST and real Retry-After/429 semantics.
- Inventory and migrate **every** external HTTP path: existing `portfolio-mtm-refresh-v1` direct CoinGecko/Frankfurter bypass, old Twelve/Alpha and any validators/retry workers. New consumers must share the canonical provider service; manual refresh never bypasses quota.
- Validate P0 vs P4 under quota pressure, 20-session atomicity, Edge parity, stale valuation permissions, telemetry, canary rollback, and no corruption of Sheets source of truth.
- Keep PR #49/#50/#51 **DRAFT and unmerged**, old Worker/Cron unchanged and provider cutover OFF until ALL required safety/acceptance gates pass and the owner explicitly approves.

## 5. Architecture invariants
- **Investment Portfolio Tracker - Chumponphat (Google Sheets)** is the one source of truth for **Transactions and Accounting**.
- Supabase is **Shared Market Data / Price / Research / API quota infrastructure**; no duplicate transaction or accounting ledger.
- **Focused Wealth Dashboard - Chumponphat** focuses on **S&P500 Scanner + Research**, not trade accounting.
- Reuse existing provider registry, two historical usage tables, PR3 logical usage view and canonical market observations. No live trade/holding/transaction edits.
- Production-as-test is shared with real data; every test needs explicit QA isolation, preferably single-session rollback, and verified after-test cleanup. Never count external API usage unless a mocked end-to-end network attempt has actually been performed.

## 6. Handover prompt for the next chat

> Continue FWIOS v3 **PR4 — Cache-First, Distributed Single-Flight & Priority Scheduler** in the **Investment project**. First read `docs/implementation/PR4_HANDOVER_TO_NEXT_CHAT_20261013.md` and `docs/implementation/PR4_CACHE_FIRST_SINGLEFLIGHT_SCHEDULER.md` from GitHub repo `ChumponphatRangsee/focused-wealth-investment-os`, branch `feat/pr4-cache-singleflight-priority`. PR #51 is draft stacked on PR #50, which is stacked on PR #49. The two PR4 Supabase migrations were already applied to Production-as-test project `ysjbmeukwbfnxnwqchuq`, rollback-only SQL QA passed with zero residues, and GitHub Actions same-core mock tests passed 10/10. **Do not rerun applied DDL or misstate 20 independent sessions as complete.** Continue with a security/code review, then complete genuine independent 20-DB-session PR3/PR4 stress and deployed QA-only Edge Mock E2E only where authorized credentials and strict isolation permit. Verify cleanup every time. Maintain P0 protected quota and PR3 Reserve→Dispatch→Finalize. Do not create another Supabase project, use Local CLI, duplicate ledgers, call real APIs unnecessarily, modify actual Sheets transactions/holdings, merge PRs or cut over existing Workers/Cron. Report precise passes, pending gates and blockers.
