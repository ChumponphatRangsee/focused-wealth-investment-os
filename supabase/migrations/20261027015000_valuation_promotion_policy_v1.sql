insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status
) values (
  'VALUATION_PROMOTION',
  'VALUATION',
  'Valuation Model Promotion v1',
  'Deterministically evaluate whether a validated non-production valuation-model shadow run is eligible for one-step human-approved promotion, needs manual review, or is blocked.',
  'fwios.preview_valuation_promotion_v1 / fwios.v_valuation_promotion_readiness_v1',
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
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,
  config,source_reference,effective_at
) values (
  'POL-VALUATION-PROMOTION-V1',
  'VALUATION_PROMOTION',
  '1.0',
  'ACTIVE',
  true,
  jsonb_build_object(
    'result_states',jsonb_build_array('AUTO_ELIGIBLE','MANUAL_REVIEW','BLOCKED'),
    'required_input_pass_ratio',1.0,
    'required_source_tier','A',
    'required_verification_status','VERIFIED',
    'accepted_no_conflict_statuses',jsonb_build_array('NO','NO_CONFLICT'),
    'require_metric_quality_pass',true,
    'require_complete_metric_lineage',true,
    'require_single_production_version',true,
    'require_supersedes_current_production',true,
    'require_regression_pass',true,
    'auto_eligible_max_abs_fv_delta',0.15,
    'manual_review_high_delta',0.30,
    'require_same_kernel_for_auto_eligible',true,
    'auto_apply',false,
    'human_cutover_required',true,
    'portfolio_mutation',false,
    'auto_trade',false,
    'note','AUTO_ELIGIBLE means ready for one-step explicit human-approved promotion. It never performs cutover by itself.'
  ),
  'GitHub valuation promotion policy v1',
  timestamptz '2026-10-27 01:45:00+00'
)
on conflict(policy_version_id) do update set
  lifecycle_status=excluded.lifecycle_status,
  deterministic_scoring=excluded.deterministic_scoring,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

create or replace function fwios.preview_valuation_promotion_v1(p_shadow_run_id text)
returns jsonb
language plpgsql
stable
security invoker
set search_path = pg_catalog, fwios
as $$
declare
  v_policy jsonb;
  v_shadow fwios.valuation_runs%rowtype;
  v_shadow_version fwios.valuation_model_versions%rowtype;
  v_prod fwios.valuation_runs%rowtype;
  v_prod_version fwios.valuation_model_versions%rowtype;
  v_dashboard_run_id text;

  v_required_count integer := 0;
  v_required_pass integer := 0;
  v_required_evidence_pass integer := 0;
  v_input_count integer := 0;
  v_lineage_count integer := 0;
  v_production_version_count integer := 0;

  v_bear_delta numeric;
  v_base_delta numeric;
  v_bull_delta numeric;
  v_pw_delta numeric;
  v_max_delta numeric;
  v_auto_delta_threshold numeric;
  v_high_delta_threshold numeric;

  v_same_kernel boolean := false;
  v_supersedes_ok boolean := false;
  v_shadow_gates_pass boolean := false;
  v_shadow_no_cutover boolean := false;
  v_no_auto_trade boolean := false;

  v_blockers text[] := array[]::text[];
  v_review_reasons text[] := array[]::text[];
  v_status text;
