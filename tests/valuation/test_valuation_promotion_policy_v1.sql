-- Valuation Promotion Policy v1 regression
-- The policy is non-mutating. The test verifies current eligible candidates plus fail-closed behavior.

do $$
declare
  r jsonb;
begin
  -- T01 active policy exists and cannot auto-apply.
  if not exists (
    select 1
    from fwios.policy_versions
    where policy_version_id='POL-VALUATION-PROMOTION-V1'
      and lifecycle_status='ACTIVE'
      and deterministic_scoring=true
      and (config->>'auto_apply')::boolean=false
      and (config->>'human_cutover_required')::boolean=true
      and (config->>'auto_trade')::boolean=false
  ) then raise exception 'T01 promotion policy missing or unsafe'; end if;

  -- T02 unknown shadow run fails closed.
  r := fwios.preview_valuation_promotion_v1('DOES-NOT-EXIST');
  if r->>'promotion_status'<>'BLOCKED'
     or not (r->'blockers') ? 'SHADOW_RUN_NOT_FOUND'
  then raise exception 'T02 unknown run did not fail closed: %',r; end if;

  -- T03 ACN is AUTO_ELIGIBLE.
  r := fwios.preview_valuation_promotion_v1('VAL-SHADOW-ACN-ITSERV-V2-20261026');
  if r->>'promotion_status'<>'AUTO_ELIGIBLE'
     or jsonb_array_length(r->'blockers')<>0
     or (r->'fair_value_delta'->>'max_abs_pct')::numeric > 0.15
  then raise exception 'T03 ACN eligibility failed: %',r; end if;

  -- T04 EOG is AUTO_ELIGIBLE.
  r := fwios.preview_valuation_promotion_v1('VAL-SHADOW-EOG-EP-V2-20261026');
  if r->>'promotion_status'<>'AUTO_ELIGIBLE'
     or jsonb_array_length(r->'blockers')<>0
     or (r->'fair_value_delta'->>'max_abs_pct')::numeric > 0.15
  then raise exception 'T04 EOG eligibility failed: %',r; end if;

  -- T05 NFLX is AUTO_ELIGIBLE.
  r := fwios.preview_valuation_promotion_v1('VAL-SHADOW-NFLX-STREAM-V2-20261026');
  if r->>'promotion_status'<>'AUTO_ELIGIBLE'
     or jsonb_array_length(r->'blockers')<>0
     or (r->'fair_value_delta'->>'max_abs_pct')::numeric > 0.15
  then raise exception 'T05 NFLX eligibility failed: %',r; end if;

  -- T06 required inputs are 100% PASS for all three.
  if exists (
    select 1
    from fwios.v_valuation_promotion_readiness_v1
    where ticker in ('ACN','EOG','NFLX')
      and (
        (checks->>'required_inputs_pass')::boolean is distinct from true
        or (checks->>'required_tier_a_verified_conflict_free')::boolean is distinct from true
      )
  ) then raise exception 'T06 required input/evidence gate failed'; end if;

  -- T07 complete input lineage for all three.
  if exists (
    select 1
    from fwios.v_valuation_promotion_readiness_v1
    where ticker in ('ACN','EOG','NFLX')
      and (checks->>'all_input_lineage_complete')::boolean is distinct from true
  ) then raise exception 'T07 lineage gate failed'; end if;

  -- T08 production dashboard still points at pre-v2 runs.
  if not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='ACN' and valuation_run_id='VAL-SUPA-ACN-ITSERV-20260905'
  ) or not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='EOG' and valuation_run_id='VAL-EOG-20260904-P087'
  ) or not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='NFLX' and valuation_run_id='VAL-NFLX-STREAM-20260911'
  ) then raise exception 'T08 production dashboard changed unexpectedly'; end if;

  -- T09 shadow runs remain non-production.
  if exists (
    select 1
    from fwios.valuation_runs
    where run_id in (
      'VAL-SHADOW-ACN-ITSERV-V2-20261026',
      'VAL-SHADOW-EOG-EP-V2-20261026',
      'VAL-SHADOW-NFLX-STREAM-V2-20261026'
    )
      and production_eligible=true
  ) then raise exception 'T09 shadow run promoted unexpectedly'; end if;

  -- T10 preview function is not public/anon/authenticated executable.
  if has_function_privilege('public','fwios.preview_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('anon','fwios.preview_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('authenticated','fwios.preview_valuation_promotion_v1(text)','EXECUTE')
     or not has_function_privilege('service_role','fwios.preview_valuation_promotion_v1(text)','EXECUTE')
  then raise exception 'T10 preview function privilege boundary invalid'; end if;

  -- T11 readiness view is not public/anon/authenticated readable and is service-role readable.
  if has_table_privilege('public','fwios.v_valuation_promotion_readiness_v1','SELECT')
     or has_table_privilege('anon','fwios.v_valuation_promotion_readiness_v1','SELECT')
     or has_table_privilege('authenticated','fwios.v_valuation_promotion_readiness_v1','SELECT')
     or not has_table_privilege('service_role','fwios.v_valuation_promotion_readiness_v1','SELECT')
  then raise exception 'T11 readiness view privilege boundary invalid'; end if;

  -- T12 preview is explicitly non-mutating/human-cutover only.
  if exists (
    select 1
    from fwios.v_valuation_promotion_readiness_v1
    where ticker in ('ACN','EOG','NFLX')
      and (
        result->>'production_changes' <> 'NONE'
        or (result->>'auto_apply')::boolean is distinct from false
        or (result->>'human_cutover_required')::boolean is distinct from true
        or (result->>'auto_trade')::boolean is distinct from false
      )
  ) then raise exception 'T12 mutation boundary failed'; end if;
end $$;

select 'FWIOS VALUATION PROMOTION POLICY V1: PASS (12/12, NON-MUTATING)' result;
