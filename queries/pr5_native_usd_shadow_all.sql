-- PR5 / read native USD shadow quotes for all active canonical instruments.
-- SELECT ONLY: no provider fetch, API usage, quota reservation or write.
-- Does NOT authorize valuation or Google Sheets accounting cutover.
with supported as (
  select distinct id.asset_symbol as asset
  from fwios.instruments i
  join fwios.v_instrument_identity_current id
    on id.instrument_id=i.instrument_id
  where i.lifecycle_status='ACTIVE'
    and i.asset_class in ('Stock','Crypto')
    and not(i.metadata ? 'qa_identity')
), shadow as materialized (
  select asset, fwios.pr5_native_usd_price_shadow_v1(asset) as quote
  from supported
)
select
  asset,
  quote->>'asset_class' as asset_class,
  quote->>'status' as freshness_status,
  (quote->>'price_usd')::numeric as price_usd,
  quote->>'currency' as currency,
  quote->>'provider' as provider,
  quote->>'quote_kind' as quote_kind,
  (quote->>'observed_at')::timestamptz as observed_at,
  (quote->>'valid_until')::timestamptz as valid_until,
  quote->>'observation_id' as observation_id,
  (quote->>'source_native_usd')::boolean as source_native_usd,
  (quote->>'valuation_eligible')::boolean as valuation_eligible,
  quote->>'reason' as missing_reason
from shadow
order by
  case when quote->>'status'='MISSING' then 0 else 1 end,
  asset_class,asset;
