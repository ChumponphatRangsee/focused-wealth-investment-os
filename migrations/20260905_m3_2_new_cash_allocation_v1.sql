-- FWIOS M3.2 New-Cash Capital Allocation v1
-- Contract target: FWIOS-CONTRACT-0.87.6
-- Private/internal only. Human review only. No portfolio mutation.

alter table fwios.capital_allocation_runs
  add column if not exists ranking_run_id text references fwios.opportunity_ranking_runs(ranking_run_id),
  add column if not exists requested_new_cash_thb numeric,
  add column if not exists allocated_new_cash_thb numeric,
  add column if not exists unallocated_cash_thb numeric,
  add column if not exists input_integrity_gate text,
  add column if not exists allocation_gate text;

alter table fwios.capital_allocation_actions
  add column if not exists ranking_candidate_id text references fwios.opportunity_ranked_candidates(ranking_candidate_id);

do $$
begin
  if not exists (select 1 from pg_constraint where conname='capital_allocation_runs_cash_nonnegative_check') then
    alter table fwios.capital_allocation_runs
      add constraint capital_allocation_runs_cash_nonnegative_check
      check ((requested_new_cash_thb is null or requested_new_cash_thb >= 0)
         and (allocated_new_cash_thb is null or allocated_new_cash_thb >= 0)
         and (unallocated_cash_thb is null or unallocated_cash_thb >= 0));
  end if;

  if not exists (select 1 from pg_constraint where conname='capital_allocation_actions_amount_nonnegative_check') then
    alter table fwios.capital_allocation_actions
      add constraint capital_allocation_actions_amount_nonnegative_check
      check (amount_thb is null or amount_thb >= 0);
  end if;

  if not exists (select 1 from pg_constraint where conname='capital_allocation_actions_add_traceability_check') then
    alter table fwios.capital_allocation_actions
      add constraint capital_allocation_actions_add_traceability_check
      check (action_type <> 'ADD' or (decision_snapshot_id is not null and ranking_candidate_id is not null));
  end if;
end $$;

create or replace function fwios.new_cash_capacity_v1(
  existing_position boolean,
  current_position_value_thb numeric,
  post_money_total_thb numeric,
  candidate_asset_class text
) returns numeric
language sql
immutable parallel safe
set search_path = pg_catalog, fwios
as $$
select case
  when post_money_total_thb is null or post_money_total_thb <= 0 then 0::numeric
  when candidate_asset_class is distinct from 'Stock' then 0::numeric
  when coalesce(existing_position,false) = false then round(post_money_total_thb * 0.05, 2)
  else round(least(
    post_money_total_thb * 0.05,
    greatest(post_money_total_thb * 0.30 - coalesce(current_position_value_thb,0), 0)
  ), 2)
end
$$;

create or replace function fwios.new_cash_input_gate_v1(
  requested_new_cash_thb numeric,
  latest_portfolio_batch_id text,
  latest_portfolio_batch_status text,
  ranking_portfolio_batch_id text,
  ranking_run_status text,
  ranking_policy_status text
) returns text
language sql
immutable parallel safe
set search_path = pg_catalog, fwios
as $$
select case
  when requested_new_cash_thb is null or requested_new_cash_thb <= 0 then 'BLOCKED - INVALID NEW CASH'
  when latest_portfolio_batch_id is null or latest_portfolio_batch_status is distinct from 'PASS' then 'BLOCKED - PORTFOLIO BATCH NOT READY'
  when ranking_portfolio_batch_id is null or ranking_run_status is distinct from 'PASS' then 'BLOCKED - RANKING RUN NOT READY'
  when ranking_policy_status is distinct from 'ACTIVE' then 'BLOCKED - RANKING POLICY NOT ACTIVE'
  when ranking_portfolio_batch_id is distinct from latest_portfolio_batch_id then 'BLOCKED - STALE PORTFOLIO/RANKING'
  else 'PASS'
end
$$;

