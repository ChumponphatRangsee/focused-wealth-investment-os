-- PR4 hardening (follow-up to deployed additive PR4 migration).
-- QA-only Edge worker must never claim an eventual live provider flight.
-- Disallow old UNFILTERED service role claim: callers must pass qa scope.
create or replace function fwios.pr4_claim_market_refresh_v1(
  p_worker_id uuid,p_qa_only boolean
) returns jsonb language plpgsql volatile security invoker
set search_path to 'pg_catalog','fwios'
as $fn$
declare v fwios.market_refresh_flights_v1%rowtype;
begin
  if p_worker_id is null or p_qa_only is null then
    return jsonb_build_object('status','BLOCKED','reason','MISSING_CLAIM_SCOPE');
  end if;
  select f.* into v
  from fwios.market_refresh_flights_v1 f
  join fwios.decision_refresh_provider_registry r on r.provider_key=f.provider_key
  where f.qa_only=p_qa_only
    and (f.state='QUEUED' or (f.state='DEFERRED' and f.retry_after<=clock_timestamp()))
    and (
      (p_qa_only and f.provider_key like 'QA_PR4_%')
      or (not p_qa_only and r.config->'unified_quota_v1'->>'migration_state'='ACTIVE')
    )
  order by f.priority asc,f.created_at asc
  for update of f skip locked limit 1;
  if not found then return jsonb_build_object('status','EMPTY'); end if;
  update fwios.market_refresh_flights_v1 set state='RUNNING',worker_id=p_worker_id,
    lease_until=clock_timestamp()+interval '120 seconds',retry_after=null,
    attempt_number=attempt_number+1,updated_at=clock_timestamp()
  where flight_key=v.flight_key returning * into v;
  return jsonb_build_object('status','CLAIMED','flight_key',v.flight_key,
    'signature',v.request_signature,'provider_key',v.provider_key,'capability',v.capability,
    'endpoint',v.endpoint,'instrument_id',v.instrument_id,'observation_type',v.observation_type,
    'currency',v.currency,'session_date',v.session_date,'priority',v.priority,
    'ttl_seconds',v.ttl_seconds,'attempt_number',v.attempt_number,
    'request_key','PR4:'||v.flight_key||':'||v.attempt_number,
    'qa_only',v.qa_only);
end $fn$;

-- This signature is intentionally legacy-unscoped and must not be called by workers.
revoke all on function fwios.pr4_claim_market_refresh_v1(uuid)
  from public,anon,authenticated,service_role;
revoke all on function fwios.pr4_claim_market_refresh_v1(uuid,boolean)
  from public,anon,authenticated;
grant execute on function fwios.pr4_claim_market_refresh_v1(uuid,boolean)
  to service_role;
