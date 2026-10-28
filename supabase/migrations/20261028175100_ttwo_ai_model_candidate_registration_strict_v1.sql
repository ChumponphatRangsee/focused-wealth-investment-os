-- TTWO model candidate registration must reject null/missing hypothetical flag.
CREATE OR REPLACE FUNCTION fwios.register_ttwo_ai_model_candidate_v1(
 p_version text,p_proposal jsonb,p_github_pr_url text
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO '' AS $$
DECLARE v_id uuid; v_hash text; v_archetype text; v_model_count integer;
BEGIN
 IF p_version IS NULL OR p_version !~ '^0[.][0-9]+[.][0-9]+-SHADOW$' THEN
  RAISE EXCEPTION 'TTWO_CANDIDATE_VERSION_SHADOW_ONLY';
 END IF;
 IF coalesce(jsonb_typeof(p_proposal),'null') <> 'object'
    OR coalesce(jsonb_typeof(p_proposal->'scenarios'),'null') <> 'array'
    OR jsonb_array_length(p_proposal->'scenarios') <> 3
    OR coalesce(p_proposal->>'hypothetical','false') <> 'true' THEN
  RAISE EXCEPTION 'TTWO_CANDIDATE_REQUIRES_THREE_HYPOTHETICAL_SCENARIOS';
 END IF;
 IF p_github_pr_url IS NULL OR
    p_github_pr_url !~ '^https://github[.]com/ChumponphatRangsee/focused-wealth-investment-os/pull/[0-9]+$' THEN
  RAISE EXCEPTION 'TTWO_CANDIDATE_GITHUB_PR_REQUIRED';
 END IF;
 SELECT t.archetype INTO v_archetype
 FROM fwios.thesis_registry t WHERE t.ticker='TTWO' AND t.active=true;
 IF v_archetype IS NULL THEN RAISE EXCEPTION 'TTWO_ACTIVE_THESIS_NOT_FOUND'; END IF;
 SELECT count(*) INTO v_model_count FROM fwios.valuation_models m
 JOIN fwios.valuation_model_versions v ON v.model_id=m.model_id
 WHERE lower(m.archetype)=lower(v_archetype)
  AND m.production_status='IMPLEMENTED' AND v.status='PRODUCTION'
  AND v.regression_status='PASS';
 IF v_model_count>0 THEN RAISE EXCEPTION 'EXISTING_PRODUCTION_ROUTE_USE_APPROVED_MODEL'; END IF;
 v_hash:=md5(p_proposal::text||p_github_pr_url);
 INSERT INTO fwios.ai_model_candidates_v1
 (ticker,model_id,model_version,archetype,proposal,proposal_hash,github_pr_url)
 VALUES ('TTWO','INTERACTIVE_ENTERTAINMENT_IP_DCF_V1',p_version,v_archetype,p_proposal,v_hash,p_github_pr_url)
 ON CONFLICT (ticker,model_id,model_version,proposal_hash) DO NOTHING
 RETURNING candidate_id INTO v_id;
 IF v_id IS NULL THEN
  SELECT candidate_id INTO v_id FROM fwios.ai_model_candidates_v1
  WHERE ticker='TTWO' AND model_id='INTERACTIVE_ENTERTAINMENT_IP_DCF_V1'
   AND model_version=p_version AND proposal_hash=v_hash;
 END IF;
 RETURN jsonb_build_object('candidate_id',v_id,'status','SHADOW_ONLY',
 'proposal_hash',v_hash,'production_write',false,'auto_trade',false);
END; $$;

