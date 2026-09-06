create table if not exists fwios.dashboard_refresh_access (
  access_key text primary key,
  token_sha256 text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  rotated_at timestamptz not null default now()
);

create table if not exists fwios.dashboard_refresh_cache (
  cache_key text primary key,
  payload jsonb not null,
  source_fingerprint text not null,
  contract_id text not null,
  portfolio_batch_id text,
  last_good_at timestamptz not null,
  updated_at timestamptz not null default now(),
  constraint dashboard_refresh_cache_key_chk check (cache_key='PRIMARY')
);

alter table fwios.dashboard_refresh_access enable row level security;
alter table fwios.dashboard_refresh_cache enable row level security;
revoke all on fwios.dashboard_refresh_access from public, anon, authenticated;
revoke all on fwios.dashboard_refresh_cache from public, anon, authenticated;
grant select, insert, update on fwios.dashboard_refresh_access to service_role;
grant select, insert, update on fwios.dashboard_refresh_cache to service_role;

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
    'current_action', current_action.v,
    'alerts', alerts.v,
    'system_health', system_health.v
  ) data,
  system_health.*
  from account_summary, holdings, opportunities, current_action, alerts, system_health
)
select jsonb_build_object(
  'schema_version', 'DASHBOARD_REFRESH_PAYLOAD_V1',
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

drop function if exists fwios.dashboard_refresh_serve_v1();
