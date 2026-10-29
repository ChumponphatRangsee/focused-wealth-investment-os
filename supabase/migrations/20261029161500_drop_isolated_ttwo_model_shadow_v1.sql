-- User-directed price-only decommission: remove isolated TTWO AI/valuation shadow data.
-- This is a narrow, dependency-safe first drop, NOT the complete research subsystem retirement.
DO $$
BEGIN
 IF (SELECT count(*) FROM fwios.ai_model_candidates_v1) <> 1
    OR (SELECT count(*) FROM fwios.ai_model_evaluations_v1) <> 1
 THEN RAISE EXCEPTION 'PRE_DROP_DRIFT_TTWO_AI_MODEL'; END IF;
END $$;
DROP FUNCTION IF EXISTS fwios.evaluate_ttwo_ai_model_candidate_v1(uuid) RESTRICT;
DROP FUNCTION IF EXISTS fwios.register_ttwo_ai_model_candidate_v1(text,jsonb,text) RESTRICT;
DROP TABLE fwios.ai_model_evaluations_v1 RESTRICT;
DROP TABLE fwios.ai_model_candidates_v1 RESTRICT;
