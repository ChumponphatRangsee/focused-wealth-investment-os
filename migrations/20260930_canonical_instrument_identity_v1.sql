-- Canonical Instrument Identity v1
-- Epic #31 / Issue #33
-- Additive identity foundation. Legacy ticker / asset_symbol columns and production read paths remain authoritative.
-- No portfolio, decision, approval or trade mutation is introduced.

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status,updated_at
) values (
  'INSTRUMENT_IDENTITY',
  'IDENTITY',
  'Canonical Instrument Identity v1',
  'Provide immutable instrument identity, entity separation, symbol history and fail-closed symbol resolution while preserving legacy symbol compatibility.',
  'fwios.resolve_instrument_id_v1',
  'ACTIVE',
  now()
)
on conflict(policy_key) do update set
  policy_domain=excluded.policy_domain,
  policy_name=excluded.policy_name,
  purpose=excluded.purpose,
  backing_object=excluded.backing_object,
  lifecycle_status=excluded.lifecycle_status,
  updated_at=now();

insert into fwios.policy_versions(
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference,effective_at
) values (
  'POL-INSTRUMENT-IDENTITY-V1',
  'INSTRUMENT_IDENTITY',
  '1.0',
  'ACTIVE',
  true,
  $json$
  {
    "instrument_id_immutable": true,
    "entity_separate_from_instrument": true,
    "legacy_ticker_preserved": true,
    "legacy_asset_symbol_preserved": true,
    "production_read_cutover": false,
    "ticker_change_policy": "retain instrument_id when the same tradable legal instrument changes symbol; close old symbol history row and open the new row",
    "share_class_policy": "separate instrument_id per tradable share class; multiple instruments may reference one entity_id",
    "delisting_policy": "retain instrument_id and history; set instrument status DELISTED/INACTIVE and close active symbol row",
    "relisting_policy": "reuse instrument_id only when the same legal instrument returns; create a new instrument_id for a legally new security",
    "multi_exchange_policy": "distinct tradable listings use distinct instrument_id values and may share one entity_id",
    "crypto_collision_policy": "symbol is never sufficient identity; symbol_namespace and durable external identifiers must distinguish colliding symbols",
    "resolver_policy": "ambiguous or missing symbol resolution returns NULL rather than guessing",
    "human_execution_only": true,
    "auto_trade": false
  }
  $json$::jsonb,
  'GitHub policies/identity/INSTRUMENT_IDENTITY_V1.md; Epic #31 Issue #33',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status=excluded.lifecycle_status,
  deterministic_scoring=excluded.deterministic_scoring,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

create table if not exists fwios.asset_entities (
  entity_id uuid primary key default gen_random_uuid(),
  entity_type text not null
    check (entity_type in ('COMPANY','NETWORK','PROTOCOL','FUND','OTHER')),
  display_name text not null,
  sector text,
  industry text,
  country_code text,
  legacy_seed_key text unique,
  metadata jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists fwios.instruments (
  instrument_id uuid primary key default gen_random_uuid(),
  entity_id uuid references fwios.asset_entities(entity_id) on delete restrict,
  asset_class text not null,
  instrument_type text not null,
  primary_venue text not null default 'UNSPECIFIED',
  trading_currency text,
  lifecycle_status text not null default 'ACTIVE'
    check (lifecycle_status in ('ACTIVE','INACTIVE','DELISTED')),
  legacy_seed_key text unique,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(trim(asset_class))>0),
  check (length(trim(instrument_type))>0),
  check (length(trim(primary_venue))>0)
);

create index if not exists instruments_entity_idx
  on fwios.instruments(entity_id);

create table if not exists fwios.instrument_symbols (
  instrument_symbol_id uuid primary key default gen_random_uuid(),
  instrument_id uuid not null references fwios.instruments(instrument_id) on delete restrict,
  symbol text not null,
  venue text not null,
  symbol_namespace text not null default 'DEFAULT',
  is_primary boolean not null default true,
  active boolean not null default true,
  valid_from date,
  valid_to date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(trim(symbol))>0),
  check (length(trim(venue))>0),
  check (length(trim(symbol_namespace))>0),
  check (valid_to is null or valid_from is null or valid_to>=valid_from)
);

