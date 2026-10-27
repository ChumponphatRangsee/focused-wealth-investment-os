-- FWIOS MVP-1 Portfolio-independent Decision / Opportunity cutover
-- Live acceptance baseline: 2026-10-27 Asia/Bangkok.
-- Read-only regression: every assertion must PASS.
-- No portfolio/accounting/approval/execution mutation is performed here.

with checks as (
  select 'DPI-01 scoring v4 active' test_id,
    exists(select 1 from fwios.data_scoring_policies where policy_id='FWB-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT' and active) ok
  union all select 'DPI-02 scoring v4 weights 40/40/0/20',
    exists(select 1 from fwios.data_scoring_policies where policy_id='FWB-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT'
      and business_thesis_weight=0.40 and expected_return_weight=0.40 and portfolio_fit_weight=0 and downside_risk_weight=0.20)
  union all select 'DPI-03 scoring v3 retired',
    exists(select 1 from fwios.policy_versions where policy_version_id='POL-DATA-SCORING-V3-DURABILITY' and lifecycle_status='RETIRED')
  union all select 'DPI-04 portfolio fit registry retired',
    exists(select 1 from fwios.policy_registry where policy_key='PORTFOLIO_FIT' and lifecycle_status='RETIRED')
  union all select 'DPI-05 portfolio fit backing inactive',
    exists(select 1 from fwios.portfolio_fit_policies where policy_id='FWB-PORTFOLIO-FIT-V1' and active=false)
  union all select 'DPI-06 decision ranking bridge v1 retired',
    exists(select 1 from fwios.policy_versions where policy_version_id='POL-DECISION-RANKING-REFRESH-BRIDGE-V1' and lifecycle_status='RETIRED')
  union all select 'DPI-07 decision opportunity bridge v2 active',
    exists(select 1 from fwios.policy_versions where policy_version_id='POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2' and lifecycle_status='ACTIVE')
  union all select 'DPI-08 opportunity quality v2 retired',
    exists(select 1 from fwios.policy_versions where policy_version_id='POL-OPPORTUNITY-QUALITY-V2' and lifecycle_status='RETIRED')
  union all select 'DPI-09 opportunity quality v3 active',
    exists(select 1 from fwios.policy_versions where policy_version_id='POL-OPPORTUNITY-QUALITY-V3-PORTFOLIO-INDEPENDENT' and lifecycle_status='ACTIVE')
  union all select 'DPI-10 opportunity ranking v2 remains retired',
    exists(select 1 from fwios.policy_versions where policy_version_id='POL-OPPORTUNITY-RANKING-V2' and lifecycle_status='RETIRED')
  union all select 'DPI-11 score fit snapshot nullable',
    exists(select 1 from information_schema.columns where table_schema='fwios' and table_name='candidate_decision_scores'
      and column_name='portfolio_fit_snapshot_id' and is_nullable='YES')
  union all select 'DPI-12 score fit score nullable',
    exists(select 1 from information_schema.columns where table_schema='fwios' and table_name='candidate_decision_scores'
      and column_name='portfolio_fit_score' and is_nullable='YES')
  union all select 'DPI-13 decision portfolio batch nullable',
    exists(select 1 from information_schema.columns where table_schema='fwios' and table_name='decision_snapshots'
      and column_name='portfolio_batch_id' and is_nullable='YES')
  union all select 'DPI-14 decision fit snapshot nullable',
    exists(select 1 from information_schema.columns where table_schema='fwios' and table_name='decision_snapshots'
      and column_name='portfolio_fit_snapshot_id' and is_nullable='YES')
  union all select 'DPI-15 new functions security invoker',
    (select bool_and(not p.prosecdef)
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='fwios' and p.proname in ('preview_decision_refresh_bridge_v2','apply_decision_refresh_bridge_v2','refresh_opportunity_quality_v3'))
  union all select 'DPI-16 new functions service-role only',
    (select bool_and(has_function_privilege('service_role',p.oid,'EXECUTE')
       and not has_function_privilege('anon',p.oid,'EXECUTE')
       and not has_function_privilege('authenticated',p.oid,'EXECUTE'))
     from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='fwios' and p.proname in ('preview_decision_refresh_bridge_v2','apply_decision_refresh_bridge_v2','refresh_opportunity_quality_v3'))
  union all select 'DPI-17 decision v2 no fit-table dependency',
    not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='fwios' and p.proname in ('preview_decision_refresh_bridge_v2','apply_decision_refresh_bridge_v2')
        and lower(p.prosrc) like '%candidate_portfolio_fit%')
  union all select 'DPI-18 decision v2 no portfolio-batch dependency',
    not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='fwios' and p.proname in ('preview_decision_refresh_bridge_v2','apply_decision_refresh_bridge_v2')
        and lower(p.prosrc) like '%v_latest_portfolio_batch%')
  union all select 'DPI-19 opportunity view no latest portfolio batch',
    not exists(select 1 from pg_views where schemaname='fwios' and viewname='v_opportunity_quality_current'
      and lower(definition) like '%v_latest_portfolio_batch%')
  union all select 'DPI-20 opportunity view no scenario-review join',
    not exists(select 1 from pg_views where schemaname='fwios' and viewname='v_opportunity_quality_current'
      and lower(definition) like '%portfolio_scenario_review%')
  union all select 'DPI-21 ACN review preserved portfolio-independent',
    exists(select 1 from fwios.v_latest_decision_snapshots d join fwios.candidate_decision_scores s on s.score_snapshot_id=d.score_snapshot_id
      where d.ticker='ACN' and d.decision_state='REVIEW - QUALITY HARDENING'
        and d.portfolio_batch_id is null and d.portfolio_fit_snapshot_id is null
        and s.scoring_policy_id='FWB-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT' and s.portfolio_fit_score is null)
  union all select 'DPI-22 EOG fail preserved portfolio-independent',
    exists(select 1 from fwios.v_latest_decision_snapshots d join fwios.candidate_decision_scores s on s.score_snapshot_id=d.score_snapshot_id
      where d.ticker='EOG' and d.decision_state='FAIL - QUALITY HARDENING'
        and d.portfolio_batch_id is null and d.portfolio_fit_snapshot_id is null
        and s.scoring_policy_id='FWB-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT' and s.portfolio_fit_score is null)
  union all select 'DPI-23 NFLX review created portfolio-independent',
    exists(select 1 from fwios.v_latest_decision_snapshots d join fwios.candidate_decision_scores s on s.score_snapshot_id=d.score_snapshot_id
      where d.ticker='NFLX' and d.decision_state='REVIEW - QUALITY HARDENING'
        and d.portfolio_batch_id is null and d.portfolio_fit_snapshot_id is null
        and s.scoring_policy_id='FWB-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT' and s.portfolio_fit_score is null)
  union all select 'DPI-24 PINS price-conflict decision preserved',
    exists(select 1 from fwios.v_latest_decision_snapshots where ticker='PINS'
      and decision_snapshot_id='DEC-PINS-REFRESH-20260911' and decision_state='PRICE CONFLICT')
  union all select 'DPI-25 PINS preview fail-closed',
    fwios.preview_decision_refresh_bridge_v2('PINS')->>'reason'='CURRENT_MISPRICING_NOT_ALIGNED_TO_HARDENING'
  union all select 'DPI-26 ACN normalized core score',
    exists(select 1 from fwios.v_latest_decision_snapshots where ticker='ACN' and core_score=70.1952)
  union all select 'DPI-27 EOG normalized core score',
    exists(select 1 from fwios.v_latest_decision_snapshots where ticker='EOG' and core_score=68.3469)
  union all select 'DPI-28 NFLX normalized core score',
    exists(select 1 from fwios.v_latest_decision_snapshots where ticker='NFLX' and core_score=78.2216)
  union all select 'DPI-29 opportunity v3 target snapshots current date',
    (select count(*)=4 from fwios.opportunity_quality_snapshots
      where ticker in ('ACN','EOG','NFLX','PINS') and as_of_date='2026-10-27'
        and policy_version_id='POL-OPPORTUNITY-QUALITY-V3-PORTFOLIO-INDEPENDENT')
  union all select 'DPI-30 opportunity scenario not applicable',
    (select count(*)=4 from fwios.v_opportunity_quality_current
      where ticker in ('ACN','EOG','NFLX','PINS')
        and portfolio_scenario_gate='NOT_APPLICABLE - PORTFOLIO INDEPENDENT')
  union all select 'DPI-31 PINS opportunity still price verify',
    exists(select 1 from fwios.v_opportunity_quality_current where ticker='PINS'
      and opportunity_state='PRICE_VERIFY' and final_buy_review_gate='BLOCKED - PRICE VERIFY')
  union all select 'DPI-32 retired ranking zero visible',
    (select count(*)=0 from fwios.v_opportunity_ranking_current)
  union all select 'DPI-33 protected counts unchanged',
    (select count(*)=58 from fwios.portfolio_transactions)
    and (select count(*)=32 from fwios.portfolio_source_positions)
    and (select count(*)=15 from fwios.portfolio_live_holdings_rows_v1)
    and (select count(*)=3 from fwios.portfolio_accounts)
    and (select count(*)=1 from fwios.human_approval_packets)
    and (select count(*)=0 from fwios.human_approval_events)
  union all select 'DPI-34 hardening lineage reaches new decisions',
    (select count(*)=3
     from fwios.lineage_edges e
     join fwios.lineage_artifacts f on f.artifact_id=e.from_artifact_id
     join fwios.lineage_artifacts t on t.artifact_id=e.to_artifact_id
     where e.edge_type='HARDENING_SUPPORTS_DECISION'
       and f.artifact_key in (
         'HARDENING:HARD-QHR-ACN-20261026-7cf9191efa86',
         'HARDENING:HARD-QCE-EOG-20261026-8094977faaad',
         'HARDENING:HARD-QCE-NFLX-20261026-2d4df8695276')
       and t.artifact_key in (
         'DECISION:DEC-DPI-ACN-1b8c0fbb6b0c850e',
         'DECISION:DEC-DPI-EOG-f20c421e6bd81612',
         'DECISION:DEC-DPI-NFLX-65100f7a08581ea9'))
  union all select 'DPI-35 cutover policies auto-trade false',
    not exists(select 1 from fwios.policy_versions
      where policy_version_id in (
        'POL-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT',
        'POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2',
        'POL-OPPORTUNITY-QUALITY-V3-PORTFOLIO-INDEPENDENT')
      and coalesce((config->>'auto_trade')::boolean,false)=true)
)
select test_id,
       case when ok then 'PASS' else 'FAIL' end as status
from checks
order by test_id;
