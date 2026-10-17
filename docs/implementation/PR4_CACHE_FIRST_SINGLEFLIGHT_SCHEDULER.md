# FWIOS v3 — PR4 Cache-First / Distributed Single-Flight / Priority Scheduler

**Status:** DRAFT stacked on PR3; no production worker cutover, no cron changes, no real provider HTTP, no Google Sheets writes. The existing Supabase Production project is owner-approved as a **shared** test environment, not an isolated staging project.

## Verified baseline
- PR2 registry in `fwios.decision_refresh_provider_registry`; PR3 atomic Reserve → Dispatch → Finalize functions and unified read-only view already installed.
- Existing canonical prices in `fwios.market_observations`, legacy price snapshots, `dashboard_refresh_cache` (dashboard payload only), decision / daily-close jobs, PGMQ and active cron.
- PR3 worker binaries remain deployed unmodified; `portfolio-mtm-refresh-v1` still bypasses quota for CoinGecko/Frankfurter, and old daily-close worker writes legacy usage outside PR3 dispatch/finalize.
- All real vendor plans/costs remain UNVERIFIED; all new routes default to `PR4_CUTOVER_OFF`.

## Design — smallest additive coordinator
One **small internal-only coordination table** `fwios.market_refresh_flights_v1` is necessary because current job queues are scoped to decision-refresh or daily-close runs; they do NOT represent a canonical cross-consumer request signature, owner, lease and published observation. This is **not** a market-price cache, usage ledger, provider registry or transaction ledger. It stores only work-state metadata; no raw provider secrets, holdings, trades or account balances.

1. `pr4_cache_lookup_v1`: reads **immutable** `fwios.market_observations` only. Existing records lacking the PR4 exact signature are deliberate misses. Quotes and FX use strict provider-specific maximum TTL (90/300 seconds); requested session date is exact. `REGULAR_CLOSE` is returned as `LAST_CLOSE`, never disguised as live.
2. `pr4_request_market_refresh_v1`: checks actual tagged cache before attempting to enqueue, then advisory-locks the canonical SHA-256 flight key and joins existing work. Rejects incompatible cached semantics and key collisions. Unverified real routes fail CLOSED (provider descriptor `migration_state` must be `ACTIVE`). QA-only routes require provider names prefixed `QA_PR4_` and a synthetic QA identity.
3. `pr4_claim_market_refresh_v1`: shared Postgres `FOR UPDATE SKIP LOCKED` claim, ordered **P0, P1, P2, P3, P4** with FIFO within priority. Claims are atomic across independent DB connections. P0 non-QA requests must be verified against existing OPEN portfolio positions and canonical identities; a better Tracker-derived holdings feed is a PR5/6 cutover prerequisite.
4. `pr4_core.ts`: every external attempt strictly follows `reserve_api_quota_unified_v1` → `mark_api_quota_dispatched_v1` → one injected provider transport call → `finalize_api_quota_usage_v1`. Fresh cache hits do none of those. No automatic retry inside one claim; denied quota never calls a provider. P4 is blocked by PR3's **verified explicit** protected P0 credits, not an inferred legacy headroom value.
5. `pr4_publish_market_refresh_v1`: append-only immutable canonical observation and READY transition in one DB transaction, requiring a matching successful PR3 usage record with exact attempt key and signature. No destructive replace or duplicate ledger.
6. Bounded failure: 429 Retry-After (clamped), 5xx, invalid price, timeout and provider failures get conservative PR3 billing and deferred status. A crashed `RUNNING` flight with expired lease is **UNCERTAIN** and cannot be reclaimed automatically: reconcile the usage/HTTP status before manually authorizing a new generation. This chooses duplicate-call safety over full liveness.
7. Fallback is **new provider-specific flight with its own validated policy + quota**. Never reuse the primary provider's credit permit; no fallback to unconfigured/unverified provider.
8. `market-refresh-orchestrator-v1` is **not deployed** and has **no live-provider adapter** in this draft. It uses only synthetic QA responses, requires `FWIOS_PR4_MOCK_ONLY=true` and a separate `PR4_MARKET_REFRESH_WORKER` automation token (not provisioned by this PR). `verify_jwt=true` is required if deploying the QA function later. No existing worker/cron has been rewired.

