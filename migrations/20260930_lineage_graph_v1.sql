-- Evidence → Metric → Decision Lineage Graph v1
-- Epic #31 / Issue #35
-- Additive audit graph. No production decision/valuation consumer cutover.
-- Existing arrays/prose remain compatibility payloads, but lineage-critical relations are normalized into append-only edges.

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status,updated_at
) values (
  'LINEAGE_GRAPH',
  'LINEAGE',
  'Evidence Metric Decision Lineage Graph v1',
  'Provide append-only typed lineage from sources and evidence through metric observations, revision/valuation/hardening outputs and decision snapshots.',
  'fwios.lineage_edges',
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
  'POL-LINEAGE-GRAPH-V1',
  'LINEAGE_GRAPH',
  '1.0',
  'ACTIVE',
  true,
  $json$
  {
    "append_only": true,
    "production_read_cutover": false,
    "unresolved_reference_policy": "EXPLICIT_REFERENCE_ARTIFACT_FAIL_CLOSED",
    "artifact_types": [
      "SOURCE",
      "SOURCE_REFERENCE",
      "EVIDENCE",
      "EVIDENCE_REFERENCE",
      "METRIC_OBSERVATION",
      "REVISION_COMPONENT",
      "REVISION_SNAPSHOT",
      "VALUATION_RUN",
      "HARDENING_SNAPSHOT",
      "DECISION_SNAPSHOT"
    ],
    "critical_array_relations_normalized": [
      "metric_observations.evidence_ids",
      "metric_observations.source_observation_ids",
      "candidate_revision_component_inputs.evidence_ids",
      "candidate_revision_snapshots.component_input_ids"
    ],
    "decision_links_normalized": [
      "valuation_run_to_decision",
      "revision_snapshot_to_decision",
      "hardening_snapshot_to_decision"
    ],
    "human_execution_only": true,
    "auto_trade": false
  }
  $json$::jsonb,
  'GitHub policies/lineage/LINEAGE_GRAPH_V1.md; Epic #31 Issue #35',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status=excluded.lifecycle_status,
  deterministic_scoring=excluded.deterministic_scoring,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

-- Complete PINS owner-economics observation coverage from already-verified evidence.
insert into fwios.metric_definitions(
  metric_code,metric_name,value_kind,canonical_unit,scope_status,decision_uses,description,metadata
) values (
  'SHARE_REPURCHASES',
  'Share repurchases',
  'NUMERIC',
  'USD B',
  'DECISION_RELEVANT',
  array['THESIS','RISK','HARDENING']::text[],
  'Reported share repurchases for the stated period.',
  '{"seed":"LINEAGE_V1_OWNER_ECONOMICS"}'::jsonb
)
on conflict(metric_code) do nothing;

insert into fwios.metric_observations(
  observation_key,instrument_id,metric_code,observation_layer,
  value_numeric,value_text,value_boolean,canonical_unit,
  source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
  period_end,as_of_date,period_label,reported_at,effective_at,
  derivation_method,primary_evidence_id,evidence_ids,
  source_table,source_key,source_reference,provenance_status,quality_gate,raw_payload
)
select
  'EV:'||e.evidence_id||':'||
    case
      when e.metric_id='fcf_h1_2026' then 'FREE_CASH_FLOW'
      when e.metric_id='buybacks_h1_2026' then 'SHARE_REPURCHASES'
      when e.metric_id in ('shares_q2_2025','shares_q2_2026') then 'SHARES_OUTSTANDING'
      else upper(e.metric_id)
    end,
  e.instrument_id,
  case
    when e.metric_id='fcf_h1_2026' then 'FREE_CASH_FLOW'
    when e.metric_id='buybacks_h1_2026' then 'SHARE_REPURCHASES'
    when e.metric_id in ('shares_q2_2025','shares_q2_2026') then 'SHARES_OUTSTANDING'
    else upper(e.metric_id)
  end,
  'REPORTED',
  fwios.canonical_metric_numeric_v2(e.value_text,e.unit),
  null,
  null,
  fwios.canonical_metric_unit_v2(
    e.unit,
    case
      when e.metric_id='fcf_h1_2026' then 'FREE_CASH_FLOW'
      when e.metric_id='buybacks_h1_2026' then 'SHARE_REPURCHASES'
      when e.metric_id in ('shares_q2_2025','shares_q2_2026') then 'SHARES_OUTSTANDING'
      else upper(e.metric_id)
    end
  ),
  e.value_text,
  e.unit,
  case when e.metric_id in ('fcf_h1_2026','buybacks_h1_2026') then 'YTD' else 'QUARTER' end,
  case when e.metric_id='shares_q2_2025' then 2025 else 2026 end,
  case when e.metric_id in ('shares_q2_2025','shares_q2_2026') then 2 else null end,
  fwios.safe_iso_date_v2(e.evidence_date_text),
  fwios.safe_iso_date_v2(e.evidence_date_text),
  e.period,
  null,
  fwios.safe_iso_date_v2(e.evidence_date_text)::timestamptz,
  e.derivation_method,
  e.evidence_id,
  array[e.evidence_id]::text[],
  'fwios.evidence_records',
  e.evidence_id,
  e.source_url,
  'PASS',
  e.canonical_metric_gate,
  coalesce(e.raw_payload,'{}'::jsonb) || '{"lineage_v1_owner_economics":true}'::jsonb
from fwios.evidence_records e
where e.evidence_id in (
  'QH-PINS-H1-26-FCF-20260906',
  'QH-PINS-H1-26-BUYBACK-20260906',
  'QH-PINS-Q2-25-SHARES-20260906',
  'QH-PINS-Q2-26-SHARES-20260906'
)
and e.instrument_id is not null
on conflict(observation_key) do nothing;

create table if not exists fwios.lineage_artifacts (
  artifact_id uuid primary key default gen_random_uuid(),
  artifact_key text not null unique,
  artifact_type text not null check (
    artifact_type in (
      'SOURCE','SOURCE_REFERENCE','EVIDENCE','EVIDENCE_REFERENCE',
      'METRIC_OBSERVATION','REVISION_COMPONENT','REVISION_SNAPSHOT',
      'VALUATION_RUN','HARDENING_SNAPSHOT','DECISION_SNAPSHOT'
    )
  ),
  object_schema text,
  object_table text,
  object_key text not null,
  instrument_id uuid references fwios.instruments(instrument_id) on delete restrict,
  resolution_status text not null default 'RESOLVED'
    check (resolution_status in ('RESOLVED','REFERENCE_ONLY')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists lineage_artifacts_type_object_idx
  on fwios.lineage_artifacts(artifact_type,object_key);

create index if not exists lineage_artifacts_instrument_idx
  on fwios.lineage_artifacts(instrument_id)
  where instrument_id is not null;

create table if not exists fwios.lineage_edges (
  edge_id uuid primary key default gen_random_uuid(),
  from_artifact_id uuid not null references fwios.lineage_artifacts(artifact_id) on delete restrict,
  to_artifact_id uuid not null references fwios.lineage_artifacts(artifact_id) on delete restrict,
  edge_type text not null check (
    edge_type in (
      'SOURCE_SUPPORTS_EVIDENCE',
      'EVIDENCE_SUPPORTS_METRIC',
      'METRIC_DERIVES_METRIC',
      'EVIDENCE_SUPPORTS_REVISION_COMPONENT',
      'METRIC_SUPPORTS_REVISION_COMPONENT',
      'REVISION_COMPONENT_CONTRIBUTES_TO_REVISION',
      'METRIC_INPUT_TO_VALUATION',
      'VALUATION_SUPPORTS_HARDENING',
      'EVIDENCE_SUPPORTS_HARDENING',
      'METRIC_SUPPORTS_HARDENING',
      'REVISION_SUPPORTS_DECISION',
      'HARDENING_SUPPORTS_DECISION',
      'VALUATION_SUPPORTS_DECISION'
    )
  ),
  edge_role text not null default '',
  ordinal integer,
  provenance_status text not null default 'RESOLVED'
    check (provenance_status in ('RESOLVED','REFERENCE_ONLY')),
  source_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (from_artifact_id<>to_artifact_id)
);

create unique index if not exists lineage_edges_identity_uidx
  on fwios.lineage_edges(from_artifact_id,to_artifact_id,edge_type,edge_role);

create index if not exists lineage_edges_to_idx
  on fwios.lineage_edges(to_artifact_id,edge_type);

create index if not exists lineage_edges_from_idx
  on fwios.lineage_edges(from_artifact_id,edge_type);

create or replace function fwios.lineage_append_only_guard_v1()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  raise exception 'FWIOS lineage is append-only; % is not allowed on %.%', TG_OP, TG_TABLE_SCHEMA, TG_TABLE_NAME;
end
$function$;

drop trigger if exists lineage_artifacts_append_only on fwios.lineage_artifacts;
create trigger lineage_artifacts_append_only
before update or delete on fwios.lineage_artifacts
for each row execute function fwios.lineage_append_only_guard_v1();

drop trigger if exists lineage_edges_append_only on fwios.lineage_edges;
create trigger lineage_edges_append_only
before update or delete on fwios.lineage_edges
for each row execute function fwios.lineage_append_only_guard_v1();

alter table fwios.lineage_artifacts enable row level security;
alter table fwios.lineage_edges enable row level security;

revoke all on fwios.lineage_artifacts from public,anon,authenticated;
revoke all on fwios.lineage_edges from public,anon,authenticated;

grant select,insert on fwios.lineage_artifacts to service_role;
grant select,insert on fwios.lineage_edges to service_role;

-- Resolved source objects use the existing composite source key.
insert into fwios.lineage_artifacts(
  artifact_key,artifact_type,object_schema,object_table,object_key,resolution_status,metadata
)
select
  'SOURCE:'||md5(s.source_id||'|'||s.source_url),
  'SOURCE',
  'fwios','sources',
  s.source_id||'|'||s.source_url,
  'RESOLVED',
  jsonb_build_object(
    'source_id',s.source_id,
    'source_url',s.source_url,
    'source_tier',s.source_tier,
    'source_type',s.source_type,
    'publisher',s.publisher
  )
from fwios.sources s
on conflict(artifact_key) do nothing;

-- Evidence rows.
insert into fwios.lineage_artifacts(
  artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
)
select
  'EVIDENCE:'||e.evidence_id,
  'EVIDENCE',
  'fwios','evidence_records',
  e.evidence_id,
  e.instrument_id,
  'RESOLVED',
  jsonb_build_object(
    'ticker',e.ticker,
    'source_id',e.source_id,
    'source_url',e.source_url,
    'verification_status',e.verification_status,
    'canonical_metric_gate',e.canonical_metric_gate
  )
from fwios.evidence_records e
on conflict(artifact_key) do nothing;

-- Explicit unresolved evidence references replace lineage-critical array-only references.
with refs as (
  select distinct x.evidence_id
  from (
    select unnest(coalesce(o.evidence_ids,'{}'::text[])) evidence_id
    from fwios.metric_observations o
    union all
    select o.primary_evidence_id
    from fwios.metric_observations o
    where o.primary_evidence_id is not null
    union all
    select unnest(coalesce(c.evidence_ids,'{}'::text[]))
    from fwios.candidate_revision_component_inputs c
  ) x
  where x.evidence_id is not null
)
insert into fwios.lineage_artifacts(
  artifact_key,artifact_type,object_schema,object_table,object_key,resolution_status,metadata
)
select
  'EVIDENCE_REF:'||r.evidence_id,
  'EVIDENCE_REFERENCE',
  null,null,
  r.evidence_id,
  'REFERENCE_ONLY',
  jsonb_build_object(
    'missing_canonical_evidence_record',true,
    'migration_source','LINEAGE_GRAPH_V1'
  )
from refs r
left join fwios.evidence_records e on e.evidence_id=r.evidence_id
where e.evidence_id is null
on conflict(artifact_key) do nothing;

-- Source-reference artifacts only where no exact fwios.sources row resolves the evidence source.
with unresolved_source as (
  select distinct
    e.source_id,e.source_url,
    coalesce(e.source_id,'')||'|'||coalesce(e.source_url,'') source_key
  from fwios.evidence_records e
  left join fwios.sources s
    on s.source_id=e.source_id and s.source_url=e.source_url
  where s.source_id is null
    and (e.source_id is not null or e.source_url is not null)
)
insert into fwios.lineage_artifacts(
  artifact_key,artifact_type,object_schema,object_table,object_key,resolution_status,metadata
)
select
  'SOURCE_REF:'||md5(u.source_key),
  'SOURCE_REFERENCE',
  null,null,
  u.source_key,
  'REFERENCE_ONLY',
  jsonb_build_object('source_id',u.source_id,'source_url',u.source_url)
from unresolved_source u
on conflict(artifact_key) do nothing;

-- Metric observations.
insert into fwios.lineage_artifacts(
  artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
)
select
  'METRIC_OBS:'||o.observation_id::text,
  'METRIC_OBSERVATION',
  'fwios','metric_observations',
  o.observation_id::text,
  o.instrument_id,
  'RESOLVED',
  jsonb_build_object(
    'observation_key',o.observation_key,
    'metric_code',o.metric_code,
    'observation_layer',o.observation_layer,
    'period_label',o.period_label,
    'canonical_unit',o.canonical_unit
  )
from fwios.metric_observations o
on conflict(artifact_key) do nothing;

-- Revision, valuation, hardening and decision artifacts.
insert into fwios.lineage_artifacts(
  artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
)
select
  'REV_COMPONENT:'||c.component_input_id,
  'REVISION_COMPONENT','fwios','candidate_revision_component_inputs',c.component_input_id,
  fwios.resolve_instrument_id_v1(c.ticker,'Stock',null,null),
  'RESOLVED',
  jsonb_build_object('ticker',c.ticker,'component_code',c.component_code,'component_score',c.component_score)
from fwios.candidate_revision_component_inputs c
on conflict(artifact_key) do nothing;

insert into fwios.lineage_artifacts(
  artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
)
select
  'REVISION:'||r.revision_snapshot_id,
  'REVISION_SNAPSHOT','fwios','candidate_revision_snapshots',r.revision_snapshot_id,
  fwios.resolve_instrument_id_v1(r.ticker,'Stock',null,null),
  'RESOLVED',
  jsonb_build_object('ticker',r.ticker,'revision_score',r.revision_score,'revision_gate',r.revision_gate)
from fwios.candidate_revision_snapshots r
on conflict(artifact_key) do nothing;

insert into fwios.lineage_artifacts(
  artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
)
select
  'VALUATION:'||v.run_id,
  'VALUATION_RUN','fwios','valuation_runs',v.run_id,
  fwios.resolve_instrument_id_v1(v.ticker,'Stock',null,null),
  'RESOLVED',
  jsonb_build_object(
    'ticker',v.ticker,
    'model_id',v.model_id,
    'valuation_gate',v.valuation_gate,
    'base_fv_per_share',v.base_fv_per_share
  )
from fwios.valuation_runs v
on conflict(artifact_key) do nothing;

insert into fwios.lineage_artifacts(
  artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
)
select
  'HARDENING:'||h.hardening_snapshot_id,
  'HARDENING_SNAPSHOT','fwios','candidate_quality_hardening_snapshots',h.hardening_snapshot_id,
  fwios.resolve_instrument_id_v1(h.ticker,'Stock',null,null),
  'RESOLVED',
  jsonb_build_object(
    'ticker',h.ticker,
    'overall_gate',h.overall_gate,
    'owner_earnings_gate',h.owner_earnings_gate,
    'valuation_confidence',h.valuation_confidence
  )
from fwios.candidate_quality_hardening_snapshots h
on conflict(artifact_key) do nothing;

insert into fwios.lineage_artifacts(
  artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
)
select
  'DECISION:'||d.decision_snapshot_id,
  'DECISION_SNAPSHOT','fwios','decision_snapshots',d.decision_snapshot_id,
  fwios.resolve_instrument_id_v1(d.ticker,'Stock',null,null),
  'RESOLVED',
  jsonb_build_object(
    'ticker',d.ticker,
    'decision_state',d.decision_state,
    'promotion_gate',d.promotion_gate,
    'core_score',d.core_score
  )
from fwios.decision_snapshots d
on conflict(artifact_key) do nothing;

-- Source -> Evidence.
insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
)
select
  s_art.artifact_id,
  e_art.artifact_id,
  'SOURCE_SUPPORTS_EVIDENCE',
  coalesce(e.evidence_role,''),
  'RESOLVED',
  e.source_url,
  jsonb_build_object('source_id',e.source_id)
from fwios.evidence_records e
join fwios.sources s
  on s.source_id=e.source_id and s.source_url=e.source_url
join fwios.lineage_artifacts s_art
  on s_art.artifact_key='SOURCE:'||md5(s.source_id||'|'||s.source_url)
join fwios.lineage_artifacts e_art
  on e_art.artifact_key='EVIDENCE:'||e.evidence_id
on conflict do nothing;

insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
)
select
  s_art.artifact_id,
  e_art.artifact_id,
  'SOURCE_SUPPORTS_EVIDENCE',
  coalesce(e.evidence_role,''),
  'REFERENCE_ONLY',
  e.source_url,
  jsonb_build_object('source_id',e.source_id,'canonical_source_row_missing',true)
from fwios.evidence_records e
left join fwios.sources s
  on s.source_id=e.source_id and s.source_url=e.source_url
join fwios.lineage_artifacts s_art
  on s_art.artifact_key='SOURCE_REF:'||md5(coalesce(e.source_id,'')||'|'||coalesce(e.source_url,''))
join fwios.lineage_artifacts e_art
  on e_art.artifact_key='EVIDENCE:'||e.evidence_id
where s.source_id is null
  and (e.source_id is not null or e.source_url is not null)
on conflict do nothing;

-- Evidence -> Metric Observation, normalized from evidence arrays.
with obs_evidence as (
  select distinct
    o.observation_id,
    ev_id,
    case when ev_id=o.primary_evidence_id then 'PRIMARY' else 'SUPPORTING' end edge_role
  from fwios.metric_observations o
  cross join lateral unnest(
    array_remove(
      array[o.primary_evidence_id]::text[] || coalesce(o.evidence_ids,'{}'::text[]),
      null
    )
  ) ev_id
)
insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,metadata
)
select
  coalesce(e_art.artifact_id,er_art.artifact_id),
  m_art.artifact_id,
  'EVIDENCE_SUPPORTS_METRIC',
  oe.edge_role,
  case when e_art.artifact_id is not null then 'RESOLVED' else 'REFERENCE_ONLY' end,
  jsonb_build_object('normalized_from','metric_observations.evidence_ids')
