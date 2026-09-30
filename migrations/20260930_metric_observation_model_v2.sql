-- Decision-Relevant Metric Observation Model v2
-- Epic #31 / Issue #34
-- Additive time-series foundation keyed by instrument_id.
-- Existing company_metrics / normalized_metrics / valuation / revision read paths remain authoritative.

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status,updated_at
) values (
  'METRIC_OBSERVATION_MODEL',
  'METRICS',
  'Decision-Relevant Metric Observation Model v2',
  'Store typed period-aware metric observations keyed by immutable instrument identity without building a full financial warehouse.',
  'fwios.metric_observations',
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
  'POL-METRIC-OBSERVATION-V2',
  'METRIC_OBSERVATION_MODEL',
  '2.0',
  'ACTIVE',
  true,
  $json$
  {
    "instrument_identity_required": true,
    "typed_values_required": true,
    "period_identity_required": true,
    "full_financial_statement_replication": false,
    "canonicalization_scope": [
      "SCREENING",
      "THESIS",
      "VALUATION",
      "REVISION",
      "RISK",
      "PORTFOLIO"
    ],
    "observation_layers": [
      "REPORTED",
      "DERIVED",
      "NORMALIZED",
      "GUIDANCE",
      "ESTIMATE",
      "SCENARIO",
      "STRUCTURED"
    ],
    "period_types": [
      "QUARTER",
      "YEAR",
      "YTD",
      "LTM",
      "INSTANT",
      "GUIDANCE",
      "STRUCTURAL",
      "SCENARIO",
      "MATERIAL_EVENT",
      "OTHER"
    ],
    "legacy_company_metrics_authoritative": true,
    "legacy_normalized_metrics_authoritative": true,
    "production_read_cutover": false,
    "evidence_lineage_full_graph_deferred_to_issue": 35,
    "human_execution_only": true,
    "auto_trade": false
  }
  $json$::jsonb,
  'GitHub policies/metrics/METRIC_OBSERVATION_V2.md; Epic #31 Issue #34',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status=excluded.lifecycle_status,
  deterministic_scoring=excluded.deterministic_scoring,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

create or replace function fwios.canonical_metric_code_v2(
  p_metric_id text,
  p_metric_label text default null
)
returns text
language sql
immutable
set search_path to ''
as $function$
  select case
    when nullif(trim(coalesce(p_metric_id,'')),'') is null then null
    when lower(p_metric_id) in ('fcf_ltm','fcf_q2','fcf_q2_prior_year','fcf_h1_2026')
      then 'FREE_CASH_FLOW'
    when lower(p_metric_id) in ('revenue_ltm','revenue_q2')
      then 'REVENUE'
    when lower(p_metric_id) in ('gross_margin','gross_margin_q3')
      then 'GROSS_MARGIN'
    when lower(p_metric_id) in ('operating_margin','operating_margin_q3')
      then 'OPERATING_MARGIN'
    when lower(p_metric_id) in ('recurring_growth_yoy','adobe_arr_growth_yoy')
      then 'RECURRING_REVENUE_GROWTH_YOY'
    when lower(p_metric_id)='engagement_growth'
      and lower(coalesce(p_metric_label,'')) like '%mau%'
      then 'GLOBAL_MAU_GROWTH_YOY'
    else upper(regexp_replace(trim(p_metric_id),'[^A-Za-z0-9]+','_','g'))
  end;
$function$;

create or replace function fwios.canonical_metric_unit_v2(
  p_source_unit text,
  p_metric_code text default null
)
returns text
language sql
immutable
set search_path to ''
as $function$
  select case
    when upper(coalesce(p_metric_code,''))='ALUMINUM_PASS_THROUGH_COVERAGE' then 'categorical'
    when upper(trim(coalesce(p_source_unit,''))) in ('PCT','PERCENT','RATIO') then 'ratio'
    when upper(trim(coalesce(p_source_unit,'')))='USD M' then 'USD B'
    when upper(trim(coalesce(p_source_unit,''))) in ('M SHARES','M DILUTED SHARES') then 'M shares'
    when upper(trim(coalesce(p_source_unit,'')))='B SHARES' then 'M shares'
    when nullif(trim(coalesce(p_source_unit,'')),'') is null then 'unitless'
    else trim(p_source_unit)
  end;
$function$;

create or replace function fwios.canonical_metric_numeric_v2(
  p_value_text text,
  p_source_unit text
)
returns numeric
language plpgsql
immutable
set search_path to ''
as $function$
declare
  v numeric;
  u text := upper(trim(coalesce(p_source_unit,'')));
begin
  if p_value_text is null
     or trim(p_value_text) !~ '^[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$' then
    return null;
  end if;

  v := trim(p_value_text)::numeric;

  if u in ('PCT','PERCENT') then
    return v/100.0;
  elsif u='USD M' then
    return v/1000.0;
  elsif u='B SHARES' then
    return v*1000.0;
  else
    return v;
  end if;
end
$function$;

create or replace function fwios.metric_period_type_v2(p_period text)
returns text
language sql
immutable
set search_path to ''
as $function$
  select case
    when upper(coalesce(p_period,'')) like '%MATERIAL_EVENT%' then 'MATERIAL_EVENT'
    when upper(coalesce(p_period,'')) like '%SCENARIO%' then 'SCENARIO'
    when upper(coalesce(p_period,'')) like '%STRUCTURAL%' then 'STRUCTURAL'
    when upper(coalesce(p_period,'')) like '%GUIDANCE%'
      or upper(coalesce(p_period,'')) like 'FORWARD%'
      then 'GUIDANCE'
    when upper(coalesce(p_period,'')) like '%LTM%' then 'LTM'
    when upper(coalesce(p_period,'')) ~ '(^|[^A-Z0-9])Q[1-4]([^A-Z0-9]|$)'
      or upper(coalesce(p_period,'')) like '%QUARTER%'
      then 'QUARTER'
    when upper(coalesce(p_period,'')) ~ '(^|[^A-Z0-9])H[12]([^A-Z0-9]|$)'
      or upper(coalesce(p_period,'')) like '%YTD%'
      then 'YTD'
    when upper(coalesce(p_period,'')) ~ '(^|[^A-Z0-9])FY ?[0-9]{4}([^A-Z0-9]|$)'
      or upper(coalesce(p_period,'')) like '%CURRENT_FY%'
      or upper(coalesce(p_period,'')) like '%HISTORICAL_FY%'
      then 'YEAR'
    when upper(coalesce(p_period,'')) like '%BALANCE_SHEET%'
      or upper(coalesce(p_period,'')) like '%SNAPSHOT%'
      or upper(coalesce(p_period,'')) in ('CURRENT','CURRENT_SHARE_COUNT','CURRENT_FILING','CURRENT_DILUTED')
      then 'INSTANT'
    else 'OTHER'
  end;
$function$;

create or replace function fwios.metric_fiscal_year_v2(p_period text)
returns integer
language plpgsql
immutable
set search_path to ''
as $function$
declare
  m text[];
begin
  if p_period is null then return null; end if;

  m := regexp_match(upper(p_period),'FY ?([0-9]{4})');
  if m is not null then return m[1]::integer; end if;

  m := regexp_match(upper(p_period),'(^|[^0-9])([0-9]{4})([^0-9]|$)');
  if m is not null then return m[2]::integer; end if;

  return null;
end
$function$;

create or replace function fwios.metric_fiscal_quarter_v2(p_period text)
returns smallint
language plpgsql
immutable
set search_path to ''
as $function$
declare
  m text[];
begin
  if p_period is null then return null; end if;
  m := regexp_match(upper(p_period),'Q([1-4])');
  if m is null then return null; end if;
  return m[1]::smallint;
end
$function$;

create or replace function fwios.safe_iso_date_v2(p_text text)
returns date
language sql
immutable
set search_path to ''
as $function$
  select case
    when trim(coalesce(p_text,'')) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      then trim(p_text)::date
    else null
  end;
$function$;

create table if not exists fwios.metric_definitions (
  metric_code text primary key,
  metric_name text not null,
  value_kind text not null
    check (value_kind in ('NUMERIC','TEXT','BOOLEAN')),
  canonical_unit text not null,
  scope_status text not null default 'DECISION_RELEVANT'
    check (scope_status in ('DECISION_RELEVANT','EXPERIMENTAL','DEPRECATED')),
  decision_uses text[] not null default '{}'::text[],
  description text,
  metadata jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists fwios.metric_legacy_mappings (
  source_layer text not null,
  legacy_metric_id text not null,
  definition_standard text not null default '',
  metric_code text not null references fwios.metric_definitions(metric_code) on delete restrict,
  mapping_version text not null default 'METRIC_OBSERVATION_V2',
  notes text,
  created_at timestamptz not null default now(),
  primary key(source_layer,legacy_metric_id,definition_standard,mapping_version)
);

create table if not exists fwios.metric_observations (
  observation_id uuid primary key default gen_random_uuid(),
  observation_key text not null unique,
  instrument_id uuid not null references fwios.instruments(instrument_id) on delete restrict,
  metric_code text not null references fwios.metric_definitions(metric_code) on delete restrict,
  observation_layer text not null
    check (observation_layer in ('REPORTED','DERIVED','NORMALIZED','GUIDANCE','ESTIMATE','SCENARIO','STRUCTURED')),
  value_numeric numeric,
  value_text text,
  value_boolean boolean,
  canonical_unit text not null,
  source_value_text text,
  source_unit text,
  period_type text not null
    check (period_type in ('QUARTER','YEAR','YTD','LTM','INSTANT','GUIDANCE','STRUCTURAL','SCENARIO','MATERIAL_EVENT','OTHER')),
  fiscal_year integer,
  fiscal_quarter smallint
    check (fiscal_quarter is null or fiscal_quarter between 1 and 4),
  period_start date,
  period_end date,
  as_of_date date,
  period_label text,
  reported_at timestamptz,
  effective_at timestamptz,
  normalization_version text,
  derivation_method text,
  source_observation_ids uuid[] not null default '{}'::uuid[],
  primary_evidence_id text references fwios.evidence_records(evidence_id) on delete restrict,
  evidence_ids text[] not null default '{}'::text[],
  source_table text not null,
  source_key text not null,
  source_reference text,
  valuation_model_id text,
  provenance_status text not null default 'PASS',
  quality_gate text,
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    ((value_numeric is not null)::int +
     (value_text is not null)::int +
     (value_boolean is not null)::int) = 1
  )
);

create index if not exists metric_observations_instrument_metric_period_idx
  on fwios.metric_observations(
    instrument_id,metric_code,period_end desc,as_of_date desc,created_at desc
  );

create index if not exists metric_observations_metric_period_idx
  on fwios.metric_observations(
    metric_code,period_type,fiscal_year desc,fiscal_quarter desc,created_at desc
  );

create index if not exists metric_observations_primary_evidence_idx
  on fwios.metric_observations(primary_evidence_id)
  where primary_evidence_id is not null;

alter table fwios.metric_definitions enable row level security;
alter table fwios.metric_legacy_mappings enable row level security;
alter table fwios.metric_observations enable row level security;

revoke all on fwios.metric_definitions from public,anon,authenticated;
revoke all on fwios.metric_legacy_mappings from public,anon,authenticated;
revoke all on fwios.metric_observations from public,anon,authenticated;

grant select,insert,update,delete on fwios.metric_definitions to service_role;
grant select,insert,update,delete on fwios.metric_legacy_mappings to service_role;
grant select,insert,update,delete on fwios.metric_observations to service_role;

-- Attach canonical identity to the legacy metric/evidence layers without changing their current keys.
alter table fwios.company_metrics add column if not exists instrument_id uuid;
alter table fwios.normalized_metrics add column if not exists instrument_id uuid;
alter table fwios.evidence_records add column if not exists instrument_id uuid;

do $$
begin
  if not exists(
    select 1 from pg_constraint
    where conname='company_metrics_instrument_id_fkey'
      and conrelid='fwios.company_metrics'::regclass
  ) then
    alter table fwios.company_metrics
      add constraint company_metrics_instrument_id_fkey
      foreign key(instrument_id) references fwios.instruments(instrument_id) on delete restrict;
  end if;

  if not exists(
    select 1 from pg_constraint
    where conname='normalized_metrics_instrument_id_fkey'
      and conrelid='fwios.normalized_metrics'::regclass
  ) then
    alter table fwios.normalized_metrics
      add constraint normalized_metrics_instrument_id_fkey
      foreign key(instrument_id) references fwios.instruments(instrument_id) on delete restrict;
  end if;

  if not exists(
    select 1 from pg_constraint
    where conname='evidence_records_instrument_id_fkey'
      and conrelid='fwios.evidence_records'::regclass
  ) then
    alter table fwios.evidence_records
      add constraint evidence_records_instrument_id_fkey
      foreign key(instrument_id) references fwios.instruments(instrument_id) on delete restrict;
  end if;
end
$$;

create index if not exists company_metrics_instrument_id_idx
  on fwios.company_metrics(instrument_id);
create index if not exists normalized_metrics_instrument_id_idx
  on fwios.normalized_metrics(instrument_id);
create index if not exists evidence_records_instrument_id_idx
  on fwios.evidence_records(instrument_id);

update fwios.company_metrics
set instrument_id=fwios.resolve_instrument_id_v1(ticker,'Stock',null,null)
where instrument_id is null;

update fwios.normalized_metrics
set instrument_id=fwios.resolve_instrument_id_v1(ticker,'Stock',null,null)
where instrument_id is null;

update fwios.evidence_records
set instrument_id=fwios.resolve_instrument_id_v1(ticker,null,null,null)
where instrument_id is null
  and ticker is not null;

-- Seed metric definitions from the already-curated decision metric layers.
with legacy as (
  select
    fwios.canonical_metric_code_v2(metric_id,metric_label) metric_code,
    coalesce(metric_label,initcap(replace(fwios.canonical_metric_code_v2(metric_id,metric_label),'_',' '))) metric_name,
    fwios.canonical_metric_unit_v2(unit,fwios.canonical_metric_code_v2(metric_id,metric_label)) canonical_unit,
    fwios.canonical_metric_numeric_v2(canonical_value_text,unit) numeric_value,
    canonical_value_text source_value,
    valuation_model_id
  from fwios.company_metrics
  where metric_id is not null

  union all

  select
    fwios.canonical_metric_code_v2(n.metric_id,c.metric_label),
    coalesce(c.metric_label,initcap(replace(fwios.canonical_metric_code_v2(n.metric_id,c.metric_label),'_',' '))),
    fwios.canonical_metric_unit_v2(n.normalized_unit,fwios.canonical_metric_code_v2(n.metric_id,c.metric_label)),
    fwios.canonical_metric_numeric_v2(n.normalized_value_text,n.normalized_unit),
    n.normalized_value_text,
    n.valuation_model_id
  from fwios.normalized_metrics n
  left join fwios.company_metrics c
    on c.ticker=n.ticker and c.metric_id=n.metric_id
),
grouped as (
  select
    metric_code,
    min(metric_name) metric_name,
    min(canonical_unit) canonical_unit,
    case
      when bool_and(numeric_value is not null) then 'NUMERIC'
      else 'TEXT'
    end value_kind,
    array_remove(array[
      'RESEARCH'::text,
      case when bool_or(valuation_model_id is not null) then 'VALUATION' end
    ],null) decision_uses
  from legacy
  where metric_code is not null
  group by metric_code
)
insert into fwios.metric_definitions(
  metric_code,metric_name,value_kind,canonical_unit,scope_status,decision_uses,description,metadata
)
select
  metric_code,
  metric_name,
  value_kind,
  canonical_unit,
  'DECISION_RELEVANT',
  decision_uses,
  'Migrated from curated FWIOS company_metrics / normalized_metrics; not a full financial-statement warehouse.',
  jsonb_build_object('migration_source','METRIC_OBSERVATION_V2')
from grouped
on conflict(metric_code) do update set
  metric_name=excluded.metric_name,
  value_kind=excluded.value_kind,
  canonical_unit=excluded.canonical_unit,
  decision_uses=excluded.decision_uses,
  updated_at=now();

-- Additional canonical definitions required by selective thesis/revision history.
insert into fwios.metric_definitions(
  metric_code,metric_name,value_kind,canonical_unit,decision_uses,description,metadata
) values
  ('GLOBAL_ARPU','Global ARPU','NUMERIC','USD/user',array['THESIS','RESEARCH']::text[],
   'Global average revenue per user for the stated quarter.', '{"seed":"PINS_THESIS_BASELINE"}'::jsonb),
  ('SHARE_BASED_COMPENSATION','Share-based compensation','NUMERIC','USD B',array['THESIS','RISK','HARDENING']::text[],
   'Reported share-based compensation for the stated period.', '{"seed":"PINS_PRIMARY_EVIDENCE"}'::jsonb)
on conflict(metric_code) do nothing;

-- Map legacy metric names to canonical semantic codes.
insert into fwios.metric_legacy_mappings(
  source_layer,legacy_metric_id,definition_standard,metric_code,mapping_version,notes
)
select distinct
  'COMPANY_METRICS',
  c.metric_id,
  '',
  fwios.canonical_metric_code_v2(c.metric_id,c.metric_label),
  'METRIC_OBSERVATION_V2',
  'Current-state compatibility mapping.'
from fwios.company_metrics c
where c.metric_id is not null
on conflict do nothing;

insert into fwios.metric_legacy_mappings(
  source_layer,legacy_metric_id,definition_standard,metric_code,mapping_version,notes
)
select distinct
  'NORMALIZED_METRICS',
  n.metric_id,
  coalesce(n.definition_standard,''),
  fwios.canonical_metric_code_v2(n.metric_id,c.metric_label),
  'METRIC_OBSERVATION_V2',
  'Normalized compatibility mapping.'
from fwios.normalized_metrics n
left join fwios.company_metrics c
  on c.ticker=n.ticker and c.metric_id=n.metric_id
where n.metric_id is not null
on conflict do nothing;

-- Backfill company_metrics as typed reported/derived observations.
insert into fwios.metric_observations(
  observation_key,instrument_id,metric_code,observation_layer,
  value_numeric,value_text,value_boolean,canonical_unit,
  source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
  period_start,period_end,as_of_date,period_label,reported_at,effective_at,
  normalization_version,derivation_method,source_observation_ids,
  primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
  valuation_model_id,provenance_status,quality_gate,raw_payload
)
select
  'CM:'||c.ticker||':'||c.metric_id,
  c.instrument_id,
  fwios.canonical_metric_code_v2(c.metric_id,c.metric_label),
  case
    when upper(coalesce(c.data_type,'')) like '%DERIVED%'
      or upper(coalesce(c.value_type,''))='DERIVED'
      then 'DERIVED'
    when fwios.canonical_metric_numeric_v2(c.canonical_value_text,c.unit) is null
      then 'STRUCTURED'
    else 'REPORTED'
  end,
  fwios.canonical_metric_numeric_v2(c.canonical_value_text,c.unit),
  case when fwios.canonical_metric_numeric_v2(c.canonical_value_text,c.unit) is null
    then c.canonical_value_text end,
  null::boolean,
  fwios.canonical_metric_unit_v2(c.unit,fwios.canonical_metric_code_v2(c.metric_id,c.metric_label)),
  c.canonical_value_text,
  c.unit,
  fwios.metric_period_type_v2(c.period),
  fwios.metric_fiscal_year_v2(c.period),
  fwios.metric_fiscal_quarter_v2(c.period),
  null::date,
  fwios.safe_iso_date_v2(c.evidence_date_text),
  fwios.safe_iso_date_v2(c.evidence_date_text),
  c.period,
  case
    when fwios.safe_iso_date_v2(e.published_at_text) is not null
      then fwios.safe_iso_date_v2(e.published_at_text)::timestamptz
    else null
  end,
  case
    when fwios.safe_iso_date_v2(c.evidence_date_text) is not null
      then fwios.safe_iso_date_v2(c.evidence_date_text)::timestamptz
    else null
  end,
  null,
  coalesce(e.derivation_method,c.raw_payload->>'derivation_method'),
  '{}'::uuid[],
  case when e.evidence_id is not null then e.evidence_id end,
  case when c.evidence_id is not null then array[c.evidence_id]::text[] else '{}'::text[] end,
  'fwios.company_metrics',
  c.ticker||':'||c.metric_id,
  c.source_url,
  c.valuation_model_id,
  case when c.evidence_gate='PASS' then 'PASS' else coalesce(c.evidence_gate,'REVIEW') end,
  c.metric_status,
  coalesce(c.raw_payload,'{}'::jsonb) || jsonb_build_object(
    'legacy_ticker',c.ticker,
    'legacy_metric_id',c.metric_id,
    'legacy_value_type',c.value_type,
    'legacy_data_type',c.data_type
  )
from fwios.company_metrics c
left join fwios.evidence_records e
  on e.evidence_id=c.evidence_id
where c.instrument_id is not null
on conflict(observation_key) do nothing;

-- Backfill normalized_metrics as typed normalized observations.
insert into fwios.metric_observations(
  observation_key,instrument_id,metric_code,observation_layer,
  value_numeric,value_text,value_boolean,canonical_unit,
  source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
  period_start,period_end,as_of_date,period_label,reported_at,effective_at,
  normalization_version,derivation_method,source_observation_ids,
  primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
  valuation_model_id,provenance_status,quality_gate,raw_payload
)
select
  'NM:'||n.ticker||':'||n.metric_id||':'||n.normalization_version,
  n.instrument_id,
  fwios.canonical_metric_code_v2(n.metric_id,c.metric_label),
  'NORMALIZED',
  fwios.canonical_metric_numeric_v2(n.normalized_value_text,n.normalized_unit),
  case when fwios.canonical_metric_numeric_v2(n.normalized_value_text,n.normalized_unit) is null
    then n.normalized_value_text end,
  null::boolean,
  fwios.canonical_metric_unit_v2(n.normalized_unit,fwios.canonical_metric_code_v2(n.metric_id,c.metric_label)),
  n.source_value_text,
  coalesce(c.unit,n.normalized_unit),
  fwios.metric_period_type_v2(coalesce(c.period,n.period_type)),
  fwios.metric_fiscal_year_v2(c.period),
  fwios.metric_fiscal_quarter_v2(c.period),
  null::date,
  fwios.safe_iso_date_v2(c.evidence_date_text),
  fwios.safe_iso_date_v2(c.evidence_date_text),
  coalesce(c.period,n.period_type),
  case
    when fwios.safe_iso_date_v2(e.published_at_text) is not null
      then fwios.safe_iso_date_v2(e.published_at_text)::timestamptz
    else null
  end,
  case
    when fwios.safe_iso_date_v2(c.evidence_date_text) is not null
      then fwios.safe_iso_date_v2(c.evidence_date_text)::timestamptz
    else null
  end,
  n.normalization_version,
  n.normalization_method,
  case when src.observation_id is not null then array[src.observation_id]::uuid[] else '{}'::uuid[] end,
  case when e.evidence_id is not null then e.evidence_id end,
  coalesce(n.evidence_ids,'{}'::text[]),
  'fwios.normalized_metrics',
  n.ticker||':'||n.metric_id||':'||n.normalization_version,
  null,
  n.valuation_model_id,
  case when n.normalization_gate='PASS' and n.source_gate='PASS' then 'PASS' else 'REVIEW' end,
  n.normalization_gate,
  coalesce(n.raw_payload,'{}'::jsonb) || jsonb_build_object(
    'legacy_ticker',n.ticker,
    'legacy_metric_id',n.metric_id,
    'definition_standard',n.definition_standard,
    'comparable_status',n.comparable_status
  )
from fwios.normalized_metrics n
left join fwios.company_metrics c
  on c.ticker=n.ticker and c.metric_id=n.metric_id
left join fwios.metric_observations src
  on src.observation_key='CM:'||n.ticker||':'||n.metric_id
left join fwios.evidence_records e
  on e.evidence_id=case
    when cardinality(coalesce(n.evidence_ids,'{}'::text[]))>0 then n.evidence_ids[1]
    else null
  end
where n.instrument_id is not null
on conflict(observation_key) do nothing;

-- Selective historical evidence needed immediately by current Revision/Thesis workflows.
-- ADBE ARR/recurring growth Q2 FY26; Q3 FY26 already exists from company_metrics.
insert into fwios.metric_observations(
  observation_key,instrument_id,metric_code,observation_layer,value_numeric,value_text,value_boolean,
  canonical_unit,source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
  period_end,as_of_date,period_label,reported_at,effective_at,derivation_method,
  primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
  provenance_status,quality_gate,raw_payload
)
select
  'EV:'||e.evidence_id||':RECURRING_REVENUE_GROWTH_YOY',
  e.instrument_id,
  'RECURRING_REVENUE_GROWTH_YOY',
  'REPORTED',
  fwios.canonical_metric_numeric_v2(e.value_text,e.unit),
  null,
  null,
  fwios.canonical_metric_unit_v2(e.unit,'RECURRING_REVENUE_GROWTH_YOY'),
  e.value_text,e.unit,
  fwios.metric_period_type_v2(e.period),
  fwios.metric_fiscal_year_v2(e.period),
  fwios.metric_fiscal_quarter_v2(e.period),
  fwios.safe_iso_date_v2(e.evidence_date_text),
  fwios.safe_iso_date_v2(e.evidence_date_text),
  e.period,
  fwios.safe_iso_date_v2(e.published_at_text)::timestamptz,
  fwios.safe_iso_date_v2(e.evidence_date_text)::timestamptz,
  e.derivation_method,
  e.evidence_id,array[e.evidence_id]::text[],
  'fwios.evidence_records',e.evidence_id,e.source_url,
  'PASS',e.canonical_metric_gate,
  coalesce(e.raw_payload,'{}'::jsonb)
from fwios.evidence_records e
where e.evidence_id='METRIC-ADBE-SAAS-20260905-09'
  and e.instrument_id is not null
on conflict(observation_key) do nothing;

-- PINS Q1 history for MAU growth and revenue growth.
insert into fwios.metric_observations(
  observation_key,instrument_id,metric_code,observation_layer,value_numeric,value_text,value_boolean,
  canonical_unit,source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
  period_end,as_of_date,period_label,reported_at,effective_at,derivation_method,
  primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
  provenance_status,quality_gate,raw_payload
)
select
  'EV:'||e.evidence_id||':'||
  case when e.evidence_id='EVD-PINS-Q1-ENG-20260331'
       then 'GLOBAL_MAU_GROWTH_YOY' else 'REVENUE_GROWTH_YOY' end,
  e.instrument_id,
  case when e.evidence_id='EVD-PINS-Q1-ENG-20260331'
       then 'GLOBAL_MAU_GROWTH_YOY' else 'REVENUE_GROWTH_YOY' end,
  'REPORTED',
  fwios.canonical_metric_numeric_v2(e.value_text,e.unit),
  null,null,
  fwios.canonical_metric_unit_v2(e.unit,
    case when e.evidence_id='EVD-PINS-Q1-ENG-20260331'
         then 'GLOBAL_MAU_GROWTH_YOY' else 'REVENUE_GROWTH_YOY' end),
  e.value_text,e.unit,
  'QUARTER',2026,1,
  fwios.safe_iso_date_v2(e.evidence_date_text),
  fwios.safe_iso_date_v2(e.evidence_date_text),
  e.period,
  fwios.safe_iso_date_v2(e.published_at_text)::timestamptz,
  fwios.safe_iso_date_v2(e.evidence_date_text)::timestamptz,
  e.derivation_method,
  e.evidence_id,array[e.evidence_id]::text[],
  'fwios.evidence_records',e.evidence_id,e.source_url,
  'PASS',e.canonical_metric_gate,coalesce(e.raw_payload,'{}'::jsonb)
from fwios.evidence_records e
where e.evidence_id in ('EVD-PINS-Q1-ENG-20260331','EVD-PINS-Q1-REVGR-20260331')
  and e.instrument_id is not null
on conflict(observation_key) do nothing;

-- PINS prior-year quarterly FCF so Q2 2025 / Q2 2026 coexist under one semantic metric.
insert into fwios.metric_observations(
  observation_key,instrument_id,metric_code,observation_layer,value_numeric,value_text,value_boolean,
  canonical_unit,source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
  period_end,as_of_date,period_label,reported_at,effective_at,derivation_method,
  primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
  provenance_status,quality_gate,raw_payload
)
select
  'EV:'||e.evidence_id||':FREE_CASH_FLOW',
  e.instrument_id,'FREE_CASH_FLOW','REPORTED',
  fwios.canonical_metric_numeric_v2(e.value_text,e.unit),
  null,null,
  fwios.canonical_metric_unit_v2(e.unit,'FREE_CASH_FLOW'),
  e.value_text,e.unit,'QUARTER',2025,2,
  fwios.safe_iso_date_v2(e.evidence_date_text),
  fwios.safe_iso_date_v2(e.evidence_date_text),
  e.period,
  fwios.safe_iso_date_v2(e.published_at_text)::timestamptz,
  fwios.safe_iso_date_v2(e.evidence_date_text)::timestamptz,
  e.derivation_method,
  e.evidence_id,array[e.evidence_id]::text[],
  'fwios.evidence_records',e.evidence_id,e.source_url,
  'PASS',e.canonical_metric_gate,coalesce(e.raw_payload,'{}'::jsonb)
from fwios.evidence_records e
where e.evidence_id='EVD-PINS-Q2-2025-FCF-REF'
  and e.instrument_id is not null
on conflict(observation_key) do nothing;

-- PINS current ARPU baseline: source is the already-approved thesis baseline backed by the Q2 SEC release.
insert into fwios.metric_observations(
  observation_key,instrument_id,metric_code,observation_layer,value_numeric,value_text,value_boolean,
  canonical_unit,source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
  period_end,as_of_date,period_label,reported_at,effective_at,
  primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
  provenance_status,quality_gate,raw_payload
)
select
  'THESIS:PINS:GLOBAL_ARPU:Q2-2026',
  t.instrument_id,'GLOBAL_ARPU','REPORTED',
  1.86,null,null,
  'USD/user','1.86','USD/user','QUARTER',2026,2,
  date '2026-06-30',date '2026-06-30','Q2 2026',
  null,date '2026-06-30'::timestamptz,
  null,'{}'::text[],
  'fwios.thesis_registry','PINS:monitoring_kpis:Global ARPU',t.source_reference,
  'PASS','PASS',
  jsonb_build_object(
    'baseline','Q2 2026 $1.86; +7% YoY',
    'migration_note','Structured from existing approved thesis baseline; full evidence edge will be normalized in Issue #35.'
  )
from fwios.thesis_registry t
where t.ticker='PINS' and t.instrument_id is not null
on conflict(observation_key) do nothing;

-- PINS H1 share-based compensation primary evidence.
insert into fwios.metric_observations(
  observation_key,instrument_id,metric_code,observation_layer,value_numeric,value_text,value_boolean,
  canonical_unit,source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
  period_end,as_of_date,period_label,reported_at,effective_at,derivation_method,
  primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
  provenance_status,quality_gate,raw_payload
)
select
  'EV:'||e.evidence_id||':SHARE_BASED_COMPENSATION',
  e.instrument_id,'SHARE_BASED_COMPENSATION','REPORTED',
  fwios.canonical_metric_numeric_v2(e.value_text,e.unit),
  null,null,
  fwios.canonical_metric_unit_v2(e.unit,'SHARE_BASED_COMPENSATION'),
  e.value_text,e.unit,'YTD',2026,null,
  fwios.safe_iso_date_v2(e.evidence_date_text),
  fwios.safe_iso_date_v2(e.evidence_date_text),
  e.period,
  null,
  fwios.safe_iso_date_v2(e.evidence_date_text)::timestamptz,
  e.derivation_method,
  e.evidence_id,array[e.evidence_id]::text[],
  'fwios.evidence_records',e.evidence_id,e.source_url,
  'PASS',e.canonical_metric_gate,coalesce(e.raw_payload,'{}'::jsonb)
from fwios.evidence_records e
where e.evidence_id='QH-PINS-H1-26-SBC-20260906'
  and e.instrument_id is not null
on conflict(observation_key) do nothing;

create or replace view fwios.v_metric_observations_current
with (security_invoker=true)
as
select distinct on (o.instrument_id,o.metric_code,o.observation_layer)
  o.observation_id,
  o.instrument_id,
  i.asset_symbol,
  i.ticker,
  o.metric_code,
  d.metric_name,
  d.value_kind,
  o.observation_layer,
  o.value_numeric,
  o.value_text,
  o.value_boolean,
  o.canonical_unit,
  o.period_type,
  o.fiscal_year,
  o.fiscal_quarter,
  o.period_label,
  o.period_end,
  o.as_of_date,
  o.reported_at,
  o.effective_at,
  o.normalization_version,
  o.primary_evidence_id,
  o.evidence_ids,
  o.provenance_status,
  o.quality_gate,
  o.source_table,
  o.source_key,
  o.created_at
from fwios.metric_observations o
join fwios.metric_definitions d using(metric_code)
join fwios.v_instrument_identity_current i using(instrument_id)
order by
  o.instrument_id,o.metric_code,o.observation_layer,
  coalesce(o.period_end,o.as_of_date,'1900-01-01'::date) desc,
  o.created_at desc;

revoke all on fwios.v_metric_observations_current from public,anon,authenticated;
grant select on fwios.v_metric_observations_current to service_role;

-- Register acceptance regressions.
with tests(test_case,passed,notes) as (
  values
    ('policy active / no read cutover',
      exists(
        select 1 from fwios.policy_versions
        where policy_version_id='POL-METRIC-OBSERVATION-V2'
          and lifecycle_status='ACTIVE'
          and config->>'production_read_cutover'='false'
          and config->>'auto_trade'='false'
      ),
      'Metric v2 is additive only.'),

    ('legacy metric identity backfilled',
      not exists(select 1 from fwios.company_metrics where instrument_id is null)
      and not exists(select 1 from fwios.normalized_metrics where instrument_id is null)
      and not exists(select 1 from fwios.evidence_records where ticker is not null and instrument_id is null),
      'company_metrics / normalized_metrics / ticker evidence all map to canonical identity.'),

    ('company metric compatibility observations complete',
      (select count(*) from fwios.metric_observations where source_table='fwios.company_metrics')
      =(select count(*) from fwios.company_metrics),
      'Every curated company metric has a v2 observation.'),

    ('normalized metric compatibility observations complete',
      (select count(*) from fwios.metric_observations where source_table='fwios.normalized_metrics')
      =(select count(*) from fwios.normalized_metrics),
      'Every current normalized metric has a v2 normalized observation.'),

    ('typed value invariant',
      not exists(
        select 1 from fwios.metric_observations
        where ((value_numeric is not null)::int+(value_text is not null)::int+(value_boolean is not null)::int)<>1
      ),
      'Exactly one typed canonical value per observation.'),

    ('ADBE Q2 and Q3 recurring growth coexist',
      (select count(distinct fiscal_quarter) from fwios.metric_observations
       where instrument_id=fwios.resolve_instrument_id_v1('ADBE','Stock',null,null)
         and metric_code='RECURRING_REVENUE_GROWTH_YOY'
         and observation_layer in ('REPORTED','DERIVED')
         and fiscal_year=2026
         and fiscal_quarter in (2,3))=2,
      'Period is identity; metric code no longer carries quarter.'),

    ('PINS MAU Q1 and Q2 coexist',
      (select count(distinct fiscal_quarter) from fwios.metric_observations
       where instrument_id=fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
         and metric_code='GLOBAL_MAU_GROWTH_YOY'
         and fiscal_year=2026
         and fiscal_quarter in (1,2))=2,
      'Quarterly MAU history is period-aware.'),

    ('PINS revenue growth Q1 and Q2 coexist',
      (select count(distinct fiscal_quarter) from fwios.metric_observations
       where instrument_id=fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
         and metric_code='REVENUE_GROWTH_YOY'
         and fiscal_year=2026
         and fiscal_quarter in (1,2))=2,
      'Revision acceleration can use period rows rather than period-coded metric IDs.'),

    ('PINS FCF Q2 2025 and Q2 2026 coexist',
      (select count(distinct fiscal_year) from fwios.metric_observations
       where instrument_id=fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
         and metric_code='FREE_CASH_FLOW'
         and period_type='QUARTER'
         and fiscal_quarter=2
         and fiscal_year in (2025,2026))=2,
      'FCF history supports YoY comparisons.'),

    ('PINS ARPU period-aware baseline present',
      exists(
        select 1 from fwios.metric_observations
        where observation_key='THESIS:PINS:GLOBAL_ARPU:Q2-2026'
          and metric_code='GLOBAL_ARPU'
          and fiscal_year=2026 and fiscal_quarter=2
          and value_numeric=1.86
      ),
      'ARPU can accumulate additional quarterly observations under one metric code.'),

    ('PINS SBC period-aware evidence present',
      exists(
        select 1 from fwios.metric_observations
        where metric_code='SHARE_BASED_COMPENSATION'
          and instrument_id=fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
          and fiscal_year=2026
          and period_type='YTD'
      )
      and exists(
        select 1 from fwios.metric_observations
        where metric_code='SBC_TO_REVENUE'
          and instrument_id=fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
          and period_type='LTM'
      ),
      'SBC amount and owner-economics ratio retain explicit period semantics.'),

    ('normalized observations point to source observations when available',
      not exists(
        select 1 from fwios.metric_observations
        where source_table='fwios.normalized_metrics'
          and source_observation_ids='{}'::uuid[]
      ),
      'Normalization has direct source-observation support before the full #35 lineage graph.'),

    ('private RLS enabled',
      not exists(
        select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
        where n.nspname='fwios'
          and c.relname in ('metric_definitions','metric_legacy_mappings','metric_observations')
          and c.relrowsecurity=false
      ),
      'Metric v2 tables are internal/private.'),

    ('human execution only',
      (select config->>'human_execution_only'='true'
       from fwios.policy_versions where policy_version_id='POL-METRIC-OBSERVATION-V2'),
      'Metric storage cannot trade.')
),
numbered as (
  select row_number() over(order by test_case) n,* from tests
)
insert into fwios.decision_policy_regression_runs(
  regression_id,policy_key,policy_version_id,test_case,input_payload,
  expected_payload,actual_payload,status,tolerance,notes
)
select
  'REG-METRIC-V2-'||lpad(n::text,2,'0'),
  'METRIC_OBSERVATION_MODEL',
  'POL-METRIC-OBSERVATION-V2',
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
