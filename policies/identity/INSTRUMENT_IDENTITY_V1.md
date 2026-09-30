# Canonical Instrument Identity v1

Policy: `POL-INSTRUMENT-IDENTITY-V1`  
Epic: #31  
Issue: #33  
Production read-path cutover: **NO**

## Purpose

Separate immutable investment identity from display symbols.

A ticker or crypto symbol is a label that may change or collide. FWIOS uses an immutable `instrument_id` as the long-term key while preserving existing `ticker` and `asset_symbol` interfaces during migration.

## Core objects

### asset_entities
Economic/legal/network entity.

Examples:
- company,
- crypto network/protocol,
- fund,
- other economic entity.

One entity may own or underlie multiple tradable instruments.

### instruments
One tradable instrument/listing.

Key fields:
- `instrument_id` — immutable UUID,
- `entity_id`,
- asset class,
- instrument type,
- primary venue,
- trading currency,
- lifecycle status.

### instrument_symbols
Time-bounded symbol history.

A current active identity key is:

`symbol + venue + symbol_namespace`

The combination is unique for active symbols.

### instrument_identifiers
Durable external/provider identifiers can be attached independently of display symbols.

Examples for later enrichment:
- ISIN,
- FIGI,
- CIK,
- exchange security ID,
- crypto network/provider ID,
- contract address.

The initial `LEGACY_SEED` identifier is migration provenance only and is not a durable external identifier.

## Required behavior

### Ticker change
If the same legal/tradable instrument changes ticker:
- retain the same `instrument_id`,
- close the old symbol row,
- add the new symbol row,
- do not rewrite historical lineage.

### Share classes
Each separately tradable share class receives its own `instrument_id`.

Multiple share-class instruments may share one `entity_id`.

### Delisting
- retain `instrument_id`,
- close the active symbol row,
- set instrument lifecycle to `DELISTED` or `INACTIVE`,
- retain all research/decision/portfolio history.

### Relisting
Reuse the prior `instrument_id` only when it is demonstrably the same legal instrument.

A new legal security after merger/reorganization receives a new `instrument_id`.

### Multi-exchange
A separately tradable listing on another exchange uses a distinct `instrument_id` and may share the same `entity_id`.

This prevents exchange-local symbol ambiguity from leaking into portfolio accounting.

### Crypto symbol collisions
Crypto symbol alone is never sufficient identity.

Future token/network onboarding must attach a durable namespace/identifier such as:
- native network identity,
- contract chain + contract address,
- verified provider asset ID.

Colliding symbols must use distinct `symbol_namespace` and durable identifiers.

## Resolver behavior

`resolve_instrument_id_v1(symbol, asset_class, venue, symbol_namespace)`

returns an ID only when exactly one active instrument matches.

Zero matches or multiple matches => `NULL`.

The resolver never guesses.

## Migration scope

Issue #33 adds `instrument_id` to these existing anchor tables:

- `companies`
- `research_candidates`
- `thesis_registry`
- `portfolio_assets`
- `portfolio_transactions`
- `market_daily_closes`
- `market_price_quotes`
- `market_price_snapshots`

The columns remain nullable during migration even though all current rows are backfilled.

No legacy key is removed.

## Compatibility

`v_instrument_identity_current` exposes:
- `instrument_id`,
- `asset_symbol`,
- stock `ticker`,
- exchange,
- currency,
- entity information.

Legacy production views and dashboard queries remain unchanged.

## Security

Identity tables are private/internal:
- RLS enabled,
- public/anon/authenticated privileges revoked,
- service-role access only.

## Non-goals

This phase does not:
- rewrite all 48 ticker tables,
- rewrite all 20 asset-symbol tables,
- change decision scoring,
- change valuation logic,
- change portfolio quantities/cost basis,
- execute trades,
- cut dashboards over to instrument IDs.

Those migrations proceed incrementally in later Epic #31 phases.
