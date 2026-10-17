
-- The legacy THB compatibility quote path is not the source used by Price Data.
-- Align the derived, read-only valuation with native USD + validated USDTHB FX.
create or replace view fwios.v_portfolio_live_account_valuation_v1 as
with fx as (
 select observation_value::numeric rate,provider,observation_id
 from fwios.market_observations
 where observation_type='FX' and value_currency='THB'
   and provenance_status='PASS' and observation_value>0
 order by observed_at desc,created_at desc limit 1
), prices as (
 select p.account_key,p.asset_symbol,p.quantity,p.received_at,p.batch_id,
        fwios.pr7_native_usd_price_read_v1(p.asset_symbol) native
 from fwios.v_portfolio_live_positions_current_v1 p
)
select case when grouping(p.account_key)=1 then 'ALL' else p.account_key end account_view_key,
 count(*)::integer open_position_rows,
 count(distinct p.asset_symbol)::integer unique_open_assets,
 sum(p.quantity * nullif(p.native->>'price_usd','')::numeric * fx.rate) portfolio_value_thb,
 count(*) filter (where fx.rate is null or (p.native->>'valuation_eligible')::boolean is distinct from true
   or nullif(p.native->>'price_usd','')::numeric is null)::integer unpriced_positions,
 min(p.received_at) projection_received_at,
 max(p.batch_id::text) source_batch_id,
 case when count(*) filter (where fx.rate is null or (p.native->>'valuation_eligible')::boolean is distinct from true
   or nullif(p.native->>'price_usd','')::numeric is null)=0
 then 'PASS' else 'BLOCKED' end valuation_gate
from prices p left join fx on true
group by grouping sets ((p.account_key),());
revoke all on fwios.v_portfolio_live_account_valuation_v1 from anon,authenticated;