begin
  select config
    into v_policy
  from fwios.policy_versions
  where policy_version_id='POL-VALUATION-PROMOTION-V1'
    and lifecycle_status='ACTIVE';

  if v_policy is null then
    return jsonb_build_object(
      'policy_version_id','POL-VALUATION-PROMOTION-V1',
      'shadow_run_id',p_shadow_run_id,
      'promotion_status','BLOCKED',
      'blockers',jsonb_build_array('POLICY_NOT_ACTIVE'),
      'auto_apply',false,
      'human_cutover_required',true,
      'production_changes','NONE'
    );
  end if;

  v_auto_delta_threshold := (v_policy->>'auto_eligible_max_abs_fv_delta')::numeric;
  v_high_delta_threshold := (v_policy->>'manual_review_high_delta')::numeric;

  select *
    into v_shadow
  from fwios.valuation_runs
  where run_id=p_shadow_run_id;

  if not found then
    return jsonb_build_object(
      'policy_version_id','POL-VALUATION-PROMOTION-V1',
      'shadow_run_id',p_shadow_run_id,
      'promotion_status','BLOCKED',
      'blockers',jsonb_build_array('SHADOW_RUN_NOT_FOUND'),
      'auto_apply',false,
      'human_cutover_required',true,
      'production_changes','NONE'
    );
  end if;

  if v_shadow.production_eligible then
    v_blockers := array_append(v_blockers,'RUN_ALREADY_PRODUCTION_ELIGIBLE');
  end if;

  select *
    into v_shadow_version
  from fwios.valuation_model_versions
  where version_id=v_shadow.model_version_id;

  if not found then
    v_blockers := array_append(v_blockers,'SHADOW_MODEL_VERSION_NOT_FOUND');
  else
    if v_shadow_version.status <> 'EXPERIMENTAL' then
      v_blockers := array_append(v_blockers,'SHADOW_VERSION_NOT_EXPERIMENTAL');
    end if;
    if v_shadow_version.regression_status <> 'PASS' then
      v_blockers := array_append(v_blockers,'MODEL_REGRESSION_NOT_PASS');
    end if;
    v_shadow_no_cutover := coalesce(v_shadow_version.input_contract->>'production_read_cutover','')='false';
    if not v_shadow_no_cutover then
      v_blockers := array_append(v_blockers,'SHADOW_VERSION_CUTOVER_FLAG_NOT_FALSE');
    end if;
  end if;

  select d.valuation_run_id
    into v_dashboard_run_id
  from fwios.v_dashboard_valuation_map d
  where d.ticker=v_shadow.ticker;

  if v_dashboard_run_id is null then
    v_blockers := array_append(v_blockers,'CURRENT_PRODUCTION_DASHBOARD_RUN_NOT_FOUND');
  else
    select *
      into v_prod
    from fwios.valuation_runs
    where run_id=v_dashboard_run_id;

    if not found then
      v_blockers := array_append(v_blockers,'CURRENT_PRODUCTION_RUN_NOT_FOUND');
    else
      if not v_prod.production_eligible then
        v_blockers := array_append(v_blockers,'DASHBOARD_RUN_NOT_PRODUCTION_ELIGIBLE');
      end if;
      if v_prod.model_id is distinct from v_shadow.model_id then
        v_blockers := array_append(v_blockers,'PRODUCTION_MODEL_ID_MISMATCH');
      end if;

      select *
        into v_prod_version
      from fwios.valuation_model_versions
      where version_id=v_prod.model_version_id;

      if not found then
        v_blockers := array_append(v_blockers,'PRODUCTION_MODEL_VERSION_NOT_FOUND');
      end if;
    end if;
  end if;

  select count(*) filter(where status='PRODUCTION')
    into v_production_version_count
  from fwios.valuation_model_versions
  where model_id=v_shadow.model_id;

  if v_production_version_count <> 1 then
    v_blockers := array_append(v_blockers,'PRODUCTION_VERSION_AUTHORITY_NOT_SINGULAR');
  end if;

  if v_shadow_version.version_id is not null and v_prod.model_version_id is not null then
    v_supersedes_ok := v_shadow_version.supersedes_version_id = v_prod.model_version_id;
    if not v_supersedes_ok then
      v_blockers := array_append(v_blockers,'SHADOW_DOES_NOT_SUPERSEDE_CURRENT_PRODUCTION_VERSION');
    end if;
  end if;

  select
    count(*),
    count(*) filter(where required),
    count(*) filter(where required and gate_status='PASS')
  into v_input_count,v_required_count,v_required_pass
  from fwios.valuation_run_inputs
  where run_id=p_shadow_run_id;

  if v_required_count = 0 then
    v_blockers := array_append(v_blockers,'NO_REQUIRED_INPUTS_RECORDED');
  elsif v_required_pass <> v_required_count then
    v_blockers := array_append(v_blockers,'REQUIRED_INPUTS_NOT_100_PERCENT_PASS');
  end if;

  select count(*)
    into v_required_evidence_pass
  from fwios.valuation_run_inputs i
  join fwios.metric_observations o
    on o.observation_key=i.source_key
  join fwios.evidence_records e
    on e.evidence_id=o.primary_evidence_id
  where i.run_id=p_shadow_run_id
    and i.required=true
    and i.gate_status='PASS'
    and o.provenance_status='PASS'
    and o.quality_gate='PASS'
    and e.source_tier=(v_policy->>'required_source_tier')
    and e.verification_status=(v_policy->>'required_verification_status')
    and e.machine_status='PASS'
    and e.conflict_status in ('NO','NO_CONFLICT');

  if v_required_evidence_pass <> v_required_count then
    v_blockers := array_append(v_blockers,'REQUIRED_INPUT_EVIDENCE_NOT_ALL_TIER_A_VERIFIED_CONFLICT_FREE');
  end if;

  select count(*)
    into v_lineage_count
  from fwios.v_lineage_edges_resolved
  where to_object_key=p_shadow_run_id
    and edge_type='METRIC_INPUT_TO_VALUATION';

  if v_lineage_count < v_input_count then
    v_blockers := array_append(v_blockers,'INCOMPLETE_METRIC_INPUT_LINEAGE');
  end if;

  v_shadow_gates_pass :=
    coalesce(v_shadow.valuation_readiness,'')='PASS'
    and coalesce(v_shadow.router_gate,'')='PASS'
    and coalesce(v_shadow.valuation_gate,'')='PASS'
    and coalesce(v_shadow.schema_gate,'')='PASS';

  if not v_shadow_gates_pass then
    v_blockers := array_append(v_blockers,'SHADOW_VALUATION_GATES_NOT_ALL_PASS');
  end if;

  v_no_auto_trade :=
    not coalesce((v_shadow.raw_payload->>'auto_trade')::boolean,false)
    and not coalesce((v_shadow.raw_payload->>'production_cutover')::boolean,false);

  if not v_no_auto_trade then
    v_blockers := array_append(v_blockers,'SHADOW_RUN_MUTATION_BOUNDARY_INVALID');
  end if;

  if v_prod.run_id is not null then
    if v_shadow.bear_fv_per_share is null
       or v_shadow.base_fv_per_share is null
       or v_shadow.bull_fv_per_share is null
       or v_shadow.probability_weighted_fv_per_share is null
       or v_prod.bear_fv_per_share is null
       or v_prod.base_fv_per_share is null
       or v_prod.bull_fv_per_share is null
       or v_prod.probability_weighted_fv_per_share is null
       or v_prod.bear_fv_per_share=0
       or v_prod.base_fv_per_share=0
       or v_prod.bull_fv_per_share=0
       or v_prod.probability_weighted_fv_per_share=0
    then
      v_blockers := array_append(v_blockers,'FAIR_VALUE_COMPARISON_INCOMPLETE');
    else
      v_bear_delta := abs(v_shadow.bear_fv_per_share/v_prod.bear_fv_per_share-1);
      v_base_delta := abs(v_shadow.base_fv_per_share/v_prod.base_fv_per_share-1);
      v_bull_delta := abs(v_shadow.bull_fv_per_share/v_prod.bull_fv_per_share-1);
      v_pw_delta := abs(v_shadow.probability_weighted_fv_per_share/v_prod.probability_weighted_fv_per_share-1);
      v_max_delta := greatest(v_bear_delta,v_base_delta,v_bull_delta,v_pw_delta);
    end if;
  end if;

  if v_shadow_version.version_id is not null and v_prod_version.version_id is not null then
    v_same_kernel := v_shadow_version.kernel_family is not distinct from v_prod_version.kernel_family;
    if not v_same_kernel then
      v_review_reasons := array_append(v_review_reasons,'KERNEL_FAMILY_CHANGED');
    end if;
  end if;

  if v_max_delta is not null and v_max_delta > v_auto_delta_threshold then
    v_review_reasons := array_append(v_review_reasons,'FAIR_VALUE_DELTA_ABOVE_AUTO_THRESHOLD');
  end if;

  if v_max_delta is not null and v_max_delta > v_high_delta_threshold then
    v_review_reasons := array_append(v_review_reasons,'FAIR_VALUE_DELTA_HIGH');
  end if;

  if cardinality(v_blockers) > 0 then
    v_status := 'BLOCKED';
  elsif v_same_kernel and v_max_delta <= v_auto_delta_threshold then
    v_status := 'AUTO_ELIGIBLE';
  else
    v_status := 'MANUAL_REVIEW';
  end if;

  return jsonb_build_object(
    'policy_version_id','POL-VALUATION-PROMOTION-V1',
    'promotion_status',v_status,
    'ticker',v_shadow.ticker,
    'model_id',v_shadow.model_id,
    'shadow_run_id',v_shadow.run_id,
    'shadow_model_version_id',v_shadow.model_version_id,
    'current_production_run_id',v_prod.run_id,
    'current_production_model_version_id',v_prod.model_version_id,
    'rollback_run_id',v_prod.run_id,
    'rollback_model_version_id',v_prod.model_version_id,
    'checks',jsonb_build_object(
      'shadow_non_production',not v_shadow.production_eligible,
      'shadow_version_experimental',coalesce(v_shadow_version.status='EXPERIMENTAL',false),
      'model_regression_pass',coalesce(v_shadow_version.regression_status='PASS',false),
      'production_read_cutover_false',v_shadow_no_cutover,
      'single_production_version',v_production_version_count=1,
      'supersedes_current_production',v_supersedes_ok,
      'required_inputs_pass',v_required_pass=v_required_count and v_required_count>0,
      'required_inputs',v_required_count,
      'required_inputs_pass_count',v_required_pass,
      'required_tier_a_verified_conflict_free',v_required_evidence_pass=v_required_count and v_required_count>0,
      'required_evidence_pass_count',v_required_evidence_pass,
      'all_input_lineage_complete',v_lineage_count>=v_input_count,
      'input_count',v_input_count,
      'lineage_edge_count',v_lineage_count,
      'valuation_gates_pass',v_shadow_gates_pass,
      'same_kernel_family',v_same_kernel,
      'mutation_boundary_safe',v_no_auto_trade
    ),
    'fair_value_delta',jsonb_build_object(
      'bear_abs_pct',v_bear_delta,
      'base_abs_pct',v_base_delta,
      'bull_abs_pct',v_bull_delta,
      'probability_weighted_abs_pct',v_pw_delta,
      'max_abs_pct',v_max_delta,
      'auto_eligible_threshold',v_auto_delta_threshold,
      'manual_review_high_delta_threshold',v_high_delta_threshold
    ),
    'blockers',to_jsonb(v_blockers),
    'review_reasons',to_jsonb(v_review_reasons),
    'auto_apply',false,
    'human_cutover_required',true,
    'suggested_action',
      case v_status
        when 'AUTO_ELIGIBLE' then 'READY_FOR_ONE_STEP_EXPLICIT_PROMOTION'
        when 'MANUAL_REVIEW' then 'REVIEW_DELTA_OR_METHOD_CHANGE_BEFORE_PROMOTION'
        else 'FIX_BLOCKERS_BEFORE_PROMOTION'
      end,
    'production_changes','NONE',
    'auto_trade',false
  );
end;
$$;

create or replace view fwios.v_valuation_promotion_readiness_v1
with (security_invoker=true)
as
with candidates as (
  select distinct on (r.ticker,r.model_id)
    r.run_id,r.ticker,r.model_id,r.model_version_id,r.created_at
  from fwios.valuation_runs r
  join fwios.valuation_model_versions v
    on v.version_id=r.model_version_id
  where r.production_eligible=false
    and v.status='EXPERIMENTAL'
  order by r.ticker,r.model_id,r.created_at desc
),
evaluated as (
  select c.*,fwios.preview_valuation_promotion_v1(c.run_id) result
  from candidates c
)
select
  ticker,
  model_id,
  model_version_id,
  run_id as shadow_run_id,
  result->>'promotion_status' as promotion_status,
  (result->'fair_value_delta'->>'max_abs_pct')::numeric as max_abs_fv_delta,
  result->>'current_production_run_id' as current_production_run_id,
  result->>'current_production_model_version_id' as current_production_model_version_id,
  result->>'suggested_action' as suggested_action,
  result->'blockers' as blockers,
  result->'review_reasons' as review_reasons,
  result->'checks' as checks,
  result
from evaluated;

revoke all on function fwios.preview_valuation_promotion_v1(text) from public;