create unique index if not exists instrument_symbols_active_identity_uidx
  on fwios.instrument_symbols(
    upper(symbol),
    upper(venue),
    upper(symbol_namespace)
  )
  where active=true and valid_to is null;

create unique index if not exists instrument_symbols_one_primary_current_uidx
  on fwios.instrument_symbols(instrument_id)
  where active=true and valid_to is null and is_primary=true;

create index if not exists instrument_symbols_lookup_idx
  on fwios.instrument_symbols(upper(symbol),instrument_id)
  where active=true and valid_to is null;

create table if not exists fwios.instrument_identifiers (
  identifier_id uuid primary key default gen_random_uuid(),
  instrument_id uuid not null references fwios.instruments(instrument_id) on delete restrict,
  identifier_type text not null,
  identifier_namespace text not null default 'INTERNAL',
  identifier_value text not null,
  provider text,
  is_primary boolean not null default false,
  active boolean not null default true,
  valid_from date,
  valid_to date,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (length(trim(identifier_type))>0),
  check (length(trim(identifier_namespace))>0),
  check (length(trim(identifier_value))>0),
  check (valid_to is null or valid_from is null or valid_to>=valid_from)
);

create unique index if not exists instrument_identifiers_active_uidx
  on fwios.instrument_identifiers(
    upper(identifier_type),
    upper(identifier_namespace),
    upper(identifier_value)
  )
  where active=true and valid_to is null;

create index if not exists instrument_identifiers_instrument_idx
  on fwios.instrument_identifiers(instrument_id);

alter table fwios.asset_entities enable row level security;
alter table fwios.instruments enable row level security;
alter table fwios.instrument_symbols enable row level security;
alter table fwios.instrument_identifiers enable row level security;

revoke all on fwios.asset_entities from public,anon,authenticated;
revoke all on fwios.instruments from public,anon,authenticated;
revoke all on fwios.instrument_symbols from public,anon,authenticated;
revoke all on fwios.instrument_identifiers from public,anon,authenticated;

grant select,insert,update,delete on fwios.asset_entities to service_role;
grant select,insert,update,delete on fwios.instruments to service_role;
grant select,insert,update,delete on fwios.instrument_symbols to service_role;
grant select,insert,update,delete on fwios.instrument_identifiers to service_role;

-- Seed one entity per current legacy symbol+asset-class pair.
-- This is a migration convenience, not a permanent one-instrument-per-entity rule.
with universe as (
  select upper(ticker) symbol,'Stock'::text asset_class from fwios.companies
  union
  select upper(ticker),'Stock' from fwios.research_candidates
  union
  select upper(ticker),'Stock' from fwios.thesis_registry
  union
  select upper(asset_symbol),asset_class from fwios.portfolio_assets
  union
  select upper(asset_symbol),asset_class from fwios.portfolio_transactions
  union
  select upper(asset_symbol),asset_class from fwios.market_price_quotes
  union
  select upper(asset_symbol),asset_class from fwios.market_price_snapshots
  union
  select upper(asset_symbol),'Stock' from fwios.market_daily_closes
),
seed as (
  select
    u.symbol,
    u.asset_class,
    upper(u.asset_class)||':'||u.symbol legacy_seed_key,
    case when u.asset_class='Crypto' then 'NETWORK' else 'COMPANY' end entity_type,
    coalesce(c.company_name,u.symbol) display_name,
    c.sector,
    c.archetype industry
  from universe u
  left join fwios.companies c
    on u.asset_class='Stock' and upper(c.ticker)=u.symbol
)
insert into fwios.asset_entities(
  entity_type,display_name,sector,industry,legacy_seed_key,metadata
)
select
  s.entity_type,
  s.display_name,
  s.sector,
  s.industry,
  s.legacy_seed_key,
  jsonb_build_object(
    'migration_source','CANONICAL_INSTRUMENT_IDENTITY_V1',
    'legacy_symbol',s.symbol,
    'legacy_asset_class',s.asset_class,
    'seed_only',true
  )
