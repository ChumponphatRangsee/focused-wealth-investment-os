-- Portfolio Mark-to-Market V1
-- Separates market pricing from the portfolio ledger.
-- Transactions, quantities and cost basis remain authoritative and unchanged.
-- Dashboard/exposure views use a fresh market quote cache; fail closed when quote coverage is incomplete.

insert into fwios.policy_registry(policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status)
values(
  'PORTFOLIO_MARK_TO_MARKET_V1',
  'PORTFOLIO_VALUATION',
  'Portfolio Mark-to-Market V1',
  'Automatically mark open portfolio positions to fresh market prices without mutating transactions, quantities, or cost basis.',
  'fwios.v_portfolio_market_quote_current',
  'ACTIVE'
)
on conflict(policy_key) do update set
  policy_domain=excluded.policy_domain,
  policy_name=excluded.policy_name,
  purpose=excluded.purpose,
  backing_object=excluded.backing_object,
  lifecycle_status='ACTIVE',
  updated_at=now();

insert into fwios.policy_versions(
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference,effective_at
)
values(
  'POL-PORTFOLIO-MTM-V1',
  'PORTFOLIO_MARK_TO_MARKET_V1',
  '1.0','ACTIVE',true,
  jsonb_build_object(
    'refresh_cadence_minutes',15,
    'crypto_provider','COINGECKO',
    'stock_provider','TWELVE_DATA',
    'fx_primary_provider','TWELVE_DATA',
    'fx_fallback_provider','FRANKFURTER',
    'crypto_fresh_minutes',45,
    'stock_fresh_hours_weekday',48,
    'stock_fresh_hours_weekend',96,
    'stock_poll_utc_window','13:00-22:00 Mon-Fri',
    'market_price_required_for_dashboard_refresh',true,
    'transaction_mutation',false,
    'quantity_mutation',false,
    'cost_basis_mutation',false,
    'auto_trade',false
  ),
  'FWIOS Portfolio Mark-to-Market V1',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status='ACTIVE',
  deterministic_scoring=true,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=coalesce(fwios.policy_versions.effective_at,excluded.effective_at);

create table if not exists fwios.portfolio_market_quote_snapshots (
  quote_id uuid primary key default gen_random_uuid(),
  asset_symbol text not null,
  asset_class text not null,
  price_native numeric not null check(price_native>0),
  native_currency text not null,
  fx_rate_thb numeric,
  price_thb numeric not null check(price_thb>0),
  provider text not null,
  source_tier text not null,
  observed_at timestamptz not null,
  valid_until timestamptz not null,
  market_status text,
  provenance_status text not null default 'PASS',
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table fwios.portfolio_market_quote_snapshots enable row level security;
revoke all on fwios.portfolio_market_quote_snapshots from public,anon,authenticated;
grant select,insert,update,delete on fwios.portfolio_market_quote_snapshots to service_role;

create index if not exists portfolio_market_quote_latest_idx
  on fwios.portfolio_market_quote_snapshots(asset_symbol,observed_at desc,created_at desc);

create table if not exists fwios.portfolio_mtm_runs (
  run_id uuid primary key default gen_random_uuid(),
  run_source text not null,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  asset_count integer not null default 0,
  fresh_asset_count integer not null default 0,
  portfolio_value_thb numeric,
  pricing_gate text not null default 'RUNNING',
  stock_refresh_attempted boolean not null default false,
  crypto_refresh_attempted boolean not null default false,
  fx_rate_thb numeric,
  detail jsonb not null default '{}'::jsonb
);

alter table fwios.portfolio_mtm_runs enable row level security;
revoke all on fwios.portfolio_mtm_runs from public,anon,authenticated;
grant select,insert,update,delete on fwios.portfolio_mtm_runs to service_role;

create or replace view fwios.v_portfolio_market_quote_current
with (security_invoker=true)
as
select distinct on (q.asset_symbol)
  q.quote_id,q.asset_symbol,q.asset_class,q.price_native,q.native_currency,q.fx_rate_thb,q.price_thb,
  q.provider,q.source_tier,q.observed_at,q.valid_until,q.market_status,q.provenance_status,
  case when q.provenance_status='PASS' and now()<=q.valid_until then 'FRESH' else 'STALE' end freshness_status,
  q.raw_payload
from fwios.portfolio_market_quote_snapshots q
where q.provenance_status='PASS'
order by q.asset_symbol,q.created_at desc,q.quote_id desc;

revoke all on fwios.v_portfolio_market_quote_current from public,anon,authenticated;
grant select on fwios.v_portfolio_market_quote_current to service_role;

create or replace view fwios.v_portfolio_market_price_health
with (security_invoker=true)
as
with open_assets as (
  select distinct p.asset_symbol,p.asset_class
  from fwios.v_portfolio_positions_current p
  where upper(p.source_position_status)='OPEN' and coalesce(p.quantity,0)>0
),
x as (
  select a.asset_symbol,a.asset_class,q.provider,q.observed_at,q.valid_until,q.freshness_status
  from open_assets a
  left join fwios.v_portfolio_market_quote_current q on q.asset_symbol=a.asset_symbol
)
select
  count(*)::integer open_asset_count,
  count(*) filter(where freshness_status='FRESH')::integer fresh_asset_count,
  count(*) filter(where freshness_status is null)::integer missing_asset_count,
  count(*) filter(where freshness_status='STALE')::integer stale_asset_count,
  min(observed_at) filter(where freshness_status='FRESH') oldest_fresh_quote_at,
  max(observed_at) latest_quote_at,
  case
    when count(*)>0 and count(*)=count(*) filter(where freshness_status='FRESH') then 'PASS'
    else 'BLOCKED - MARKET PRICE COVERAGE'
  end pricing_gate,
  coalesce(jsonb_agg(jsonb_build_object(
    'asset_symbol',asset_symbol,'asset_class',asset_class,'provider',provider,
    'observed_at',observed_at,'valid_until',valid_until,
    'freshness_status',coalesce(freshness_status,'MISSING')
  ) order by asset_symbol),'[]'::jsonb) asset_detail
from x;

revoke all on fwios.v_portfolio_market_price_health from public,anon,authenticated;
grant select on fwios.v_portfolio_market_price_health to service_role;

create or replace view fwios.v_portfolio_positions_marked_current
with (security_invoker=true)
as
select
  p.batch_id,p.account_name,p.account_key,p.asset_symbol,p.asset_class,p.target_bucket,
  p.quantity,p.cost_basis_thb,p.source_snapshot_price_thb,p.source_snapshot_value_thb,
  p.source_unrealized_pnl_thb,p.source_return_pct,p.source_allocation_pct,p.source_position_status,
  q.price_thb market_price_thb,
  case when q.freshness_status='FRESH' then p.quantity*q.price_thb else p.source_snapshot_value_thb end marked_value_thb,
  case when q.freshness_status='FRESH' then p.quantity*q.price_thb-p.cost_basis_thb else p.source_unrealized_pnl_thb end marked_unrealized_pnl_thb,
  q.provider price_provider,q.observed_at price_observed_at,q.valid_until price_valid_until,
  coalesce(q.freshness_status,'MISSING') price_freshness_status
from fwios.v_portfolio_positions_current p
left join fwios.v_portfolio_market_quote_current q on q.asset_symbol=p.asset_symbol;

revoke all on fwios.v_portfolio_positions_marked_current from public,anon,authenticated;
grant select on fwios.v_portfolio_positions_marked_current to service_role;

create or replace view fwios.v_dashboard_holdings
with (security_invoker=true)
as
with latest_batch as (
  select batch_id,observed_at from fwios.v_latest_portfolio_batch
),
open_positions as (
  select p.*
  from fwios.v_portfolio_positions_marked_current p
  join latest_batch b on b.batch_id=p.batch_id
  where upper(p.source_position_status)='OPEN' and coalesce(p.marked_value_thb,0)>0
),
all_rows as (
  select 'ALL'::text account_view_key,'All Accounts'::text account_view_name,
         asset_symbol,asset_class,sum(quantity) quantity,sum(cost_basis_thb) cost_basis_thb,
         sum(marked_value_thb) value_thb,sum(marked_unrealized_pnl_thb) unrealized_pnl_thb,
         max(price_observed_at) observed_at
  from open_positions group by asset_symbol,asset_class
),
account_rows as (
  select account_key account_view_key,account_name account_view_name,
         asset_symbol,asset_class,sum(quantity) quantity,sum(cost_basis_thb) cost_basis_thb,
         sum(marked_value_thb) value_thb,sum(marked_unrealized_pnl_thb) unrealized_pnl_thb,
         max(price_observed_at) observed_at
  from open_positions group by account_key,account_name,asset_symbol,asset_class
),
combined as (
  select * from all_rows
  union all
  select * from account_rows
)
select
  c.account_view_key,c.account_view_name,c.asset_symbol,c.asset_class,c.quantity,c.cost_basis_thb,
  c.value_thb,c.unrealized_pnl_thb,
  case when c.cost_basis_thb<>0 then c.unrealized_pnl_thb/c.cost_basis_thb else null::numeric end unrealized_return_pct,
  case when sum(c.value_thb) over(partition by c.account_view_key)<>0
    then c.value_thb/sum(c.value_thb) over(partition by c.account_view_key) else null::numeric end view_weight,
  b.batch_id,greatest(b.observed_at,coalesce(c.observed_at,b.observed_at)) observed_at
from combined c cross join latest_batch b;

revoke all on fwios.v_dashboard_holdings from public,anon,authenticated;
grant select on fwios.v_dashboard_holdings to service_role;

create or replace view fwios.v_portfolio_exposure_current
with (security_invoker=true)
as
with p as (
  select asset_symbol,max(asset_class) asset_class,sum(value_thb) value_thb
  from fwios.v_dashboard_holdings
  where account_view_key='ALL'
  group by asset_symbol
),
t as (select sum(value_thb) total_value_thb from p)
select p.asset_symbol,p.asset_class,p.value_thb,
       case when t.total_value_thb>0 then p.value_thb/t.total_value_thb else null::numeric end portfolio_weight,
       t.total_value_thb
from p cross join t;

revoke all on fwios.v_portfolio_exposure_current from public,anon,authenticated;
grant select on fwios.v_portfolio_exposure_current to service_role;

create or replace view fwios.v_dashboard_account_summary
with (security_invoker=true)
as
with latest_batch as (
  select batch_id,observed_at,status batch_status from fwios.v_latest_portfolio_batch
),
realized_by_account as (
  select t.account_key,coalesce(sum(t.source_realized_pnl_thb),0::numeric) realized_pnl_thb
  from fwios.portfolio_transactions t join latest_batch b on b.batch_id=t.batch_id
  group by t.account_key
),
realized_all as (
  select coalesce(sum(realized_pnl_thb),0::numeric) realized_pnl_thb from realized_by_account
),
base as (
  select h.account_view_key,h.account_view_name,sum(h.value_thb) portfolio_value_thb,
         sum(h.cost_basis_thb) open_cost_basis_thb,sum(h.unrealized_pnl_thb) unrealized_pnl_thb,
         count(*)::integer unique_open_assets,
         coalesce(sum(h.value_thb) filter(where upper(h.asset_class)='CRYPTO'),0::numeric) crypto_value_thb,
         max(h.value_thb) largest_position_value_thb,max(h.observed_at) observed_at
  from fwios.v_dashboard_holdings h
  group by h.account_view_key,h.account_view_name
),
largest as (
  select distinct on (h.account_view_key)
    h.account_view_key,h.asset_symbol largest_position_symbol,h.view_weight largest_position_weight
  from fwios.v_dashboard_holdings h
  order by h.account_view_key,h.value_thb desc,h.asset_symbol
),
price_health as (select * from fwios.v_portfolio_market_price_health)
select
  b.account_view_key,b.account_view_name,b.portfolio_value_thb,b.open_cost_basis_thb,b.unrealized_pnl_thb,
  case when b.account_view_key='ALL' then ra.realized_pnl_thb else coalesce(r.realized_pnl_thb,0::numeric) end realized_pnl_thb,
  b.unrealized_pnl_thb+case when b.account_view_key='ALL' then ra.realized_pnl_thb else coalesce(r.realized_pnl_thb,0::numeric) end total_pnl_thb,
  b.unique_open_assets,
  case when b.portfolio_value_thb<>0 then b.crypto_value_thb/b.portfolio_value_thb else null::numeric end crypto_weight,
  l.largest_position_symbol,l.largest_position_weight,1000000::numeric phase1_goal_thb,
  case when b.portfolio_value_thb<>0 then b.portfolio_value_thb/1000000::numeric else 0::numeric end phase1_goal_progress,
  lb.batch_id,greatest(lb.observed_at,coalesce(b.observed_at,lb.observed_at)) observed_at,
  case when lb.batch_status='PASS' and ph.pricing_gate='PASS' then 'PASS'
       when lb.batch_status<>'PASS' then lb.batch_status else ph.pricing_gate end batch_status
from base b
left join realized_by_account r on r.account_key=b.account_view_key
cross join realized_all ra
cross join latest_batch lb
cross join price_health ph
left join largest l on l.account_view_key=b.account_view_key;

revoke all on fwios.v_dashboard_account_summary from public,anon,authenticated;
grant select on fwios.v_dashboard_account_summary to service_role;

create or replace view fwios.v_dashboard_system_health
with (security_invoker=true)
as
with foundation as (select state_value from fwios.system_state where state_key='foundation_version'),
arch as (select state_value from fwios.system_state where state_key='architecture_consolidation_v1'),
sector as (select state_value from fwios.system_state where state_key='sector_loop'),
m3 as (select state_value from fwios.system_state where state_key='m3_human_approval_cutover'),
batch as (select * from fwios.v_latest_portfolio_batch),
price_health as (select * from fwios.v_portfolio_market_price_health),
model_debt as (select count(*)::integer open_model_blockers from fwios.v_open_model_debt)
select
  f.state_value->>'version' foundation_version,
  f.state_value->>'contract' contract_id,
  f.state_value->>'status' foundation_status,
  a.state_value->>'github_merge_sha' github_merge_sha,
  m.state_value->>'m3_overall' m3_status,
  m.state_value->>'policy' approval_policy,
  m.state_value->>'regressions' approval_regressions,
  m.state_value->>'traceability_layers' cutover_traceability,
  s.state_value->>'automation_mode' sector_automation_mode,
  s.state_value->>'next_queued_sector' next_queued_sector,
  s.state_value->>'next_action' next_action,
  b.batch_id portfolio_batch_id,
  case when b.status='PASS' and ph.pricing_gate='PASS' then 'PASS'
       when b.status<>'PASS' then b.status else ph.pricing_gate end portfolio_batch_status,
  b.source_transaction_count,b.transaction_pass_count,b.source_position_count,b.position_pass_count,
  d.open_model_blockers,false auto_trade,true human_execution_only,now() read_model_checked_at
from foundation f cross join arch a cross join sector s cross join m3 m cross join batch b
cross join price_health ph cross join model_debt d;

revoke all on fwios.v_dashboard_system_health from public,anon,authenticated;
grant select on fwios.v_dashboard_system_health to service_role;

select cron.unschedule(jobid) from cron.job where jobname='fwios-portfolio-mtm-refresh';
select cron.schedule(
  'fwios-portfolio-mtm-refresh',
  '*/15 * * * *',
  $cron$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='fwios_project_url' limit 1) || '/functions/v1/portfolio-mtm-refresh-v1',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'x-fwios-automation-token',(select decrypted_secret from vault.decrypted_secrets where name='fwios_automation_token' limit 1)
    ),
    body := jsonb_build_object('source','CRON_15_MIN','force_all',false,'requested_at',now()),
    timeout_milliseconds := 25000
  );
  $cron$
);

update fwios.system_state
set state_value=state_value||jsonb_build_object(
  'portfolio_mark_to_market','LIVE_V1',
  'portfolio_mark_to_market_policy','POL-PORTFOLIO-MTM-V1',
  'portfolio_mark_to_market_cadence_minutes',15,
  'portfolio_mark_to_market_worker_version',1,
  'portfolio_transactions_changed',false,
  'auto_trade',false
),
updated_at=now(),as_of_text=(now() at time zone 'Asia/Bangkok')::date::text
where state_key='architecture_consolidation_v1';
