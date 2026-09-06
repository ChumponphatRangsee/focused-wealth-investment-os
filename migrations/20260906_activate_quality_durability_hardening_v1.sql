-- Activate Quality / Durability Hardening v1 after 20/20 deterministic regressions PASS.
-- Immutable historical score/decision snapshots are preserved; new snapshots supersede them by recency.

begin;

-- Correct the draft bear-case policy for an aggressive Phase-1 mandate:
-- >30% bear downside is a review signal; >50% is a hard fail threshold.
update fwios.policy_versions
set config = jsonb_set(
               jsonb_set(config - 'bear_case_fail_below', '{bear_case_review_below}', to_jsonb(-0.30::numeric), true),
               '{bear_case_fail_below}', to_jsonb(-0.50::numeric), true
             ),
    source_reference='Focused Wealth quality hardening v1; 20/20 regressions PASS; bear review below -30%, fail below -50%'
where policy_version_id='POL-QUALITY-HARDENING-V1';

-- Activate the hardened production policy set and retire superseded versions.
update fwios.policy_versions set lifecycle_status='RETIRED'
where policy_version_id in ('POL-DATA-SCORING-V2-NATIVE','POL-OPPORTUNITY-RANKING-V1');
update fwios.policy_versions set lifecycle_status='ACTIVE',effective_at=now()
where policy_version_id in ('POL-QUALITY-HARDENING-V1','POL-DATA-SCORING-V3-DURABILITY','POL-OPPORTUNITY-RANKING-V2');
update fwios.data_scoring_policies set active=false where policy_id='FWB-DATA-SCORING-V2-NATIVE';
update fwios.data_scoring_policies set active=true,updated_at=now() where policy_id='FWB-DATA-SCORING-V3-DURABILITY';

-- New immutable score snapshots. Core weights remain exactly 30/30/25/15.
insert into fwios.candidate_decision_scores(
 score_snapshot_id,ticker,scoring_policy_id,valuation_run_id,mispricing_snapshot_id,portfolio_fit_snapshot_id,
 business_thesis_score,expected_return_score,portfolio_fit_score,downside_risk_score,core_score,
 quality_gate,valuation_gate,mispricing_gate,portfolio_gate,downside_gate,revision_gate,chase_gate,core_scoring_gate,
 promotion_gate,decision_state,decision_note,source_reference,
 hardening_snapshot_id,valuation_confidence,hardening_gate)
values
('SCORE-PINS-QH-20260906-V1','PINS','FWB-DATA-SCORING-V3-DURABILITY','VAL-SUPA-PINS-DIGADS-20260905','MIS-PINS-20260904','FIT-PINS-PORTFOLIO-M2-20260905-01',
 82,40.0000,90,70,69.6000,
 'PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS',
 'BLOCKED - QUALITY HARDENING','MODEL REVIEW - DURABILITY / OWNER EARNINGS',
 'PINS mispricing remains numerically attractive, but promotion is blocked: no verified multi-year durability anchor, SBC/revenue 22.43% lacks owner-earnings/dilution reconciliation, and extreme modeled upside lacks canonical counter-thesis evidence.',
 'POL-DATA-SCORING-V3-DURABILITY + HARD-PINS-20260906-V1 + MIS-PINS-20260904',
 'HARD-PINS-20260906-V1',0.4000,'BLOCKED'),
('SCORE-RDDT-QH-20260906-V1','RDDT','FWB-DATA-SCORING-V3-DURABILITY','VAL-SUPA-RDDT-DIGADS-20260905','MIS-RDDT-20260904','FIT-RDDT-PORTFOLIO-M2-20260905-01',
 88,24.7607,90,65,66.0782,
 'PASS','PASS','FAIL - INSUFFICIENT MISPRICING','PASS','PASS','PASS','PASS','PASS',
 'FAIL - INSUFFICIENT MISPRICING','GOOD COMPANY - WAIT FOR VALUE',
 'RDDT remains Value-Wait because mispricing is insufficient. Quality hardening is also incomplete and must clear before any future Immediate promotion.',
 'POL-DATA-SCORING-V3-DURABILITY + HARD-RDDT-20260906-V1 + MIS-RDDT-20260904',
 'HARD-RDDT-20260906-V1',0.5500,'BLOCKED')
on conflict (score_snapshot_id) do nothing;

-- New immutable Decision Snapshots; old M2 decisions remain audit history.
insert into fwios.decision_snapshots(
 decision_snapshot_id,ticker,portfolio_batch_id,price_snapshot_id,valuation_run_id,mispricing_snapshot_id,
 portfolio_fit_snapshot_id,revision_snapshot_id,chase_snapshot_id,score_snapshot_id,
 scoring_policy_version_id,revision_policy_version_id,chase_policy_version_id,
 core_score,decision_state,promotion_gate,input_integrity_gate,decision_payload,hardening_snapshot_id)
