-- FWIOS v3 / PR 2: fail-closed provider registry + shared quota policy resolver.
-- Run AFTER applying migrations/20261013_pr2_unified_provider_quota_policy_v1.sql
-- Read-only assertions: no provider calls, no reservations, no usage/transaction writes.

do $test$
declare
  v jsonb;
begin
  v := fwios.resolve_provider_quota_policy_v1('UNKNOWN_PROVIDER','MARKET_PRICE','QUOTE');
  if v->>'reason' <> 'PROVIDER_NOT_REGISTERED'
     or (v->>'allowed')::boolean is distinct from false then
    raise exception 'FAIL unknown provider must deny: %',v;
  end if;

  v := fwios.resolve_provider_quota_policy_v1('TWELVE_DATA','MARKET_PRICE','QUOTE');
  if v->>'reason' <> 'VENDOR_ENTITLEMENT_UNVERIFIED'
     or (v->>'allowed')::boolean is distinct from false
     or (v->>'dispatch_allowed')::boolean is distinct from false
     or (v->'limits'->>'minute')::int <> 8
     or (v->'limits'->>'day')::int <> 700
     or (v->'limits'->>'legacy_headroom_outside_daily_budget')::int <> 100 then
    raise exception 'FAIL existing Twelve Data budget/readiness regression: %',v;
  end if;

  v := fwios.resolve_provider_quota_policy_v1('ALPHA_VANTAGE_PRICE','MARKET_PRICE','TIME_SERIES_DAILY');
  if v->>'reason' <> 'VENDOR_ENTITLEMENT_UNVERIFIED'
     or (v->>'dispatch_allowed')::boolean is distinct from false
     or (v->'limits'->>'day')::int <> 25
     or (v->'limits'->>'endpoint_class')::int <> 15
     or (v->'limits'->>'reserve_bucket_within_daily_budget')::int <> 3 then
    raise exception 'FAIL existing Alpha Vantage shared budget regression: %',v;
  end if;

  v := fwios.resolve_provider_quota_policy_v1('ALPHA_VANTAGE_CONSENSUS','ANALYST_DATA','EARNINGS_ESTIMATES');
  if v->>'reason' <> 'PROVIDER_DISABLED' then
    raise exception 'FAIL disabled Alpha Vantage route must deny: %',v;
  end if;

  v := fwios.resolve_provider_quota_policy_v1('TWELVE_DATA','FUNDAMENTALS','QUOTE');
  if v->>'reason' <> 'CAPABILITY_NOT_CONFIGURED' then
    raise exception 'FAIL unconfigured capability must deny: %',v;
  end if;

  v := fwios.resolve_provider_quota_policy_v1('TWELVE_DATA','MARKET_PRICE','NO_SUCH_ENDPOINT');
  if v->>'reason' <> 'ENDPOINT_NOT_CONFIGURED' then
    raise exception 'FAIL unconfigured endpoint must deny: %',v;
  end if;

  v := fwios.resolve_provider_quota_policy_v1('COINGECKO','MARKET_PRICE','SIMPLE_PRICE');
  if v->>'reason' <> 'PROVIDER_DISABLED' then
    raise exception 'FAIL CoinGecko unverified placeholder must deny: %',v;
  end if;

  v := fwios.resolve_provider_quota_policy_v1('FRANKFURTER_FX','FX','LATEST');
  if v->>'reason' <> 'PROVIDER_DISABLED' then
    raise exception 'FAIL Frankfurter unverified placeholder must deny: %',v;
  end if;

  v := fwios.resolve_provider_quota_policy_v1('','','');
  if v->>'reason' <> 'INVALID_POLICY_LOOKUP' then
    raise exception 'FAIL empty lookup must deny: %',v;
  end if;

  if has_function_privilege('anon',
       'fwios.resolve_provider_quota_policy_v1(text,text,text)','EXECUTE')
     or has_function_privilege('authenticated',
       'fwios.resolve_provider_quota_policy_v1(text,text,text)','EXECUTE')
     or not has_function_privilege('service_role',
       'fwios.resolve_provider_quota_policy_v1(text,text,text)','EXECUTE') then
    raise exception 'FAIL resolver grants do not meet internal-only contract';
  end if;

  if not exists(
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='fwios'
    and p.proname='reserve_decision_refresh_api_call_v1')
    or not exists(
      select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='fwios'
      and p.proname='reserve_market_daily_close_api_call_v1') then
    raise exception 'FAIL original reservation functions must remain for compatibility';
  end if;

  raise notice 'PASS: PR2 resolver is internal-only, additive, no dispatch and deny-by-default.';
end
$test$;
