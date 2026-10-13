-- PR 2 / FWIOS v3 — additive provider-policy normalization.
-- SOURCE OF TRUTH: reuse decision_refresh_provider_registry, market_daily_close_policy,
-- and decision_refresh_api_quota_policy. Do NOT create a second quota ledger.
-- PRODUCTION CUTOVER: false. PR 3 owns atomic shared reservations and usage accounting.
-- Vendor entitlements, endpoint credits, reset clocks and concurrency are NOT verified.
-- Therefore new lookup always returns dispatch_allowed=false and allowed=false.

-- Add a namespaced descriptor to the existing registry without replacing provider config.
-- Legacy numeric budgets remain ONLY in their current operational policy tables.
update fwios.decision_refresh_provider_registry
set config = jsonb_set(
  config, '{unified_quota_v1}',
  jsonb_build_object(
    'plan_id', coalesce(
      (select p.config->>'plan' from fwios.market_daily_close_policy p
       where p.provider_key='TWELVE_DATA'), 'UNVERIFIED'),
    'provider_group', 'TWELVE_DATA',
    'budget_source', 'fwios.market_daily_close_policy',
    'entitlement_status', 'UNVERIFIED',
    'endpoint_cost_status', 'UNVERIFIED',
    'vendor_reset_status', 'UNVERIFIED',
    'hourly_limit_status', 'UNVERIFIED',
    'concurrency_limit_status', 'UNVERIFIED',
    'legacy_accounting_timezone', 'UTC',
    'shared_scope', 'PROVIDER_ACCOUNT',
    'priority_reserve', 'P0_HOLDINGS',
    'warning_threshold_pct', 80,
    'critical_threshold_pct', 95,
    'on_429', 'RESPECT_RETRY_AFTER_NO_IMMEDIATE_LOOP',
    'migration_state', 'SHADOW_ONLY',
    'routes', jsonb_build_object(
      'TIME_SERIES', jsonb_build_object('capabilities',jsonb_build_array('DAILY_CLOSE')),
      'QUOTE', jsonb_build_object('capabilities',jsonb_build_array('MARKET_PRICE')),
      'EXCHANGE_RATE', jsonb_build_object('capabilities',jsonb_build_array('FX'))
    )
  ), true
), updated_at=now()
where provider_key='TWELVE_DATA'
  and not (config ? 'unified_quota_v1');

update fwios.decision_refresh_provider_registry
set config = jsonb_set(
  config, '{unified_quota_v1}',
  jsonb_build_object(
    'plan_id', 'ALPHA_VANTAGE_EXISTING_PLAN_UNVERIFIED',
    'provider_group', 'ALPHA_VANTAGE_SHARED',
    'budget_source', 'fwios.decision_refresh_api_quota_policy',
    'entitlement_status', 'UNVERIFIED',
    'endpoint_cost_status', 'UNVERIFIED',
    'vendor_reset_status', 'UNVERIFIED',
    'hourly_limit_status', 'UNVERIFIED',
    'concurrency_limit_status', 'UNVERIFIED',
    'legacy_accounting_timezone', 'America/New_York',
    'shared_scope', 'PROVIDER_ACCOUNT',
    'priority_reserve', 'P0_HOLDINGS',
    'warning_threshold_pct', 80,
    'critical_threshold_pct', 95,
    'on_429', 'RESPECT_RETRY_AFTER_NO_IMMEDIATE_LOOP',
    'migration_state', 'SHADOW_ONLY',
    'routes', case
      when provider_key='ALPHA_VANTAGE_PRICE' then
        jsonb_build_object('TIME_SERIES_DAILY',
          jsonb_build_object('capabilities',jsonb_build_array('MARKET_PRICE','DAILY_CLOSE'),
                             'legacy_class','PRICE'))
      else jsonb_build_object('EARNINGS_ESTIMATES',
          jsonb_build_object('capabilities',jsonb_build_array('ANALYST_DATA','EARNINGS'),
                             'legacy_class','VALIDATOR'))
      end
  ), true
), updated_at=now()
where provider_key in ('ALPHA_VANTAGE_PRICE','ALPHA_VANTAGE_CONSENSUS')
  and not (config ? 'unified_quota_v1');

