-- FWIOS PR4 canary guardrails (2026-10-13).
-- This migration does NOT activate providers, touch cron, or modify portfolio data.
-- Harden synthetic market-price isolation and queued-flight priority promotion.
-- Applied functions remain SECURITY INVOKER with pinned search_path and existing grants.
create or replace function fwios.pr4_request_market_refresh_v1(
  p_flight_key text,p_signature text,p_instrument_id uuid,
  p_provider_key text,p_capability text,p_endpoint text,
  p_observation_type text,p_currency text,p_session_date date,
  p_priority text,p_ttl_seconds integer,
  p_fx_base_currency text default null,p_fx_quote_currency text default null,
  p_qa_only boolean default false
) returns jsonb language plpgsql volatile security invoker
set search_path to 'pg_catalog','fwios'
as $fn$
declare v_cache jsonb; v_row fwios.market_refresh_flights_v1%rowtype;
  v_migration_state text; v_now timestamptz:=clock_timestamp();
begin
  if p_flight_key is null or p_flight_key !~ '^[0-9a-f]{64}$'
     or p_signature is null or p_signature !~ '^[0-9a-f]{64}$'
     or p_instrument_id is null or p_session_date is null
     or upper(coalesce(p_priority,'')) not in ('P0','P1','P2','P3','P4')
     or upper(coalesce(p_observation_type,'')) not in ('LIVE_QUOTE','REGULAR_CLOSE','FX','PRE_MARKET','AFTER_HOURS')
     or coalesce(p_ttl_seconds,0) not between 1 and 259200
     or coalesce(length(p_provider_key),0) not between 3 and 64
     or coalesce(length(p_currency),0) not between 3 and 8
     or coalesce(length(p_capability),0) not between 2 and 64
     or coalesce(length(p_endpoint),0) not between 2 and 64
     or ((p_observation_type='FX') <> (p_fx_base_currency is not null and p_fx_quote_currency is not null)) then
    return jsonb_build_object('status','BLOCKED','reason','INVALID_REQUEST');
  end if;
  select config->'unified_quota_v1'->>'migration_state'
    into v_migration_state from fwios.decision_refresh_provider_registry
    where provider_key=upper(p_provider_key);
  if p_qa_only then
    if upper(p_provider_key) !~ '^QA_PR4_[A-Z0-9_]+$' then
      return jsonb_build_object('status','BLOCKED','reason','QA_PROVIDER_REQUIRED');
    end if;
  elsif v_migration_state is distinct from 'ACTIVE' then
    return jsonb_build_object('status','BLOCKED','reason','PR4_CUTOVER_OFF');
  end if;
  -- QA identity must be synthetic and bound to this exact QA provider.
  -- Never allow a mock quote to target a real holding or real instrument.
  if p_qa_only and not exists (
    select 1 from fwios.instruments qa
    where qa.instrument_id=p_instrument_id
      and qa.asset_class='QA_CRYPTO' and qa.instrument_type='QA_SPOT'
      and qa.metadata->>'qa_identity'=upper(p_provider_key)
      and qa.metadata->>'ephemeral'='true'
  ) then
    return jsonb_build_object('status','BLOCKED','reason','QA_INSTRUMENT_NOT_VERIFIED');
  end if;
  if not p_qa_only and exists (
    select 1 from fwios.instruments qa
    where qa.instrument_id=p_instrument_id and qa.metadata ? 'qa_identity'
  ) then
    return jsonb_build_object('status','BLOCKED','reason','SYNTHETIC_INSTRUMENT_NOT_LIVE');
  end if;
  -- P0 for real traffic requires a current OPEN holding of this canonical instrument.
  -- QA-only P0 simulations may use an isolated synthetic instrument in rollback tests.
  if p_priority='P0' and not p_qa_only and not exists (
    select 1 from fwios.v_instrument_identity_current i
    join fwios.v_portfolio_positions_current pos
      on upper(pos.asset_symbol)=upper(i.asset_symbol)
    where i.instrument_id=p_instrument_id and upper(pos.source_position_status)='OPEN'
      and pos.quantity>0
  ) then
    return jsonb_build_object('status','BLOCKED','reason','P0_HOLDING_NOT_VERIFIED');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('fwios-pr4-flight:'||p_flight_key,0));
  v_cache:=fwios.pr4_cache_lookup_v1(p_flight_key,p_signature,p_instrument_id,
    p_provider_key,p_observation_type,p_currency,p_session_date,p_ttl_seconds);
  if v_cache->>'status' in ('FRESH','LAST_CLOSE') then return v_cache; end if;
  select * into v_row from fwios.market_refresh_flights_v1
    where flight_key=p_flight_key for update;
  if found then
    if v_row.request_signature<>p_signature or v_row.instrument_id<>p_instrument_id
       or v_row.provider_key<>upper(p_provider_key)
       or v_row.capability<>upper(p_capability) or v_row.endpoint<>upper(p_endpoint)
       or v_row.observation_type<>upper(p_observation_type)
       or v_row.currency<>upper(p_currency) or v_row.session_date<>p_session_date
       or v_row.fx_base_currency is distinct from p_fx_base_currency
       or v_row.fx_quote_currency is distinct from p_fx_quote_currency
       or v_row.qa_only is distinct from p_qa_only then
      return jsonb_build_object('status','BLOCKED','reason','FLIGHT_KEY_COLLISION');
    end if;
    if v_row.state='RUNNING' then
      return jsonb_build_object('status',case when v_row.lease_until<v_now then 'UNCERTAIN' else 'JOIN' end,
        'reason',case when v_row.lease_until<v_now then 'EXPIRED_DISPATCH_UNCERTAIN' else null end);
    end if;
    if v_row.state='QUEUED' then
      -- Equivalent high-priority demand must promote existing queued flight.
      -- A P0 request was verified against an OPEN holding above.
      if p_priority < v_row.priority then
        update fwios.market_refresh_flights_v1
           set priority=p_priority,updated_at=v_now
         where flight_key=p_flight_key;
      end if;
      return jsonb_build_object('status','JOIN',
        'priority',least(v_row.priority,p_priority));
    end if;
    if v_row.state='UNCERTAIN' or v_row.state='FAILED' then
      return jsonb_build_object('status',v_row.state,'reason',v_row.last_error);
    end if;
    if v_row.state='DEFERRED' and coalesce(v_row.retry_after,'infinity'::timestamptz)>v_now then
      return jsonb_build_object('status','DEFERRED','retry_after',v_row.retry_after);
    end if;
    update fwios.market_refresh_flights_v1 set state='QUEUED',
      priority=case when p_priority<v_row.priority then p_priority else v_row.priority end,
      retry_after=null,worker_id=null,lease_until=null,observation_id=null,
      last_error=null,updated_at=v_now where flight_key=p_flight_key;
    return jsonb_build_object('status','QUEUED');
  end if;
  insert into fwios.market_refresh_flights_v1
    (flight_key,request_signature,instrument_id,provider_key,capability,endpoint,
     observation_type,currency,session_date,priority,ttl_seconds,
     fx_base_currency,fx_quote_currency,qa_only)
  values (p_flight_key,p_signature,p_instrument_id,upper(p_provider_key),upper(p_capability),
     upper(p_endpoint),upper(p_observation_type),upper(p_currency),p_session_date,
     upper(p_priority),p_ttl_seconds,p_fx_base_currency,p_fx_quote_currency,p_qa_only);
  return jsonb_build_object('status','QUEUED');
