-- PR5 MVP: include every active canonical stock in the existing daily-close universe.
-- Keeps current holdings/research/company priorities and existing Twelve Data quota/worker/Cron.
create or replace function fwios.start_market_daily_close_run_v1(
  p_session_date date default fwios.decision_refresh_target_session_v1(now()),
  p_trigger_source text default 'MANUAL'
)
returns jsonb
language plpgsql
set search_path to ''
as $function$
declare
  v_run_id uuid;
  v_created boolean := false;
  v_daily_budget integer := 700;
  v_planned integer := 0;
begin
  select daily_budget into v_daily_budget
  from fwios.market_daily_close_policy
  where provider_key='TWELVE_DATA' and active=true
  limit 1;

  select run_id into v_run_id
  from fwios.market_daily_close_runs
  where session_date=p_session_date;

  if v_run_id is null then
    insert into fwios.market_daily_close_runs(
      session_date,trigger_source,provider_key,status,metadata
    )
    values(
      p_session_date,p_trigger_source,'TWELVE_DATA','QUEUED',
      jsonb_build_object(
        'contract','MARKET_DAILY_CLOSE_V1',
        'display_source_of_truth',true,
        'decision_verification','SELECTIVE_ALPHA_VANTAGE',
        'daily_budget',v_daily_budget,
        'auto_trade',false
      )
    )
    returning run_id into v_run_id;
    v_created := true;
  end if;

  with universe as (
    select h.asset_symbol ticker,0 priority_group,'PORTFOLIO_HOLDING' reason
    from fwios.v_dashboard_holdings h
    where h.account_view_key='ALL' and h.asset_class='Stock'
    union all
    select rc.ticker,1,'RESEARCH_CANDIDATE'
    from fwios.research_candidates rc
    union all
    select c.ticker,2,'ACTIVE_COMPANY'
    from fwios.companies c
    where c.active=true
    union all
    select id.asset_symbol,3,'CANONICAL_STOCK_COVERAGE'
    from fwios.instruments i
    join fwios.v_instrument_identity_current id on id.instrument_id=i.instrument_id
    where i.lifecycle_status='ACTIVE'
      and i.asset_class='Stock'
      and i.instrument_type='COMMON_STOCK'
      and not(i.metadata ? 'qa_identity')
  ),
  dedup as (
    select ticker,min(priority_group) priority_group,
           (array_agg(reason order by priority_group))[1] priority_reason
    from universe
    where ticker is not null and ticker<>''
    group by ticker
  ),
  ranked as (
    select ticker,priority_reason,
           row_number() over(order by priority_group,ticker) rn
    from dedup
  )
  insert into fwios.market_daily_close_jobs(run_id,ticker,priority_reason,status)
  select v_run_id,ticker,priority_reason,'QUEUED'
  from ranked
  where rn<=v_daily_budget
  on conflict(run_id,ticker) do nothing;

  select count(*) into v_planned
  from fwios.market_daily_close_jobs
  where run_id=v_run_id;

  update fwios.market_daily_close_runs
  set symbols_planned=v_planned,jobs_total=v_planned,
      status=case when v_planned>0 then 'QUEUED' else 'BLOCKED' end,
      updated_at=now()
  where run_id=v_run_id;

  return jsonb_build_object(
    'run_id',v_run_id,'created',v_created,'session_date',p_session_date,
    'symbols_planned',v_planned,'daily_budget',v_daily_budget,
    'provider','TWELVE_DATA','display_source_of_truth',true,'auto_trade',false
  );
end
$function$;
