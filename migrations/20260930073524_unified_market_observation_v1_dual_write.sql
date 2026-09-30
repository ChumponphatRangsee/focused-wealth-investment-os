
create or replace function fwios.sync_market_price_quote_observation_v1()
returns trigger language plpgsql set search_path to 'pg_catalog','fwios' as $f$
begin
  if new.instrument_id is null then
    new.instrument_id:=fwios.resolve_instrument_id_v1(new.asset_symbol,new.asset_class,null,null);
  end if;
  if new.instrument_id is null then raise exception 'unresolved market quote identity % %',new.asset_class,new.asset_symbol; end if;
  new.market_observation_id:=fwios.ensure_market_observation_v1(
    new.instrument_id,fwios.market_observation_type_v1(new.price_type,new.market_status),
    new.price,new.currency,new.session_date,coalesce(new.quote_at,new.retrieved_at,new.created_at,now()),
    new.market_status,new.source_provider,new.source_tier,new.source_url,new.provenance_status,
    coalesce(new.raw_payload,'{}'::jsonb)||jsonb_build_object('legacy_source_table','fwios.market_price_quotes','legacy_quote_id',new.quote_id)
  );
  insert into fwios.market_observation_legacy_links(source_table,source_key,link_role,observation_id)
  values('fwios.market_price_quotes',new.quote_id,'PRICE',new.market_observation_id)
  on conflict(source_table,source_key,link_role) do update set observation_id=excluded.observation_id;
  return new;
end
$f$;

create trigger sync_market_price_quote_observation
before insert or update of asset_symbol,asset_class,price,price_type,market_status,session_date,quote_at,
  source_provider,source_tier,source_url,provenance_status,raw_payload
on fwios.market_price_quotes
for each row execute function fwios.sync_market_price_quote_observation_v1();

create or replace function fwios.sync_market_daily_close_observation_v1()
returns trigger language plpgsql set search_path to 'pg_catalog','fwios' as $f$
declare v_key text;
begin
  if new.instrument_id is null then
    new.instrument_id:=fwios.resolve_instrument_id_v1(new.asset_symbol,'Stock',null,null);
  end if;
  if new.instrument_id is null then raise exception 'unresolved daily close identity %',new.asset_symbol; end if;

  new.primary_observation_id:=fwios.ensure_market_observation_v1(
    new.instrument_id,'REGULAR_CLOSE',new.close_price,coalesce(new.currency,'USD'),new.session_date,
    ((new.session_date::text||' 16:00 America/New_York')::timestamptz),'CLOSED',
    new.primary_provider,new.source_tier,new.source_url,new.provenance_status,
    coalesce(new.raw_payload,'{}'::jsonb)||jsonb_build_object('legacy_source_table','fwios.market_daily_closes','legacy_role','PRIMARY')
  );

  if new.secondary_provider is not null and new.secondary_close is not null then
    new.secondary_observation_id:=fwios.ensure_market_observation_v1(
      new.instrument_id,'REGULAR_CLOSE',new.secondary_close,coalesce(new.currency,'USD'),new.session_date,
      ((new.session_date::text||' 16:00 America/New_York')::timestamptz),'CLOSED',
      new.secondary_provider,new.source_tier,new.source_url,new.provenance_status,
      coalesce(new.raw_payload,'{}'::jsonb)||jsonb_build_object('legacy_source_table','fwios.market_daily_closes','legacy_role','SECONDARY')
    );
  else
    new.secondary_observation_id:=null;
  end if;

  v_key:=new.asset_symbol||'|'||new.session_date::text;
  new.market_verification_id:='DCL:'||new.asset_symbol||':'||new.session_date::text;

  insert into fwios.market_observation_legacy_links(source_table,source_key,link_role,observation_id)
  values('fwios.market_daily_closes',v_key,'PRIMARY',new.primary_observation_id)
  on conflict(source_table,source_key,link_role) do update set observation_id=excluded.observation_id;

  if new.secondary_observation_id is not null then
    insert into fwios.market_observation_legacy_links(source_table,source_key,link_role,observation_id)
    values('fwios.market_daily_closes',v_key,'SECONDARY',new.secondary_observation_id)
    on conflict(source_table,source_key,link_role) do update set observation_id=excluded.observation_id;
  end if;

  insert into fwios.market_verification_sets(
    verification_id,verification_scope,instrument_id,session_date,primary_observation_id,
    secondary_observation_id,selected_observation_id,selected_value,divergence_pct,max_allowed_divergence_pct,
    conflict_status,verification_status,gate,source_table,source_key,metadata
  ) values (
    new.market_verification_id,'DAILY_CLOSE',new.instrument_id,new.session_date,new.primary_observation_id,
    new.secondary_observation_id,new.primary_observation_id,new.close_price,new.divergence_pct,0.005,
    case when new.verification_status='CONFLICT' then 'CONFLICT'
         when new.secondary_observation_id is null then 'NO_CROSSCHECK' else 'PASS' end,
    new.verification_status,
    case when new.provenance_status<>'PASS' then 'BLOCKED - PROVENANCE'
         when new.verification_status='CONFLICT' then 'BLOCKED - PRICE CONFLICT'
         else 'PASS' end,
    'fwios.market_daily_closes',v_key,
    jsonb_build_object('primary_provider',new.primary_provider,'secondary_provider',new.secondary_provider)
  )
  on conflict(verification_id) do update set
    primary_observation_id=excluded.primary_observation_id,
    secondary_observation_id=excluded.secondary_observation_id,
    selected_observation_id=excluded.selected_observation_id,
    selected_value=excluded.selected_value,
    divergence_pct=excluded.divergence_pct,
    conflict_status=excluded.conflict_status,
    verification_status=excluded.verification_status,
    gate=excluded.gate,metadata=excluded.metadata,updated_at=now();

  return new;