-- These are actual observed network dependencies of portfolio-mtm-refresh-v1,
-- not newly enabled providers. Unverified endpoints MUST stay disabled.
insert into fwios.decision_refresh_provider_registry
(provider_key,provider_type,provider_name,source_tier,requires_secret,active,readiness_status,config)
values
('COINGECKO','CRYPTO_MARKET_PRICE','CoinGecko','B',false,false,'DISABLED',
 jsonb_build_object('unified_quota_v1',jsonb_build_object(
   'plan_id','UNVERIFIED','provider_group','COINGECKO','budget_source','UNCONFIGURED',
   'entitlement_status','UNVERIFIED','endpoint_cost_status','UNVERIFIED',
   'vendor_reset_status','UNVERIFIED','hourly_limit_status','UNVERIFIED',
   'concurrency_limit_status','UNVERIFIED','shared_scope','PROVIDER_ACCOUNT',
   'priority_reserve','P0_HOLDINGS','migration_state','SHADOW_ONLY',
   'routes',jsonb_build_object('SIMPLE_PRICE',jsonb_build_object(
     'capabilities',jsonb_build_array('MARKET_PRICE')))))),
('FRANKFURTER_FX','FOREIGN_EXCHANGE','Frankfurter FX','B',false,false,'DISABLED',
 jsonb_build_object('unified_quota_v1',jsonb_build_object(
   'plan_id','UNVERIFIED','provider_group','FRANKFURTER_FX','budget_source','UNCONFIGURED',
   'entitlement_status','UNVERIFIED','endpoint_cost_status','UNVERIFIED',
   'vendor_reset_status','UNVERIFIED','hourly_limit_status','UNVERIFIED',
   'concurrency_limit_status','UNVERIFIED','shared_scope','PROVIDER_ACCOUNT',
   'priority_reserve','P0_HOLDINGS','migration_state','SHADOW_ONLY',
   'routes',jsonb_build_object('LATEST',jsonb_build_object(
     'capabilities',jsonb_build_array('FX'))))))
on conflict(provider_key) do nothing;

-- This is a *read-only resolver*, NOT a quota reservation or authorization to call.
-- It never reads/writes a duplicate ledger. Existing workers remain unchanged.
create or replace function fwios.resolve_provider_quota_policy_v1(
  p_provider_key text,
  p_capability text,
  p_endpoint text
) returns jsonb
language plpgsql
stable
security invoker
set search_path to 'pg_catalog', 'fwios'
as $function$
declare
  v_key text := upper(trim(coalesce(p_provider_key,'')));
  v_cap text := upper(trim(coalesce(p_capability,'')));
  v_endpoint text := upper(trim(coalesce(p_endpoint,'')));
  v_provider fwios.decision_refresh_provider_registry%rowtype;
  v_contract jsonb;
  v_route jsonb;
  v_source text;
  v_group text;
  v_plan text;
  v_day int;
  v_min int;
  v_class int;
  v_reserve int;
  v_reason text;
  v_cost numeric;
  v_budget_active boolean := false;