from obs_evidence oe
left join fwios.lineage_artifacts e_art
  on e_art.artifact_key='EVIDENCE:'||oe.ev_id
left join fwios.lineage_artifacts er_art
  on er_art.artifact_key='EVIDENCE_REF:'||oe.ev_id
join fwios.lineage_artifacts m_art
  on m_art.artifact_key='METRIC_OBS:'||oe.observation_id::text
where coalesce(e_art.artifact_id,er_art.artifact_id) is not null
on conflict do nothing;

-- Metric -> derived/normalized metric.
with derivation as (
  select o.observation_id target_id, unnest(o.source_observation_ids) source_id
  from fwios.metric_observations o
)
insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,metadata
)
select
  s_art.artifact_id,t_art.artifact_id,
  'METRIC_DERIVES_METRIC',
  'SOURCE_OBSERVATION',
  'RESOLVED',
  jsonb_build_object('normalized_from','metric_observations.source_observation_ids')
from derivation d
join fwios.lineage_artifacts s_art on s_art.artifact_key='METRIC_OBS:'||d.source_id::text
join fwios.lineage_artifacts t_art on t_art.artifact_key='METRIC_OBS:'||d.target_id::text
on conflict do nothing;

-- Evidence -> Revision Component.
with comp_evidence as (
  select c.component_input_id,c.component_code,unnest(c.evidence_ids) evidence_id
  from fwios.candidate_revision_component_inputs c
)
insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
)
select
  coalesce(e_art.artifact_id,er_art.artifact_id),
  c_art.artifact_id,
  'EVIDENCE_SUPPORTS_REVISION_COMPONENT',
  ce.component_code,
  case when e_art.artifact_id is not null then 'RESOLVED' else 'REFERENCE_ONLY' end,
  c.source_reference,
  jsonb_build_object('normalized_from','candidate_revision_component_inputs.evidence_ids')