from seed s
on conflict(legacy_seed_key) do update set
  display_name=coalesce(nullif(excluded.display_name,''),fwios.asset_entities.display_name),
  sector=coalesce(excluded.sector,fwios.asset_entities.sector),
  industry=coalesce(excluded.industry,fwios.asset_entities.industry),
  updated_at=now();

-- Derive only evidence-backed listing metadata. Unknown is explicit rather than guessed.
with universe as (
  select upper(ticker) symbol,'Stock'::text asset_class from fwios.companies
  union
  select upper(ticker),'Stock' from fwios.research_candidates
  union
  select upper(ticker),'Stock' from fwios.thesis_registry
  union
  select upper(asset_symbol),asset_class from fwios.portfolio_assets
  union
  select upper(asset_symbol),asset_class from fwios.portfolio_transactions
  union
  select upper(asset_symbol),asset_class from fwios.market_price_quotes
  union
  select upper(asset_symbol),asset_class from fwios.market_price_snapshots
  union
  select upper(asset_symbol),'Stock' from fwios.market_daily_closes
),
market_meta_rows as (
  select upper(asset_symbol) symbol,'Stock'::text asset_class,exchange,currency
  from fwios.market_daily_closes
  union all
  select upper(asset_symbol),asset_class,exchange,currency
  from fwios.market_price_quotes
  union all
  select upper(asset_symbol),asset_class,null::text,currency
  from fwios.market_price_snapshots
  union all
  select upper(asset_symbol),asset_class,null::text,currency
  from fwios.portfolio_transactions
),
market_meta as (
  select
    symbol,
    asset_class,
    case
      when count(distinct exchange) filter(where exchange is not null)=1
        then min(exchange) filter(where exchange is not null)
      when asset_class='Crypto' then 'CRYPTO_NATIVE'
      else 'UNSPECIFIED'
    end primary_venue,
    case
      when asset_class='Crypto' then null::text
      when count(distinct currency) filter(where currency is not null)=1
        then min(currency) filter(where currency is not null)
      else null::text
    end trading_currency
  from market_meta_rows
  group by symbol,asset_class
),
seed as (
  select
    u.symbol,u.asset_class,
    upper(u.asset_class)||':'||u.symbol legacy_seed_key,
    coalesce(
      mm.primary_venue,
      case when u.asset_class='Crypto' then 'CRYPTO_NATIVE' else 'UNSPECIFIED' end
    ) primary_venue,
    mm.trading_currency
  from universe u
  left join market_meta mm
    on mm.symbol=u.symbol and mm.asset_class=u.asset_class
)
insert into fwios.instruments(
  entity_id,asset_class,instrument_type,primary_venue,trading_currency,
  lifecycle_status,legacy_seed_key,metadata
)
select
  e.entity_id,
  s.asset_class,
  case
    when s.asset_class='Stock' then 'COMMON_STOCK'
    when s.asset_class='Crypto' then 'CRYPTO_ASSET'
    else upper(replace(s.asset_class,' ','_'))
  end,
  s.primary_venue,
  s.trading_currency,
  'ACTIVE',
  s.legacy_seed_key,
  jsonb_build_object(
    'migration_source','CANONICAL_INSTRUMENT_IDENTITY_V1',
    'legacy_symbol',s.symbol,
    'legacy_asset_class',s.asset_class,
    'legacy_seed_key_non_authoritative',true
  )
from seed s
join fwios.asset_entities e on e.legacy_seed_key=s.legacy_seed_key
on conflict(legacy_seed_key) do update set
  entity_id=coalesce(fwios.instruments.entity_id,excluded.entity_id),
  primary_venue=case
    when fwios.instruments.primary_venue='UNSPECIFIED' then excluded.primary_venue
    else fwios.instruments.primary_venue
  end,
  trading_currency=coalesce(fwios.instruments.trading_currency,excluded.trading_currency),
  updated_at=now();

