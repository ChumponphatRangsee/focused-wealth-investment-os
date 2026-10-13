-- FWIOS PR 3 / Part A: additive, reuse-first shared usage and atomic reservation.
-- Requires PR 2 migration; staging FIRST. No automatic consumer cutover.
-- Both existing usage ledgers remain authoritative historical records.
-- No new table and no portfolio/transaction state mutation.

do $$
declare v_table text;
begin
  foreach v_table in array array[
    'fwios.decision_refresh_api_usage',
    'fwios.market_daily_close_api_usage'
  ] loop
    execute format('alter table %s add column if not exists quota_provider_group text',v_table);
    execute format('alter table %s add column if not exists quota_provider_key text',v_table);
    execute format('alter table %s add column if not exists quota_plan_id text',v_table);
    execute format('alter table %s add column if not exists quota_endpoint text',v_table);
    execute format('alter table %s add column if not exists quota_request_key text',v_table);
    execute format('alter table %s add column if not exists quota_request_signature text',v_table);
    execute format('alter table %s add column if not exists quota_credit_reserved numeric(18,6)',v_table);
    execute format('alter table %s add column if not exists quota_credit_actual numeric(18,6)',v_table);
    execute format('alter table %s add column if not exists quota_expires_at timestamptz',v_table);
    execute format('alter table %s add column if not exists quota_dispatched_at timestamptz',v_table);
    execute format('alter table %s add column if not exists quota_finalized_at timestamptz',v_table);
    execute format('alter table %s add column if not exists quota_retry_after timestamptz',v_table);
    execute format('alter table %s add column if not exists quota_http_status integer',v_table);
    execute format('alter table %s add column if not exists quota_error_reason text',v_table);
  end loop;
end $$;

create unique index if not exists decision_api_usage_request_key_v1_uidx
  on fwios.decision_refresh_api_usage(provider_group,quota_request_key)
  where quota_request_key is not null;

create unique index if not exists daily_api_usage_request_key_v1_uidx
  on fwios.market_daily_close_api_usage(provider_key,quota_request_key)
  where quota_request_key is not null;

-- A single logical ledger, backed by the existing two physical tables.
-- Conservative legacy accounting: each unclassified legacy row costs >=1 credit.
-- EXPIRED and unknown-outcome rows retain charges, never silently refund.
create or replace view fwios.v_api_usage_unified_v1
with (security_invoker = true)
as
select
  'DECISION_REFRESH'::text as source_ledger,
  u.usage_id,
  u.provider_group,
  coalesce(u.quota_provider_key,u.provider_group) as provider_key,
  u.quota_plan_id as plan_id,
  u.capability,
  coalesce(u.quota_endpoint,u.endpoint_class) as endpoint,
  u.endpoint_class,
  u.caller,
  u.job_id as run_job_id,
  null::text as instrument,
  u.quota_request_key as request_key,
  u.quota_request_signature as request_signature,
  u.called_at,
  u.outcome,
  case when u.outcome='RELEASED' and u.quota_finalized_at is not null
    then 0::numeric
    else greatest(coalesce(u.quota_credit_reserved,1::numeric),
                  coalesce(u.quota_credit_actual,0::numeric)) end as spent_credits,
  u.quota_credit_reserved as reserved_credits,
  u.quota_credit_actual as actual_credits,
  u.quota_expires_at as expires_at,
  u.quota_dispatched_at as dispatched_at,
  u.quota_finalized_at as finalized_at,
  u.quota_retry_after as retry_after,
  u.quota_http_status as http_status,
  u.quota_error_reason as error_reason,
  u.metadata
from fwios.decision_refresh_api_usage u
union all
select
  'MARKET_DAILY_CLOSE'::text,
  u.usage_id,
  coalesce(u.quota_provider_group,u.provider_key),
  coalesce(u.quota_provider_key,u.provider_key),
  u.quota_plan_id,
  coalesce(u.metadata->>'capability','DAILY_CLOSE'),
  coalesce(u.quota_endpoint,'TIME_SERIES'),
  coalesce(u.metadata->>'endpoint_class','DAILY_CLOSE'),
  u.caller,
  null::uuid,
  u.ticker,
  u.quota_request_key,
  u.quota_request_signature,
  u.called_at,
  u.outcome,
  case when u.outcome='RELEASED' and u.quota_finalized_at is not null
    then 0::numeric
    else greatest(coalesce(u.quota_credit_reserved,1::numeric),
                  coalesce(u.quota_credit_actual,0::numeric)) end,
  u.quota_credit_reserved,
  u.quota_credit_actual,
  u.quota_expires_at,
  u.quota_dispatched_at,
  u.quota_finalized_at,
  u.quota_retry_after,
  u.quota_http_status,
  u.quota_error_reason,
  u.metadata
