
-- Thesis Memory + Reactivation v1 foundation
-- Epic #31 / Issue #37
-- Additive normalized thesis-memory foundation. Legacy thesis JSON remains authoritative during transition.

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status,updated_at
) values (
  'THESIS_MEMORY','RESEARCH',
  'Thesis Memory + Reactivation v1',
  'Normalize machine-actionable thesis conditions, KPI bindings, decision memory and explicit research reactivation rules without automatic capital promotion.',
  'fwios.thesis_conditions','ACTIVE',now()
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
  'POL-THESIS-MEMORY-V1','THESIS_MEMORY','1.0','ACTIVE',true,
  '{
    "production_read_cutover": false,
    "legacy_thesis_json_authoritative": true,
    "condition_types": ["MUST_REMAIN_TRUE","CATALYST","INVALIDATION"],
    "decision_classes": ["REJECT","DEFER","WATCH","PROMOTE"],
    "reactivation_trigger_required": true,
    "reactivation_review_only": true,
    "reactivation_targets": ["UNIVERSE","SCREENED","WATCH"],
    "direct_buy_promotion": false,
    "prior_research_history_preserved": true,
    "auto_trade": false,
    "human_execution_only": true
  }'::jsonb,
  'GitHub policies/thesis/THESIS_MEMORY_V1.md; Epic #31 Issue #37',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status=excluded.lifecycle_status,
  deterministic_scoring=excluded.deterministic_scoring,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

create table fwios.thesis_conditions (
  condition_id text primary key,
  ticker text not null references fwios.thesis_registry(ticker) on delete restrict,
  instrument_id uuid not null references fwios.instruments(instrument_id) on delete restrict,
  baseline_version text not null,
  condition_type text not null check (condition_type in ('MUST_REMAIN_TRUE','CATALYST','INVALIDATION')),
  ordinal integer not null check (ordinal>0),
  statement text not null,
  severity text,
  horizon text,
  target_date date,
  source_payload jsonb not null,
  source_payload_hash text not null,
  source_reference text,
  created_at timestamptz not null default now(),
  unique(ticker,baseline_version,condition_type,ordinal,source_payload_hash)
);

create index thesis_conditions_ticker_type_idx
  on fwios.thesis_conditions(ticker,condition_type,ordinal);
create index thesis_conditions_instrument_idx
  on fwios.thesis_conditions(instrument_id,condition_type);

create table fwios.thesis_kpi_bindings (
  binding_id text primary key,
  ticker text not null references fwios.thesis_registry(ticker) on delete restrict,
  instrument_id uuid not null references fwios.instruments(instrument_id) on delete restrict,
  baseline_version text not null,
  ordinal integer not null check (ordinal>0),
  kpi_label text not null,
  baseline_text text,
  frequency text,
  metric_code text references fwios.metric_definitions(metric_code) on delete restrict,
  baseline_observation_id uuid references fwios.metric_observations(observation_id) on delete restrict,
  mapping_status text not null default 'UNMAPPED'
    check (mapping_status in ('RESOLVED','PARTIAL','METRIC_ONLY','UNMAPPED')),
  mapping_note text,
  source_payload jsonb not null,
  source_payload_hash text not null,
  created_at timestamptz not null default now(),
  unique(ticker,baseline_version,ordinal,source_payload_hash)
);

create index thesis_kpi_bindings_instrument_idx
  on fwios.thesis_kpi_bindings(instrument_id,ordinal);
create index thesis_kpi_bindings_metric_idx
  on fwios.thesis_kpi_bindings(metric_code)
  where metric_code is not null;
create index thesis_kpi_bindings_observation_idx
  on fwios.thesis_kpi_bindings(baseline_observation_id)
  where baseline_observation_id is not null;