from comp_evidence ce
join fwios.candidate_revision_component_inputs c
  on c.component_input_id=ce.component_input_id
left join fwios.lineage_artifacts e_art
  on e_art.artifact_key='EVIDENCE:'||ce.evidence_id
left join fwios.lineage_artifacts er_art
  on er_art.artifact_key='EVIDENCE_REF:'||ce.evidence_id
join fwios.lineage_artifacts c_art
  on c_art.artifact_key='REV_COMPONENT:'||ce.component_input_id
where coalesce(e_art.artifact_id,er_art.artifact_id) is not null
on conflict do nothing;

-- Metric observations that share evidence with Revision components.
insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,metadata
)
select distinct
  m_art.artifact_id,
  c_art.artifact_id,
  'METRIC_SUPPORTS_REVISION_COMPONENT',
  c.component_code,
  'RESOLVED',
  jsonb_build_object('join_basis','shared evidence id')
from fwios.candidate_revision_component_inputs c
join fwios.metric_observations o
  on (
    (o.primary_evidence_id is not null and o.primary_evidence_id=any(c.evidence_ids))
    or o.evidence_ids && c.evidence_ids
  )
join fwios.lineage_artifacts m_art
  on m_art.artifact_key='METRIC_OBS:'||o.observation_id::text
