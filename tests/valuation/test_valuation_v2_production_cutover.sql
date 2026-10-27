-- FWIOS valuation v2 production cutover regression
-- Live assertions + rollback dry-run. Final state remains v2 because rollback section is rolled back.

do $$
declare
  r jsonb;
begin
  -- T01: all three v2 model versions are sole production authorities.
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
  ) then raise exception 'T01 production version authority invalid'; end if;

  -- T02: old versions are retained but retired.
  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='IT_SERVICES_FCF_COMPOUNDER_V1::1.0' and status='RETIRED'
  ) or not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='E&P_NORMALIZED_FCF_YIELD_V1@PHASE_0_87' and status='RETIRED'
  ) or not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='STREAMING_FCF_DCF_V1::1.0' and status='RETIRED'
  ) then raise exception 'T02 rollback model versions not retained/retired'; end if;

  -- T03: registry points to semantic v2.
  if (select count(*) from fwios.valuation_models
      where model_id in (
        'IT_SERVICES_FCF_COMPOUNDER_V1',
        'E&P_NORMALIZED_FCF_YIELD_V1',
        'STREAMING_FCF_DCF_V1'
      )
        and model_version='2.0'
        and regression_status='PASS'
        and confidence_status='PRODUCTION_V2')<>3
  then raise exception 'T03 model registry not aligned to v2'; end if;

  -- T04: promoted production runs exist and remain production eligible.
  if (select count(*) from fwios.valuation_runs
      where run_id in (
        'VAL-PROD-ACN-ITSERV-V2-20261026',
        'VAL-PROD-EOG-EP-V2-20261026',
        'VAL-PROD-NFLX-STREAM-V2-20261026'
      )
        and production_eligible=true
        and raw_payload->>'promotion_policy_id'='POL-VALUATION-PROMOTION-V1'
        and raw_payload->>'production_cutover'='true'
        and raw_payload->>'auto_trade'='false')<>3
  then raise exception 'T04 production run metadata invalid'; end if;

  -- T05: production Fair Values exactly match approved shadows.
  if exists (
    select 1
    from (values
      ('VAL-PROD-ACN-ITSERV-V2-20261026','VAL-SHADOW-ACN-ITSERV-V2-20261026'),
      ('VAL-PROD-EOG-EP-V2-20261026','VAL-SHADOW-EOG-EP-V2-20261026'),
      ('VAL-PROD-NFLX-STREAM-V2-20261026','VAL-SHADOW-NFLX-STREAM-V2-20261026')
    ) x(prod_id,shadow_id)
    join fwios.valuation_runs p on p.run_id=x.prod_id
    join fwios.valuation_runs s on s.run_id=x.shadow_id
    where p.bear_fv_per_share is distinct from s.bear_fv_per_share
       or p.base_fv_per_share is distinct from s.base_fv_per_share
       or p.bull_fv_per_share is distinct from s.bull_fv_per_share
       or p.probability_weighted_fv_per_share is distinct from s.probability_weighted_fv_per_share
  ) then raise exception 'T05 production/shadow Fair Value parity failed'; end if;

  -- T06: shadow runs remain non-production and unchanged as approval artifacts.
  if exists (
    select 1 from fwios.valuation_runs
    where run_id in (
      'VAL-SHADOW-ACN-ITSERV-V2-20261026',
      'VAL-SHADOW-EOG-EP-V2-20261026',
      'VAL-SHADOW-NFLX-STREAM-V2-20261026'
    )
      and production_eligible=true
  ) then raise exception 'T06 shadow eligibility boundary violated'; end if;

  -- T07: input-lineage parity was preserved in production.
  if (select count(*) from fwios.v_lineage_edges_resolved
      where to_object_key='VAL-PROD-ACN-ITSERV-V2-20261026')<>10
     or (select count(*) from fwios.v_lineage_edges_resolved
      where to_object_key='VAL-PROD-EOG-EP-V2-20261026')<>8
     or (select count(*) from fwios.v_lineage_edges_resolved
      where to_object_key='VAL-PROD-NFLX-STREAM-V2-20261026')<>9
  then raise exception 'T07 production lineage parity failed'; end if;

  -- T08: Dashboard reads v2 production runs.
  if not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='ACN' and valuation_run_id='VAL-PROD-ACN-ITSERV-V2-20261026'
  ) or not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='EOG' and valuation_run_id='VAL-PROD-EOG-EP-V2-20261026'
  ) or not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='NFLX' and valuation_run_id='VAL-PROD-NFLX-STREAM-V2-20261026'
  ) then raise exception 'T08 Dashboard not on v2 production'; end if;

  -- T09: readiness consumes the v2 production runs.
  if (select count(*) from fwios.v_research_readiness_current_v1
      where ticker in ('ACN','EOG','NFLX')
        and valuation_readiness='READY'
        and valuation_run_id in (
          'VAL-PROD-ACN-ITSERV-V2-20261026',
          'VAL-PROD-EOG-EP-V2-20261026',
          'VAL-PROD-NFLX-STREAM-V2-20261026'
        ))<>3
  then raise exception 'T09 readiness not aligned to v2 production'; end if;

  -- T10: previous production runs remain available as rollback targets.
  if not exists (
    select 1 from fwios.valuation_runs
    where run_id='VAL-SUPA-ACN-ITSERV-20260905' and production_eligible=true
  ) or not exists (
    select 1 from fwios.valuation_runs
    where run_id='VAL-EOG-20260904-P087' and production_eligible=true
  ) or not exists (
    select 1 from fwios.valuation_runs
    where run_id='VAL-NFLX-STREAM-20260911' and production_eligible=true
  ) then raise exception 'T10 rollback run missing'; end if;

  -- T11: re-applying exact shadow promotions is idempotent.
  r := fwios.apply_valuation_promotion_v1('VAL-SHADOW-ACN-ITSERV-V2-20261026');
  if r->>'status'<>'NOOP_ALREADY_PROMOTED' then raise exception 'T11 ACN idempotency failed: %',r; end if;
  r := fwios.apply_valuation_promotion_v1('VAL-SHADOW-EOG-EP-V2-20261026');
  if r->>'status'<>'NOOP_ALREADY_PROMOTED' then raise exception 'T11 EOG idempotency failed: %',r; end if;
  r := fwios.apply_valuation_promotion_v1('VAL-SHADOW-NFLX-STREAM-V2-20261026');
  if r->>'status'<>'NOOP_ALREADY_PROMOTED' then raise exception 'T11 NFLX idempotency failed: %',r; end if;

  -- T12: exactly 20 authoritative production model versions remain.
  if (select count(*) from fwios.valuation_model_versions where status='PRODUCTION')<>20
  then raise exception 'T12 production model-version count changed'; end if;

  -- T13: apply/rollback functions remain service-role-only.
  if has_function_privilege('public','fwios.apply_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('anon','fwios.apply_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('authenticated','fwios.apply_valuation_promotion_v1(text)','EXECUTE')
     or not has_function_privilege('service_role','fwios.apply_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('public','fwios.rollback_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('anon','fwios.rollback_valuation_promotion_v1(text)','EXECUTE')
     or has_function_privilege('authenticated','fwios.rollback_valuation_promotion_v1(text)','EXECUTE')
     or not has_function_privilege('service_role','fwios.rollback_valuation_promotion_v1(text)','EXECUTE')
  then raise exception 'T13 promotion function privilege boundary invalid'; end if;
end $$;

begin;
do $$
declare
  r jsonb;
begin
  -- T14: rollback path restores all three prior production runs inside a transaction.
  r := fwios.rollback_valuation_promotion_v1('VAL-PROD-ACN-ITSERV-V2-20261026');
  if r->>'status'<>'ROLLED_BACK' then raise exception 'T14 ACN rollback failed: %',r; end if;
  r := fwios.rollback_valuation_promotion_v1('VAL-PROD-EOG-EP-V2-20261026');
  if r->>'status'<>'ROLLED_BACK' then raise exception 'T14 EOG rollback failed: %',r; end if;
  r := fwios.rollback_valuation_promotion_v1('VAL-PROD-NFLX-STREAM-V2-20261026');
  if r->>'status'<>'ROLLED_BACK' then raise exception 'T14 NFLX rollback failed: %',r; end if;

  if not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='ACN' and valuation_run_id='VAL-SUPA-ACN-ITSERV-20260905'
  ) or not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='EOG' and valuation_run_id='VAL-EOG-20260904-P087'
  ) or not exists (
    select 1 from fwios.v_dashboard_valuation_map
    where ticker='NFLX' and valuation_run_id='VAL-NFLX-STREAM-20260911'
  ) then raise exception 'T14 rollback Dashboard verification failed'; end if;
end $$;
rollback;

select 'FWIOS VALUATION V2 PRODUCTION CUTOVER: PASS (14/14, ROLLBACK-VERIFIED)' result;
