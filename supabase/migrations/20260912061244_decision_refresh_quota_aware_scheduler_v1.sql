create table if not exists fwios.decision_refresh_api_quota_policy (
  provider_group text primary key,
  daily_limit integer,
  price_budget integer not null default 0,
  validator_budget integer not null default 0,
  reserve_budget integer not null default 0,
  active boolean not null default true,
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  check (daily_limit is null or daily_limit > 0),
  check (price_budget >= 0 and validator_budget >= 0 and reserve_budget >= 0),
  check (daily_limit is null or price_budget + validator_budget + reserve_budget <= daily_limit)
);

create table if not exists fwios.decision_refresh_api_usage (
  usage_id uuid primary key default gen_random_uuid(),
  provider_group text not null,
  capability text not null,
  endpoint_class text not null,
  usage_date_et date not null,
  job_id uuid null references fwios.decision_refresh_jobs(job_id) on delete set null,
  caller text not null,
  called_at timestamptz not null default now(),
  outcome text not null default 'RESERVED',
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists idx_decision_refresh_api_usage_budget on fwios.decision_refresh_api_usage(provider_group,usage_date_et,endpoint_class,called_at);
create index if not exists idx_decision_refresh_api_usage_job on fwios.decision_refresh_api_usage(job_id) where job_id is not null;
alter table fwios.decision_refresh_api_quota_policy enable row level security;
alter table fwios.decision_refresh_api_usage enable row level security;
revoke all on fwios.decision_refresh_api_quota_policy from anon, authenticated;
revoke all on fwios.decision_refresh_api_usage from anon, authenticated;

delete from fwios.decision_refresh_api_quota_policy where provider_group='ALPHA_VANTAGE_SHARED';
insert into fwios.decision_refresh_api_quota_policy(provider_group,daily_limit,price_budget,validator_budget,reserve_budget,active,config)
values('ALPHA_VANTAGE_SHARED',25,20,2,3,true,jsonb_build_object(
  'source','Alpha Vantage official support','free_daily_limit',25,
  'price_budget_reason','20 daily price crosschecks','validator_budget_reason','price + consensus validation',
  'reserve_reason','manual/retry emergency reserve'));

create or replace function fwios.reserve_decision_refresh_api_call_v1(
  p_provider_group text,p_capability text,p_endpoint_class text,p_caller text,
  p_job_id uuid default null,p_metadata jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path='pg_catalog','fwios' as $$
declare
  q fwios.decision_refresh_api_quota_policy%rowtype;
  d date := (now() at time zone 'America/New_York')::date;
  total_used integer := 0; class_used integer := 0; class_limit integer := null; id uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended('fwios-api-quota:'||p_provider_group||':'||d::text,0));
  select * into q from fwios.decision_refresh_api_quota_policy where provider_group=p_provider_group and active=true;
  if not found or q.daily_limit is null then
    insert into fwios.decision_refresh_api_usage(provider_group,capability,endpoint_class,usage_date_et,job_id,caller,metadata)
    values(p_provider_group,p_capability,p_endpoint_class,d,p_job_id,p_caller,coalesce(p_metadata,'{}'::jsonb)) returning usage_id into id;
    return jsonb_build_object('allowed',true,'usage_id',id,'usage_date_et',d,'policy','UNLIMITED_OR_UNCONFIGURED');
  end if;
  select count(*) into total_used from fwios.decision_refresh_api_usage where provider_group=p_provider_group and usage_date_et=d;
  if p_endpoint_class='PRICE' then class_limit:=q.price_budget;
  elsif p_endpoint_class='VALIDATOR' then class_limit:=q.validator_budget;
  else class_limit:=q.reserve_budget;
  end if;
  select count(*) into class_used from fwios.decision_refresh_api_usage where provider_group=p_provider_group and usage_date_et=d and endpoint_class=p_endpoint_class;
  if total_used >= q.daily_limit or class_used >= class_limit then
    return jsonb_build_object('allowed',false,'usage_date_et',d,'daily_limit',q.daily_limit,'total_used',total_used,
      'endpoint_class',p_endpoint_class,'class_limit',class_limit,'class_used',class_used,'reason','API_QUOTA_BUDGET_EXHAUSTED');
  end if;
  insert into fwios.decision_refresh_api_usage(provider_group,capability,endpoint_class,usage_date_et,job_id,caller,metadata)
  values(p_provider_group,p_capability,p_endpoint_class,d,p_job_id,p_caller,coalesce(p_metadata,'{}'::jsonb)) returning usage_id into id;
  return jsonb_build_object('allowed',true,'usage_id',id,'usage_date_et',d,'daily_limit',q.daily_limit,'total_used_after',total_used+1,
    'endpoint_class',p_endpoint_class,'class_limit',class_limit,'class_used_after',class_used+1);
end $$;
revoke all on function fwios.reserve_decision_refresh_api_call_v1(text,text,text,text,uuid,jsonb) from public, anon, authenticated;

create or replace function fwios.decision_refresh_target_session_v1(p_now timestamptz default now()) returns date
language sql stable set search_path='pg_catalog','fwios' as $$
  with x as (select (p_now at time zone 'America/New_York')::date d)
  select case extract(isodow from d)::int when 1 then d-3 when 7 then d-2 else d-1 end from x
$$;
revoke all on function fwios.decision_refresh_target_session_v1(timestamptz) from public, anon, authenticated;
