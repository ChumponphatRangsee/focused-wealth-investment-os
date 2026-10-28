-- FWIOS TTWO autonomous model-candidate gateway v1.
-- Only an additive, isolated SHADOW state path. No valuation_models, valuation_runs,
-- decision, portfolio, cron, model promotion, trade, or historical rows are changed.
CREATE TABLE IF NOT EXISTS fwios.ai_model_candidates_v1 (
  candidate_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticker text NOT NULL CHECK (ticker = 'TTWO'),
  model_id text NOT NULL CHECK (model_id = 'INTERACTIVE_ENTERTAINMENT_IP_DCF_V1'),
  model_version text NOT NULL CHECK (model_version ~ '^0[.][0-9]+[.][0-9]+-SHADOW$'),
  archetype text NOT NULL,
  proposal jsonb NOT NULL CHECK (jsonb_typeof(proposal)='object'),
  proposal_hash text NOT NULL,
  github_pr_url text NOT NULL
    CHECK (github_pr_url ~ '^https://github[.]com/ChumponphatRangsee/focused-wealth-investment-os/pull/[0-9]+$'),
  lifecycle_state text NOT NULL DEFAULT 'SHADOW_ONLY'
    CHECK (lifecycle_state='SHADOW_ONLY'),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(ticker,model_id,model_version,proposal_hash)
);
CREATE TABLE IF NOT EXISTS fwios.ai_model_evaluations_v1 (
  evaluation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id uuid NOT NULL REFERENCES fwios.ai_model_candidates_v1(candidate_id),
  snapshot_hash text NOT NULL,
  policy_version text NOT NULL DEFAULT 'TTWO_SHADOW_EVAL_V1',
  evaluation_state text NOT NULL CHECK(evaluation_state IN ('SHADOW_STRUCTURAL_PASS','BLOCKED')),
  checks jsonb NOT NULL CHECK (jsonb_typeof(checks)='object'),
  scenario_outputs jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(scenario_outputs)='array'),
  price_session date,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(candidate_id,snapshot_hash,policy_version)
);
ALTER TABLE fwios.ai_model_candidates_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE fwios.ai_model_evaluations_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON fwios.ai_model_candidates_v1,fwios.ai_model_evaluations_v1 FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT ON fwios.ai_model_candidates_v1,fwios.ai_model_evaluations_v1 TO service_role;

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
    OR p_proposal->>'hypothetical' <> 'true' THEN
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

CREATE OR REPLACE FUNCTION fwios.evaluate_ttwo_ai_model_candidate_v1(p_candidate_id uuid)
 RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER SET search_path TO '' AS $$
DECLARE
 c fwios.ai_model_candidates_v1%ROWTYPE;
 v_facts jsonb; v_filings jsonb; v_facts_hash text; v_filings_hash text;
 v_close numeric; v_session date; v_price_ok boolean:=false;
 v_sec_ok boolean:=false; v_fact_ok boolean:=false;
 v_model_exists boolean:=false; v_input_ok boolean:=true;
 v_scenarios jsonb; v_row jsonb; v_output jsonb:='[]'::jsonb;
 v_seen text[]:='{}'; v_weight_sum numeric:=0;
 v_weight numeric; v_shock numeric; v_growth numeric; v_margin numeric;
 v_discount numeric; v_term numeric; v_dilution numeric;
 v_net_cash numeric:=-0.6931; v_shares numeric; v_fcf numeric;
 v_pv numeric; v_terminal numeric; v_fv numeric; v_y int;
 v_name text; v_state text; v_hash text; v_id uuid; v_checks jsonb;
