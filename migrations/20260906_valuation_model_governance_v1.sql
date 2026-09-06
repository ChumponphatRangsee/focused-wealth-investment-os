-- Valuation model governance registry v1
-- Separates model/version registry from policy regression governance.

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status
)
values(
  'VALUATION_MODEL',
  'VALUATION',
  'Valuation Model Governance',
  'Govern deterministic valuation-model implementation, regression, activation and fail-closed production eligibility without conflating model versions with decision-policy versions.',
  'fwios.valuation_models',
  'ACTIVE'
)
on conflict(policy_key) do update set
  policy_domain=excluded.policy_domain,
  policy_name=excluded.policy_name,
  purpose=excluded.purpose,
  backing_object=excluded.backing_object,
  lifecycle_status=excluded.lifecycle_status,
  updated_at=now();

insert into fwios.policy_versions(
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference,effective_at
)
values(
  'POL-VALUATION-MODEL-GOVERNANCE-V1',
  'VALUATION_MODEL',
  '1.0',
  'ACTIVE',
  true,
  '{
    "model_registry":"fwios.valuation_models",
    "version_registry":"fwios.valuation_model_versions",
    "regression_registry":"fwios.decision_policy_regression_runs",
    "activation_requires_model_specific_regression_pass":true,
    "candidate_specific_valuation_requires_complete_normalized_inputs":true,
    "current_market_price_is_not_a_model_assumption":true,
    "rough_multiples_are_triage_only":true,
    "missing_or_unverified_critical_inputs":"BLOCKED",
    "human_execution_only":true,
    "auto_trade":false
  }'::jsonb,
  'GitHub migrations/20260906_valuation_model_governance_v1.sql',
  now()
)
on conflict(policy_version_id) do update set
  policy_key=excluded.policy_key,
  version=excluded.version,
  lifecycle_status=excluded.lifecycle_status,
  deterministic_scoring=excluded.deterministic_scoring,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;