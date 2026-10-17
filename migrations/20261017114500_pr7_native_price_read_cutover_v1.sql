create or replace function fwios.pr7_native_usd_price_read_v1(p_asset text)
returns jsonb
language plpgsql
stable
set search_path to 'pg_catalog','fwios'
as $function$
declare
  q jsonb;
  v_status text;
  v_class text;
  v_price numeric;
  v_source_native boolean;
  v_eligible boolean := false;
begin
  q := fwios.pr5_native_usd_price_shadow_v1(p_asset);
  v_status := coalesce(q->>'status','MISSING');
  v_class := coalesce(q->>'asset_class','');
  v_price := nullif(q->>'price_usd','')::numeric;
  v_source_native := coalesce((q->>'source_native_usd')::boolean,false);

  v_eligible :=
    v_source_native
    and coalesce(v_price,0) > 0
    and (
      (v_class='Stock' and v_status in ('LAST_CLOSE','FRESH'))
      or
      (v_class='Crypto' and v_status='FRESH')
    );

  return q || jsonb_build_object(
    'cutover_mode','FWIOS_NATIVE',
    'shadow_only',false,
    'read_only',true,
    'valuation_eligible',v_eligible,
    'accounting_eligible',v_eligible,
    'trading_eligible',false,
    'eligibility_reason',
      case
        when v_eligible then 'VERIFIED_NATIVE_USD'
        when not v_source_native then 'NATIVE_USD_SOURCE_REQUIRED'
        when coalesce(v_price,0) <= 0 then 'POSITIVE_NATIVE_USD_PRICE_REQUIRED'
        when v_class='Crypto' and v_status<>'FRESH' then 'CRYPTO_FRESH_REQUIRED'
        when v_class='Stock' and v_status not in ('LAST_CLOSE','FRESH') then 'STOCK_LATEST_CLOSE_OR_FRESH_REQUIRED'
        else 'VALUATION_BLOCKED'
      end
  );
end
$function$;

comment on function fwios.pr7_native_usd_price_read_v1(text) is
'PR7 controlled Price Data read-cutover wrapper. Reuses PR5 native USD observations, permits verified Stock LAST_CLOSE/FRESH and Crypto FRESH for valuation, and never enables trading.';
