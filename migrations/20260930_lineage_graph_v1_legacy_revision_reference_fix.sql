-- Lineage Graph v1 legacy Revision reference normalization
-- Some legacy candidate_revision_snapshots.component_input_ids entries contain evidence reference IDs
-- rather than candidate_revision_component_inputs IDs. Preserve the historical shape explicitly;
-- do not fabricate revision components.

alter table fwios.lineage_edges
  drop constraint if exists lineage_edges_edge_type_check;

alter table fwios.lineage_edges
  add constraint lineage_edges_edge_type_check check (
    edge_type in (
      'SOURCE_SUPPORTS_EVIDENCE',
      'EVIDENCE_SUPPORTS_METRIC',
      'METRIC_DERIVES_METRIC',
      'EVIDENCE_SUPPORTS_REVISION_COMPONENT',
      'METRIC_SUPPORTS_REVISION_COMPONENT',
      'REVISION_COMPONENT_CONTRIBUTES_TO_REVISION',
      'EVIDENCE_SUPPORTS_REVISION_SNAPSHOT',
      'METRIC_INPUT_TO_VALUATION',
      'VALUATION_SUPPORTS_HARDENING',
      'EVIDENCE_SUPPORTS_HARDENING',
      'METRIC_SUPPORTS_HARDENING',
      'REVISION_SUPPORTS_DECISION',
      'HARDENING_SUPPORTS_DECISION',
      'VALUATION_SUPPORTS_DECISION'
    )
  );

with legacy_ref as (
  select
    r.revision_snapshot_id,
    r.ticker,
    x.comp_id,
    x.ord
  from fwios.candidate_revision_snapshots r
  cross join lateral unnest(r.component_input_ids) with ordinality x(comp_id,ord)
  left join fwios.candidate_revision_component_inputs c on c.component_input_id=x.comp_id
  where c.component_input_id is null
)
insert into fwios.lineage_edges(
  from_artifact_id,to_artifact_id,edge_type,edge_role,ordinal,
  provenance_status,source_reference,metadata
)
select
  coalesce(e_art.artifact_id,er_art.artifact_id),
  r_art.artifact_id,
  'EVIDENCE_SUPPORTS_REVISION_SNAPSHOT',
  'LEGACY_COMPONENT_SLOT_REFERENCE',
  lr.ord::integer,
  case when e_art.artifact_id is not null then 'RESOLVED' else 'REFERENCE_ONLY' end,
  null,
  jsonb_build_object(
    'legacy_field','candidate_revision_snapshots.component_input_ids',
    'legacy_semantic_mismatch',true,
    'note','Legacy snapshot stored an evidence/reference ID in component_input_ids; normalized without fabricating a component.'
  )
from legacy_ref lr
left join fwios.lineage_artifacts e_art on e_art.artifact_key='EVIDENCE:'||lr.comp_id
left join fwios.lineage_artifacts er_art on er_art.artifact_key='EVIDENCE_REF:'||lr.comp_id
join fwios.lineage_artifacts r_art on r_art.artifact_key='REVISION:'||lr.revision_snapshot_id
where coalesce(e_art.artifact_id,er_art.artifact_id) is not null
on conflict do nothing;

-- Refresh the two affected registered regression results using the corrected semantic rule.
with normalized as (
  select not exists(
    select 1
    from fwios.candidate_revision_snapshots r
    cross join lateral unnest(r.component_input_ids) comp_id
    left join fwios.candidate_revision_component_inputs c on c.component_input_id=comp_id
    where not (
      (c.component_input_id is not null and exists(
        select 1 from fwios.v_lineage_edges_resolved l
        where l.edge_type='REVISION_COMPONENT_CONTRIBUTES_TO_REVISION'
          and l.to_artifact_key='REVISION:'||r.revision_snapshot_id
          and l.from_object_key=comp_id
      ))
      or
      (c.component_input_id is null and exists(
        select 1 from fwios.v_lineage_edges_resolved l
        where l.edge_type='EVIDENCE_SUPPORTS_REVISION_SNAPSHOT'
          and l.to_artifact_key='REVISION:'||r.revision_snapshot_id
          and l.from_object_key=comp_id
      ))
    )
  ) passed
)
update fwios.decision_policy_regression_runs
set
  actual_payload=jsonb_build_object('passed',(select passed from normalized)),
  status=case when (select passed from normalized) then 'PASS' else 'FAIL' end,
  notes='Legacy component_input_ids are normalized as component edges when a component exists, otherwise as explicit evidence/reference edges without fabricating components.'
where policy_version_id='POL-LINEAGE-GRAPH-V1'
  and test_case='Revision snapshot components are explicit edges.';

update fwios.decision_policy_regression_runs
set
  actual_payload=jsonb_build_object(
    'passed',
    not exists(
      select 1 from fwios.decision_policy_regression_runs r2
      where r2.policy_version_id='POL-LINEAGE-GRAPH-V1'
        and r2.regression_id<>fwios.decision_policy_regression_runs.regression_id
        and r2.status<>'PASS'
    )
  ),
  status=case when not exists(
    select 1 from fwios.decision_policy_regression_runs r2
    where r2.policy_version_id='POL-LINEAGE-GRAPH-V1'
      and r2.regression_id<>fwios.decision_policy_regression_runs.regression_id
      and r2.status<>'PASS'
  ) then 'PASS' else 'FAIL' end
where policy_version_id='POL-LINEAGE-GRAPH-V1'
  and test_case='Human execution only.';
