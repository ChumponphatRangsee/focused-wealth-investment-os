-- Financials sector quality-filter acceptance v1.
-- Non-mutating production-state verification for SECTOR-FIN-FULL-20260906-01.
-- Expected result: 8/8 PASS.

with checks(test_id,status) as (
  values
  ('FIN-QF-01-RUN-COMPLETE',case when exists(select 1 from fwios.sector_runs where run_id='SECTOR-FIN-FULL-20260906-01' and status='COMPLETE') then 'PASS' else 'FAIL' end),
  ('FIN-QF-02-FOCUSED-FUNNEL',case when exists(select 1 from fwios.sector_runs where run_id='SECTOR-FIN-FULL-20260906-01' and universe_count=20 and cardinality(shortlist)=5 and deep_researched_count=3) then 'PASS' else 'FAIL' end),
  ('FIN-QF-03-JPM-QUALITY-MODEL-SEPARATION',case when exists(select 1 from fwios.research_candidates where ticker='JPM' and quality_score>=94 and valuation_gate like 'BLOCKED%') then 'PASS' else 'FAIL' end),
  ('FIN-QF-04-VISA-QUALITY-MODEL-SEPARATION',case when exists(select 1 from fwios.research_candidates where ticker='V' and quality_score>=94 and evidence_pass_count=9 and valuation_gate like 'BLOCKED%') then 'PASS' else 'FAIL' end),
  ('FIN-QF-05-CHUBB-QUALITY-MODEL-SEPARATION',case when exists(select 1 from fwios.research_candidates where ticker='CB' and quality_score>=94 and evidence_pass_count=9 and valuation_gate like 'BLOCKED%') then 'PASS' else 'FAIL' end),
  ('FIN-QF-06-EXPECTED-RETURN-FAIL-CLOSED',case when (select count(*) from fwios.research_candidates where ticker in ('JPM','V','CB') and expected_return_valuation_score is not null)=0 then 'PASS' else 'FAIL' end),
  ('FIN-QF-07-FIVE-CANONICAL-MODEL-BLOCKERS',case when (select count(*) from fwios.blockers where block_id like 'BLK-FIN-%' and current_status='BLOCKED')=5 then 'PASS' else 'FAIL' end),
  ('FIN-QF-08-NO-FORCE-FILL',case when exists(select 1 from fwios.sector_runs where run_id='SECTOR-FIN-FULL-20260906-01' and immediate_buy_count=0 and valuation_ready_count=0) then 'PASS' else 'FAIL' end)
)
select count(*) total,
       count(*) filter(where status='PASS') pass_count,
       count(*) filter(where status='FAIL') fail_count,
       jsonb_agg(jsonb_build_object('test_id',test_id,'status',status) order by test_id) details
from checks;
