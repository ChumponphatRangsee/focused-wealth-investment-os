-- M3.3 Portfolio Scenario Simulation v1 deterministic regressions
-- Expected: 28/28 PASS. Preview-only; no scenario or portfolio mutation.

with cases(test_case, passed) as (
  values
  ('01 no-sell positive cash', fwios.portfolio_scenario_current_input_gate_v1('NO_SELL',10000)='PASS'),
  ('02 no-sell rejects trim', fwios.portfolio_scenario_current_input_gate_v1('NO_SELL',10000,array['NVDA'],array[1000::numeric],array['CONCENTRATION_REVIEW'])='BLOCKED - TRIM NOT ALLOWED IN MODE'),
  ('03 soft positive cash', fwios.portfolio_scenario_current_input_gate_v1('SOFT_REBALANCE',10000)='PASS'),
  ('04 soft rejects trim', fwios.portfolio_scenario_current_input_gate_v1('SOFT_REBALANCE',10000,array['NVDA'],array[1000::numeric],array['CONCENTRATION_REVIEW'])='BLOCKED - TRIM NOT ALLOWED IN MODE'),
  ('05 active requires action', fwios.portfolio_scenario_current_input_gate_v1('ACTIVE_REBALANCE',0)='BLOCKED - NO SCENARIO ACTION'),
  ('06 active rejects over-trim', fwios.portfolio_scenario_current_input_gate_v1('ACTIVE_REBALANCE',0,array['NVDA'],array[999999::numeric],array['CONCENTRATION_REVIEW'])='BLOCKED - TRIM EXCEEDS CURRENT POSITION'),
  ('07 appreciation-only trim forbidden', fwios.portfolio_scenario_current_input_gate_v1('ACTIVE_REBALANCE',0,array['NVDA'],array[1000::numeric],array['PRICE_APPRECIATION_ONLY'])='BLOCKED - APPRECIATION-ONLY TRIM FORBIDDEN'),
  ('08 duplicate trim symbol forbidden', fwios.portfolio_scenario_current_input_gate_v1('ACTIVE_REBALANCE',0,array['NVDA','NVDA'],array[1000::numeric,1000::numeric],array['CONCENTRATION_REVIEW','OPPORTUNITY_COST'])='BLOCKED - DUPLICATE TRIM SYMBOL'),
  ('09 no-sell 10k PINS parity', abs(coalesce((select amount_thb from fwios.preview_portfolio_scenario_actions_v1('NO_SELL',10000) where asset_symbol='PINS' and action_type='ADD'),0)-10000)<=0.01),
  ('10 no-sell 50k PINS parity', abs(coalesce((select amount_thb from fwios.preview_portfolio_scenario_actions_v1('NO_SELL',50000) where asset_symbol='PINS' and action_type='ADD'),0)-19545.30)<=0.01),
  ('11 no-sell 50k residual cash', abs(coalesce((select amount_thb from fwios.preview_portfolio_scenario_actions_v1('NO_SELL',50000) where asset_symbol='CASH_THB'),0)-30454.70)<=0.01),
  ('12 no-sell 100k PINS parity', abs(coalesce((select amount_thb from fwios.preview_portfolio_scenario_actions_v1('NO_SELL',100000) where asset_symbol='PINS' and action_type='ADD'),0)-22045.30)<=0.01),
  ('13 RDDT value-wait receives no add', (select count(*) from fwios.preview_portfolio_scenario_actions_v1('NO_SELL',100000) where asset_symbol='RDDT' and action_type='ADD')=0),
  ('14 PINS decision snapshot lineage', (select decision_snapshot_id from fwios.preview_portfolio_scenario_actions_v1('NO_SELL',50000) where asset_symbol='PINS' and action_type='ADD')='DEC-PINS-M2-20260905-V2'),
  ('15 PINS mispricing lineage', (select mispricing_snapshot_id from fwios.preview_portfolio_scenario_positions_v1('NO_SELL',50000) where asset_symbol='PINS')='MIS-PINS-20260904'),
  ('16 after weights sum to one', abs((select sum(after_weight) from fwios.preview_portfolio_scenario_positions_v1('NO_SELL',50000))-1)<=0.000001),
  ('17 no-sell lowers max-stock concentration', (select after_value<before_value from fwios.preview_portfolio_scenario_metrics_v1('NO_SELL',50000) where metric_name='max_single_stock_weight')),
  ('18 no-sell lowers crypto weight', (select after_value<before_value from fwios.preview_portfolio_scenario_metrics_v1('NO_SELL',50000) where metric_name='crypto_weight')),
  ('19 full expected-upside fail-closed', (select gate from fwios.preview_portfolio_scenario_metrics_v1('NO_SELL',50000) where metric_name='full_portfolio_pw_upside')='BLOCKED - INCOMPLETE PORTFOLIO VALUATION COVERAGE'),
  ('20 changed-assets expected value computable for no-sell', (select gate='PASS - CHANGED ASSETS COVERED' and after_value>0 from fwios.preview_portfolio_scenario_metrics_v1('NO_SELL',50000) where metric_name='modeled_expected_value_change_thb')),
  ('21 PINS downside score lineage', abs(coalesce((select after_value from fwios.preview_portfolio_scenario_metrics_v1('NO_SELL',50000) where metric_name='added_asset_downside_risk_score'),-1)-70)<=0.0001),
  ('22 active NVDA trim 10k reallocates to PINS 10k', abs(coalesce((select amount_thb from fwios.preview_portfolio_scenario_actions_v1('ACTIVE_REBALANCE',0,array['NVDA'],array[10000::numeric],array['CONCENTRATION_AND_OPPORTUNITY_COST']) where asset_symbol='PINS' and action_type='ADD'),0)-10000)<=0.01),
  ('23 active zero-new-cash preserves total', abs((select after_value-before_value from fwios.preview_portfolio_scenario_metrics_v1('ACTIVE_REBALANCE',0,array['NVDA'],array[10000::numeric],array['CONCENTRATION_AND_OPPORTUNITY_COST']) where metric_name='portfolio_total_thb'))<=0.000001),
  ('24 active NVDA trim lowers concentration', (select after_value<before_value from fwios.preview_portfolio_scenario_metrics_v1('ACTIVE_REBALANCE',0,array['NVDA'],array[10000::numeric],array['CONCENTRATION_AND_OPPORTUNITY_COST']) where metric_name='max_single_stock_weight')),
  ('25 active expected-value blocks on uncovered trim asset', (select gate from fwios.preview_portfolio_scenario_metrics_v1('ACTIVE_REBALANCE',0,array['NVDA'],array[10000::numeric],array['CONCENTRATION_AND_OPPORTUNITY_COST']) where metric_name='modeled_expected_value_change_thb')='BLOCKED - CHANGED ASSET VALUATION MISSING'),
  ('26 soft one-time cash equals no-sell', (select jsonb_agg(jsonb_build_object('asset',asset_symbol,'type',action_type,'amount',amount_thb) order by sequence_no) from fwios.preview_portfolio_scenario_actions_v1('NO_SELL',50000))=(select jsonb_agg(jsonb_build_object('asset',asset_symbol,'type',action_type,'amount',amount_thb) order by sequence_no) from fwios.preview_portfolio_scenario_actions_v1('SOFT_REBALANCE',50000))),
  ('27 preview materializes no scenario run', (select count(*) from fwios.portfolio_scenario_runs)=0),
  ('28 rebalance policy remains draft', (select lifecycle_status from fwios.policy_registry where policy_key='REBALANCE')='DRAFT')
), summary as (
  select count(*) total, count(*) filter(where passed) pass_count, count(*) filter(where not passed) fail_count from cases
)
select * from cases
union all
select 'SUMMARY '||pass_count||'/'||total||' PASS', fail_count=0 from summary;