end
$f$;

create trigger sync_market_daily_close_observation
before insert or update of asset_symbol,session_date,close_price,currency,primary_provider,source_url,source_tier,
  verification_status,secondary_provider,secondary_close,divergence_pct,provenance_status,raw_payload
on fwios.market_daily_closes
for each row execute function fwios.sync_market_daily_close_observation_v1();

create or replace function fwios.sync_market_price_snapshot_observation_v1()
returns trigger language plpgsql set search_path to 'pg_catalog','fwios' as $f$
declare q1 fwios.market_price_quotes%rowtype; q2 fwios.market_price_quotes%rowtype;
begin
  if new.instrument_id is null then new.instrument_id:=fwios.resolve_instrument_id_v1(new.asset_symbol,new.asset_class,null,null); end if;
  if new.instrument_id is null then raise exception 'unresolved price snapshot identity %',new.asset_symbol; end if;
  select * into q1 from fwios.market_price_quotes where quote_id=new.primary_quote_id;
  if q1.quote_id is null or q1.market_observation_id is null then raise exception 'primary quote canonical observation missing %',new.primary_quote_id; end if;
  new.primary_observation_id:=q1.market_observation_id;
  if new.crosscheck_quote_id is not null then
    select * into q2 from fwios.market_price_quotes where quote_id=new.crosscheck_quote_id;
    new.crosscheck_observation_id:=q2.market_observation_id;
  else new.crosscheck_observation_id:=null;
  end if;
  new.selected_observation_id:=case
    when new.selected_price=q1.price then q1.market_observation_id
    when q2.quote_id is not null and new.selected_price=q2.price then q2.market_observation_id
    else null end;
  new.market_verification_id:='DPR:'||new.snapshot_id;

  insert into fwios.market_verification_sets(
    verification_id,verification_scope,instrument_id,session_date,primary_observation_id,
    secondary_observation_id,selected_observation_id,selected_value,divergence_pct,max_allowed_divergence_pct,
    conflict_status,verification_status,gate,source_table,source_key,metadata
  ) values (
    new.market_verification_id,'DECISION_PRICE',new.instrument_id,new.session_date,new.primary_observation_id,
    new.crosscheck_observation_id,new.selected_observation_id,new.selected_price,new.divergence_pct,new.max_allowed_divergence_pct,
    new.conflict_status,case when new.price_gate='PASS' then 'VERIFIED' else 'BLOCKED' end,new.price_gate,
    'fwios.market_price_snapshots',new.snapshot_id,
    jsonb_build_object('legacy_primary_quote_id',new.primary_quote_id,'legacy_crosscheck_quote_id',new.crosscheck_quote_id)
  )
  on conflict(verification_id) do update set
    primary_observation_id=excluded.primary_observation_id,
    secondary_observation_id=excluded.secondary_observation_id,
    selected_observation_id=excluded.selected_observation_id,
    selected_value=excluded.selected_value,
    divergence_pct=excluded.divergence_pct,
    max_allowed_divergence_pct=excluded.max_allowed_divergence_pct,
    conflict_status=excluded.conflict_status,
    verification_status=excluded.verification_status,
    gate=excluded.gate,metadata=excluded.metadata,updated_at=now();
  return new;
