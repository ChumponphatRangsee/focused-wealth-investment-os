# DB-ARCH-2.0 — Proposed Table & Contract Catalog
**STATUS: PLANNED / NOT DEPLOYED**. This is a **conceptual schema**, not migration SQL, not an existing Supabase table inventory and not permission to implement. **Safety invariant:** `auto_trade=false`; current production prices and portfolio accounting remain unchanged. Future types, indexes, privileges and FK constraints require a separate review.

## 1. Schema and privilege ownership

- `fwios_provider`: **proposed** private control plane; not exposed via Data API. Six proposed tables.
- `fwios_research`: **proposed** private normalized evidence plane; not exposed via Data API. Eleven proposed tables.
- **Current, unchanged**: `fwios` (3 price tables + identity view), `fwios_quota.api_call_ledger` (price-specific operational ledger). Zero automatic FK promotion from research to price.
- New roles/grants, RLS policies, Vault aliases, Storage buckets and privileged functions are **not currently installed**. Do not add proposed names to current schema documentation.

## 2. Proposed provider tables (six; all new)

| Table | Key design fields / constraints | Main indexes, access & retention |
|---|---|---|
| `provider_registry` | `provider_id uuid PK`; unique `provider_code`; `status` enum proposed `PROPOSED, VERIFIED, DISABLED`; `license_class`, `entitlement_proof_ref`, `credential_alias` (never plaintext), `last_reviewed_at` | Unique code; key alias is metadata only; disable provider before teardown |
| `capability_registry` | `capability_id uuid PK`; unique `capability_code`; typed `contract_version`, `asset_class`, `currency_policy`, `time_semantics`, `min_provenance` | Unique code+version per immutable contract; lookup by capability |
| `provider_capabilities` | `provider_capability_id uuid PK`; `provider_id FK`, `capability_id FK`; `entitlement_state`, `plan_code`, `endpoint_template` (no token), `data_delay_seconds`, `license_conditions`, `required_adjustment` | Unique provider/capability/plan/contract; default `BLOCKED` unless independently verified |
| `route_policies` | `route_policy_id uuid PK`; `provider_capability_id FK` for primary; `policy_version`, `valid_from`, `valid_to`, `candidates_and_gates JSONB`, `auto_fallback_allowed=false`; approval provenance | Unique capability/policy version; schema-validated candidate array; activate only via reviewed promotion |
| `quota_policies` | `quota_policy_id uuid PK`; `provider_capability_id FK`; `max_credits_per_minute`, `max_credits_per_day`, `max_credits_per_month`, `max_concurrent`, `max_monthly_spend_usd`, `endpoint_cost_model_version`, `verified_at` | Effective-dated policy, operator approval; **default zero authorized paid spend**; vendor usage may be unknown |
| `request_ledger` | `request_id uuid PK`; `provider_id FK`, `capability_id FK`, `request_fingerprint UNIQUE`; `batch_key`, `reservation_credit_units`, `estimated_cost_usd`, `state`, `reserved_at`, `dispatched_at`, `completed_at`, `http_status`, `provider_call_id`, `error_category`, `response_sha256` | Atomic budget reservations; `UNIQUE(request_fingerprint)`; status/time partial indexes; **do not prune until duplicate-call policy is redesigned** |

**Quota consistency:** A `request_fingerprint` covers provider, capability, normalized params, target session/as-of window, and policy version. A dispatch requires its own successful transactionally committed `RESERVED` receipt. In the event of concurrent requests, **only one** reservation proceeds; others observe the same batch state or block. External calls must never occur inside a SQL transaction. `DISPATCHED` and `UNKNOWN` charge the conservative local allowance; only definitely **not dispatched** `RESERVED` slots can be canceled. New ledger does not replace or delete `fwios_quota.api_call_ledger`.

### Provider request state machine

```text
PLANNED request
  ├── BLOCKED (license, quota, market timing, plan or validation)
  └── RESERVED (durable atomic capacity)
         ├── CANCELED (only if definitely never dispatched)
         └── DISPATCHED
              ├── SUCCESS (parsed and provider receipt complete, not yet research accepted)
              ├── PROVIDER_REJECTED (HTTP/provider refusal, budget may still be consumed)
              └── UNKNOWN (network timeout/uncertain dispatch, budget conservatively consumed)
```

