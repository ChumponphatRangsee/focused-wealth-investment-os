insert into fwios.metric_definitions(
  metric_code,metric_name,value_kind,canonical_unit,scope_status,decision_uses,description,metadata,active
) values (
  'DILUTED_SHARES','Diluted share denominator','NUMERIC','M shares','DECISION_RELEVANT',
  array['VALUATION'],
  'Fully diluted weighted-average share denominator used for per-share valuation when the model explicitly requires diluted shares; distinct from period-end economic shares outstanding.',
  jsonb_build_object('semantic_version','METRIC_PERIOD_AWARE_V2','share_semantics','DILUTED_WEIGHTED_AVERAGE','period_identity_separate',true),
  true
)
on conflict(metric_code) do update set
  metric_name=excluded.metric_name,
  value_kind=excluded.value_kind,
  canonical_unit=excluded.canonical_unit,
  description=excluded.description,
  metadata=excluded.metadata,
  active=true,
  updated_at=now();

insert into fwios.valuation_model_versions(
  version_id,model_id,version_label,status,kernel_family,input_contract,model_policy,assumptions,
  confidence_tier,regression_status,effective_from,source_system,source_ref,supersedes_version_id
)
select
  'E&P_NORMALIZED_FCF_YIELD_V1::2.0',
  'E&P_NORMALIZED_FCF_YIELD_V1',
  '2.0','EXPERIMENTAL',v.kernel_family,
  jsonb_build_object(
    'contract_version','PERIOD_AWARE_INPUT_V2',
    'resolver_policy','VALUATION_INPUT_RESOLVER_V1',
    'normalization_version','NORM_V2-E&P-PERIOD-AWARE',
    'production_read_cutover',false,
    'required_metrics',jsonb_build_array(
      'FREE_CASH_FLOW','FCF_5Y_MEDIAN','TOTAL_PRODUCTION_MBOED','OIL_PRODUCTION_MBOD',
      'CASH_OPERATING_COST_PER_BOE','NET_DEBT','SHARES_OUTSTANDING'
    ),
    'input_selectors',jsonb_build_array(
      jsonb_build_object('input_key','fcf_prior_fiscal_year','metric_code','FREE_CASH_FLOW','period_type','YEAR','period_rule','LATEST_COMPLETED_FISCAL_YEAR','required',true),
      jsonb_build_object('input_key','fcf_5y_median','metric_code','FCF_5Y_MEDIAN','period_type','YEAR','period_rule','LATEST_AVAILABLE_CYCLE_STATISTIC','required',true),
      jsonb_build_object('input_key','fcf_ltm','metric_code','FREE_CASH_FLOW','period_type','LTM','period_rule','LATEST_REPORTED_LTM','required',true),
      jsonb_build_object('input_key','total_production_mboed','metric_code','TOTAL_PRODUCTION_MBOED','period_type','QUARTER','period_rule','LATEST_REPORTED_QUARTER','required',true),
      jsonb_build_object('input_key','oil_production_mbod','metric_code','OIL_PRODUCTION_MBOD','period_type','QUARTER','period_rule','LATEST_REPORTED_QUARTER','required',true),
      jsonb_build_object('input_key','cash_operating_cost_per_boe','metric_code','CASH_OPERATING_COST_PER_BOE','period_type','QUARTER','period_rule','LATEST_REPORTED_QUARTER','required',true),
      jsonb_build_object('input_key','net_debt','metric_code','NET_DEBT','period_type','QUARTER','period_rule','LATEST_REPORTED_QUARTER','required',true),
      jsonb_build_object('input_key','shares_outstanding','metric_code','SHARES_OUTSTANDING','period_rule','LATEST_FILING_SHARE_COUNT','required',true)
    )
  ),
  jsonb_build_object(
    'policy','RULE_BASED_E&P_V2_PERIOD_AWARE',
    'normalization','FY2026 asset-base guidance × 5Y P25/median/P75 WTI-HH cycle deck + LTM recurring cash bridge',
    'historical_fcf_policy','Resolve latest completed fiscal-year FREE_CASH_FLOW by YEAR metadata; never encode a fiscal year in metric identity.',
    'current_fcf_policy','Use latest reported LTM FREE_CASH_FLOW as the current-cycle cross-check.',
    'operating_inputs_policy','Use latest reported quarter for production, unit cost and net debt diagnostics.',
    'share_policy','Use latest filing economic shares outstanding; do not substitute weighted-average diluted shares.',
    'human_execution_only',true
  ),
  v.assumptions,
  'PREVIEW_ONLY','PASS',date '2026-10-26','FWIOS_PERIOD_SEMANTICS_V2',
  'EOG period-aware contract; production remains PHASE_0_87',v.version_id
from fwios.valuation_model_versions v
where v.version_id='E&P_NORMALIZED_FCF_YIELD_V1@PHASE_0_87'
on conflict(version_id) do nothing;

