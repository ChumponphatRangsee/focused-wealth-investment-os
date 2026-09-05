-- Post-M3 Dashboard Read Models v1 regressions
-- Expected result: 17/17 PASS.
with tests as (
select '01_consolidated_value_matches_batch' test_id,
  (abs((select portfolio_value_thb from fwios.v_dashboard_account_summary where account_view_key='ALL')-(select source_total_value_thb from fwios.v_latest_portfolio_batch)) < 0.01) passed
union all select '02_total_pnl_identity',
  (abs((select total_pnl_thb-unrealized_pnl_thb-realized_pnl_thb from fwios.v_dashboard_account_summary where account_view_key='ALL')) < 0.01)
union all select '03_account_values_sum_to_all',
  (abs((select portfolio_value_thb from fwios.v_dashboard_account_summary where account_view_key='ALL')-(select sum(portfolio_value_thb) from fwios.v_dashboard_account_summary where account_view_key<>'ALL')) < 0.01)
union all select '04_account_views_count_4',
  ((select count(*) from fwios.v_dashboard_account_summary)=4)
union all select '05_all_open_assets_10',
  ((select count(*) from fwios.v_dashboard_holdings where account_view_key='ALL')=10)
union all select '06_weights_sum_one_each_view',
  (not exists(select 1 from (select account_view_key,abs(sum(view_weight)-1) d from fwios.v_dashboard_holdings group by account_view_key) x where d>0.000001))
union all select '07_pins_immediate_rank1',
  (exists(select 1 from fwios.v_dashboard_opportunities where ticker='PINS' and opportunity_bucket='IMMEDIATE_BUY_CANDIDATE' and bucket_rank=1 and eligibility_gate='PASS'))
union all select '08_rddt_watchlist_rank1',
  (exists(select 1 from fwios.v_dashboard_opportunities where ticker='RDDT' and opportunity_bucket='WATCHLIST_VALUE_WAIT' and bucket_rank=1 and eligibility_gate='WAIT'))
union all select '09_action_requires_capital_input',
  (exists(select 1 from fwios.v_dashboard_current_action where action_state='READY_FOR_CAPITAL_INPUT' and candidate_ticker='PINS' and auto_trade=false and human_execution_only=true))
union all select '10_concentration_alert_matches_guardrail',
  (exists(select 1 from fwios.v_dashboard_alerts where alert_type='CONCENTRATION' and subject='NVDA' and status='REVIEW'))
union all select '11_crypto_alert_above_target',
  (exists(select 1 from fwios.v_dashboard_alerts where alert_type='CRYPTO_EXPOSURE' and status='ABOVE_TARGET'))
union all select '12_focus_alert_review',
  (exists(select 1 from fwios.v_dashboard_alerts where alert_type='FOCUS' and current_value=10 and status='REVIEW'))
union all select '13_reconciliation_29_29_16_16',
  (exists(select 1 from fwios.v_dashboard_system_health where portfolio_batch_status='PASS' and source_transaction_count=29 and transaction_pass_count=29 and source_position_count=16 and position_pass_count=16))
union all select '14_no_trade_or_mutation_capability',
  (exists(select 1 from fwios.v_dashboard_system_health where auto_trade=false and human_execution_only=true))
union all select '15_views_security_invoker',
  (not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='fwios' and c.relname in ('v_dashboard_holdings','v_dashboard_account_summary','v_dashboard_opportunities','v_dashboard_current_action','v_dashboard_alerts','v_dashboard_system_health') and not ('security_invoker=true'=any(coalesce(c.reloptions,array[]::text[])))))
union all select '16_anon_authenticated_no_select',
  (not exists(select 1 from (values ('v_dashboard_holdings'),('v_dashboard_account_summary'),('v_dashboard_opportunities'),('v_dashboard_current_action'),('v_dashboard_alerts'),('v_dashboard_system_health')) v(name) where has_table_privilege('anon','fwios.'||v.name,'SELECT') or has_table_privilege('authenticated','fwios.'||v.name,'SELECT')))
union all select '17_dashboard_did_not_materialize_runs',
  ((select count(*) from fwios.capital_allocation_runs)=0
   and (select count(*) from fwios.portfolio_scenario_runs)=0
   and (select count(*) from fwios.rebalancing_recommendation_runs where run_scope='PRODUCTION_USER_REQUESTED')=0
   and (select count(*) from fwios.human_approval_events)=0)
)
select test_id,case when passed then 'PASS' else 'FAIL' end status from tests order by test_id;