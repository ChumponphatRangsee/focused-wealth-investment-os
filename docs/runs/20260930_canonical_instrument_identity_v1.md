# Canonical Instrument Identity v1 — 2026-09-30

Issue: #33  
Epic: #31  
Policy: `POL-INSTRUMENT-IDENTITY-V1`  
Contract: `FWIOS-CONTRACT-0.87.13`  
Foundation compatibility: `0.87`

## Scope

Introduced immutable canonical instrument identity beneath existing ticker / asset-symbol interfaces without cutting production reads over.

## Live objects

New:
- `fwios.asset_entities`
- `fwios.instruments`
- `fwios.instrument_symbols`
- `fwios.instrument_identifiers`
- `fwios.v_instrument_identity_current`
- `fwios.resolve_instrument_id_v1()`
- `fwios.current_instrument_symbol_v1()`

Selected legacy anchors now carry nullable/backfilled `instrument_id`:
- companies
- research_candidates
- thesis_registry
- portfolio_assets
- portfolio_transactions
- market_daily_closes
- market_price_quotes
- market_price_snapshots

No legacy primary key or symbol column was removed.

## Backfill

Current canonical seed:
- **70 instruments**
- **64 Stock**
- **6 Crypto**
- **70 asset entities**
- **70 current primary symbols**
- **70 migration-provenance identifiers**

ADBE, PINS and BTC resolve deterministically.

## Identity rules

- Same legal instrument + ticker change => retain `instrument_id`, close old symbol history and add new symbol.
- Distinct share classes => distinct instruments, shared entity allowed.
- Delisting => retain identity/history; close symbol and mark instrument inactive/delisted.
- Relisting reuses ID only when demonstrably the same legal instrument.
- Separately tradable exchange listings => distinct instruments, shared entity allowed.
- Crypto symbol alone is never sufficient long-term identity.
- Ambiguous resolver match => NULL / fail closed.

## Regression

`tests/identity/test_canonical_instrument_identity_v1.sql`

Result: **20/20 PASS**.

Coverage includes:
- active policy / no auto trade / no read cutover;
- exact 70-instrument seed;
- 64 Stock / 6 Crypto;
- current primary symbol coverage;
- active symbol collision prevention;
- deterministic ADBE/PINS/BTC resolution;
- 100% backfill of all 8 selected legacy anchors;
- legacy company and portfolio symbol parity;
- private RLS boundary;
- registered identity regressions all PASS.

## Production parity

Pre/post identity migration remained identical for:

### ADBE
- Revision Score 47.5878
- Revision Gate `FAIL - NEGATIVE FUNDAMENTAL REVISION`
- Thesis Health WEAKENING / 86.5
- Opportunity Score 89.7125
- Final Buy Review `BLOCKED - THESIS HEALTH`

### PINS
- Revision Score 60.5531
- Revision Gate PASS
- Thesis Health WATCH / 87
- Opportunity Score 87.7
- Final Buy Review `BLOCKED - PRICE VERIFY`

### Portfolio
- 10 open dashboard rows
- aggregate quantity 3265.78999991
- cost basis THB 335,340.09
- marked value at parity check THB 353,574.91

No transaction, quantity, cost-basis, approval or trade mutation occurred.

## Security / advisor verification

Identity tables:
- RLS enabled;
- anon/authenticated table privileges revoked;
- service-role only;
- compatibility view uses `security_invoker=true`.

Supabase security advisor reports `RLS enabled / no policy` at INFO level for these internal tables. This is expected under the existing private service-role-only `fwios` pattern because untrusted roles have no table grants. See Supabase RLS guidance: https://supabase.com/docs/guides/database/postgres/row-level-security

Fresh identity indexes may appear as unused immediately after creation; no advisor finding blocks #33.

## Result

Issue #33 acceptance criteria are satisfied at the additive identity-foundation layer.

Next task: **#34 — Decision-Relevant Metric Observation Model v2**.