insert into fwios.instrument_symbols(
  instrument_id,symbol,venue,symbol_namespace,is_primary,active,metadata
)
select
  i.instrument_id,
  split_part(i.legacy_seed_key,':',2),
  i.primary_venue,
  case when i.asset_class='Crypto' then 'NATIVE' else 'LISTING' end,
  true,
  true,
  jsonb_build_object(
    'migration_source','CANONICAL_INSTRUMENT_IDENTITY_V1',
    'legacy_seed',true
  )
from fwios.instruments i
where i.legacy_seed_key is not null
on conflict do nothing;

insert into fwios.instrument_identifiers(
  instrument_id,identifier_type,identifier_namespace,identifier_value,
  provider,is_primary,active,metadata
)
select
  i.instrument_id,
  'LEGACY_SEED',
  'FWIOS',
  i.legacy_seed_key,
  'FWIOS',
  false,
  true,
  jsonb_build_object(
    'migration_source','CANONICAL_INSTRUMENT_IDENTITY_V1',
    'non_authoritative_external_identifier',true
  )
from fwios.instruments i
where i.legacy_seed_key is not null
on conflict do nothing;

create or replace function fwios.resolve_instrument_id_v1(
  p_symbol text,
  p_asset_class text default null,
  p_venue text default null,
  p_symbol_namespace text default null
)
returns uuid
language plpgsql
stable
set search_path to ''
as $function$
declare
  v_id uuid;
  v_count integer;
begin
  if nullif(trim(coalesce(p_symbol,'')),'') is null then
    return null;
  end if;

  select count(*),(array_agg(i.instrument_id order by i.instrument_id))[1]
    into v_count,v_id
  from fwios.instrument_symbols s
  join fwios.instruments i on i.instrument_id=s.instrument_id
  where s.active=true
    and s.valid_to is null
    and upper(s.symbol)=upper(trim(p_symbol))
    and (p_asset_class is null or upper(i.asset_class)=upper(trim(p_asset_class)))
    and (p_venue is null or upper(s.venue)=upper(trim(p_venue)))
    and (p_symbol_namespace is null or upper(s.symbol_namespace)=upper(trim(p_symbol_namespace)))
    and i.lifecycle_status<>'DELISTED';

  if v_count=1 then
    return v_id;
  end if;

  return null;
end
$function$;

create or replace function fwios.current_instrument_symbol_v1(p_instrument_id uuid)
returns text
language sql
stable
set search_path to ''
as $function$
  select s.symbol
  from fwios.instrument_symbols s
  where s.instrument_id=p_instrument_id
    and s.active=true
    and s.valid_to is null
    and s.is_primary=true
  order by s.created_at desc
  limit 1;
$function$;

revoke all on function fwios.resolve_instrument_id_v1(text,text,text,text)
  from public,anon,authenticated;
revoke all on function fwios.current_instrument_symbol_v1(uuid)
  from public,anon,authenticated;

grant execute on function fwios.resolve_instrument_id_v1(text,text,text,text)
  to service_role;
grant execute on function fwios.current_instrument_symbol_v1(uuid)
  to service_role;

-- Add nullable instrument references to selected migration anchors only.
alter table fwios.companies add column if not exists instrument_id uuid;
alter table fwios.research_candidates add column if not exists instrument_id uuid;
alter table fwios.thesis_registry add column if not exists instrument_id uuid;
alter table fwios.portfolio_assets add column if not exists instrument_id uuid;
alter table fwios.portfolio_transactions add column if not exists instrument_id uuid;
alter table fwios.market_daily_closes add column if not exists instrument_id uuid;
alter table fwios.market_price_quotes add column if not exists instrument_id uuid;
alter table fwios.market_price_snapshots add column if not exists instrument_id uuid;