from fwios.market_daily_close_api_usage u;

revoke all on fwios.v_api_usage_unified_v1 from public,anon,authenticated;
grant select on fwios.v_api_usage_unified_v1 to service_role;

-- One account-scoped advisory lock serializes all new reservation attempts.
-- PR 3 Part B migrates legacy v1 reservers to THE SAME lock key.
create or replace function fwios.reserve_api_quota_unified_v1(
  p_provider_key text,
  p_capability text,
  p_endpoint text,
  p_caller text,
  p_request_key text,
  p_request_signature text,
  p_priority text default 'P2',
  p_job_id uuid default null,
  p_instrument text default null,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql volatile security invoker
set search_path to 'pg_catalog','fwios'
as $fn$
declare
  v_provider text := upper(trim(coalesce(p_provider_key,'')));
  v_cap text := upper(trim(coalesce(p_capability,'')));
  v_end text := upper(trim(coalesce(p_endpoint,'')));
  v_priority text := upper(trim(coalesce(p_priority,'')));
  v_policy jsonb;
  v_group text;
  v_plan text;
  v_rule jsonb;
  v_registry_limits jsonb;
  v_zone text;
  v_now timestamptz;
  v_day_start timestamptz;
  v_day_end timestamptz;
  v_min_limit numeric;
  v_hour_limit numeric;
  v_day_limit numeric;
  v_con_limit integer;
  v_class_limit numeric;
  v_class text;
  v_cost numeric;
  v_reserved_protected numeric;
  v_used_min numeric := 0;
  v_used_hour numeric := 0;
  v_used_day numeric := 0;
  v_used_class numeric := 0;
  v_inflight bigint := 0;
  v_cooldown timestamptz;
  v_lease_seconds integer;
  v_expires timestamptz;
  v_previous uuid;
  v_previous_outcome text;
  v_id uuid;
  v_metadata jsonb;
begin
  if coalesce(length(trim(p_caller)),0)<3
     or coalesce(length(trim(p_request_key)),0)<8
     or length(p_request_key)>180
     or coalesce(length(trim(p_request_signature)),0)<8
     or length(p_request_signature)>256
     or v_priority not in ('P0','P1','P2','P3','P4')
     or v_provider='' or v_cap='' or v_end=''
     or p_metadata is null or jsonb_typeof(p_metadata)<>'object' then
    return jsonb_build_object('allowed',false,'reason','INVALID_RESERVATION_ARGUMENTS');
  end if;

  v_policy := fwios.resolve_provider_quota_policy_v1(v_provider,v_cap,v_end);
  if coalesce((v_policy->>'policy_ready')::boolean,false) is distinct from true then
    return jsonb_build_object('allowed',false,'reason',
      coalesce(v_policy->>'reason','POLICY_UNAVAILABLE'),'provider_key',v_provider);
  end if;

  v_group := v_policy->>'provider_group';
  v_plan := v_policy->>'plan_id';
  -- PR 2 resolver exposes legacy operational ceilings. The original
  -- registry config owns missing provider-specific minute/hour/concurrency.
  select r.config->'unified_quota_v1'->'limits'
    into v_registry_limits
  from fwios.decision_refresh_provider_registry r
  where r.provider_key=v_provider;
  v_min_limit := coalesce(
    (v_policy->'limits'->>'minute')::numeric,
    (v_registry_limits->>'minute')::numeric);
  v_hour_limit := coalesce(
    (v_policy->'limits'->>'hour')::numeric,
    (v_registry_limits->>'hour')::numeric);
  v_day_limit := coalesce(
    (v_policy->'limits'->>'day')::numeric,
    (v_registry_limits->>'day')::numeric);
  v_con_limit := coalesce(
    (v_policy->'limits'->>'concurrent')::integer,
    (v_registry_limits->>'concurrent')::integer);
  v_class_limit := (v_policy->'limits'->>'endpoint_class')::numeric;
  v_class := case
    when v_provider='ALPHA_VANTAGE_PRICE' then 'PRICE'
    when v_provider='ALPHA_VANTAGE_CONSENSUS' then 'RESERVE'
    else null end;
  -- Existing decision worker bills EARNINGS_ESTIMATES through RESERVE,
  -- not VALIDATOR. Reuse the operational RESERVE bucket, not the stale
  -- PR 2 descriptor hint for consensus.
  if v_provider='ALPHA_VANTAGE_CONSENSUS' then
    select reserve_budget::numeric into v_class_limit
    from fwios.decision_refresh_api_quota_policy
    where provider_group=v_group and active=true;
  end if;
  v_cost := (v_policy->>'endpoint_credit_cost')::numeric;

  -- The reserved amount for P0 must be *explicit*. Old Twelve Data
  -- headroom outside the 700-day worker ceiling is NOT a new P0 allocation.
  select
    case when jsonb_typeof(r.config->'unified_quota_v1'->'protected_daily_credits')='number'
         then (r.config->'unified_quota_v1'->>'protected_daily_credits')::numeric
         else null end,
    case when jsonb_typeof(r.config->'unified_quota_v1'->'lease_seconds')='number'
         then (r.config->'unified_quota_v1'->>'lease_seconds')::int
         else 120 end
  into v_reserved_protected,v_lease_seconds
  from fwios.decision_refresh_provider_registry r where r.provider_key=v_provider;

  v_rule := v_policy->'vendor_reset_rule';
  v_zone := v_rule->>'timezone';
  if v_group is null or v_group='' or v_plan is null or v_plan=''
     or v_day_limit is null or v_day_limit<=0
     or (v_min_limit is not null and v_min_limit<=0)
     or (v_hour_limit is not null and v_hour_limit<=0)
     or (v_con_limit is not null and v_con_limit<=0)
     or v_cost is null or v_cost<=0
     or v_lease_seconds not between 10 and 900
     or v_rule->>'type' <> 'CALENDAR_DAY'
     or v_zone is null
     or not exists(select 1 from pg_timezone_names where name=v_zone)
     or v_min_limit is null
     or (v_hour_limit is null and
           (select config->'unified_quota_v1'->>'hourly_limit_status'
              from fwios.decision_refresh_provider_registry
              where provider_key=v_provider) <> 'NOT_APPLICABLE')
     or (v_con_limit is null and
           (select config->'unified_quota_v1'->>'concurrency_limit_status'
              from fwios.decision_refresh_provider_registry
              where provider_key=v_provider) <> 'NOT_APPLICABLE')
     or (v_reserved_protected is null and v_priority<>'P0')
     or (v_reserved_protected is not null and
            (v_reserved_protected<0 or v_reserved_protected>=v_day_limit)) then
    return jsonb_build_object('allowed',false,'reason','INCOMPLETE_ATOMIC_QUOTA_POLICY');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('fwios-api-account:'||v_group,0));
  v_now := clock_timestamp();
  v_day_start := ((v_now at time zone v_zone)::date::timestamp at time zone v_zone);
  v_day_end := (((v_now at time zone v_zone)::date+1)::timestamp at time zone v_zone);

  -- A retry of the SAME request key must NEVER grant another external call.
  if v_provider='TWELVE_DATA' then
    select usage_id,outcome into v_previous,v_previous_outcome
    from fwios.market_daily_close_api_usage
    where provider_key=v_provider and quota_request_key=p_request_key;
  else
    select usage_id,outcome into v_previous,v_previous_outcome
    from fwios.decision_refresh_api_usage
    where provider_group=v_group and quota_request_key=p_request_key;
  end if;

  if v_previous is not null then
    return jsonb_build_object('allowed',false,'reason','IDEMPOTENT_REPLAY_NO_NEW_CALL',
      'usage_id',v_previous,'outcome',v_previous_outcome);
  end if;

  select
    coalesce(sum(spent_credits) filter
      (where called_at > v_now - interval '1 minute'),0),
    coalesce(sum(spent_credits) filter
      (where called_at > v_now - interval '1 hour'),0),
    coalesce(sum(spent_credits) filter
      (where called_at >= v_day_start and called_at < v_day_end),0),
    coalesce(sum(spent_credits) filter
      (where called_at >= v_day_start and called_at < v_day_end
         and endpoint_class=v_class),0),
    count(*) filter
      (where outcome in ('RESERVED','DISPATCHED')
         and coalesce(expires_at,called_at + interval '2 minutes') > v_now),
    max(retry_after) filter (where retry_after > v_now)
  into v_used_min,v_used_hour,v_used_day,v_used_class,v_inflight,v_cooldown
  from fwios.v_api_usage_unified_v1
  where provider_group=v_group
    and called_at>=least(v_day_start,v_now-interval '1 hour',v_now-interval '2 days');

  if v_cooldown is not null then
    return jsonb_build_object('allowed',false,'reason','PROVIDER_RETRY_AFTER',
      'retry_after',v_cooldown);
  end if;
  if v_min_limit is not null and v_used_min+v_cost>v_min_limit then
    return jsonb_build_object('allowed',false,'reason','MINUTE_CREDITS_EXHAUSTED',
      'used',v_used_min,'limit',v_min_limit);
  end if;
  if v_hour_limit is not null and v_used_hour+v_cost>v_hour_limit then
    return jsonb_build_object('allowed',false,'reason','HOUR_CREDITS_EXHAUSTED',
      'used',v_used_hour,'limit',v_hour_limit);
  end if;
  if v_used_day+v_cost>v_day_limit then
    return jsonb_build_object('allowed',false,'reason','DAY_CREDITS_EXHAUSTED',
      'used',v_used_day,'limit',v_day_limit);
  end if;
  if v_class_limit is not null and v_used_class+v_cost>v_class_limit then
    return jsonb_build_object('allowed',false,'reason','CAPABILITY_CREDITS_EXHAUSTED');
  end if;
  if v_con_limit is not null and v_inflight>=v_con_limit then
    return jsonb_build_object('allowed',false,'reason','CONCURRENCY_EXHAUSTED');
  end if;
  if v_priority<>'P0'
     and v_used_day+v_cost > v_day_limit-v_reserved_protected then
    return jsonb_build_object('allowed',false,'reason','P0_CAPACITY_PROTECTED');
  end if;

  v_expires:=v_now+make_interval(secs=>v_lease_seconds);
  v_metadata:=p_metadata || jsonb_build_object(
    'quota_version','UNIFIED_V1','priority',v_priority,
    'provider_called',false,'instrument',p_instrument,
    'request_signature',p_request_signature);

  if v_provider='TWELVE_DATA' then
    insert into fwios.market_daily_close_api_usage(
      provider_key,usage_date_utc,ticker,caller,called_at,outcome,metadata,
      quota_provider_group,quota_provider_key,quota_plan_id,quota_endpoint,
      quota_request_key,quota_request_signature,quota_credit_reserved,quota_expires_at
    ) values(
      v_provider,(v_now at time zone 'UTC')::date,p_instrument,p_caller,v_now,'RESERVED',
      v_metadata,v_group,v_provider,v_plan,v_end,p_request_key,p_request_signature,v_cost,v_expires
    ) returning usage_id into v_id;
  else
    insert into fwios.decision_refresh_api_usage(
      provider_group,capability,endpoint_class,usage_date_et,job_id,caller,called_at,outcome,metadata,
      quota_provider_group,quota_provider_key,quota_plan_id,quota_endpoint,
      quota_request_key,quota_request_signature,quota_credit_reserved,quota_expires_at
    ) values(
      v_group,v_cap,coalesce(v_class,v_end),
      (v_now at time zone 'America/New_York')::date,p_job_id,p_caller,v_now,'RESERVED',v_metadata,
      v_group,v_provider,v_plan,v_end,p_request_key,p_request_signature,v_cost,v_expires
    ) returning usage_id into v_id;
  end if;

  return jsonb_build_object('allowed',true,'usage_id',v_id,'provider_group',v_group,
    'provider_key',v_provider,'plan_id',v_plan,'endpoint',v_end,
    'credit_reserved',v_cost,'lease_expires_at',v_expires,
    'remaining_day_after',v_day_limit-v_used_day-v_cost,
    'priority',v_priority,'status','RESERVED');
