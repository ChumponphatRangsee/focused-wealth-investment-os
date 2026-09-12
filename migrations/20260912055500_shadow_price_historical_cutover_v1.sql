create or replace function fwios.cutover_shadow_price_historical_v1(p_ticker text, p_session_date date)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  td record;
  av record;
  vr record;
  pol record;
  td_px numeric;
  av_px numeric;
  sel_px numeric;
  div_pct numeric;
  q_td text;
  q_av text;
  snap_id text;
  mis_id text;
  b_up numeric;
  base_up numeric;
  bull_up numeric;
  pw_up numeric;
  m_gate text;
  m_class text;
  ex text;
  close_at timestamptz;
  stale_at timestamptz;
begin
  p_ticker := upper(trim(p_ticker));
  if p_ticker is null or p_ticker='' then raise exception 'ticker required'; end if;

  select e.* into td
  from fwios.decision_refresh_shadow_evidence e
  where e.ticker=p_ticker and e.fact_class='MARKET_PRICE' and e.source_provider='TWELVE_DATA'
    and e.source_tier='A' and e.collection_status='PASS'
    and (e.payload->>'session_date')::date=p_session_date
  order by e.observed_at desc limit 1;

  select e.* into av
  from fwios.decision_refresh_shadow_evidence e
  where e.ticker=p_ticker and e.fact_class='MARKET_PRICE' and e.source_provider='ALPHA_VANTAGE_PRICE'
    and e.source_tier='A' and e.collection_status='PASS'
    and (e.payload->>'session_date')::date=p_session_date
  order by e.observed_at desc limit 1;

  if td is null or av is null then
    return jsonb_build_object('ticker',p_ticker,'session_date',p_session_date,'cutover','BLOCKED','reason','EXACT_DUAL_SOURCE_SHADOW_EVIDENCE_MISSING');
  end if;

  if not exists(select 1 from fwios.decision_refresh_provider_registry where provider_key='TWELVE_DATA' and active=true and readiness_status='READY' and source_tier='A')
     or not exists(select 1 from fwios.decision_refresh_provider_registry where provider_key='ALPHA_VANTAGE_PRICE' and active=true and readiness_status='READY' and source_tier='A') then
    return jsonb_build_object('ticker',p_ticker,'session_date',p_session_date,'cutover','BLOCKED','reason','TIER_A_PRICE_PROVIDER_NOT_READY');
  end if;

  td_px := (td.payload->>'close')::numeric;
  av_px := (av.payload->>'close')::numeric;
  if td_px<=0 or av_px<=0 then raise exception 'invalid price evidence'; end if;
  div_pct := abs(td_px-av_px)/((td_px+av_px)/2);
  if div_pct>0.005 then
    return jsonb_build_object('ticker',p_ticker,'session_date',p_session_date,'cutover','BLOCKED','reason','PRICE_CONFLICT','divergence_pct',div_pct);
  end if;
  sel_px := (td_px+av_px)/2;

  select v.* into vr from fwios.valuation_runs v
  where v.ticker=p_ticker and v.production_eligible=true and v.valuation_gate='PASS'
  order by v.created_at desc limit 1;
  if vr is null then
    return jsonb_build_object('ticker',p_ticker,'session_date',p_session_date,'cutover','BLOCKED','reason','PRODUCTION_VALUATION_MISSING');
  end if;

  select m.* into pol from fwios.mispricing_policies m where m.active=true order by m.updated_at desc limit 1;
  if pol is null then raise exception 'active mispricing policy missing'; end if;

  ex := coalesce(td.payload->'meta'->>'exchange','UNKNOWN');
  close_at := ((p_session_date::text || ' 16:00 America/New_York')::timestamptz);
  stale_at := (((p_session_date + 1)::text || ' 09:30 America/New_York')::timestamptz);
  q_td := 'Q-'||p_ticker||'-TD-'||to_char(p_session_date,'YYYYMMDD')||'-CLOSE';
  q_av := 'Q-'||p_ticker||'-AV-'||to_char(p_session_date,'YYYYMMDD')||'-CLOSE';
  snap_id := 'PX-'||p_ticker||'-'||to_char(p_session_date,'YYYYMMDD')||'-AUTO';
  mis_id := 'MIS-'||p_ticker||'-'||to_char(p_session_date,'YYYYMMDD')||'-AUTO';

  insert into fwios.market_price_quotes(quote_id,asset_symbol,asset_class,exchange,currency,price_type,price,session_date,quote_at,market_status,source_provider,source_url,source_tier,retrieved_at,provenance_status,raw_payload)
  values(q_td,p_ticker,'Stock',ex,'USD','REGULAR_CLOSE',td_px,p_session_date,close_at,'CLOSED','TWELVE_DATA',td.source_url,'A',td.observed_at,'PASS',td.payload || jsonb_build_object('shadow_run_id',td.run_id,'shadow_job_id',td.job_id,'cutover_contract','SHADOW_PRICE_HISTORICAL_CUTOVER_V1'))
  on conflict(quote_id) do update set price=excluded.price,retrieved_at=excluded.retrieved_at,provenance_status='PASS',raw_payload=excluded.raw_payload;

  insert into fwios.market_price_quotes(quote_id,asset_symbol,asset_class,exchange,currency,price_type,price,session_date,quote_at,market_status,source_provider,source_url,source_tier,retrieved_at,provenance_status,raw_payload)
  values(q_av,p_ticker,'Stock',ex,'USD','REGULAR_CLOSE',av_px,p_session_date,close_at,'CLOSED','ALPHA_VANTAGE_PRICE',av.source_url,'A',av.observed_at,'PASS',av.payload || jsonb_build_object('shadow_run_id',av.run_id,'shadow_job_id',av.job_id,'cutover_contract','SHADOW_PRICE_HISTORICAL_CUTOVER_V1'))
  on conflict(quote_id) do update set price=excluded.price,retrieved_at=excluded.retrieved_at,provenance_status='PASS',raw_payload=excluded.raw_payload;

  insert into fwios.market_price_snapshots(snapshot_id,asset_symbol,asset_class,primary_quote_id,crosscheck_quote_id,selected_price,currency,session_date,market_status,divergence_pct,max_allowed_divergence_pct,fresh_until,conflict_status,provenance_status,price_gate,notes)
  values(snap_id,p_ticker,'Stock',q_td,q_av,sel_px,'USD',p_session_date,'CLOSED',div_pct,0.005,stale_at,'PASS','PASS','PASS','AUTO cutover from Tier-A Twelve Data + Alpha Vantage Price shadow evidence; historical canonical snapshot.')
  on conflict(snapshot_id) do update set selected_price=excluded.selected_price,divergence_pct=excluded.divergence_pct,primary_quote_id=excluded.primary_quote_id,crosscheck_quote_id=excluded.crosscheck_quote_id,provenance_status='PASS',price_gate='PASS',notes=excluded.notes;

  b_up := vr.bear_fv_per_share/sel_px-1;
  base_up := vr.base_fv_per_share/sel_px-1;
  bull_up := vr.bull_fv_per_share/sel_px-1;
  pw_up := vr.probability_weighted_fv_per_share/sel_px-1;
  if base_up>=pol.base_upside_min and pw_up>=pol.probability_weighted_upside_min then
    m_gate := 'PASS'; m_class := 'VERIFIED MISPRICING';
  else
    m_gate := 'FAIL - INSUFFICIENT MISPRICING'; m_class := 'GOOD COMPANY - WAIT FOR VALUE';
  end if;

  insert into fwios.valuation_mispricing_snapshots(mispricing_snapshot_id,valuation_run_id,ticker,price_snapshot_id,policy_id,current_price,bear_fv_per_share,base_fv_per_share,bull_fv_per_share,probability_weighted_fv_per_share,bear_upside,base_upside,bull_upside,probability_weighted_upside,reward_risk,mispricing_gate,mispricing_class,mispricing_note)
  values(mis_id,vr.run_id,p_ticker,snap_id,pol.policy_id,sel_px,vr.bear_fv_per_share,vr.base_fv_per_share,vr.bull_fv_per_share,vr.probability_weighted_fv_per_share,b_up,base_up,bull_up,pw_up,null,m_gate,m_class,'Tier-A dual-source historical close '||p_session_date||'; selected price '||round(sel_px,6)||'. Current ranking still requires a fresh production price snapshot.')
  on conflict(valuation_run_id,price_snapshot_id,policy_id) do update set current_price=excluded.current_price,bear_upside=excluded.bear_upside,base_upside=excluded.base_upside,bull_upside=excluded.bull_upside,probability_weighted_upside=excluded.probability_weighted_upside,mispricing_gate=excluded.mispricing_gate,mispricing_class=excluded.mispricing_class,mispricing_note=excluded.mispricing_note;

  return jsonb_build_object('ticker',p_ticker,'session_date',p_session_date,'cutover','PASS','price_snapshot_id',snap_id,'mispricing_snapshot_id',mis_id,'selected_price',sel_px,'divergence_pct',div_pct,'mispricing_gate',m_gate,'base_upside',base_up,'pw_upside',pw_up,'fresh_until',stale_at,'current_fresh',stale_at>now());
end $$;

revoke all on function fwios.cutover_shadow_price_historical_v1(text,date) from public,anon,authenticated;
grant execute on function fwios.cutover_shadow_price_historical_v1(text,date) to service_role;
