create or replace function fwios.decision_refresh_price_plan_v1(p_session_date date, p_limit integer default null)
returns table(plan_rank integer,ticker text,priority_reason text,last_price_session date)
language sql stable set search_path='pg_catalog','fwios' as $$
with cfg as (
  select coalesce(p_limit,price_budget,20) lim
  from fwios.decision_refresh_api_quota_policy
  where provider_group='ALPHA_VANTAGE_SHARED' and active=true
), last_px as (
  select asset_symbol,max(session_date) last_session
  from fwios.market_price_snapshots
  where price_gate='PASS' and provenance_status='PASS'
  group by asset_symbol
), scored as (
  select rc.ticker,lp.last_session,
    case
      when exists(select 1 from fwios.blockers b where b.ticker=rc.ticker and b.current_status='BLOCKED' and b.orchestrator_state in ('WAITING_PROVIDER_EOD','WAITING_POST_EVENT_PRICE')) then 0
      when rc.mispricing_gate='PASS' then 1
      when rc.mispricing_gate like 'BLOCKED - PRICE%' or rc.mispricing_gate='BLOCKED - POST-EVENT PRICE' then 2
      when rc.valuation_gate='PASS' then 3
      else 4
    end priority_group,
    case
      when exists(select 1 from fwios.blockers b where b.ticker=rc.ticker and b.current_status='BLOCKED' and b.orchestrator_state='WAITING_POST_EVENT_PRICE') then 'MATERIAL_EVENT_PRICE'
      when exists(select 1 from fwios.blockers b where b.ticker=rc.ticker and b.current_status='BLOCKED' and b.orchestrator_state='WAITING_PROVIDER_EOD') then 'EXACT_SESSION_FRESHNESS'
      when rc.mispricing_gate='PASS' then 'MISPRICING_PASS_RECHECK'
      when rc.mispricing_gate like 'BLOCKED - PRICE%' or rc.mispricing_gate='BLOCKED - POST-EVENT PRICE' then 'PRICE_BLOCKED'
      when rc.valuation_gate='PASS' then 'VALUATION_READY_ROTATION'
      else 'ROTATION'
    end reason,
    coalesce(rc.expected_return_valuation_score,0) ers,
    coalesce(rc.quality_score,0) qs
  from fwios.research_candidates rc
  left join last_px lp on lp.asset_symbol=rc.ticker
), ranked as (
  select row_number() over(order by priority_group,last_session asc nulls first,ers desc,qs desc,md5(ticker||p_session_date::text))::integer plan_rank,
         ticker,reason,last_session
  from scored
)
select r.plan_rank,r.ticker,r.reason,r.last_session
from ranked r cross join cfg
where r.plan_rank<=cfg.lim
order by r.plan_rank
$$;
revoke all on function fwios.decision_refresh_price_plan_v1(date,integer) from public,anon,authenticated;

create or replace function fwios.start_decision_refresh_shadow(p_session_date date default ((now() at time zone 'America/New_York'))::date,p_trigger_source text default 'MANUAL') returns jsonb
language plpgsql set search_path='' as $$
declare
  v_run_id uuid; v_created boolean:=false; v_candidate_count integer:=0; v_job_count integer:=0; v_price_count integer:=0; v_price_budget integer:=20; r record;
begin
  select coalesce(price_budget,20) into v_price_budget from fwios.decision_refresh_api_quota_policy where provider_group='ALPHA_VANTAGE_SHARED' and active=true limit 1;
  select run_id into v_run_id from fwios.decision_refresh_runs where mode='SHADOW' and session_date=p_session_date;
  if v_run_id is null then
    insert into fwios.decision_refresh_runs(mode,session_date,trigger_source,status,authoritative_write,metadata)
    values('SHADOW',p_session_date,p_trigger_source,'QUEUED',false,jsonb_build_object(
      'contract','AUTO_DECISION_REFRESH_V1','authoritative_write',false,'quota_aware',true,'price_budget',v_price_budget,
      'calendar_gate','EOD AFTER MIDNIGHT ET NEXT TRADING DAY; EXACT SESSION REQUIRED','consensus_daily',false,
      'created_by','fwios.start_decision_refresh_shadow')) returning run_id into v_run_id;
    v_created:=true;
  end if;
  select count(*) into v_candidate_count from fwios.research_candidates;
  for r in
    with ins as (
      insert into fwios.decision_refresh_jobs(run_id,ticker,job_type,status)
      select v_run_id,rc.ticker,'SEC_SUBMISSIONS','QUEUED' from fwios.research_candidates rc
      on conflict(run_id,ticker,job_type) do nothing returning job_id,ticker,job_type
    ) select * from ins
  loop
    perform pgmq.send('fwios_decision_refresh',jsonb_build_object('job_id',r.job_id,'run_id',v_run_id,'ticker',r.ticker,'job_type',r.job_type));
    v_job_count:=v_job_count+1;
  end loop;
  for r in
    with plan as (select * from fwios.decision_refresh_price_plan_v1(p_session_date,v_price_budget)), ins as (
      insert into fwios.decision_refresh_jobs(run_id,ticker,job_type,status)
      select v_run_id,p.ticker,'PRICE_PAIR','QUEUED' from plan p
      on conflict(run_id,ticker,job_type) do nothing returning job_id,ticker,job_type
    ) select * from ins
  loop
    perform pgmq.send('fwios_decision_refresh',jsonb_build_object('job_id',r.job_id,'run_id',v_run_id,'ticker',r.ticker,'job_type',r.job_type));
    v_job_count:=v_job_count+1; v_price_count:=v_price_count+1;
  end loop;
  update fwios.decision_refresh_runs set candidate_count=v_candidate_count,jobs_total=(select count(*) from fwios.decision_refresh_jobs where run_id=v_run_id),
    status=case when (select count(*) from fwios.decision_refresh_jobs where run_id=v_run_id)>0 then 'QUEUED' else status end,
    metadata=metadata||jsonb_build_object('price_jobs_planned',v_price_count),updated_at=now() where run_id=v_run_id;
  return jsonb_build_object('run_id',v_run_id,'created',v_created,'session_date',p_session_date,'candidate_count',v_candidate_count,
    'new_jobs_enqueued',v_job_count,'price_jobs_enqueued',v_price_count,'price_budget',v_price_budget,'consensus_enqueued',false,'mode','SHADOW','authoritative_write',false);
end $$;

DO $$ begin perform cron.unschedule('fwios-shadow-decision-refresh-enqueue'); exception when others then null; end $$;
select cron.schedule('fwios-shadow-decision-refresh-enqueue','20 5 * * 1-5',
  $$select fwios.start_decision_refresh_shadow(fwios.decision_refresh_target_session_v1(now()),'CRON_EOD_QUOTA_AWARE');$$);
DO $$ begin perform cron.unschedule('fwios-provider-validator-v1'); exception when others then null; end $$;
select cron.schedule('fwios-provider-validator-v1','17 6 * * 1,3,5',
  $$select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='fwios_project_url' limit 1) || '/functions/v1/decision-refresh-provider-validator-v1',
    headers := jsonb_build_object('Content-Type','application/json','x-fwios-automation-token',(select decrypted_secret from vault.decrypted_secrets where name='fwios_automation_token' limit 1)),
    body := jsonb_build_object('source','PG_CRON_QUOTA_AWARE','requested_at',now()),timeout_milliseconds := 20000
  );$$);
