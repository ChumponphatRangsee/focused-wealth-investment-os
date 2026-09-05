-- Activate M3.3 Portfolio Scenario Simulation v1 after deterministic regressions pass.

update fwios.policy_registry
set lifecycle_status='ACTIVE', updated_at=now()
where policy_key='PORTFOLIO_SCENARIO';

insert into fwios.policy_versions(
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference,effective_at
)
values (
 'POL-PORTFOLIO-SCENARIO-V1','PORTFOLIO_SCENARIO','1.0','ACTIVE',true,
 jsonb_build_object(
  'modes',jsonb_build_array('NO_SELL','SOFT_REBALANCE','ACTIVE_REBALANCE'),
  'source_allocation_policy','POL-NEW-CASH-ALLOCATION-V1',
  'source_ranking_policy','POL-OPPORTUNITY-RANKING-V1',
  'no_sell_uses_new_cash_engine',true,
  'soft_rebalance_allows_trim',false,
  'soft_rebalance_one_time_cash_math_equals_no_sell',true,
  'active_rebalance_trim_is_input_not_recommendation',true,
  'trim_requires_explicit_rationale',true,
  'price_appreciation_only_rationale_forbidden',true,
  'live_portfolio_mutation',false,
  'full_expected_portfolio_upside_requires_complete_valuation_coverage',true,
  'partial_covered_upside_metrics_allowed',true,
  'changed_asset_expected_value_requires_changed_asset_valuation',true,
  'current_holding_valuation_coverage_at_activation',0,
  'current_full_portfolio_upside_gate','BLOCKED - INCOMPLETE PORTFOLIO VALUATION COVERAGE',
  'regression_suite','28/28 PASS',
  'human_execution_only',true,
  'auto_trade',false
 ),
 'GitHub policies/scenario/PORTFOLIO_SCENARIO_V1.md',now()
)
on conflict (policy_version_id) do update
set lifecycle_status='ACTIVE',config=excluded.config,source_reference=excluded.source_reference,effective_at=excluded.effective_at;

update fwios.decision_policy_regression_runs
set policy_version_id='POL-PORTFOLIO-SCENARIO-V1'
where regression_id like 'REG-M3-SCENARIO-V1-%' and status='PASS';
