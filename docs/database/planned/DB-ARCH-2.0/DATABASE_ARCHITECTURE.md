# DB-ARCH-2.0 — FWIOS Multi-Provider Infrastructure v1
**STATUS: PLANNED / NOT DEPLOYED** | **Design authorized: 2026-11-09** | **Implementation NOT approved**

## 1. Design mandate and baseline

The user approved **Provider Strategy v1** and authorized **architecture design only** on 2026-11-09. This document is a proposed system/data architecture, not an existing database schema or deployed capability. Follow the [planned manifest](MANIFEST.yaml) and retain `docs/database/CURRENT.yaml` as the only current-production pointer.

Production read-only baseline (2026-11-09 ~09:11 UTC): healthy Supabase Postgres 17.6.1.166; `fwios` has exactly `instruments`, `instrument_symbols`, and append-only `market_observations` plus the `v_instrument_identity_current` view; private `fwios_quota.api_call_ledger`; Edge `price-market-refresh-v1` v14 and `price-sheet-sync-v1` v7; active Crons #15–#20. `ASSET-PRICE-CONTRACT-1.1.0` remains unchanged and excludes stock discovery, fundamentals, research, valuation, trading and portfolio accounting. **Do not rebuild the retired scanner/valuation runtime into that price-only contract.**

## 2. Architecture boundaries (proposed)

**A. Existing Price Service — immutable operational boundary (NOT modified by design)**

- `fwios.market_observations`: canonical, append-only, validated holdings price and FX history.
- `fwios.instruments` and `fwios.instrument_symbols`: currently 10 held assets and one FX pair; **not** a universal 500-security index.
- `fwios_quota.api_call_ledger`: existing Twelve-specific/price-service reservation ledger with preserved audit.
- Existing two Edge Functions, Crons #15–#20 and Google Sheet `_Market_Data` → `Price Data` → `Holdings` → `Dashboard` remain authoritative. `FWIOS Live Valuation` stays historical-only.
- No new provider path may write price tables or Sheet accounting without **separate** price-contract change approval; research-priced bars are **not** automatically promoted to holdings prices.

**B. Proposed Provider Control Plane — private schema `fwios_provider`**

- **Provider Registry** records provider identity, active eligibility, entitlement, license class, default currency/timezone and credential *alias* only; never stores secrets.
- **Capability Registry** records provider-specific capabilities and semantics: BULK_EOD, FOCUSED_EOD, FINANCIALS, SEC_FILINGS, NEWS, CRYPTO, FX_REFERENCE. Availability and license vary by product/plan, not just provider name.
- **Routing Policies** are versioned, explicit primary/secondary orders with manual/automatic-fallback permission and require compatible session/adjustment/currency/provenance.
- **Quota Policies** set per-minute, per-day, monthly, concurrency, credit-cost, cooldown, and hard-dollar budgets per provider/key alias/capability. Unsupported or unverified entitlement = blocked.
- **Request Ledger / fetch receipts** provide atomic budget reservation, durable request state, idempotency, HTTP status, API credits, response checksums, timing and source identity.
- No generic public API Gateway in v1: trusted server-only dispatcher, separate queue/claims if and when approved; external auth must use server-scoped credentials with least privilege.

**C. Proposed Research & Evidence Plane — private schema `fwios_research`**

- Research security master with external identifiers and dated symbol mappings; **separate** from the 10 holdings-only `fwios.instruments`.
- Point-in-time S&P 500 membership with constituent source, effective dates, rights and versioning.
- Unadjusted bulk EOD bars as **research inputs** (not replacements for held-price canonical observations).
- Raw evidence pointer + content hash, immutable SEC filing accession record, versioned as-of metric facts, relevant news events, immutable validation and lineage.
- Evidence passes identity, period, filing/availability time, currency, units, taxonomy, adjustment, completeness and source/licensing gates before research acceptance. Provider-normalized facts are not authoritative filing facts.
- No actual valuation, scoring, decision, trading or portfolio accounting subsystem is deployed or authorized by this design. Later research consumers would require a distinct contract and approval.

## 3. Domain orchestration (future only)

1. **Discovery/plan:** a future scheduler selects an explicit capability and time window, checks current entitlement/licensing, quota credits, time-of-publication, and idempotency key. If no eligible plan exists => `BLOCKED`.
2. **Atomic reserve:** one transaction reserves all expected credit units before dispatch; a provider call cannot be sent without a durable reserved ledger row. Dispatched/unknown outcomes conservatively consume budget.
3. **Fetch:** trusted worker calls approved provider endpoint, sanitizes credential-bearing URLs/headers, records receipt and encrypted/private evidence pointer. Cache/ETag or singleflight may prevent duplicate fetches; cache hits do not masquerade as provider calls.
4. **Normalize:** provider-specific adapters emit typed, named contracts (e.g., `BulkEodBarV1`, `FilingFactV1`, `NewsEventV1`) retaining original ID/session/period/filing time, `source_url` without credentials, payload hash, and API-call lineage.
5. **Validate:** deterministic gate returns `PASS`, `QUARANTINED`, or `BLOCKED`; rejected/partial batches never become complete by mixing dates or silent substitutions. For all-source conflicts, preserve alternatives and explicit conflict reason.
6. **Persist:** append-only receipts and facts with content-key/idempotent dedupe. Research read views expose only certified, as-of-valid, licensed observations; no writes to `fwios.market_observations` or portfolio ledger.
7. **Read-only research consumers:** future users/screeners may fetch source-backed research results only after a separately approved consumer contract. They must not mutate decisions, scores, holdings or trades under the current price contract.