join fwios.lineage_artifacts c_art
  on c_art.artifact_key='REV_COMPONENT:'||c.component_input_id
on conflict do nothing;

-- Revision Component -> Revision Snapshot, normalized from component_input_ids / FK.
insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,ordinal,provenance_status,metadata
)
select
  c_art.artifact_id,
  r_art.artifact_id,
  'REVISION_COMPONENT_CONTRIBUTES_TO_REVISION',
  c.component_code,
  x.ord::integer,
  'RESOLVED',
  jsonb_build_object('normalized_from','candidate_revision_snapshots.component_input_ids')
from fwios.candidate_revision_snapshots r
cross join lateral unnest(r.component_input_ids) with ordinality x(component_input_id,ord)
join fwios.candidate_revision_component_inputs c
  on c.component_input_id=x.component_input_id
join fwios.lineage_artifacts c_art
  on c_art.artifact_key='REV_COMPONENT:'||c.component_input_id
join fwios.lineage_artifacts r_art
  on r_art.artifact_key='REVISION:'||r.revision_snapshot_id
on conflict do nothing;

-- Metric Observation -> Valuation Run from explicit valuation_run_inputs.source_key.
insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
)
select
  m_art.artifact_id,
  v_art.artifact_id,
  'METRIC_INPUT_TO_VALUATION',
  vi.input_role||':'||vi.input_key,
  'RESOLVED',
  vi.source_key,
  jsonb_build_object(
    'input_layer',vi.input_layer,
    'input_version',vi.input_version,
    'required',vi.required,
    'gate_status',vi.gate_status
  )