end $fn$;

-- The trusted caller MUST mark DISPATCHED immediately before external network I/O.
-- A repeated mark or expired lease must never authorize another provider call.
create or replace function fwios.mark_api_quota_dispatched_v1(
  p_usage_id uuid,
  p_timeout_seconds integer default 30
) returns jsonb
language plpgsql volatile security invoker
set search_path to 'pg_catalog','fwios'
as $fn$
declare
  v_ledger text;
  v_group text;
  v_request_key text;
  v_current text;
  v_expiry timestamptz;
  v_now timestamptz;
begin
  if p_usage_id is null or p_timeout_seconds not between 5 and 300 then
    return jsonb_build_object('allowed',false,'reason','INVALID_DISPATCH_ARGUMENTS');
  end if;

  select ledger,provider_group,request_key into v_ledger,v_group,v_request_key
  from (
    select 'DECISION_REFRESH'::text ledger,provider_group,quota_request_key request_key
      from fwios.decision_refresh_api_usage where usage_id=p_usage_id
    union all
    select 'MARKET_DAILY_CLOSE',coalesce(quota_provider_group,provider_key),
      quota_request_key from fwios.market_daily_close_api_usage where usage_id=p_usage_id
  ) a;

  if v_request_key is null then
    return jsonb_build_object('allowed',false,'reason','UNMANAGED_OR_UNKNOWN_RESERVATION');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('fwios-api-account:'||v_group,0));
  if v_ledger='DECISION_REFRESH' then
    select outcome,quota_expires_at into v_current,v_expiry
    from fwios.decision_refresh_api_usage where usage_id=p_usage_id for update;
  else
    select outcome,quota_expires_at into v_current,v_expiry
    from fwios.market_daily_close_api_usage where usage_id=p_usage_id for update;
  end if;

  v_now := clock_timestamp();
  if v_current <> 'RESERVED' then
    return jsonb_build_object('allowed',false,'reason','ALREADY_DISPATCHED_OR_FINALIZED',
      'outcome',v_current);
  end if;
  if v_expiry is null or v_expiry<=v_now then
    return jsonb_build_object('allowed',false,'reason','RESERVATION_LEASE_EXPIRED');
  end if;

  if v_ledger='DECISION_REFRESH' then
    update fwios.decision_refresh_api_usage
    set outcome='DISPATCHED',quota_dispatched_at=v_now,
      quota_expires_at=greatest(quota_expires_at,
        v_now+make_interval(secs=>p_timeout_seconds+30)),
      metadata=metadata||'{"provider_called":true}'::jsonb
    where usage_id=p_usage_id and outcome='RESERVED';
  else
    update fwios.market_daily_close_api_usage
    set outcome='DISPATCHED',quota_dispatched_at=v_now,
      quota_expires_at=greatest(quota_expires_at,
        v_now+make_interval(secs=>p_timeout_seconds+30)),
      metadata=metadata||'{"provider_called":true}'::jsonb
    where usage_id=p_usage_id and outcome='RESERVED';
  end if;

  return jsonb_build_object('allowed',true,'usage_id',p_usage_id,
    'status','DISPATCHED','timeout_seconds',p_timeout_seconds);
