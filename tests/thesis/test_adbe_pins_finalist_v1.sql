-- ADBE / PINS Finalist V1 regressions
with tests as (
  select 'F01_ADBE_BASELINE_COMPLETE' test_id,
    exists(select 1 from fwios.thesis_registry where ticker='ADBE' and baseline_status='COMPLETE' and baseline_completeness=1) passed
  union all select 'F02_PINS_BASELINE_COMPLETE',
    exists(select 1 from fwios.thesis_registry where ticker='PINS' and baseline_status='COMPLETE' and baseline_completeness=1)
  union all select 'F03_ADBE_HEALTH_WATCH',
    exists(select 1 from fwios.v_thesis_tracking_current where ticker='ADBE' and health_status='WATCH' and recent_event_score=20)
  union all select 'F04_PINS_HEALTH_WATCH',
    exists(select 1 from fwios.v_thesis_tracking_current where ticker='PINS' and health_status='WATCH'
      and recent_event_score=15 and contradict_events_120d=1)
  union all select 'F05_SEC_REVIEW_CURRENT',
    not exists(select 1 from fwios.v_thesis_tracking_current
      where ticker in ('ADBE','PINS') and filing_review_gate<>'SEC REVIEW CURRENT')
  union all select 'F06_ADBE_REVISION_PARTIAL_FAIL_CLOSED',
    exists(select 1 from fwios.v_candidate_revision_current where ticker='ADBE'
      and component_coverage=0.25
      and consensus_gate='PASS - COMPARABLE CONSENSUS EVIDENCE'
      and revision_gate='BLOCKED - COMPONENT SCORING INCOMPLETE')
  union all select 'F07_PINS_REVISION_PASS',
    exists(select 1 from fwios.v_candidate_revision_current where ticker='PINS'
      and revision_gate='PASS' and component_coverage=1)
  union all select 'F08_BOTH_FULL_THESIS_PASS',
    not exists(select 1 from fwios.v_opportunity_quality_current
      where ticker in ('ADBE','PINS') and full_thesis_gate<>'PASS')
  union all select 'F09_BOTH_PRICE_VERIFY_BLOCKED',
    not exists(select 1 from fwios.v_opportunity_quality_current
      where ticker in ('ADBE','PINS') and prebuy_research_gate<>'BLOCKED - PRICE VERIFY')
  union all select 'F10_RANKS_STABLE',
    exists(select 1 from fwios.v_opportunity_quality_current where ticker='ADBE' and opportunity_rank=1)
    and exists(select 1 from fwios.v_opportunity_quality_current where ticker='PINS' and opportunity_rank=2)
  union all select 'F11_ADBE_ADD20_REVIEW',
    exists(select 1 from fwios.preview_candidate_portfolio_fit_v2('ADBE',20000,'{}'::text[],'{}'::numeric[])
      where metric_name='scenario_fit_score' and gate='REVIEW')
  union all select 'F12_PINS_FULL_TTWO_REPLACE_PASS',
    exists(select 1 from fwios.preview_candidate_portfolio_fit_v2(
      'PINS',29110.124558554817,array['TTWO']::text[],array[29110.124558554817]::numeric[])
      where metric_name='scenario_fit_score' and gate='PASS' and after_value=100)
  union all select 'F13_ADBE_PRIMARY_CLOSE_CURRENT',
    exists(select 1 from fwios.v_dashboard_valuation_map
      where ticker='ADBE' and price_session_date=date '2026-09-23' and current_price=240.69)
  union all select 'F14_PINS_INTERNAL_PRICE_STILL_BLOCKED',
    exists(select 1 from fwios.v_dashboard_valuation_map where ticker='PINS' and price_gate like 'BLOCKED%')
  union all select 'F15_NO_BUY_REVIEW_YET',
    not exists(select 1 from fwios.v_opportunity_quality_current
      where ticker in ('ADBE','PINS') and final_buy_review_gate='PASS - HUMAN BUY REVIEW ELIGIBLE')
  union all select 'F16_NO_AUTO_TRADE',
    coalesce((select (state_value->>'auto_trade')::boolean
      from fwios.system_state where state_key='architecture_consolidation_v1'),false)=false
)
select test_id,case when passed then 'PASS' else 'FAIL' end status
from tests order by test_id;
