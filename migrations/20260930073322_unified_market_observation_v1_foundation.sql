
insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status,updated_at
) values (
  'MARKET_OBSERVATION','MARKET_DATA','Unified Market Observation Layer v1',
  'Canonicalize provider/time/session-aware price and FX observations while preserving existing decision-price, daily-close and portfolio-MTM semantics.',
  'fwios.market_observations','ACTIVE',now()
)
on conflict(policy_key) do update set
  policy_domain=excluded.policy_domain,policy_name=excluded.policy_name,purpose=excluded.purpose,
  backing_object=excluded.backing_object,lifecycle_status=excluded.lifecycle_status,updated_at=now();

insert into fwios.policy_versions(
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference,effective_at
) values (
  'POL-MARKET-OBSERVATION-V1','MARKET_OBSERVATION','1.0','ACTIVE',true,
  '{"production_read_cutover":false,"observation_types":["REGULAR_CLOSE","LIVE_QUOTE","PRE_MARKET","AFTER_HOURS","FX"],"canonical_instrument_required":true,"provider_provenance_required":true,"session_semantics_required":true,"manual_web_price_bypass":false,"legacy_price_consumers_preserved":true,"human_execution_only":true,"auto_trade":false}'::jsonb,
  'GitHub policies/market/MARKET_OBSERVATION_V1.md; Epic #31 Issue #36',now()
)
on conflict(policy_version_id) do update set
  lifecycle_status=excluded.lifecycle_status,deterministic_scoring=excluded.deterministic_scoring,
  config=excluded.config,source_reference=excluded.source_reference,effective_at=excluded.effective_at;

create table fwios.market_observations (
  observation_id uuid primary key default gen_random_uuid(),
  observation_key text not null unique,
  instrument_id uuid not null references fwios.instruments(instrument_id) on delete restrict,
  observation_type text not null check (observation_type in ('REGULAR_CLOSE','LIVE_QUOTE','PRE_MARKET','AFTER_HOURS','FX')),
  observation_value numeric not null check (observation_value>0),
  value_currency text not null,
  fx_base_currency text,
  fx_quote_currency text,
  session_date date,
  observed_at timestamptz not null,
  market_status text,
  provider text not null,
  source_tier text not null,
  source_url text,
  provenance_status text not null default 'PASS' check (provenance_status in ('PASS','BLOCKED')),
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (
    (observation_type='FX' and fx_base_currency is not null and fx_quote_currency is not null)
    or (observation_type<>'FX' and fx_base_currency is null and fx_quote_currency is null)
  )
);

create index market_observations_instrument_session_idx on fwios.market_observations(instrument_id,session_date,observation_type);
create index market_observations_provider_time_idx on fwios.market_observations(provider,observed_at desc);

