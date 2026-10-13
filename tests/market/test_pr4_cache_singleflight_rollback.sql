-- PR4 QA regression: a single BEGIN..ROLLBACK, never persistent market/holding data.
-- Do not split this file into multiple SQL sessions.
begin;
do $qa$
declare
  v_provider text:='QA_PR4_REG_'||txid_current()::text;
  v_instrument uuid;
  v_cfg jsonb; a jsonb; b jsonb; c jsonb; d jsonb;
  v_p0 uuid; v_p4 uuid; v_observation uuid;
  v_before bigint; v_after bigint;
  k0 text:=repeat('a',64); k4 text:=repeat('b',64); k4b text:=repeat('c',64);
  sig0 text:=repeat('d',64); sig4 text:=repeat('e',64); sig4b text:=repeat('f',64);
begin
  insert into fwios.instruments(asset_class,instrument_type,primary_venue,
      trading_currency,metadata)
    values ('QA_CRYPTO','QA_SPOT','QA_ONLY','THB',
      jsonb_build_object('qa_identity',v_provider,'ephemeral',true))
    returning instrument_id into v_instrument;

  v_cfg:=jsonb_build_object('unified_quota_v1',jsonb_build_object(
    'plan_id','QA_SYNTHETIC_NEVER_VENDOR','provider_group',v_provider,
    'budget_source','fwios.decision_refresh_provider_registry.config',
    'migration_state','QA_ONLY','entitlement_status','VERIFIED',
    'endpoint_cost_status','VERIFIED','vendor_reset_status','VERIFIED',
    'hourly_limit_status','VERIFIED','concurrency_limit_status','VERIFIED',
    'protected_daily_credits',1,'lease_seconds',120,
    'vendor_reset_rule',jsonb_build_object('type','CALENDAR_DAY','timezone','UTC'),
    'limits',jsonb_build_object('minute',10,'hour',10,'day',3,'concurrent',3),
    'routes',jsonb_build_object('SIMPLE_PRICE',jsonb_build_object(
      'capabilities',jsonb_build_array('MARKET_PRICE'),'credit_cost',1))));
  insert into fwios.decision_refresh_provider_registry
    (provider_key,provider_type,provider_name,source_tier,active,readiness_status,config)
  values (v_provider,'QA_MARKET_PRICE','QA_Only_Mock','B',true,'READY',v_cfg);
  select count(*) into v_before from fwios.v_api_usage_unified_v1
    where provider_key=v_provider;

  a:=fwios.pr4_request_market_refresh_v1(k4,sig4,v_instrument,v_provider,
    'MARKET_PRICE','SIMPLE_PRICE','LIVE_QUOTE','THB',current_date,'P4',45,
    null,null,true);
  b:=fwios.pr4_request_market_refresh_v1(k4,sig4,v_instrument,v_provider,
    'MARKET_PRICE','SIMPLE_PRICE','LIVE_QUOTE','THB',current_date,'P4',45,
    null,null,true);
  c:=fwios.pr4_request_market_refresh_v1(k0,sig0,v_instrument,v_provider,
    'MARKET_PRICE','SIMPLE_PRICE','LIVE_QUOTE','THB',current_date,'P0',45,
    null,null,true);
  d:=fwios.pr4_request_market_refresh_v1(k4b,sig4b,v_instrument,v_provider,
    'MARKET_PRICE','SIMPLE_PRICE','LIVE_QUOTE','THB',current_date,'P4',45,
    null,null,true);
  if a->>'status'<>'QUEUED' or b->>'status'<>'JOIN'
     or c->>'status'<>'QUEUED' or d->>'status'<>'QUEUED' then
    raise exception 'Queue/join failed: % / % / % / %',a,b,c,d;
  end if;
  if (select count(*) from fwios.v_api_usage_unified_v1 where provider_key=v_provider)<>v_before
  then raise exception 'Cache miss enqueue must NOT reserve credits'; end if;

  -- Priority claim must select P0 even though P4 was enqueued first.
  v_p0:=gen_random_uuid();
  a:=fwios.pr4_claim_market_refresh_v1(v_p0,true);
  if a->>'status'<>'CLAIMED' or a->>'priority'<>'P0' then
    raise exception 'P0 was not claimed first: %',a;
  end if;
  b:=fwios.reserve_api_quota_unified_v1(v_provider,'MARKET_PRICE',
    'SIMPLE_PRICE','pr4-qa',a->>'request_key',a->>'signature','P0',
    null::uuid,v_instrument::text,'{}'::jsonb);
  if (b->>'allowed')::boolean is distinct from true then
    raise exception 'QA P0 reserve failed: %',b; end if;
  c:=fwios.mark_api_quota_dispatched_v1((b->>'usage_id')::uuid,15);
  if (c->>'allowed')::boolean is distinct from true then raise exception 'Dispatch P0 failed: %',c; end if;
  c:=fwios.finalize_api_quota_usage_v1((b->>'usage_id')::uuid,'SUCCESS',1,200,null,null,true);
  if (c->>'ok')::boolean is distinct from true then raise exception 'Finalize failed: %',c; end if;
  c:=fwios.pr4_publish_market_refresh_v1(k0,v_p0,(b->>'usage_id')::uuid,
    123.45,clock_timestamp(),'24X7','B');
  if (c->>'ok')::boolean is distinct from true then raise exception 'Publish failed: %',c; end if;
  v_observation:=(c->>'observation_id')::uuid;
  d:=fwios.pr4_cache_lookup_v1(k0,sig0,v_instrument,v_provider,
    'LIVE_QUOTE','THB',current_date,45);
  if d->>'status'<>'FRESH' or (d->>'observation_id')::uuid<>v_observation
  then raise exception 'Fresh tagged cache identity failure: %',d; end if;

  d:=fwios.pr4_request_market_refresh_v1(k0,sig0,v_instrument,v_provider,
    'MARKET_PRICE','SIMPLE_PRICE','LIVE_QUOTE','THB',current_date,'P0',45,
    null,null,true);
  if d->>'status'<>'FRESH' or d->>'observation_id'<>v_observation::text
  then raise exception 'Cache-first reuse failure: %',d; end if;
  if (select count(*) from fwios.v_api_usage_unified_v1 where provider_key=v_provider)<>v_before+1
  then raise exception 'Cache hit must not reserve credits'; end if;

  v_p4:=gen_random_uuid();
  a:=fwios.pr4_claim_market_refresh_v1(v_p4,true);
  if a->>'priority'<>'P4' then raise exception 'P4 claim failed: %',a; end if;
  b:=fwios.reserve_api_quota_unified_v1(v_provider,'MARKET_PRICE',
    'SIMPLE_PRICE','pr4-qa',a->>'request_key',a->>'signature','P4',
    null::uuid,v_instrument::text,'{}'::jsonb);
  if (b->>'allowed')::boolean is distinct from true then
    raise exception 'One P4 credit should pass: %',b; end if;
  c:=fwios.mark_api_quota_dispatched_v1((b->>'usage_id')::uuid,15);
  c:=fwios.finalize_api_quota_usage_v1((b->>'usage_id')::uuid,'SUCCESS',1,200,null,null,true);
  c:=fwios.pr4_publish_market_refresh_v1(a->>'flight_key',v_p4,(b->>'usage_id')::uuid,
    200,clock_timestamp(),'24X7','B');
  if (c->>'ok')::boolean is distinct from true then raise exception 'P4 publish failed: %',c; end if;
  a:=fwios.pr4_claim_market_refresh_v1(gen_random_uuid(),true);
  b:=fwios.reserve_api_quota_unified_v1(v_provider,'MARKET_PRICE',
    'SIMPLE_PRICE','pr4-qa',a->>'request_key',a->>'signature','P4',
    null::uuid,v_instrument::text,'{}'::jsonb);
  if b->>'reason'<>'P0_CAPACITY_PROTECTED' then
    raise exception 'P4 spent P0 protected reserve: %',b;
  end if;

  select count(*) into v_after from fwios.v_api_usage_unified_v1
    where provider_key=v_provider;
  if v_after<>v_before+2 then raise exception 'Unexpected quota rows: % -> %',v_before,v_after; end if;
  if has_function_privilege('anon',
     'fwios.pr4_claim_market_refresh_v1(uuid,boolean)','EXECUTE')
     or has_function_privilege('authenticated',
     'fwios.pr4_publish_market_refresh_v1(text,uuid,uuid,numeric,timestamptz,text,text)','EXECUTE')
  then raise exception 'PR4 private RPC must deny frontend roles'; end if;
  -- Old unscoped method is inaccessible even to service_role.
  if has_function_privilege('service_role',
     'fwios.pr4_claim_market_refresh_v1(uuid)','EXECUTE')
     or not has_function_privilege('service_role',
     'fwios.pr4_claim_market_refresh_v1(uuid,boolean)','EXECUTE') then
    raise exception 'QA scoped claim hardening failed'; end if;
  -- Scope must NOT claim queued QA rows when the live-only scope is requested.
  if (fwios.pr4_claim_market_refresh_v1(gen_random_uuid(),false)->>'status')<>'EMPTY' then
    raise exception 'Live scope may never claim QA fixture'; end if;

  raise notice 'PASS PR4 rollback-only: cache 0 credits, join, P0 order, P4 reserve, PR3 lifecycle, publication, security';
end $qa$;
rollback;
