-- M3.5 Human Approval / Cutover v1 regression suite.
-- Reference live cutover fixture is deliberately non-actionable.

-- Materialize validation fixture only when absent.
do $$
begin
  if not exists(select 1 from fwios.rebalancing_recommendation_runs where recommendation_run_id='REBAL-M3-CUTOVER-20260905-01') then
    perform fwios.materialize_rebalancing_recommendation_snapshot_v1('REBAL-M3-CUTOVER-20260905-01',0,'CUTOVER_VALIDATION','M3.5 cutover validation only; non-actionable');
  end if;
  if not exists(select 1 from fwios.human_approval_packets where approval_packet_id='APPROVAL-M3-CUTOVER-20260905-01') then
    perform fwios.materialize_human_approval_packet_v1('APPROVAL-M3-CUTOVER-20260905-01','REBAL-M3-CUTOVER-20260905-01','CUTOVER_VALIDATION','M3.5 cutover validation only; non-actionable');
  end if;
end$$;

with tests(test_no,test_case,passed,actual_payload) as (
 values
 ('01','PENDING + APPROVED + PASS => APPROVED',fwios.human_approval_transition_v1('PENDING','APPROVED','PRODUCTION_USER_REQUESTED','PASS')='APPROVED',jsonb_build_object('actual',fwios.human_approval_transition_v1('PENDING','APPROVED','PRODUCTION_USER_REQUESTED','PASS'))),
 ('02','APPROVED requires revalidation PASS',fwios.human_approval_transition_v1('PENDING','APPROVED','PRODUCTION_USER_REQUESTED','BLOCKED - INPUT STALE')='BLOCKED - REVALIDATION FAILED',jsonb_build_object('actual',fwios.human_approval_transition_v1('PENDING','APPROVED','PRODUCTION_USER_REQUESTED','BLOCKED - INPUT STALE'))),
 ('03','PENDING + REJECTED => REJECTED',fwios.human_approval_transition_v1('PENDING','REJECTED','PRODUCTION_USER_REQUESTED','PASS')='REJECTED',jsonb_build_object('actual',fwios.human_approval_transition_v1('PENDING','REJECTED','PRODUCTION_USER_REQUESTED','PASS'))),
 ('04','PENDING + EXPIRED => EXPIRED',fwios.human_approval_transition_v1('PENDING','EXPIRED','PRODUCTION_USER_REQUESTED','PASS')='EXPIRED',jsonb_build_object('actual',fwios.human_approval_transition_v1('PENDING','EXPIRED','PRODUCTION_USER_REQUESTED','PASS'))),
 ('05','PENDING + STALE => STALE',fwios.human_approval_transition_v1('PENDING','STALE','PRODUCTION_USER_REQUESTED','PASS')='STALE',jsonb_build_object('actual',fwios.human_approval_transition_v1('PENDING','STALE','PRODUCTION_USER_REQUESTED','PASS'))),
 ('06','Terminal state cannot transition',fwios.human_approval_transition_v1('APPROVED','REJECTED','PRODUCTION_USER_REQUESTED','PASS')='BLOCKED - TERMINAL STATE',jsonb_build_object('actual',fwios.human_approval_transition_v1('APPROVED','REJECTED','PRODUCTION_USER_REQUESTED','PASS'))),
 ('07','CUTOVER_VALIDATION cannot be approved',fwios.human_approval_transition_v1('PENDING','APPROVED','CUTOVER_VALIDATION','PASS')='BLOCKED - NONACTIONABLE SCOPE',jsonb_build_object('actual',fwios.human_approval_transition_v1('PENDING','APPROVED','CUTOVER_VALIDATION','PASS'))),
 ('08','Invalid current state blocks',fwios.human_approval_transition_v1('VALIDATION_ONLY','REJECTED','PRODUCTION_USER_REQUESTED','PASS')='BLOCKED - INVALID CURRENT STATE',jsonb_build_object('actual',fwios.human_approval_transition_v1('VALIDATION_ONLY','REJECTED','PRODUCTION_USER_REQUESTED','PASS'))),
 ('09','Recommendation fingerprint exists',fwios.recommendation_snapshot_fingerprint_v1('REBAL-M3-CUTOVER-20260905-01') is not null,jsonb_build_object('fingerprint',fwios.recommendation_snapshot_fingerprint_v1('REBAL-M3-CUTOVER-20260905-01'))),
 ('10','Recommendation fingerprint deterministic',fwios.recommendation_snapshot_fingerprint_v1('REBAL-M3-CUTOVER-20260905-01')=fwios.recommendation_snapshot_fingerprint_v1('REBAL-M3-CUTOVER-20260905-01'),jsonb_build_object('fingerprint',fwios.recommendation_snapshot_fingerprint_v1('REBAL-M3-CUTOVER-20260905-01'))),
 ('11','Recommendation traceability PASS',fwios.recommendation_traceability_gate_v1('REBAL-M3-CUTOVER-20260905-01')='PASS',jsonb_build_object('gate',fwios.recommendation_traceability_gate_v1('REBAL-M3-CUTOVER-20260905-01'))),
 ('12','Approval packet integrity PASS',fwios.human_approval_packet_integrity_gate_v1('APPROVAL-M3-CUTOVER-20260905-01')='PASS',jsonb_build_object('gate',fwios.human_approval_packet_integrity_gate_v1('APPROVAL-M3-CUTOVER-20260905-01'))),
 ('13','Validation packet approval revalidation blocked',fwios.human_approval_revalidation_gate_v1('APPROVAL-M3-CUTOVER-20260905-01')='BLOCKED - NONACTIONABLE SCOPE',jsonb_build_object('gate',fwios.human_approval_revalidation_gate_v1('APPROVAL-M3-CUTOVER-20260905-01'))),
 ('14','All nine cutover traceability layers PASS',(select count(*)=9 and count(*) filter(where gate='PASS')=9 from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01')),jsonb_build_object('total',(select count(*) from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01')),'pass',(select count(*) from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where gate='PASS'))),
 ('15','Source transactions reconciliation PASS',(select gate='PASS' from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where layer_name='SOURCE_TRANSACTIONS'),jsonb_build_object('gate',(select gate from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where layer_name='SOURCE_TRANSACTIONS'))),
 ('16','Source positions reconciliation PASS',(select gate='PASS' from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where layer_name='SOURCE_POSITIONS'),jsonb_build_object('gate',(select gate from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where layer_name='SOURCE_POSITIONS'))),
 ('17','Candidate Decision Snapshot lineage PASS',(select gate='PASS' from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where layer_name='CANDIDATE_DECISION'),jsonb_build_object('gate',(select gate from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where layer_name='CANDIDATE_DECISION'))),
 ('18','Opportunity Ranking lineage PASS',(select gate='PASS' from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where layer_name='OPPORTUNITY_RANKING'),jsonb_build_object('gate',(select gate from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where layer_name='OPPORTUNITY_RANKING'))),
 ('19','Source holding valuation lineage PASS',(select gate='PASS' from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where layer_name='SOURCE_HOLDING_VALUATION'),jsonb_build_object('gate',(select gate from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where layer_name='SOURCE_HOLDING_VALUATION'))),
 ('20','Execution isolation PASS',(select gate='PASS' from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where layer_name='EXECUTION_ISOLATION'),jsonb_build_object('gate',(select gate from fwios.m3_5_traceability_layers_v1('REBAL-M3-CUTOVER-20260905-01','APPROVAL-M3-CUTOVER-20260905-01') where layer_name='EXECUTION_ISOLATION'))),
 ('21','Validation packet is VALIDATION_ONLY',(select packet_status='VALIDATION_ONLY' from fwios.human_approval_packets where approval_packet_id='APPROVAL-M3-CUTOVER-20260905-01'),jsonb_build_object('status',(select packet_status from fwios.human_approval_packets where approval_packet_id='APPROVAL-M3-CUTOVER-20260905-01'))),
 ('22','Validation recommendation scope is nonactionable',(select run_scope='CUTOVER_VALIDATION' from fwios.rebalancing_recommendation_runs where recommendation_run_id='REBAL-M3-CUTOVER-20260905-01'),jsonb_build_object('scope',(select run_scope from fwios.rebalancing_recommendation_runs where recommendation_run_id='REBAL-M3-CUTOVER-20260905-01'))),
 ('23','Validation trim matches M3.4 parity',(select abs(sum(amount_thb)-17045.30)<0.02 from fwios.rebalancing_recommendation_actions where recommendation_run_id='REBAL-M3-CUTOVER-20260905-01' and action_type='TRIM'),jsonb_build_object('trim_thb',(select sum(amount_thb) from fwios.rebalancing_recommendation_actions where recommendation_run_id='REBAL-M3-CUTOVER-20260905-01' and action_type='TRIM'))),
 ('24','Validation ADD equals TRIM when new cash is zero',(select abs(coalesce(sum(amount_thb) filter(where action_type='ADD'),0)-coalesce(sum(amount_thb) filter(where action_type='TRIM'),0))<0.01 from fwios.rebalancing_recommendation_actions where recommendation_run_id='REBAL-M3-CUTOVER-20260905-01'),jsonb_build_object('add_thb',(select sum(amount_thb) from fwios.rebalancing_recommendation_actions where recommendation_run_id='REBAL-M3-CUTOVER-20260905-01' and action_type='ADD'),'trim_thb',(select sum(amount_thb) from fwios.rebalancing_recommendation_actions where recommendation_run_id='REBAL-M3-CUTOVER-20260905-01' and action_type='TRIM'))),
 ('25','No production-user recommendation materialized',(select count(*)=0 from fwios.rebalancing_recommendation_runs where run_scope='PRODUCTION_USER_REQUESTED'),jsonb_build_object('count',(select count(*) from fwios.rebalancing_recommendation_runs where run_scope='PRODUCTION_USER_REQUESTED'))),
 ('26','No human approval event created during cutover',(select count(*)=0 from fwios.human_approval_events),jsonb_build_object('count',(select count(*) from fwios.human_approval_events))),
 ('27','Portfolio value remains reconciled',(select abs(g.total_value_thb-b.source_total_value_thb)<0.01 from fwios.v_portfolio_guardrails_current g join fwios.portfolio_import_batches b on b.batch_id='PORTFOLIO-M2-20260905-01' limit 1),jsonb_build_object('current_total',(select total_value_thb from fwios.v_portfolio_guardrails_current limit 1),'source_total',(select source_total_value_thb from fwios.portfolio_import_batches where batch_id='PORTFOLIO-M2-20260905-01'))),
 ('28','No allocation/scenario/event execution side effect',(select (select count(*) from fwios.capital_allocation_runs)=0 and (select count(*) from fwios.portfolio_scenario_runs)=0 and (select count(*) from fwios.system_events)=0),jsonb_build_object('allocation_runs',(select count(*) from fwios.capital_allocation_runs),'scenario_runs',(select count(*) from fwios.portfolio_scenario_runs),'system_events',(select count(*) from fwios.system_events)))
)
insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,input_payload,expected_payload,actual_payload,status,notes)
select 'REG-M3-APPROVAL-V1-'||test_no,'HUMAN_APPROVAL','POL-HUMAN-APPROVAL-V1',test_case,'{}'::jsonb,jsonb_build_object('pass',true),actual_payload,case when passed then 'PASS' else 'FAIL' end,'M3.5 Human Approval / Cutover v1 deterministic regression'
from tests
on conflict (regression_id) do nothing;

