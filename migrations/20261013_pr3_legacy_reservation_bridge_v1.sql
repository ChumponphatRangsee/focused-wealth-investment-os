-- FWIOS PR 3 / Part B: legacy reservation bridge.
-- DEPLOYMENT GATE: stage and verify all active v1 callers before production.
-- Preserves both v1 signatures and response shapes; replaces incompatible locks
-- with account-global lock to prevent cross-ledger daily overspend.
-- Alpha unconfigured provider now DENIES instead of "UNLIMITED_OR_UNCONFIGURED".
-- Legacy v1 routes do not enforce *new* endpoint-credit prices/hour/concurrency;
-- full system cutover requires migrating callers to unified_v1.

create or replace function fwios.reserve_decision_refresh_api_call_v1(
  p_provider_group text,
  p_capability text,
  p_endpoint_class text,
  p_caller text,
  p_job_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql volatile
security definer
set search_path to 'pg_catalog','fwios'
as $fn$
declare
  q fwios.decision_refresh_api_quota_policy%rowtype;
  d date;
  v_start timestamptz;
  v_end timestamptz;
  v_now timestamptz;
  total_used numeric := 0;
  class_used numeric := 0;
  class_limit integer := null;
  id uuid;
begin
  -- This v1 API is only approved for the INVENTORIED Alpha group.
  if p_provider_group is distinct from 'ALPHA_VANTAGE_SHARED'
     or p_endpoint_class not in ('PRICE','VALIDATOR','RESERVE')
     or coalesce(length(p_caller),0)<3 then
    return jsonb_build_object('allowed',false,'reason','LEGACY_POLICY_NOT_CONFIGURED');
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('fwios-api-account:'||p_provider_group,0)
  );

  select * into q from fwios.decision_refresh_api_quota_policy
  where provider_group=p_provider_group and active=true;
  if not found or q.daily_limit is null or q.daily_limit<=0 then
    return jsonb_build_object('allowed',false,'reason','POLICY_NOT_ACTIVE');
  end if;

  v_now := clock_timestamp();
  d := (v_now at time zone 'America/New_York')::date;
  v_start := (d::timestamp at time zone 'America/New_York');
  v_end := ((d+1)::timestamp at time zone 'America/New_York');

  class_limit := case p_endpoint_class
    when 'PRICE' then q.price_budget
    when 'VALIDATOR' then q.validator_budget
    when 'RESERVE' then q.reserve_budget
    else null end;

  select
    coalesce(sum(spent_credits),0),
    coalesce(sum(spent_credits) filter
      (where endpoint_class=p_endpoint_class),0)
  into total_used,class_used
  from fwios.v_api_usage_unified_v1
  where provider_group=p_provider_group
    and called_at>=v_start and called_at<v_end;

  if total_used+1>q.daily_limit or class_limit is null
     or class_used+1>class_limit then
    return jsonb_build_object('allowed',false,
      'usage_date_et',d,'daily_limit',q.daily_limit,'total_used',total_used,
      'endpoint_class',p_endpoint_class,'class_limit',class_limit,
      'class_used',class_used,'reason','API_QUOTA_BUDGET_EXHAUSTED');
  end if;

  insert into fwios.decision_refresh_api_usage(
    provider_group,capability,endpoint_class,usage_date_et,job_id,caller,
    called_at,metadata
  ) values (
    p_provider_group,p_capability,p_endpoint_class,d,p_job_id,p_caller,
    v_now,coalesce(p_metadata,'{}'::jsonb)
  ) returning usage_id into id;

  return jsonb_build_object('allowed',true,'usage_id',id,
    'usage_date_et',d,'daily_limit',q.daily_limit,
    'total_used_after',total_used+1,'endpoint_class',p_endpoint_class,
    'class_limit',class_limit,'class_used_after',class_used+1);
end $fn$;

-- SECURITY DEFINER v1 is a legacy privileged boundary. Do not let
-- anon/authenticated/PUBLIC call it. Known worker uses privileged DB access.
revoke all on function fwios.reserve_decision_refresh_api_call_v1(
  text,text,text,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function fwios.reserve_decision_refresh_api_call_v1(
  text,text,text,text,uuid,jsonb) to service_role;

create or replace function fwios.reserve_market_daily_close_api_call_v1(
  p_provider_key text,p_ticker text,p_caller text,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql volatile
security invoker
set search_path to 'pg_catalog','fwios'
as $fn$
declare
  v_per_minute int;
  v_daily int;
  v_minute_used numeric;
  v_daily_used numeric;
  v_usage_id uuid;
  v_now timestamptz;
  v_day date;
  v_day_start timestamptz;
  v_day_end timestamptz;
begin
  if p_provider_key is distinct from 'TWELVE_DATA'
     or coalesce(length(p_caller),0)<3 then
    return jsonb_build_object('allowed',false,'reason','LEGACY_POLICY_NOT_CONFIGURED');
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('fwios-api-account:'||p_provider_key,0)
  );

  select per_minute_budget,daily_budget
  into v_per_minute,v_daily
  from fwios.market_daily_close_policy
  where provider_key=p_provider_key and active=true;

  if v_per_minute is null or v_daily is null then
    return jsonb_build_object('allowed',false,'reason','POLICY_NOT_ACTIVE');
  end if;

  v_now := clock_timestamp();
  v_day := (v_now at time zone 'UTC')::date;
  v_day_start := (v_day::timestamp at time zone 'UTC');
  v_day_end := ((v_day+1)::timestamp at time zone 'UTC');

  select
    coalesce(sum(spent_credits) filter
      (where called_at > v_now-interval '1 minute'),0),
    coalesce(sum(spent_credits) filter
      (where called_at>=v_day_start and called_at<v_day_end),0)
  into v_minute_used,v_daily_used
  from fwios.v_api_usage_unified_v1
  where provider_group=p_provider_key
    and called_at>=least(v_day_start,v_now-interval '1 minute');

  if v_minute_used+1>v_per_minute then
    return jsonb_build_object('allowed',false,
      'reason','PER_MINUTE_BUDGET_EXHAUSTED','used',v_minute_used,'limit',v_per_minute);
  end if;

  if v_daily_used+1>v_daily then
    return jsonb_build_object('allowed',false,
      'reason','DAILY_BUDGET_EXHAUSTED','used',v_daily_used,'limit',v_daily);
  end if;

  insert into fwios.market_daily_close_api_usage(
    provider_key,usage_date_utc,ticker,caller,called_at,outcome,metadata
  ) values (
    p_provider_key,v_day,p_ticker,p_caller,v_now,'RESERVED',
    coalesce(p_metadata,'{}'::jsonb)
  ) returning usage_id into v_usage_id;

  return jsonb_build_object('allowed',true,'usage_id',v_usage_id,
    'minute_used_after',v_minute_used+1,'minute_limit',v_per_minute,
    'daily_used_after',v_daily_used+1,'daily_limit',v_daily);
end $fn$;

revoke all on function fwios.reserve_market_daily_close_api_call_v1(
  text,text,text,jsonb) from public,anon,authenticated;
grant execute on function fwios.reserve_market_daily_close_api_call_v1(
  text,text,text,jsonb) to service_role;

-- Explicit server permissions for security-invoker resolver, ledger view and
-- unified functions. No anon/authenticated exposure.
grant usage on schema fwios to service_role;
grant select on fwios.decision_refresh_provider_registry,
  fwios.decision_refresh_api_quota_policy,
  fwios.market_daily_close_policy to service_role;
grant select,insert,update on fwios.decision_refresh_api_usage,
  fwios.market_daily_close_api_usage to service_role;
