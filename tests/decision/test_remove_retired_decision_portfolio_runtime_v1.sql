-- Retired runtime cleanup acceptance.
with checks as (
  select 'LRC-01 legacy functions removed' test_id,
    (select count(*)=0
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='fwios'
       and p.proname in (
         'preview_decision_refresh_bridge_v1',
         'apply_decision_refresh_bridge_v1',
         'preview_opportunity_ranking_refresh_bridge_v1',
         'apply_opportunity_ranking_refresh_bridge_v1',
         'refresh_opportunity_quality_v2',
         'preview_candidate_portfolio_fit_v2',
         'materialize_candidate_portfolio_fit_v2'
       )) ok
  union all select 'LRC-02 active v2/v3 runtime remains',
    (select count(*)=3
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='fwios'
       and p.proname in (
         'preview_decision_refresh_bridge_v2',
         'apply_decision_refresh_bridge_v2',
         'refresh_opportunity_quality_v3'
       ))
  union all select 'LRC-03 retired bridge marked removed',
    exists(select 1 from fwios.policy_versions
      where policy_version_id='POL-DECISION-RANKING-REFRESH-BRIDGE-V1'
        and lifecycle_status='RETIRED'
        and config->>'runtime_removed'='true')
  union all select 'LRC-04 retired opportunity v2 marked removed',
    exists(select 1 from fwios.policy_versions
      where policy_version_id='POL-OPPORTUNITY-QUALITY-V2'
        and lifecycle_status='RETIRED'
        and config->>'runtime_removed'='true')
  union all select 'LRC-05 retired portfolio fit marked removed',
    exists(select 1 from fwios.policy_versions
      where policy_version_id='POL-PORTFOLIO-FIT-V1'
        and lifecycle_status='RETIRED'
        and config->>'runtime_removed'='true')
  union all select 'LRC-06 retired registry backing cleared',
    (select count(*)=2 from fwios.policy_registry
      where policy_key in ('DECISION_RANKING_REFRESH_BRIDGE','OPPORTUNITY_QUALITY_V2')
        and lifecycle_status='RETIRED' and backing_object is null)
  union all select 'LRC-07 audit fit snapshots retained',
    (select count(*)=5 from fwios.candidate_portfolio_fit_snapshots)
  union all select 'LRC-08 audit ranking rows retained',
    (select count(*)=9 from fwios.opportunity_ranked_candidates)
  union all select 'LRC-09 portfolio-independent decisions intact',
    (select count(*)=3 from fwios.v_latest_decision_snapshots
      where ticker in ('ACN','EOG','NFLX')
        and portfolio_batch_id is null
        and portfolio_fit_snapshot_id is null)
  union all select 'LRC-10 retired ranking remains invisible',
    (select count(*)=0 from fwios.v_opportunity_ranking_current)
)
select test_id, case when ok then 'PASS' else 'FAIL' end status
from checks order by test_id;
