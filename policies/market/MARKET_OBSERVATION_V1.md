# Unified Market Observation Layer v1

Policy: `POL-MARKET-OBSERVATION-V1`  
Epic: #31  
Issue: #36  
Production read-path cutover: **NO**

## Purpose

Provide one canonical, provider-aware market observation model beneath the existing decision-price, daily-close and portfolio-MTM paths.

Supported observation types:
- `REGULAR_CLOSE`
- `LIVE_QUOTE`
- `PRE_MARKET`
- `AFTER_HOURS`
- `FX`

Every observation is keyed by canonical `instrument_id` and retains source/provider, tier, time/session, currency and provenance semantics.

## Live objects

- `fwios.market_observations` — immutable canonical source observations
- `fwios.market_observation_legacy_links` — legacy-source → canonical-observation bridge
- `fwios.market_verification_sets` — primary/secondary observation comparison for Decision Price and Daily Close
- `fwios.v_market_price_quotes_observation_compat`
- `fwios.v_market_daily_closes_observation_compat`
- `fwios.v_market_price_snapshots_observation_compat`
- `fwios.v_portfolio_market_quotes_observation_compat`

## Dual-write compatibility

Existing production consumers remain authoritative.

Legacy writers are synchronized by four database triggers:
- decision quote → canonical observation
- daily close → primary/secondary observations + verification set
- price snapshot → observation-backed Decision Price verification
- portfolio MTM quote → native-price observation + FX observation when required

This keeps new writes lineage-complete without changing existing read semantics.

## Verification semantics

A verification set keeps:
- primary observation ID
- optional secondary observation ID
- optional selected observation ID
- selected value
- divergence
- allowed divergence
- conflict/verification state
- final gate

A derived selected price such as an average may have no single selected observation ID; its two source observation IDs remain explicit.

## PINS regression anchors

### September 4, 2026
- primary: $20.28
- crosscheck: $20.30
- divergence: 0.000986193293885602
- conflict: PASS
- price gate: PASS

The two provider values are separate canonical observations.

### September 10, 2026
- selected price: $18.655
- divergence: 0.012597158938622352
- conflict: CONFLICT
- price gate: `BLOCKED - PRICE CONFLICT`

The existing fail-closed conflict behavior is unchanged.

## Portfolio MTM

Every existing portfolio quote is mapped to a canonical market observation.

Foreign-currency Stock MTM rows also reference an explicit FX observation. For example, USD→THB conversion retains the FX provider and timestamp from the existing quote payload.

## Safety / boundary

- `production_read_cutover=false`
- no manual web price bypass
- no provider-tier weakening
- no change to target-session logic
- no change to mispricing formulas
- no change to portfolio accounting
- no auto-trade
- human execution only
- canonical market observations are immutable; legacy compatibility rows remain mutable under their existing semantics