from fwios.valuation_run_inputs vi
join fwios.metric_observations o
  on o.source_key=vi.source_key
join fwios.lineage_artifacts m_art
  on m_art.artifact_key='METRIC_OBS:'||o.observation_id::text
join fwios.lineage_artifacts v_art
  on v_art.artifact_key='VALUATION:'||vi.run_id
where vi.input_layer in ('CANONICAL','NORMALIZED','EVIDENCE')
on conflict do nothing;

-- Valuation -> Hardening.
insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
)
select
  v_art.artifact_id,
  h_art.artifact_id,
  'VALUATION_SUPPORTS_HARDENING',
  'VALUATION_RUN',
  'RESOLVED',
  h.source_reference,
  jsonb_build_object(
    'mispricing_snapshot_id',h.mispricing_snapshot_id,
    'policy_version_id',h.policy_version_id
  )
from fwios.candidate_quality_hardening_snapshots h
join fwios.lineage_artifacts v_art on v_art.artifact_key='VALUATION:'||h.valuation_run_id
join fwios.lineage_artifacts h_art on h_art.artifact_key='HARDENING:'||h.hardening_snapshot_id
on conflict do nothing;

-- PINS hardening v2 explicit evidence inputs replacing prose-only owner-economics lineage.
with pins_hardening_evidence(evidence_id,edge_role) as (
  values
    ('QH-PINS-H1-26-FCF-20260906','OWNER_EARNINGS_FCF'),
    ('QH-PINS-H1-26-SBC-20260906','OWNER_EARNINGS_SBC'),
    ('QH-PINS-H1-26-BUYBACK-20260906','OWNER_EARNINGS_BUYBACKS'),
    ('QH-PINS-Q2-25-SHARES-20260906','DILUTION_PRIOR_SHARES'),
    ('QH-PINS-Q2-26-SHARES-20260906','DILUTION_CURRENT_SHARES'),
    ('QH-PINS-FY22-REV-20260906','DURABILITY_REVENUE'),
    ('QH-PINS-FY23-REV-20260906','DURABILITY_REVENUE'),
    ('QH-PINS-FY24-REV-20260906','DURABILITY_REVENUE'),
    ('QH-PINS-FY25-REV-20260906','DURABILITY_REVENUE'),
    ('QH-PINS-FY24-MAU-20260906','DURABILITY_USERS'),
    ('QH-PINS-FY25-MAU-20260906','DURABILITY_USERS'),
    ('QH-PINS-Q2-26-USER-STREAK-20260906','DURABILITY_USER_STREAK')
)
insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
)
select
  e_art.artifact_id,
  h_art.artifact_id,
  'EVIDENCE_SUPPORTS_HARDENING',
  p.edge_role,
  'RESOLVED',
  e.source_url,
  jsonb_build_object(
    'hardening_snapshot_id','HARD-PINS-20260906-V2',
    'normalized_from','existing hardening evidence_payload / primary evidence set'
  )
from pins_hardening_evidence p
join fwios.evidence_records e on e.evidence_id=p.evidence_id
join fwios.lineage_artifacts e_art on e_art.artifact_key='EVIDENCE:'||p.evidence_id
join fwios.lineage_artifacts h_art on h_art.artifact_key='HARDENING:HARD-PINS-20260906-V2'
on conflict do nothing;