alter table fwios.companies
  add constraint companies_instrument_id_fkey
  foreign key(instrument_id) references fwios.instruments(instrument_id) on delete restrict;
alter table fwios.research_candidates
  add constraint research_candidates_instrument_id_fkey
  foreign key(instrument_id) references fwios.instruments(instrument_id) on delete restrict;
alter table fwios.thesis_registry
  add constraint thesis_registry_instrument_id_fkey
  foreign key(instrument_id) references fwios.instruments(instrument_id) on delete restrict;
alter table fwios.portfolio_assets
  add constraint portfolio_assets_instrument_id_fkey
  foreign key(instrument_id) references fwios.instruments(instrument_id) on delete restrict;
alter table fwios.portfolio_transactions
  add constraint portfolio_transactions_instrument_id_fkey
  foreign key(instrument_id) references fwios.instruments(instrument_id) on delete restrict;
alter table fwios.market_daily_closes
  add constraint market_daily_closes_instrument_id_fkey
  foreign key(instrument_id) references fwios.instruments(instrument_id) on delete restrict;
alter table fwios.market_price_quotes
  add constraint market_price_quotes_instrument_id_fkey
  foreign key(instrument_id) references fwios.instruments(instrument_id) on delete restrict;
alter table fwios.market_price_snapshots
  add constraint market_price_snapshots_instrument_id_fkey
  foreign key(instrument_id) references fwios.instruments(instrument_id) on delete restrict;

create unique index if not exists companies_instrument_id_uidx
  on fwios.companies(instrument_id) where instrument_id is not null;
create unique index if not exists research_candidates_instrument_id_uidx
  on fwios.research_candidates(instrument_id) where instrument_id is not null;
create unique index if not exists thesis_registry_instrument_id_uidx
  on fwios.thesis_registry(instrument_id) where instrument_id is not null;
create unique index if not exists portfolio_assets_instrument_id_uidx
  on fwios.portfolio_assets(instrument_id) where instrument_id is not null;

create index if not exists portfolio_transactions_instrument_id_idx
  on fwios.portfolio_transactions(instrument_id);
create index if not exists market_daily_closes_instrument_id_idx
  on fwios.market_daily_closes(instrument_id,session_date desc);
create index if not exists market_price_quotes_instrument_id_idx
  on fwios.market_price_quotes(instrument_id,session_date desc);
create index if not exists market_price_snapshots_instrument_id_idx
  on fwios.market_price_snapshots(instrument_id,session_date desc);

update fwios.companies
set instrument_id=fwios.resolve_instrument_id_v1(ticker,'Stock',null,null)
where instrument_id is null;

update fwios.research_candidates
set instrument_id=fwios.resolve_instrument_id_v1(ticker,'Stock',null,null)
where instrument_id is null;

update fwios.thesis_registry
set instrument_id=fwios.resolve_instrument_id_v1(ticker,'Stock',null,null)
where instrument_id is null;

update fwios.portfolio_assets
set instrument_id=fwios.resolve_instrument_id_v1(asset_symbol,asset_class,null,null)
where instrument_id is null;

update fwios.portfolio_transactions
set instrument_id=fwios.resolve_instrument_id_v1(asset_symbol,asset_class,null,null)
where instrument_id is null;

update fwios.market_daily_closes
set instrument_id=fwios.resolve_instrument_id_v1(asset_symbol,'Stock',null,null)
where instrument_id is null;

update fwios.market_price_quotes
set instrument_id=fwios.resolve_instrument_id_v1(asset_symbol,asset_class,null,null)
where instrument_id is null;

update fwios.market_price_snapshots
set instrument_id=fwios.resolve_instrument_id_v1(asset_symbol,asset_class,null,null)
where instrument_id is null;

