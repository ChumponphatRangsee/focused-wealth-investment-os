-- Thesis SEC filing review gate v1
create or replace view fwios.v_thesis_tracking_current
with (security_invoker = true)
as
with latest_health as (
  select distinct on (ticker) *
  from fwios.thesis_health_snapshots
  order by ticker,as_of_date desc,created_at desc
),
latest_event as (
  select distinct on (ticker)
    ticker,event_date,event_type,direction,impact_score,summary,evidence_source,source_reference
  from fwios.thesis_events
  where direction in ('SUPPORTS','CONTRADICTS','NEUTRAL')
    and event_type not in ('HEALTH_CHANGE','BASELINE_COMPLETED','BASELINE_REQUIRED','BASELINE_MIGRATION')
  order by ticker,event_date desc,created_at desc
),
base as (
  select
    tr.tracking_priority,tr.ownership_status,tr.ticker,tr.company_name,tr.sector,tr.archetype,
    tr.baseline_status,tr.baseline_completeness,tr.thesis_statement,
    lh.health_status,lh.health_score,lh.thesis_score,lh.risk_gate,lh.revision_score,lh.revision_gate,
    lh.chase_risk,lh.chase_gate,lh.hardening_gate,lh.valuation_confidence,lh.entry_status,
    vm.current_price,vm.price_session_date,vm.fair_value,vm.fair_value_upside,vm.price_zone,vm.system_signal,
    lh.promotion_gate,lh.final_decision,lh.blocker_count,
    le.event_date last_event_date,le.event_type last_event_type,le.direction last_event_direction,le.summary last_event_summary,
    lh.as_of_date health_as_of,lh.recent_event_score,lh.support_events_120d,lh.contradict_events_120d,lh.strongest_negative_120d,
    le.evidence_source last_evidence_source,le.source_reference last_evidence_reference,
    sf.latest_sec_filing_date,sf.latest_sec_form,sf.latest_sec_accession_number,sf.sec_checked_at,
    case
      when sf.latest_sec_filing_date is null then 'NO SEC REFRESH'
      when le.event_date is null then 'REVIEW NEW SEC FILING'
      when sf.latest_sec_filing_date > le.event_date then 'REVIEW NEW SEC FILING'
      else 'SEC REVIEW CURRENT'
    end filing_review_gate
  from fwios.thesis_registry tr
  left join latest_health lh on lh.ticker=tr.ticker
  left join latest_event le on le.ticker=tr.ticker
  left join fwios.v_dashboard_valuation_map vm on vm.ticker=tr.ticker
  left join fwios.v_thesis_sec_filing_current sf on sf.ticker=tr.ticker
  where tr.active=true
)
select
  b.tracking_priority,b.ownership_status,b.ticker,b.company_name,b.sector,b.archetype,
  b.baseline_status,b.baseline_completeness,b.thesis_statement,b.health_status,b.health_score,b.thesis_score,
  b.risk_gate,b.revision_score,b.revision_gate,b.chase_risk,b.chase_gate,b.hardening_gate,b.valuation_confidence,
  b.entry_status,b.current_price,b.price_session_date,b.fair_value,b.fair_value_upside,b.price_zone,b.system_signal,
  b.promotion_gate,b.final_decision,b.blocker_count,b.last_event_date,b.last_event_type,b.last_event_direction,b.last_event_summary,
  case
    when b.health_status='BROKEN' then 'REVIEW INVALIDATION / EXIT THESIS'
    when b.health_status='WEAKENING' then 'REVIEW FUNDAMENTALS'
    when b.baseline_status='BASELINE_REQUIRED' then 'BUILD BASELINE'
    when b.baseline_completeness<1 then 'COMPLETE THESIS BASELINE'
    when b.filing_review_gate='REVIEW NEW SEC FILING' then 'REVIEW NEW SEC FILING'
    when coalesce(b.revision_gate,'') like 'BLOCKED%' then 'COMPLETE REVISION EVIDENCE'
    when coalesce(b.chase_gate,'') like 'BLOCKED%' then 'COMPLETE CHASE EVIDENCE'
    when b.hardening_gate in ('FAIL','REVIEW') then 'REVIEW QUALITY HARDENING'
    when b.system_signal='PRICE VERIFY' then 'VERIFY PRICE'
    when b.system_signal='BUY REVIEW' then 'HUMAN BUY REVIEW'
    else 'MONITOR'
  end next_action,
  b.health_as_of,b.recent_event_score,b.support_events_120d,b.contradict_events_120d,b.strongest_negative_120d,
  b.last_evidence_source,b.last_evidence_reference,
  b.latest_sec_filing_date,b.latest_sec_form,b.latest_sec_accession_number,b.sec_checked_at,b.filing_review_gate
from base b
order by b.tracking_priority,
  case coalesce(b.health_status,'BASELINE_REQUIRED')
    when 'BROKEN' then 0 when 'WEAKENING' then 1 when 'WATCH' then 2 when 'BASELINE_REQUIRED' then 3
    when 'STABLE' then 4 when 'STRONG' then 5 else 6 end,
  b.ticker;

revoke all on fwios.v_thesis_tracking_current from public,anon,authenticated;
grant select on fwios.v_thesis_tracking_current to service_role;
