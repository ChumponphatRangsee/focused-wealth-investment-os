-- FWIOS PR4: bounded real-data canary; no vendor HTTP and no trading writes.
-- Only BTC/THB CoinGecko market observations already present in canonical storage.
-- No new table, provider activation, consumer cutover or change to existing cron/worker.
create or replace function fwios.pr4_btc_canary_market_quote_v1()
returns jsonb
language plpgsql stable security invoker
set search_path to 'pg_catalog','fwios'
as $fn$
declare
  v fwios.market_observations%rowtype;
  v_now timestamptz := clock_timestamp();
  v_fresh boolean;
begin
  select m.* into v
  from fwios.market_observations m
  join fwios.instruments i on i.instrument_id=m.instrument_id
  where m.instrument_id='2653312e-698d-4678-8975-0dd2c1b32901'::uuid
    and i.asset_class='Crypto'
    and i.instrument_type='CRYPTO_ASSET'
    and not (i.metadata ? 'qa_identity')
    and m.provider='COINGECKO'
    and m.observation_type='LIVE_QUOTE'
    and m.value_currency='THB'
    and m.market_status='24X7'
    and m.provenance_status='PASS'
    and m.source_tier='B'
    and m.observation_value>0
    and m.observed_at<=v_now+interval '5 seconds'
    and coalesce(m.raw_payload->'fwios_pr4'->>'qa_only','false')<>'true'
  order by m.observed_at desc, m.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object('status','MISSING','instrument','BTC',
      'provider','COINGECKO','canary_only',true,
      'accounting_eligible',false,'trading_eligible',false);
  end if;

  v_fresh := v.observed_at>v_now-interval '15 minutes'
    and v.session_date=(v_now at time zone 'UTC')::date;
  return jsonb_build_object(
    'status',case when v_fresh then 'FRESH' else 'STALE' end,
    'instrument','BTC',
    'instrument_id',v.instrument_id,
    'observation_id',v.observation_id,
    'price',v.observation_value,
    'currency','THB',
    'provider','COINGECKO',
    'source_tier',v.source_tier,
    'market_status','24X7',
    'session_date',v.session_date,
    'observed_at',v.observed_at,
    'valid_until',v.observed_at+interval '15 minutes',
    'checked_at',v_now,
    'canary_only',true,
    'cache_origin','EXISTING_CANONICAL_OBSERVATION',
    'new_provider_calls',0,
    'new_quota_reservations',0,
    'accounting_eligible',false,
    'trading_eligible',false,
    'valuation_eligible',false);
end
$fn$;

revoke all on function fwios.pr4_btc_canary_market_quote_v1()
  from public,anon,authenticated;
grant execute on function fwios.pr4_btc_canary_market_quote_v1()
  to service_role;
