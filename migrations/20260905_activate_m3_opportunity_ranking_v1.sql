begin;

do $$
declare v_total int; v_fail int;
begin
  select count(*),count(*) filter (where status='FAIL') into v_total,v_fail
  from fwios.decision_policy_regression_runs
  where policy_key='OPPORTUNITY_RANKING';
  if v_total < 8 or v_fail <> 0 then
    raise exception 'Opportunity Ranking activation blocked: total %, fail %',v_total,v_fail;
  end if;
end $$;

insert into fwios.policy_versions
(policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference,effective_at)
select
  'POL-OPPORTUNITY-RANKING-V1',
  'OPPORTUNITY_RANKING',
  '1.0',
  'ACTIVE',
  true,
  config || jsonb_build_object('regression_suite','8/8 PASS','activation_gate','BOUNDARY_AND_PRODUCTION_PARITY_PASS'),
  'M3.1 Opportunity Ranking v1; 8/8 regressions PASS; production Decision Snapshot parity verified',
  now()
from fwios.policy_versions
where policy_version_id='POL-OPPORTUNITY-RANKING-V1-DRAFT'
on conflict (policy_version_id) do update
set lifecycle_status='ACTIVE',
    deterministic_scoring=true,
    config=excluded.config,
    source_reference=excluded.source_reference,
    effective_at=coalesce(fwios.policy_versions.effective_at,excluded.effective_at);

update fwios.policy_registry
set lifecycle_status='ACTIVE',updated_at=now()
where policy_key='OPPORTUNITY_RANKING';

update fwios.decision_policy_regression_runs
set policy_version_id='POL-OPPORTUNITY-RANKING-V1'
where policy_key='OPPORTUNITY_RANKING';

commit;

-- Production ranking snapshots are runtime state, not schema migration state.
-- The first live run is OPPRANK-M3-20260905-01 on PORTFOLIO-M2-20260905-01.