Provider response `SUCCESS` is **not** research fact `PASS`; the latter needs independent quality/provenance validation. Any manual reconciliation must append a new auditable decision, not rewrite dispatched history.

## 3. Proposed research tables (eleven; all new)

| Table | Key design fields / constraints | Primary data semantics |
|---|---|---|
| `security_master` | `security_id uuid PK`, `security_type`, `issuer_cik` nullable, `figi` nullable, `share_class`, `primary_mic`, `currency`, `lifecycle`, `identity_source` | One **tradable security**, not an issuer-only row; CIK can legitimately be shared across share classes; no automatic link to price-service IDs |
| `symbol_aliases` | `alias_id uuid PK`, `security_id FK`, `symbol`, `symbol_namespace`, `mic`, `valid_from`, `valid_to`, `alias_source` | Temporal ticker map; unique non-overlapping symbol+venue intervals, no future-ticker leakage |
| `index_memberships` | `membership_id uuid PK`, `index_code`, `security_id FK`, `effective_from`, `effective_to`, `announced_at`, `known_at`, `source_evidence_id`, `source_license` | Point-in-time source-backed S&P 500 membership, temporal overlap excluded for a given security/index/source version; if unavailable mark current-universe-only |
| `ingest_batches` | `batch_id uuid PK`, `capability_code`, `target_session_or_asof`, `expected_members_count`, `observed_members_count`, `status`, `started_at`, `closed_at` | Explicit `PARTIAL/COMPLETE/BLOCKED/QUARANTINED`; no `500/500 PASS` without valid source membership and counts |
| `raw_evidence` | `evidence_id uuid PK`, `batch_id FK`, `request_id` logical link, `source_url_sanitized`, `response_content_sha256`, `private_storage_object_key`, `retrieved_at`, `source_published_at`, `license_policy_version`, `retention_class` | Immutable raw provenance or redacted/hash-only receipt when provider terms forbid archiving; no secrets, token URL, or public bucket |
| `bulk_eod_bars` | `bar_id uuid PK`, `security_id FK`, `evidence_id FK`, `ny_session_date`, `open/high/low/close_unadjusted`, `volume`, `source_adjusted=false`, `currency=USD`, `source_asof` | Research EOD data only, not `fwios.market_observations`; dedup by security/session/provider/adjustment/source checksum |
| `sec_filings` | `filing_id uuid PK`, `evidence_id FK`, `issuer_cik`, `accession_number UNIQUE`, `form_type`, `filed_on`, `accepted_at`, `amends_accession`, `document_url` | Primary SEC evidence and amendment chain; never infer first public time solely from fiscal period |
| `metric_facts` | `fact_id uuid PK`, `security_id FK`, `evidence_id FK`, `filing_id FK nullable`, `taxonomy`, `concept`, `period_start/end`, `fiscal_year/quarter`, `unit`, `value`, `first_public_at`, `vendor_observed_at`, `version_fingerprint` | **Append-only point-in-time versions**; SEC filing as authority when present; vendor-only fact with unknown first-public time cannot pass historical as-of certification |
| `news_events` | `event_id uuid PK`, `evidence_id FK`, `security_id FK nullable`, `publisher_id`, `article_id`, `url_canonical`, `published_at`, `first_seen_at`, `event_tags`, `copyright_policy` | Dedup article, preserve original publisher time vs when system learned about it, store metadata only if license disallows full text |
| `validation_results` | `validation_id uuid PK`, `evidence_id FK`, `subject_type`, `subject_id`, `validator_version`, `verdict`, `reason_codes`, `validated_at`, `policy_version` | Immutable `PASS/QUARANTINED/BLOCKED`; versioned validator, per-subject audit, no retroactive silent upgrades |
| `lineage_edges` | `lineage_id uuid PK`, `source_type/id`, `target_type/id`, `relationship`, `rule_version`, `created_at` | Typed source graph; cross-object IDs are **logical**, so an integrity validator is mandatory; no orphaned accepted facts |

**Append-only exceptions:** operational requests may gain only valid status transitions (audited), while `raw_evidence`, `metric_facts`, `validation_results`, and accepted snapshots must never be silently overwritten or deleted. Other registry policy updates produce effective-dated versions. Do not create generic age-based deletion of evidence or canonical price history.