end $fn$;

-- Success/error finalization is idempotent. No inferred refunds:
-- only an explicit *pre-dispatch* RELEASED can set spend=0.
create or replace function fwios.finalize_api_quota_usage_v1(
  p_usage_id uuid,
  p_outcome text,
  p_credit_actual numeric default null,
  p_http_status integer default null,
  p_retry_after timestamptz default null,
  p_error_reason text default null,
  p_provider_called boolean default true
) returns jsonb
language plpgsql volatile security invoker
set search_path to 'pg_catalog','fwios'
as $fn$
declare
  v_ledger text;
  v_group text;
  v_current text;
  v_credit numeric;
  v_request_key text;
  v_dispatched timestamptz;
  v_outcome text := upper(trim(coalesce(p_outcome,'')));
  v_actual numeric;
begin
  if p_usage_id is null or v_outcome not in
     ('SUCCESS','BILLABLE_FAILURE','PROVIDER_ERROR','RELEASED','EXPIRED')
     or (v_outcome='RELEASED' and p_provider_called)
     or (v_outcome in ('SUCCESS','BILLABLE_FAILURE') and not p_provider_called)
     or (p_credit_actual is not null and p_credit_actual<0)
     or (p_http_status is not null and (p_http_status<100 or p_http_status>599))
     or length(coalesce(p_error_reason,''))>500 then
    return jsonb_build_object('ok',false,'reason','INVALID_FINALIZE_ARGUMENTS');
  end if;

  select ledger,provider_group,outcome,credit,request_key
    into v_ledger,v_group,v_current,v_credit,v_request_key
  from (
    select 'DECISION_REFRESH'::text ledger,provider_group,outcome,
      quota_credit_reserved credit,quota_request_key request_key
    from fwios.decision_refresh_api_usage where usage_id=p_usage_id
    union all
    select 'MARKET_DAILY_CLOSE',coalesce(quota_provider_group,provider_key),
      outcome,quota_credit_reserved,quota_request_key
    from fwios.market_daily_close_api_usage where usage_id=p_usage_id
  ) r;

  if v_request_key is null then
    return jsonb_build_object('ok',false,'reason','UNMANAGED_OR_UNKNOWN_RESERVATION');
  end if;

  perform pg_advisory_xact_lock(hashtextextended('fwios-api-account:'||v_group,0));

  -- Immutable terminal records protect against double-spend and late retries.
  if v_ledger='DECISION_REFRESH' then
    select outcome,quota_credit_reserved,quota_dispatched_at
      into v_current,v_credit,v_dispatched
    from fwios.decision_refresh_api_usage where usage_id=p_usage_id for update;
  else
    select outcome,quota_credit_reserved,quota_dispatched_at
      into v_current,v_credit,v_dispatched
    from fwios.market_daily_close_api_usage where usage_id=p_usage_id for update;
  end if;
  if v_current not in ('RESERVED','DISPATCHED') then
    return jsonb_build_object('ok',true,'changed',false,'usage_id',p_usage_id,
      'outcome',v_current,'reason','ALREADY_FINALIZED');
  end if;
  if (v_outcome='RELEASED' and (v_current<>'RESERVED' or v_dispatched is not null))
     or (v_outcome in ('SUCCESS','BILLABLE_FAILURE','PROVIDER_ERROR')
           and (v_current<>'DISPATCHED' or v_dispatched is null)) then
    return jsonb_build_object('ok',false,'changed',false,'usage_id',p_usage_id,
      'reason','INVALID_QUOTA_STATE_TRANSITION');
  end if;

  v_actual := case when v_outcome='RELEASED' then 0
                   else greatest(coalesce(p_credit_actual,v_credit),v_credit) end;

  if v_ledger='DECISION_REFRESH' then
    update fwios.decision_refresh_api_usage
    set outcome=v_outcome,quota_credit_actual=v_actual,
      quota_finalized_at=clock_timestamp(),
      quota_http_status=p_http_status,quota_retry_after=p_retry_after,
      quota_error_reason=p_error_reason,
      metadata=metadata || jsonb_build_object('provider_called',p_provider_called)
    where usage_id=p_usage_id;
  else
    update fwios.market_daily_close_api_usage
    set outcome=v_outcome,quota_credit_actual=v_actual,
      quota_finalized_at=clock_timestamp(),
      quota_http_status=p_http_status,quota_retry_after=p_retry_after,
      quota_error_reason=p_error_reason,
      metadata=metadata || jsonb_build_object('provider_called',p_provider_called)
    where usage_id=p_usage_id;
  end if;

  return jsonb_build_object('ok',true,'changed',true,'usage_id',p_usage_id,
    'outcome',v_outcome,'charged_credits',v_actual,
    'credit_overrun_reportable',v_actual>v_credit);
end $fn$;

revoke all on function fwios.reserve_api_quota_unified_v1(
  text,text,text,text,text,text,text,uuid,text,jsonb) from public,anon,authenticated;
revoke all on function fwios.mark_api_quota_dispatched_v1(uuid,integer)
  from public,anon,authenticated;
grant execute on function fwios.mark_api_quota_dispatched_v1(uuid,integer)
  to service_role;
revoke all on function fwios.finalize_api_quota_usage_v1(
  uuid,text,numeric,integer,timestamptz,text,boolean) from public,anon,authenticated;
grant execute on function fwios.reserve_api_quota_unified_v1(
  text,text,text,text,text,text,text,uuid,text,jsonb) to service_role;
grant execute on function fwios.finalize_api_quota_usage_v1(
  uuid,text,numeric,integer,timestamptz,text,boolean) to service_role;

-- Do not grant tables/functions to frontend users.