-- Metric observations that directly represent owner-economics inputs.
insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,metadata
)
select
  m_art.artifact_id,
  h_art.artifact_id,
  'METRIC_SUPPORTS_HARDENING',
  case
    when o.metric_code='FREE_CASH_FLOW' then 'OWNER_EARNINGS_FCF'
    when o.metric_code='SHARE_BASED_COMPENSATION' then 'OWNER_EARNINGS_SBC'
    when o.metric_code='SHARE_REPURCHASES' then 'OWNER_EARNINGS_BUYBACKS'
    when o.metric_code='SBC_TO_REVENUE' then 'OWNER_EARNINGS_SBC_RATIO'
    when o.metric_code='SHARES_OUTSTANDING' then 'DILUTION_SHARES'
    else 'HARDENING_METRIC'
  end,
  'RESOLVED',
  jsonb_build_object('hardening_snapshot_id','HARD-PINS-20260906-V2')
from fwios.metric_observations o
join fwios.lineage_artifacts m_art
  on m_art.artifact_key='METRIC_OBS:'||o.observation_id::text
join fwios.lineage_artifacts h_art
  on h_art.artifact_key='HARDENING:HARD-PINS-20260906-V2'
where o.instrument_id=fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
  and (
    o.primary_evidence_id in (
      'QH-PINS-H1-26-FCF-20260906',
      'QH-PINS-H1-26-SBC-20260906',
      'QH-PINS-H1-26-BUYBACK-20260906',
      'QH-PINS-Q2-25-SHARES-20260906',
      'QH-PINS-Q2-26-SHARES-20260906'
    )
    or (
      o.metric_code='SBC_TO_REVENUE'
      and o.period_type='LTM'
      and o.fiscal_year=2026
    )
  )
on conflict do nothing;

-- Revision / Hardening / Valuation -> Decision from existing explicit FKs.
insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,metadata
)
select
  r_art.artifact_id,d_art.artifact_id,
  'REVISION_SUPPORTS_DECISION','REVISION_SNAPSHOT','RESOLVED','{}'::jsonb
from fwios.decision_snapshots d
join fwios.lineage_artifacts r_art on r_art.artifact_key='REVISION:'||d.revision_snapshot_id
join fwios.lineage_artifacts d_art on d_art.artifact_key='DECISION:'||d.decision_snapshot_id
where d.revision_snapshot_id is not null
on conflict do nothing;

insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,metadata
)
select
  h_art.artifact_id,d_art.artifact_id,
  'HARDENING_SUPPORTS_DECISION','HARDENING_SNAPSHOT','RESOLVED','{}'::jsonb
from fwios.decision_snapshots d
join fwios.lineage_artifacts h_art on h_art.artifact_key='HARDENING:'||d.hardening_snapshot_id
join fwios.lineage_artifacts d_art on d_art.artifact_key='DECISION:'||d.decision_snapshot_id
where d.hardening_snapshot_id is not null
on conflict do nothing;

insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,metadata
)
select
  v_art.artifact_id,d_art.artifact_id,
  'VALUATION_SUPPORTS_DECISION','VALUATION_RUN','RESOLVED','{}'::jsonb
from fwios.decision_snapshots d
join fwios.lineage_artifacts v_art on v_art.artifact_key='VALUATION:'||d.valuation_run_id
join fwios.lineage_artifacts d_art on d_art.artifact_key='DECISION:'||d.decision_snapshot_id
on conflict do nothing;

create or replace view fwios.v_lineage_edges_resolved
with (security_invoker=true)
as
select
  e.edge_id,
  e.edge_type,
  e.edge_role,
  e.ordinal,
  e.provenance_status,
  e.source_reference,
  f.artifact_key from_artifact_key,
  f.artifact_type from_artifact_type,
  f.object_key from_object_key,
  f.instrument_id from_instrument_id,
  t.artifact_key to_artifact_key,
  t.artifact_type to_artifact_type,
  t.object_key to_object_key,
  t.instrument_id to_instrument_id,
  e.metadata,
  e.created_at
from fwios.lineage_edges e
join fwios.lineage_artifacts f on f.artifact_id=e.from_artifact_id
join fwios.lineage_artifacts t on t.artifact_id=e.to_artifact_id;

revoke all on fwios.v_lineage_edges_resolved from public,anon,authenticated;
grant select on fwios.v_lineage_edges_resolved to service_role;

