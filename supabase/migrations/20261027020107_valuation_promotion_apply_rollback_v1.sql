
update fwios.policy_registry
set backing_object='fwios.preview_valuation_promotion_v1 / fwios.apply_valuation_promotion_v1 / fwios.rollback_valuation_promotion_v1 / fwios.v_valuation_promotion_readiness_v1',
    updated_at=now()
where policy_key='VALUATION_PROMOTION';

update fwios.policy_versions
set config = config || jsonb_build_object(
  'apply_function','fwios.apply_valuation_promotion_v1',
  'rollback_function','fwios.rollback_valuation_promotion_v1',
  'apply_requires_auto_eligible',true,
  'rollback_requires_current_promoted_run',true,
  'shadow_immutability_preserved',true,
  'old_production_run_retained_for_rollback',true
)
where policy_version_id='POL-VALUATION-PROMOTION-V1';

create or replace function fwios.apply_valuation_promotion_v1(p_shadow_run_id text)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = pg_catalog, fwios
as $$
declare
  v_preview jsonb;
  v_preview_after_lock jsonb;
  v_shadow fwios.valuation_runs%rowtype;
  v_old_prod fwios.valuation_runs%rowtype;
  v_shadow_version fwios.valuation_model_versions%rowtype;
  v_old_version fwios.valuation_model_versions%rowtype;
  v_model fwios.valuation_models%rowtype;
  v_prod_run_id text;
  v_current_price numeric;
  v_current_dashboard_run text;
  v_required_metric_ids text[];
  v_shadow_lineage_count integer;
  v_prod_lineage_count integer;