create table fwios.thesis_condition_metric_links (
  link_id text primary key,
  condition_id text not null references fwios.thesis_conditions(condition_id) on delete restrict,
  metric_code text not null references fwios.metric_definitions(metric_code) on delete restrict,
  baseline_observation_id uuid references fwios.metric_observations(observation_id) on delete restrict,
  comparison_operator text
    check (comparison_operator is null or comparison_operator in ('LT','LTE','GT','GTE','EQ','NE','DIRECTION_DOWN','DIRECTION_UP')),
  threshold_numeric numeric,
  threshold_unit text,
  comparison_basis text,
  consecutive_periods integer not null default 1 check (consecutive_periods>=1),
  clause_group integer not null default 1 check (clause_group>=1),
  group_logic text not null default 'ALL' check (group_logic in ('ALL','ANY')),
  mapping_status text not null check (mapping_status in ('RESOLVED','PARTIAL','METRIC_ONLY')),
  notes text,
  created_at timestamptz not null default now(),
  unique(condition_id,metric_code,clause_group)
);

create index thesis_condition_metric_links_metric_idx
  on fwios.thesis_condition_metric_links(metric_code);
create index thesis_condition_metric_links_observation_idx
  on fwios.thesis_condition_metric_links(baseline_observation_id)
  where baseline_observation_id is not null;

create table fwios.thesis_decision_memory (
  decision_memory_id text primary key,
  ticker text not null references fwios.thesis_registry(ticker) on delete restrict,
  instrument_id uuid not null references fwios.instruments(instrument_id) on delete restrict,
  decision_class text not null check (decision_class in ('REJECT','DEFER','WATCH','PROMOTE')),
  lifecycle_state text not null check (lifecycle_state in ('UNIVERSE','SCREENED','WATCH','RESEARCH_CANDIDATE','FULL_THESIS','PORTFOLIO','REJECTED','ARCHIVED')),
  decision_snapshot_id text references fwios.decision_snapshots(decision_snapshot_id) on delete restrict,
  decision_summary text not null,
  rationale text not null,
  reactivation_required boolean not null default false,
  source_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (decision_class<>'REJECT' or reactivation_required=true),
  check (not (decision_class='PROMOTE' and lifecycle_state='PORTFOLIO'))
);

create index thesis_decision_memory_ticker_created_idx
  on fwios.thesis_decision_memory(ticker,created_at desc);
create index thesis_decision_memory_snapshot_idx
  on fwios.thesis_decision_memory(decision_snapshot_id)
  where decision_snapshot_id is not null;

create table fwios.thesis_reactivation_rules (
  rule_id text primary key,
  decision_memory_id text not null references fwios.thesis_decision_memory(decision_memory_id) on delete restrict,
  ticker text not null references fwios.thesis_registry(ticker) on delete restrict,
  instrument_id uuid not null references fwios.instruments(instrument_id) on delete restrict,
  trigger_type text not null check (trigger_type in ('METRIC_THRESHOLD','THESIS_EVENT','MANUAL_REVIEW','MATERIAL_CHANGE')),
  metric_code text references fwios.metric_definitions(metric_code) on delete restrict,
  comparison_operator text
    check (comparison_operator is null or comparison_operator in ('LT','LTE','GT','GTE','EQ','NE')),
  threshold_numeric numeric,
  threshold_text text,
  consecutive_periods integer not null default 1 check (consecutive_periods>=1),
  target_lifecycle_state text not null check (target_lifecycle_state in ('UNIVERSE','SCREENED','WATCH')),
  trigger_summary text not null,
  active boolean not null default true,
  source_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (
    trigger_type<>'METRIC_THRESHOLD'
    or (metric_code is not null and comparison_operator is not null and threshold_numeric is not null)
  )
);

create index thesis_reactivation_rules_memory_idx
  on fwios.thesis_reactivation_rules(decision_memory_id);
create index thesis_reactivation_rules_metric_idx
  on fwios.thesis_reactivation_rules(metric_code)
  where metric_code is not null;

