-- FWIOS PR 3 — staging-only transactional regressions.
-- Requires both PR 2 + PR 3 migrations. DO NOT run outside a disposable STAGING DB.
-- All fixture changes automatically roll back after the assertions.

begin;

do $test$
declare
  v jsonb;
  a jsonb;
  b jsonb;
  c jsonb;
  k text := 'PR3_TEST_STAGING_' || txid_current()::text;
  id_a uuid;
  id_b uuid;
  v_before bigint;
  v_after bigint;
  v_cfg jsonb;
begin
  select count(*) into v_before from fwios.v_api_usage_unified_v1
    where provider_group='COINGECKO';

  v := fwios.resolve_provider_quota_policy_v1('COINGECKO','MARKET_PRICE','SIMPLE_PRICE');
  if v->>'reason' <> 'PROVIDER_DISABLED' then
    raise exception 'Expected disabled placeholder: %',v;
  end if;
  a := fwios.reserve_api_quota_unified_v1(
    'COINGECKO','MARKET_PRICE','SIMPLE_PRICE','pr3-staging',k||'0',
    'sha256-staging-00','P0');
  if (a->>'allowed')::boolean is distinct from false then
    raise exception 'Unknown/unverified provider must deny: %',a;
  end if;

  -- Only this transaction enables a synthetic provider fixture.
  -- This is NOT a verified vendor plan and must NEVER be committed.
  select config->'unified_quota_v1' into v_cfg
  from fwios.decision_refresh_provider_registry where provider_key='COINGECKO';
  update fwios.decision_refresh_provider_registry
  set active=true, readiness_status='READY',
      config=jsonb_set(config,'{unified_quota_v1}',
        v_cfg || jsonb_build_object(
          'plan_id','STAGING_FAKE_PLAN',
          'entitlement_status','VERIFIED',
          'endpoint_cost_status','VERIFIED',
          'vendor_reset_status','VERIFIED',
          'hourly_limit_status','VERIFIED',
          'concurrency_limit_status','VERIFIED',
          'vendor_reset_rule',jsonb_build_object(
            'type','CALENDAR_DAY','timezone','UTC'),
          'protected_daily_credits',0,
          'lease_seconds',120,
          'limits',jsonb_build_object(
            'minute',2,'hour',2,'day',2,'concurrent',1),
          'routes',jsonb_build_object('SIMPLE_PRICE',jsonb_build_object(
            'capabilities',jsonb_build_array('MARKET_PRICE'),
            'credit_cost',1))
        ),true)
  where provider_key='COINGECKO';

  v := fwios.resolve_provider_quota_policy_v1('COINGECKO','MARKET_PRICE','SIMPLE_PRICE');
  if (v->>'policy_ready')::boolean is distinct from true then
    raise exception 'Synthetic policy not ready: %',v;
  end if;

  a := fwios.reserve_api_quota_unified_v1(
    'COINGECKO','MARKET_PRICE','SIMPLE_PRICE','pr3-staging',k||'1',
    'sha256-staging-01','P0');
  if (a->>'allowed')::boolean is distinct from true then
    raise exception 'First atomic reservation failed: %',a;
  end if;
  id_a := (a->>'usage_id')::uuid;

  b := fwios.reserve_api_quota_unified_v1(
    'COINGECKO','MARKET_PRICE','SIMPLE_PRICE','pr3-staging',k||'1',
    'sha256-staging-01','P0');
  if (b->>'allowed')::boolean is distinct from false
    or b->>'reason'<>'IDEMPOTENT_REPLAY_NO_NEW_CALL' then
    raise exception 'Same request key must never dispatch twice: %',b;
  end if;

  b := fwios.reserve_api_quota_unified_v1(
    'COINGECKO','MARKET_PRICE','SIMPLE_PRICE','pr3-staging',k||'2',
    'sha256-staging-02','P0');
  if b->>'reason'<>'CONCURRENCY_EXHAUSTED' then
    raise exception 'One concurrent lease should block second: %',b;
  end if;

  -- A *confirmed pre-dispatch* cancellation is the ONLY refund path.
  b := fwios.finalize_api_quota_usage_v1(
    id_a,'RELEASED',0,null,null,null,false);
  if (b->>'charged_credits')::numeric <> 0
    or (b->>'changed')::boolean is distinct from true then
    raise exception 'Pre-dispatch release failed: %',b;
  end if;

  b := fwios.finalize_api_quota_usage_v1(
    id_a,'SUCCESS',1,200,null,null,true);
  if (b->>'changed')::boolean is distinct from false then
    raise exception 'Terminal transition must be immutable: %',b;
  end if;

  b := fwios.reserve_api_quota_unified_v1(
    'COINGECKO','MARKET_PRICE','SIMPLE_PRICE','pr3-staging',k||'2',
    'sha256-staging-02','P0');
  if (b->>'allowed')::boolean is distinct from true then
    raise exception 'Capacity should be released: %',b;
  end if;
  id_b := (b->>'usage_id')::uuid;

  c := fwios.finalize_api_quota_usage_v1(
    id_b,'SUCCESS',1,200,null,null,true);
  if c->>'outcome'<>'SUCCESS' then
    raise exception 'Success finalization failed: %',c;
  end if;

  b := fwios.reserve_api_quota_unified_v1(
    'COINGECKO','MARKET_PRICE','SIMPLE_PRICE','pr3-staging',k||'3',
    'sha256-staging-03','P0');
  if (b->>'allowed')::boolean is distinct from true then
    raise exception 'Second billable credit should pass: %',b;
  end if;

  a := fwios.reserve_api_quota_unified_v1(
    'COINGECKO','MARKET_PRICE','SIMPLE_PRICE','pr3-staging',k||'4',
    'sha256-staging-04','P0');
  if a->>'reason'<>'DAY_CREDITS_EXHAUSTED' then
    raise exception 'Third billable credit must fail: %',a;
  end if;

  c := fwios.finalize_api_quota_usage_v1(
    (b->>'usage_id')::uuid,'PROVIDER_ERROR',null,429,
    clock_timestamp()+interval '15 minutes','HTTP_429',true);
  if (c->>'charged_credits')::numeric<>1 then
    raise exception '429 remains conservatively billable: %',c;
  end if;

  a := fwios.reserve_api_quota_unified_v1(
    'COINGECKO','MARKET_PRICE','SIMPLE_PRICE','pr3-staging',k||'5',
    'sha256-staging-05','P0');
  if a->>'reason'<>'PROVIDER_RETRY_AFTER' then
    raise exception 'Retry-After must suppress new dispatches: %',a;
  end if;

  select count(*) into v_after from fwios.v_api_usage_unified_v1
    where provider_group='COINGECKO';
  if v_after<>v_before+3 then
    raise exception 'Expected three audit rows; before % after %',v_before,v_after;
  end if;

  a := fwios.reserve_decision_refresh_api_call_v1(
    'UNCONFIGURED_PROVIDER','PRICE','PRICE','pr3-staging',null,'{}'::jsonb);
  if (a->>'allowed')::boolean is distinct from false then
    raise exception 'Legacy Alpha fail-closed regression: %',a;
  end if;

  a := fwios.reserve_market_daily_close_api_call_v1(
    'UNCONFIGURED_PROVIDER','TEST','pr3-staging','{}'::jsonb);
  if (a->>'allowed')::boolean is distinct from false then
    raise exception 'Legacy daily-close fail-closed regression: %',a;
  end if;

  if has_function_privilege('anon',
      'fwios.reserve_api_quota_unified_v1(text,text,text,text,text,text,text,uuid,text,jsonb)','EXECUTE')
     or has_function_privilege('authenticated',
      'fwios.finalize_api_quota_usage_v1(uuid,text,numeric,integer,timestamptz,text,boolean)','EXECUTE') then
    raise exception 'Privileged quota functions must not be exposed';
  end if;

  raise notice 'PASS PR3: fail-closed, accounting, idempotency, concurrency, release, credit limits, 429, legacy compatibility';
end $test$;

rollback;
