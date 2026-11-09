# FWIOS Table Catalog

**Architecture version:** DB-ARCH-1.0  
**Doc revision:** DOC-REV-3  
**Status:** CURRENT  
**Verified against live Supabase:** 2026-11-06 10:26:42 UTC

Row counts below are a snapshot, not contractual expected values.

## Application-owned relations

### `fwios.instruments`

**Status:** CURRENT  
**Snapshot rows:** 11  
**Purpose:** Canonical price-domain instrument identity and lifecycle.

**Primary key:** `instrument_id`

**Key fields:**
- `entity_id` — retained lineage/provenance identity from earlier architecture.
- `asset_class`
- `instrument_type`
- `primary_venue`
- `trading_currency`
- `lifecycle_status`
- `metadata`

**Referenced by:**
- `fwios.instrument_symbols.instrument_id`
- `fwios.market_observations.instrument_id`

**Writers:** approved migrations / identity-management paths.  
**Readers:** identity view, resolver, price workers/read functions.  
**Retention:** current identities retained according to lifecycle; do not hard-delete without an approved guarded cleanup.  
**Source-of-truth role:** canonical instrument identity.

---

### `fwios.instrument_symbols`

**Status:** CURRENT  
**Snapshot rows:** 11  
**Purpose:** Symbol/venue/namespace mappings for canonical instruments, including validity and primary-symbol status.

**Primary key:** `instrument_symbol_id`  
**Foreign key:** `instrument_id -> fwios.instruments.instrument_id`

**Key fields:**
- `symbol`
- `venue`
- `symbol_namespace`
- `is_primary`
- `active`
- `valid_from`
- `valid_to`

**Writers:** approved identity migrations/management.  
**Readers:** `v_instrument_identity_current`, `resolve_instrument_id_v1`, workers/readers.  
**Retention:** preserve dated mapping lineage when required; current primary mapping is active + primary + non-expired.  
**Source-of-truth role:** symbol mapping, not instrument identity itself.

---

### `fwios.market_observations`

**Status:** CURRENT  
**Snapshot rows:** 1,149  
**Purpose:** Canonical append-only market-price and FX evidence.

**Primary key:** `observation_id`  
**Unique key:** `observation_key`  
**Foreign key:** `instrument_id -> fwios.instruments.instrument_id`

**Supported current observation types:**
- `REGULAR_CLOSE`
- `LIVE_QUOTE`
- `PRE_MARKET`
- `AFTER_HOURS`
- `FX`

**Important fields:**
- `observation_value`
- `value_currency`
- `fx_base_currency`, `fx_quote_currency`
- `session_date`, `observed_at`
- `market_status`
- `provider`, `source_tier`, `source_url`
- `provenance_status`
- `raw_payload`

**Writers:** validated market collection through `ensure_market_observation_v1` / approved migration seed paths.  
**Readers:** native USD price functions, Sheet sync, verification tooling.  
**Mutation rule:** append-only; active trigger rejects UPDATE and DELETE during normal runtime.  
**Retention:** active canonical history is not age-pruned. Targeted retirement requires explicit authorization and guarded migration.  
**Source-of-truth role:** canonical market observation history.

---

### `fwios.v_instrument_identity_current`

**Status:** CURRENT VIEW  
**Purpose:** Current identity projection joining `instruments` to active, primary, non-expired `instrument_symbols`.

**Inputs:**
- `fwios.instruments`
- `fwios.instrument_symbols`

**Readers:** current asset lookup/read functions and runtime identity consumers.  
**Writer:** none; view only.  
**Important rule:** it is a projection, not a second identity authority.

---

### `fwios_quota.api_call_ledger`

**Status:** CURRENT PRIVATE OPERATIONAL  
**Snapshot rows:** 24  
**Purpose:** Atomic provider-call reservation, dispatch/completion state, cooldown and deterministic batch duplicate protection.

**Primary key:** `call_id`