create table fwios.thesis_reactivation_events (
  reactivation_event_id uuid primary key default gen_random_uuid(),
  rule_id text not null references fwios.thesis_reactivation_rules(rule_id) on delete restrict,
  decision_memory_id text not null references fwios.thesis_decision_memory(decision_memory_id) on delete restrict,
  ticker text not null references fwios.thesis_registry(ticker) on delete restrict,
  instrument_id uuid not null references fwios.instruments(instrument_id) on delete restrict,
  trigger_observation_id uuid references fwios.metric_observations(observation_id) on delete restrict,
  trigger_thesis_event_id uuid references fwios.thesis_events(event_id) on delete restrict,
  prior_lifecycle_state text not null check (prior_lifecycle_state in ('REJECTED','ARCHIVED')),
  resulting_lifecycle_state text not null check (resulting_lifecycle_state in ('UNIVERSE','SCREENED','WATCH')),
  evaluation_gate text not null check (evaluation_gate='PASS'),
  evaluation_payload jsonb not null default '{}'::jsonb,
  source_reference text,
  created_at timestamptz not null default now()
);

create index thesis_reactivation_events_ticker_created_idx
  on fwios.thesis_reactivation_events(ticker,created_at desc);
create index thesis_reactivation_events_observation_idx
  on fwios.thesis_reactivation_events(trigger_observation_id)
  where trigger_observation_id is not null;

alter table fwios.thesis_conditions enable row level security;
alter table fwios.thesis_kpi_bindings enable row level security;
alter table fwios.thesis_condition_metric_links enable row level security;
alter table fwios.thesis_decision_memory enable row level security;
alter table fwios.thesis_reactivation_rules enable row level security;
alter table fwios.thesis_reactivation_events enable row level security;

revoke all on fwios.thesis_conditions from public,anon,authenticated;
revoke all on fwios.thesis_kpi_bindings from public,anon,authenticated;
revoke all on fwios.thesis_condition_metric_links from public,anon,authenticated;
revoke all on fwios.thesis_decision_memory from public,anon,authenticated;
revoke all on fwios.thesis_reactivation_rules from public,anon,authenticated;
revoke all on fwios.thesis_reactivation_events from public,anon,authenticated;

grant select,insert on fwios.thesis_conditions to service_role;
grant select,insert,update on fwios.thesis_kpi_bindings to service_role;
grant select,insert,update on fwios.thesis_condition_metric_links to service_role;
grant select,insert on fwios.thesis_decision_memory to service_role;
grant select,insert on fwios.thesis_reactivation_rules to service_role;
grant select,insert on fwios.thesis_reactivation_events to service_role;

create or replace function fwios.thesis_memory_append_only_guard_v1()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  raise exception 'FWIOS thesis decision/reactivation memory is append-only; % is not allowed on %.%',
    TG_OP,TG_TABLE_SCHEMA,TG_TABLE_NAME;
end
$function$;

create trigger thesis_decision_memory_append_only
before update or delete on fwios.thesis_decision_memory
for each row execute function fwios.thesis_memory_append_only_guard_v1();

create trigger thesis_reactivation_rules_append_only
before update or delete on fwios.thesis_reactivation_rules
for each row execute function fwios.thesis_memory_append_only_guard_v1();

create trigger thesis_reactivation_events_append_only
before update or delete on fwios.thesis_reactivation_events
for each row execute function fwios.thesis_memory_append_only_guard_v1();

create or replace function fwios.thesis_reactivation_transition_gate_v1(
  p_from_state text,
  p_to_state text,
  p_explicit_trigger boolean,
  p_decision_memory_complete boolean
)
returns text
language plpgsql
stable
set search_path to ''
as $function$
declare
  v_from text:=upper(trim(coalesce(p_from_state,'')));
  v_to text:=upper(trim(coalesce(p_to_state,'')));
  v_gate text;
begin
  if v_from not in ('REJECTED','ARCHIVED') then
    return 'BLOCKED - REACTIVATION SOURCE MUST BE DORMANT';
  end if;

  if v_to not in ('UNIVERSE','SCREENED','WATCH') then
    return 'BLOCKED - REACTIVATION REVIEW ONLY';
  end if;

  if not p_explicit_trigger then
    return 'BLOCKED - REACTIVATION TRIGGER REQUIRED';
  end if;

  if not p_decision_memory_complete then
    return 'BLOCKED - DECISION MEMORY REQUIRED';
  end if;

  v_gate:=fwios.research_lifecycle_transition_gate_v1(
    v_from,v_to,'GENERIC',true,true,false
  );

  return v_gate;
