-- PR5 readiness audit (read only): each active market asset must have an
-- original PASS USD market observation. Raw THB/FX is not USD coverage.
-- Source presence is NOT proof of current price freshness/valuation eligibility.
with active as (
  select i.instrument_id, id.asset_symbol, i.asset_class
  from fwios.instruments i
  join fwios.v_instrument_identity_current id
    on id.instrument_id=i.instrument_id
  where i.lifecycle_status='ACTIVE'
    and i.asset_class in ('Crypto','Stock')
), coverage as (
  select a.*,
    (select max(o.observed_at)
     from fwios.market_observations o
     where o.instrument_id=a.instrument_id
       and o.value_currency='USD'
       and o.observation_type in
          ('LIVE_QUOTE','REGULAR_CLOSE','PRE_MARKET','AFTER_HOURS')
       and o.provenance_status='PASS' and o.observation_value>0
    ) as latest_native_usd_observed_at,
    exists (
     select 1 from fwios.market_observations o
     where o.instrument_id=a.instrument_id
       and o.value_currency='THB'
       and o.observation_type in
          ('LIVE_QUOTE','REGULAR_CLOSE','PRE_MARKET','AFTER_HOURS')
       and o.provenance_status='PASS' and o.observation_value>0
    ) as legacy_thb_asset_quote_present
  from active a
)
select asset_symbol, asset_class,
  case when latest_native_usd_observed_at is not null
       then 'USD_SOURCE_PRESENT_NOT_FRESHNESS_CERTIFIED'
       else 'USD_SOURCE_MISSING' end as usd_source_status,
  latest_native_usd_observed_at,
  legacy_thb_asset_quote_present
from coverage
order by case when latest_native_usd_observed_at is null then 0 else 1 end,
         asset_class, asset_symbol;
