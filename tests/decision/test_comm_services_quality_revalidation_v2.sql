-- Communication Services quality filter acceptance suite v2.
-- Expected result: 8/8 PASS.

with checks(test_id,status) as (
  values
  ('QF-01-PINS-DURABILITY', case when (select business_durability_gate from fwios.v_candidate_quality_hardening_current where ticker='PINS')='PASS' then 'PASS' else 'FAIL' end),
  ('QF-02-PINS-OWNER-NUANCE', case when (select owner_earnings_gate from fwios.v_candidate_quality_hardening_current where ticker='PINS')='REVIEW' then 'PASS' else 'FAIL' end),
  ('QF-03-RDDT-DURABILITY', case when (select business_durability_gate from fwios.v_candidate_quality_hardening_current where ticker='RDDT')='PASS' then 'PASS' else 'FAIL' end),
  ('QF-04-RDDT-OWNER', case when (select owner_earnings_gate from fwios.v_candidate_quality_hardening_current where ticker='RDDT')='PASS' then 'PASS' else 'FAIL' end),
  ('QF-05-RDDT-VALUE-WAIT', case when exists(select 1 from fwios.opportunity_ranked_candidates where ranking_run_id='OPPRANK-QH-REVAL-20260906-02' and ticker='RDDT' and opportunity_bucket='WATCHLIST_VALUE_WAIT') then 'PASS' else 'FAIL' end),
  ('QF-06-PINS-MODEL-REVIEW', case when exists(select 1 from fwios.opportunity_ranked_candidates where ranking_run_id='OPPRANK-QH-REVAL-20260906-02' and ticker='PINS' and opportunity_bucket='WATCHLIST_MODEL_REVIEW') then 'PASS' else 'FAIL' end),
  ('QF-07-NFLX-QUALITY-MODEL-SEPARATION', case when exists(select 1 from fwios.research_candidates where ticker='NFLX' and quality_score>=90 and valuation_gate='BLOCKED - MODEL NOT IMPLEMENTED') then 'PASS' else 'FAIL' end),
  ('QF-08-NO-FORCE-FILL', case when not exists(select 1 from fwios.opportunity_ranked_candidates where ranking_run_id='OPPRANK-QH-REVAL-20260906-02' and opportunity_bucket='IMMEDIATE_BUY_CANDIDATE') then 'PASS' else 'FAIL' end)
)
select count(*) total,count(*) filter(where status='PASS') pass_count,count(*) filter(where status='FAIL') fail_count,jsonb_agg(jsonb_build_object('test_id',test_id,'status',status) order by test_id) details from checks;