begin
  if p_shadow_run_id is null or btrim(p_shadow_run_id)='' then
    return jsonb_build_object(
      'status','BLOCKED','reason','SHADOW_RUN_ID_REQUIRED',
      'production_changes','NONE','auto_trade',false
    );
  end if;

  v_prod_run_id := regexp_replace(p_shadow_run_id,'^VAL-SHADOW-','VAL-PROD-');
  if v_prod_run_id = p_shadow_run_id then
    v_prod_run_id := 'VAL-PROD-' || p_shadow_run_id;
  end if;

  if exists (
    select 1
    from fwios.valuation_runs
    where run_id=v_prod_run_id
      and production_eligible=true
      and raw_payload->>'promoted_from_shadow_run_id'=p_shadow_run_id
  ) then
    return jsonb_build_object(
      'status','NOOP_ALREADY_PROMOTED',
      'shadow_run_id',p_shadow_run_id,
      'production_run_id',v_prod_run_id,
      'production_changes','NONE',
      'auto_trade',false,
      'human_execution_only',true
    );
  elsif exists (select 1 from fwios.valuation_runs where run_id=v_prod_run_id) then
    return jsonb_build_object(
      'status','BLOCKED',
      'reason','PRODUCTION_RUN_ID_COLLISION',
      'shadow_run_id',p_shadow_run_id,
      'production_run_id',v_prod_run_id,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  v_preview := fwios.preview_valuation_promotion_v1(p_shadow_run_id);
  if coalesce(v_preview->>'promotion_status','BLOCKED') <> 'AUTO_ELIGIBLE' then
    return jsonb_build_object(
      'status','BLOCKED',
      'reason','PROMOTION_POLICY_NOT_AUTO_ELIGIBLE',
      'preview',v_preview,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  select * into v_shadow
  from fwios.valuation_runs
  where run_id=p_shadow_run_id
  for update;

  if not found then
    return jsonb_build_object(
      'status','BLOCKED',
      'reason','SHADOW_RUN_NOT_FOUND_AFTER_LOCK',
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  select * into v_shadow_version
  from fwios.valuation_model_versions
  where version_id=v_shadow.model_version_id
  for update;

  select * into v_model
  from fwios.valuation_models
  where model_id=v_shadow.model_id
  for update;

  select * into v_old_prod
  from fwios.valuation_runs
  where run_id=v_preview->>'current_production_run_id'
  for update;

  select * into v_old_version
  from fwios.valuation_model_versions
  where version_id=v_preview->>'current_production_model_version_id'
  for update;

  v_preview_after_lock := fwios.preview_valuation_promotion_v1(p_shadow_run_id);
  if coalesce(v_preview_after_lock->>'promotion_status','BLOCKED') <> 'AUTO_ELIGIBLE'
     or (v_preview_after_lock->>'current_production_run_id') is distinct from v_old_prod.run_id
     or (v_preview_after_lock->>'current_production_model_version_id') is distinct from v_old_version.version_id
  then
    return jsonb_build_object(
      'status','BLOCKED',
      'reason','PROMOTION_STATE_CHANGED_DURING_LOCK',
      'preview_before',v_preview,
      'preview_after',v_preview_after_lock,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  select d.current_price,d.valuation_run_id
    into v_current_price,v_current_dashboard_run
  from fwios.v_dashboard_valuation_map d
  where d.ticker=v_shadow.ticker;

  if v_current_dashboard_run is distinct from v_old_prod.run_id then
    return jsonb_build_object(
      'status','BLOCKED',
      'reason','DASHBOARD_PRODUCTION_RUN_CHANGED',
      'expected_run_id',v_old_prod.run_id,
      'actual_run_id',v_current_dashboard_run,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  v_current_price := coalesce(v_current_price,v_shadow.current_price,v_old_prod.current_price);

  select array_agg(x.metric_code order by x.ord)
    into v_required_metric_ids
  from jsonb_array_elements_text(v_shadow_version.input_contract->'required_metrics')
       with ordinality x(metric_code,ord);

  if v_required_metric_ids is null then
    select array_agg(distinct o.metric_code order by o.metric_code)
      into v_required_metric_ids
    from fwios.valuation_run_inputs i
    join fwios.metric_observations o on o.observation_key=i.source_key
    where i.run_id=p_shadow_run_id and i.required=true;
  end if;

  insert into fwios.valuation_runs(
    run_id,ticker,model_id,model_version_id,as_of_text,current_price,
    forecast_scope,forecast_period,valuation_readiness,router_gate,valuation_gate,schema_gate,
    model_decision,mispricing_gate,mispricing_class,mispricing_note,
    bear_fv_per_share,base_fv_per_share,bull_fv_per_share,probability_weighted_fv_per_share,
    bear_probability,base_probability,bull_probability,
    bear_upside,base_upside,bull_upside,probability_weighted_upside,reward_risk,
    production_eligible,source_sheet,source_row,source_snapshot,raw_payload
  )
  values (
    v_prod_run_id,
    v_shadow.ticker,
    v_shadow.model_id,
    v_shadow.model_version_id,
    regexp_replace(v_shadow.as_of_text,'SHADOW','PRODUCTION'),
    v_current_price,
    v_shadow.forecast_scope,
    v_shadow.forecast_period,
    v_shadow.valuation_readiness,
    v_shadow.router_gate,
    v_shadow.valuation_gate,
    v_shadow.schema_gate,
    'PRODUCTION V2 - PROMOTED FROM VALIDATED SHADOW',
    'VALUATION ONLY - CURRENT MISPRICING GATE SEPARATE',
    'PROMOTED_VALUATION',
    'Intrinsic valuation promoted from validated shadow; current-price mispricing remains a separate live gate.',
    v_shadow.bear_fv_per_share,
    v_shadow.base_fv_per_share,
    v_shadow.bull_fv_per_share,
    v_shadow.probability_weighted_fv_per_share,
    v_shadow.bear_probability,
    v_shadow.base_probability,
    v_shadow.bull_probability,
    case when v_current_price>0 then v_shadow.bear_fv_per_share/v_current_price-1 else v_shadow.bear_upside end,
    case when v_current_price>0 then v_shadow.base_fv_per_share/v_current_price-1 else v_shadow.base_upside end,
    case when v_current_price>0 then v_shadow.bull_fv_per_share/v_current_price-1 else v_shadow.bull_upside end,
    case when v_current_price>0 then v_shadow.probability_weighted_fv_per_share/v_current_price-1 else v_shadow.probability_weighted_upside end,
    v_shadow.reward_risk,
    true,
    'SYSTEM_PRODUCTION',
    null,
    'PROMOTED:'||p_shadow_run_id,
    v_shadow.raw_payload || jsonb_build_object(
      'promoted_from_shadow_run_id',p_shadow_run_id,
      'promotion_policy_id','POL-VALUATION-PROMOTION-V1',
      'promotion_status','AUTO_ELIGIBLE',
      'promotion_preview',v_preview_after_lock,
      'promoted_at',now(),
      'rollback_run_id',v_old_prod.run_id,
      'rollback_model_version_id',v_old_version.version_id,
      'rollback_model_registry',jsonb_build_object(
        'model_version',v_model.model_version,
        'required_metric_ids',to_jsonb(v_model.required_metric_ids),
        'regression_status',v_model.regression_status,
        'confidence_status',v_model.confidence_status,
        'notes',v_model.notes
      ),
      'production_cutover',true,
      'human_execution_only',true,
      'auto_trade',false
    )
  );

  insert into fwios.valuation_scenarios(
    run_id,scenario,probability,fair_value_per_share,upside_vs_current,
    normalized_inputs,assumptions,notes
  )
  select
    v_prod_run_id,
    scenario,
    probability,
    fair_value_per_share,
    case when v_current_price>0 then fair_value_per_share/v_current_price-1 else upside_vs_current end,
    normalized_inputs,
    assumptions,
    concat_ws(' | ',notes,'Promoted unchanged from shadow '||p_shadow_run_id)
  from fwios.valuation_scenarios
  where run_id=p_shadow_run_id;

  insert into fwios.valuation_run_inputs(
    run_id,input_key,input_layer,input_version,input_value_text,input_unit,
    input_role,source_key,required,gate_status,notes
  )
  select
    v_prod_run_id,input_key,input_layer,input_version,input_value_text,input_unit,
    input_role,source_key,required,gate_status,
    concat_ws(' | ',notes,'Promoted unchanged from shadow '||p_shadow_run_id)
  from fwios.valuation_run_inputs
  where run_id=p_shadow_run_id;

  insert into fwios.lineage_artifacts(
    artifact_key,artifact_type,object_schema,object_table,object_key,
    instrument_id,resolution_status,metadata
  )
  values (
    'VALUATION:'||v_prod_run_id,
    'VALUATION_RUN','fwios','valuation_runs',v_prod_run_id,
    fwios.resolve_instrument_id_v1(v_shadow.ticker,'Stock',null,null),
    'RESOLVED',
    jsonb_build_object(
      'ticker',v_shadow.ticker,
      'model_version_id',v_shadow.model_version_id,
      'production_eligible',true,
      'promoted_from_shadow_run_id',p_shadow_run_id,
      'promotion_policy_id','POL-VALUATION-PROMOTION-V1'
    )
  )
  on conflict(artifact_key) do nothing;

  insert into fwios.lineage_edges(
    from_artifact_id,to_artifact_id,edge_type,edge_role,
    provenance_status,source_reference,metadata
  )
  select
    e.from_artifact_id,
    prod_art.artifact_id,
    e.edge_type,
    e.edge_role,
    e.provenance_status,
    e.source_reference,
    e.metadata || jsonb_build_object(
      'promoted_from_shadow_run_id',p_shadow_run_id,
      'promotion_policy_id','POL-VALUATION-PROMOTION-V1'
    )
  from fwios.lineage_artifacts shadow_art
  join fwios.lineage_edges e on e.to_artifact_id=shadow_art.artifact_id
  join fwios.lineage_artifacts prod_art on prod_art.artifact_key='VALUATION:'||v_prod_run_id
  where shadow_art.artifact_key='VALUATION:'||p_shadow_run_id
    and not exists (
      select 1
      from fwios.lineage_edges existing
      where existing.from_artifact_id=e.from_artifact_id
        and existing.to_artifact_id=prod_art.artifact_id
        and existing.edge_type=e.edge_type
        and existing.edge_role=e.edge_role
    );

  update fwios.valuation_model_versions
  set status='RETIRED'
  where version_id=v_old_version.version_id
    and status='PRODUCTION';

  update fwios.valuation_model_versions
  set status='PRODUCTION',
      confidence_tier='PRODUCTION_VERIFIED',
      effective_from=current_date,
      source_system='FWIOS_PROMOTION_POLICY_V1',
      source_ref='PROMOTED_FROM_SHADOW:'||p_shadow_run_id,
      input_contract=jsonb_set(input_contract,'{production_read_cutover}','true'::jsonb,true)
  where version_id=v_shadow_version.version_id
    and status='EXPERIMENTAL';

  update fwios.valuation_models
  set model_version=v_shadow_version.version_label,
      required_metric_ids=v_required_metric_ids,
      regression_status='PASS',
      confidence_status='PRODUCTION_V2',
      notes=concat_ws(' | ',v_model.notes,'Promoted via POL-VALUATION-PROMOTION-V1 from '||p_shadow_run_id),
      updated_at=now()
  where model_id=v_shadow.model_id;

  if (select count(*) from fwios.valuation_model_versions
      where model_id=v_shadow.model_id and status='PRODUCTION') <> 1
  then
    raise exception 'Promotion produced non-singular production version authority for %',v_shadow.model_id;
  end if;

  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id=v_shadow_version.version_id
      and status='PRODUCTION'
      and input_contract->>'production_read_cutover'='true'
  ) then
    raise exception 'Promoted version not production/cutover=true';
  end if;

  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id=v_old_version.version_id and status='RETIRED'
  ) then
    raise exception 'Previous production version not retired';
  end if;

  if not exists (
    select 1 from fwios.valuation_runs p
    join fwios.valuation_runs s on s.run_id=p_shadow_run_id
    where p.run_id=v_prod_run_id
      and p.production_eligible=true
      and p.bear_fv_per_share=s.bear_fv_per_share
      and p.base_fv_per_share=s.base_fv_per_share
      and p.bull_fv_per_share=s.bull_fv_per_share
      and p.probability_weighted_fv_per_share=s.probability_weighted_fv_per_share
  ) then
    raise exception 'Production valuation differs from approved shadow';
  end if;

  select count(*) into v_shadow_lineage_count
  from fwios.v_lineage_edges_resolved
  where to_object_key=p_shadow_run_id;

  select count(*) into v_prod_lineage_count
  from fwios.v_lineage_edges_resolved
  where to_object_key=v_prod_run_id;

  if v_prod_lineage_count <> v_shadow_lineage_count then
    raise exception 'Production lineage parity failed: shadow %, production %',
      v_shadow_lineage_count,v_prod_lineage_count;
  end if;

  select valuation_run_id into v_current_dashboard_run
  from fwios.v_dashboard_valuation_map
  where ticker=v_shadow.ticker;

  if v_current_dashboard_run is distinct from v_prod_run_id then
    raise exception 'Dashboard did not cut over to %; got %',v_prod_run_id,v_current_dashboard_run;
  end if;

  return jsonb_build_object(
    'status','APPLIED',
    'ticker',v_shadow.ticker,
    'model_id',v_shadow.model_id,
    'shadow_run_id',p_shadow_run_id,
    'production_run_id',v_prod_run_id,
    'production_model_version_id',v_shadow_version.version_id,
    'retired_model_version_id',v_old_version.version_id,
    'rollback_run_id',v_old_prod.run_id,
    'rollback_model_version_id',v_old_version.version_id,
    'dashboard_run_id',v_current_dashboard_run,
    'lineage_edges',v_prod_lineage_count,
    'production_changes','VALUATION_MODEL_AND_RUN_CUTOVER',
    'portfolio_mutation',false,
    'auto_trade',false,
    'human_execution_only',true
  );
end;
$$;

create or replace function fwios.rollback_valuation_promotion_v1(p_production_run_id text)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = pg_catalog, fwios
as $$
declare
  v_prod fwios.valuation_runs%rowtype;
  v_new_version fwios.valuation_model_versions%rowtype;
  v_old_version fwios.valuation_model_versions%rowtype;
  v_registry jsonb;
  v_rollback_run_id text;
  v_rollback_version_id text;
  v_dashboard_run_id text;
  v_required_metric_ids text[];
begin
  select * into v_prod
  from fwios.valuation_runs
  where run_id=p_production_run_id
  for update;

  if not found then
    return jsonb_build_object(
      'status','BLOCKED','reason','PRODUCTION_RUN_NOT_FOUND',
      'production_changes','NONE','auto_trade',false
    );
  end if;

  if v_prod.raw_payload->>'promotion_policy_id' <> 'POL-VALUATION-PROMOTION-V1' then
    return jsonb_build_object(
      'status','BLOCKED','reason','RUN_NOT_CREATED_BY_PROMOTION_POLICY_V1',
      'production_changes','NONE','auto_trade',false
    );
  end if;

  v_rollback_run_id := v_prod.raw_payload->>'rollback_run_id';
  v_rollback_version_id := v_prod.raw_payload->>'rollback_model_version_id';
  v_registry := v_prod.raw_payload->'rollback_model_registry';

  if not v_prod.production_eligible then
    if exists (
      select 1 from fwios.valuation_model_versions
      where version_id=v_rollback_version_id and status='PRODUCTION'
    ) then
      return jsonb_build_object(
        'status','NOOP_ALREADY_ROLLED_BACK',
        'production_run_id',p_production_run_id,
        'rollback_run_id',v_rollback_run_id,
        'rollback_model_version_id',v_rollback_version_id,
        'production_changes','NONE',
        'auto_trade',false
      );
    end if;
  end if;

  select valuation_run_id into v_dashboard_run_id
  from fwios.v_dashboard_valuation_map
  where ticker=v_prod.ticker;

  if v_dashboard_run_id is distinct from p_production_run_id then
    return jsonb_build_object(
      'status','BLOCKED',
      'reason','PROMOTED_RUN_IS_NOT_CURRENT_DASHBOARD_RUN',
      'current_dashboard_run_id',v_dashboard_run_id,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  if not exists (
    select 1 from fwios.valuation_runs
    where run_id=v_rollback_run_id and production_eligible=true
  ) then
    return jsonb_build_object(
      'status','BLOCKED',
      'reason','ROLLBACK_RUN_NOT_AVAILABLE',
      'rollback_run_id',v_rollback_run_id,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  select * into v_new_version
  from fwios.valuation_model_versions
  where version_id=v_prod.model_version_id
  for update;

  select * into v_old_version
  from fwios.valuation_model_versions
  where version_id=v_rollback_version_id
  for update;

  select array_agg(value order by ord)
    into v_required_metric_ids
  from jsonb_array_elements_text(coalesce(v_registry->'required_metric_ids','[]'::jsonb))
       with ordinality x(value,ord);

  update fwios.valuation_runs
  set production_eligible=false,
      raw_payload=raw_payload || jsonb_build_object(
        'rolled_back_at',now(),
        'rollback_applied',true
      )
  where run_id=p_production_run_id;

  update fwios.valuation_model_versions
  set status='RETIRED',
      input_contract=jsonb_set(input_contract,'{production_read_cutover}','false'::jsonb,true),
      source_ref=concat_ws(' | ',source_ref,'ROLLED_BACK_FROM:'||p_production_run_id)
  where version_id=v_new_version.version_id;

  update fwios.valuation_model_versions
  set status='PRODUCTION'
  where version_id=v_old_version.version_id;

  update fwios.valuation_models
  set model_version=v_registry->>'model_version',
      required_metric_ids=v_required_metric_ids,
      regression_status=coalesce(v_registry->>'regression_status',regression_status),
      confidence_status=coalesce(v_registry->>'confidence_status',confidence_status),
      notes=v_registry->>'notes',
      updated_at=now()
  where model_id=v_prod.model_id;

  select valuation_run_id into v_dashboard_run_id
  from fwios.v_dashboard_valuation_map
  where ticker=v_prod.ticker;

  if v_dashboard_run_id is distinct from v_rollback_run_id then
    raise exception 'Rollback did not restore dashboard run %, got %',
      v_rollback_run_id,v_dashboard_run_id;
  end if;

  if (select count(*) from fwios.valuation_model_versions
      where model_id=v_prod.model_id and status='PRODUCTION') <> 1
  then
    raise exception 'Rollback produced non-singular production version authority';
  end if;

  return jsonb_build_object(
    'status','ROLLED_BACK',
    'ticker',v_prod.ticker,
    'production_run_id',p_production_run_id,
    'rollback_run_id',v_rollback_run_id,
    'retired_model_version_id',v_new_version.version_id,
    'restored_model_version_id',v_old_version.version_id,
    'dashboard_run_id',v_dashboard_run_id,
    'production_changes','VALUATION_MODEL_AND_RUN_ROLLBACK',
    'portfolio_mutation',false,
    'auto_trade',false,
    'human_execution_only',true
  );
end;
$$;

revoke all on function fwios.apply_valuation_promotion_v1(text) from public;
revoke all on function fwios.rollback_valuation_promotion_v1(text) from public;
grant execute on function fwios.apply_valuation_promotion_v1(text) to service_role;
grant execute on function fwios.rollback_valuation_promotion_v1(text) to service_role;
