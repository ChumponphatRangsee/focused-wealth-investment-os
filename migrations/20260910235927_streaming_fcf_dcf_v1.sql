-- Streaming / Media FCF DCF v1
-- Runtime evidence, prices, valuation runs, and candidate decisions are state and are intentionally not hard-coded here.

insert into fwios.valuation_models(
  model_id,archetype,model_family,production_status,model_version,required_metric_ids,regression_status,confidence_status,notes
) values (
  'STREAMING_FCF_DCF_V1','Streaming / Media','FCF_COMPOUNDER','IMPLEMENTED','1.0',
  array['fcf_guidance_fy2026','net_debt','shares_outstanding','revenue_growth_yoy','operating_margin','engagement_growth','content_cash_to_amortization']::text[],
  'PASS','PRODUCTION_V1',
  'Streaming/media cash-flow valuation. Starting cash flow is company-reported annual FCF guidance; content cash spend versus amortization is a normalization sanity diagnostic so accounting content amortization is not treated as economic free cash flow.'
)
on conflict(model_id) do update set
  archetype=excluded.archetype,model_family=excluded.model_family,production_status=excluded.production_status,
  model_version=excluded.model_version,required_metric_ids=excluded.required_metric_ids,
  regression_status=excluded.regression_status,confidence_status=excluded.confidence_status,notes=excluded.notes,updated_at=now();

create or replace function fwios.streaming_fcf_dcf_fv_v1(
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
    when p_growth_y1_5 < -0.10 or p_growth_y1_5 > 0.20 then null
    when p_growth_y6_10 < -0.05 or p_growth_y6_10 > 0.12 then null
    when p_discount_rate < 0.07 or p_discount_rate > 0.14 then null
    when p_terminal_growth < 0 or p_terminal_growth > 0.045 then null
    when p_discount_rate <= p_terminal_growth then null
    else fwios.fcf_compounder_fv(
      p_normalized_fcf_b,-p_net_debt_b,p_shares_m,
      p_growth_y1_5,p_growth_y6_10,p_discount_rate,p_terminal_growth
    )
  end
$$;
revoke execute on function fwios.streaming_fcf_dcf_fv_v1(numeric,numeric,numeric,numeric,numeric,numeric,numeric) from public,anon,authenticated;

insert into fwios.valuation_model_versions(
  version_id,model_id,version_label,status,kernel_family,input_contract,model_policy,assumptions,
  confidence_tier,regression_status,effective_from,source_system,source_ref
) values (
  'STREAMING_FCF_DCF_V1::1.0','STREAMING_FCF_DCF_V1','1.0','PRODUCTION','FCF_COMPOUNDER',
  '{"required_metrics":["fcf_guidance_fy2026","net_debt","shares_outstanding","revenue_growth_yoy","operating_margin","engagement_growth","content_cash_to_amortization"],"normalization_version":"NORM_V1-STREAMING","annual_fcf_guidance_required":true,"material_transaction_review_required":true}'::jsonb,
  '{"method":"10-year equity FCF DCF with explicit net-debt deduction","policy":"STREAMING_FCF_DCF_POLICY_V1","probabilities":"25/50/25","transaction_policy":"signed pending acquisitions must be reflected explicitly; terminated/declined transactions receive zero purchase-price adjustment","starting_fcf_policy":"use company-reported annual FCF guidance or verified normalized annual FCF; do not substitute content amortization or quarterly FCF annualization","scenario_growth_policy":"company-specific and evidence-anchored to revenue growth, operating margin and engagement/monetization evidence","content_accounting_policy":"content cash spend to amortization ratio is a normalization sanity gate, not a hidden valuation uplift"}'::jsonb,
  '{"base_discount":0.09,"bear_discount":0.11,"bull_discount":0.08,"base_growth_y1_5":0.10,"bear_growth_y1_5":0.05,"bull_growth_y1_5":0.13,"base_growth_y6_10":0.05,"bear_growth_y6_10":0.03,"bull_growth_y6_10":0.07,"base_terminal_growth":0.035,"bear_terminal_growth":0.03,"bull_terminal_growth":0.04}'::jsonb,
  'PRODUCTION_V1','PASS','2026-09-11','supabase','STREAMING_VALUATION_CONTRACT_V1'
)
on conflict(version_id) do update set
  status=excluded.status,kernel_family=excluded.kernel_family,input_contract=excluded.input_contract,
  model_policy=excluded.model_policy,assumptions=excluded.assumptions,confidence_tier=excluded.confidence_tier,
  regression_status=excluded.regression_status,effective_from=excluded.effective_from,
  source_system=excluded.source_system,source_ref=excluded.source_ref;
