-- PR5 USD-only canonical ASSET price shadow read.
-- Additive / SECURITY INVOKER / read-only. No provider HTTP, cron, ledger,
-- accounting, quotes ingestion or change to PR4/legacy consumers.
-- Deliberately refuses FX pairs as asset prices; no THB->USD conversion.
create or replace function fwios.pr5_native_usd_price_shadow_v1(p_asset text)
returns jsonb
language plpgsql stable security invoker
set search_path = pg_catalog, fwios
as $fn$
declare
  v_asset text := upper(btrim(coalesce(p_asset,'')));
  v_count integer;
  v_instrument_id uuid;
  v_class text;
  v_o fwios.market_observations%rowtype;
  v_now timestamptz := now();
  v_max_age interval;
  v_status text;
  v_kind text;
begin
  if length(v_asset) < 1 or length(v_asset) > 24 then
    return jsonb_build_object(
      'asset',left(v_asset,24),'status','UNSUPPORTED',
      'reason','INVALID_ASSET','shadow_only',true,'read_only',true,
      'valuation_eligible',false,'accounting_eligible',false,
      'trading_eligible',false,'new_provider_calls',0,'new_quota_reservations',0);
  end if;

  select count(*),(array_agg(i.instrument_id))[1],(array_agg(i.asset_class))[1]
    into v_count,v_instrument_id,v_class
  from fwios.instruments i
  join fwios.v_instrument_identity_current id
    on id.instrument_id=i.instrument_id
  where id.asset_symbol=v_asset
    and i.lifecycle_status='ACTIVE'
    and i.asset_class in ('Stock','Crypto')
    and i.instrument_type in ('COMMON_STOCK','CRYPTO_ASSET')
    and not (i.metadata ? 'qa_identity');

  if v_count <> 1 then
    return jsonb_build_object(
      'asset',v_asset,
      'status',case when v_count=0 then 'UNSUPPORTED' else 'AMBIGUOUS_INSTRUMENT' end,
      'reason','ACTIVE_CANONICAL_IDENTITY_NOT_UNIQUE',
      'currency','USD','shadow_only',true,'read_only',true,
      'valuation_eligible',false,'accounting_eligible',false,
      'trading_eligible',false,'new_provider_calls',0,'new_quota_reservations',0);
  end if;

  -- Stocks: prefer verified A-tier regular close / an actually fresh,
  -- regular-session live quote. Never treat CLOSED live quote as a live price.
  -- Crypto: native CoinGecko USD ONLY. No FX-derived price in this function.
  select o.* into v_o
  from fwios.market_observations o
  where o.instrument_id=v_instrument_id
    and o.value_currency='USD'
    and o.provenance_status='PASS'
    and o.observation_value>0
    and o.observed_at <= v_now+interval '5 seconds'
    and coalesce(o.raw_payload->'fwios_pr4'->>'qa_only','false')<>'true'
    and (
      (v_class='Crypto'
       and o.provider='COINGECKO' and o.source_tier='B'
       and o.observation_type='LIVE_QUOTE' and o.market_status='24X7'
       and o.session_date <= (v_now at time zone 'UTC')::date)
      or
      (v_class='Stock'
       and o.source_tier='A'
       and o.session_date <= (v_now at time zone 'America/New_York')::date
       and (
          (o.observation_type='REGULAR_CLOSE' and o.market_status='CLOSED'
           and o.provider in ('TWELVE_DATA','ALPHA_VANTAGE_PRICE'))
          or
          (o.observation_type='LIVE_QUOTE' and o.market_status='OPEN'
           and o.provider='TWELVE_DATA_QUOTE'
           and o.observed_at >= v_now-interval '15 minutes')
       ))
    )
  order by o.observed_at desc, o.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'asset',v_asset,'instrument_id',v_instrument_id,
      'asset_class',v_class,'currency','USD','price_usd',null,
      'status','MISSING','reason','NATIVE_USD_VERIFIED_OBSERVATION_MISSING',
      'shadow_only',true,'read_only',true,'source_native_usd',false,
      'valuation_eligible',false,'accounting_eligible',false,
      'trading_eligible',false,'new_provider_calls',0,'new_quota_reservations',0);
  end if;

  if v_class='Crypto' then
    v_max_age := interval '30 hours';
    v_kind := 'CRYPTO_DAILY_SNAPSHOT';
    v_status := case
      when v_o.observed_at >= v_now-v_max_age
       and v_o.session_date = (v_now at time zone 'UTC')::date
      then 'FRESH' else 'STALE' end;
  elsif v_o.observation_type='LIVE_QUOTE' then
    v_max_age := interval '15 minutes';
    v_kind := 'STOCK_LIVE_QUOTE';
    v_status := 'FRESH';
  else
    v_max_age := interval '5 days';
    v_kind := 'STOCK_REGULAR_CLOSE';
    v_status := case when v_o.observed_at >= v_now-v_max_age
      then 'LAST_CLOSE' else 'STALE' end;
  end if;

  return jsonb_build_object(
    'asset',v_asset,'instrument_id',v_instrument_id,
    'asset_class',v_class,'currency','USD','price_usd',v_o.observation_value,
    'status',v_status,'quote_kind',v_kind,'observed_at',v_o.observed_at,
    'valid_until',v_o.observed_at+v_max_age,
    'session_date',v_o.session_date,'provider',v_o.provider,
    'source_tier',v_o.source_tier,'observation_id',v_o.observation_id,
    'provenance_status',v_o.provenance_status,
    'source_native_usd',true,'checked_at',v_now,
    'shadow_only',true,'read_only',true,'valuation_eligible',false,
    'accounting_eligible',false,'trading_eligible',false,
    'new_provider_calls',0,'new_quota_reservations',0);
end
$fn$;

revoke all on function fwios.pr5_native_usd_price_shadow_v1(text)
 from public,anon,authenticated;
grant execute on function fwios.pr5_native_usd_price_shadow_v1(text)
 to service_role;