end
$f$;

create trigger sync_market_price_snapshot_observation
before insert or update of asset_symbol,asset_class,primary_quote_id,crosscheck_quote_id,selected_price,currency,
  session_date,market_status,divergence_pct,max_allowed_divergence_pct,conflict_status,provenance_status,price_gate
on fwios.market_price_snapshots
for each row execute function fwios.sync_market_price_snapshot_observation_v1();

create or replace function fwios.sync_portfolio_market_quote_observation_v1()
returns trigger language plpgsql set search_path to 'pg_catalog','fwios' as $f$
declare v_fx_at timestamptz;
begin
  if new.instrument_id is null then new.instrument_id:=fwios.resolve_instrument_id_v1(new.asset_symbol,new.asset_class,null,null); end if;
  if new.instrument_id is null then raise exception 'unresolved portfolio quote identity % %',new.asset_class,new.asset_symbol; end if;

  new.market_observation_id:=fwios.ensure_market_observation_v1(
    new.instrument_id,
    case when upper(coalesce(new.market_status,''))='PRE_MARKET' then 'PRE_MARKET'
         when upper(coalesce(new.market_status,''))='AFTER_HOURS' then 'AFTER_HOURS'
         else 'LIVE_QUOTE' end,
    new.price_native,new.native_currency,
    case when new.asset_class='Stock' then (new.observed_at at time zone 'America/New_York')::date else new.observed_at::date end,
    new.observed_at,new.market_status,new.provider,new.source_tier,null,new.provenance_status,
    coalesce(new.raw_payload,'{}'::jsonb)||jsonb_build_object('legacy_source_table','fwios.portfolio_market_quote_snapshots','legacy_quote_id',new.quote_id::text)
  );

  if new.fx_rate_thb is not null and new.native_currency<>'THB' then
    v_fx_at:=coalesce(
      case when (new.raw_payload->'fx_payload'->>'timestamp') ~ '^[0-9]+$'
           then to_timestamp((new.raw_payload->'fx_payload'->>'timestamp')::double precision) else null end,
      new.observed_at
    );
    new.fx_observation_id:=fwios.ensure_market_observation_v1(
      new.instrument_id,'FX',new.fx_rate_thb,'THB',new.observed_at::date,v_fx_at,'FX',
      coalesce(new.raw_payload->>'fx_provider',new.provider||'_FX'),new.source_tier,null,new.provenance_status,
      coalesce(new.raw_payload->'fx_payload','{}'::jsonb)||
        jsonb_build_object('legacy_source_table','fwios.portfolio_market_quote_snapshots','legacy_quote_id',new.quote_id::text),
      new.native_currency,'THB'
    );
  else new.fx_observation_id:=null;
  end if;

  insert into fwios.market_observation_legacy_links(source_table,source_key,link_role,observation_id)
  values('fwios.portfolio_market_quote_snapshots',new.quote_id::text,'PRICE',new.market_observation_id)
  on conflict(source_table,source_key,link_role) do update set observation_id=excluded.observation_id;

  if new.fx_observation_id is not null then
    insert into fwios.market_observation_legacy_links(source_table,source_key,link_role,observation_id)
    values('fwios.portfolio_market_quote_snapshots',new.quote_id::text,'FX',new.fx_observation_id)
    on conflict(source_table,source_key,link_role) do update set observation_id=excluded.observation_id;
  end if;
  return new;
end
$f$;

create trigger sync_portfolio_market_quote_observation
before insert or update of asset_symbol,asset_class,price_native,native_currency,fx_rate_thb,price_thb,provider,
  source_tier,observed_at,valid_until,market_status,provenance_status,raw_payload
on fwios.portfolio_market_quote_snapshots
for each row execute function fwios.sync_portfolio_market_quote_observation_v1();

