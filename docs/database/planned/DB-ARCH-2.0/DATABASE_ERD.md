# DB-ARCH-2.0 — Proposed Entity Relationships
**STATUS: PLANNED / NOT DEPLOYED**. All edges below are **future design relationships**, not asserted current-production FKs. **Safety invariant:** `auto_trade=false`; no portfolio accounting or canonical price history mutation. Physical FKs should be applied only where explicit in [TABLE_CATALOG.md](TABLE_CATALOG.md) after separate implementation authorization.

## Existing current price-service footprint (separate, not redefined)

```mermaid
flowchart LR
  subgraph CURRENT["CURRENT DB-ARCH-1.0 — do not mutate"]
    FI["fwios.instruments"] --> FS["fwios.instrument_symbols"]
    FI --> FO["fwios.market_observations (append-only)"]
    FQ["fwios_quota.api_call_ledger (price-only)"]
  end
  subgraph PLANNED["PLANNED DB-ARCH-2.0 — design only"]
    CP["fwios_provider (six tables)"]
    RE["fwios_research (eleven tables)"]
    CP --> RE
  end
  RE -. "explicit reviewed research identity linkage only; no automatic price writes" .-> FI
```

## Proposed Provider Control Plane (six new tables, all not deployed)

```mermaid
erDiagram
  provider_registry ||--o{ provider_capabilities : advertises
  capability_registry ||--o{ provider_capabilities : defines
  provider_capabilities ||--o{ route_policies : selected_by_policy
  provider_capabilities ||--o{ quota_policies : budgeted_by
  provider_registry ||--o{ request_ledger : called
  capability_registry ||--o{ request_ledger : tracks

  provider_registry {
    uuid provider_id PK
    text provider_code UK
    text operational_status
    text license_class
    text credential_alias
  }
  capability_registry {
    uuid capability_id PK
    text capability_code UK
    text contract_version
    text expected_semantics
  }
  provider_capabilities {
    uuid provider_capability_id PK
    uuid provider_id FK
    uuid capability_id FK
    text entitlement_state
    text scope_class
  }
  route_policies {
    uuid route_policy_id PK
    uuid provider_capability_id FK
    int policy_version
    jsonb candidates_and_gates
    boolean auto_fallback_allowed
  }
  quota_policies {
    uuid quota_policy_id PK
    uuid provider_capability_id FK
    int credits_per_minute
    int credits_per_day
    numeric max_monthly_spend_usd
  }
  request_ledger {
    uuid request_id PK
    uuid provider_id FK
    uuid capability_id FK
    text request_fingerprint UK
    text state
    timestamptz reserved_at
    timestamptz dispatched_at
  }
```

`route_policies.candidates_and_gates` has a required schema/validator and versioned ordered candidates; an unreviewed JSON route is not executable. For a production implementation, consider normalizing route candidates to a separate relation if review, queryability or effective-dating demands it.

## Proposed Research/Evidence Plane (eleven new tables, all not deployed)

```mermaid
erDiagram
  security_master ||--o{ symbol_aliases : resolves
  security_master ||--o{ index_memberships : constituent
  security_master ||--o{ bulk_eod_bars : observed
  security_master ||--o{ metric_facts : issuer_security_link
  security_master ||--o{ news_events : associated
  sec_filings ||--o{ metric_facts : primary_filing
  raw_evidence ||--o{ sec_filings : filing_payload
  raw_evidence ||--o{ bulk_eod_bars : bar_payload
  raw_evidence ||--o{ metric_facts : normalized_from
  raw_evidence ||--o{ news_events : article_payload
  ingest_batches ||--o{ raw_evidence : received_in
  raw_evidence ||--o{ validation_results : assessed
  metric_facts ||--o{ validation_results : assessed
  raw_evidence ||--o{ lineage_edges : participates
  metric_facts ||--o{ lineage_edges : participates

  security_master {
    uuid security_id PK
    text security_type
    text cik
    text figi
  }
  symbol_aliases {
    uuid alias_id PK
    uuid security_id FK
    text ticker
    date valid_from
    date valid_to
  }
  index_memberships {
    uuid membership_id PK
    uuid security_id FK
    text index_code
    date effective_from
    date effective_to
  }
  ingest_batches {
    uuid batch_id PK
    text capability
    text target_as_of
    text batch_status
  }
  raw_evidence {
    uuid evidence_id PK
    uuid batch_id FK
    uuid request_id
    text content_sha256
    text private_object_key
  }
  bulk_eod_bars {
    uuid bar_id PK
    uuid security_id FK
    uuid evidence_id FK
    date session_date
    numeric close_unadjusted
  }
  sec_filings {
    uuid filing_id PK
    uuid evidence_id FK
    text sec_accession UK
    timestamptz accepted_at
  }
  metric_facts {
    uuid fact_id PK
    uuid evidence_id FK
    uuid security_id FK
    uuid filing_id FK
    text taxonomy_concept
    numeric metric_value
    timestamptz first_public_at
  }
  news_events {
    uuid event_id PK
    uuid evidence_id FK
    uuid security_id FK
    text publisher_article_id
    timestamptz first_seen_at
  }
  validation_results {
    uuid validation_id PK
    uuid evidence_id FK
    text verdict
    text check_version
  }
  lineage_edges {
    uuid lineage_id PK
    text source_ref
    text target_ref
    text relationship
  }
```

### Cross-schema FK policy (future, not actual)

- `fwios_research.raw_evidence.request_id` may FK to `fwios_provider.request_ledger.request_id` **only after** the write-order/error-isolation design is reviewed. Until then it is a logical link with deterministic reconciliation checks.
- No FK from research security master to `fwios.instruments` in v1. A user holding an instrument does **not** automatically create 500 research price identities in the price service.
- `lineage_edges` is a typed logical audit graph; it is not a replacement for mandatory FKs on core evidence tables. Invalid references must fail validation.

## Cardinality and operational requirements

- One provider offers multiple capabilities; the same capability may have multiple provider/plan implementations.
- Multiple fact versions can exist for one issuer/concept/period; immutable source accession and `first_public_at` decide an **as-of** read.
- Index membership is effective-dated; never infer past membership from today's list.
- One fetch request can produce a batch of evidence items; each accepted item retains exact request provenance.
- Current production has **zero** tables from these two proposed private schemas. Their presence in diagrams is design intent only.