## 4. Provider responsibility & route policy

| Capability | Primary | Secondary or verifier | Strict preconditions |
|---|---|---|---|
| BULK_EOD_US | Massive Stocks Basic | EODHD optional; Twelve Data *small scoped retry only* | After NY midnight on free Basic; `adjusted=false`; valid NY trading session and sufficient rights. A grouped all-US result is **not** an S&P 500 membership feed |
| FOCUSED_EOD_US | Twelve Data (currently deployed price path) | Massive candidate for **future reviewed** fallback | Preserve `REGULAR_CLOSE`, USD, exact session, full held-asset batch, unadjusted; no changes to existing Cron #17/#18 |
| NORMALIZED_FINANCIALS | Massive Financials & Ratios optional paid tier | SEC authoritative cross-check; FMP optional enrichment | Purchase/entitlement not yet approved; normalize units, period, filing ID, point-in-time availability |
| PRIMARY_SEC_EVIDENCE | SEC EDGAR / data.sec.gov | None with equal official primary authority | Descriptive User-Agent, fair-access limit, CIK/accession, actual filing `accepted_at`, amendments |
| CATALYSTS_NEWS | Massive News + SEC 8-K | Tiingo optional if separately licensed | Publisher timestamps, first-seen timestamps, dedup; 8-K primary when relevant |
| CRYPTO_SPOT | CoinGecko (existing price service) | Twelve Data candidate, **not live automatic fallback** | Coin ID, USD, provenance, freshness, free-tier attribution |
| FX_REFERENCE_USDTHB | Frankfurter (existing price service) | Twelve Data FX candidate | Explicit rate source/provider (blend vs pinned), value date, reference not executable FX |
| Any provider | **ALPHA_VANTAGE EXCLUDED** | No replacement Alpha route | Historical records preserved as immutable lineage only |

## 5. Storage/security topology (proposed)

- Schemas `fwios_provider` and `fwios_research` are **private/not in exposed Supabase Data API schemas**. Default privileges revoked from `PUBLIC`, `anon` and `authenticated`; operator/service access explicitly scoped. RLS in any exposed schema is mandatory; private-schema RLS recommended defense in depth.
- Design table owner and controlled future worker invoker roles separately; avoid broad `SECURITY DEFINER` on public functions. If a privileged transactional reservation function is unavoidable, protect function `search_path`, role/execute grants, validation and audit.
- Secrets remain **server-side only** in supported Vault/Edge secret facilities, with key aliases in metadata. Never expose `service_role`/secret in a browser, logs, URL fields or GitHub. SEC User-Agent contact is configuration, not token leakage.
- Raw provider payloads may be licensed/restricted: private object storage under hash-addressed object keys plus nonsecret `raw_evidence` metadata, checksum, immutable source lineage and provider-specific retention/redistribution policy. Storage is proposed, **not** an existing deployed bucket.
- Immutable canonical price observations retain **no age-based prune**. Existing `fwios_quota.api_call_ledger` remains indefinitely retained. Research raw data requires a **separately approved** policy per source/license, not reuse of pg_net short-lived HTTP receipts as an audit store.
- For publication or customer-facing SaaS, deny redistribution unless the actual account plan/license grants display/reuse; internal personal permission does not imply commercial rights.

## 6. Error, fallback and audit semantics

- Request states: `RESERVED → DISPATCHED → SUCCESS | PROVIDER_REJECTED | UNKNOWN`; `RESERVED → CANCELED` only before dispatch. Timeouts after dispatch => `UNKNOWN` and budget consumed until reconciled. HTTP 429/503 => provider-specific cooldown and explicit retry policy, never unbounded.
- Quota and local budget are not equivalent to vendor-account balances; headers/usage API must be recorded when available. Do not promise spend under $0 or $29 before account-specific entitlements are verified.
- `primary PASS` is valid only with exact typed capability. A secondary response may be compared independently but **cannot** overwrite an existing certified primary result, patch missing rows of an atomic held-asset batch, or silently change price semantics.
- Deterministic idempotency by `provider_id + capability_id + request_params_hash + as_of_window`; research-version keys include source accession/content hash so restatements append rather than rewrite old facts.
- Distinguish `event_time`, `published_at`, `first_seen_at`, `ingested_at` and `valid_from/valid_to`. Never use current-year membership or revised numbers as historical information available earlier.
- Keep provenance graph `request → raw receipt → source filing/article/bar → normalized fact → validation verdict → accepted research read`. Link missing => fail closed.

## 7. Non-goals and invariant checks

- **NOT IMPLEMENTED:** Provider/Capability Registry tables, queue, new Edge workers, Research tables, S&P 500 scheduler, budgets, failover, fundamental model, stock scorer or AI decision engine.
- **NOT AUTHORIZED:** paid Massive add-on, EODHD/Tiingo/FMP keys, provider activation, migration or Production transaction.
- **NOT MODIFIED:** `contracts/system-contract.yaml`, `docs/database/CURRENT.yaml`, current database docs, Alpha historical receipts, daily live Crons, `fwios.market_observations`, Google Sheet Transactions/Holdings/Cost Basis/Manual Overrides, `auto_trade=false`.
- Parked natural E2E: Crypto Cron #20 first post-rename and Stock #17→#18 Twelve-only post-Alpha-cutover (Issue #106) remain independent production acceptance gates.

See [ERD](DATABASE_ERD.md), [data flows](DATA_FLOW.md), [table catalog](TABLE_CATALOG.md), [design decisions](DESIGN_DECISIONS.md) and [implementation gates](IMPLEMENTATION_PLAN.md).
