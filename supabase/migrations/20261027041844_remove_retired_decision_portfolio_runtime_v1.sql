-- Remove retired Decision/Ranking/Portfolio Fit runtime entry points.
-- Historical rows/tables/policy versions/lineage and migration history remain for audit.

set local lock_timeout = '5s';
set local statement_timeout = '30s';

drop function if exists fwios.preview_decision_refresh_bridge_v1(text) restrict;
drop function if exists fwios.apply_decision_refresh_bridge_v1(text,boolean) restrict;
drop function if exists fwios.preview_opportunity_ranking_refresh_bridge_v1(text[]) restrict;
drop function if exists fwios.apply_opportunity_ranking_refresh_bridge_v1(text[],boolean) restrict;
drop function if exists fwios.refresh_opportunity_quality_v2(date,text) restrict;
drop function if exists fwios.preview_candidate_portfolio_fit_v2(text,numeric,text[],numeric[]) restrict;
drop function if exists fwios.materialize_candidate_portfolio_fit_v2(text,numeric,text[],numeric[],text) restrict;

update fwios.policy_registry
set backing_object = null,
    purpose = purpose || ' Runtime function removed after portfolio-independent cutover; historical policy retained for audit.',
    updated_at = now()
where policy_key in ('DECISION_RANKING_REFRESH_BRIDGE','OPPORTUNITY_QUALITY_V2')
  and lifecycle_status='RETIRED';

update fwios.policy_versions
set config = coalesce(config,'{}'::jsonb) || jsonb_build_object(
      'runtime_removed',true,
      'runtime_removed_at','2026-10-27',
      'historical_audit_retained',true
    )
where policy_version_id in (
  'POL-DECISION-RANKING-REFRESH-BRIDGE-V1',
  'POL-OPPORTUNITY-QUALITY-V2',
  'POL-PORTFOLIO-FIT-V1'
);