values
('DEC-PINS-QH-20260906-V1','PINS','PORTFOLIO-M2-20260905-01','PX-PINS-20260904','VAL-SUPA-PINS-DIGADS-20260905','MIS-PINS-20260904',
 'FIT-PINS-PORTFOLIO-M2-20260905-01','REV-PINS-Q2-2026-M2-V1','CHASE-PINS-20260904-M2-V1','SCORE-PINS-QH-20260906-V1',
 'POL-DATA-SCORING-V3-DURABILITY','POL-REVISION-SCORE-V1','POL-CHASE-SCORE-V1',
 69.6000,'MODEL REVIEW - DURABILITY / OWNER EARNINGS','BLOCKED - QUALITY HARDENING','PASS',
 '{"mispricing_gate":"PASS","hardening_gate":"BLOCKED","valuation_confidence":0.4,"expected_return_score_old":100,"expected_return_score_v3":40,"business_durability_gate":"BLOCKED","owner_earnings_gate":"BLOCKED","value_trap_gate":"BLOCKED","valuation_robustness_gate":"BLOCKED","historical_price_role":"review_trigger_only","human_execution_only":true,"pretrade_price_verification_required":true}'::jsonb,
 'HARD-PINS-20260906-V1'),
('DEC-RDDT-QH-20260906-V1','RDDT','PORTFOLIO-M2-20260905-01','PX-RDDT-20260904','VAL-SUPA-RDDT-DIGADS-20260905','MIS-RDDT-20260904',
 'FIT-RDDT-PORTFOLIO-M2-20260905-01','REV-RDDT-Q2-2026-M2-V1','CHASE-RDDT-20260904-M2-V1','SCORE-RDDT-QH-20260906-V1',
 'POL-DATA-SCORING-V3-DURABILITY','POL-REVISION-SCORE-V1','POL-CHASE-SCORE-V1',
 66.0782,'GOOD COMPANY - WAIT FOR VALUE','FAIL - INSUFFICIENT MISPRICING','PASS',
 '{"mispricing_gate":"FAIL - INSUFFICIENT MISPRICING","hardening_gate":"BLOCKED","valuation_confidence":0.55,"expected_return_score_old":45,"expected_return_score_v3":24.7607,"business_durability_gate":"BLOCKED","owner_earnings_gate":"BLOCKED","value_trap_gate":"PASS","valuation_robustness_gate":"BLOCKED","human_execution_only":true}'::jsonb,
 'HARD-RDDT-20260906-V1')
on conflict (decision_snapshot_id) do nothing;

-- Materialize a new production ranking snapshot. There are deliberately zero Immediate candidates.
insert into fwios.opportunity_ranking_runs(ranking_run_id,policy_version_id,portfolio_batch_id,status,source_reference,completed_at)
values ('OPPRANK-QH-20260906-01','POL-OPPORTUNITY-RANKING-V2','PORTFOLIO-M2-20260905-01','PASS',
        'Quality/Durability Hardening v1 production rerank; 20/20 regressions PASS',now())
on conflict (ranking_run_id) do nothing;

insert into fwios.opportunity_ranked_candidates(
 ranking_candidate_id,ranking_run_id,ticker,decision_snapshot_id,score_snapshot_id,opportunity_bucket,bucket_rank,
 priority_score,expected_return_score,portfolio_fit_score,downside_risk_score,business_thesis_score,
 eligibility_gate,rationale_code,source_reference)
values
('RANK-QH-PINS-20260906-01','OPPRANK-QH-20260906-01','PINS','DEC-PINS-QH-20260906-V1','SCORE-PINS-QH-20260906-V1',
 'WATCHLIST_MODEL_REVIEW',1,69.6000,40.0000,90,70,82,'PASS - RESEARCH ONLY','QUALITY_HARDENING_BLOCKED',
 'POL-OPPORTUNITY-RANKING-V2 + DEC-PINS-QH-20260906-V1'),
('RANK-QH-RDDT-20260906-01','OPPRANK-QH-20260906-01','RDDT','DEC-RDDT-QH-20260906-V1','SCORE-RDDT-QH-20260906-V1',
 'WATCHLIST_VALUE_WAIT',1,66.0782,24.7607,90,65,88,'PASS - RESEARCH ONLY','MISPRICING_INSUFFICIENT',
 'POL-OPPORTUNITY-RANKING-V2 + DEC-RDDT-QH-20260906-V1')
on conflict (ranking_candidate_id) do nothing;

commit;