create table fwios.market_observation_legacy_links (
  source_table text not null,
  source_key text not null,
  link_role text not null,
  observation_id uuid not null references fwios.market_observations(observation_id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key(source_table,source_key,link_role)
);
create index market_observation_legacy_links_observation_idx on fwios.market_observation_legacy_links(observation_id);

create table fwios.market_verification_sets (
  verification_id text primary key,
  verification_scope text not null check (verification_scope in ('DECISION_PRICE','DAILY_CLOSE')),
  instrument_id uuid not null references fwios.instruments(instrument_id) on delete restrict,
  session_date date not null,
  primary_observation_id uuid not null references fwios.market_observations(observation_id) on delete restrict,
  secondary_observation_id uuid references fwios.market_observations(observation_id) on delete restrict,
  selected_observation_id uuid references fwios.market_observations(observation_id) on delete restrict,
  selected_value numeric not null check(selected_value>0),
  divergence_pct numeric,
  max_allowed_divergence_pct numeric,
  conflict_status text,
  verification_status text,
  gate text not null,
  source_table text not null,
  source_key text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index market_verification_sets_instrument_session_idx on fwios.market_verification_sets(instrument_id,session_date,verification_scope);

alter table fwios.market_observations enable row level security;
alter table fwios.market_observation_legacy_links enable row level security;
alter table fwios.market_verification_sets enable row level security;
revoke all on fwios.market_observations from public,anon,authenticated;
revoke all on fwios.market_observation_legacy_links from public,anon,authenticated;
revoke all on fwios.market_verification_sets from public,anon,authenticated;
grant select,insert on fwios.market_observations to service_role;
grant select,insert,update on fwios.market_observation_legacy_links to service_role;
grant select,insert,update on fwios.market_verification_sets to service_role;

create or replace function fwios.market_observation_append_only_guard_v1()
returns trigger language plpgsql set search_path to '' as $f$
begin
  raise exception 'FWIOS market observations are immutable; % is not allowed on %.%',TG_OP,TG_TABLE_SCHEMA,TG_TABLE_NAME;
end
$f$;
create trigger market_observations_append_only
before update or delete on fwios.market_observations
for each row execute function fwios.market_observation_append_only_guard_v1();

create or replace function fwios.market_observation_type_v1(p_price_type text,p_market_status text)
returns text language sql immutable set search_path to '' as $f$
select case
  when upper(coalesce(p_price_type,''))='REGULAR_CLOSE' then 'REGULAR_CLOSE'
  when upper(coalesce(p_price_type,''))='AFTER_HOURS' or upper(coalesce(p_market_status,''))='AFTER_HOURS' then 'AFTER_HOURS'
  when upper(coalesce(p_market_status,''))='PRE_MARKET' then 'PRE_MARKET'
  else 'LIVE_QUOTE'
end
$f$;

create or replace function fwios.ensure_market_observation_v1(
  p_instrument_id uuid,p_observation_type text,p_value numeric,p_value_currency text,
  p_session_date date,p_observed_at timestamptz,p_market_status text,p_provider text,
  p_source_tier text,p_source_url text,p_provenance_status text,p_raw_payload jsonb,
  p_fx_base_currency text default null,p_fx_quote_currency text default null
)
returns uuid language plpgsql set search_path to 'pg_catalog','fwios' as $f$
declare v_key text; v_id uuid; v_time_key text;
begin
  if p_instrument_id is null then raise exception 'market observation instrument_id required'; end if;
  if p_value is null or p_value<=0 then raise exception 'market observation positive value required'; end if;
  if p_observation_type not in ('REGULAR_CLOSE','LIVE_QUOTE','PRE_MARKET','AFTER_HOURS','FX') then raise exception 'invalid market observation type'; end if;
  if p_observation_type='FX' and (p_fx_base_currency is null or p_fx_quote_currency is null) then raise exception 'FX currencies required'; end if;
  v_time_key:=case when p_observation_type='REGULAR_CLOSE' then coalesce(p_session_date::text,'') else coalesce(extract(epoch from p_observed_at)::text,'') end;
  v_key:=p_observation_type||':'||p_instrument_id::text||':'||upper(coalesce(p_provider,''))||':'||
         coalesce(p_session_date::text,'')||':'||v_time_key||':'||p_value::text||':'||
         upper(coalesce(p_value_currency,''))||':'||upper(coalesce(p_fx_base_currency,''))||':'||upper(coalesce(p_fx_quote_currency,''));
  insert into fwios.market_observations(
    observation_key,instrument_id,observation_type,observation_value,value_currency,
    fx_base_currency,fx_quote_currency,session_date,observed_at,market_status,provider,
    source_tier,source_url,provenance_status,raw_payload
  ) values (
    v_key,p_instrument_id,p_observation_type,p_value,upper(p_value_currency),
    case when p_observation_type='FX' then upper(p_fx_base_currency) else null end,
    case when p_observation_type='FX' then upper(p_fx_quote_currency) else null end,
    p_session_date,p_observed_at,p_market_status,p_provider,p_source_tier,p_source_url,
    coalesce(p_provenance_status,'PASS'),coalesce(p_raw_payload,'{}'::jsonb)
  ) on conflict(observation_key) do nothing;
  select observation_id into v_id from fwios.market_observations where observation_key=v_key;
  return v_id;
end
$f$;

alter table fwios.market_price_quotes
  add column market_observation_id uuid references fwios.market_observations(observation_id) on delete restrict;
alter table fwios.market_daily_closes
  add column primary_observation_id uuid references fwios.market_observations(observation_id) on delete restrict,
  add column secondary_observation_id uuid references fwios.market_observations(observation_id) on delete restrict,
  add column market_verification_id text references fwios.market_verification_sets(verification_id) on delete restrict;
alter table fwios.market_price_snapshots
  add column primary_observation_id uuid references fwios.market_observations(observation_id) on delete restrict,
  add column crosscheck_observation_id uuid references fwios.market_observations(observation_id) on delete restrict,
  add column selected_observation_id uuid references fwios.market_observations(observation_id) on delete restrict,
  add column market_verification_id text references fwios.market_verification_sets(verification_id) on delete restrict;
alter table fwios.portfolio_market_quote_snapshots
  add column instrument_id uuid references fwios.instruments(instrument_id) on delete restrict,
  add column market_observation_id uuid references fwios.market_observations(observation_id) on delete restrict,
  add column fx_observation_id uuid references fwios.market_observations(observation_id) on delete restrict;

create index market_price_quotes_market_observation_idx on fwios.market_price_quotes(market_observation_id);
create index market_daily_closes_primary_observation_idx on fwios.market_daily_closes(primary_observation_id);
create index market_price_snapshots_primary_observation_idx on fwios.market_price_snapshots(primary_observation_id);
create index portfolio_market_quote_snapshots_instrument_idx on fwios.portfolio_market_quote_snapshots(instrument_id);
create index portfolio_market_quote_snapshots_market_observation_idx on fwios.portfolio_market_quote_snapshots(market_observation_id);
