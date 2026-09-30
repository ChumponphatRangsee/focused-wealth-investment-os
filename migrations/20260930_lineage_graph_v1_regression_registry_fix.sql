-- Lineage Graph v1 regression registry repair
-- Epic #31 / Issue #35
-- Runtime lineage semantics were corrected by the legacy-reference fix, but the prior
-- registry UPDATE targeted an obsolete test-case label. Recompute the stable regression row.

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
  notes='Revision snapshot component_input_ids are explicit lineage edges; legacy evidence/reference IDs are represented without fabricating revision components.'
where regression_id='REG-LINEAGE-V1-13'
  and policy_version_id='POL-LINEAGE-GRAPH-V1';