create or replace view fwios.v_instrument_identity_current
with (security_invoker=true)
as
select
  i.instrument_id,
  i.entity_id,
  e.entity_type,
  e.display_name entity_name,
  i.asset_class,
  i.instrument_type,
  i.lifecycle_status,
  s.symbol asset_symbol,
  case when i.asset_class='Stock' then s.symbol end ticker,
  s.venue exchange,
  i.trading_currency currency,
  s.symbol_namespace,
  i.primary_venue,
  i.metadata instrument_metadata,
  e.metadata entity_metadata
from fwios.instruments i
join fwios.instrument_symbols s
  on s.instrument_id=i.instrument_id
 and s.active=true
 and s.valid_to is null
 and s.is_primary=true
left join fwios.asset_entities e
  on e.entity_id=i.entity_id;

revoke all on fwios.v_instrument_identity_current from public,anon,authenticated;
grant select on fwios.v_instrument_identity_current to service_role;

-- Identity regression registrations.
with tests(test_case,passed,notes) as (
  values
    ('70 seeded canonical instruments',
      (select count(*)=70 from fwios.instruments where legacy_seed_key is not null),
      '64 Stock + 6 Crypto expected from the current legacy universe.'),
    ('ADBE resolves deterministically',
      fwios.resolve_instrument_id_v1('ADBE','Stock',null,null)
        =(select instrument_id from fwios.companies where ticker='ADBE'),
      'Ticker is compatibility only; resolver returns one immutable instrument_id.'),
    ('PINS resolves deterministically',
      fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
        =(select instrument_id from fwios.companies where ticker='PINS'),
      'PINS identity parity.'),
    ('BTC resolves deterministically',
      fwios.resolve_instrument_id_v1('BTC','Crypto',null,null)
        =(select instrument_id from fwios.portfolio_assets where asset_symbol='BTC'),
      'Crypto symbol resolves only because the current active namespace is unambiguous.'),
    ('selected legacy anchors fully backfilled',
      not exists(
        select 1 from fwios.companies where instrument_id is null
        union all select 1 from fwios.research_candidates where instrument_id is null
        union all select 1 from fwios.thesis_registry where instrument_id is null
        union all select 1 from fwios.portfolio_assets where instrument_id is null
        union all select 1 from fwios.portfolio_transactions where instrument_id is null
        union all select 1 from fwios.market_daily_closes where instrument_id is null
        union all select 1 from fwios.market_price_quotes where instrument_id is null
        union all select 1 from fwios.market_price_snapshots where instrument_id is null
      ),
      'All current rows on selected migration anchors must map.'),
    ('no ambiguous active symbol identity keys',
      not exists(
        select upper(symbol),upper(venue),upper(symbol_namespace)
        from fwios.instrument_symbols
        where active=true and valid_to is null
        group by 1,2,3
        having count(*)>1
      ),
      'Unique active symbol + venue + namespace.'),
    ('production read cutover remains false',
      (select config->>'production_read_cutover'='false'
       from fwios.policy_versions
       where policy_version_id='POL-INSTRUMENT-IDENTITY-V1'),
      'Legacy read paths remain authoritative in #33.'),
    ('no auto trade',
      (select config->>'auto_trade'='false'
       from fwios.policy_versions
       where policy_version_id='POL-INSTRUMENT-IDENTITY-V1'),
      'Identity migration never creates trading authority.')
),
numbered as (
  select row_number() over(order by test_case) n,* from tests
)
insert into fwios.decision_policy_regression_runs(
  regression_id,policy_key,policy_version_id,test_case,input_payload,
  expected_payload,actual_payload,status,tolerance,notes
)
select
  'REG-ID-V1-'||lpad(n::text,2,'0'),
  'INSTRUMENT_IDENTITY',
  'POL-INSTRUMENT-IDENTITY-V1',
  test_case,
  '{}'::jsonb,
  '{"passed":true}'::jsonb,
  jsonb_build_object('passed',passed),
  case when passed then 'PASS' else 'FAIL' end,
  null,
  notes
from numbered
on conflict(regression_id) do update set
  expected_payload=excluded.expected_payload,
  actual_payload=excluded.actual_payload,
  status=excluded.status,
  notes=excluded.notes;
