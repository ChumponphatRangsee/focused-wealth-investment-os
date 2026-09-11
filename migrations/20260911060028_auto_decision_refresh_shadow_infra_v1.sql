create extension if not exists pgcrypto with schema extensions;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;
create extension if not exists pgmq;

create table if not exists fwios.decision_refresh_provider_registry (
  provider_key text primary key,
  provider_type text not null,
  provider_name text not null,
  source_tier text not null,
  requires_secret boolean not null default false,
  secret_name text,
  active boolean not null default false,
  readiness_status text not null,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (readiness_status in ('READY','NOT_CONFIGURED','DISABLED','DEGRADED'))
);

create table if not exists fwios.decision_refresh_runs (
  run_id uuid primary key default gen_random_uuid(),
  mode text not null default 'SHADOW',
  session_date date not null,
  trigger_source text not null,
  status text not null default 'QUEUED',
  candidate_count integer not null default 0,
  jobs_total integer not null default 0,
  jobs_pass integer not null default 0,
  jobs_blocked integer not null default 0,
  jobs_failed integer not null default 0,
  authoritative_write boolean not null default false,
  started_at timestamptz,
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(mode, session_date),
  check (mode in ('SHADOW','PRODUCTION')),
  check (status in ('QUEUED','RUNNING','PASS','BLOCKED','FAILED')),
  check (not (mode='SHADOW' and authoritative_write))
);

create table if not exists fwios.decision_refresh_jobs (
  job_id uuid primary key default gen_random_uuid(),
  run_id uuid not null references fwios.decision_refresh_runs(run_id) on delete cascade,
  ticker text not null,
  job_type text not null,
  status text not null default 'QUEUED',
  attempts integer not null default 0,
  max_attempts integer not null default 5,
  last_error text,
  output jsonb not null default '{}'::jsonb,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(run_id, ticker, job_type),
  check (job_type in ('SEC_SUBMISSIONS','PRICE_PAIR','CONSENSUS')),
  check (status in ('QUEUED','RUNNING','PASS','BLOCKED','RETRY','DEAD_LETTER')),
  check (attempts >= 0 and max_attempts between 1 and 20)
);

create index if not exists idx_decision_refresh_jobs_due
  on fwios.decision_refresh_jobs(status, updated_at)
  where status in ('QUEUED','RETRY');
create index if not exists idx_decision_refresh_jobs_run
  on fwios.decision_refresh_jobs(run_id, status);

create table if not exists fwios.decision_refresh_shadow_evidence (
  evidence_id uuid primary key default gen_random_uuid(),
  run_id uuid not null references fwios.decision_refresh_runs(run_id) on delete cascade,
  job_id uuid not null references fwios.decision_refresh_jobs(job_id) on delete cascade,
  ticker text not null,
  fact_class text not null,
  source_provider text not null,
  source_url text not null,
  source_tier text not null,
  observed_at timestamptz,
  payload_fingerprint text,
  payload jsonb not null default '{}'::jsonb,
  collection_status text not null,
  created_at timestamptz not null default now(),
  unique(job_id, source_provider, fact_class),
  check (collection_status in ('PASS','BLOCKED','ERROR'))
);

create index if not exists idx_shadow_evidence_ticker
  on fwios.decision_refresh_shadow_evidence(ticker, created_at desc);

