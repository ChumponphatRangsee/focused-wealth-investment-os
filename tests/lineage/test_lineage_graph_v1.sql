-- Evidence → Metric → Decision Lineage Graph v1 regression checks
with tests as (
  select 'LIN01_POLICY_ACTIVE' test_id,
    exists(
      select 1 from fwios.policy_versions
      where policy_version_id='POL-LINEAGE-GRAPH-V1'
        and lifecycle_status='ACTIVE'
        and config->>'append_only'='true'
        and config->>'production_read_cutover'='false'
        and config->>'auto_trade'='false'
    ) passed

  union all select 'LIN02_METRIC_EVIDENCE_NORMALIZED',
    not exists(
      select 1
      from fwios.metric_observations o
      cross join lateral unnest(
        array_remove(array[o.primary_evidence_id]::text[]||coalesce(o.evidence_ids,'{}'::text[]),null)
      ) ev_id
      where not exists(
        select 1 from fwios.v_lineage_edges_resolved l
        where l.edge_type='EVIDENCE_SUPPORTS_METRIC'
          and l.to_artifact_key='METRIC_OBS:'||o.observation_id::text
          and l.from_object_key=ev_id
      )
    )

  union all select 'LIN03_METRIC_DERIVATIONS_NORMALIZED',
    not exists(
      select 1
      from fwios.metric_observations o
      cross join lateral unnest(o.source_observation_ids) src_id
      where not exists(
        select 1 from fwios.v_lineage_edges_resolved l
        where l.edge_type='METRIC_DERIVES_METRIC'
          and l.to_artifact_key='METRIC_OBS:'||o.observation_id::text
          and l.from_object_key=src_id::text
      )
    )

  union all select 'LIN04_REVISION_EVIDENCE_NORMALIZED',
    not exists(
      select 1
      from fwios.candidate_revision_component_inputs c
      cross join lateral unnest(c.evidence_ids) ev_id
      where not exists(
        select 1 from fwios.v_lineage_edges_resolved l
        where l.edge_type='EVIDENCE_SUPPORTS_REVISION_COMPONENT'
          and l.to_artifact_key='REV_COMPONENT:'||c.component_input_id
          and l.from_object_key=ev_id
      )
    )

  union all select 'LIN05_REVISION_COMPONENTS_NORMALIZED',
    not exists(
      select 1
      from fwios.candidate_revision_snapshots r
      cross join lateral unnest(r.component_input_ids) comp_id
      where not exists(
        select 1 from fwios.v_lineage_edges_resolved l
        where l.edge_type='REVISION_COMPONENT_CONTRIBUTES_TO_REVISION'
          and l.to_artifact_key='REVISION:'||r.revision_snapshot_id
          and l.from_object_key=comp_id
      )
    )

  union all select 'LIN06_ADBE_FOUR_COMPONENTS',
    (select count(*) from fwios.v_lineage_edges_resolved
     where edge_type='REVISION_COMPONENT_CONTRIBUTES_TO_REVISION'
       and to_artifact_key='REVISION:REV-ADBE-Q3-2026-FINALIST-V2-COMPLETE')=4

  union all select 'LIN07_ADBE_EVIDENCE_COMPLETE_OR_EXPLICIT_REF',
    not exists(
      select 1 from fwios.v_lineage_edges_resolved rc
      where rc.edge_type='REVISION_COMPONENT_CONTRIBUTES_TO_REVISION'
        and rc.to_artifact_key='REVISION:REV-ADBE-Q3-2026-FINALIST-V2-COMPLETE'
        and not exists(
          select 1 from fwios.v_lineage_edges_resolved ev
          where ev.edge_type='EVIDENCE_SUPPORTS_REVISION_COMPONENT'
            and ev.to_artifact_key=rc.from_artifact_key
        )
    )

  union all select 'LIN08_ADBE_ZACKS_GAP_VISIBLE',
    (select count(*) from fwios.v_lineage_edges_resolved
     where edge_type='EVIDENCE_SUPPORTS_REVISION_COMPONENT'
       and to_artifact_key='REV_COMPONENT:REVCOMP-ADBE-CONSENSUS-Q3-2026-V2'
       and provenance_status='REFERENCE_ONLY')=2

  union all select 'LIN09_PINS_OWNER_EVIDENCE',
    (select count(*) from fwios.v_lineage_edges_resolved
     where edge_type='EVIDENCE_SUPPORTS_HARDENING'
       and to_artifact_key='HARDENING:HARD-PINS-20260906-V2'
       and edge_role in (
         'OWNER_EARNINGS_FCF','OWNER_EARNINGS_SBC','OWNER_EARNINGS_BUYBACKS',
         'DILUTION_PRIOR_SHARES','DILUTION_CURRENT_SHARES'
       ))=5

  union all select 'LIN10_PINS_OWNER_METRICS',
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
    )

  union all select 'LIN11_PINS_HARDENING_TO_DECISION',
    exists(
      select 1 from fwios.v_lineage_edges_resolved
      where edge_type='HARDENING_SUPPORTS_DECISION'
        and from_artifact_key='HARDENING:HARD-PINS-20260906-V2'
        and to_artifact_key='DECISION:DEC-PINS-QH-20260906-V2'
    )

  union all select 'LIN12_VALUATION_INPUT_EDGES',
    exists(
      select 1 from fwios.v_lineage_edges_resolved
      where edge_type='METRIC_INPUT_TO_VALUATION'
        and to_artifact_key='VALUATION:VAL-SUPA-PINS-DIGADS-20260905'
    )

  union all select 'LIN13_TRACE_RPC',
    exists(
      select 1
      from fwios.lineage_trace_v1('DECISION:DEC-PINS-QH-20260906-V2','UPSTREAM',8)
      where from_artifact_key='EVIDENCE:QH-PINS-H1-26-SBC-20260906'
    )
    and exists(
      select 1
      from fwios.lineage_trace_v1('DECISION:DEC-PINS-QH-20260906-V2','UPSTREAM',8)
      where from_artifact_key='EVIDENCE:QH-PINS-H1-26-FCF-20260906'
    )

  union all select 'LIN14_APPEND_ONLY_TRIGGERS',
    (select count(*) from pg_trigger
     where tgrelid in ('fwios.lineage_artifacts'::regclass,'fwios.lineage_edges'::regclass)
       and not tgisinternal
       and tgname in ('lineage_artifacts_append_only','lineage_edges_append_only'))=2

  union all select 'LIN15_PRIVATE_RLS',
    not exists(
      select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='fwios'
        and c.relname in ('lineage_artifacts','lineage_edges')
        and c.relrowsecurity=false
    )

  union all select 'LIN16_REGISTERED_REGRESSIONS_PASS',
    not exists(
      select 1 from fwios.decision_policy_regression_runs
      where policy_version_id='POL-LINEAGE-GRAPH-V1'
        and status<>'PASS'
    )
)
select test_id,case when passed then 'PASS' else 'FAIL' end status
from tests
order by test_id;