create or replace function fwios.new_cash_current_input_gate_v1(p_new_cash_thb numeric)
returns text
language sql
stable parallel safe
security invoker
set search_path = pg_catalog, fwios
as $$
with latest_batch as (
  select batch_id,status
  from fwios.v_latest_portfolio_batch
  limit 1
), latest_ranking as (
  select r.ranking_run_id,r.portfolio_batch_id,r.status,pv.lifecycle_status as policy_status
  from fwios.opportunity_ranking_runs r
  join fwios.policy_versions pv on pv.policy_version_id=r.policy_version_id
  where r.status='PASS'
  order by r.completed_at desc nulls last,r.created_at desc,r.ranking_run_id desc
  limit 1
)
select fwios.new_cash_input_gate_v1(
  p_new_cash_thb,
  (select batch_id from latest_batch),
  (select status from latest_batch),
  (select portfolio_batch_id from latest_ranking),
  (select status from latest_ranking),
  (select policy_status from latest_ranking)
)
$$;

create or replace function fwios.preview_new_cash_candidates_v1(p_new_cash_thb numeric)
returns table(
  ranking_run_id text,
  ranking_candidate_id text,
  ticker text,
  bucket_rank integer,
  priority_score numeric,
  decision_snapshot_id text,
  existing_position boolean,
  candidate_asset_class text,
  current_position_value_thb numeric,
  current_position_weight numeric,
  post_money_total_thb numeric,
  allocation_capacity_thb numeric,
  candidate_gate text,
  rationale_code text
)
language sql
stable parallel safe
security invoker
set search_path = pg_catalog, fwios
as $$
with latest_batch as (
  select batch_id,status,source_total_value_thb
  from fwios.v_latest_portfolio_batch
  limit 1
), latest_ranking as (
  select r.ranking_run_id,r.portfolio_batch_id,r.status,r.policy_version_id,pv.lifecycle_status as policy_status
  from fwios.opportunity_ranking_runs r
  join fwios.policy_versions pv on pv.policy_version_id=r.policy_version_id
  where r.status='PASS'
  order by r.completed_at desc nulls last,r.created_at desc,r.ranking_run_id desc
  limit 1
), base as (
  select
    lr.ranking_run_id,
    rc.ranking_candidate_id,
    rc.ticker,
    rc.bucket_rank,
    rc.priority_score,
    rc.decision_snapshot_id,
    pf.existing_position,
    case when c.ticker is not null then 'Stock'::text else null::text end as candidate_asset_class,
    coalesce(e.value_thb,0)::numeric as current_position_value_thb,
    coalesce(e.portfolio_weight,0)::numeric as current_position_weight,
    (lb.source_total_value_thb + greatest(coalesce(p_new_cash_thb,0),0))::numeric as post_money_total_thb,
    pf.portfolio_fit_gate,
    pf.portfolio_batch_id as fit_portfolio_batch_id,
    lb.batch_id as latest_portfolio_batch_id,
    lb.status as latest_portfolio_batch_status,
    lr.portfolio_batch_id as ranking_portfolio_batch_id,
    lr.status as ranking_run_status,
    lr.policy_status,
    rc.opportunity_bucket,
    rc.eligibility_gate,
    d.input_integrity_gate
  from latest_batch lb
  cross join latest_ranking lr
  join fwios.opportunity_ranked_candidates rc on rc.ranking_run_id=lr.ranking_run_id
  join fwios.decision_snapshots d on d.decision_snapshot_id=rc.decision_snapshot_id
  join fwios.candidate_portfolio_fit_snapshots pf on pf.fit_snapshot_id=d.portfolio_fit_snapshot_id
  left join fwios.companies c on c.ticker=rc.ticker and c.active=true
  left join fwios.v_portfolio_exposure_current e on e.asset_symbol=rc.ticker
  where rc.opportunity_bucket='IMMEDIATE_BUY_CANDIDATE'
), scored as (
  select b.*,
    fwios.new_cash_capacity_v1(b.existing_position,b.current_position_value_thb,b.post_money_total_thb,b.candidate_asset_class) as capacity,
    fwios.new_cash_input_gate_v1(
      p_new_cash_thb,b.latest_portfolio_batch_id,b.latest_portfolio_batch_status,b.ranking_portfolio_batch_id,b.ranking_run_status,b.policy_status
    ) as global_gate
  from base b
)
select
  s.ranking_run_id,
  s.ranking_candidate_id,
  s.ticker,
  s.bucket_rank,
  s.priority_score,
  s.decision_snapshot_id,
  s.existing_position,
  s.candidate_asset_class,
  s.current_position_value_thb,
  s.current_position_weight,
  s.post_money_total_thb,
  s.capacity as allocation_capacity_thb,
  case
    when s.global_gate <> 'PASS' then s.global_gate
    when s.input_integrity_gate <> 'PASS' then 'BLOCKED - DECISION INPUT INTEGRITY'
    when s.eligibility_gate <> 'PASS' then 'BLOCKED - RANKING ELIGIBILITY'
    when s.portfolio_fit_gate <> 'PASS' then 'BLOCKED - PORTFOLIO FIT'
    when s.fit_portfolio_batch_id is distinct from s.latest_portfolio_batch_id then 'BLOCKED - STALE PORTFOLIO FIT'
    when s.candidate_asset_class is distinct from 'Stock' then 'BLOCKED - UNSUPPORTED ASSET CLASS'
    when s.existing_position and s.current_position_weight > 0.30 then 'BLOCKED - EXISTING POSITION ABOVE 30%'
    when s.capacity <= 0 then 'BLOCKED - NO ALLOCATION CAPACITY'
    else 'PASS'
  end as candidate_gate,
  case when s.existing_position then 'EXISTING_POSITION_STAGED_ADD' else 'NEW_POSITION_STARTER_MAX_5PCT' end as rationale_code