create table if not exists fwios.decision_refresh_automation_access (
  access_key text primary key,
  token_sha256 text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table fwios.decision_refresh_provider_registry enable row level security;
alter table fwios.decision_refresh_runs enable row level security;
alter table fwios.decision_refresh_jobs enable row level security;
alter table fwios.decision_refresh_shadow_evidence enable row level security;
alter table fwios.decision_refresh_automation_access enable row level security;

revoke all on fwios.decision_refresh_provider_registry from anon, authenticated;
revoke all on fwios.decision_refresh_runs from anon, authenticated;
revoke all on fwios.decision_refresh_jobs from anon, authenticated;
revoke all on fwios.decision_refresh_shadow_evidence from anon, authenticated;
revoke all on fwios.decision_refresh_automation_access from anon, authenticated;

insert into fwios.decision_refresh_provider_registry
(provider_key, provider_type, provider_name, source_tier, requires_secret, secret_name, active, readiness_status, config)
values
('SEC_EDGAR','FILINGS','SEC EDGAR data.sec.gov','A',false,null,true,'READY',jsonb_build_object('max_requests_per_second',5,'user_agent','FWIOS/1.0 personal-investment-research')),
('TWELVE_DATA','MARKET_PRICE','Twelve Data','A_PENDING_VALIDATION',true,'TWELVE_DATA_API_KEY',false,'NOT_CONFIGURED','{}'::jsonb),
('ALPHA_VANTAGE','MARKET_PRICE_AND_CONSENSUS','Alpha Vantage','A_PENDING_VALIDATION',true,'ALPHA_VANTAGE_API_KEY',false,'NOT_CONFIGURED','{}'::jsonb)
on conflict(provider_key) do update set
  provider_type=excluded.provider_type,
  provider_name=excluded.provider_name,
  source_tier=excluded.source_tier,
  requires_secret=excluded.requires_secret,
  secret_name=excluded.secret_name,
  config=excluded.config,
  updated_at=now();

select pgmq.create('fwios_decision_refresh');

do $$
declare
  v_token text;
begin
  if not exists (select 1 from vault.secrets where name='fwios_project_url') then
    perform vault.create_secret('https://ysjbmeukwbfnxnwqchuq.supabase.co','fwios_project_url','FWIOS project URL for internal cron calls');
  end if;

  if not exists (select 1 from vault.secrets where name='fwios_automation_token') then
    v_token := encode(gen_random_bytes(32),'hex');
    perform vault.create_secret(v_token,'fwios_automation_token','FWIOS internal decision-refresh worker token');
    insert into fwios.decision_refresh_automation_access(access_key, token_sha256, active)
    values('DECISION_REFRESH_WORKER', encode(digest(v_token,'sha256'),'hex'), true)
    on conflict(access_key) do update set token_sha256=excluded.token_sha256, active=true, updated_at=now();
  elsif not exists (select 1 from fwios.decision_refresh_automation_access where access_key='DECISION_REFRESH_WORKER') then
    select decrypted_secret into v_token from vault.decrypted_secrets where name='fwios_automation_token' limit 1;
    insert into fwios.decision_refresh_automation_access(access_key, token_sha256, active)
    values('DECISION_REFRESH_WORKER', encode(digest(v_token,'sha256'),'hex'), true);
  end if;
end $$;

create or replace function fwios.start_decision_refresh_shadow(
  p_session_date date default ((now() at time zone 'America/New_York')::date),
  p_trigger_source text default 'MANUAL'
) returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_run_id uuid;
  v_created boolean := false;
  v_candidate_count integer := 0;
  v_job_count integer := 0;
  r record;
begin
  select run_id into v_run_id
  from fwios.decision_refresh_runs
  where mode='SHADOW' and session_date=p_session_date;

  if v_run_id is null then
    insert into fwios.decision_refresh_runs(mode, session_date, trigger_source, status, authoritative_write, metadata)
    values('SHADOW', p_session_date, p_trigger_source, 'QUEUED', false,
      jsonb_build_object(
        'contract','AUTO_DECISION_REFRESH_V1',
        'authoritative_write',false,
        'calendar_gate','WEEKDAY_SCHEDULE; SESSION VALIDATION DEFERRED TO MARKET PROVIDER',
        'created_by','fwios.start_decision_refresh_shadow'
      ))
    returning run_id into v_run_id;
    v_created := true;
  end if;

  select count(*) into v_candidate_count from fwios.research_candidates;

  for r in
    with ins as (
      insert into fwios.decision_refresh_jobs(run_id,ticker,job_type,status)
      select v_run_id, rc.ticker, jt.job_type, 'QUEUED'
      from fwios.research_candidates rc
      cross join (values ('SEC_SUBMISSIONS'),('PRICE_PAIR'),('CONSENSUS')) as jt(job_type)
      on conflict(run_id,ticker,job_type) do nothing
      returning job_id, ticker, job_type
    )
    select * from ins
  loop
    perform pgmq.send('fwios_decision_refresh', jsonb_build_object('job_id',r.job_id,'run_id',v_run_id,'ticker',r.ticker,'job_type',r.job_type));
    v_job_count := v_job_count + 1;
  end loop;

  update fwios.decision_refresh_runs
  set candidate_count=v_candidate_count,
      jobs_total=(select count(*) from fwios.decision_refresh_jobs where run_id=v_run_id),
      status=case when (select count(*) from fwios.decision_refresh_jobs where run_id=v_run_id) > 0 then 'QUEUED' else status end,
      updated_at=now()
  where run_id=v_run_id;

  return jsonb_build_object(
    'run_id',v_run_id,
    'created',v_created,
    'session_date',p_session_date,
    'candidate_count',v_candidate_count,
    'new_jobs_enqueued',v_job_count,
    'mode','SHADOW',
    'authoritative_write',false
  );
end $$;

create or replace function fwios.refresh_decision_refresh_run_status(p_run_id uuid)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_total integer;
  v_pass integer;
  v_blocked integer;
  v_failed integer;
  v_open integer;
  v_status text;
begin
  select count(*),
         count(*) filter(where status='PASS'),
         count(*) filter(where status='BLOCKED'),
         count(*) filter(where status='DEAD_LETTER'),
         count(*) filter(where status in ('QUEUED','RUNNING','RETRY'))
    into v_total,v_pass,v_blocked,v_failed,v_open
  from fwios.decision_refresh_jobs where run_id=p_run_id;

  v_status := case
    when v_open > 0 then 'RUNNING'
    when v_failed > 0 then 'FAILED'
    when v_blocked > 0 then 'BLOCKED'
    else 'PASS'
  end;

  update fwios.decision_refresh_runs
  set jobs_total=v_total,
      jobs_pass=v_pass,
      jobs_blocked=v_blocked,
      jobs_failed=v_failed,
      status=v_status,
      started_at=coalesce(started_at,now()),
      completed_at=case when v_open=0 then now() else null end,
      updated_at=now()
  where run_id=p_run_id;

  return jsonb_build_object('run_id',p_run_id,'status',v_status,'total',v_total,'pass',v_pass,'blocked',v_blocked,'failed',v_failed,'open',v_open);
end $$;

insert into fwios.system_state(state_key,state_value,source_system,source_ref,as_of_text,updated_at)
values(
  'auto_decision_refresh_v1',
  jsonb_build_object(
    'mode','SHADOW',
    'status','INFRA_DEPLOYING',
    'authoritative_write',false,
    'scheduler','PG_CRON',
    'queue','PGMQ',
    'worker','decision-refresh-worker-v1',
    'providers',jsonb_build_object('sec_edgar','READY','price','NOT_CONFIGURED','consensus','NOT_CONFIGURED'),
    'safety','FAIL_CLOSED'
  ),
  'SUPABASE_AUTOMATION',
  'AUTO_DECISION_REFRESH_V1',
  to_char(now() at time zone 'Asia/Bangkok','YYYY-MM-DD HH24:MI "Asia/Bangkok"'),
  now()
)
on conflict(state_key) do update set
  state_value=excluded.state_value,
  source_system=excluded.source_system,
  source_ref=excluded.source_ref,
  as_of_text=excluded.as_of_text,
  updated_at=excluded.updated_at;

select cron.schedule(
  'fwios-shadow-decision-refresh-enqueue',
  '35 21 * * 1-5',
  $$select fwios.start_decision_refresh_shadow((now() at time zone 'America/New_York')::date,'CRON');$$
);

select cron.schedule(
  'fwios-shadow-decision-refresh-worker',
  '*/5 * * * *',
  $cron$
  select net.http_post(
    url := (select decrypted_secret from vault.decrypted_secrets where name='fwios_project_url' limit 1) || '/functions/v1/decision-refresh-worker-v1',
    headers := jsonb_build_object(
      'Content-Type','application/json',
      'x-fwios-automation-token',(select decrypted_secret from vault.decrypted_secrets where name='fwios_automation_token' limit 1)
    ),
    body := jsonb_build_object('source','PG_CRON','requested_at',now()),
    timeout_milliseconds := 10000
  );
  $cron$
);