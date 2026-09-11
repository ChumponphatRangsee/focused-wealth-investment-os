-- Packaging FCF DCF v1
-- Runtime evidence, prices, valuation runs, and candidate decisions are state and are intentionally not hard-coded here.

insert into fwios.valuation_models(
  model_id,archetype,model_family,production_status,model_version,required_metric_ids,regression_status,confidence_status,notes
) values (
  'PACKAGING_FCF_DCF_V1','Packaging','FCF_COMPOUNDER','IMPLEMENTED','1.0',
  array['shipment_growth','normalized_fcf','net_debt','shares_outstanding','aluminum_pass_through_coverage','eps_growth_guidance']::text[],
  'PASS','PRODUCTION_V1',
  'Packaging-specific equity FCF DCF. Uses normalized/guided FCF as the cash-flow anchor, deducts net debt, and treats shipment growth, EPS guidance and commodity pass-through as explicit scenario/quality anchors.'
)
on conflict(model_id) do update set
  archetype=excluded.archetype,model_family=excluded.model_family,production_status=excluded.production_status,
  model_version=excluded.model_version,required_metric_ids=excluded.required_metric_ids,
  regression_status=excluded.regression_status,confidence_status=excluded.confidence_status,notes=excluded.notes,updated_at=now();

create or replace function fwios.packaging_fcf_dcf_fv_v1(
  p_normalized_fcf_b numeric,
  p_net_debt_b numeric,
  p_shares_m numeric,
  p_growth_y1_5 numeric,
  p_growth_y6_10 numeric,
  p_discount_rate numeric,
  p_terminal_growth numeric
) returns numeric
language sql
immutable strict
security invoker
set search_path=pg_catalog,fwios
as $$
  select case
    when p_normalized_fcf_b <= 0 then null
    when p_shares_m <= 0 then null
    when p_growth_y1_5 < -0.10 or p_growth_y1_5 > 0.15 then null
    when p_growth_y6_10 < -0.05 or p_growth_y6_10 > 0.08 then null
    when p_discount_rate < 0.07 or p_discount_rate > 0.13 then null
    when p_terminal_growth < 0 or p_terminal_growth > 0.04 then null
    when p_discount_rate <= p_terminal_growth then null
    else fwios.fcf_compounder_fv(
      p_normalized_fcf_b,-p_net_debt_b,p_shares_m,
      p_growth_y1_5,p_growth_y6_10,p_discount_rate,p_terminal_growth
    )
  end
$$;
revoke execute on function fwios.packaging_fcf_dcf_fv_v1(numeric,numeric,numeric,numeric,numeric,numeric,numeric) from public,anon,authenticated;

insert into fwios.valuation_model_versions(
  version_id,model_id,version_label,status,kernel_family,input_contract,model_policy,assumptions,
  confidence_tier,regression_status,effective_from,source_system,source_ref
) values (
  'PACKAGING_FCF_DCF_V1::1.0','PACKAGING_FCF_DCF_V1','1.0','PRODUCTION','FCF_COMPOUNDER',
  '{"required_metrics":["shipment_growth","normalized_fcf","net_debt","shares_outstanding","aluminum_pass_through_coverage","eps_growth_guidance"],"normalization_version":"NORM_V1-PACKAGING","guidance_fcf_must_be_company_reported":true,"commodity_pass_through_review_required":true}'::jsonb,
  '{"method":"10-year equity FCF DCF with explicit net-debt deduction","policy":"PACKAGING_FCF_DCF_POLICY_V1","probabilities":"25/50/25","starting_fcf_policy":"use company-reported annual FCF guidance floor or verified normalized FCF; do not annualize a single quarter","scenario_growth_policy":"company-specific and evidence-anchored","commodity_pass_through_role":"quality/risk diagnostic, not a hidden score modifier"}'::jsonb,
  '{"base_discount":0.09,"bear_discount":0.105,"bull_discount":0.08,"base_growth_y1_5":0.07,"bear_growth_y1_5":0.02,"bull_growth_y1_5":0.10,"base_growth_y6_10":0.035,"bear_growth_y6_10":0.02,"bull_growth_y6_10":0.05,"base_terminal_growth":0.03,"bear_terminal_growth":0.025,"bull_terminal_growth":0.03}'::jsonb,
  'PRODUCTION_V1','PASS','2026-09-11','supabase','PACKAGING_VALUATION_CONTRACT_V1'
)
on conflict(version_id) do update set
  status=excluded.status,kernel_family=excluded.kernel_family,input_contract=excluded.input_contract,
  model_policy=excluded.model_policy,assumptions=excluded.assumptions,confidence_tier=excluded.confidence_tier,
  regression_status=excluded.regression_status,effective_from=excluded.effective_from,
  source_system=excluded.source_system,source_ref=excluded.source_ref;
