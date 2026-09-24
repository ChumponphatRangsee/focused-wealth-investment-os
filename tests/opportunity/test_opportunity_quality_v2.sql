-- Opportunity Quality V2 / Portfolio Scenario Fit V2 regression checks
with tests as (
  select 'OQ01_POLICY_ACTIVE' test_id,
    exists(select 1 from fwios.policy_versions where policy_version_id='POL-OPPORTUNITY-QUALITY-V2' and lifecycle_status='ACTIVE') passed
  union all select 'OQ02_PORTFOLIO_WEIGHT_ZERO',
    ((select config->>'portfolio_fit_weight' from fwios.policy_versions where policy_version_id='POL-OPPORTUNITY-QUALITY-V2')::numeric=0)
  union all select 'OQ03_ALL_CANDIDATES_VISIBLE',
    ((select count(*) from fwios.v_opportunity_quality_current)=(select count(*) from fwios.research_candidates))
  union all select 'OQ04_ADBE_SURFACED_TOP',
    exists(select 1 from fwios.v_opportunity_quality_current where ticker='ADBE' and opportunity_rank=1)
  union all select 'OQ05_PINS_SURFACED_SECOND',
    exists(select 1 from fwios.v_opportunity_quality_current where ticker='PINS' and opportunity_rank=2)
  union all select 'OQ06_PORTFOLIO_NOT_DISCOVERY_GATE',
    not exists(select 1 from fwios.opportunity_quality_snapshots where payload->>'portfolio_fit_discovery_gate'<>'false')
  union all select 'OQ07_FULL_THESIS_BEFORE_SCENARIO',
    not exists(select 1 from fwios.v_opportunity_quality_current
      where full_thesis_gate<>'PASS' and prebuy_research_gate='PASS - READY FOR PORTFOLIO SCENARIO')
  union all select 'OQ08_SCENARIO_REQUIRED_BEFORE_BUY',
    not exists(select 1 from fwios.v_opportunity_quality_current
      where final_buy_review_gate='PASS - HUMAN BUY REVIEW ELIGIBLE' and portfolio_scenario_gate<>'PASS')
  union all select 'OQ09_ADBE_ADD_IS_REVIEW_NOT_EXCLUDED',
    exists(select 1 from fwios.preview_candidate_portfolio_fit_v2('ADBE',20000,'{}'::text[],'{}'::numeric[])
      where metric_name='scenario_fit_score' and gate='REVIEW')
  union all select 'OQ10_EOG_REPLACE_CAN_PASS',
    exists(select 1 from fwios.preview_candidate_portfolio_fit_v2(
      'EOG',29110.124558554817,array['TTWO'],array[29110.124558554817]::numeric[])
      where metric_name='scenario_fit_score' and gate='PASS')
  union all select 'OQ11_DASHBOARD_TOP5_AND_FULL27',
    jsonb_array_length(fwios.dashboard_refresh_payload_v1()->'data'->'opportunities')=5
    and jsonb_array_length(fwios.dashboard_refresh_payload_v1()->'data'->'opportunity_quality')=27
  union all select 'OQ12_CRON_ACTIVE',
    exists(select 1 from cron.job where jobname='fwios-opportunity-quality-refresh' and active=true and schedule='45 6 * * 1-5')
  union all select 'OQ13_LEGACY_RANKING_RETIRED',
    exists(select 1 from fwios.policy_registry where policy_key='OPPORTUNITY_RANKING' and lifecycle_status='RETIRED')
  union all select 'OQ14_SCENARIO_POLICY_ACTIVE',
    exists(select 1 from fwios.policy_versions where policy_version_id='POL-PORTFOLIO-SCENARIO-FIT-V2' and lifecycle_status='ACTIVE')
  union all select 'OQ15_NO_AUTO_TRADE',
    coalesce((select (state_value->>'auto_trade')::boolean from fwios.system_state where state_key='architecture_consolidation_v1'),false)=false
)
select test_id,case when passed then 'PASS' else 'FAIL' end status
from tests order by test_id;
