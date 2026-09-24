-- Holding thesis baseline + evidence-aware health regression checks
with tests as (
  select 'H01_PRIORITY0_BASELINES_COMPLETE' test_id,
    not exists(
      select 1
      from (values ('NVDA'),('MSFT'),('TTWO'),('TLN')) x(ticker)
      left join fwios.thesis_registry tr on tr.ticker=x.ticker
      where tr.ticker is null
         or tr.tracking_priority<>0
         or tr.ownership_status<>'PORTFOLIO'
         or tr.baseline_status<>'COMPLETE'
         or tr.baseline_completeness<>1
    ) passed

  union all select 'H02_BASELINE_COMPONENTS_PRESENT',
    not exists(
      select 1
      from fwios.thesis_registry
      where ticker in ('NVDA','MSFT','TTWO','TLN')
        and (
          thesis_statement is null
          or jsonb_array_length(must_remain_true)<3
          or jsonb_array_length(monitoring_kpis)<3
          or jsonb_array_length(catalysts)<2
          or jsonb_array_length(invalidation_criteria)<3
        )
    )

  union all select 'H03_COMPLETED_METADATA_PRESERVED',
    exists(select 1 from fwios.thesis_registry where ticker='MSFT' and company_name='Microsoft Corporation' and sector='Information Technology')
    and exists(select 1 from fwios.thesis_registry where ticker='TTWO' and company_name='Take-Two Interactive Software, Inc.' and sector='Communication Services')
    and exists(select 1 from fwios.thesis_registry where ticker='TLN' and company_name='Talen Energy Corporation' and sector='Utilities')

  union all select 'H04_EVENT_SCORE_HOLDINGS',
    exists(select 1 from fwios.v_thesis_tracking_current where ticker='NVDA' and recent_event_score=20)
    and exists(select 1 from fwios.v_thesis_tracking_current where ticker='MSFT' and recent_event_score=20)
    and exists(select 1 from fwios.v_thesis_tracking_current where ticker='TLN' and recent_event_score=20)
    and exists(select 1 from fwios.v_thesis_tracking_current where ticker='TTWO' and recent_event_score=10)

  union all select 'H05_HEALTH_CURRENT',
    exists(select 1 from fwios.v_thesis_tracking_current where ticker='NVDA' and health_status='STRONG')
    and exists(select 1 from fwios.v_thesis_tracking_current where ticker='MSFT' and health_status='STRONG')
    and exists(select 1 from fwios.v_thesis_tracking_current where ticker='TLN' and health_status='STRONG')
    and exists(select 1 from fwios.v_thesis_tracking_current where ticker='TTWO' and health_status='STABLE')

  union all select 'H06_PRICE_NOT_IN_HEALTH',
    not exists(
      select 1 from fwios.thesis_health_snapshots
      where payload->>'health_price_separation'<>'true'
    )

  union all select 'H07_BROKEN_EXPLICIT_ONLY',
    not exists(
      select 1
      from fwios.v_thesis_tracking_current t
      where t.health_status='BROKEN'
        and not exists(
          select 1 from fwios.thesis_events e
          where e.ticker=t.ticker
            and e.event_type='THESIS_INVALIDATION'
            and e.direction='CONTRADICTS'
            and e.impact_score<=-80
        )
    )

  union all select 'H08_SEC_REFRESH_INCLUDES_PORTFOLIO',
    position('v_dashboard_holdings' in pg_get_functiondef('fwios.start_decision_refresh_shadow(date,text)'::regprocedure))>0
    and position('SEC_SUBMISSIONS' in pg_get_functiondef('fwios.start_decision_refresh_shadow(date,text)'::regprocedure))>0

  union all select 'H09_SEC_VIEW_SECURITY_INVOKER',
    exists(
      select 1
      from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='fwios' and c.relname='v_thesis_sec_filing_current'
        and coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']
    )

  union all select 'H10_THESIS_VIEW_SECURITY_INVOKER',
    exists(
      select 1
      from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='fwios' and c.relname='v_thesis_tracking_current'
        and coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']
    )

  union all select 'H11_LIVE_SEC_REVIEW_CURRENT',
    not exists(
      select 1
      from fwios.v_thesis_tracking_current
      where ticker in ('NVDA','MSFT','TTWO','TLN')
        and filing_review_gate<>'SEC REVIEW CURRENT'
    )

  union all select 'H12_NO_AUTO_TRADE',
    coalesce(
      (select (state_value->>'auto_trade')::boolean
       from fwios.system_state where state_key='architecture_consolidation_v1'),
      false
    )=false
)
select test_id,case when passed then 'PASS' else 'FAIL' end status
from tests
order by test_id;
