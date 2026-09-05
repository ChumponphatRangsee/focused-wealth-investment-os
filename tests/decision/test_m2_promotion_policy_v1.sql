-- M2 Promotion Policy v1 acceptance checks
-- Expected live recorded suite: 16/16 PASS.

-- Revision mapping boundaries
select fwios.score_revision_delta_v1(-10)=0 as rev_neg10_pass;
select fwios.score_revision_delta_v1(0)=50 as rev_neutral_pass;
select fwios.score_revision_delta_v1(10)=100 as rev_pos10_pass;
select fwios.revision_gate_v1(null,50,50,50,'PASS','PASS - COMPARABLE CONSENSUS EVIDENCE')='BLOCKED - COMPONENT SCORING INCOMPLETE' as rev_missing_pass;
select fwios.revision_gate_v1(40,40,40,40,'PASS','PASS - COMPARABLE CONSENSUS EVIDENCE')='FAIL - NEGATIVE FUNDAMENTAL REVISION' as rev_negative_gate_pass;

-- Chase mapping boundaries
select fwios.score_chase_excess_v1(-5)=0 as chase_nonpositive_pass;
select fwios.score_chase_excess_v1(40)=100 as chase_40_pass;
select fwios.score_price_vs_fv_risk_v1(-20)=0 as fv_neg20_pass;
select fwios.score_price_vs_fv_risk_v1(0)=40 as fv_zero_pass;
select fwios.score_price_vs_fv_risk_v1(25)=100 as fv_25_pass;
select fwios.chase_gate_v1(0,0,null,0,60)='BLOCKED - INCOMPLETE CHASE DATA' as chase_missing_pass;
select fwios.chase_gate_v1(100,100,100,100,60)='FAIL - CHASE RISK' as chase_limit_pass;

-- Production parity
select abs(fwios.calculate_revision_score_v1(50,83.8540,50,60.4479)-60.5531)<=0.01 as pins_revision_parity;
select abs(fwios.calculate_revision_score_v1(71.6500,93.2990,27.5,98.5310)-71.4010)<=0.01 as rddt_revision_parity;
select fwios.calculate_chase_risk_v1(0,0,0,0)=0 as pins_chase_parity;
select abs(fwios.calculate_chase_risk_v1(0,0,0,61.3738)-12.2748)<=0.01 as rddt_chase_parity;

-- Final recorded live policy regressions must contain no FAIL.
select count(*)=16 as regression_count_pass,
       count(*) filter(where status='PASS')=16 as all_pass,
       count(*) filter(where status='FAIL')=0 as no_fail
from fwios.decision_policy_regression_runs
where regression_id like 'REG-M2-POLICY-V1-%';
