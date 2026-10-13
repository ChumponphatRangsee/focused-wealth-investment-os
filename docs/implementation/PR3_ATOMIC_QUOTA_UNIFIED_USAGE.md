# PR 3 — Atomic Quota Reservation & Unified Usage

**Status (2026-10-13):** DB migrations APPLIED to the existing Production Supabase project, used as the owner's authorized test environment. GitHub PR remains DRAFT / stacked on PR 2 / UNMERGED. New worker dispatch cutover is OFF; legacy v1 quota reservation bodies ARE replaced by the compatibility bridge.

## Reuse existing Supabase

Keep both historical ledgers:
- fwios.market_daily_close_api_usage (Twelve Data)
- fwios.decision_refresh_api_usage (Alpha Vantage, and new providers without their own older ledger)

The view fwios.v_api_usage_unified_v1 is a read-only UNION ALL; no new usage table or second physical ledger. Add nullable metadata, idempotency, dispatch, credit and lifecycle columns to existing tables.

## SQL deliverables

- migrations/20261013_pr3_unified_usage_atomic_reservation_v1.sql
- migrations/20261013_pr3_legacy_reservation_bridge_v1.sql

New internal-only functions:
- reserve_api_quota_unified_v1: account-scoped advisory lock, centralized policy lookup, credit-cost budgets, minute/hour/day/concurrency, priority capacity, cooldown, idempotency
- mark_api_quota_dispatched_v1: required lease/state transition before external network call
- finalize_api_quota_usage_v1: immutable completion, 429/Retry-After, conservative billing, restricted pre-dispatch refund

## Required network-call sequence

1. Return valid fresh cache data without calling a provider or reserving credits.
2. Request a new unique-attempt-key reservation. If denied, STOP.
3. Mark the reserved usage ID DISPATCHED (with bounded provider timeout). If denied, STOP.
4. Perform exactly one provider HTTP attempt.
5. Finalize SUCCESS, BILLABLE_FAILURE or PROVIDER_ERROR, recording actual credits, status and Retry-After.
6. Only if HTTP was never started, finalize RELEASED with provider_called=false; after dispatch refunds are rejected.
7. Retry means a new attempt key and new budget check. Duplicate keys never grant a second dispatch.

All new functions deny unless the provider plan, endpoint cost and reset rule are verified. The lease is 10–900 seconds; network timeout must be enforced by the caller. Expired or crashed requests retain reserved billable credits. If actual billed cost exceeds reserved cost, account for the higher value.

## Legacy compatibility bridge

Both existing v1 reservation function signatures and return shapes are preserved, but rewritten to use the same provider/account advisory lock and count the logical usage union. Alpha's UNLIMITED_OR_UNCONFIGURED fallback is replaced by DENY. The actual Alpha consensus live Worker uses the RESERVE bucket (not VALIDATOR), which is preserved. The old Twelve Data 700/day operational ceiling and separate 100/day headroom are not double-subtracted.

**Important:** v1 callers cannot automatically enforce every new hourly, concurrency and endpoint-credit billing rule. Cutover remains blocked until all external provider calls use the new three-step reservation/dispatch/finalization contract.

## Existing operational limits — not confirmed vendor entitlements

| Provider group | Existing policy | Notes |
| --- | --- | --- |
| TWELVE_DATA | 8/min, 700/day | The 100/day historical headroom is outside the 700/day worker budget |
| ALPHA_VANTAGE_SHARED | 25/day, price=15, validator=2, reserve=3 | All inside 25/day; legacy descriptor price=20 is not authoritative |
| COINGECKO | Unknown | Disabled/unverified |
| FRANKFURTER_FX | Unknown | Disabled/unverified |

Vendor billing rules, account/key sharing, minute/hour/day/concurrency, IANA reset timezone, endpoint costs and 429 semantics must be verified from the real subscribed plans. Do not promote historical config labels to VERIFIED.

## Tests

- tests/market/test_unified_api_quota_pr3_staging.sql — rollback-only test fixture, fail-closed, one active lease, duplicate attempt, pre-dispatch release, DISPATCHED gate, daily spend, 429 cooldown and legacy deny.
- tests/market/pr3_atomic_concurrency_staging.py — separate staging DB sessions; 20 parallel workers with 1 available credit should yield exactly 1 allowed reservation and 1 usage row.

Run only against STAGING after both PR 2 + PR 3 migrations. The Python stress test additionally requires psql, FWIOS_IS_STAGING=YES and FWIOS_STAGING_DATABASE_URL. It aborts if the test provider row already exists and cleans its disposable fixture after completion.

## Release gates and known bypasses

- Old workers are not automatically redeployed or rewired by these migrations.
- portfolio-mtm-refresh-v1 currently calls CoinGecko and Frankfurter outside a unified quota gate.
- PR 4 owns cache-first/single-flight/protected scheduling, and PR 5–7 own market-data/Tracker cutover.
- Verify true parallel atomicity, vendor time-zone reset boundaries, DST, failure-after-dispatch and partial credits before activating a provider.
- Do not describe system-wide quota safety as complete while any external-call path bypasses this gate.
- Production DB functions, existing provider-registry descriptors and nullable usage columns **have changed** via the three migration records; they are live. No Edge Function code, scheduled job definitions, Google Sheets, transactions, holdings, credentials or historical usage rows were changed. No new outbound API request was made in testing.
- The 20 independent-session concurrency stress, worker end-to-end/canary, vendor-plan verification, reset-time/DST and real HTTP 429 tests remain PENDING. Do not claim full quota safety.

## Production-test receipt — 2026-10-13

Applied with the Supabase migration API, sequentially:
1. `fwios_pr2_unified_provider_registry_quota_policy_v1`
2. `fwios_pr3_unified_usage_atomic_reservation_v1`
3. `fwios_pr3_legacy_quota_reservation_bridge_v1`

PR 2 read-only regressions PASS; PR 3 rollback-only synthetic transactional regressions PASS including fail-closed, idempotent reservation, pre-dispatch refund, DISPATCHED gate, daily ceiling, 429 cooldown and legacy deny. First daily-ceiling test hit minute ceiling by design, corrected test fixture (minute=10/hour=10/day=2), reran successfully. Usage totals remain unchanged: decision=353, daily close=3232 at test time. Service-role access and anon/authenticated denial verified. Existing cron remains enabled and already-deployed worker binaries were not modified.

**Unverified:** 20 concurrent independent DB sessions, production worker throughput and real vendor-credit correctness. The database test is not proof of successful cross-worker production rollout.

## Rollback

Disable unified dispatch/cutover feature flag; restore prior validated worker and legacy v1 function definitions in a separate reviewed migration if needed. Never truncate old usage logs or erase reserved credits. Keep historical observations and transaction accounting untouched.
