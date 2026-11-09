# FWIOS Database Architecture

**Architecture version:** DB-ARCH-1.0  
**Doc revision:** DOC-REV-4  
**Status:** CURRENT  
**Live schema snapshot:** 2026-11-06 10:26:42 UTC  
**Operational cutover verification:** 2026-11-09 04:16:58 UTC  
**PostgreSQL:** 17.6.1.166  
**Region:** ap-northeast-1

## 1. Architecture boundary

This document describes the database and operational persistence that exists in live FWIOS production today.

It does **not** design the future Multi-Provider Data Infrastructure. Future objects such as Provider Registry, Capability Registry, Raw Provider Data, Normalized Fundamentals, Filing Evidence or Validation tables are not current production objects and must remain outside the CURRENT diagrams until approved and deployed.

## 2. Current application schemas

### `fwios` — canonical price-domain data

Current relations:

- `fwios.instruments` — canonical instrument identity and lifecycle.
- `fwios.instrument_symbols` — active/dated symbol mappings for instruments.
- `fwios.market_observations` — append-only market-price and FX observations.
- `fwios.v_instrument_identity_current` — current primary-symbol identity read view.

Current application functions:

- `fwios.resolve_instrument_id_v1(...)`
- `fwios.ensure_market_observation_v1(...)`
- `fwios.market_observation_append_only_guard_v1()`
- `fwios.pr5_native_usd_price_shadow_v1(p_asset text)`
- `fwios.pr7_native_usd_price_read_v1(p_asset text)`

Current trigger:

- `market_observations_append_only` blocks UPDATE/DELETE on `fwios.market_observations`.

### `fwios_quota` — private provider-call operational ledger

Current relation:

- `fwios_quota.api_call_ledger`

Current functions:

- `reserve_eod_batch_v1(...)`
- `mark_eod_dispatched_v1(...)`
- `complete_eod_call_v1(...)`
- `cancel_eod_undispatched_v1(...)`

This schema is operational quota/idempotency state, not canonical market data.

### Runtime legacy note

**Alpha runtime cutover completed 2026-11-09.** Active Market Worker v14 no longer fetches Alpha Vantage. Cron #17 schedules Twelve Data alone and Cron #18 follows up Twelve-only; the `ALPHA_VANTAGE_API_KEY` Supabase Vault credential was removed. Historical Alpha observations and quota receipts are immutable and preserved. Existing quota table CHECK constraints, SQL read functions, and Sheet read-side validation still recognize historical Alpha provider identifiers as legacy compatibility; **these do not constitute an active Alpha API provider path**. Autonomous post-cutover Twelve 4/4 + Sheet readback acceptance is pending.

## 3. Supabase/Postgres platform schemas used by FWIOS

These are operational dependencies, not FWIOS-owned application tables.

### `cron`

- `cron.job` — pg_cron schedule definitions.
- `cron.job_run_details` — operational execution receipts; 30-day FWIOS retention job is active.

Live active jobs at the snapshot:

| Job ID | Name | Schedule |
|---:|---|---|
| 15 | `fwios-portfolio-stock-post-close-sync` | `10 21,22 * * 1-5` |
| 16 | `fwios-portfolio-sheet-shadow-sync-native` | `20 21,22 * * *` |
| 17 | `fwios-us-stock-eod-close-v1` | `55 5,6 * * *` (01:55 NY) |
| 18 | `fwios-us-stock-eod-sheet-followup-v1` | `10 6,7 * * *` (02:10 NY) |
| 19 | `fwios-cron-run-details-retention-v1` | `15 3 * * *` |
| 20 | `fwios-crypto-price-daily-refresh` | `10 21,22 * * *` |

**2026-11-09 operational rename:** Old Crypto Cron ID #14 was retired atomically and replaced with #20. Its 46 historical run receipts remain attached to ID #14 in `cron.job_run_details`. The six active IDs are #15, #16, #17, #18, #19 and #20. This is a Cron identity/description update only; canonical price tables, migrations of market data and the database authority model remain unchanged.

### `net`

- `net.http_request_queue` — pg_net request queue.
- `net._http_response` — ephemeral HTTP response diagnostics; current retention is platform pg_net TTL, not durable audit history.

### `vault`

- `vault.secrets` — encrypted server-side secret storage used for provider/runtime credentials.
- Secret values must never be copied into architecture documentation.

## 4. Current Edge Functions

Live Edge Functions:

- `price-market-refresh-v1` — version 14.
- `price-sheet-sync-v1` — version 7.

These functions are runtime components, not database tables, but they are included in the data-flow documentation because they are primary readers/writers around the database.

## 5. Live relation snapshot

Snapshot counts are operational evidence, not fixed schema invariants.

| Relation | Snapshot rows |
|---|---:|
| `fwios.instruments` | 11 |
| `fwios.instrument_symbols` | 11 |
| `fwios.market_observations` | 1,149 |
| `fwios_quota.api_call_ledger` | 24 |
| `cron.job_run_details` | 178 |
| `net._http_response` | 2 |

## 6. Core database invariants

### Identity

- `instrument_id` is the canonical database identity for price-domain instruments.
- Symbol strings are mappings, not the immutable canonical identity.
- A current primary symbol is resolved through `instrument_symbols` and the current identity view.

### Market observations

- Must reference a valid `instrument_id`.
- Observation value must be positive.
- Supported current observation types are `REGULAR_CLOSE`, `LIVE_QUOTE`, `PRE_MARKET`, `AFTER_HOURS`, and `FX`.
- FX observations require base and quote currencies.
- `observation_key` provides deterministic insert idempotency.
- Observations are append-only under the active trigger.
- Historical evidence is not rewritten just to make current architecture visually uniform.

### Read model

`pr5_native_usd_price_shadow_v1` resolves current identity, selects qualifying native-USD observations, applies freshness semantics, and returns a read-only JSON payload.

`pr7_native_usd_price_read_v1` applies the current valuation-eligibility cutover on top of the shadow read. Trading eligibility remains false.

### Accounting ownership

Price eligibility does not transfer accounting ownership to Supabase. Holdings quantity, transactions, cost basis, manual overrides and portfolio accounting remain Google Sheet-owned under the current contract.

## 7. Security/visibility note

Supabase's table-list advisory flags `fwios_quota.api_call_ledger` because RLS is disabled.

A direct privilege check at this baseline found:

- `anon`: no `USAGE` on `fwios_quota`
- `authenticated`: no `USAGE` on `fwios_quota`
- `service_role`: no `USAGE` on `fwios_quota`
- no direct table grants to `anon`, `authenticated`, `service_role` or `PUBLIC`

Therefore this documentation records the advisory as a defense-in-depth item, not as proof that the table is currently exposed through the client Data API. No RLS change is authorized by this documentation task.

## 8. Architecture upgrade/downgrade rule

A structural change is complete only when both conditions are true:

1. production state has been verified after the approved change; and
2. all affected files under `docs/database/` have been updated to match that verified state.

Database docs must never be used to silently promote PLANNED objects to CURRENT before deployment.