end
$function$;

create or replace function fwios.thesis_decision_memory_gate_v1(p_decision_memory_id text)
returns text
language sql
stable
set search_path to ''
as $function$
select case
  when m.decision_memory_id is null then 'BLOCKED - DECISION MEMORY MISSING'
  when m.decision_class='REJECT'
    and not exists(
      select 1 from fwios.thesis_reactivation_rules r
      where r.decision_memory_id=m.decision_memory_id and r.active=true
    ) then 'BLOCKED - REACTIVATION RULE REQUIRED'
  else 'PASS'
end
from (select p_decision_memory_id decision_memory_id) i
left join fwios.thesis_decision_memory m
  on m.decision_memory_id=i.decision_memory_id;
$function$;

create or replace view fwios.v_thesis_memory_normalized_compat
with (security_invoker=true)
as
select
  tr.ticker,
  tr.instrument_id,
  coalesce(tr.metadata->>'baseline_version','LEGACY_BASELINE') baseline_version,
  coalesce((
    select jsonb_agg(c.source_payload order by c.ordinal)
    from fwios.thesis_conditions c
    where c.ticker=tr.ticker
      and c.baseline_version=coalesce(tr.metadata->>'baseline_version','LEGACY_BASELINE')
      and c.condition_type='MUST_REMAIN_TRUE'
  ),'[]'::jsonb) normalized_must_remain_true,
  coalesce((
    select jsonb_agg(k.source_payload order by k.ordinal)
    from fwios.thesis_kpi_bindings k
    where k.ticker=tr.ticker
      and k.baseline_version=coalesce(tr.metadata->>'baseline_version','LEGACY_BASELINE')
  ),'[]'::jsonb) normalized_monitoring_kpis,
  coalesce((
    select jsonb_agg(c.source_payload order by c.ordinal)
    from fwios.thesis_conditions c
    where c.ticker=tr.ticker
      and c.baseline_version=coalesce(tr.metadata->>'baseline_version','LEGACY_BASELINE')
      and c.condition_type='CATALYST'
  ),'[]'::jsonb) normalized_catalysts,
  coalesce((
    select jsonb_agg(c.source_payload order by c.ordinal)
    from fwios.thesis_conditions c
    where c.ticker=tr.ticker
      and c.baseline_version=coalesce(tr.metadata->>'baseline_version','LEGACY_BASELINE')
      and c.condition_type='INVALIDATION'
  ),'[]'::jsonb) normalized_invalidation_criteria
from fwios.thesis_registry tr;

create or replace view fwios.v_thesis_condition_metric_links
with (security_invoker=true)
as
select
  c.ticker,c.instrument_id,c.baseline_version,c.condition_id,c.condition_type,c.ordinal,
  c.statement,l.link_id,l.metric_code,d.metric_name,l.comparison_operator,
  l.threshold_numeric,l.threshold_unit,l.comparison_basis,l.consecutive_periods,
  l.group_logic,l.mapping_status,l.baseline_observation_id,
  o.value_numeric baseline_value_numeric,o.value_text baseline_value_text,
  o.canonical_unit baseline_unit,o.period_label baseline_period_label,o.provenance_status
from fwios.thesis_conditions c
join fwios.thesis_condition_metric_links l on l.condition_id=c.condition_id
join fwios.metric_definitions d on d.metric_code=l.metric_code
left join fwios.metric_observations o on o.observation_id=l.baseline_observation_id;

revoke all on fwios.v_thesis_memory_normalized_compat from public,anon,authenticated;
revoke all on fwios.v_thesis_condition_metric_links from public,anon,authenticated;
grant select on fwios.v_thesis_memory_normalized_compat to service_role;
grant select on fwios.v_thesis_condition_metric_links to service_role;
