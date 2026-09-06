-- Quality / Durability Hardening v1 deterministic regression checks.
-- Expected result: every row returns PASS.

select 'QH-01 gate factors' as test_case,
  case when fwios.hardening_gate_factor_v1('PASS')=1
         and fwios.hardening_gate_factor_v1('REVIEW')=.7
         and fwios.hardening_gate_factor_v1('BLOCKED')=.4
         and fwios.hardening_gate_factor_v1('FAIL')=0 then 'PASS' else 'FAIL' end as status;

select 'QH-02 overall fail closed' as test_case,
  case when fwios.quality_hardening_overall_gate_v1('PASS','BLOCKED','PASS','PASS')='BLOCKED'
         and fwios.quality_hardening_overall_gate_v1('PASS','PASS','PASS','PASS')='PASS'
         and fwios.quality_hardening_overall_gate_v1('PASS','FAIL','PASS','PASS')='FAIL' then 'PASS' else 'FAIL' end as status;

select 'QH-03 continuous expected-return curve' as test_case,
  case when fwios.continuous_upside_score_v1(-.5)=0
         and fwios.continuous_upside_score_v1(0)=50
         and fwios.continuous_upside_score_v1(.5)=100 then 'PASS' else 'FAIL' end as status;

select 'QH-04 PINS confidence adjusted score' as test_case,
  case when fwios.expected_return_score_v3(1.002070832840236686,1.169740764669625247,.4)=40 then 'PASS' else 'FAIL' end as status;

select 'QH-05 PINS model-review bucket' as test_case,
  case when fwios.opportunity_bucket_v2('BLOCKED - QUALITY HARDENING','PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS','BLOCKED')='WATCHLIST_MODEL_REVIEW' then 'PASS' else 'FAIL' end as status;

select 'QH-06 RDDT stays value-wait' as test_case,
  case when fwios.opportunity_bucket_v2('FAIL - INSUFFICIENT MISPRICING','FAIL - INSUFFICIENT MISPRICING','PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS','BLOCKED')='WATCHLIST_VALUE_WAIT' then 'PASS' else 'FAIL' end as status;

select 'QH-07 production has zero Immediate after rerank' as test_case,
  case when (select count(*) from fwios.v_opportunity_ranking_current where opportunity_bucket='IMMEDIATE_BUY_CANDIDATE')=0 then 'PASS' else 'FAIL' end as status;

select 'QH-08 PINS production bucket' as test_case,
  case when exists(select 1 from fwios.v_opportunity_ranking_current where ticker='PINS' and opportunity_bucket='WATCHLIST_MODEL_REVIEW') then 'PASS' else 'FAIL' end as status;

select 'QH-09 cash allocation does not force fill' as test_case,
  case when exists(select 1 from fwios.preview_new_cash_allocation_v1(50000) where asset_symbol='CASH_THB' and action_type='HOLD' and amount_thb=50000) then 'PASS' else 'FAIL' end as status;

select 'QH-10 core weights unchanged' as test_case,
  case when (select business_thesis_weight+expected_return_weight+portfolio_fit_weight+downside_risk_weight from fwios.data_scoring_policies where policy_id='FWB-DATA-SCORING-V3-DURABILITY')=1 then 'PASS' else 'FAIL' end as status;

select 'QH-11 stored regression suite 20/20' as test_case,
  case when (select count(*) from fwios.decision_policy_regression_runs where regression_id like 'REG-QH-V1-%')=20
         and (select count(*) from fwios.decision_policy_regression_runs where regression_id like 'REG-QH-V1-%' and status='PASS')=20 then 'PASS' else 'FAIL' end as status;