from scored s
order by s.bucket_rank,s.ticker
$$;

create or replace function fwios.preview_new_cash_allocation_v1(p_new_cash_thb numeric)
returns table(
  sequence_no integer,
  asset_symbol text,
  action_type text,
  amount_thb numeric,
  target_weight numeric,
  ranking_run_id text,
  ranking_candidate_id text,
  decision_snapshot_id text,
  allocation_gate text,
  rationale_code text
)
language sql
stable parallel safe
security invoker
set search_path = pg_catalog, fwios
as $$
with ctx as (
  select
    coalesce((select source_total_value_thb from fwios.v_latest_portfolio_batch limit 1),0)::numeric as current_total,
    greatest(coalesce(p_new_cash_thb,0),0)::numeric as requested_cash,
    fwios.new_cash_current_input_gate_v1(p_new_cash_thb) as global_gate,
    (select r.ranking_run_id from fwios.opportunity_ranking_runs r where r.status='PASS' order by r.completed_at desc nulls last,r.created_at desc,r.ranking_run_id desc limit 1) as latest_ranking_run_id
), selected as (
  select c.*
  from fwios.preview_new_cash_candidates_v1(p_new_cash_thb) c
  where c.candidate_gate='PASS' and c.allocation_capacity_thb > 0
  order by c.bucket_rank,c.ticker
  limit 1
), calc as (
  select
    ctx.*,
    s.ranking_run_id as selected_ranking_run_id,
    s.ranking_candidate_id,
    s.ticker,
    s.decision_snapshot_id,
    s.current_position_value_thb,
    s.allocation_capacity_thb,
    least(ctx.requested_cash,coalesce(s.allocation_capacity_thb,0))::numeric as allocated_cash,
    (ctx.current_total + ctx.requested_cash)::numeric as post_money_total
  from ctx
  left join selected s on true
)
select 1,
       c.ticker,
       'ADD'::text,
       round(c.allocated_cash,2),
       case when c.post_money_total>0 then round((coalesce(c.current_position_value_thb,0)+c.allocated_cash)/c.post_money_total,8) else 0 end,
       c.selected_ranking_run_id,
       c.ranking_candidate_id,
       c.decision_snapshot_id,
       'READY - HUMAN REVIEW'::text,
       case when coalesce(c.current_position_value_thb,0)>0 then 'TOP_RANK_EXISTING_STAGED_ADD' else 'TOP_RANK_NEW_POSITION_STARTER' end