## 4. Typed adapter output contracts (examples; not live API payloads)

**`BulkEodBarV1`:** `security_id`, `provider_code`, `ny_session_date`, `currency=USD`, `adjustment=NONE`, `close_kind=UNADJUSTED`, OHLCV, `observed_at`, `source_available_at`, `request_id`, `evidence_id`, `source_sha256`. A default split-adjusted Massive bar **must not** pass.

**`FinancialFactV1`:** `security_id`, `issuer_cik`, `taxonomy`, `concept`, fiscal `period_start/end`, `filing_accepted_at`, `sec_accession`, `first_public_at`, `unit`, `value`, `version_fingerprint`, `vendor_observed_at`, `source_tier`, `evidence_id`. For point-in-time backtesting, `first_public_at` plus relevant accession/filing evidence must be verified; else the fact is `BLOCKED_FOR_ASOF`.

**`IndexConstituentV1`:** `index_code`, `security_id`, `effective_from/to`, `announced_at`, `source_citation`, `license_class`, `known_at`. Record gaps and survivorship restrictions explicitly.

**`NewsEventV1`:** `publisher_article_id`, `provider`, `security_ids`, `published_at`, `first_seen_at`, `source_url`, `content_hash`, `rights`, `evidence_id`.

**`FxReferenceV1` (future validation-only, no price-service change):** `pair`, `value_date`, `provider_code`, `upstream_official_source` or `blend`, `reference_rate`, `retrieved_at`, `evidence_id`. Do not substitute for production `USDTHB` without a separate price contract.

## 5. Validation and constraints to prove before implementation

- **Identity:** CIK is issuer-level; security ID is share-class/instrument-level; detect ticker reuse/delisting; guard effective-date overlap and ensure research identity does not expand the holdings-only price-service identity set.
- **Data types:** positive finite EOD price; exact currency; OHLC coherent; volume nonnegative; no stale NY session; no mixed adjusted/actual regular close.
- **Facts:** concept namespace, period type (instant vs duration), unit scale, amendments/restatements, `source_available_at`, corrected original filing; vendor snapshot marked separately from original filing evidence.
- **Read consistency:** require an accepted validation record and lineage graph for every result exposed to a later research consumer; enforce `first_public_at <= simulated_decision_at` for historical as-of reads.
- **Historical index membership:** a constituent is eligible for simulated time `T` only if its effective-dated membership covers `T` **and** `known_at <= T`; otherwise label the result `CURRENT_UNIVERSE_ONLY` or block the point-in-time claim. A historical constituent list without source rights is not a certified backtest universe.
- **Security:** private schemas not exposed to `anon`/`authenticated`, principle of least privilege, no plaintext credential or service secret in logs, sources, GitHub or Google Sheet.
- **Time:** all timestamps UTC in store with explicit NY exchange session date and separate report/source timezone.
- **Operations:** per capability/provider published quota, locally authorized spend, request fingerprint, timeout/UNKNOWN behavior, rate headers, retry/backoff and same-key idempotency tested with concurrency.
- **License/retention:** restrictive provider terms take precedence over convenient payload storage; no assumption that personal subscription allows data redistribution or unlimited derived-data caching.

## 6. Staged implementation grouping — NOT approved

- **Possible Phase I (minimal private provider pilot):** `provider_registry`, `capability_registry`, `provider_capabilities`, `quota_policies`, `request_ledger` plus non-public read-only fixtures and a reviewed route policy. All default DISABLED/BLOCKED.
- **Possible Phase II (evidence pilot):** `security_master`, `symbol_aliases`, `ingest_batches`, `raw_evidence`, `sec_filings`, `metric_facts`, `validation_results`, `lineage_edges` using small issuer samples.
- **Possible Phase III (broad screening):** `index_memberships`, `bulk_eod_bars` and associated source license/temporal-validation.
- **Possible Phase IV (catalysts):** `news_events`, content-rights/SEC verification and reviewed failover candidate rules.

The phases are **proposed design groupings**, not deployment tasks or approval to add 17 tables to Production. Keep `docs/database/CURRENT.yaml` at DB-ARCH-1.0 until a separately authorized, deployed and verified promotion.
