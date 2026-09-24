-- Daily Close Store + Selective Price Verification v1
-- Twelve Data becomes the display/history source for completed daily closes.
-- Alpha Vantage remains a selective verifier for portfolio/decision-critical names.
-- No auto-trading behavior is introduced.

create table if not exists fwios.market_daily_close_policy (
  provider_key text primary key,
  per_minute_budget integer not null check (per_minute_budget between 1 and 1000),
  daily_budget integer not null check (daily_budget between 1 and 100000),
  worker_batch integer not null check (worker_batch between 1 and 1000),
  active boolean not null default true,
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into fwios.market_daily_close_policy(provider_key,per_minute_budget,daily_budget,worker_batch,active,config)
values (
  'TWELVE_DATA',8,700,8,true,
  jsonb_build_object(
    'plan','BASIC_FREE',
    'official_limit','8 credits/minute; 800/day',
    'daily_reserve',100,
    'interval','1day',
    'adjust','none',
    'display_source_of_truth',true,
    'decision_verification_source','ALPHA_VANTAGE_PRICE'
  )
)
on conflict(provider_key) do update
set per_minute_budget=excluded.per_minute_budget,
    daily_budget=excluded.daily_budget,
    worker_batch=excluded.worker_batch,
    active=excluded.active,
    config=excluded.config,
    updated_at=now();

create table if not exists fwios.market_daily_close_runs (
  run_id uuid primary key default gen_random_uuid(),
  session_date date not null unique,
  trigger_source text not null,
  provider_key text not null default 'TWELVE_DATA',
  status text not null default 'QUEUED'
    check (status in ('QUEUED','RUNNING','PASS','PARTIAL','BLOCKED','FAILED')),
  symbols_planned integer not null default 0,
  jobs_total integer not null default 0,
  jobs_pass integer not null default 0,
  jobs_blocked integer not null default 0,
  jobs_failed integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists fwios.market_daily_close_jobs (
  job_id uuid primary key default gen_random_uuid(),
  run_id uuid not null references fwios.market_daily_close_runs(run_id) on delete cascade,
  ticker text not null,
  priority_reason text not null,
  status text not null default 'QUEUED'
    check (status in ('QUEUED','RUNNING','PASS','RETRY','BLOCKED','DEAD_LETTER')),
  attempts integer not null default 0,
  max_attempts integer not null default 4,
  last_error text,
  output jsonb not null default '{}'::jsonb,
  next_retry_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(run_id,ticker)
);

create index if not exists market_daily_close_jobs_status_idx
  on fwios.market_daily_close_jobs(status,updated_at);
create index if not exists market_daily_close_jobs_run_idx
  on fwios.market_daily_close_jobs(run_id,status);

create table if not exists fwios.market_daily_closes (
  asset_symbol text not null,
  session_date date not null,
  close_price numeric not null check (close_price > 0),
  currency text,
  exchange text,
  primary_provider text not null default 'TWELVE_DATA',
  source_url text,
  source_tier text not null default 'A',
  retrieved_at timestamptz not null default now(),
  verification_status text not null default 'PRIMARY_ONLY'
    check (verification_status in ('PRIMARY_ONLY','VERIFIED','CONFLICT','REJECTED')),
  secondary_provider text,
  secondary_close numeric,
  divergence_pct numeric,
  verified_at timestamptz,
  provenance_status text not null default 'PASS',
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(asset_symbol,session_date)
);

create index if not exists market_daily_closes_session_idx
  on fwios.market_daily_closes(session_date desc,asset_symbol);

create table if not exists fwios.market_daily_close_api_usage (
  usage_id uuid primary key default gen_random_uuid(),
  provider_key text not null,
  usage_date_utc date not null,
  ticker text,
  caller text not null,
  called_at timestamptz not null default now(),
  outcome text not null default 'RESERVED',
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists market_daily_close_api_usage_day_idx
  on fwios.market_daily_close_api_usage(provider_key,usage_date_utc,called_at);

alter table fwios.market_daily_close_policy enable row level security;
alter table fwios.market_daily_close_runs enable row level security;
alter table fwios.market_daily_close_jobs enable row level security;
alter table fwios.market_daily_closes enable row level security;
alter table fwios.market_daily_close_api_usage enable row level security;

revoke all on fwios.market_daily_close_policy from public,anon,authenticated;
revoke all on fwios.market_daily_close_runs from public,anon,authenticated;
revoke all on fwios.market_daily_close_jobs from public,anon,authenticated;
revoke all on fwios.market_daily_closes from public,anon,authenticated;
revoke all on fwios.market_daily_close_api_usage from public,anon,authenticated;

create or replace view fwios.v_market_daily_close_latest
with (security_invoker = true)
as
select distinct on (asset_symbol)
  asset_symbol,session_date,close_price,currency,exchange,primary_provider,
  verification_status,retrieved_at,provenance_status
from fwios.market_daily_closes
where provenance_status='PASS'
order by asset_symbol,session_date desc,retrieved_at desc;

revoke all on fwios.v_market_daily_close_latest from public,anon,authenticated;

create or replace function fwios.reserve_market_daily_close_api_call_v1(
  p_provider_key text,p_ticker text,p_caller text,p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
set search_path to ''
as $function$
declare
  v_per_minute int;
  v_daily int;
  v_minute_used int;
  v_daily_used int;
  v_usage_id uuid;
  v_day date := (now() at time zone 'UTC')::date;
begin
  select per_minute_budget,daily_budget
  into v_per_minute,v_daily
  from fwios.market_daily_close_policy
  where provider_key=p_provider_key and active=true
  limit 1;

  if v_per_minute is null then
    return jsonb_build_object('allowed',false,'reason','POLICY_NOT_ACTIVE');
  end if;

  perform pg_advisory_xact_lock(
    hashtext(p_provider_key || '|' || to_char(now() at time zone 'UTC','YYYY-MM-DD HH24:MI'))
  );

  select count(*) into v_minute_used
  from fwios.market_daily_close_api_usage
  where provider_key=p_provider_key
    and called_at >= date_trunc('minute',now());

  select count(*) into v_daily_used
  from fwios.market_daily_close_api_usage
  where provider_key=p_provider_key
    and usage_date_utc=v_day;

  if v_minute_used >= v_per_minute then
    return jsonb_build_object(
      'allowed',false,'reason','PER_MINUTE_BUDGET_EXHAUSTED',
      'used',v_minute_used,'limit',v_per_minute
    );
  end if;

  if v_daily_used >= v_daily then
    return jsonb_build_object(
      'allowed',false,'reason','DAILY_BUDGET_EXHAUSTED',
      'used',v_daily_used,'limit',v_daily
    );
  end if;

  insert into fwios.market_daily_close_api_usage(
    provider_key,usage_date_utc,ticker,caller,outcome,metadata
  )
  values(p_provider_key,v_day,p_ticker,p_caller,'RESERVED',coalesce(p_metadata,'{}'::jsonb))
  returning usage_id into v_usage_id;

  return jsonb_build_object(
    'allowed',true,'usage_id',v_usage_id,
    'minute_used_after',v_minute_used+1,'minute_limit',v_per_minute,
    'daily_used_after',v_daily_used+1,'daily_limit',v_daily
  );
end
$function$;

revoke all on function fwios.reserve_market_daily_close_api_call_v1(text,text,text,jsonb)
  from public,anon,authenticated;
grant execute on function fwios.reserve_market_daily_close_api_call_v1(text,text,text,jsonb)
  to service_role;

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

revoke all on function fwios.start_market_daily_close_run_v1(date,text)
  from public,anon,authenticated;
grant execute on function fwios.start_market_daily_close_run_v1(date,text)
  to service_role;

create or replace function fwios.claim_market_daily_close_jobs_v1(p_limit integer default 8)
returns setof fwios.market_daily_close_jobs
language sql
set search_path to 'pg_catalog','fwios'
as $function$
  with picked as (
    select j.job_id
    from fwios.market_daily_close_jobs j
    join fwios.market_daily_close_runs r on r.run_id=j.run_id
    where (
      j.status='QUEUED'
      or (j.status='RETRY' and coalesce(j.next_retry_at,now())<=now())
      or (j.status='RUNNING' and j.updated_at<now()-interval '15 minutes')
    )
      and r.status in ('QUEUED','RUNNING','PARTIAL')
    order by r.session_date,j.created_at,j.ticker
    for update of j skip locked
    limit greatest(1,least(coalesce(p_limit,8),8))
  )
  update fwios.market_daily_close_jobs j
  set status='RUNNING',attempts=j.attempts+1,next_retry_at=null,updated_at=now()
  from picked p
  where j.job_id=p.job_id
  returning j.*;
$function$;

revoke all on function fwios.claim_market_daily_close_jobs_v1(integer)
  from public,anon,authenticated;
grant execute on function fwios.claim_market_daily_close_jobs_v1(integer)
  to service_role;

create or replace function fwios.refresh_market_daily_close_run_status_v1(p_run_id uuid)
returns jsonb
language plpgsql
set search_path to ''
as $function$
declare
  v_total int;
  v_pass int;
  v_blocked int;
  v_failed int;
  v_open int;
  v_status text;
begin
  select count(*),
         count(*) filter(where status='PASS'),
         count(*) filter(where status='BLOCKED'),
         count(*) filter(where status='DEAD_LETTER'),
         count(*) filter(where status in ('QUEUED','RUNNING','RETRY'))
  into v_total,v_pass,v_blocked,v_failed,v_open
  from fwios.market_daily_close_jobs
  where run_id=p_run_id;

  v_status := case
    when v_open>0 and v_pass=0 then 'RUNNING'
    when v_open>0 then 'PARTIAL'
    when v_total>0 and v_pass=v_total then 'PASS'
    when v_pass>0 then 'PARTIAL'
    when v_failed>0 then 'FAILED'
    else 'BLOCKED'
  end;

  update fwios.market_daily_close_runs
  set jobs_total=v_total,jobs_pass=v_pass,jobs_blocked=v_blocked,jobs_failed=v_failed,
      status=v_status,completed_at=case when v_open=0 then now() else null end,updated_at=now()
  where run_id=p_run_id;

  return jsonb_build_object(
    'run_id',p_run_id,'status',v_status,'jobs_total',v_total,
    'jobs_pass',v_pass,'jobs_blocked',v_blocked,'jobs_failed',v_failed,'jobs_open',v_open
  );
end
$function$;

revoke all on function fwios.refresh_market_daily_close_run_status_v1(uuid)
  from public,anon,authenticated;
grant execute on function fwios.refresh_market_daily_close_run_status_v1(uuid)
  to service_role;

update fwios.decision_refresh_api_quota_policy
set price_budget=15,
    config=config||jsonb_build_object(
      'price_budget_reason','selective verification: portfolio + highest priority research only',
      'daily_close_primary','TWELVE_DATA',
      'daily_close_store','fwios.market_daily_closes'
    ),
    updated_at=now()
where provider_group='ALPHA_VANTAGE_SHARED';

update fwios.decision_refresh_provider_registry
set config=(config-'session_bound')||jsonb_build_object(
      'session_selector','date',
      'exact_daily_close_param','date=YYYY-MM-DD',
      'eod_availability_policy','after 00:00 ET on next trading day'
    ),
    updated_at=now()
where provider_key='TWELVE_DATA';

create or replace function fwios.decision_refresh_price_plan_v1(
  p_session_date date,p_limit integer default null
)
returns table(plan_rank integer,ticker text,priority_reason text,last_price_session date)
language sql
stable
set search_path to 'pg_catalog','fwios'
as $function$
with cfg as (
  select least(coalesce(p_limit,price_budget,15),15) lim
  from fwios.decision_refresh_api_quota_policy
  where provider_group='ALPHA_VANTAGE_SHARED' and active=true
),
last_verified as (
  select asset_symbol,max(session_date) last_session
  from fwios.market_price_snapshots
  where price_gate='PASS' and provenance_status='PASS'
  group by asset_symbol
),
holdings as (
  select h.asset_symbol ticker
  from fwios.v_dashboard_holdings h
  where h.account_view_key='ALL' and h.asset_class='Stock'
),
scored as (
  select rc.ticker,lv.last_session,
         case
           when h.ticker is not null then 0
           when exists(
             select 1 from fwios.blockers b
             where b.ticker=rc.ticker and b.current_status='BLOCKED'
               and b.orchestrator_state in ('WAITING_PROVIDER_EOD','WAITING_POST_EVENT_PRICE')
           ) then 1
           when rc.mispricing_gate='PASS' then 2
           when rc.mispricing_gate like 'BLOCKED - PRICE%'
             or rc.mispricing_gate='BLOCKED - POST-EVENT PRICE' then 3
           when rc.valuation_gate='PASS' then 4
           else 5
         end priority_group,
         case
           when h.ticker is not null then 'PORTFOLIO_HOLDING_VERIFY'
           when exists(
             select 1 from fwios.blockers b
             where b.ticker=rc.ticker and b.current_status='BLOCKED'
               and b.orchestrator_state='WAITING_POST_EVENT_PRICE'
           ) then 'MATERIAL_EVENT_VERIFY'
           when exists(
             select 1 from fwios.blockers b
             where b.ticker=rc.ticker and b.current_status='BLOCKED'
               and b.orchestrator_state='WAITING_PROVIDER_EOD'
           ) then 'PRICE_FRESHNESS_VERIFY'
           when rc.mispricing_gate='PASS' then 'MISPRICING_PASS_VERIFY'
           when rc.mispricing_gate like 'BLOCKED - PRICE%'
             or rc.mispricing_gate='BLOCKED - POST-EVENT PRICE' then 'PRICE_BLOCKED_VERIFY'
           when rc.valuation_gate='PASS' then 'VALUATION_READY_VERIFY'
           else 'ROTATION_VERIFY'
         end reason,
         coalesce(rc.expected_return_valuation_score,0) ers,
         coalesce(rc.quality_score,0) qs
  from fwios.research_candidates rc
  left join last_verified lv on lv.asset_symbol=rc.ticker
  left join holdings h on h.ticker=rc.ticker
),
portfolio_only as (
  select h.ticker,lv.last_session,0 priority_group,'PORTFOLIO_HOLDING_VERIFY' reason,
         0::numeric ers,0::numeric qs
  from holdings h
  left join last_verified lv on lv.asset_symbol=h.ticker
  where not exists(select 1 from scored s where s.ticker=h.ticker)
),
all_scored as (
  select * from scored
  union all
  select * from portfolio_only
),
ranked as (
  select row_number() over(
           order by priority_group,last_session asc nulls first,ers desc,qs desc,
                    md5(ticker||p_session_date::text)
         )::integer plan_rank,
         ticker,reason,last_session
  from all_scored
)
select r.plan_rank,r.ticker,r.reason,r.last_session
from ranked r cross join cfg
where r.plan_rank<=cfg.lim
order by r.plan_rank;
$function$;

revoke all on function fwios.decision_refresh_price_plan_v1(date,integer)
  from public,anon,authenticated;
grant execute on function fwios.decision_refresh_price_plan_v1(date,integer)
  to service_role;

create or replace view fwios.v_dashboard_valuation_map
with (security_invoker = true)
as
with latest_valuation as (
  select distinct on (v.ticker)
    v.ticker,v.run_id valuation_run_id,v.model_id,v.as_of_text valuation_as_of,
    v.created_at valuation_created_at,v.current_price valuation_reference_price,
    v.bear_fv_per_share,v.base_fv_per_share,v.bull_fv_per_share,
    v.probability_weighted_fv_per_share
  from fwios.valuation_runs v
  where v.production_eligible=true
    and v.bear_fv_per_share is not null
    and v.base_fv_per_share is not null
    and v.bull_fv_per_share is not null
    and v.probability_weighted_fv_per_share is not null
  order by v.ticker,v.created_at desc
),
latest_candidate as (
  select distinct on (r.ticker)
    r.ticker,r.promotion_gate,r.mispricing_gate candidate_mispricing_gate,
    r.final_decision,r.updated_at
  from fwios.research_candidates r
  order by r.ticker,r.updated_at desc
),
latest_mispricing as (
  select distinct on (m.ticker)
    m.ticker,m.effective_mispricing_gate,m.effective_mispricing_class,m.created_at
  from fwios.v_valuation_mispricing_current m
  order by m.ticker,m.created_at desc
),
base as (
  select
    c.sector,v.ticker,c.company_name,
    coalesce(dc.close_price,p.selected_price,v.valuation_reference_price) current_price,
    coalesce(dc.session_date,p.session_date) price_session_date,
    case
      when dc.asset_symbol is not null then 'DAILY CLOSE - '||dc.verification_status
      else coalesce(p.effective_price_gate,'BLOCKED - NO CURRENT PRICE')
    end price_gate,
    coalesce(p.effective_price_gate,'BLOCKED - NO VERIFIED DECISION PRICE') decision_price_gate,
    v.bear_fv_per_share bear_fv,v.base_fv_per_share base_fv,
    v.bull_fv_per_share high_fv,v.probability_weighted_fv_per_share fair_value,
    case when coalesce(dc.close_price,p.selected_price,v.valuation_reference_price)>0
      then v.bear_fv_per_share/coalesce(dc.close_price,p.selected_price,v.valuation_reference_price)-1 end bear_upside,
    case when coalesce(dc.close_price,p.selected_price,v.valuation_reference_price)>0
      then v.base_fv_per_share/coalesce(dc.close_price,p.selected_price,v.valuation_reference_price)-1 end base_upside,
    case when coalesce(dc.close_price,p.selected_price,v.valuation_reference_price)>0
      then v.bull_fv_per_share/coalesce(dc.close_price,p.selected_price,v.valuation_reference_price)-1 end high_upside,
    case when coalesce(dc.close_price,p.selected_price,v.valuation_reference_price)>0
      then v.probability_weighted_fv_per_share/coalesce(dc.close_price,p.selected_price,v.valuation_reference_price)-1 end fair_value_upside,
    v.valuation_as_of,v.model_id,v.valuation_run_id,lc.promotion_gate,
    coalesce(lm.effective_mispricing_gate,lc.candidate_mispricing_gate,'PENDING PRICE') mispricing_gate
  from latest_valuation v
  left join fwios.companies c on c.ticker=v.ticker
  left join fwios.v_market_daily_close_latest dc on dc.asset_symbol=v.ticker
  left join fwios.v_market_price_latest p on p.asset_symbol=v.ticker
  left join latest_candidate lc on lc.ticker=v.ticker
  left join latest_mispricing lm on lm.ticker=v.ticker
)
select
  sector,ticker,company_name,current_price,price_session_date,price_gate,
  bear_fv,base_fv,high_fv,fair_value,bear_upside,base_upside,high_upside,fair_value_upside,
  case
    when current_price is null then 'PRICE MISSING'
    when current_price<=bear_fv then 'HIGH UPSIDE / BELOW BEAR FV'
    when current_price<=base_fv then 'BASE VALUE ZONE'
    when current_price<=high_fv then 'BULL CASE ONLY'
    else 'ABOVE BULL FV'
  end price_zone,
  case
    when decision_price_gate<>'PASS' then 'PRICE VERIFY'
    when mispricing_gate='PASS' and promotion_gate='PASS' then 'BUY REVIEW'
    when current_price<=base_fv then 'VALUE WATCH'
    else 'WAIT'
  end system_signal,
  mispricing_gate,valuation_as_of,model_id,valuation_run_id
from base
order by
  case
    when decision_price_gate='PASS' and mispricing_gate='PASS' and promotion_gate='PASS' then 0
    when current_price<=bear_fv then 1
    when current_price<=base_fv then 2
    when current_price<=high_fv then 3
    else 4
  end,
  fair_value_upside desc nulls last,ticker;

revoke all on fwios.v_dashboard_valuation_map from public,anon,authenticated;

select cron.unschedule(jobid)
from cron.job
where jobname in ('fwios-market-daily-close-enqueue','fwios-market-daily-close-worker');

select cron.schedule(
  'fwios-market-daily-close-enqueue',
  '25 5 * * 1-5',
  $$select fwios.start_market_daily_close_run_v1(
      fwios.decision_refresh_target_session_v1(now()),
      'CRON_EOD_DAILY_CLOSE'
    );$$
);

select cron.schedule(
  'fwios-market-daily-close-worker',
  '*/2 5-8 * * 1-5',
  $cmd$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name='fwios_project_url' limit 1)
             || '/functions/v1/market-daily-close-worker-v1',
      headers := jsonb_build_object(
        'Content-Type','application/json',
        'x-fwios-automation-token',
        (select decrypted_secret from vault.decrypted_secrets where name='fwios_automation_token' limit 1)
      ),
      body := jsonb_build_object('source','PG_CRON','requested_at',now()),
      timeout_milliseconds := 20000
    );
  $cmd$
);

select cron.unschedule(jobid)
from cron.job
where jobname='fwios-shadow-decision-refresh-enqueue';

select cron.schedule(
  'fwios-shadow-decision-refresh-enqueue',
  '10 6 * * 1-5',
  $$select fwios.start_decision_refresh_shadow(
      fwios.decision_refresh_target_session_v1(now()),
      'CRON_EOD_SELECTIVE_VERIFY'
    );$$
);

update fwios.system_state
set state_value=state_value||jsonb_build_object(
      'daily_close_store','LIVE_TWELVE_DATA_PRIMARY_V1',
      'daily_close_table','fwios.market_daily_closes',
      'daily_close_schedule_utc','05:25 Mon-Fri',
      'daily_close_worker_window_utc','05:00-08:59 Mon-Fri / every 2 minutes / max 8 calls per run',
      'daily_close_budget','8/min; 700/day internal guard; Twelve Basic official 800/day',
      'decision_price_verification','SELECTIVE_ALPHA_VANTAGE_MAX_15_PER_DAY',
      'decision_refresh_schedule_utc','06:10 Mon-Fri',
      'googlefinance_role','DISPLAY_FALLBACK_ONLY',
      'twelve_daily_exact_selector','date=YYYY-MM-DD',
      'legacy_end_date_bug','FIXED_2026-09-24',
      'auto_trade',false
    ),
    as_of_text='2026-09-24',
    updated_at=now()
where state_key='architecture_consolidation_v1';