begin
  if v_key='' or v_cap='' or v_endpoint='' then
    return jsonb_build_object('allowed',false,'dispatch_allowed',false,
      'policy_ready',false,'reason','INVALID_POLICY_LOOKUP');
  end if;

  select * into v_provider
  from fwios.decision_refresh_provider_registry
  where provider_key=v_key;

  if not found then
    return jsonb_build_object('allowed',false,'dispatch_allowed',false,
      'policy_ready',false,'provider_key',v_key,
      'reason','PROVIDER_NOT_REGISTERED');
  end if;

  v_contract := v_provider.config->'unified_quota_v1';
  v_route := v_contract->'routes'->v_endpoint;
  v_source := v_contract->>'budget_source';
  v_group := v_contract->>'provider_group';
  v_plan := v_contract->>'plan_id';

  if v_key='TWELVE_DATA' then
    select p.active,p.per_minute_budget,p.daily_budget,
           nullif(p.config->>'daily_reserve','')::int
      into v_budget_active,v_min,v_day,v_reserve
    from fwios.market_daily_close_policy p
    where p.provider_key=v_key;
  elsif v_key in ('ALPHA_VANTAGE_PRICE','ALPHA_VANTAGE_CONSENSUS') then
    select p.active,p.daily_limit,
      case v_route->>'legacy_class'
        when 'PRICE' then p.price_budget
        when 'VALIDATOR' then p.validator_budget
        when 'RESERVE' then p.reserve_budget
        else null end,
      p.reserve_budget
    into v_budget_active,v_day,v_class,v_reserve
    from fwios.decision_refresh_api_quota_policy p
    where p.provider_group='ALPHA_VANTAGE_SHARED';
  end if;

  v_reason := case
    when not v_provider.active then 'PROVIDER_DISABLED'
    when v_provider.readiness_status <> 'READY' then 'PROVIDER_NOT_READY'
    when v_contract is null then 'POLICY_NOT_CONFIGURED'
    when v_route is null then 'ENDPOINT_NOT_CONFIGURED'
    when not coalesce((v_route->'capabilities') ? v_cap,false) then 'CAPABILITY_NOT_CONFIGURED'
    when v_source not in ('fwios.market_daily_close_policy',
                          'fwios.decision_refresh_api_quota_policy')
      or v_source is null then 'BUDGET_SOURCE_NOT_CONFIGURED'
    when not v_budget_active then 'BUDGET_POLICY_NOT_ACTIVE'
    when v_day is null or v_day<=0 then 'DAILY_BUDGET_NOT_CONFIGURED'
    when v_source='fwios.market_daily_close_policy' and
         (v_min is null or v_min<=0) then 'MINUTE_BUDGET_NOT_CONFIGURED'
    when v_source='fwios.decision_refresh_api_quota_policy' and
         (v_class is null or v_class<=0) then 'CAPABILITY_BUDGET_NOT_CONFIGURED'
    when coalesce(v_contract->>'entitlement_status','')<>'VERIFIED'
      then 'VENDOR_ENTITLEMENT_UNVERIFIED'
    when coalesce(v_contract->>'endpoint_cost_status','')<>'VERIFIED'
      then 'ENDPOINT_COST_UNVERIFIED'
    when coalesce(v_contract->>'vendor_reset_status','')<>'VERIFIED'
      then 'VENDOR_RESET_UNVERIFIED'
    when coalesce(v_contract->>'hourly_limit_status','') not in ('VERIFIED','NOT_APPLICABLE')
      then 'HOURLY_LIMIT_UNVERIFIED'
    when coalesce(v_contract->>'concurrency_limit_status','') not in ('VERIFIED','NOT_APPLICABLE')
      then 'CONCURRENCY_LIMIT_UNVERIFIED'
    when jsonb_typeof(v_route->'credit_cost') <> 'number' then 'ENDPOINT_COST_UNVERIFIED'
    when (v_route->>'credit_cost')::numeric<=0 then 'INVALID_ENDPOINT_COST'
    else 'CONFIGURED_PENDING_ATOMIC_QUOTA_GATE'
  end;

  -- Deliberately never return "allowed=true": that permission is PR 3's
  -- atomic and shared budget reservation. A policy lookup is not a permit.
  return jsonb_build_object(
    'provider_key',v_key,'provider_group',v_group,
    'capability',v_cap,'endpoint',v_endpoint,
    'plan_id',v_plan,'policy_version','UNIFIED_QUOTA_V1',
    'budget_source',v_source,
    'limits',jsonb_build_object(
      'minute',v_min,'hour',null,'day',v_day,'concurrent',null,
      'endpoint_class',v_class,'protected_daily_reserve',v_reserve),
    'legacy_accounting_timezone',v_contract->>'legacy_accounting_timezone',
    'vendor_reset_status',v_contract->>'vendor_reset_status',
    'endpoint_credit_cost',v_route->'credit_cost',
    'thresholds',jsonb_build_object(
      'warning_pct',v_contract->'warning_threshold_pct',
      'critical_pct',v_contract->'critical_threshold_pct'),
    'priority_reserve',v_contract->>'priority_reserve',
    'policy_ready',(v_reason='CONFIGURED_PENDING_ATOMIC_QUOTA_GATE'),
    'allowed',false,'dispatch_allowed',false,
    'reason',v_reason,'cutover',false
  );
end
$function$;

-- Resolver is internal-only. No anon/authenticated access.
revoke all on function fwios.resolve_provider_quota_policy_v1(text,text,text)
  from public, anon, authenticated;
grant execute on function fwios.resolve_provider_quota_policy_v1(text,text,text)
  to service_role;