BEGIN
 SELECT * INTO c FROM fwios.ai_model_candidates_v1 WHERE candidate_id=p_candidate_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'UNKNOWN_TTWO_MODEL_CANDIDATE'; END IF;
 SELECT e.payload,e.payload_fingerprint INTO v_facts,v_facts_hash
 FROM fwios.decision_refresh_shadow_evidence e
 WHERE e.ticker='TTWO' AND e.fact_class='SEC_COMPANY_FACTS'
  AND e.source_provider='SEC_EDGAR' AND e.collection_status='PASS'
 ORDER BY e.observed_at DESC LIMIT 1;
 SELECT e.payload,e.payload_fingerprint INTO v_filings,v_filings_hash
 FROM fwios.decision_refresh_shadow_evidence e
 WHERE e.ticker='TTWO' AND e.fact_class='SEC_SUBMISSIONS'
  AND e.source_provider='SEC_EDGAR' AND e.collection_status='PASS'
 ORDER BY e.observed_at DESC LIMIT 1;
 SELECT d.session_date,d.close_price,
   (d.verification_status='VERIFIED' AND d.provenance_status='PASS'
      AND d.secondary_close>0 AND d.close_price>0
      AND d.session_date>=current_date-7)
 INTO v_session,v_close,v_price_ok
 FROM fwios.market_daily_closes d WHERE d.asset_symbol='TTWO'
 ORDER BY d.session_date DESC LIMIT 1;
 v_price_ok:=coalesce(v_price_ok,false);
 SELECT EXISTS(
  SELECT 1 FROM pg_catalog.jsonb_array_elements(
   coalesce(v_filings->'latest_filings','[]'::jsonb)) f(x)
  WHERE x->>'form'='10-Q' AND x->>'report_date'='2026-06-30'
   AND x->>'accession_number'='0001628280-26-054870'
 ) INTO v_sec_ok;
 SELECT EXISTS(
  SELECT 1 FROM pg_catalog.jsonb_array_elements(
   coalesce(v_facts->'facts'->'RevenueFromContractWithCustomerExcludingAssessedTax'->'units'->'USD','[]'::jsonb)) f(x)
  WHERE x->>'start'='2026-04-01' AND x->>'end'='2026-06-30'
   AND x->>'accn'='0001628280-26-054870'
   AND x->>'form'='10-Q'
   AND x->>'val'='1533900000'
 ) INTO v_fact_ok;
 SELECT EXISTS(SELECT 1 FROM fwios.valuation_models m
  JOIN fwios.valuation_model_versions v ON v.model_id=m.model_id
  WHERE lower(m.archetype)=lower(c.archetype)
   AND m.production_status='IMPLEMENTED'
   AND v.status='PRODUCTION' AND v.regression_status='PASS')
 INTO v_model_exists;
 v_scenarios:=c.proposal->'scenarios';
 IF coalesce(jsonb_typeof(v_scenarios),'null')<>'array' OR
    jsonb_array_length(v_scenarios)<>3 THEN v_input_ok:=false;
 ELSE
 FOR v_row IN SELECT value FROM pg_catalog.jsonb_array_elements(v_scenarios) LOOP
  v_name:=v_row->>'name';
  IF v_name IS NULL OR v_name NOT IN ('Bear','Base','Bull')
      OR v_name=ANY(v_seen) THEN
   v_input_ok:=false; EXIT;
  END IF;
  v_seen:=array_append(v_seen,v_name);
  IF COALESCE(((v_row->>'weight') ~ '^[0-9]+([.][0-9]+)?
   AND (v_row->>'fy28_shock') ~ '^[-+]?[0-9]+([.][0-9]+)?$'
   AND (v_row->>'later_growth') ~ '^[-+]?[0-9]+([.][0-9]+)?$'
   AND (v_row->>'owner_cash_margin') ~ '^[0-9]+([.][0-9]+)?$'
   AND (v_row->>'discount_rate') ~ '^[0-9]+([.][0-9]+)?$'
   AND (v_row->>'terminal_growth') ~ '^[0-9]+([.][0-9]+)?$'
   AND (v_row->>'dilution') ~ '^[0-9]+([.][0-9]+)?
   v_input_ok:=false; EXIT;
  END IF;
  v_weight:=(v_row->>'weight')::numeric;
  v_shock:=(v_row->>'fy28_shock')::numeric;
  v_growth:=(v_row->>'later_growth')::numeric;
  v_margin:=(v_row->>'owner_cash_margin')::numeric;
  v_discount:=(v_row->>'discount_rate')::numeric;
  v_term:=(v_row->>'terminal_growth')::numeric;
  v_dilution:=(v_row->>'dilution')::numeric;
  IF COALESCE((v_weight>0 AND v_weight<=1
    AND v_shock BETWEEN -0.50 AND 1
    AND v_growth BETWEEN -0.05 AND 0.20
    AND v_margin BETWEEN 0.02 AND 0.50
    AND v_discount BETWEEN 0.07 AND 0.20
    AND v_term BETWEEN 0 AND 0.04
    AND v_discount-v_term>=0.04
    AND v_dilution BETWEEN 0 AND 0.20),false) IS NOT TRUE THEN
   v_input_ok:=false; EXIT;
  END IF;
  v_weight_sum:=v_weight_sum+v_weight;
  v_pv:=0;v_terminal:=0;v_shares:=187*(1+v_dilution);
  FOR v_y IN 1..10 LOOP
   IF v_y=1 THEN v_fcf:=1.0-0.29; -- FY27 issuer *guide lower-bound proxy*, not audited FCF.
   ELSE v_fcf:=8.1*(1+v_shock)*power(1+v_growth,v_y-2)*v_margin; END IF;
   v_pv:=v_pv+v_fcf/power(1+v_discount,v_y);
   IF v_y=10 THEN
    v_terminal:=v_fcf*(1+v_term)/(v_discount-v_term)/power(1+v_discount,10);
   END IF;
  END LOOP;
  v_fv:=round((v_pv+v_terminal+v_net_cash)*1000/v_shares,2);
  v_output:=v_output||jsonb_build_array(jsonb_build_object(
   'scenario',v_name,'hypothetical_per_share_usd',v_fv,
   'pv_10y_b',round(v_pv,6),'pv_terminal_b',round(v_terminal,6),
   'label','HYPOTHETICAL_ONLY_NOT_FAIR_VALUE'));
 END LOOP;
 IF v_weight_sum IS DISTINCT FROM 1 OR array_length(v_seen,1) IS DISTINCT FROM 3 THEN v_input_ok:=false; END IF;
 END IF;
 v_state:=CASE WHEN v_price_ok AND v_sec_ok AND v_fact_ok
  AND NOT v_model_exists AND v_input_ok AND c.lifecycle_state='SHADOW_ONLY'
 THEN 'SHADOW_STRUCTURAL_PASS' ELSE 'BLOCKED' END;
 IF v_state='BLOCKED' THEN v_output:='[]'::jsonb; END IF;
 v_checks:=jsonb_build_object(
 'verified_price_current',v_price_ok,'sec_filing_present',v_sec_ok,
 'sec_financial_fact_matched',v_fact_ok,'new_archetype_uncovered',NOT v_model_exists,
 'three_scenario_assumptions_structurally_valid',v_input_ok,
 'economic_correctness_validated',false,
 'production_eligible',false,'auto_trade',false);
 v_hash:=md5(c.proposal_hash||coalesce(v_facts_hash,'NO_SEC_FACTS')
 ||coalesce(v_filings_hash,'NO_SEC_SUBMISSIONS')||coalesce(v_session::text,'NO_PRICE')
 ||coalesce(v_close::text,'NO_PRICE')||v_model_exists::text);
 INSERT INTO fwios.ai_model_evaluations_v1(
 candidate_id,snapshot_hash,evaluation_state,checks,scenario_outputs,price_session)
 VALUES (c.candidate_id,v_hash,v_state,v_checks,v_output,v_session)
 ON CONFLICT(candidate_id,snapshot_hash,policy_version) DO NOTHING
 RETURNING evaluation_id INTO v_id;
 IF v_id IS NULL THEN
  SELECT evaluation_id INTO v_id FROM fwios.ai_model_evaluations_v1
  WHERE candidate_id=c.candidate_id AND snapshot_hash=v_hash
   AND policy_version='TTWO_SHADOW_EVAL_V1';
 END IF;
 RETURN jsonb_build_object('candidate_id',c.candidate_id,'evaluation_id',v_id,
 'state',v_state,'checks',v_checks,'scenario_outputs',v_output,
 'price_session',v_session,'production_changes','NONE','auto_trade',false);
END; $$;
REVOKE ALL ON FUNCTION fwios.register_ttwo_ai_model_candidate_v1(text,jsonb,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION fwios.evaluate_ttwo_ai_model_candidate_v1(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION fwios.register_ttwo_ai_model_candidate_v1(text,jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION fwios.evaluate_ttwo_ai_model_candidate_v1(uuid) TO service_role;

   AND (v_row->>'fy28_shock') ~ '^[-+]?[0-9]+([.][0-9]+)?$'
   AND (v_row->>'later_growth') ~ '^[-+]?[0-9]+([.][0-9]+)?$'
   AND (v_row->>'owner_cash_margin') ~ '^[0-9]+([.][0-9]+)?$'
   AND (v_row->>'discount_rate') ~ '^[0-9]+([.][0-9]+)?$'
   AND (v_row->>'terminal_growth') ~ '^[0-9]+([.][0-9]+)?$'
   AND (v_row->>'dilution') ~ '^[0-9]+([.][0-9]+)?$') THEN
   v_input_ok:=false; EXIT;
  END IF;
  v_weight:=(v_row->>'weight')::numeric;
  v_shock:=(v_row->>'fy28_shock')::numeric;
  v_growth:=(v_row->>'later_growth')::numeric;
  v_margin:=(v_row->>'owner_cash_margin')::numeric;
  v_discount:=(v_row->>'discount_rate')::numeric;
  v_term:=(v_row->>'terminal_growth')::numeric;
  v_dilution:=(v_row->>'dilution')::numeric;
  IF NOT (v_weight>0 AND v_weight<=1
    AND v_shock BETWEEN -0.50 AND 1
    AND v_growth BETWEEN -0.05 AND 0.20
    AND v_margin BETWEEN 0.02 AND 0.50
    AND v_discount BETWEEN 0.07 AND 0.20
    AND v_term BETWEEN 0 AND 0.04
    AND v_discount-v_term>=0.04
    AND v_dilution BETWEEN 0 AND 0.20) THEN
   v_input_ok:=false; EXIT;
  END IF;
  v_weight_sum:=v_weight_sum+v_weight;
  v_pv:=0;v_terminal:=0;v_shares:=187*(1+v_dilution);
  FOR v_y IN 1..10 LOOP
   IF v_y=1 THEN v_fcf:=1.0-0.29; -- FY27 issuer *guide lower-bound proxy*, not audited FCF.
   ELSE v_fcf:=8.1*(1+v_shock)*power(1+v_growth,v_y-2)*v_margin; END IF;
   v_pv:=v_pv+v_fcf/power(1+v_discount,v_y);
   IF v_y=10 THEN
    v_terminal:=v_fcf*(1+v_term)/(v_discount-v_term)/power(1+v_discount,10);
   END IF;
  END LOOP;
  v_fv:=round((v_pv+v_terminal+v_net_cash)*1000/v_shares,2);
  v_output:=v_output||jsonb_build_array(jsonb_build_object(
   'scenario',v_name,'hypothetical_per_share_usd',v_fv,
   'pv_10y_b',round(v_pv,6),'pv_terminal_b',round(v_terminal,6),
   'label','HYPOTHETICAL_ONLY_NOT_FAIR_VALUE'));
 END LOOP;
 IF v_weight_sum<>1 OR array_length(v_seen,1)<>3 THEN v_input_ok:=false; END IF;
 END IF;
 v_state:=CASE WHEN v_price_ok AND v_sec_ok AND v_fact_ok
  AND NOT v_model_exists AND v_input_ok AND c.lifecycle_state='SHADOW_ONLY'
 THEN 'SHADOW_STRUCTURAL_PASS' ELSE 'BLOCKED' END;
 IF v_state='BLOCKED' THEN v_output:='[]'::jsonb; END IF;
 v_checks:=jsonb_build_object(
 'verified_price_current',v_price_ok,'sec_filing_present',v_sec_ok,
 'sec_financial_fact_matched',v_fact_ok,'new_archetype_uncovered',NOT v_model_exists,
 'three_scenario_assumptions_structurally_valid',v_input_ok,
 'economic_correctness_validated',false,
 'production_eligible',false,'auto_trade',false);
 v_hash:=md5(c.proposal_hash||coalesce(v_facts_hash,'NO_SEC_FACTS')
 ||coalesce(v_filings_hash,'NO_SEC_SUBMISSIONS')||coalesce(v_session::text,'NO_PRICE')
 ||coalesce(v_close::text,'NO_PRICE')||v_model_exists::text);
 INSERT INTO fwios.ai_model_evaluations_v1(
 candidate_id,snapshot_hash,evaluation_state,checks,scenario_outputs,price_session)
 VALUES (c.candidate_id,v_hash,v_state,v_checks,v_output,v_session)
 ON CONFLICT(candidate_id,snapshot_hash,policy_version) DO NOTHING
 RETURNING evaluation_id INTO v_id;
 IF v_id IS NULL THEN
  SELECT evaluation_id INTO v_id FROM fwios.ai_model_evaluations_v1
  WHERE candidate_id=c.candidate_id AND snapshot_hash=v_hash
   AND policy_version='TTWO_SHADOW_EVAL_V1';
 END IF;
 RETURN jsonb_build_object('candidate_id',c.candidate_id,'evaluation_id',v_id,
 'state',v_state,'checks',v_checks,'scenario_outputs',v_output,
 'price_session',v_session,'production_changes','NONE','auto_trade',false);
END; $$;
REVOKE ALL ON FUNCTION fwios.register_ttwo_ai_model_candidate_v1(text,jsonb,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION fwios.evaluate_ttwo_ai_model_candidate_v1(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION fwios.register_ttwo_ai_model_candidate_v1(text,jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION fwios.evaluate_ttwo_ai_model_candidate_v1(uuid) TO service_role;
),false) IS NOT TRUE THEN
   v_input_ok:=false; EXIT;
  END IF;
  v_weight:=(v_row->>'weight')::numeric;
  v_shock:=(v_row->>'fy28_shock')::numeric;
  v_growth:=(v_row->>'later_growth')::numeric;
  v_margin:=(v_row->>'owner_cash_margin')::numeric;
  v_discount:=(v_row->>'discount_rate')::numeric;
  v_term:=(v_row->>'terminal_growth')::numeric;
  v_dilution:=(v_row->>'dilution')::numeric;
  IF NOT (v_weight>0 AND v_weight<=1
    AND v_shock BETWEEN -0.50 AND 1
    AND v_growth BETWEEN -0.05 AND 0.20
    AND v_margin BETWEEN 0.02 AND 0.50
    AND v_discount BETWEEN 0.07 AND 0.20
    AND v_term BETWEEN 0 AND 0.04
    AND v_discount-v_term>=0.04
    AND v_dilution BETWEEN 0 AND 0.20) THEN
   v_input_ok:=false; EXIT;
  END IF;
  v_weight_sum:=v_weight_sum+v_weight;
  v_pv:=0;v_terminal:=0;v_shares:=187*(1+v_dilution);
  FOR v_y IN 1..10 LOOP
   IF v_y=1 THEN v_fcf:=1.0-0.29; -- FY27 issuer *guide lower-bound proxy*, not audited FCF.
   ELSE v_fcf:=8.1*(1+v_shock)*power(1+v_growth,v_y-2)*v_margin; END IF;
   v_pv:=v_pv+v_fcf/power(1+v_discount,v_y);
   IF v_y=10 THEN
    v_terminal:=v_fcf*(1+v_term)/(v_discount-v_term)/power(1+v_discount,10);
   END IF;
  END LOOP;
  v_fv:=round((v_pv+v_terminal+v_net_cash)*1000/v_shares,2);
  v_output:=v_output||jsonb_build_array(jsonb_build_object(
   'scenario',v_name,'hypothetical_per_share_usd',v_fv,
   'pv_10y_b',round(v_pv,6),'pv_terminal_b',round(v_terminal,6),
   'label','HYPOTHETICAL_ONLY_NOT_FAIR_VALUE'));
 END LOOP;
 IF v_weight_sum<>1 OR array_length(v_seen,1)<>3 THEN v_input_ok:=false; END IF;
 END IF;
 v_state:=CASE WHEN v_price_ok AND v_sec_ok AND v_fact_ok
  AND NOT v_model_exists AND v_input_ok AND c.lifecycle_state='SHADOW_ONLY'
 THEN 'SHADOW_STRUCTURAL_PASS' ELSE 'BLOCKED' END;
 IF v_state='BLOCKED' THEN v_output:='[]'::jsonb; END IF;
 v_checks:=jsonb_build_object(
 'verified_price_current',v_price_ok,'sec_filing_present',v_sec_ok,
 'sec_financial_fact_matched',v_fact_ok,'new_archetype_uncovered',NOT v_model_exists,
 'three_scenario_assumptions_structurally_valid',v_input_ok,
 'economic_correctness_validated',false,
 'production_eligible',false,'auto_trade',false);
 v_hash:=md5(c.proposal_hash||coalesce(v_facts_hash,'NO_SEC_FACTS')
 ||coalesce(v_filings_hash,'NO_SEC_SUBMISSIONS')||coalesce(v_session::text,'NO_PRICE')
 ||coalesce(v_close::text,'NO_PRICE')||v_model_exists::text);
 INSERT INTO fwios.ai_model_evaluations_v1(
 candidate_id,snapshot_hash,evaluation_state,checks,scenario_outputs,price_session)
 VALUES (c.candidate_id,v_hash,v_state,v_checks,v_output,v_session)
 ON CONFLICT(candidate_id,snapshot_hash,policy_version) DO NOTHING
 RETURNING evaluation_id INTO v_id;
 IF v_id IS NULL THEN
  SELECT evaluation_id INTO v_id FROM fwios.ai_model_evaluations_v1
  WHERE candidate_id=c.candidate_id AND snapshot_hash=v_hash
   AND policy_version='TTWO_SHADOW_EVAL_V1';
 END IF;
 RETURN jsonb_build_object('candidate_id',c.candidate_id,'evaluation_id',v_id,
 'state',v_state,'checks',v_checks,'scenario_outputs',v_output,
 'price_session',v_session,'production_changes','NONE','auto_trade',false);
END; $$;
REVOKE ALL ON FUNCTION fwios.register_ttwo_ai_model_candidate_v1(text,jsonb,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION fwios.evaluate_ttwo_ai_model_candidate_v1(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION fwios.register_ttwo_ai_model_candidate_v1(text,jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION fwios.evaluate_ttwo_ai_model_candidate_v1(uuid) TO service_role;

   AND (v_row->>'fy28_shock') ~ '^[-+]?[0-9]+([.][0-9]+)?$'
   AND (v_row->>'later_growth') ~ '^[-+]?[0-9]+([.][0-9]+)?$'
   AND (v_row->>'owner_cash_margin') ~ '^[0-9]+([.][0-9]+)?$'
   AND (v_row->>'discount_rate') ~ '^[0-9]+([.][0-9]+)?$'
   AND (v_row->>'terminal_growth') ~ '^[0-9]+([.][0-9]+)?$'
   AND (v_row->>'dilution') ~ '^[0-9]+([.][0-9]+)?$') THEN
   v_input_ok:=false; EXIT;
  END IF;
  v_weight:=(v_row->>'weight')::numeric;
  v_shock:=(v_row->>'fy28_shock')::numeric;
  v_growth:=(v_row->>'later_growth')::numeric;
  v_margin:=(v_row->>'owner_cash_margin')::numeric;
  v_discount:=(v_row->>'discount_rate')::numeric;
  v_term:=(v_row->>'terminal_growth')::numeric;
  v_dilution:=(v_row->>'dilution')::numeric;
  IF NOT (v_weight>0 AND v_weight<=1
    AND v_shock BETWEEN -0.50 AND 1
    AND v_growth BETWEEN -0.05 AND 0.20
    AND v_margin BETWEEN 0.02 AND 0.50
    AND v_discount BETWEEN 0.07 AND 0.20
    AND v_term BETWEEN 0 AND 0.04
    AND v_discount-v_term>=0.04
    AND v_dilution BETWEEN 0 AND 0.20) THEN
   v_input_ok:=false; EXIT;
  END IF;
  v_weight_sum:=v_weight_sum+v_weight;
  v_pv:=0;v_terminal:=0;v_shares:=187*(1+v_dilution);
  FOR v_y IN 1..10 LOOP
   IF v_y=1 THEN v_fcf:=1.0-0.29; -- FY27 issuer *guide lower-bound proxy*, not audited FCF.
   ELSE v_fcf:=8.1*(1+v_shock)*power(1+v_growth,v_y-2)*v_margin; END IF;
   v_pv:=v_pv+v_fcf/power(1+v_discount,v_y);
   IF v_y=10 THEN
    v_terminal:=v_fcf*(1+v_term)/(v_discount-v_term)/power(1+v_discount,10);
   END IF;
  END LOOP;
  v_fv:=round((v_pv+v_terminal+v_net_cash)*1000/v_shares,2);
  v_output:=v_output||jsonb_build_array(jsonb_build_object(
   'scenario',v_name,'hypothetical_per_share_usd',v_fv,
   'pv_10y_b',round(v_pv,6),'pv_terminal_b',round(v_terminal,6),
   'label','HYPOTHETICAL_ONLY_NOT_FAIR_VALUE'));
 END LOOP;
 IF v_weight_sum<>1 OR array_length(v_seen,1)<>3 THEN v_input_ok:=false; END IF;
 END IF;
 v_state:=CASE WHEN v_price_ok AND v_sec_ok AND v_fact_ok
  AND NOT v_model_exists AND v_input_ok AND c.lifecycle_state='SHADOW_ONLY'
 THEN 'SHADOW_STRUCTURAL_PASS' ELSE 'BLOCKED' END;
 IF v_state='BLOCKED' THEN v_output:='[]'::jsonb; END IF;
 v_checks:=jsonb_build_object(
 'verified_price_current',v_price_ok,'sec_filing_present',v_sec_ok,
 'sec_financial_fact_matched',v_fact_ok,'new_archetype_uncovered',NOT v_model_exists,
 'three_scenario_assumptions_structurally_valid',v_input_ok,
 'economic_correctness_validated',false,
 'production_eligible',false,'auto_trade',false);
 v_hash:=md5(c.proposal_hash||coalesce(v_facts_hash,'NO_SEC_FACTS')
 ||coalesce(v_filings_hash,'NO_SEC_SUBMISSIONS')||coalesce(v_session::text,'NO_PRICE')
 ||coalesce(v_close::text,'NO_PRICE')||v_model_exists::text);
 INSERT INTO fwios.ai_model_evaluations_v1(
 candidate_id,snapshot_hash,evaluation_state,checks,scenario_outputs,price_session)
 VALUES (c.candidate_id,v_hash,v_state,v_checks,v_output,v_session)
 ON CONFLICT(candidate_id,snapshot_hash,policy_version) DO NOTHING
 RETURNING evaluation_id INTO v_id;
 IF v_id IS NULL THEN
  SELECT evaluation_id INTO v_id FROM fwios.ai_model_evaluations_v1
  WHERE candidate_id=c.candidate_id AND snapshot_hash=v_hash
   AND policy_version='TTWO_SHADOW_EVAL_V1';
 END IF;
 RETURN jsonb_build_object('candidate_id',c.candidate_id,'evaluation_id',v_id,
 'state',v_state,'checks',v_checks,'scenario_outputs',v_output,
 'price_session',v_session,'production_changes','NONE','auto_trade',false);
END; $$;
REVOKE ALL ON FUNCTION fwios.register_ttwo_ai_model_candidate_v1(text,jsonb,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION fwios.evaluate_ttwo_ai_model_candidate_v1(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION fwios.register_ttwo_ai_model_candidate_v1(text,jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION fwios.evaluate_ttwo_ai_model_candidate_v1(uuid) TO service_role;
