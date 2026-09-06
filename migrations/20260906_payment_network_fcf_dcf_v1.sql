-- Payment Network valuation model v1
-- Runtime evidence, market prices and candidate-specific valuation snapshots are state and are intentionally not hard-coded here.

create or replace function fwios.payment_network_fcf_dcf_fv_v1(
  p_starting_fcf_b numeric,
  p_net_cash_b numeric,
  p_shares_m numeric,
  p_growth_y1_5 numeric,
  p_growth_y6_10 numeric,
  p_discount_rate numeric,
  p_terminal_growth numeric
) returns numeric
language sql
immutable
strict
security invoker
set search_path=pg_catalog,fwios
as $$
  select case
    when p_starting_fcf_b <= 0 then null
    when p_shares_m <= 0 then null
    when p_growth_y1_5 < -0.25 or p_growth_y1_5 > 0.30 then null
    when p_growth_y6_10 < -0.10 or p_growth_y6_10 > 0.20 then null
    when p_discount_rate < 0.06 or p_discount_rate > 0.15 then null
    when p_terminal_growth < 0 or p_terminal_growth > 0.05 then null
    when p_discount_rate <= p_terminal_growth then null
    else fwios.fcf_compounder_fv(
      p_starting_fcf_b,
      p_net_cash_b,
      p_shares_m,
      p_growth_y1_5,
      p_growth_y6_10,
      p_discount_rate,
      p_terminal_growth
    )
  end
$$;

revoke execute on function fwios.payment_network_fcf_dcf_fv_v1(numeric,numeric,numeric,numeric,numeric,numeric,numeric)
from public,anon,authenticated;

insert into fwios.valuation_model_versions(
  version_id,model_id,version_label,status,kernel_family,input_contract,model_policy,assumptions,
  confidence_tier,regression_status,effective_from,source_system,source_ref
)
values(
  'PAYMENT_NETWORK_FCF_DCF_V1::1.0',
  'PAYMENT_NETWORK_FCF_DCF_V1',
  '1.0',
  'EXPERIMENTAL',
  'FCF_COMPOUNDER',
  '{
    "required_metrics":["payments_volume_growth","cross_border_growth","take_rate","operating_margin","fcf_ltm","net_cash","shares_outstanding"],
    "normalization_version":"NORM_V1-PAYNET",
    "required_source_tier":"A",
    "current_market_price_required_for_mispricing":true,
    "market_price_is_not_model_assumption":true
  }'::jsonb,
  '{
    "policy":"PAYMENT_NETWORK_FCF_DCF_POLICY_V1",
    "method":"10-year equity FCF compounder DCF with explicit growth decay and terminal value",
    "probabilities":{"bear":0.25,"base":0.50,"bull":0.25},
    "starting_fcf_definition":"LTM operating cash flow minus purchases of property, equipment and technology; annual + current YTD - prior YTD bridge when necessary",
    "net_cash_definition":"unrestricted cash plus marketable investment securities minus carrying debt; restricted litigation escrow and customer collateral excluded",
    "share_definition":"latest diluted/as-converted Class A equivalent share count suitable for per-share valuation",
    "take_rate_role":"economic sanity check; not an independent fair-value shortcut",
    "operating_margin_role":"quality/economic sanity check; not a substitute for FCF",
    "rough_multiple_role":"TRIAGE_ONLY_NOT_VALUATION",
    "facts_assumptions_separated":true,
    "auto_trade":false
  }'::jsonb,
  '{
    "bear":{"growth_y1_5":0.07,"growth_y6_10":0.04,"discount_rate":0.10,"terminal_growth":0.03},
    "base":{"growth_y1_5":0.10,"growth_y6_10":0.06,"discount_rate":0.09,"terminal_growth":0.035},
    "bull":{"growth_y1_5":0.12,"growth_y6_10":0.08,"discount_rate":0.0825,"terminal_growth":0.04},
    "assumption_rationale":"Near-term growth is anchored below/around verified payment-network operating growth and explicitly decays over years 6-10; discount rates retain a material premium over the current risk-free backdrop."
  }'::jsonb,
  'EXPERIMENTAL_V1',
  'NOT_RUN',
  '2026-09-06',
  'github',
  'PAYMENT_NETWORK_VALUATION_V1'
)
on conflict(version_id) do update set
  status=excluded.status,
  kernel_family=excluded.kernel_family,
  input_contract=excluded.input_contract,
  model_policy=excluded.model_policy,
  assumptions=excluded.assumptions,
  confidence_tier=excluded.confidence_tier,
  regression_status=excluded.regression_status,
  effective_from=excluded.effective_from,
  source_system=excluded.source_system,
  source_ref=excluded.source_ref;

update fwios.valuation_models
set production_status='CONFIGURED_NOT_IMPLEMENTED',
    model_version='1.0',
    regression_status='NOT_RUN',
    confidence_status='EXPERIMENTAL_V1',
    notes='Payment Network FCF DCF implementation installed in experimental state; activation requires deterministic regression PASS.',
    updated_at=now()
where model_id='PAYMENT_NETWORK_FCF_DCF_V1';