with tests(test_case,passed,notes) as (
  values
  ('policy active / no read cutover',
    exists(select 1 from fwios.policy_versions where policy_version_id='POL-MARKET-OBSERVATION-V1'
      and lifecycle_status='ACTIVE' and config->>'production_read_cutover'='false'
      and config->>'manual_web_price_bypass'='false' and config->>'auto_trade'='false'),
    'Additive market foundation only.'),
  ('legacy market identity complete',
    not exists(select 1 from fwios.market_daily_closes where instrument_id is null)
    and not exists(select 1 from fwios.market_price_quotes where instrument_id is null)
    and not exists(select 1 from fwios.market_price_snapshots where instrument_id is null)
    and not exists(select 1 from fwios.portfolio_market_quote_snapshots where instrument_id is null),
    'All current market layers resolve to canonical identity.'),
  ('decision quotes mapped to observations',
    not exists(select 1 from fwios.market_price_quotes where market_observation_id is null),
    'Every decision quote has a canonical observation ID.'),
  ('daily closes mapped to observations',
    not exists(select 1 from fwios.market_daily_closes where primary_observation_id is null)
    and not exists(select 1 from fwios.market_daily_closes where secondary_close is not null and secondary_observation_id is null),
    'Daily-close provider evidence is explicit.'),
  ('decision snapshots consume observation IDs',
    not exists(select 1 from fwios.market_price_snapshots where primary_observation_id is null or market_verification_id is null),
    'Decision-price verification references observations.'),
  ('portfolio MTM mapped to observations',
    not exists(select 1 from fwios.portfolio_market_quote_snapshots where market_observation_id is null),
    'Portfolio quotes reuse canonical observations.'),
  ('portfolio FX observations mapped',
    not exists(select 1 from fwios.portfolio_market_quote_snapshots where native_currency<>'THB' and fx_rate_thb is not null and fx_observation_id is null),
    'FX conversion observations are explicit.'),
  ('PINS Sep04 primary and secondary separate',
    exists(select 1 from fwios.market_price_snapshots s
      join fwios.market_observations p on p.observation_id=s.primary_observation_id
      join fwios.market_observations x on x.observation_id=s.crosscheck_observation_id
      where s.snapshot_id='PX-PINS-QHREVAL-20260906' and p.observation_id<>x.observation_id
        and p.observation_value=20.28 and x.observation_value=20.30),
    'PINS source observations remain separate.'),
  ('PINS Sep04 verified price parity',
    exists(select 1 from fwios.market_price_snapshots where snapshot_id='PX-PINS-QHREVAL-20260906'
      and selected_price=20.28 and abs(divergence_pct-0.000986193293885602)<0.000000000001
      and conflict_status='PASS' and price_gate='PASS'),
    'Verified price output unchanged.'),
  ('PINS Sep10 conflict parity',
    exists(select 1 from fwios.market_price_snapshots where snapshot_id='PX-PINS-20260910'
      and selected_price=18.655 and abs(divergence_pct-0.012597158938622352)<0.000000000001
      and conflict_status='CONFLICT' and price_gate='BLOCKED - PRICE CONFLICT'),
    'Fail-closed conflict unchanged.'),
  ('core observation types live',
    exists(select 1 from fwios.market_observations where observation_type='REGULAR_CLOSE')
    and exists(select 1 from fwios.market_observations where observation_type='LIVE_QUOTE')
    and exists(select 1 from fwios.market_observations where observation_type='FX'),
    'Current data exercises close, live quote and FX; schema supports pre/after-hours.'),
  ('private RLS enabled',
    not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='fwios' and c.relname in ('market_observations','market_observation_legacy_links','market_verification_sets')
        and c.relrowsecurity=false),
    'Canonical market tables are private.'),
  ('dual-write triggers installed',
    (select count(*) from pg_trigger where tgrelid in (
      'fwios.market_price_quotes'::regclass,'fwios.market_daily_closes'::regclass,
      'fwios.market_price_snapshots'::regclass,'fwios.portfolio_market_quote_snapshots'::regclass)
      and not tgisinternal and tgname in (
      'sync_market_price_quote_observation','sync_market_daily_close_observation',
      'sync_market_price_snapshot_observation','sync_portfolio_market_quote_observation'))=4,
    'Future legacy writes dual-write canonical observations.'),
  ('human execution only',
    (select config->>'human_execution_only'='true' from fwios.policy_versions where policy_version_id='POL-MARKET-OBSERVATION-V1'),
    'Market layer cannot trade.')
), numbered as (
  select row_number() over(order by test_case) n,* from tests
)
insert into fwios.decision_policy_regression_runs(
  regression_id,policy_key,policy_version_id,test_case,input_payload,expected_payload,actual_payload,status,tolerance,notes
)
select 'REG-MARKET-OBS-V1-'||lpad(n::text,2,'0'),'MARKET_OBSERVATION','POL-MARKET-OBSERVATION-V1',
  test_case,'{}'::jsonb,'{"passed":true}'::jsonb,jsonb_build_object('passed',passed),
  case when passed then 'PASS' else 'FAIL' end,null,notes
from numbered
on conflict(regression_id) do update set
  expected_payload=excluded.expected_payload,actual_payload=excluded.actual_payload,status=excluded.status,notes=excluded.notes;