from calc c
where c.global_gate='PASS' and c.ticker is not null and c.allocated_cash>0
union all
select case when c.global_gate='PASS' and c.ticker is not null and c.allocated_cash>0 then 2 else 1 end,
       'CASH_THB'::text,
       'HOLD'::text,
       round(case when c.global_gate='PASS' then c.requested_cash-c.allocated_cash else c.requested_cash end,2),
       case when c.post_money_total>0 then round((case when c.global_gate='PASS' then c.requested_cash-c.allocated_cash else c.requested_cash end)/c.post_money_total,8) else 0 end,
       coalesce(c.selected_ranking_run_id,c.latest_ranking_run_id),
       null::text,
       null::text,
       case
         when c.global_gate<>'PASS' then c.global_gate
         when c.ticker is null then 'PASS - HOLD CASH / NO ALLOCATABLE IMMEDIATE CANDIDATE'
         else 'PASS - HOLD RESIDUAL CASH'
       end,
       case
         when c.global_gate<>'PASS' then 'INPUT_FAIL_CLOSED'
         when c.ticker is null then 'NO_ALLOCATABLE_IMMEDIATE_CANDIDATE'
         else 'RESIDUAL_CASH_AFTER_CAP'
       end
from calc c
where (case when c.global_gate='PASS' then c.requested_cash-c.allocated_cash else c.requested_cash end) > 0
   or c.global_gate<>'PASS'
order by 1
$$;

create or replace function fwios.preview_new_cash_metrics_v1(p_new_cash_thb numeric)
returns table(metric_name text,before_value numeric,after_value numeric,unit text,gate text,note text)
language sql
stable parallel safe
security invoker
set search_path = pg_catalog, fwios
as $$
with g as (
  select * from fwios.v_portfolio_guardrails_current limit 1
), alloc as (
  select * from fwios.preview_new_cash_allocation_v1(p_new_cash_thb)
), add_by_ticker as (
  select asset_symbol,sum(amount_thb)::numeric as add_amount
  from alloc where action_type='ADD' group by asset_symbol
), totals as (
  select
    g.total_value_thb::numeric as current_total,
    greatest(coalesce(p_new_cash_thb,0),0)::numeric as requested_cash,
    (g.total_value_thb + greatest(coalesce(p_new_cash_thb,0),0))::numeric as post_money_total,
    coalesce((select sum(amount_thb) from alloc where action_type='ADD'),0)::numeric as allocated_cash,
    coalesce((select sum(amount_thb) from alloc where action_type='HOLD' and asset_symbol='CASH_THB'),0)::numeric as held_cash,
    g.unique_open_assets,
    g.max_single_stock_weight::numeric as before_max_stock,
    g.crypto_weight::numeric as before_crypto
  from g
), stock_after as (
  select e.asset_symbol,(e.value_thb + coalesce(a.add_amount,0))::numeric as value_after
  from fwios.v_portfolio_exposure_current e
  left join add_by_ticker a on a.asset_symbol=e.asset_symbol
  where e.asset_class='Stock'
  union all
  select a.asset_symbol,a.add_amount
  from add_by_ticker a
  left join fwios.v_portfolio_exposure_current e on e.asset_symbol=a.asset_symbol
  where e.asset_symbol is null
), derived as (
  select t.*,
    coalesce((select max(value_after/t.post_money_total) from stock_after where t.post_money_total>0),0)::numeric as after_max_stock,
    case when t.post_money_total>0 then coalesce((select sum(value_thb) from fwios.v_portfolio_exposure_current where asset_class='Crypto'),0)/t.post_money_total else 0 end::numeric as after_crypto,
    (t.unique_open_assets + coalesce((select count(*) from add_by_ticker a left join fwios.v_portfolio_exposure_current e on e.asset_symbol=a.asset_symbol where e.asset_symbol is null and a.add_amount>0),0))::numeric as after_assets,
    case when t.requested_cash>0 then t.allocated_cash/t.requested_cash else 0 end::numeric as deploy_ratio,
    case when t.post_money_total>0 then t.held_cash/t.post_money_total else 0 end::numeric as residual_cash_weight
  from totals t
)
select 'portfolio_total_thb',d.current_total,d.post_money_total,'THB','PASS','Post-money total includes all requested new cash, whether invested or held.' from derived d
union all select 'allocated_new_cash_thb',0,d.allocated_cash,'THB',case when d.allocated_cash>0 then 'PASS' else 'HOLD' end,'Only the highest-ranked allocatable Immediate candidate may receive capital in v1.' from derived d
union all select 'unallocated_cash_thb',0,d.held_cash,'THB',case when d.held_cash>0 then 'HOLD' else 'PASS' end,'Residual new cash remains CASH_THB; the engine never force-fills a second candidate.' from derived d
union all select 'max_single_stock_weight',d.before_max_stock,d.after_max_stock,'ratio',case when d.after_max_stock<=0.30 then 'PASS' else 'REVIEW - ABOVE 30%' end,'Above 30% remains a concentration review flag, not an automatic sell instruction.' from derived d
union all select 'crypto_weight',d.before_crypto,d.after_crypto,'ratio',case when d.after_crypto between 0.15 and 0.20 then 'PASS' when d.after_crypto>0.20 then 'REVIEW - ABOVE PHASE1 TARGET' else 'REVIEW - BELOW PHASE1 TARGET' end,'Stock new-cash allocation cannot add crypto exposure in v1.' from derived d
union all select 'unique_open_assets',d.unique_open_assets::numeric,d.after_assets,'count',case when d.after_assets between 5 and 8 then 'PASS' else 'REVIEW - OUTSIDE 5-8 PREFERENCE' end,'A new position may increase count by at most one per allocation run.' from derived d
union all select 'new_cash_deployment_ratio',0,d.deploy_ratio,'ratio',case when d.deploy_ratio>0 then 'PASS' else 'HOLD' end,'Unallocated cash is valid when candidate capacity is exhausted or no candidate qualifies.' from derived d
union all select 'residual_new_cash_weight',0,d.residual_cash_weight,'ratio',case when d.residual_cash_weight<=0.10 then 'PASS' else 'REVIEW - OPPORTUNITY CASH ABOVE GUIDELINE' end,'This measures residual cash from this request only; current legacy portfolio cash is not inferred.' from derived d
$$;

