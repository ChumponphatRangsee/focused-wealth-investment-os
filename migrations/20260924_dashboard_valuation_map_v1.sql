-- Dashboard Valuation Map v1
-- Display-only valuation scenario map. Does not alter trading/execution policy.

create or replace view fwios.v_dashboard_valuation_map
with (security_invoker = true)
as
with latest_valuation as (
  select distinct on (v.ticker)
    v.ticker,
    v.run_id as valuation_run_id,
    v.model_id,
    v.as_of_text as valuation_as_of,
    v.created_at as valuation_created_at,
    v.current_price as valuation_reference_price,
    v.bear_fv_per_share,
    v.base_fv_per_share,
    v.bull_fv_per_share,
    v.probability_weighted_fv_per_share
  from fwios.valuation_runs v
  where v.production_eligible = true
    and v.bear_fv_per_share is not null
    and v.base_fv_per_share is not null
    and v.bull_fv_per_share is not null
    and v.probability_weighted_fv_per_share is not null
  order by v.ticker, v.created_at desc
),
latest_candidate as (
  select distinct on (r.ticker)
    r.ticker,
    r.promotion_gate,
    r.mispricing_gate as candidate_mispricing_gate,
    r.final_decision,
    r.updated_at
  from fwios.research_candidates r
  order by r.ticker, r.updated_at desc
),
latest_mispricing as (
  select distinct on (m.ticker)
    m.ticker,
    m.effective_mispricing_gate,
    m.effective_mispricing_class,
    m.created_at
  from fwios.v_valuation_mispricing_current m
  order by m.ticker, m.created_at desc
),
base as (
  select
    c.sector,
    v.ticker,
    c.company_name,
    coalesce(p.selected_price, v.valuation_reference_price) as current_price,
    p.session_date as price_session_date,
    coalesce(p.effective_price_gate, 'BLOCKED - NO CURRENT PRICE') as price_gate,
    v.bear_fv_per_share as bear_fv,
    v.base_fv_per_share as base_fv,
    v.bull_fv_per_share as high_fv,
    v.probability_weighted_fv_per_share as fair_value,
    case when coalesce(p.selected_price, v.valuation_reference_price) > 0
      then v.bear_fv_per_share / coalesce(p.selected_price, v.valuation_reference_price) - 1 end as bear_upside,
    case when coalesce(p.selected_price, v.valuation_reference_price) > 0
      then v.base_fv_per_share / coalesce(p.selected_price, v.valuation_reference_price) - 1 end as base_upside,
    case when coalesce(p.selected_price, v.valuation_reference_price) > 0
      then v.bull_fv_per_share / coalesce(p.selected_price, v.valuation_reference_price) - 1 end as high_upside,
    case when coalesce(p.selected_price, v.valuation_reference_price) > 0
      then v.probability_weighted_fv_per_share / coalesce(p.selected_price, v.valuation_reference_price) - 1 end as fair_value_upside,
    v.valuation_as_of,
    v.model_id,
    v.valuation_run_id,
    lc.promotion_gate,
    coalesce(lm.effective_mispricing_gate, lc.candidate_mispricing_gate, 'PENDING PRICE') as mispricing_gate
  from latest_valuation v
  left join fwios.companies c on c.ticker = v.ticker
  left join fwios.v_market_price_latest p on p.asset_symbol = v.ticker
  left join latest_candidate lc on lc.ticker = v.ticker
  left join latest_mispricing lm on lm.ticker = v.ticker
)
select
  sector,
  ticker,
  company_name,
  current_price,
  price_session_date,
  price_gate,
  bear_fv,
  base_fv,
  high_fv,
  fair_value,
  bear_upside,
  base_upside,
  high_upside,
  fair_value_upside,
  case
    when current_price is null then 'PRICE MISSING'
    when current_price <= bear_fv then 'HIGH UPSIDE / BELOW BEAR FV'
    when current_price <= base_fv then 'BASE VALUE ZONE'
    when current_price <= high_fv then 'BULL CASE ONLY'
    else 'ABOVE BULL FV'
  end as price_zone,
  case
    when price_gate <> 'PASS' then 'PRICE VERIFY'
    when mispricing_gate = 'PASS' and promotion_gate = 'PASS' then 'BUY REVIEW'
    when current_price <= base_fv then 'VALUE WATCH'
    else 'WAIT'
  end as system_signal,
  mispricing_gate,
  valuation_as_of,
  model_id,
  valuation_run_id
