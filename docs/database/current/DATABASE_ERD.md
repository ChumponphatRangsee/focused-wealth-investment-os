# FWIOS Database ERD

**Architecture version:** DB-ARCH-1.0  
**Doc revision:** DOC-REV-3  
**Status:** CURRENT  
**Verified against live Supabase:** 2026-11-06 10:26:42 UTC

## Core application ERD

```mermaid
erDiagram
    INSTRUMENTS ||--o{ INSTRUMENT_SYMBOLS : "has symbol mappings"
    INSTRUMENTS ||--o{ MARKET_OBSERVATIONS : "has observations"

    INSTRUMENTS {
        uuid instrument_id PK
        uuid entity_id
        text asset_class
        text instrument_type
        text primary_venue
        text trading_currency
        text lifecycle_status
        jsonb metadata
        timestamptz created_at
        timestamptz updated_at
    }

    INSTRUMENT_SYMBOLS {
        uuid instrument_symbol_id PK
        uuid instrument_id FK
        text symbol
        text venue
        text symbol_namespace
        boolean is_primary
        boolean active
        date valid_from
        date valid_to
        jsonb metadata
        timestamptz created_at
        timestamptz updated_at
    }

    MARKET_OBSERVATIONS {
        uuid observation_id PK
        text observation_key UK
        uuid instrument_id FK
        text observation_type
        numeric observation_value
        text value_currency
        text fx_base_currency
        text fx_quote_currency
        date session_date
        timestamptz observed_at
        text market_status
        text provider
        text source_tier
        text source_url
        text provenance_status
        jsonb raw_payload
        timestamptz created_at
    }

    API_CALL_LEDGER {
        uuid call_id PK
        text provider
        text key_alias
        text batch_id
        date session_date
        text symbol
        text endpoint
        text state
        timestamptz reserved_at
        timestamptz dispatched_at
        timestamptz completed_at
        text error_code
        timestamptz blocked_until
    }
```

## Relationship notes

### `fwios.instruments -> fwios.instrument_symbols`

Physical FK:

`instrument_symbols.instrument_id -> instruments.instrument_id`

An instrument may have multiple symbol mappings over time. The current identity read selects active, non-expired, primary symbol mappings.

### `fwios.instruments -> fwios.market_observations`

Physical FK:

`market_observations.instrument_id -> instruments.instrument_id`

Each price/FX observation is anchored to a canonical instrument.

### `fwios_quota.api_call_ledger`

There is deliberately **no physical FK** from the quota ledger to the canonical price tables.

The ledger records provider request reservations/outcomes by provider, batch, session and symbol. It is operational state. A successful provider call may lead to a canonical market observation only after worker validation.

## Current identity view

```mermaid
flowchart LR
    I["fwios.instruments"] --> V["fwios.v_instrument_identity_current"]
    S["fwios.instrument_symbols<br/>active + primary + non-expired"] --> V
    V --> R["resolve/read functions"]
```

The view is a read projection, not a table and not a second identity authority.

## Important non-relational logical link

`api_call_ledger.symbol` and `batch_id` can be correlated operationally with provider collection, but this is not a referential FK to `instrument_symbols` or `market_observations`. Do not add a relationship line in the ERD unless a future approved schema creates a real FK or durable lineage key.

## Current vs future

This ERD contains only the current application relations.

Do not add Provider Registry, Capability Registry, raw-provider tables, normalized fundamentals, filing evidence, scoring or valuation tables here until they are actually deployed and verified as CURRENT.
