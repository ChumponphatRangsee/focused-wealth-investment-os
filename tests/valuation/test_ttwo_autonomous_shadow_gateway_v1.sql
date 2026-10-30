-- FWIOS TTWO Autonomous Model Evaluation: read-only regression for live SHADOW gateway.
-- Does not call any mutating function. Automated receipt idempotency checked separately.
WITH c AS (
 SELECT * FROM fwios.ai_model_candidates_v1
 WHERE ticker='TTWO' AND model_id='INTERACTIVE_ENTERTAINMENT_IP_DCF_V1'
 ORDER BY created_at DESC LIMIT 1
),e AS (
 SELECT a.* FROM fwios.ai_model_evaluations_v1 a JOIN c
 ON c.candidate_id=a.candidate_id ORDER BY a.created_at DESC LIMIT 1
), checks(check_id,ok) AS (
 SELECT '01_TTWO_SHADOW_CANDIDATE_EXISTS'::text,(SELECT COUNT(*)=1 FROM c)
 UNION ALL SELECT '02_TTWO_SCOPE_LOCK', (SELECT ticker='TTWO' FROM c)
 UNION ALL SELECT '03_ONLY_SHADOW_MODEL', (SELECT lifecycle_state='SHADOW_ONLY' AND model_version LIKE '%SHADOW' FROM c)
 UNION ALL SELECT '04_GITHUB_PR_TRACE', (SELECT github_pr_url LIKE 'https://github.com/ChumponphatRangsee/focused-wealth-investment-os/pull/%' FROM c)
 UNION ALL SELECT '05_EVAL_RECEIPT_EXISTS',(SELECT COUNT(*)=1 FROM e)
 UNION ALL SELECT '06_EVAL_STRUCTURAL_PASS',(SELECT evaluation_state='SHADOW_STRUCTURAL_PASS' FROM e)
 UNION ALL SELECT '07_PRICE_CHECK',(SELECT checks->>'verified_price_current'='true' FROM e)
 UNION ALL SELECT '08_SEC_CHECKS',(SELECT checks->>'sec_filing_present'='true' AND checks->>'sec_financial_fact_matched'='true' FROM e)
 UNION ALL SELECT '09_MODEL_NOT_PRODUCTION',(SELECT checks->>'production_eligible'='false' AND checks->>'economic_correctness_validated'='false' FROM e)
 UNION ALL SELECT '10_THREE_SIMULATIONS',(SELECT jsonb_array_length(scenario_outputs)=3 FROM e)
 UNION ALL SELECT '11_ALL_SHADOW_LABELS',(SELECT NOT EXISTS(SELECT 1 FROM jsonb_array_elements(scenario_outputs) x(v) WHERE x.v->>'label' <> 'HYPOTHETICAL_ONLY_NOT_FAIR_VALUE') FROM e)
 UNION ALL SELECT '12_NO_MODEL_VERSION_PROMOTION',(SELECT COUNT(*)=0 FROM fwios.valuation_model_versions WHERE model_id='INTERACTIVE_ENTERTAINMENT_IP_DCF_V1')
 UNION ALL SELECT '13_NO_PRODUCTION_VALUATION',(SELECT COUNT(*)=0 FROM fwios.valuation_runs WHERE ticker='TTWO')
 UNION ALL SELECT '14_NO_CANONICAL_APPLY',(SELECT COUNT(*)=0 FROM fwios.metric_observations WHERE instrument_id='4930e480-cb82-40b7-89a7-9ea55e190244'::uuid)
 UNION ALL SELECT '15_NO_DECISION',(SELECT COUNT(*)=0 FROM fwios.decision_snapshots WHERE ticker='TTWO')
 UNION ALL SELECT '16_NO_RESEARCH_APPLY',(SELECT COUNT(*)=0 FROM fwios.research_ingest_receipts_v1 WHERE ticker='TTWO')
 UNION ALL SELECT '17_EXISTING_EOD_64_INTACT',(SELECT COUNT(*)=64 FROM fwios.market_daily_closes WHERE session_date='2026-10-27')
 UNION ALL SELECT '18_CANDIDATE_RLS_ENABLED',(SELECT relrowsecurity FROM pg_class WHERE oid='fwios.ai_model_candidates_v1'::regclass)
 UNION ALL SELECT '19_EVALUATION_RLS_ENABLED',(SELECT relrowsecurity FROM pg_class WHERE oid='fwios.ai_model_evaluations_v1'::regclass)
 UNION ALL SELECT '20_ANON_NOT_EXECUTOR',(SELECT NOT has_function_privilege('anon','fwios.evaluate_ttwo_ai_model_candidate_v1(uuid)','EXECUTE'))
 UNION ALL SELECT '21_AUTHENTICATED_NOT_EXECUTOR',(SELECT NOT has_function_privilege('authenticated','fwios.evaluate_ttwo_ai_model_candidate_v1(uuid)','EXECUTE'))
 UNION ALL SELECT '22_INVOKER_EXECUTOR',(SELECT NOT prosecdef FROM pg_proc WHERE oid='fwios.evaluate_ttwo_ai_model_candidate_v1(uuid)'::regprocedure)
 UNION ALL SELECT '23_ZERO_DUPLICATE_RECEIPTS',(SELECT COUNT(*)=COUNT(DISTINCT (candidate_id,snapshot_hash,policy_version)) FROM fwios.ai_model_evaluations_v1)
 UNION ALL SELECT '24_NO_PUBLIC_TABLE_SELECT',(SELECT NOT has_table_privilege('anon','fwios.ai_model_candidates_v1','SELECT'))
)
SELECT check_id, CASE WHEN ok IS TRUE THEN 'PASS' ELSE 'FAIL' END result
FROM checks ORDER BY check_id;