from base
order by
  case
    when price_gate = 'PASS' and mispricing_gate = 'PASS' and promotion_gate = 'PASS' then 0
    when current_price <= bear_fv then 1
    when current_price <= base_fv then 2
    when current_price <= high_fv then 3
    else 4
  end,
  fair_value_upside desc nulls last,
  ticker;

revoke all on fwios.v_dashboard_valuation_map from public, anon, authenticated;

comment on view fwios.v_dashboard_valuation_map is
'Display-only valuation map: latest production-eligible Bear/Base/High/PW fair values, latest accepted-or-reference price, valuation zone and conservative system signal. PRICE VERIFY blocks actionable interpretation when price freshness fails.';

create or replace function fwios.dashboard_refresh_payload_v1()
returns jsonb
language sql
stable
set search_path to pg_catalog, fwios
as $function$
with
account_summary as (
  select coalesce(jsonb_agg(to_jsonb(a) order by case when a.account_view_key='ALL' then 0 else 1 end, a.account_view_name), '[]'::jsonb) v
  from fwios.v_dashboard_account_summary a
),
holdings as (
  select coalesce(jsonb_agg(to_jsonb(h) order by case when h.account_view_key='ALL' then 0 else 1 end, h.account_view_key, h.value_thb desc, h.asset_symbol), '[]'::jsonb) v
  from fwios.v_dashboard_holdings h
),
opportunities as (
  select coalesce(jsonb_agg(to_jsonb(o) order by case o.opportunity_bucket when 'IMMEDIATE_BUY_CANDIDATE' then 0 when 'WATCHLIST_VALUE_WAIT' then 1 else 2 end, o.bucket_rank, o.ticker), '[]'::jsonb) v
  from fwios.v_dashboard_opportunities o
),
valuation_map as (
  select coalesce(jsonb_agg(to_jsonb(v)), '[]'::jsonb) v
  from fwios.v_dashboard_valuation_map v
),
current_action as (
  select coalesce(jsonb_agg(to_jsonb(c)), '[]'::jsonb) v
  from fwios.v_dashboard_current_action c
),
alerts as (
  select coalesce(jsonb_agg(to_jsonb(a) order by a.alert_order), '[]'::jsonb) v
  from fwios.v_dashboard_alerts a
),
system_health as (
  select coalesce(jsonb_agg(to_jsonb(s) - 'read_model_checked_at'), '[]'::jsonb) v,
         max(s.portfolio_batch_status) portfolio_batch_status,
         max(s.source_transaction_count) source_transaction_count,
         max(s.transaction_pass_count) transaction_pass_count,
         max(s.source_position_count) source_position_count,
         max(s.position_pass_count) position_pass_count,
         bool_or(s.auto_trade) auto_trade,
         bool_and(s.human_execution_only) human_execution_only,
         max(s.contract_id) contract_id,
         max(s.portfolio_batch_id) portfolio_batch_id
  from fwios.v_dashboard_system_health s
),
payload as (
  select jsonb_build_object(
    'account_summary', account_summary.v,
    'holdings', holdings.v,
    'opportunities', opportunities.v,
    'valuation_map', valuation_map.v,
    'current_action', current_action.v,
    'alerts', alerts.v,
    'system_health', system_health.v
  ) data,
  system_health.*
  from account_summary, holdings, opportunities, valuation_map, current_action, alerts, system_health
)
select jsonb_build_object(
  'schema_version', 'DASHBOARD_REFRESH_PAYLOAD_V1_1',
  'sheet_id', '17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8',
  'generated_at', now(),
  'contract_id', contract_id,
  'portfolio_batch_id', portfolio_batch_id,
  'refresh_gate', case
    when portfolio_batch_status='PASS'
     and source_transaction_count=transaction_pass_count
     and source_position_count=position_pass_count
     and coalesce(auto_trade,false)=false
     and coalesce(human_execution_only,false)=true
    then 'PASS' else 'BLOCKED' end,
  'source_fingerprint', md5(data::text),
  'data', data
)
from payload;
$function$;

revoke all on function fwios.dashboard_refresh_payload_v1() from public, anon, authenticated;
grant execute on function fwios.dashboard_refresh_payload_v1() to service_role;
