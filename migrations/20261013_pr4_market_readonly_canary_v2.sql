-- FWIOS PR4 real-data read-only canary v2.
-- ADDITIVE: no outgoing vendor requests, no write to transactions/holdings/quotes,
-- no provider migration-state, cron, endpoint billing or accounting changes.
-- Only explicit canonical instruments/providers/observation types can be read.
create or replace function fwios.pr4_market_canary_quote_v2(p_asset text)
returns jsonb
language plpgsql stable security invoker
set search_path = pg_catalog,fwios
as $fn$
declare
  v_asset text := upper(btrim(coalesce(p_asset,'')));
  v_instrument_id uuid;
  v_expected_class text;
  v_expected_type text;
  v_provider text;
  v_obs_type text;
  v_currency text;
  v_market_status text;
  v_now timestamptz := now();
  v_value fwios.market_observations%rowtype;
  v_status text;
  v_kind text;
  v_max_age interval;
begin
  -- Explicit read-only allowlist. Asset symbol is not interpolated into SQL.
  case v_asset
    when 'BTC' then
      v_instrument_id := '2653312e-698d-4678-8975-0dd2c1b32901'::uuid;
      v_expected_class := 'Crypto'; v_expected_type := 'CRYPTO_ASSET';
      v_provider := 'COINGECKO'; v_obs_type := 'LIVE_QUOTE';
      v_currency := 'THB'; v_market_status := '24X7'; v_kind := 'CRYPTO_QUOTE';
      v_max_age := interval '15 minutes';
    when 'NVDA' then
      v_instrument_id := '272e2066-f57e-4902-882e-b2016aae22cc'::uuid;
      v_expected_class := 'Stock'; v_expected_type := 'COMMON_STOCK';
      v_provider := 'TWELVE_DATA'; v_obs_type := 'REGULAR_CLOSE';
      v_currency := 'USD'; v_market_status := 'CLOSED'; v_kind := 'STOCK_REGULAR_CLOSE';
      v_max_age := interval '5 days';
    when 'TTWO' then
      v_instrument_id := '4930e480-cb82-40b7-89a7-9ea55e190244'::uuid;
      v_expected_class := 'Stock'; v_expected_type := 'COMMON_STOCK';
      v_provider := 'TWELVE_DATA'; v_obs_type := 'REGULAR_CLOSE';
      v_currency := 'USD'; v_market_status := 'CLOSED'; v_kind := 'STOCK_REGULAR_CLOSE';
      v_max_age := interval '5 days';
    when 'USDTHB' then
      -- Existing FX observations are *attached to* the NVDA instrument.
      -- This is reference-only, NOT an independent canonical FX instrument.
      v_instrument_id := '272e2066-f57e-4902-882e-b2016aae22cc'::uuid;
      v_expected_class := 'Stock'; v_expected_type := 'COMMON_STOCK';
      v_provider := 'TWELVE_DATA_FX'; v_obs_type := 'FX';
      v_currency := 'THB'; v_market_status := 'FX'; v_kind := 'FX_ATTACHED_REFERENCE';
      v_max_age := interval '30 minutes';
    else
      return jsonb_build_object(
        'status','UNSUPPORTED','asset',v_asset,'canary_only',true,
        'allowlist',jsonb_build_array('BTC','NVDA','TTWO','USDTHB'),
        'accounting_eligible',false,'valuation_eligible',false);
  end case;

  select m.* into v_value
  from fwios.market_observations m
  join fwios.instruments i on i.instrument_id=m.instrument_id
  join fwios.v_instrument_identity_current id on id.instrument_id=i.instrument_id
  where m.instrument_id=v_instrument_id
    and id.asset_symbol=(case when v_asset='USDTHB' then 'NVDA' else v_asset end)
    and i.asset_class=v_expected_class
    and i.instrument_type=v_expected_type
    and i.lifecycle_status='ACTIVE'
    and not (i.metadata ? 'qa_identity')
    and m.provider=v_provider
    and m.observation_type=v_obs_type
    and m.value_currency=v_currency
    and m.market_status=v_market_status
    and m.provenance_status='PASS'
    and m.source_tier=case when v_asset='BTC' then 'B' else 'A' end
    and m.observation_value>0
    and m.observed_at<=v_now+interval '5 seconds'
    and m.session_date <= (v_now at time zone
      (case when v_kind='STOCK_REGULAR_CLOSE' then 'America/New_York' else 'UTC' end))::date
    and (v_asset<>'USDTHB' or
         (m.fx_base_currency='USD' and m.fx_quote_currency='THB'))
    and coalesce(m.raw_payload->'fwios_pr4'->>'qa_only','false')<>'true'
  order by m.observed_at desc,m.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'status','MISSING','asset',v_asset,'quote_kind',v_kind,
      'canary_only',true,'accounting_eligible',false,'valuation_eligible',false,
      'trading_eligible',false,'new_provider_calls',0,'new_quota_reservations',0);
  end if;

  if v_value.observed_at < v_now-v_max_age then
    v_status := 'STALE';
  elsif v_kind='STOCK_REGULAR_CLOSE' then
    -- A prior-session close is *never* called a fresh live quote.
    v_status := 'LAST_CLOSE';
  elsif v_kind='CRYPTO_QUOTE' and v_value.session_date<>(v_now at time zone 'UTC')::date then
    v_status := 'STALE';
  elsif v_kind='FX_ATTACHED_REFERENCE' then
    v_status := 'FRESH_REFERENCE';
  else
    v_status := 'FRESH';
  end if;

  return jsonb_build_object(
    'status',v_status,'asset',v_asset,'quote_kind',v_kind,
    'price',v_value.observation_value,'currency',v_currency,
    'instrument_id',v_value.instrument_id,'observation_id',v_value.observation_id,
    'observation_type',v_obs_type,'provider',v_value.provider,
    'source_tier',v_value.source_tier,'market_status',v_value.market_status,
    'session_date',v_value.session_date,'observed_at',v_value.observed_at,
    'valid_until',v_value.observed_at+v_max_age,'checked_at',v_now,
    'origin','EXISTING_CANONICAL_OBSERVATION',
    'fx_standalone_identity',false,
    'canary_only',true,'read_only',true,'accounting_eligible',false,
    'valuation_eligible',false,'trading_eligible',false,
    'new_provider_calls',0,'new_quota_reservations',0);
end
$fn$;

revoke all on function fwios.pr4_market_canary_quote_v2(text)
 from public,anon,authenticated;
grant execute on function fwios.pr4_market_canary_quote_v2(text)
 to service_role;
