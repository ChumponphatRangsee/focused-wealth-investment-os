-- Valuation Promotion Policy v1 regression
-- Post-cutover lifecycle regression. Non-mutating: apply calls are idempotent NOOPs.

do $$
declare
  r jsonb;
begin
  -- T01 active policy remains human-gated and never auto-trades.
  if not exists (
    select 1
    from fwios.policy_versions
    where policy_version_id='POL-VALUATION-PROMOTION-V1'
      and lifecycle_status='ACTIVE'
      and deterministic_scoring=true
      and (config->>'auto_apply')::boolean=false
      and (config->>'human_cutover_required')::boolean=true
      and (config->>'auto_trade')::boolean=false
      and config->>'apply_function'='fwios.apply_valuation_promotion_v1'
      and config->>'rollback_function'='fwios.rollback_valuation_promotion_v1'
  ) then raise exception 'T01 promotion policy missing or unsafe'; end if;

  -- T02 unknown shadow run fails closed.
  r := fwios.preview_valuation_promotion_v1('DOES-NOT-EXIST');
  if r->>'promotion_status'<>'BLOCKED'
     or not (r->'blockers') ? 'SHADOW_RUN_NOT_FOUND'
  then raise exception 'T02 unknown run did not fail closed: %',r; end if;

  -- T03-T05 promoted shadows are no longer preview-eligible because v2 is now production.
  r := fwios.preview_valuation_promotion_v1('VAL-SHADOW-ACN-ITSERV-V2-20261026');
  if r->>'promotion_status'<>'BLOCKED' then raise exception 'T03 ACN promoted shadow should be blocked from re-preview: %',r; end if;
  r := fwios.preview_valuation_promotion_v1('VAL-SHADOW-EOG-EP-V2-20261026');
  if r->>'promotion_status'<>'BLOCKED' then raise exception 'T04 EOG promoted shadow should be blocked from re-preview: %',r; end if;
  r := fwios.preview_valuation_promotion_v1('VAL-SHADOW-NFLX-STREAM-V2-20261026');
  if r->>'promotion_status'<>'BLOCKED' then raise exception 'T05 NFLX promoted shadow should be blocked from re-preview: %',r; end if;

  -- T06 exact re-apply is idempotent for all promoted shadows.
  r := fwios.apply_valuation_promotion_v1('VAL-SHADOW-ACN-ITSERV-V2-20261026');
  if r->>'status'<>'NOOP_ALREADY_PROMOTED' then raise exception 'T06 ACN apply idempotency failed: %',r; end if;
  r := fwios.apply_valuation_promotion_v1('VAL-SHADOW-EOG-EP-V2-20261026');
  if r->>'status'<>'NOOP_ALREADY_PROMOTED' then raise exception 'T06 EOG apply idempotency failed: %',r; end if;
  r := fwios.apply_valuation_promotion_v1('VAL-SHADOW-NFLX-STREAM-V2-20261026');
  if r->>'status'<>'NOOP_ALREADY_PROMOTED' then raise exception 'T06 NFLX apply idempotency failed: %',r; end if;

  -- T07 no current experimental promotion candidate remains for the three cut-over routes.
  if exists (
    select 1 from fwios.v_valuation_promotion_readiness_v1
    where ticker in ('ACN','EOG','NFLX')
  ) then raise exception 'T07 promoted models still appear in experimental readiness view'; end if;

  -- T08 production model authority is v2 and singular.
  if exists (
    select model_id
    from fwios.valuation_model_versions
    where model_id in (
      'IT_SERVICES_FCF_COMPOUNDER_V1',
      'E&P_NORMALIZED_FCF_YIELD_V1',
      'STREAMING_FCF_DCF_V1'
    )
    group by model_id
    having count(*) filter(where status='PRODUCTION')<>1
       or not bool_or(status='PRODUCTION' and version_label='2.0')
  ) then raise exception 'T08 v2 production authority invalid'; end if;

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
  ) then raise exception 'T09 shadow run promoted in place'; end if;

  -- T10 service-role-only preview/apply/rollback and readiness view.
  if has_function_privilege('public','fwios.preview_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('anon','fwios.preview_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('authenticated','fwios.preview_valuation_promotion_v1(text)','EXECUTE')
     or not has_function_privilege('service_role','fwios.preview_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('public','fwios.apply_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('anon','fwios.apply_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('authenticated','fwios.apply_valuation_promotion_v1(text)','EXECUTE')
     or not has_function_privilege('service_role','fwios.apply_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('public','fwios.rollback_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('anon','fwios.rollback_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('authenticated','fwios.rollback_valuation_promotion_v1(text)','EXECUTE')
     or not has_function_privilege('service_role','fwios.rollback_valuation_promotion_v1(text)','EXECUTE')
     or has_table_privilege('public','fwios.v_valuation_promotion_readiness_v1','SELECT')
     or has_table_privilege('anon','fwios.v_valuation_promotion_readiness_v1','SELECT')
     or has_table_privilege('authenticated','fwios.v_valuation_promotion_readiness_v1','SELECT')
     or not has_table_privilege('service_role','fwios.v_valuation_promotion_readiness_v1','SELECT')
  then raise exception 'T10 promotion access boundary invalid'; end if;

  -- T11 production runs are explicitly human-only/no-auto-trade.
  if (select count(*) from fwios.valuation_runs
      where run_id in (
        'VAL-PROD-ACN-ITSERV-V2-20261026',
        'VAL-PROD-EOG-EP-V2-20261026',
        'VAL-PROD-NFLX-STREAM-V2-20261026'
      )
        and production_eligible=true
        and raw_payload->>'promotion_policy_id'='POL-VALUATION-PROMOTION-V1'
        and raw_payload->>'auto_trade'='false'
        and raw_payload->>'human_execution_only'='true')<>3
  then raise exception 'T11 promoted run safety metadata invalid'; end if;

  -- T12 Dashboard is on the promoted v2 production runs.
  if not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='ACN' and valuation_run_id='VAL-PROD-ACN-ITSERV-V2-20261026'
  ) or not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='EOG' and valuation_run_id='VAL-PROD-EOG-EP-V2-20261026'
  ) or not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='NFLX' and valuation_run_id='VAL-PROD-NFLX-STREAM-V2-20261026'
  ) then raise exception 'T12 Dashboard not on promoted v2 runs'; end if;
end $$;

select 'FWIOS VALUATION PROMOTION POLICY V1: PASS (12/12, POST-CUTOVER)' result;
