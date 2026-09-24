-- Daily Close Store + Selective Verification regression checks
with tests as (
  select 'D01_POLICY' test_id,
    exists(
      select 1 from fwios.market_daily_close_policy
      where provider_key='TWELVE_DATA' and active
        and per_minute_budget=8 and daily_budget=700 and worker_batch=8
    ) passed

  union all select 'D02_RLS_ENABLED',
    not exists(
      select 1
      from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='fwios'
        and c.relname in (
          'market_daily_close_policy','market_daily_close_runs',
          'market_daily_close_jobs','market_daily_closes','market_daily_close_api_usage'
        )
        and c.relrowsecurity=false
    )

  union all select 'D03_DAILY_CLOSE_VIEW_SECURITY_INVOKER',
    exists(
      select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='fwios' and c.relname='v_market_daily_close_latest'
        and coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']
    )

  union all select 'D04_ALPHA_PRICE_BUDGET_15',
    exists(
      select 1 from fwios.decision_refresh_api_quota_policy
      where provider_group='ALPHA_VANTAGE_SHARED' and price_budget=15
    )

  union all select 'D05_SELECTIVE_PLAN_CAP',
    (select count(*)<=15
     from fwios.decision_refresh_price_plan_v1(
       fwios.decision_refresh_target_session_v1(now()),null
     ))

  union all select 'D06_PORTFOLIO_PRIORITY',
    not exists(
      select 1
      from fwios.decision_refresh_price_plan_v1(
        fwios.decision_refresh_target_session_v1(now()),null
      ) p
      join fwios.v_dashboard_holdings h
        on h.account_view_key='ALL' and h.asset_class='Stock' and h.asset_symbol=p.ticker
      where p.priority_reason<>'PORTFOLIO_HOLDING_VERIFY'
    )

  union all select 'D07_CRON_ACTIVE',
    (select count(*)=3
     from cron.job
     where active=true and jobname in (
       'fwios-market-daily-close-enqueue',
       'fwios-market-daily-close-worker',
       'fwios-shadow-decision-refresh-enqueue'
     ))

  union all select 'D08_VALUATION_MAP_BINDS_DAILY_CLOSE',
    position(
      'v_market_daily_close_latest' in
      pg_get_viewdef('fwios.v_dashboard_valuation_map'::regclass,true)
    )>0

  union all select 'D09_NO_AUTO_TRADE',
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
