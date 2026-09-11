create or replace function fwios.start_decision_refresh_shadow(
  p_session_date date default ((now() at time zone 'America/New_York')::date),
  p_trigger_source text default 'MANUAL'
) returns jsonb
language plpgsql
set search_path=''
as $$
declare
  v_run_id uuid;
  v_created boolean := false;
  v_candidate_count integer := 0;
  v_job_count integer := 0;
  v_consensus_ready boolean := false;
  r record;
begin
  select run_id into v_run_id from fwios.decision_refresh_runs where mode='SHADOW' and session_date=p_session_date;
  if v_run_id is null then
    insert into fwios.decision_refresh_runs(mode,session_date,trigger_source,status,authoritative_write,metadata)
    values('SHADOW',p_session_date,p_trigger_source,'QUEUED',false,jsonb_build_object('contract','AUTO_DECISION_REFRESH_V1','authoritative_write',false,'calendar_gate','WEEKDAY_SCHEDULE; SESSION VALIDATION DEFERRED TO MARKET PROVIDER','created_by','fwios.start_decision_refresh_shadow','capability_aware_enqueue',true))
    returning run_id into v_run_id;
    v_created := true;
  end if;
  select count(*) into v_candidate_count from fwios.research_candidates;
  select exists(select 1 from fwios.decision_refresh_provider_registry where provider_key='ALPHA_VANTAGE_CONSENSUS' and active=true and readiness_status='READY' and source_tier='A') into v_consensus_ready;
  for r in
    with job_types as (
      select 'SEC_SUBMISSIONS'::text as job_type
      union all select 'PRICE_PAIR'
      union all select 'CONSENSUS' where v_consensus_ready
    ), ins as (
      insert into fwios.decision_refresh_jobs(run_id,ticker,job_type,status)
      select v_run_id,rc.ticker,jt.job_type,'QUEUED'
      from fwios.research_candidates rc cross join job_types jt
      on conflict(run_id,ticker,job_type) do nothing
      returning job_id,ticker,job_type
    ) select * from ins
  loop
    perform pgmq.send('fwios_decision_refresh',jsonb_build_object('job_id',r.job_id,'run_id',v_run_id,'ticker',r.ticker,'job_type',r.job_type));
    v_job_count:=v_job_count+1;
  end loop;
  update fwios.decision_refresh_runs set candidate_count=v_candidate_count,jobs_total=(select count(*) from fwios.decision_refresh_jobs where run_id=v_run_id),status=case when (select count(*) from fwios.decision_refresh_jobs where run_id=v_run_id)>0 then 'QUEUED' else status end,updated_at=now() where run_id=v_run_id;
  return jsonb_build_object('run_id',v_run_id,'created',v_created,'session_date',p_session_date,'candidate_count',v_candidate_count,'new_jobs_enqueued',v_job_count,'consensus_enqueued',v_consensus_ready,'mode','SHADOW','authoritative_write',false);
end $$;

select cron.alter_job(2,schedule:='*/5 * * * *');

update fwios.system_state
set state_value=state_value||jsonb_build_object(
  'worker_version',10,
  'provider_validator_version',3,
  'provider_capability_split','V1_LIVE',
  'alpha_price_provider','ALPHA_VANTAGE_PRICE',
  'alpha_consensus_provider','ALPHA_VANTAGE_CONSENSUS',
  'alpha_price_state','READY_TIER_A',
  'alpha_consensus_state','DEGRADED_RATE_LIMIT',
  'capability_aware_enqueue',true,
  'alpha_min_interval_ms',1100,
  'worker_schedule','*/5 * * * *'
),updated_at=now()
where state_key='auto_decision_refresh_v1';
