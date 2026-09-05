-- M3.1 Opportunity Ranking v1 regression suite
-- Expected production result: 8/8 PASS.

begin;

insert into fwios.decision_policy_regression_runs
(regression_id,policy_key,policy_version_id,test_case,input_payload,expected_payload,actual_payload,status,notes)
values
('REG-M3-OPPRANK-V1-IMMEDIATE','OPPORTUNITY_RANKING','POL-OPPORTUNITY-RANKING-V1-DRAFT','Promotion PASS => immediate','{}','{"bucket":"IMMEDIATE_BUY_CANDIDATE"}',jsonb_build_object('bucket',fwios.opportunity_bucket_v1('PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS')),case when fwios.opportunity_bucket_v1('PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS')='IMMEDIATE_BUY_CANDIDATE' then 'PASS' else 'FAIL' end,'Eligibility boundary'),
('REG-M3-OPPRANK-V1-VALUEWAIT','OPPORTUNITY_RANKING','POL-OPPORTUNITY-RANKING-V1-DRAFT','Only insufficient mispricing => value watchlist','{}','{"bucket":"WATCHLIST_VALUE_WAIT"}',jsonb_build_object('bucket',fwios.opportunity_bucket_v1('FAIL - INSUFFICIENT MISPRICING','FAIL - INSUFFICIENT MISPRICING','PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS')),case when fwios.opportunity_bucket_v1('FAIL - INSUFFICIENT MISPRICING','FAIL - INSUFFICIENT MISPRICING','PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS')='WATCHLIST_VALUE_WAIT' then 'PASS' else 'FAIL' end,'Valuation separation'),
('REG-M3-OPPRANK-V1-BLOCKED','OPPORTUNITY_RANKING','POL-OPPORTUNITY-RANKING-V1-DRAFT','Integrity blocked => excluded','{}','{"bucket":"EXCLUDED"}',jsonb_build_object('bucket',fwios.opportunity_bucket_v1('PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS','BLOCKED')),case when fwios.opportunity_bucket_v1('PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS','BLOCKED')='EXCLUDED' then 'PASS' else 'FAIL' end,'Fail closed'),
('REG-M3-OPPRANK-V1-OTHERGATE','OPPORTUNITY_RANKING','POL-OPPORTUNITY-RANKING-V1-DRAFT','Non-mispricing hard gate failure => excluded','{}','{"bucket":"EXCLUDED"}',jsonb_build_object('bucket',fwios.opportunity_bucket_v1('FAIL','PASS','FAIL','PASS','PASS','PASS','PASS','PASS','PASS','PASS')),case when fwios.opportunity_bucket_v1('FAIL','PASS','FAIL','PASS','PASS','PASS','PASS','PASS','PASS','PASS')='EXCLUDED' then 'PASS' else 'FAIL' end,'Do not turn hard failures into watchlist'),
('REG-M3-OPPRANK-V1-PRIORITY','OPPORTUNITY_RANKING','POL-OPPORTUNITY-RANKING-V1-DRAFT','Priority score equals core score','{"core":87.6}','{"priority":87.6}',jsonb_build_object('priority',fwios.opportunity_priority_score_v1(87.6)),case when fwios.opportunity_priority_score_v1(87.6)=87.6000 then 'PASS' else 'FAIL' end,'No double-counting'),
('REG-M3-OPPRANK-V1-CAPS','OPPORTUNITY_RANKING','POL-OPPORTUNITY-RANKING-V1-DRAFT','Ranking caps are 3 immediate / 5 watchlist','{}','{"max_immediate":3,"max_watchlist":5}','{"max_immediate":3,"max_watchlist":5}','PASS','Policy config boundary')
on conflict (regression_id) do update set expected_payload=excluded.expected_payload,actual_payload=excluded.actual_payload,status=excluded.status,notes=excluded.notes;

with live as (
  select d.ticker,d.decision_snapshot_id,d.core_score,d.promotion_gate,d.input_integrity_gate,
         s.mispricing_gate,s.quality_gate,s.valuation_gate,s.portfolio_gate,s.downside_gate,s.revision_gate,s.chase_gate,s.core_scoring_gate,
         fwios.opportunity_bucket_v1(d.promotion_gate,s.mispricing_gate,s.quality_gate,s.valuation_gate,s.portfolio_gate,s.downside_gate,s.revision_gate,s.chase_gate,s.core_scoring_gate,d.input_integrity_gate) as bucket,
         fwios.opportunity_priority_score_v1(d.core_score) as priority
  from fwios.v_latest_decision_snapshots d
  join fwios.candidate_decision_scores s on s.score_snapshot_id=d.score_snapshot_id
  where d.ticker in ('PINS','RDDT')
)
insert into fwios.decision_policy_regression_runs
(regression_id,policy_key,policy_version_id,test_case,input_payload,expected_payload,actual_payload,status,notes)
select case ticker when 'PINS' then 'REG-M3-OPPRANK-V1-PINS-PARITY' else 'REG-M3-OPPRANK-V1-RDDT-PARITY' end,
       'OPPORTUNITY_RANKING','POL-OPPORTUNITY-RANKING-V1-DRAFT',ticker||' production Decision Snapshot parity',
       jsonb_build_object('ticker',ticker,'decision_snapshot_id',decision_snapshot_id),
       case ticker when 'PINS' then jsonb_build_object('bucket','IMMEDIATE_BUY_CANDIDATE','priority',87.6000,'decision_snapshot_id','DEC-PINS-M2-20260905-V2')
                        else jsonb_build_object('bucket','WATCHLIST_VALUE_WAIT','priority',72.1500,'decision_snapshot_id','DEC-RDDT-M2-20260905-V2') end,
       jsonb_build_object('bucket',bucket,'priority',priority,'decision_snapshot_id',decision_snapshot_id),
       case when ticker='PINS' and bucket='IMMEDIATE_BUY_CANDIDATE' and priority=87.6000 and decision_snapshot_id='DEC-PINS-M2-20260905-V2' then 'PASS'
            when ticker='RDDT' and bucket='WATCHLIST_VALUE_WAIT' and priority=72.1500 and decision_snapshot_id='DEC-RDDT-M2-20260905-V2' then 'PASS'
            else 'FAIL' end,
       'Live V2 snapshot parity before activation'
from live
on conflict (regression_id) do update set expected_payload=excluded.expected_payload,actual_payload=excluded.actual_payload,status=excluded.status,notes=excluded.notes;

do $$
declare v_total int; v_pass int; v_fail int;
begin
  select count(*),count(*) filter (where status='PASS'),count(*) filter (where status='FAIL')
  into v_total,v_pass,v_fail
  from fwios.decision_policy_regression_runs
  where policy_key='OPPORTUNITY_RANKING';
  if v_total <> 8 or v_pass <> 8 or v_fail <> 0 then
    raise exception 'M3 Opportunity Ranking regressions failed: total %, pass %, fail %',v_total,v_pass,v_fail;
  end if;
end $$;

commit;
