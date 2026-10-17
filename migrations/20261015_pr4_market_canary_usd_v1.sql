-- FWIOS PR4 read-only USD display projection. Additive; v2 unchanged.
-- Read data already in canonical observations; never dispatch a vendor request.
-- BTC source is native BTC/THB; USD conversion uses the existing FX reference.
-- Missing or stale FX never masquerades as a fresh USD quote.
create function fwios.pr4_market_canary_usd_v1(p_asset text)
returns jsonb
language plpgsql stable security invoker
set search_path = pg_catalog,fwios
as $fn$
declare
  v_asset text := upper(btrim(coalesce(p_asset, '')));
  v_base jsonb;
  v_fx jsonb;
  v_crypto numeric;
  v_rate numeric;
  v_status text;
  v_latest_valid timestamptz;
begin
  if v_asset not in ('BTC','NVDA','TTWO','USDTHB') then
    return jsonb_build_object(
      'asset',v_asset,'status','UNSUPPORTED','canary_only',true,
      'accounting_eligible',false,'valuation_eligible',false,
      'trading_eligible',false,'read_only',true,'new_provider_calls',0,
      'new_quota_reservations',0,
      'allowlist',jsonb_build_array('BTC','NVDA','TTWO','USDTHB'));
  end if;

  v_base := fwios.pr4_market_canary_quote_v2(v_asset);
  if v_asset in ('NVDA','TTWO') then
    if v_base->>'currency' <> 'USD' or
       coalesce(v_base->>'quote_kind','') <> 'STOCK_REGULAR_CLOSE' then
      return jsonb_build_object('asset',v_asset,'status','MISSING',
        'currency','USD','canary_only',true,'read_only',true,
        'accounting_eligible',false,'valuation_eligible',false,
        'trading_eligible',false,'new_provider_calls',0,'new_quota_reservations',0);
    end if;
    return v_base || jsonb_build_object(
      'display_currency','USD','price_is_derived',false);
  elsif v_asset = 'USDTHB' then
    -- FX is quoted as THB per one USD; relabeling its units to USD is incorrect.
    return v_base || jsonb_build_object(
      'base_currency','USD','quote_currency','THB',
      'price_unit','THB_PER_USD','price_is_derived',false);
  end if;

  -- BTC: no canonical BTC/USD observation exists at rollout. Convert
  -- BTC/THB using validated existing USDTHB attached FX observation.
  v_fx := fwios.pr4_market_canary_quote_v2('USDTHB');
  if v_base->>'currency' <> 'THB'
     or v_base->>'quote_kind' <> 'CRYPTO_QUOTE'
     or v_base->>'provider' <> 'COINGECKO'
     or v_base->>'status' not in ('FRESH','STALE')
     or v_fx->>'quote_kind' <> 'FX_ATTACHED_REFERENCE'
     or v_fx->>'currency' <> 'THB'
     or v_fx->>'status' not in ('FRESH_REFERENCE','STALE')
     or v_fx->>'provider' <> 'TWELVE_DATA_FX'
     or coalesce(v_base->>'observation_id','') = ''
     or coalesce(v_fx->>'observation_id','') = ''
  then
    return jsonb_build_object(
      'asset','BTC','status','MISSING','currency','USD',
      'quote_kind','CRYPTO_FX_DERIVED','canary_only',true,
      'accounting_eligible',false,'valuation_eligible',false,
      'trading_eligible',false,'read_only',true,'new_provider_calls',0,
      'new_quota_reservations',0,'reason','CANONICAL_BTC_OR_FX_UNAVAILABLE');
  end if;

  v_crypto := (v_base->>'price')::numeric;
  v_rate := (v_fx->>'price')::numeric;
  if v_crypto is null or v_rate is null or v_crypto<=0 or v_rate<=0 then
    return jsonb_build_object(
      'asset','BTC','status','MISSING','currency','USD',
      'quote_kind','CRYPTO_FX_DERIVED','canary_only',true,
      'accounting_eligible',false,'valuation_eligible',false,
      'trading_eligible',false,'read_only',true,'new_provider_calls',0,
      'new_quota_reservations',0,'reason','INVALID_FX_OR_BTC_PRICE');
  end if;

  v_status := case when v_base->>'status'='FRESH'
                        and v_fx->>'status'='FRESH_REFERENCE'
                   then 'FRESH' else 'STALE' end;
  v_latest_valid := least(
    (v_base->>'valid_until')::timestamptz,
    (v_fx->>'valid_until')::timestamptz
  );

  return v_base || jsonb_build_object(
    'asset','BTC','price',round(v_crypto/v_rate,8),
    'currency','USD','display_currency','USD',
    'status',v_status,'quote_kind','CRYPTO_FX_DERIVED',
    'price_is_derived',true,'origin','EXISTING_CANONICAL_OBSERVATIONS_FX_DERIVED',
    'native_price_thb',v_crypto,'fx_rate_thb_per_usd',v_rate,
    'fx_base_currency','USD','fx_quote_currency','THB',
    'fx_provider',v_fx->>'provider','fx_observation_id',v_fx->>'observation_id',
    'fx_observed_at',v_fx->>'observed_at',
    'fx_status',v_fx->>'status','underlying_asset_status',v_base->>'status',
    'valid_until',v_latest_valid,
    'accounting_eligible',false,'valuation_eligible',false,
    'trading_eligible',false,'read_only',true,'canary_only',true,
    'new_provider_calls',0,'new_quota_reservations',0);
end
$fn$;

revoke all on function fwios.pr4_market_canary_usd_v1(text)
 from public,anon,authenticated;
grant execute on function fwios.pr4_market_canary_usd_v1(text)
 to service_role;