create or replace view fwios.v_new_cash_allocation_current_context
with (security_invoker=true)
as
select
  b.batch_id as portfolio_batch_id,
  b.source_total_value_thb as portfolio_value_thb,
  g.unique_open_assets,
  g.max_single_stock_weight,
  g.crypto_weight,
  r.ranking_run_id,
  r.policy_version_id as ranking_policy_version_id,
  r.status as ranking_run_status,
  pv.lifecycle_status as ranking_policy_status,
  (select count(*) from fwios.opportunity_ranked_candidates c where c.ranking_run_id=r.ranking_run_id and c.opportunity_bucket='IMMEDIATE_BUY_CANDIDATE') as immediate_candidate_count
from fwios.v_latest_portfolio_batch b
cross join lateral (select * from fwios.v_portfolio_guardrails_current limit 1) g
left join lateral (
  select rr.* from fwios.opportunity_ranking_runs rr where rr.status='PASS' order by rr.completed_at desc nulls last,rr.created_at desc,rr.ranking_run_id desc limit 1
) r on true
left join fwios.policy_versions pv on pv.policy_version_id=r.policy_version_id;

revoke all on function fwios.new_cash_capacity_v1(boolean,numeric,numeric,text) from public, anon, authenticated;
revoke all on function fwios.new_cash_input_gate_v1(numeric,text,text,text,text,text) from public, anon, authenticated;
revoke all on function fwios.new_cash_current_input_gate_v1(numeric) from public, anon, authenticated;
revoke all on function fwios.preview_new_cash_candidates_v1(numeric) from public, anon, authenticated;
revoke all on function fwios.preview_new_cash_allocation_v1(numeric) from public, anon, authenticated;
revoke all on function fwios.preview_new_cash_metrics_v1(numeric) from public, anon, authenticated;
revoke all on fwios.v_new_cash_allocation_current_context from anon, authenticated;
