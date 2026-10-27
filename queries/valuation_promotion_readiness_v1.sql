-- Valuation Promotion Policy v1 current readiness
-- READ ONLY / NON-MUTATING.

select
  ticker,
  model_id,
  model_version_id,
  shadow_run_id,
  promotion_status,
  max_abs_fv_delta,
  current_production_run_id,
  current_production_model_version_id,
  suggested_action,
  blockers,
  review_reasons,
  checks
from fwios.v_valuation_promotion_readiness_v1
order by
  case promotion_status
    when 'BLOCKED' then 1
    when 'MANUAL_REVIEW' then 2
    when 'AUTO_ELIGIBLE' then 3
    else 4
  end,
  ticker,
  model_id;