## Ownership + release limits
- `Investment Portfolio Tracker - Chumponphat` (Sheets) remains transaction/accounting source of truth. Supabase is market-data infrastructure. Focused Dashboard remains research/scanner.
- `P0=Holdings`; `P1=Focused Opportunities`; `P2=Research`; `P3=Watchlist`; `P4=Scanner`. P0 non-QA validation currently uses a legacy readonly holdings projection and does not yet cover standalone FX refresh membership correctly; keep cutover OFF.
- Do not enable live provider descriptors without verifying account/endpoint credits, reserve, minute/hour/day/concurrency, reset timezone incl. DST and 429 semantics.
- SQL function/table privileges are service_role-only for Data API, with RLS enabled. The Edge adapter has a separate token gate; never expose DB URL or service secrets to frontend.

## Tests and acceptance matrix
| Gate | Implementation | Reality / release status |
| --- | --- | --- |
| A exact freshness/0 credits | SQL cache lookup + in-process mock test + rollback SQL | Offline and rollback-only test results must be recorded after execution |
| B 20 requests same key / one dispatch | Deterministic 20-caller mock test, SKIP LOCKED coordinator | **20 independent PostgreSQL sessions pending** |
| C instrument/currency/session/adjustment isolation | SHA-256 canonical key + mock tests | Execute and confirm |
| D priority and P0 protected reserve | DB priority claim + PR3 reservation policy + SQL regression | Test actual QA fixture |
| E 429/timeout/5xx/fallback/lease | Core safe state transitions + tests | Test suite; real vendor/reset/DST pending |
| F deployed Edge Mock E2E parity | Shared core + QA-only Edge adapter committed | **Not deployed / not exercised through real Edge HTTP** |
| G QA cleanup and no real traffic | Rollback-only test; QA prefix, no new consumer wiring | Verify after each DB test |
| H PR3 release gates | Parent PR remains draft | **20 DB sessions, real vendor entitlements and legacy bypass migration pending** |

## Test procedure (Production-as-test)
1. Read the migration and inspect **live** `fwios` state first. Apply additive SQL **only** after checking it doesn't replace or redeploy any existing worker, cron or ledger.
2. Run `tests/market/test_pr4_cache_singleflight_rollback.sql` as **ONE SQL statement/session** (BEGIN and ROLLBACK). It creates a disposable QA-only provider and QA-only canonical instrument, operates on synthetic market observations inside the transaction, and rolls everything back.
3. Recheck `QA_PR4_%` provider rows, flights, canonical QA instruments, and usage rows; expected all zero after rollback. Verify service_role grants and anon/authenticated denials.
4. Run `node --experimental-strip-types --test tests/market/pr4_mock_e2e_test.ts` in GitHub Actions; no secrets or network transport. These 20 callers are **not** 20 independent PostgreSQL sessions.
5. Do NOT start the new Edge Function on the real project, enable `ACTIVE` policy, change cron, modify Sheets, or merge stacked PRs before acceptance review.

## Known open risks
- PR3 lacks 20 independent-session production-as-test proof and deployed Edge parity.
- Provider entitlements/endpoint costs/reset rules remain unverified. Current historical limits are operational, not vendor promises.
- The dedicated new coordinator is permanent infrastructure once migrated but is idle while feature flag remains OFF; it is not a duplicate business/data ledger.
- Strict cache identity means historical untagged prices MISS; this is an intentional safety choice, subject to compatibility plan in PR5.
- Cache TTL for `REGULAR_CLOSE` requires an exact matching session; stale close can be displayed only as LAST_CLOSE and must fail investment decision freshness gates.
- Crash-after-dispatch favors UNCERTAIN (operator reconciliation) over automatic rescue.
- QA-only Edge mock transport is not representative of real provider network/credit semantics until later cutover integration.

## Rollback
Leave old cron/worker untouched. Turn off new route (existing descriptor remains SHADOW_ONLY) and stop calling PR4 RPCs. Preserve append-only observations and unified usage history; no historical truncation or quota refunds. Remove test fixtures ONLY if positively identified by QA prefix/identity and approved, never delete real portfolio/market data. Database object removal would be a separately reviewed migration, not a blind rollback.

