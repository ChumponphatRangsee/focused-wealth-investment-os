-- FWIOS MVP-1 Decision / Ranking Refresh Bridge v1
-- Live acceptance baseline: 2026-10-27 Asia/Bangkok.
-- Read-only regression: returns one row per assertion; every row must be PASS.
-- This test intentionally verifies fail-closed downstream behavior and does not mutate data.

with latest_acn as (
  select d.*,s.hardening_gate,s.portfolio_gate,s.revision_gate,s.chase_gate
  from fwios.v_latest_decision_snapshots d
  join fwios.candidate_decision_scores s on s.score_snapshot_id=d.score_snapshot_id
  where d.ticker='ACN'
),
latest_eog as (
  select d.*,s.hardening_gate,s.portfolio_gate,s.revision_gate,s.chase_gate
  from fwios.v_latest_decision_snapshots d
  join fwios.candidate_decision_scores s on s.score_snapshot_id=d.score_snapshot_id
  where d.ticker='EOG'
),
tests(test_id,actual,expected) as (
  values
  ('DRB-01',
    (select lifecycle_status from fwios.policy_versions
     where policy_version_id='POL-DECISION-RANKING-REFRESH-BRIDGE-V1'),
    'ACTIVE'),
  ('DRB-02',(select valuation_run_id from latest_acn),'VAL-PROD-ACN-ITSERV-V2-20261026'),
  ('DRB-03',(select hardening_snapshot_id from latest_acn),'HARD-QHR-ACN-20261026-7cf9191efa86'),
  ('DRB-04',(select decision_state from latest_acn),'REVIEW - QUALITY HARDENING'),
  ('DRB-05',(select input_integrity_gate from latest_acn),'BLOCKED - STALE PORTFOLIO FIT'),
  ('DRB-06',(select valuation_run_id from latest_eog),'VAL-PROD-EOG-EP-V2-20261026'),
  ('DRB-07',(select hardening_snapshot_id from latest_eog),'HARD-QCE-EOG-20261026-8094977faaad'),
  ('DRB-08',(select decision_state from latest_eog),'FAIL - QUALITY HARDENING'),
  ('DRB-09',(select input_integrity_gate from latest_eog),'BLOCKED - STALE PORTFOLIO FIT'),
  ('DRB-10',
    (select fwios.preview_decision_refresh_bridge_v1('NFLX')->>'reason'),
    'PORTFOLIO_FIT_SNAPSHOT_MISSING'),
  ('DRB-11',
    (select overall_gate from fwios.v_candidate_quality_hardening_current where ticker='NFLX'),
    'REVIEW'),
  ('DRB-12',
    coalesce((select decision_snapshot_id from fwios.v_latest_decision_snapshots where ticker='NFLX'),'MISSING'),
    'MISSING'),
  ('DRB-13',
    (select lifecycle_status from fwios.policy_versions where policy_version_id='POL-OPPORTUNITY-RANKING-V2'),
    'RETIRED'),
  ('DRB-14',
    (select status from fwios.opportunity_ranking_runs where ranking_run_id='OPPRANK-DRB-800010edd38342f5'),
    'PASS'),
  ('DRB-15',
    (select count(*)::text from fwios.opportunity_ranked_candidates
     where ranking_run_id='OPPRANK-DRB-800010edd38342f5' and opportunity_bucket='EXCLUDED'),
    '3'),
  ('DRB-16',(select count(*)::text from fwios.v_opportunity_ranking_current),'0'),
  ('DRB-17',
    (select count(*)::text
     from fwios.v_lineage_edges_resolved
     where from_artifact_key='HARDENING:HARD-QHR-ACN-20261026-7cf9191efa86'
       and to_artifact_key='DECISION:DEC-DRB-ACN-b8eea53f1b52a486'
       and edge_type='HARDENING_SUPPORTS_DECISION'),
    '1'),
  ('DRB-18',
    (select count(*)::text
     from fwios.v_lineage_edges_resolved
     where from_artifact_key='HARDENING:HARD-QCE-EOG-20261026-8094977faaad'
       and to_artifact_key='DECISION:DEC-DRB-EOG-374bad5c8efc68a1'
       and edge_type='HARDENING_SUPPORTS_DECISION'),
    '1'),
  ('DRB-19',(select count(*)::text from fwios.portfolio_transactions),'58'),
  ('DRB-20',(select count(*)::text from fwios.portfolio_source_positions),'32'),
  ('DRB-21',(select count(*)::text from fwios.portfolio_live_holdings_rows_v1),'15'),
  ('DRB-22',(select count(*)::text from fwios.human_approval_events),'0'),
  ('DRB-23',(select count(*)::text from fwios.human_approval_packets),'1'),
  ('DRB-24',
    (select (config->>'auto_trade')::text
     from fwios.policy_versions
     where policy_version_id='POL-DECISION-RANKING-REFRESH-BRIDGE-V1'),
    'false')
)
select
  test_id,
  actual,
  expected,
  case when actual=expected then 'PASS' else 'FAIL' end as status
from tests
order by test_id;
