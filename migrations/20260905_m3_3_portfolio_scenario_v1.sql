-- M3.3 Portfolio Scenario Simulation v1
-- Requires M3.2 New-Cash Allocation v1.

create table if not exists fwios.portfolio_scenario_runs (
  scenario_run_id text primary key,
  policy_version_id text not null references fwios.policy_versions(policy_version_id),
  portfolio_batch_id text not null references fwios.portfolio_import_batches(batch_id),
  ranking_run_id text not null references fwios.opportunity_ranking_runs(ranking_run_id),
  allocation_policy_version_id text not null references fwios.policy_versions(policy_version_id),
  run_mode text not null check (run_mode in ('NO_SELL','SOFT_REBALANCE','ACTIVE_REBALANCE')),
  requested_new_cash_thb numeric not null default 0 check (requested_new_cash_thb >= 0),
  input_gate text not null,
  valuation_coverage_gate text not null,
  status text not null check (status in ('DRAFT','BLOCKED','READY','COMPLETE','REJECTED')),
  source_reference text not null,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists fwios.portfolio_scenario_actions (
  scenario_action_id text primary key,
  scenario_run_id text not null references fwios.portfolio_scenario_runs(scenario_run_id) on delete cascade,
  sequence_no integer not null,
  asset_symbol text not null,
  action_type text not null check (action_type in ('ADD','TRIM','HOLD','START_DCA','STOP_DCA')),
  amount_thb numeric not null default 0 check (amount_thb >= 0),
  ranking_candidate_id text references fwios.opportunity_ranked_candidates(ranking_candidate_id),
  decision_snapshot_id text references fwios.decision_snapshots(decision_snapshot_id),
  rationale_code text not null,
  source_reference text not null,
  created_at timestamptz not null default now(),
  unique (scenario_run_id, sequence_no)
);

create table if not exists fwios.portfolio_scenario_positions (
  scenario_position_id text primary key,
  scenario_run_id text not null references fwios.portfolio_scenario_runs(scenario_run_id) on delete cascade,
  asset_symbol text not null,
  asset_class text not null,
  before_value_thb numeric not null,
  action_delta_thb numeric not null,
  after_value_thb numeric not null check (after_value_thb >= 0),
  before_weight numeric not null,
  after_weight numeric not null,
  decision_snapshot_id text references fwios.decision_snapshots(decision_snapshot_id),
  mispricing_snapshot_id text references fwios.valuation_mispricing_snapshots(mispricing_snapshot_id),
  base_upside numeric,
  probability_weighted_upside numeric,
  valuation_coverage_gate text not null,
  source_reference text not null,
  created_at timestamptz not null default now(),
  unique (scenario_run_id, asset_symbol)
);

create table if not exists fwios.portfolio_scenario_metrics (
  scenario_metric_id text primary key,
  scenario_run_id text not null references fwios.portfolio_scenario_runs(scenario_run_id) on delete cascade,
  metric_name text not null,
  before_value numeric,
  after_value numeric,
  unit text not null,
  gate text not null,
  note text,
  created_at timestamptz not null default now(),
  unique (scenario_run_id, metric_name)
);

alter table fwios.portfolio_scenario_runs enable row level security;
alter table fwios.portfolio_scenario_actions enable row level security;
alter table fwios.portfolio_scenario_positions enable row level security;
alter table fwios.portfolio_scenario_metrics enable row level security;
revoke all on fwios.portfolio_scenario_runs, fwios.portfolio_scenario_actions, fwios.portfolio_scenario_positions, fwios.portfolio_scenario_metrics from anon, authenticated;

insert into fwios.policy_registry(policy_key, policy_domain, policy_name, purpose, backing_object, lifecycle_status)
values ('PORTFOLIO_SCENARIO','CAPITAL_ALLOCATION','Portfolio Scenario Simulation','Deterministically simulate before/after portfolio state without mutating live holdings.','fwios.portfolio_scenario_runs','DRAFT')
on conflict (policy_key) do update set policy_domain=excluded.policy_domain, policy_name=excluded.policy_name, purpose=excluded.purpose, backing_object=excluded.backing_object, lifecycle_status='DRAFT', updated_at=now();

insert into fwios.policy_versions(policy_version_id, policy_key, version, lifecycle_status, deterministic_scoring, config, source_reference)
values (
 'POL-PORTFOLIO-SCENARIO-V1-DRAFT','PORTFOLIO_SCENARIO','1.0-draft','DRAFT',true,
 jsonb_build_object(
  'modes',jsonb_build_array('NO_SELL','SOFT_REBALANCE','ACTIVE_REBALANCE'),
  'source_allocation_policy','POL-NEW-CASH-ALLOCATION-V1',
  'source_ranking_policy','POL-OPPORTUNITY-RANKING-V1',
  'no_sell_uses_new_cash_engine',true,
  'soft_rebalance_allows_trim',false,
  'active_rebalance_trim_is_input_not_recommendation',true,
  'trim_requires_explicit_rationale',true,
  'price_appreciation_only_rationale_forbidden',true,
  'live_portfolio_mutation',false,
  'full_expected_portfolio_upside_requires_complete_valuation_coverage',true,
  'partial_covered_upside_metrics_allowed',true,
  'human_execution_only',true,
  'auto_trade',false
 ),
 'GitHub policies/scenario/PORTFOLIO_SCENARIO_V1.md'
)
on conflict (policy_version_id) do update set config=excluded.config, lifecycle_status='DRAFT', source_reference=excluded.source_reference;

create or replace function fwios.portfolio_scenario_structural_gate_v1(
  p_run_mode text,
  p_new_cash_thb numeric,
  p_trim_symbols text[] default '{}'::text[],
  p_trim_amounts numeric[] default '{}'::numeric[],
  p_trim_rationale_codes text[] default '{}'::text[]
) returns text
language plpgsql
immutable
security invoker
set search_path = pg_catalog, fwios
as $$
declare
  n_sym int := coalesce(array_length(p_trim_symbols,1),0);
  n_amt int := coalesce(array_length(p_trim_amounts,1),0);
  n_rat int := coalesce(array_length(p_trim_rationale_codes,1),0);
begin
  if p_run_mode not in ('NO_SELL','SOFT_REBALANCE','ACTIVE_REBALANCE') then return 'BLOCKED - INVALID SCENARIO MODE'; end if;
  if p_new_cash_thb is null or p_new_cash_thb < 0 then return 'BLOCKED - INVALID NEW CASH'; end if;
  if n_sym <> n_amt or n_sym <> n_rat then return 'BLOCKED - TRIM INPUT LENGTH MISMATCH'; end if;
  if n_sym > 0 and p_run_mode in ('NO_SELL','SOFT_REBALANCE') then return 'BLOCKED - TRIM NOT ALLOWED IN MODE'; end if;
  if exists (select 1 from unnest(p_trim_symbols) s where s is null or btrim(s)='') then return 'BLOCKED - INVALID TRIM SYMBOL'; end if;
  if exists (select 1 from unnest(p_trim_amounts) a where a is null or a <= 0) then return 'BLOCKED - INVALID TRIM AMOUNT'; end if;
  if exists (select 1 from unnest(p_trim_rationale_codes) r where r is null or btrim(r)='') then return 'BLOCKED - TRIM RATIONALE REQUIRED'; end if;
  if exists (select 1 from unnest(p_trim_rationale_codes) r where upper(r) in ('PRICE_APPRECIATION_ONLY','APPRECIATION_ONLY')) then return 'BLOCKED - APPRECIATION-ONLY TRIM FORBIDDEN'; end if;
  if (select count(*) from unnest(p_trim_symbols) s) <> (select count(distinct upper(s)) from unnest(p_trim_symbols) s) then return 'BLOCKED - DUPLICATE TRIM SYMBOL'; end if;
  if p_run_mode in ('NO_SELL','SOFT_REBALANCE') and p_new_cash_thb <= 0 then return 'BLOCKED - NEW CASH REQUIRED'; end if;
  if p_run_mode='ACTIVE_REBALANCE' and p_new_cash_thb=0 and n_sym=0 then return 'BLOCKED - NO SCENARIO ACTION'; end if;
  return 'PASS';
end $$;

create or replace function fwios.portfolio_scenario_current_input_gate_v1(
  p_run_mode text,
  p_new_cash_thb numeric,
  p_trim_symbols text[] default '{}'::text[],
  p_trim_amounts numeric[] default '{}'::numeric[],
  p_trim_rationale_codes text[] default '{}'::text[]
) returns text
language plpgsql
stable
security invoker
set search_path = pg_catalog, fwios
as $$
declare
  g text;
  ctx record;
begin
  g := fwios.portfolio_scenario_structural_gate_v1(p_run_mode,p_new_cash_thb,p_trim_symbols,p_trim_amounts,p_trim_rationale_codes);
  if g <> 'PASS' then return g; end if;

  select * into ctx from fwios.v_new_cash_allocation_current_context limit 1;
  if ctx.portfolio_batch_id is null then return 'BLOCKED - NO CURRENT PORTFOLIO'; end if;
  if ctx.ranking_run_id is null or ctx.ranking_run_status <> 'PASS' then return 'BLOCKED - NO PASS RANKING'; end if;
  if ctx.ranking_policy_status <> 'ACTIVE' then return 'BLOCKED - RANKING POLICY NOT ACTIVE'; end if;
  if not exists (select 1 from fwios.policy_versions where policy_version_id='POL-NEW-CASH-ALLOCATION-V1' and lifecycle_status='ACTIVE') then return 'BLOCKED - ALLOCATION POLICY NOT ACTIVE'; end if;
  if exists (
    select 1
    from unnest(p_trim_symbols,p_trim_amounts) as i(symbol,amount)
    left join fwios.v_portfolio_exposure_current p on upper(p.asset_symbol)=upper(i.symbol)
    where p.asset_symbol is null or i.amount > p.value_thb
  ) then return 'BLOCKED - TRIM EXCEEDS CURRENT POSITION'; end if;
  return 'PASS';
end $$;

create or replace function fwios.preview_portfolio_scenario_actions_v1(
  p_run_mode text,
  p_new_cash_thb numeric,
  p_trim_symbols text[] default '{}'::text[],
  p_trim_amounts numeric[] default '{}'::numeric[],
  p_trim_rationale_codes text[] default '{}'::text[]
) returns table(
  sequence_no integer,
  asset_symbol text,
  action_type text,
  amount_thb numeric,
  ranking_run_id text,
  ranking_candidate_id text,
  decision_snapshot_id text,
  rationale_code text,
  scenario_gate text
)
language plpgsql
stable
security invoker
set search_path = pg_catalog, fwios
as $$
declare
  g text;
  trim_count int := coalesce(array_length(p_trim_symbols,1),0);
  trim_total numeric := coalesce((select sum(x) from unnest(p_trim_amounts) x),0);
  available_cash numeric;
  old_total numeric;
  post_money_total numeric;
  cand record;
  cap numeric := 0;
  add_amt numeric := 0;
  residual numeric := 0;
  seq int;
begin
  g := fwios.portfolio_scenario_current_input_gate_v1(p_run_mode,p_new_cash_thb,p_trim_symbols,p_trim_amounts,p_trim_rationale_codes);
  if g <> 'PASS' then
    return query select 1,'SCENARIO'::text,'HOLD'::text,0::numeric,null::text,null::text,null::text,'INPUT_BLOCKED'::text,g;
    return;
  end if;

  select total_value_thb into old_total from fwios.v_portfolio_guardrails_current limit 1;
  post_money_total := old_total + p_new_cash_thb;
  available_cash := p_new_cash_thb + trim_total;

  if trim_count > 0 then
    return query
    select ordinality::int, upper(symbol), 'TRIM'::text, amount, null::text, null::text, null::text, rationale, 'PASS'::text
    from unnest(p_trim_symbols,p_trim_amounts,p_trim_rationale_codes) with ordinality as x(symbol,amount,rationale,ordinality);
  end if;

  select r.ranking_run_id,r.ranking_candidate_id,r.ticker,r.decision_snapshot_id,
         coalesce(e.value_thb,0) as current_value,
         (e.asset_symbol is not null) as existing_position,
         case when c.ticker is not null then 'Stock'::text else null::text end as asset_class
  into cand
  from fwios.v_opportunity_ranking_current r
  left join fwios.v_portfolio_exposure_current e on e.asset_symbol=r.ticker
  left join fwios.companies c on c.ticker=r.ticker and c.active=true
  where r.opportunity_bucket='IMMEDIATE_BUY_CANDIDATE' and r.eligibility_gate='PASS'
  order by r.bucket_rank,r.priority_score desc,r.ticker
  limit 1;

  if cand.ticker is not null then
    cap := fwios.new_cash_capacity_v1(cand.existing_position,cand.current_value,post_money_total,cand.asset_class);
    add_amt := least(available_cash,coalesce(cap,0));
  end if;
  residual := greatest(available_cash-add_amt,0);
  seq := trim_count + 1;

  if add_amt > 0 then
    return query select seq,cand.ticker,'ADD'::text,round(add_amt,2),cand.ranking_run_id,cand.ranking_candidate_id,cand.decision_snapshot_id,'TOP_RANK_SCENARIO_ADD'::text,'READY - HUMAN REVIEW'::text;
    seq := seq + 1;
  end if;
  if residual > 0 then
    return query select seq,'CASH_THB'::text,'HOLD'::text,round(residual,2),cand.ranking_run_id,null::text,null::text,
      case when trim_total>0 then 'RESIDUAL_CASH_AFTER_REBALANCE' else 'RESIDUAL_CASH_AFTER_CAP' end,'PASS - HOLD RESIDUAL CASH'::text;
  end if;
end $$;

create or replace function fwios.preview_portfolio_scenario_positions_v1(
  p_run_mode text,
  p_new_cash_thb numeric,
  p_trim_symbols text[] default '{}'::text[],
  p_trim_amounts numeric[] default '{}'::numeric[],
  p_trim_rationale_codes text[] default '{}'::text[]
) returns table(
  asset_symbol text,
  asset_class text,
  before_value_thb numeric,
  action_delta_thb numeric,
  after_value_thb numeric,
  before_weight numeric,
  after_weight numeric,
  decision_snapshot_id text,
  mispricing_snapshot_id text,
  base_upside numeric,
  probability_weighted_upside numeric,
  valuation_coverage_gate text
)
language sql
stable
security invoker
set search_path = pg_catalog, fwios
as $$
with gate as (
  select fwios.portfolio_scenario_current_input_gate_v1(p_run_mode,p_new_cash_thb,p_trim_symbols,p_trim_amounts,p_trim_rationale_codes) g
),
a as (
  select * from fwios.preview_portfolio_scenario_actions_v1(p_run_mode,p_new_cash_thb,p_trim_symbols,p_trim_amounts,p_trim_rationale_codes)
  where (select g from gate)='PASS'
),
tot as (
  select total_value_thb old_total, total_value_thb + p_new_cash_thb after_total from fwios.v_portfolio_guardrails_current limit 1
),
current_ds as (
  select distinct on (d.ticker) d.ticker,d.decision_snapshot_id,d.mispricing_snapshot_id
  from fwios.decision_snapshots d
  join fwios.v_new_cash_allocation_current_context c on c.portfolio_batch_id=d.portfolio_batch_id
  where d.input_integrity_gate='PASS'
  order by d.ticker,d.created_at desc
),
base_rows as (
  select p.asset_symbol,p.asset_class,p.value_thb before_value_thb,p.portfolio_weight before_weight,
         coalesce(sum(case when a.action_type='ADD' then a.amount_thb when a.action_type='TRIM' then -a.amount_thb else 0 end),0) action_delta_thb,
         max(a.decision_snapshot_id) filter (where a.action_type='ADD') action_decision_snapshot_id
  from fwios.v_portfolio_exposure_current p
  left join a on a.asset_symbol=p.asset_symbol
  group by p.asset_symbol,p.asset_class,p.value_thb,p.portfolio_weight
),
new_add as (
  select a.asset_symbol,case when c.ticker is not null then 'Stock'::text else 'Unknown'::text end asset_class,
         0::numeric before_value_thb,0::numeric before_weight,
         sum(a.amount_thb) action_delta_thb,max(a.decision_snapshot_id) action_decision_snapshot_id
  from a
  left join fwios.v_portfolio_exposure_current p on p.asset_symbol=a.asset_symbol
  left join fwios.companies c on c.ticker=a.asset_symbol and c.active=true
  where a.action_type='ADD' and p.asset_symbol is null
  group by a.asset_symbol,c.ticker
),
cash_row as (
  select 'CASH_THB'::text asset_symbol,'Cash'::text asset_class,0::numeric before_value_thb,0::numeric before_weight,
         coalesce(sum(a.amount_thb) filter (where a.asset_symbol='CASH_THB' and a.action_type='HOLD'),0) action_delta_thb,null::text action_decision_snapshot_id
  from a
),
rows as (
  select * from base_rows union all select * from new_add union all select * from cash_row where action_delta_thb>0
),
resolved as (
  select r.*,
         coalesce(r.action_decision_snapshot_id,cd.decision_snapshot_id) ds_id,
         d.mispricing_snapshot_id,
         m.base_upside,m.probability_weighted_upside
  from rows r
  left join current_ds cd on cd.ticker=r.asset_symbol
  left join fwios.decision_snapshots d on d.decision_snapshot_id=coalesce(r.action_decision_snapshot_id,cd.decision_snapshot_id)
  left join fwios.valuation_mispricing_snapshots m on m.mispricing_snapshot_id=d.mispricing_snapshot_id
)
select r.asset_symbol,r.asset_class,r.before_value_thb,r.action_delta_thb,r.before_value_thb+r.action_delta_thb,
       r.before_weight,
       case when (select after_total from tot)>0 then (r.before_value_thb+r.action_delta_thb)/(select after_total from tot) else 0 end,
       r.ds_id,r.mispricing_snapshot_id,r.base_upside,r.probability_weighted_upside,
       case when r.asset_class='Cash' then 'PASS - CASH ASSUMED 0 UPSIDE'
            when r.probability_weighted_upside is not null then 'PASS - TRACEABLE VALUATION'
            else 'BLOCKED - NO CURRENT DECISION VALUATION' end
from resolved r
where r.before_value_thb+r.action_delta_thb >= 0
order by case when r.asset_symbol='CASH_THB' then 2 else 1 end, (r.before_value_thb+r.action_delta_thb) desc, r.asset_symbol;
$$;

create or replace function fwios.preview_portfolio_scenario_metrics_v1(
  p_run_mode text,
  p_new_cash_thb numeric,
  p_trim_symbols text[] default '{}'::text[],
  p_trim_amounts numeric[] default '{}'::numeric[],
  p_trim_rationale_codes text[] default '{}'::text[]
) returns table(metric_name text,before_value numeric,after_value numeric,unit text,gate text,note text)
language sql
stable
security invoker
set search_path = pg_catalog, fwios
as $$
with g as (
 select fwios.portfolio_scenario_current_input_gate_v1(p_run_mode,p_new_cash_thb,p_trim_symbols,p_trim_amounts,p_trim_rationale_codes) gate
),
p as (
 select * from fwios.preview_portfolio_scenario_positions_v1(p_run_mode,p_new_cash_thb,p_trim_symbols,p_trim_amounts,p_trim_rationale_codes) where (select gate from g)='PASS'
),
a as (
 select * from fwios.preview_portfolio_scenario_actions_v1(p_run_mode,p_new_cash_thb,p_trim_symbols,p_trim_amounts,p_trim_rationale_codes) where (select gate from g)='PASS'
),
agg as (
 select
  sum(before_value_thb) filter (where asset_class<>'Cash') old_total,
  sum(after_value_thb) after_total,
  max(before_weight) filter (where asset_class='Stock') max_stock_before,
  max(after_weight) filter (where asset_class='Stock') max_stock_after,
  sum(before_weight) filter (where asset_class='Crypto') crypto_before,
  sum(after_weight) filter (where asset_class='Crypto') crypto_after,
  count(*) filter (where asset_class<>'Cash' and before_value_thb>0) assets_before,
  count(*) filter (where asset_class<>'Cash' and after_value_thb>0) assets_after,
  coalesce(sum(before_value_thb) filter (where asset_class<>'Cash' and probability_weighted_upside is not null),0) covered_before_value,
  coalesce(sum(after_value_thb) filter (where asset_class<>'Cash' and probability_weighted_upside is not null),0) covered_after_value,
  coalesce(sum(before_value_thb) filter (where asset_class<>'Cash'),0) risk_before_value,
  coalesce(sum(after_value_thb) filter (where asset_class<>'Cash'),0) risk_after_value,
  sum(before_weight*probability_weighted_upside) filter (where asset_class<>'Cash' and probability_weighted_upside is not null) covered_pw_before,
  sum(after_weight*probability_weighted_upside) filter (where asset_class<>'Cash' and probability_weighted_upside is not null) covered_pw_after,
  bool_and(probability_weighted_upside is not null) filter (where asset_class<>'Cash') full_valuation_covered,
  bool_and(probability_weighted_upside is not null) filter (where asset_class<>'Cash' and action_delta_thb<>0) changed_assets_covered,
  sum(action_delta_thb*probability_weighted_upside) filter (where asset_class<>'Cash' and action_delta_thb<>0 and probability_weighted_upside is not null) modeled_change,
  sum(greatest(action_delta_thb,0)*probability_weighted_upside) filter (where asset_class<>'Cash' and action_delta_thb>0 and probability_weighted_upside is not null) add_expected_value,
  max(probability_weighted_upside) filter (where action_delta_thb>0 and asset_class<>'Cash') add_pw_upside,
  max(base_upside) filter (where action_delta_thb>0 and asset_class<>'Cash') add_base_upside,
  max(after_weight) filter (where action_delta_thb>0 and asset_class<>'Cash') add_weight
 from p
),
add_score as (
 select max(s.downside_risk_score) downside_score
 from a
 join fwios.decision_snapshots d on d.decision_snapshot_id=a.decision_snapshot_id
 join fwios.candidate_decision_scores s on s.score_snapshot_id=d.score_snapshot_id
 where a.action_type='ADD'
),
trim_stats as (
 select coalesce(sum(amount_thb) filter (where action_type='TRIM'),0) trim_total,
        coalesce(sum(amount_thb) filter (where action_type='ADD'),0) add_total,
        coalesce(sum(amount_thb) filter (where asset_symbol='CASH_THB' and action_type='HOLD'),0) cash_total
 from a
)
select 'portfolio_total_thb',old_total,after_total,'THB','PASS','Scenario arithmetic only; no live mutation.' from agg
union all select 'max_single_stock_weight',max_stock_before,max_stock_after,'ratio',case when max_stock_after>0.30 then 'REVIEW - ABOVE 30%' else 'PASS' end,'Concentration review is not an automatic trim instruction.' from agg
union all select 'crypto_weight',crypto_before,crypto_after,'ratio',case when crypto_after>0.20 or crypto_after<0.15 then 'REVIEW - OUTSIDE PHASE1 TARGET' else 'PASS' end,'Phase-1 crypto target 15-20%.' from agg
union all select 'unique_open_assets',assets_before::numeric,assets_after::numeric,'count',case when assets_after between 5 and 8 then 'PASS' else 'REVIEW - OUTSIDE 5-8 PREFERENCE' end,'Cash is excluded from position count.' from agg
union all select 'valuation_coverage_weight',case when risk_before_value>0 then covered_before_value/risk_before_value else 1 end,case when risk_after_value>0 then covered_after_value/risk_after_value else 1 end,'ratio',case when coalesce(full_valuation_covered,false) then 'PASS' else 'BLOCKED - INCOMPLETE PORTFOLIO VALUATION COVERAGE' end,'Coverage excludes cash and requires traceable Decision Snapshot valuation for every risk asset.' from agg
union all select 'covered_pw_upside_contribution',coalesce(covered_pw_before,0),coalesce(covered_pw_after,0),'ratio','PARTIAL - COVERED ASSETS ONLY','Do not interpret as full portfolio expected upside unless valuation coverage is PASS.' from agg
union all select 'full_portfolio_pw_upside',case when full_valuation_covered then covered_pw_before else null end,case when full_valuation_covered then covered_pw_after else null end,'ratio',case when full_valuation_covered then 'PASS' else 'BLOCKED - INCOMPLETE PORTFOLIO VALUATION COVERAGE' end,'Fail-closed: no proxy is substituted for missing holding valuations.' from agg
union all select 'modeled_expected_value_change_thb',0,case when coalesce(changed_assets_covered,false) then coalesce(modeled_change,0) else null end,'THB',case when coalesce(changed_assets_covered,false) then 'PASS - CHANGED ASSETS COVERED' else 'BLOCKED - CHANGED ASSET VALUATION MISSING' end,'Net expected-value change is computed only when every changed non-cash asset has traceable valuation.' from agg
union all select 'added_asset_expected_value_thb',0,coalesce(add_expected_value,0),'THB',case when add_pw_upside is not null then 'PASS - ADD ASSET COVERED' else 'BLOCKED - ADD VALUATION MISSING' end,'Incremental expected value for ADD assets only.' from agg
union all select 'added_asset_pw_upside',null,add_pw_upside,'ratio',case when add_pw_upside is not null then 'PASS' else 'BLOCKED - ADD VALUATION MISSING' end,'Probability-weighted upside from the exact Decision Snapshot mispricing reference.' from agg
union all select 'added_asset_base_upside',null,add_base_upside,'ratio',case when add_base_upside is not null then 'PASS' else 'BLOCKED - ADD VALUATION MISSING' end,'Base upside from the exact Decision Snapshot mispricing reference.' from agg
union all select 'added_asset_weight',0,coalesce(add_weight,0),'ratio','PASS','Post-scenario weight of the added asset.' from agg
union all select 'added_asset_downside_risk_score',null,(select downside_score from add_score),'score_0_100',case when (select downside_score from add_score) is not null then 'PASS - ADD ASSET ONLY' else 'BLOCKED - ADD SCORE MISSING' end,'This is not a full portfolio downside score.' from agg
union all select 'trimmed_value_thb',0,trim_total,'THB','PASS','Hypothetical trim input; M3.3 does not choose the trim.' from trim_stats
union all select 'added_value_thb',0,add_total,'THB','PASS','ADD follows active ranking/capacity rules.' from trim_stats
union all select 'residual_cash_thb',0,cash_total,'THB',case when cash_total>0 then 'HOLD' else 'PASS' end,'Residual cash is retained rather than force-filled.' from trim_stats
union all select 'scenario_input_gate',null,null,'state',(select gate from g),'Structural/current-state validation result.';
$$;

revoke all on function fwios.portfolio_scenario_structural_gate_v1(text,numeric,text[],numeric[],text[]) from public, anon, authenticated;
revoke all on function fwios.portfolio_scenario_current_input_gate_v1(text,numeric,text[],numeric[],text[]) from public, anon, authenticated;
revoke all on function fwios.preview_portfolio_scenario_actions_v1(text,numeric,text[],numeric[],text[]) from public, anon, authenticated;
revoke all on function fwios.preview_portfolio_scenario_positions_v1(text,numeric,text[],numeric[],text[]) from public, anon, authenticated;
revoke all on function fwios.preview_portfolio_scenario_metrics_v1(text,numeric,text[],numeric[],text[]) from public, anon, authenticated;
