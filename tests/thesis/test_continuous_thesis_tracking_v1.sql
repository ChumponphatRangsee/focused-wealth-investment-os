-- Continuous Thesis Tracking v1 regression checks
with tests as (
  select 'T01_REGISTRY_POPULATED' test_id,
    (select count(*) >= 31 from fwios.thesis_registry where active=true) passed

  union all select 'T02_PORTFOLIO_PRIORITY_ZERO',
    not exists(
      select 1
      from fwios.v_dashboard_holdings h
      left join fwios.thesis_registry tr on tr.ticker=h.asset_symbol
      where h.account_view_key='ALL'
        and h.asset_class='Stock'
        and (tr.ticker is null or tr.tracking_priority<>0 or tr.ownership_status<>'PORTFOLIO')
    )

  union all select 'T03_CANDIDATE_PRIORITY_ONE_UNLESS_HELD',
    not exists(
      select 1
      from fwios.research_candidates rc
      join fwios.thesis_registry tr on tr.ticker=rc.ticker
      where not exists(
        select 1 from fwios.v_dashboard_holdings h
        where h.account_view_key='ALL' and h.asset_class='Stock' and h.asset_symbol=rc.ticker
      )
      and tr.tracking_priority<>1
    )

  union all select 'T04_HEALTH_PRICE_SEPARATION',
    not exists(
      select 1 from fwios.thesis_health_snapshots
      where payload->>'health_price_separation' <> 'true'
    )

  union all select 'T05_BROKEN_REQUIRES_INVALIDATION',
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

  union all select 'T06_ACN_WEAKENING_ON_REVISION',
    exists(
      select 1 from fwios.v_thesis_tracking_current
      where ticker='ACN'
        and health_status='WEAKENING'
        and revision_gate like 'FAIL%'
    )

  union all select 'T07_EOG_WEAKENING_ON_HARDENING',
    exists(
      select 1 from fwios.v_thesis_tracking_current
      where ticker='EOG'
        and health_status='WEAKENING'
        and hardening_gate='FAIL'
    )

  union all select 'T08_HOLDING_BASELINE_FAIL_CLOSED',
    not exists(
      select 1
      from fwios.v_dashboard_holdings h
      join fwios.thesis_registry tr on tr.ticker=h.asset_symbol
      where h.account_view_key='ALL'
        and h.asset_class='Stock'
        and tr.baseline_status='BASELINE_REQUIRED'
        and tr.thesis_statement is not null
    )

  union all select 'T09_VIEW_SECURITY_INVOKER',
    exists(
      select 1
      from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='fwios'
        and c.relname='v_thesis_tracking_current'
        and coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']
    )

  union all select 'T10_RLS_ENABLED',
    not exists(
      select 1
      from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='fwios'
        and c.relname in ('thesis_registry','thesis_events','thesis_health_snapshots')
        and c.relrowsecurity=false
    )

  union all select 'T11_DASHBOARD_PAYLOAD_V1_2',
    ((fwios.dashboard_refresh_payload_v1()->>'schema_version')='DASHBOARD_REFRESH_PAYLOAD_V1_2'
      and jsonb_typeof(fwios.dashboard_refresh_payload_v1()->'data'->'thesis_tracking')='array')

  union all select 'T12_CRON_ACTIVE',
    exists(
      select 1 from cron.job
      where jobname='fwios-thesis-health-refresh'
        and active=true
        and schedule='40 6 * * 1-5'
    )

  union all select 'T13_NO_AUTO_TRADE',
    coalesce(
      (select (state_value->>'auto_trade')::boolean
       from fwios.system_state
       where state_key='architecture_consolidation_v1'),
      false
    )=false
)
select test_id,case when passed then 'PASS' else 'FAIL' end status
from tests
order by test_id;