-- 29: real event recorder rejects a validation-only packet.
do $$
declare ok boolean:=false; msg text;
begin
 begin
  perform fwios.record_human_approval_event_v1('EVENT-M3-CUTOVER-SHOULD-NOT-EXIST','APPROVAL-M3-CUTOVER-20260905-01','APPROVED','HUMAN','cutover-test','must reject validation scope');
 exception when others then ok:=true; msg:=sqlerrm; end;
 insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,input_payload,expected_payload,actual_payload,status,notes)
 values ('REG-M3-APPROVAL-V1-29','HUMAN_APPROVAL','POL-HUMAN-APPROVAL-V1','Event recorder rejects approval on CUTOVER_VALIDATION','{}'::jsonb,'{"pass":true}'::jsonb,jsonb_build_object('rejected',ok,'message',msg),case when ok and not exists(select 1 from fwios.human_approval_events where approval_event_id='EVENT-M3-CUTOVER-SHOULD-NOT-EXIST') then 'PASS' else 'FAIL' end,'Nonactionable validation packet cannot be approved')
 on conflict (regression_id) do nothing;
end$$;

-- 30: recommendation snapshot is immutable.
do $$
declare ok boolean:=false; msg text;
begin
 begin
  update fwios.rebalancing_recommendation_runs set source_reference='tamper-attempt' where recommendation_run_id='REBAL-M3-CUTOVER-20260905-01';
 exception when others then ok:=true; msg:=sqlerrm; end;
 insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,input_payload,expected_payload,actual_payload,status,notes)
 values ('REG-M3-APPROVAL-V1-30','HUMAN_APPROVAL','POL-HUMAN-APPROVAL-V1','Recommendation snapshot rejects UPDATE','{}'::jsonb,'{"pass":true}'::jsonb,jsonb_build_object('rejected',ok,'message',msg),case when ok and (select source_reference<>'tamper-attempt' from fwios.rebalancing_recommendation_runs where recommendation_run_id='REBAL-M3-CUTOVER-20260905-01') then 'PASS' else 'FAIL' end,'Immutable recommendation boundary')
 on conflict (regression_id) do nothing;
end$$;

select count(*) total,count(*) filter(where status='PASS') pass_count,count(*) filter(where status='FAIL') fail_count
from fwios.decision_policy_regression_runs
where regression_id like 'REG-M3-APPROVAL-V1-%';