## Production-as-test and CI receipt — 2026-10-13 (Asia/Bangkok)

**Database:** `fwios_pr4_cache_singleflight_scheduler_v1` migration **APPLIED** on the existing owner-authorized shared Supabase project `ysjbmeukwbfnxnwqchuq` (migration version `20261013043447`); no existing worker, cron, Sheets data or provider credentials were changed. This is a production DB DDL change; it is not merely a proposal.

**SQL QA transactional regression:** **PASS** after correcting the test's assumption that two queued P4 rows have deterministic same-transaction FIFO ordering. The test now publishes the flight key actually returned by Claim. Entire test runs in BEGIN...ROLLBACK. It exercises QA-only canonical instrument/provider, queue + join, P0 claim ordering, PR3 Reserve → Dispatch → Finalize, immutable observation publication, cache reuse with **zero additional reservations**, P4 blocked by P0 protected reserve and public role EXECUTE denial.

**Verified cleanup after rollback:** QA providers=0, QA flights=0, QA instruments=0, QA market observations=0, QA unified usage=0 (read-back SQL query after test).

**Privileges:** `service_role` can claim; `anon` cannot claim; `authenticated` cannot publish; coordinator RLS enabled. Internal FWIOS schema has historical informational RLS-without-policy advisor notices; new coordinator likewise uses deliberate closed RLS with service-only grants and no frontend policy. Review broader advisor findings before cutover.

**GitHub Actions same-core Mock E2E:** [run 38347851128](https://github.com/ChumponphatRangsee/focused-wealth-investment-os/actions/runs/38347851128) **SUCCESS: 10/10 tests, 0 failures**, after fixing offline MockGateway to return JOIN for an already QUEUED flight (matching database behavior). Earlier runs 38347099558 and 38347173903 were FAIL, not counted as green. Latest test models 20 simultaneous JS callers, exact semantic separation, P0/P4 protected capacity, 429 Retry-After, timeout/5xx conservative finalize, quota denial/no network, provider fallback, LAST_CLOSE.

**Do not overstate acceptance:** the 20 JS callers are not independent DB connections; the same TS logic is imported by an Edge adapter, but this adapter is not deployed/exercised over HTTP. The real 20 independent PostgreSQL sessions, actual Edge Mock E2E and vendor/legacy path gates remain pending. PR #51 stays draft and cutover OFF.

### QA scope hardening and independent-session test readiness

- Follow-up additive hardening migration `fwios_pr4_qa_scoped_claim_hardening_v1` **APPLIED** (migration version `20261013044037`) so a QA-only Edge Worker always invokes `fwios.pr4_claim_market_refresh_v1(worker_uuid, true)`. Production route explicitly uses `false` when eventually reviewed/activated.
- Service role EXECUTE on the legacy **unscoped** `pr4_claim_market_refresh_v1(uuid)` was revoked. Verified: unscoped service_role=false; scoped service_role=true; scoped anon=false.
- SQL rollback-only regression rerun **PASS** after hardening. Revalidated read-back **0** QA providers, flights, instruments, observations and usage; all **8** existing crons still active, unchanged.
- Added `tests/market/pr4_independent_20_session_qa.py`: **NOT EXECUTED**. It prepares an isolated random QA provider and instrument and uses 20 separate `psql` subprocess sessions to verify 1 QUEUED + 19 JOIN, 1 successful PR3 reservation and 1 dispatch permission out of 20 each. All SQL is mock-only, and a `finally` block cleans narrowly scoped QA records. Guard requires explicit Production-as-test approval, exact Supabase ref and a secret database URL supplied to a short-lived runner. No Local Supabase CLI, no new staging project, and no vendor HTTP calls.
- GitHub Actions `38347851128` verified Python **syntax only** (`py_compile`) and the same-core TS suite **10/10 PASS**, including added stale-cache/refresh behavior and all five priority classes P0..P4. It did **not** run the database stress test.
- A real cloud-runner 20 independent-session run needs authorized temporary database credentials and controlled QA connection budget. That gate stays OPEN until actual database sessions run successfully with a zero-residual cleanup receipt. Do not claim this as passed from syntax compilation.