**Important fields:**
- `provider`
- `key_alias`
- `batch_id`
- `session_date`
- `symbol`
- `endpoint`
- `state`
- `reserved_at`, `dispatched_at`, `completed_at`
- `error_code`
- `blocked_until`

**State machine:** `RESERVED -> DISPATCHED -> SUCCESS | PROVIDER_REJECTED | UNKNOWN`; undispatched reservations may become `CANCELED`.

**Writers/readers:** `fwios_quota` quota functions and market worker.  
**Physical FK to canonical tables:** none.  
**Retention:** retained indefinitely under current policy because it is durable provider-call audit/idempotency evidence.  
**Source-of-truth role:** operational request state, never market-price truth.

**Runtime legacy:** current check constraints/functions still enumerate Alpha Vantage alongside Twelve Data. Future strategy excludes Alpha; removal is pending an approved cutover.

**Security note:** RLS is currently disabled. Direct privilege verification found no schema USAGE or direct table grants for `anon`, `authenticated`, `service_role` or `PUBLIC` at this baseline. Treat the Supabase RLS advisory as a defense-in-depth review item rather than evidence of current public exposure.

## Platform-managed operational relations

### `cron.job`

**Status:** PLATFORM / CURRENT USE  
**Purpose:** pg_cron schedule definitions.  
**Current active FWIOS jobs:** 6 at the verified baseline.  
**Mutation ownership:** pg_cron / approved schedule migrations.  
**Do not treat row-count estimates from catalog tooling as authoritative; query active jobs directly.**

### `cron.job_run_details`

**Status:** PLATFORM / CURRENT USE  
**Snapshot rows:** 178  
**Purpose:** pg_cron execution receipts.  
**Retention:** FWIOS maintenance job retains approximately 30 days based on completed `end_time`.  
**Important rule:** cron success means command execution/dispatch, not necessarily downstream business success.

### `net.http_request_queue`

**Status:** PLATFORM / CURRENT USE  
**Purpose:** pg_net request queue.  
**Retention:** operational queue behavior controlled by pg_net.  
**Source-of-truth role:** none for canonical investment data.

### `net._http_response`

**Status:** PLATFORM / CURRENT USE  
**Snapshot rows:** 2  
**Purpose:** short-lived HTTP response diagnostics from pg_net.  
**Retention:** current pg_net TTL is 6 hours per existing production handoff.  
**Important rule:** not durable audit history.

### `vault.secrets`

**Status:** PLATFORM / CURRENT USE  
**Purpose:** encrypted secret storage for provider/runtime credentials.  
**Documentation rule:** never record secret values, tokens or resolved credentials in GitHub docs.  
**Source-of-truth role:** credential storage only, not data lineage.

## Current functions affecting relation behavior

| Function | Role |
|---|---|
| `resolve_instrument_id_v1` | Resolve one active canonical instrument from symbol/class/venue/namespace; returns null when missing/ambiguous |
| `ensure_market_observation_v1` | Validate and idempotently insert a market observation using deterministic `observation_key` |
| `market_observation_append_only_guard_v1` | Reject UPDATE/DELETE on canonical market observations |
| `pr5_native_usd_price_shadow_v1` | Read latest qualifying native USD observation with freshness/status semantics |
| `pr7_native_usd_price_read_v1` | Apply current valuation eligibility on top of the native USD read |
| `reserve_eod_batch_v1` | Atomically reserve provider-call batch under internal quota/idempotency policy |
| `mark_eod_dispatched_v1` | Move one reserved provider call to dispatched |
| `complete_eod_call_v1` | Record success/rejection/unknown completion and cooldown |
| `cancel_eod_undispatched_v1` | Cancel remaining reserved calls that were never dispatched |

## Catalog update rule

Whenever a relation is added, removed, renamed, repurposed, split, merged, or changes authority:

1. update this catalog;
2. update `DATABASE_ERD.md`;
3. update `DATA_FLOW.md` when logical flow changes;
4. add an entry to `CHANGELOG.md`;
5. verify all descriptions against live production after deployment.
