-- M3.4 deterministic regression contract.
-- Runtime ledger IDs: REG-M3-REBAL-V1-01 .. 12. Expected result: 12/12 PASS.

-- 1. NVDA has fresh production holding valuation coverage.
select case when exists(select 1 from fwios.v_holding_valuation_coverage_current where ticker='NVDA' and run_id='VAL-NVDA-SEMIS-20260905') then 'PASS' else 'FAIL' end;

-- 2. NVDA trim + PINS add changed-assets expected-value metric is covered.
select gate from fwios.preview_portfolio_scenario_metrics_v1('ACTIVE_REBALANCE',0,array['NVDA'],array[10000]::numeric[],array['CONCENTRATION_AND_OPPORTUNITY_COST']) where metric_name='modeled_expected_value_change_thb';

-- 3. No new cash: trim is starter-cap limited, not forced to 30%.
select * from fwios.preview_rebalancing_recommendation_v1(0);
-- expected: source NVDA, candidate PINS, trim ~17045.30, source remains >30%, READY - HUMAN REVIEW.

-- 4. THB 10k new cash first.
select * from fwios.preview_rebalancing_recommendation_v1(10000);
-- expected: new_cash_add 10000, trim ~7545.30.

-- 5. THB 50k fills starter capacity and suppresses trim.
select * from fwios.preview_rebalancing_recommendation_v1(50000);
-- expected: trim 0 / NEW_CASH_FIRST.

-- Additional live regression ledger cases assert:
-- opportunity edge >= 25pp;
-- RDDT Value-Wait cannot receive capital;
-- rationale is CONCENTRATION_AND_OPPORTUNITY_COST, never appreciation-only;
-- trim <= remaining candidate capacity;
-- 30% is review threshold, not forced target;
-- preview materializes zero recommendation runs;
-- full-portfolio expected upside remains fail-closed until all risk assets have coverage.

select count(*) total,count(*) filter(where status='PASS') pass_count,count(*) filter(where status='FAIL') fail_count
from fwios.decision_policy_regression_runs where regression_id like 'REG-M3-REBAL-V1-%';