insert into fwios.valuation_model_versions(
  version_id,model_id,version_label,status,kernel_family,input_contract,model_policy,assumptions,
  confidence_tier,regression_status,effective_from,source_system,source_ref,supersedes_version_id
)
select
  'STREAMING_FCF_DCF_V1::2.0',
  'STREAMING_FCF_DCF_V1',
  '2.0','EXPERIMENTAL',v.kernel_family,
  jsonb_build_object(
    'contract_version','PERIOD_AWARE_INPUT_V2',
    'resolver_policy','VALUATION_INPUT_RESOLVER_V1',
    'normalization_version','NORM_V2-STREAMING-PERIOD-AWARE',
    'production_read_cutover',false,
    'required_metrics',jsonb_build_array(
      'FREE_CASH_FLOW_GUIDANCE','NET_DEBT','DILUTED_SHARES',
      'REVENUE_GROWTH_YOY','OPERATING_MARGIN','CONTENT_CASH_TO_AMORTIZATION'
    ),
    'optional_diagnostics',jsonb_build_array(
      'ENGAGEMENT_GROWTH','FREE_CASH_FLOW','PENDING_ACQUISITION_CONSIDERATION'
    ),
    'input_selectors',jsonb_build_array(
      jsonb_build_object('input_key','fcf_guidance','metric_code','FREE_CASH_FLOW_GUIDANCE','period_type','GUIDANCE','period_rule','CURRENT_FISCAL_YEAR_GUIDANCE','required',true),
      jsonb_build_object('input_key','net_debt','metric_code','NET_DEBT','period_type','QUARTER','period_rule','LATEST_REPORTED_QUARTER','required',true),
      jsonb_build_object('input_key','diluted_shares','metric_code','DILUTED_SHARES','period_type','QUARTER','period_rule','LATEST_REPORTED_QUARTER','required',true),
      jsonb_build_object('input_key','revenue_growth_yoy','metric_code','REVENUE_GROWTH_YOY','period_type','QUARTER','period_rule','LATEST_REPORTED_QUARTER','required',true),
      jsonb_build_object('input_key','operating_margin','metric_code','OPERATING_MARGIN','period_type','QUARTER','period_rule','LATEST_REPORTED_QUARTER','required',true),
      jsonb_build_object('input_key','content_cash_to_amortization','metric_code','CONTENT_CASH_TO_AMORTIZATION','period_type','GUIDANCE','period_rule','CURRENT_FISCAL_YEAR_GUIDANCE','required',true),
      jsonb_build_object('input_key','engagement_growth','metric_code','ENGAGEMENT_GROWTH','period_rule','LATEST_AVAILABLE_ENGAGEMENT_SIGNAL','required',false),
      jsonb_build_object('input_key','free_cash_flow_quarter','metric_code','FREE_CASH_FLOW','period_type','QUARTER','period_rule','LATEST_REPORTED_QUARTER','required',false),
      jsonb_build_object('input_key','pending_acquisition_consideration','metric_code','PENDING_ACQUISITION_CONSIDERATION','period_rule','LATEST_MATERIAL_TRANSACTION_REVIEW','required',false)
    )
  ),
  jsonb_build_object(
    'method','10-year equity FCF DCF with explicit net-debt deduction',
    'policy','STREAMING_FCF_DCF_POLICY_V2_PERIOD_AWARE',
    'probabilities','25/50/25',
    'starting_fcf_policy','Resolve current-fiscal-year FREE_CASH_FLOW_GUIDANCE; never encode fiscal year in metric identity.',
    'share_policy','Use DILUTED_SHARES for the per-share denominator; do not label diluted weighted-average shares as SHARES_OUTSTANDING.',
    'growth_anchor_policy','Latest quarterly revenue growth and operating margin are sanity anchors; long-duration growth remains versioned assumptions.',
    'engagement_policy','Engagement is optional diagnostic unless a future model version defines a stable quantitative global measure.',
    'content_accounting_policy','Current-fiscal-year content cash spend to amortization guidance is a required normalization sanity gate.',
    'transaction_policy','Material pending acquisition consideration must be reviewed explicitly; optional metric is diagnostic and cannot silently alter valuation.',
    'human_execution_only',true
  ),
  v.assumptions,
  'PREVIEW_ONLY','PASS',date '2026-10-26','FWIOS_PERIOD_SEMANTICS_V2',
  'NFLX period-aware contract; production remains 1.0',v.version_id
from fwios.valuation_model_versions v
where v.version_id='STREAMING_FCF_DCF_V1::1.0'
on conflict(version_id) do nothing;

do $$
begin
  if not exists (
    select 1 from fwios.metric_definitions
    where metric_code='DILUTED_SHARES' and active and canonical_unit='M shares'
  ) then raise exception 'DILUTED_SHARES definition missing'; end if;

  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='E&P_NORMALIZED_FCF_YIELD_V1::2.0'
      and status='EXPERIMENTAL'
      and input_contract->>'production_read_cutover'='false'
      and jsonb_array_length(input_contract->'input_selectors')=8
  ) then raise exception 'EOG v2 contract missing/invalid'; end if;

  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='STREAMING_FCF_DCF_V1::2.0'
      and status='EXPERIMENTAL'
      and input_contract->>'production_read_cutover'='false'
      and jsonb_array_length(input_contract->'input_selectors')=9
  ) then raise exception 'NFLX v2 contract missing/invalid'; end if;

  if (select count(*) from fwios.valuation_model_versions
      where model_id='E&P_NORMALIZED_FCF_YIELD_V1' and status='PRODUCTION')<>1 then
    raise exception 'EOG production authority changed'; end if;

  if (select count(*) from fwios.valuation_model_versions
      where model_id='STREAMING_FCF_DCF_V1' and status='PRODUCTION')<>1 then
    raise exception 'NFLX production authority changed'; end if;
end $$;