create or replace function fwios.lineage_trace_v1(
  p_artifact_key text,
  p_direction text default 'UPSTREAM',
  p_max_depth integer default 8
)
returns table(
  depth integer,
  edge_type text,
  edge_role text,
  provenance_status text,
  from_artifact_key text,
  from_artifact_type text,
  to_artifact_key text,
  to_artifact_type text
)
language plpgsql
stable
set search_path to ''
as $function$
begin
  if upper(coalesce(p_direction,'')) not in ('UPSTREAM','DOWNSTREAM') then
    raise exception 'p_direction must be UPSTREAM or DOWNSTREAM';
  end if;

  if p_max_depth<1 or p_max_depth>20 then
    raise exception 'p_max_depth must be between 1 and 20';
  end if;

  if upper(p_direction)='UPSTREAM' then
    return query
    with recursive walk as (
      select
        0 depth,
        a.artifact_id current_artifact_id,
        array[a.artifact_id]::uuid[] path
      from fwios.lineage_artifacts a
      where a.artifact_key=p_artifact_key

      union all

      select
        w.depth+1,
        e.from_artifact_id,
        w.path||e.from_artifact_id
      from walk w
      join fwios.lineage_edges e on e.to_artifact_id=w.current_artifact_id
      where w.depth<p_max_depth
        and not e.from_artifact_id=any(w.path)
    ),
    traced as (
      select distinct
        w.depth+1 depth,
        e.edge_id
      from walk w
      join fwios.lineage_edges e on e.to_artifact_id=w.current_artifact_id
      where w.depth<p_max_depth
    )
    select
      tr.depth,
      e.edge_type,
      e.edge_role,
      e.provenance_status,
      f.artifact_key,
      f.artifact_type,
      t.artifact_key,
      t.artifact_type
    from traced tr
    join fwios.lineage_edges e on e.edge_id=tr.edge_id
    join fwios.lineage_artifacts f on f.artifact_id=e.from_artifact_id
    join fwios.lineage_artifacts t on t.artifact_id=e.to_artifact_id
    order by tr.depth,e.edge_type,f.artifact_key;
  else
    return query
    with recursive walk as (
      select
        0 depth,
        a.artifact_id current_artifact_id,
        array[a.artifact_id]::uuid[] path
      from fwios.lineage_artifacts a
      where a.artifact_key=p_artifact_key

      union all

      select
        w.depth+1,
        e.to_artifact_id,
        w.path||e.to_artifact_id
      from walk w
      join fwios.lineage_edges e on e.from_artifact_id=w.current_artifact_id
      where w.depth<p_max_depth
        and not e.to_artifact_id=any(w.path)
    ),
    traced as (
      select distinct
        w.depth+1 depth,
        e.edge_id
      from walk w
      join fwios.lineage_edges e on e.from_artifact_id=w.current_artifact_id
      where w.depth<p_max_depth
    )
    select
      tr.depth,
      e.edge_type,
      e.edge_role,
      e.provenance_status,
      f.artifact_key,
      f.artifact_type,
      t.artifact_key,
      t.artifact_type
    from traced tr
    join fwios.lineage_edges e on e.edge_id=tr.edge_id
    join fwios.lineage_artifacts f on f.artifact_id=e.from_artifact_id
    join fwios.lineage_artifacts t on t.artifact_id=e.to_artifact_id
    order by tr.depth,e.edge_type,t.artifact_key;
  end if;
end
$function$;

revoke all on function fwios.lineage_trace_v1(text,text,integer)
  from public,anon,authenticated;
grant execute on function fwios.lineage_trace_v1(text,text,integer)
  to service_role;