end $fn$;

create or replace function fwios.pr4_publish_market_refresh_v1(
 p_flight_key text,p_worker_id uuid,p_usage_id uuid,p_value numeric,
 p_observed_at timestamptz,p_market_status text,p_source_tier text
) returns jsonb language plpgsql volatile security invoker
set search_path to 'pg_catalog','fwios'
as $fn$
declare v fwios.market_refresh_flights_v1%rowtype; v_id uuid;
begin
  select * into v from fwios.market_refresh_flights_v1
    where flight_key=p_flight_key for update;
  if not found or v.state<>'RUNNING' or v.worker_id is distinct from p_worker_id
     or v.lease_until<=clock_timestamp()
     or p_value is null or p_value<=0 or p_observed_at is null
     or p_observed_at>clock_timestamp()+interval '5 seconds'
     or coalesce(p_market_status,'') not in ('OPEN','CLOSED','24X7','LAST_CLOSE')
     or coalesce(p_source_tier,'') not in ('A','B','C')
     or (v.observation_type='LIVE_QUOTE' and p_market_status not in ('OPEN','24X7')) then
    return jsonb_build_object('ok',false,'reason','INVALID_PUBLICATION_OR_OWNER');
  end if;
  -- Second defense at the immutable observation publication boundary.
  -- An unexpected DB caller cannot publish mock values on real instruments.
  if v.qa_only and not exists (
    select 1 from fwios.instruments qa
    where qa.instrument_id=v.instrument_id
      and qa.asset_class='QA_CRYPTO' and qa.instrument_type='QA_SPOT'
      and qa.metadata->>'qa_identity'=v.provider_key
      and qa.metadata->>'ephemeral'='true'
  ) then
    return jsonb_build_object('ok',false,'reason','QA_INSTRUMENT_NOT_VERIFIED');
  end if;
  if not v.qa_only and exists (
    select 1 from fwios.instruments qa
    where qa.instrument_id=v.instrument_id and qa.metadata ? 'qa_identity'
  ) then
    return jsonb_build_object('ok',false,'reason','SYNTHETIC_INSTRUMENT_NOT_LIVE');
  end if;
  if not exists (
    select 1 from fwios.v_api_usage_unified_v1 u
    where u.usage_id=p_usage_id and u.outcome='SUCCESS'
      and u.provider_key=v.provider_key and u.request_signature=v.request_signature
      and u.request_key='PR4:'||v.flight_key||':'||v.attempt_number
  ) then return jsonb_build_object('ok',false,'reason','PR3_SUCCESS_PROOF_MISSING'); end if;
  insert into fwios.market_observations
    (observation_key,instrument_id,observation_type,observation_value,
     value_currency,fx_base_currency,fx_quote_currency,session_date,
     observed_at,market_status,provider,source_tier,provenance_status,raw_payload)
  values ('PR4:'||v.flight_key||':'||v.attempt_number,v.instrument_id,v.observation_type,
     p_value,v.currency,v.fx_base_currency,v.fx_quote_currency,v.session_date,
     p_observed_at,p_market_status,v.provider_key,p_source_tier,'PASS',
     jsonb_build_object('fwios_pr4',jsonb_build_object(
       'flight_key',v.flight_key,'signature',v.request_signature,
       'usage_id',p_usage_id,'priority',v.priority,'qa_only',v.qa_only)))
  returning observation_id into v_id;
  update fwios.market_refresh_flights_v1
  set state='READY',observation_id=v_id,lease_until=null,worker_id=null,
      last_error=null,updated_at=clock_timestamp() where flight_key=p_flight_key;
  return jsonb_build_object('ok',true,'status','READY','observation_id',v_id);
end $fn$;

