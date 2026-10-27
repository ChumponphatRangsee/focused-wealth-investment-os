-- Generic payment-network valuation preview/apply runner for ticker-only clean-room orchestration.
-- Uses existing model registry/version policy and payment_network_fcf_dcf_fv_v1 kernel unchanged.

CREATE OR REPLACE FUNCTION fwios.apply_payment_network_valuation_v1(p_ticker text, p_human_authorized boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
declare
  v_preview jsonb;
  v_ticker text;
  v_run_id text;
  v_instrument_id uuid;
  v_model_id text;
  v_version_id text;
  v_inputs jsonb;
  v_assumptions jsonb;
  v_probs jsonb;
  v_bear numeric;
  v_base numeric;
  v_bull numeric;
  v_pw numeric;
  v_valuation_artifact uuid;
  v_metric_artifact uuid;
  r record;
  v_obs_id uuid;
  v_existing fwios.valuation_runs%rowtype;
  v_sync jsonb;
begin
  if not coalesce(p_human_authorized,false) then
    return jsonb_build_object('status','BLOCKED','reason','HUMAN_AUTHORIZATION_REQUIRED',
                              'production_changes','NONE','auto_trade',false);
  end if;

  v_sync:=fwios.sync_metric_lineage_v1(p_ticker);
  if coalesce(v_sync->>'status','BLOCKED')<>'PASS' then
    return jsonb_build_object('status','BLOCKED','reason','METRIC_LINEAGE_SYNC_FAILED','lineage_sync',v_sync,
                              'production_changes','NONE','auto_trade',false);
  end if;

  v_preview:=fwios.preview_payment_network_valuation_v1(p_ticker);
  if coalesce(v_preview->>'status','BLOCKED')<>'PASS' then
    return jsonb_build_object('status','BLOCKED','reason','VALUATION_PREVIEW_NOT_PASS','preview',v_preview,
                              'production_changes','NONE','auto_trade',false);
  end if;

  v_ticker:=v_preview->>'ticker';
  v_run_id:=v_preview->>'valuation_run_id';
  v_instrument_id:=(v_preview->>'instrument_id')::uuid;
  v_model_id:=v_preview->'route'->>'model_id';
  v_version_id:=v_preview->'route'->>'model_version_id';
  v_inputs:=v_preview->'inputs';
  v_assumptions:=v_preview->'assumptions';
  v_probs:=v_preview->'probabilities';
  v_bear:=(v_preview->'fair_value'->>'bear')::numeric;
  v_base:=(v_preview->'fair_value'->>'base')::numeric;
  v_bull:=(v_preview->'fair_value'->>'bull')::numeric;
  v_pw:=(v_preview->'fair_value'->>'probability_weighted')::numeric;

  select * into v_existing from fwios.valuation_runs where run_id=v_run_id;
  if found then
    if v_existing.ticker=v_ticker and v_existing.model_version_id=v_version_id
       and v_existing.bear_fv_per_share=v_bear and v_existing.base_fv_per_share=v_base
       and v_existing.bull_fv_per_share=v_bull and v_existing.probability_weighted_fv_per_share=v_pw
       and v_existing.production_eligible=true
    then
      return jsonb_build_object('status','NOOP_ALREADY_APPLIED','ticker',v_ticker,'valuation_run_id',v_run_id,
        'fair_value',v_preview->'fair_value','production_changes','NONE','auto_trade',false);
    end if;
    return jsonb_build_object('status','BLOCKED','reason','VALUATION_RUN_ID_COLLISION','valuation_run_id',v_run_id,
                              'production_changes','NONE','auto_trade',false);
  end if;

  insert into fwios.valuation_runs(
    run_id,ticker,model_id,model_version_id,as_of_text,current_price,forecast_scope,forecast_period,
    valuation_readiness,router_gate,valuation_gate,schema_gate,model_decision,mispricing_gate,mispricing_class,mispricing_note,
    bear_fv_per_share,base_fv_per_share,bull_fv_per_share,probability_weighted_fv_per_share,
    bear_probability,base_probability,bull_probability,bear_upside,base_upside,bull_upside,probability_weighted_upside,
    reward_risk,production_eligible,source_sheet,source_row,source_snapshot,raw_payload
  ) values (
    v_run_id,v_ticker,v_model_id,v_version_id,
    coalesce((v_preview->>'reported_cutoff')::timestamptz::date,current_date)::text,null,
    '10-year equity FCF compounder DCF',v_preview->>'forecast_period',
    'PASS','PASS','PASS','PASS','VALUATION COMPUTE READY',
    'PENDING PRICE LAYER','NOT SCORED','Intrinsic value computed without market price; verified market layer joins downstream.',
    v_bear,v_base,v_bull,v_pw,
    (v_probs->>'bear')::numeric,(v_probs->>'base')::numeric,(v_probs->>'bull')::numeric,
    null,null,null,null,null,true,'Supabase',null,'CLEAN_ROOM_E2E_PAYMENT_NETWORK_V1',
    jsonb_build_object('clean_room_e2e',true,'ticker_only_input',true,'input_observations',v_inputs,
      'model_assumptions_source','valuation_model_versions','market_price_excluded',true,
      'human_execution_only',true,'auto_trade',false)
  );

  insert into fwios.valuation_scenarios(run_id,scenario,probability,fair_value_per_share,upside_vs_current,normalized_inputs,assumptions,notes)
  values
  (v_run_id,'BEAR',(v_probs->>'bear')::numeric,v_bear,null,
    jsonb_build_object('fcf_ltm_b',(v_inputs->'fcf_ltm'->>'value')::numeric,
      'net_cash_b',(v_inputs->'net_cash'->>'value')::numeric,'shares_m',(v_inputs->'shares_outstanding'->>'value')::numeric,
      'payments_volume_growth',(v_inputs->'payments_volume_growth'->>'value')::numeric,
      'cross_border_growth',(v_inputs->'cross_border_growth'->>'value')::numeric,
      'take_rate',(v_inputs->'take_rate'->>'value')::numeric,'operating_margin',(v_inputs->'operating_margin'->>'value')::numeric),
    v_assumptions->'bear','Clean-room production-model scenario; market price excluded.'),
  (v_run_id,'BASE',(v_probs->>'base')::numeric,v_base,null,
    jsonb_build_object('fcf_ltm_b',(v_inputs->'fcf_ltm'->>'value')::numeric,
      'net_cash_b',(v_inputs->'net_cash'->>'value')::numeric,'shares_m',(v_inputs->'shares_outstanding'->>'value')::numeric,
      'payments_volume_growth',(v_inputs->'payments_volume_growth'->>'value')::numeric,
      'cross_border_growth',(v_inputs->'cross_border_growth'->>'value')::numeric,
      'take_rate',(v_inputs->'take_rate'->>'value')::numeric,'operating_margin',(v_inputs->'operating_margin'->>'value')::numeric),
    v_assumptions->'base','Clean-room production-model scenario; market price excluded.'),
  (v_run_id,'BULL',(v_probs->>'bull')::numeric,v_bull,null,
    jsonb_build_object('fcf_ltm_b',(v_inputs->'fcf_ltm'->>'value')::numeric,
      'net_cash_b',(v_inputs->'net_cash'->>'value')::numeric,'shares_m',(v_inputs->'shares_outstanding'->>'value')::numeric,
      'payments_volume_growth',(v_inputs->'payments_volume_growth'->>'value')::numeric,
      'cross_border_growth',(v_inputs->'cross_border_growth'->>'value')::numeric,
      'take_rate',(v_inputs->'take_rate'->>'value')::numeric,'operating_margin',(v_inputs->'operating_margin'->>'value')::numeric),
    v_assumptions->'bull','Clean-room production-model scenario; market price excluded.');

  for r in select key,value from jsonb_each(v_inputs)
  loop
    insert into fwios.valuation_run_inputs(
      run_id,input_key,input_layer,input_version,input_value_text,input_unit,input_role,source_key,required,gate_status,notes
    ) values (
      v_run_id,r.key,'NORMALIZED','CLEAN_ROOM_PAYMENT_NETWORK_V1',r.value->>'value',
      r.value->>'unit',r.value->>'input_role',r.value->>'observation_key',true,'PASS',
      'Resolved from canonical metric observation with Tier-A verified provenance.'
    );
  end loop;

  insert into fwios.valuation_run_inputs(run_id,input_key,input_layer,input_version,input_value_text,input_unit,input_role,source_key,required,gate_status,notes)
  values
  (v_run_id,'bear_assumptions','ASSUMPTION','PAYNET_V1.0',v_assumptions->'bear'::text,'scenario','ASSUMPTION','MODEL_POLICY',true,'PASS','Production model-version assumptions.'),
  (v_run_id,'base_assumptions','ASSUMPTION','PAYNET_V1.0',v_assumptions->'base'::text,'scenario','ASSUMPTION','MODEL_POLICY',true,'PASS','Production model-version assumptions.'),
  (v_run_id,'bull_assumptions','ASSUMPTION','PAYNET_V1.0',v_assumptions->'bull'::text,'scenario','ASSUMPTION','MODEL_POLICY',true,'PASS','Production model-version assumptions.');

  insert into fwios.lineage_artifacts(
    artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
  ) values (
    'VALUATION:'||v_run_id,'VALUATION_RUN','fwios','valuation_runs',v_run_id,v_instrument_id,'RESOLVED',
    jsonb_build_object('ticker',v_ticker,'model_id',v_model_id,'model_version_id',v_version_id,'clean_room_e2e',true)
  ) on conflict(artifact_key) do nothing;

  select artifact_id into v_valuation_artifact
  from fwios.lineage_artifacts where artifact_key='VALUATION:'||v_run_id;

  for r in select key,value from jsonb_each(v_inputs)
  loop
    v_obs_id:=(r.value->>'observation_id')::uuid;
    select artifact_id into v_metric_artifact
    from fwios.lineage_artifacts where artifact_key='METRIC_OBS:'||v_obs_id::text;
    if v_metric_artifact is null then
      raise exception 'VALUATION_INPUT_LINEAGE_ARTIFACT_MISSING: %',r.key;
    end if;
    insert into fwios.lineage_edges(
      from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
    )
    select v_metric_artifact,v_valuation_artifact,'METRIC_INPUT_TO_VALUATION',
           (r.value->>'input_role')||':'||r.key,'RESOLVED',r.value->>'observation_key',
           jsonb_build_object('required',true,'gate_status','PASS','input_version','CLEAN_ROOM_PAYMENT_NETWORK_V1')
    where not exists(
      select 1 from fwios.lineage_edges e
      where e.from_artifact_id=v_metric_artifact and e.to_artifact_id=v_valuation_artifact
        and e.edge_type='METRIC_INPUT_TO_VALUATION'
        and e.edge_role=(r.value->>'input_role')||':'||r.key
    );
  end loop;

  return jsonb_build_object(
    'status','APPLIED','ticker',v_ticker,'valuation_run_id',v_run_id,'route',v_preview->'route',
    'fair_value',v_preview->'fair_value','production_eligible',true,
    'portfolio_mutation',false,'approval_mutation',false,'execution_mutation',false,
    'auto_trade',false,'human_execution_only',true
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION fwios.preview_payment_network_valuation_v1(p_ticker text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
declare
  v_ticker text := upper(btrim(coalesce(p_ticker,'')));
  v_company fwios.companies%rowtype;
  v_route fwios.sector_archetypes%rowtype;
  v_model fwios.valuation_models%rowtype;
  v_version fwios.valuation_model_versions%rowtype;
  v_version_count int;
  v_age int;
  v_payvol fwios.metric_observations%rowtype;
  v_cross fwios.metric_observations%rowtype;
  v_take fwios.metric_observations%rowtype;
  v_margin fwios.metric_observations%rowtype;
  v_fcf fwios.metric_observations%rowtype;
  v_netcash fwios.metric_observations%rowtype;
  v_shares fwios.metric_observations%rowtype;
  v_missing text[] := '{}'::text[];
  v_bad_lineage text[] := '{}'::text[];
  v_bear numeric;
  v_base numeric;
  v_bull numeric;
  v_pw numeric;
  v_pbear numeric;
  v_pbase numeric;
  v_pbull numeric;
  v_latest_reported timestamptz;
  v_hash text;
  v_run_id text;
  v_inputs jsonb;
  r record;
begin
  if v_ticker='' then
    return jsonb_build_object('status','BLOCKED','reason','TICKER_REQUIRED');
  end if;

  select * into v_company from fwios.companies where ticker=v_ticker and active=true;
  if not found or v_company.instrument_id is null then
    return jsonb_build_object('status','BLOCKED','reason','ACTIVE_COMPANY_IDENTITY_REQUIRED','ticker',v_ticker);
  end if;

  select * into v_route
  from fwios.sector_archetypes
  where sector=v_company.sector and archetype=v_company.archetype
  order by id limit 1;
  if not found then
    return jsonb_build_object('status','BLOCKED','reason','VALUATION_ROUTE_NOT_FOUND','ticker',v_ticker,
                              'sector',v_company.sector,'archetype',v_company.archetype);
  end if;
  if v_route.valuation_model_id is distinct from 'PAYMENT_NETWORK_FCF_DCF_V1' then
    return jsonb_build_object('status','BLOCKED','reason','PAYMENT_NETWORK_EXECUTOR_NOT_APPLICABLE','ticker',v_ticker,
                              'routed_model_id',v_route.valuation_model_id,'archetype',v_company.archetype);
  end if;
  if coalesce(v_route.minimum_metric_coverage,1)<>1 then
    return jsonb_build_object('status','BLOCKED','reason','ROUTE_REQUIRES_INCOMPLETE_METRIC_COVERAGE',
                              'ticker',v_ticker,'minimum_metric_coverage',v_route.minimum_metric_coverage);
  end if;
  if upper(coalesce(v_route.required_source_tier,''))<>'A' then
    return jsonb_build_object('status','BLOCKED','reason','UNSUPPORTED_ROUTE_SOURCE_TIER','ticker',v_ticker,
                              'required_source_tier',v_route.required_source_tier);
  end if;

  select * into v_model from fwios.valuation_models where model_id=v_route.valuation_model_id;
  if not found or v_model.production_status<>'IMPLEMENTED' or v_model.regression_status<>'PASS' then
    return jsonb_build_object('status','BLOCKED','reason','VALUATION_MODEL_NOT_PRODUCTION_READY','ticker',v_ticker,
                              'model_id',v_route.valuation_model_id);
  end if;

  select count(*) into v_version_count
  from fwios.valuation_model_versions
  where model_id=v_model.model_id and status='PRODUCTION';
  if v_version_count<>1 then
    return jsonb_build_object('status','BLOCKED','reason','PRODUCTION_MODEL_VERSION_AUTHORITY_AMBIGUOUS',
                              'ticker',v_ticker,'model_id',v_model.model_id,'production_version_count',v_version_count);
  end if;

  select * into v_version
  from fwios.valuation_model_versions
  where model_id=v_model.model_id and status='PRODUCTION'
  order by effective_from desc,created_at desc limit 1;

  if v_version.regression_status<>'PASS' or v_version.kernel_family<>'FCF_COMPOUNDER' then
    return jsonb_build_object('status','BLOCKED','reason','MODEL_VERSION_REGRESSION_OR_KERNEL_NOT_READY',
                              'ticker',v_ticker,'model_version_id',v_version.version_id);
  end if;

  v_age:=coalesce(v_route.max_metric_age_days,120);

  select o.* into v_payvol
  from fwios.metric_observations o join fwios.evidence_records e on e.evidence_id=o.primary_evidence_id
  where o.instrument_id=v_company.instrument_id and o.metric_code='PAYMENTS_VOLUME_GROWTH'
    and o.value_numeric is not null and o.provenance_status='PASS' and o.quality_gate='PASS'
    and o.reported_at>=now()-make_interval(days=>v_age)
    and upper(coalesce(e.source_tier,''))='A' and upper(coalesce(e.verification_status,'')) in ('VERIFIED','PASS')
    and upper(coalesce(e.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','') and e.source_url like 'https://%'
  order by o.reported_at desc,o.period_end desc nulls last,o.created_at desc limit 1;
  if not found then v_missing:=array_append(v_missing,'PAYMENTS_VOLUME_GROWTH'); end if;

  select o.* into v_cross
  from fwios.metric_observations o join fwios.evidence_records e on e.evidence_id=o.primary_evidence_id
  where o.instrument_id=v_company.instrument_id and o.metric_code='CROSS_BORDER_GROWTH'
    and o.value_numeric is not null and o.provenance_status='PASS' and o.quality_gate='PASS'
    and o.reported_at>=now()-make_interval(days=>v_age)
    and upper(coalesce(e.source_tier,''))='A' and upper(coalesce(e.verification_status,'')) in ('VERIFIED','PASS')
    and upper(coalesce(e.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','') and e.source_url like 'https://%'
  order by o.reported_at desc,o.period_end desc nulls last,o.created_at desc limit 1;
  if not found then v_missing:=array_append(v_missing,'CROSS_BORDER_GROWTH'); end if;

  select o.* into v_take
  from fwios.metric_observations o join fwios.evidence_records e on e.evidence_id=o.primary_evidence_id
  where o.instrument_id=v_company.instrument_id and o.metric_code='TAKE_RATE'
    and o.value_numeric is not null and o.provenance_status='PASS' and o.quality_gate='PASS'
    and o.reported_at>=now()-make_interval(days=>v_age)
    and upper(coalesce(e.source_tier,''))='A' and upper(coalesce(e.verification_status,'')) in ('VERIFIED','PASS')
    and upper(coalesce(e.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','') and e.source_url like 'https://%'
  order by o.reported_at desc,o.period_end desc nulls last,o.created_at desc limit 1;
  if not found then v_missing:=array_append(v_missing,'TAKE_RATE'); end if;

  select o.* into v_margin
  from fwios.metric_observations o join fwios.evidence_records e on e.evidence_id=o.primary_evidence_id
  where o.instrument_id=v_company.instrument_id and o.metric_code='OPERATING_MARGIN'
    and o.value_numeric is not null and o.provenance_status='PASS' and o.quality_gate='PASS'
    and o.reported_at>=now()-make_interval(days=>v_age)
    and upper(coalesce(e.source_tier,''))='A' and upper(coalesce(e.verification_status,'')) in ('VERIFIED','PASS')
    and upper(coalesce(e.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','') and e.source_url like 'https://%'
  order by o.reported_at desc,o.period_end desc nulls last,o.created_at desc limit 1;
  if not found then v_missing:=array_append(v_missing,'OPERATING_MARGIN'); end if;

  select o.* into v_fcf
  from fwios.metric_observations o join fwios.evidence_records e on e.evidence_id=o.primary_evidence_id
  where o.instrument_id=v_company.instrument_id and o.metric_code='FREE_CASH_FLOW' and o.period_type='LTM'
    and o.value_numeric>0 and o.provenance_status='PASS' and o.quality_gate='PASS'
    and o.reported_at>=now()-make_interval(days=>v_age)
    and upper(coalesce(e.source_tier,''))='A' and upper(coalesce(e.verification_status,'')) in ('VERIFIED','PASS')
    and upper(coalesce(e.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','') and e.source_url like 'https://%'
  order by o.reported_at desc,o.period_end desc nulls last,o.created_at desc limit 1;
  if not found then v_missing:=array_append(v_missing,'FREE_CASH_FLOW:LTM'); end if;

  select o.* into v_netcash
  from fwios.metric_observations o join fwios.evidence_records e on e.evidence_id=o.primary_evidence_id
  where o.instrument_id=v_company.instrument_id and o.metric_code='NET_CASH'
    and o.value_numeric is not null and o.provenance_status='PASS' and o.quality_gate='PASS'
    and o.reported_at>=now()-make_interval(days=>v_age)
    and upper(coalesce(e.source_tier,''))='A' and upper(coalesce(e.verification_status,'')) in ('VERIFIED','PASS')
    and upper(coalesce(e.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','') and e.source_url like 'https://%'
  order by o.reported_at desc,o.period_end desc nulls last,o.created_at desc limit 1;
  if not found then v_missing:=array_append(v_missing,'NET_CASH'); end if;

  select o.* into v_shares
  from fwios.metric_observations o join fwios.evidence_records e on e.evidence_id=o.primary_evidence_id
  where o.instrument_id=v_company.instrument_id and o.metric_code='SHARES_OUTSTANDING'
    and o.value_numeric>0 and o.provenance_status='PASS' and o.quality_gate='PASS'
    and o.reported_at>=now()-make_interval(days=>v_age)
    and upper(coalesce(e.source_tier,''))='A' and upper(coalesce(e.verification_status,'')) in ('VERIFIED','PASS')
    and upper(coalesce(e.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','') and e.source_url like 'https://%'
  order by o.reported_at desc,o.period_end desc nulls last,o.created_at desc limit 1;
  if not found then v_missing:=array_append(v_missing,'SHARES_OUTSTANDING'); end if;

  if cardinality(v_missing)>0 then
    return jsonb_build_object('status','BLOCKED','reason','MISSING_STALE_OR_UNVERIFIED_REQUIRED_METRIC',
                              'ticker',v_ticker,'missing_metrics',to_jsonb(v_missing),
                              'model_id',v_model.model_id,'model_version_id',v_version.version_id,
                              'production_changes','NONE','auto_trade',false);
  end if;

  if v_payvol.value_numeric<-0.50 or v_payvol.value_numeric>1.00
     or v_cross.value_numeric<-0.50 or v_cross.value_numeric>1.50
     or v_take.value_numeric<=0 or v_take.value_numeric>=0.10
     or v_margin.value_numeric<=0 or v_margin.value_numeric>1.00
     or v_fcf.value_numeric<=0 or v_shares.value_numeric<=0
  then
    return jsonb_build_object('status','BLOCKED','reason','VALUATION_INPUT_PLAUSIBILITY_FAILED','ticker',v_ticker,
                              'production_changes','NONE','auto_trade',false);
  end if;

  v_inputs:=jsonb_build_object(
    'payments_volume_growth',jsonb_build_object('observation_id',v_payvol.observation_id,'observation_key',v_payvol.observation_key,
      'metric_code',v_payvol.metric_code,'value',v_payvol.value_numeric,'unit',v_payvol.canonical_unit,'input_role','NORMALIZED'),
    'cross_border_growth',jsonb_build_object('observation_id',v_cross.observation_id,'observation_key',v_cross.observation_key,
      'metric_code',v_cross.metric_code,'value',v_cross.value_numeric,'unit',v_cross.canonical_unit,'input_role','NORMALIZED'),
    'take_rate',jsonb_build_object('observation_id',v_take.observation_id,'observation_key',v_take.observation_key,
      'metric_code',v_take.metric_code,'value',v_take.value_numeric,'unit',v_take.canonical_unit,'input_role','SANITY'),
    'operating_margin',jsonb_build_object('observation_id',v_margin.observation_id,'observation_key',v_margin.observation_key,
      'metric_code',v_margin.metric_code,'value',v_margin.value_numeric,'unit',v_margin.canonical_unit,'input_role','SANITY'),
    'fcf_ltm',jsonb_build_object('observation_id',v_fcf.observation_id,'observation_key',v_fcf.observation_key,
      'metric_code',v_fcf.metric_code,'value',v_fcf.value_numeric,'unit',v_fcf.canonical_unit,'input_role','NORMALIZED'),
    'net_cash',jsonb_build_object('observation_id',v_netcash.observation_id,'observation_key',v_netcash.observation_key,
      'metric_code',v_netcash.metric_code,'value',v_netcash.value_numeric,'unit',v_netcash.canonical_unit,'input_role','NORMALIZED'),
    'shares_outstanding',jsonb_build_object('observation_id',v_shares.observation_id,'observation_key',v_shares.observation_key,
      'metric_code',v_shares.metric_code,'value',v_shares.value_numeric,'unit',v_shares.canonical_unit,'input_role','NORMALIZED')
  );

  for r in select key,value from jsonb_each(v_inputs)
  loop
    if not exists(
      select 1 from fwios.lineage_artifacts a
      where a.artifact_key='METRIC_OBS:'||(r.value->>'observation_id')
        and a.artifact_type='METRIC_OBSERVATION'
        and a.instrument_id=v_company.instrument_id
    ) or not exists(
      select 1
      from fwios.lineage_edges e
      join fwios.lineage_artifacts a on a.artifact_id=e.to_artifact_id
      where a.artifact_key='METRIC_OBS:'||(r.value->>'observation_id')
        and e.edge_type in ('EVIDENCE_SUPPORTS_METRIC','METRIC_DERIVES_METRIC')
        and e.provenance_status='RESOLVED'
    ) then
      v_bad_lineage:=array_append(v_bad_lineage,r.key);
    end if;
  end loop;

  if cardinality(v_bad_lineage)>0 then
    return jsonb_build_object('status','BLOCKED','reason','REQUIRED_METRIC_LINEAGE_INCOMPLETE',
                              'ticker',v_ticker,'metrics',to_jsonb(v_bad_lineage),
                              'production_changes','NONE','auto_trade',false);
  end if;

  v_pbear:=(v_version.model_policy->'probabilities'->>'bear')::numeric;
  v_pbase:=(v_version.model_policy->'probabilities'->>'base')::numeric;
  v_pbull:=(v_version.model_policy->'probabilities'->>'bull')::numeric;
  if v_pbear is null or v_pbase is null or v_pbull is null or abs((v_pbear+v_pbase+v_pbull)-1)>0.000001 then
    return jsonb_build_object('status','BLOCKED','reason','MODEL_PROBABILITY_POLICY_INVALID','ticker',v_ticker);
  end if;

  v_bear:=fwios.payment_network_fcf_dcf_fv_v1(
    v_fcf.value_numeric,v_netcash.value_numeric,v_shares.value_numeric,
    (v_version.assumptions->'bear'->>'growth_y1_5')::numeric,
    (v_version.assumptions->'bear'->>'growth_y6_10')::numeric,
    (v_version.assumptions->'bear'->>'discount_rate')::numeric,
    (v_version.assumptions->'bear'->>'terminal_growth')::numeric
  );
  v_base:=fwios.payment_network_fcf_dcf_fv_v1(
    v_fcf.value_numeric,v_netcash.value_numeric,v_shares.value_numeric,
    (v_version.assumptions->'base'->>'growth_y1_5')::numeric,
    (v_version.assumptions->'base'->>'growth_y6_10')::numeric,
    (v_version.assumptions->'base'->>'discount_rate')::numeric,
    (v_version.assumptions->'base'->>'terminal_growth')::numeric
  );
  v_bull:=fwios.payment_network_fcf_dcf_fv_v1(
    v_fcf.value_numeric,v_netcash.value_numeric,v_shares.value_numeric,
    (v_version.assumptions->'bull'->>'growth_y1_5')::numeric,
    (v_version.assumptions->'bull'->>'growth_y6_10')::numeric,
    (v_version.assumptions->'bull'->>'discount_rate')::numeric,
    (v_version.assumptions->'bull'->>'terminal_growth')::numeric
  );
  if v_bear is null or v_base is null or v_bull is null then
    return jsonb_build_object('status','BLOCKED','reason','VALUATION_KERNEL_REJECTED_INPUTS','ticker',v_ticker);
  end if;
  v_pw:=v_bear*v_pbear+v_base*v_pbase+v_bull*v_pbull;

  select max(x) into v_latest_reported
  from unnest(array[v_payvol.reported_at,v_cross.reported_at,v_take.reported_at,v_margin.reported_at,
                    v_fcf.reported_at,v_netcash.reported_at,v_shares.reported_at]) x;

  v_hash:=md5(
    v_ticker||':'||v_version.version_id||':'||
    v_payvol.observation_id||':'||v_cross.observation_id||':'||v_take.observation_id||':'||
    v_margin.observation_id||':'||v_fcf.observation_id||':'||v_netcash.observation_id||':'||v_shares.observation_id
  );
  v_run_id:='VAL-CR-'||v_ticker||'-'||to_char(coalesce(v_latest_reported,now())::date,'YYYYMMDD')||'-'||substr(v_hash,1,12);

  return jsonb_build_object(
    'status','PASS','ticker',v_ticker,'instrument_id',v_company.instrument_id,
    'route',jsonb_build_object('sector',v_company.sector,'archetype',v_company.archetype,
      'model_id',v_model.model_id,'model_version_id',v_version.version_id,'kernel_family',v_version.kernel_family),
    'inputs',v_inputs,'assumptions',v_version.assumptions,'probabilities',v_version.model_policy->'probabilities',
    'fair_value',jsonb_build_object('bear',v_bear,'base',v_base,'bull',v_bull,'probability_weighted',v_pw),
    'valuation_run_id',v_run_id,'reported_cutoff',v_latest_reported,
    'forecast_period','LTM through '||coalesce(v_fcf.period_end::text,v_fcf.as_of_date::text),
    'market_price_in_model_assumptions',false,
    'production_eligible',true,'production_changes','NONE','auto_trade',false,'human_execution_only',true
  );
end;
$function$
;