-- Register regression outcomes.
with tests(test_case,passed,notes) as (
  values
    ('policy active / append-only / no read cutover',
      exists(
        select 1 from fwios.policy_versions
        where policy_version_id='POL-LINEAGE-GRAPH-V1'
          and lifecycle_status='ACTIVE'
          and config->>'append_only'='true'
          and config->>'production_read_cutover'='false'
          and config->>'auto_trade'='false'
      ),
      'Lineage is audit-only foundation.'),

    ('metric evidence arrays normalized',
      not exists(
        select 1
        from fwios.metric_observations o
        cross join lateral unnest(
          array_remove(array[o.primary_evidence_id]::text[]||coalesce(o.evidence_ids,'{}'::text[]),null)
        ) ev_id
        where not exists(
          select 1
          from fwios.v_lineage_edges_resolved l
          where l.edge_type='EVIDENCE_SUPPORTS_METRIC'
            and l.to_artifact_key='METRIC_OBS:'||o.observation_id::text
            and l.from_object_key=ev_id
        )
      ),
      'No metric evidence relation depends only on arrays.'),

    ('metric derivation arrays normalized',
      not exists(
        select 1
        from fwios.metric_observations o
        cross join lateral unnest(o.source_observation_ids) src_id
        where not exists(
          select 1
          from fwios.v_lineage_edges_resolved l
          where l.edge_type='METRIC_DERIVES_METRIC'
            and l.to_artifact_key='METRIC_OBS:'||o.observation_id::text
            and l.from_object_key=src_id::text
        )
      ),
      'No source-observation derivation depends only on arrays.'),

    ('revision evidence arrays normalized',
      not exists(
        select 1
        from fwios.candidate_revision_component_inputs c
        cross join lateral unnest(c.evidence_ids) ev_id
        where not exists(
          select 1
          from fwios.v_lineage_edges_resolved l
          where l.edge_type='EVIDENCE_SUPPORTS_REVISION_COMPONENT'
            and l.to_artifact_key='REV_COMPONENT:'||c.component_input_id
            and l.from_object_key=ev_id
        )
      ),
      'Revision component evidence IDs are explicit edges.'),

    ('revision component arrays normalized',
      not exists(
        select 1
        from fwios.candidate_revision_snapshots r
        cross join lateral unnest(r.component_input_ids) comp_id
        where not exists(
          select 1
          from fwios.v_lineage_edges_resolved l
          where l.edge_type='REVISION_COMPONENT_CONTRIBUTES_TO_REVISION'
            and l.to_artifact_key='REVISION:'||r.revision_snapshot_id
            and l.from_object_key=comp_id
        )
      ),
      'Revision snapshot components are explicit edges.'),

    ('ADBE revision has four components',
      (select count(*) from fwios.v_lineage_edges_resolved
       where edge_type='REVISION_COMPONENT_CONTRIBUTES_TO_REVISION'
         and to_artifact_key='REVISION:REV-ADBE-Q3-2026-FINALIST-V2-COMPLETE')=4,
      'ADBE 47.5878 trace includes all four Revision V2 components.'),

    ('ADBE revision components all have evidence',
      not exists(
        select 1
        from fwios.v_lineage_edges_resolved rc
        where rc.edge_type='REVISION_COMPONENT_CONTRIBUTES_TO_REVISION'
          and rc.to_artifact_key='REVISION:REV-ADBE-Q3-2026-FINALIST-V2-COMPLETE'
          and not exists(
            select 1 from fwios.v_lineage_edges_resolved ev
            where ev.edge_type='EVIDENCE_SUPPORTS_REVISION_COMPONENT'
              and ev.to_artifact_key=rc.from_artifact_key
          )
      ),
      'Every ADBE component resolves to evidence or an explicit unresolved evidence reference.'),

    ('ADBE unresolved consensus evidence is explicit',
      (select count(*) from fwios.v_lineage_edges_resolved
       where edge_type='EVIDENCE_SUPPORTS_REVISION_COMPONENT'
         and to_artifact_key='REV_COMPONENT:REVCOMP-ADBE-CONSENSUS-Q3-2026-V2'
         and provenance_status='REFERENCE_ONLY')=2,
      'Missing canonical Zacks evidence rows are visible, not hidden in an array.'),

    ('PINS hardening owner economics evidence explicit',
      (select count(*) from fwios.v_lineage_edges_resolved
       where edge_type='EVIDENCE_SUPPORTS_HARDENING'
         and to_artifact_key='HARDENING:HARD-PINS-20260906-V2'
         and edge_role in (
           'OWNER_EARNINGS_FCF','OWNER_EARNINGS_SBC','OWNER_EARNINGS_BUYBACKS',
           'DILUTION_PRIOR_SHARES','DILUTION_CURRENT_SHARES'
         ))=5,
      'PINS REVIEW traces to FCF, SBC, buybacks and share-count evidence.'),

    ('PINS owner economics metric path explicit',
      exists(
        select 1 from fwios.v_lineage_edges_resolved
        where edge_type='METRIC_SUPPORTS_HARDENING'
          and to_artifact_key='HARDENING:HARD-PINS-20260906-V2'
          and edge_role='OWNER_EARNINGS_FCF'
      )
      and exists(
        select 1 from fwios.v_lineage_edges_resolved
        where edge_type='METRIC_SUPPORTS_HARDENING'
          and to_artifact_key='HARDENING:HARD-PINS-20260906-V2'
          and edge_role='OWNER_EARNINGS_SBC'
      )
      and exists(
        select 1 from fwios.v_lineage_edges_resolved
        where edge_type='METRIC_SUPPORTS_HARDENING'
          and to_artifact_key='HARDENING:HARD-PINS-20260906-V2'
          and edge_role='OWNER_EARNINGS_BUYBACKS'
      ),
      'Owner-economics hardening has typed metric observations, not only prose.'),

    ('PINS hardening connects to decision',
      exists(
        select 1 from fwios.v_lineage_edges_resolved
        where edge_type='HARDENING_SUPPORTS_DECISION'
          and from_artifact_key='HARDENING:HARD-PINS-20260906-V2'
          and to_artifact_key='DECISION:DEC-PINS-QH-20260906-V2'
      ),
      'Hardening output is connected to an existing decision snapshot.'),

    ('PINS valuation metric inputs explicit',
      exists(
        select 1 from fwios.v_lineage_edges_resolved
        where edge_type='METRIC_INPUT_TO_VALUATION'
          and to_artifact_key='VALUATION:VAL-SUPA-PINS-DIGADS-20260905'
          and edge_role like 'NORMALIZED:%'
      ),
      'Valuation source_key mappings are normalized into metric->valuation edges.'),

    ('trace rpc reaches owner evidence from PINS decision',
      exists(
        select 1
        from fwios.lineage_trace_v1('DECISION:DEC-PINS-QH-20260906-V2','UPSTREAM',8)
        where from_artifact_key='EVIDENCE:QH-PINS-H1-26-SBC-20260906'
      )
      and exists(
        select 1
        from fwios.lineage_trace_v1('DECISION:DEC-PINS-QH-20260906-V2','UPSTREAM',8)
        where from_artifact_key='EVIDENCE:QH-PINS-H1-26-FCF-20260906'
      ),
      'Audit/AI trace can walk from decision back to owner-economics evidence.'),

    ('append-only triggers installed',
      (select count(*) from pg_trigger
       where tgrelid in ('fwios.lineage_artifacts'::regclass,'fwios.lineage_edges'::regclass)
         and not tgisinternal
         and tgname in ('lineage_artifacts_append_only','lineage_edges_append_only'))=2,
      'Update/delete is guarded at database level.'),

    ('human execution only',
      (select config->>'human_execution_only'='true'
       from fwios.policy_versions where policy_version_id='POL-LINEAGE-GRAPH-V1'),
      'Lineage graph cannot trade.')
),
numbered as (
  select row_number() over(order by test_case) n,* from tests
)
insert into fwios.decision_policy_regression_runs(
  regression_id,policy_key,policy_version_id,test_case,input_payload,
  expected_payload,actual_payload,status,tolerance,notes
)
select
  'REG-LINEAGE-V1-'||lpad(n::text,2,'0'),
  'LINEAGE_GRAPH',
  'POL-LINEAGE-GRAPH-V1',
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
