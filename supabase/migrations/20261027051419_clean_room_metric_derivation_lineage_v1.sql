-- Clean-room canonical primitive metrics + deterministic derived-metric lineage.
-- Live-applied first; mirrored here to restore GitHub/Supabase migration parity.

insert into fwios.metric_definitions(
  metric_code,metric_name,value_kind,canonical_unit,scope_status,decision_uses,description,metadata,active
) values
('OPERATING_CASH_FLOW','Net cash provided by operating activities','NUMERIC','USD B','DECISION_RELEVANT',array['RESEARCH','VALUATION']::text[],'Reported operating cash flow for the stated period.','{"clean_room_primitive":true}'::jsonb,true),
('CAPEX_PROPERTY_EQUIPMENT','Purchases of property and equipment','NUMERIC','USD B','DECISION_RELEVANT',array['RESEARCH','VALUATION']::text[],'Reported cash purchases of property and equipment, represented as a positive spend amount.','{"clean_room_primitive":true}'::jsonb,true),
('CAPITALIZED_SOFTWARE','Capitalized software cash investment','NUMERIC','USD B','DECISION_RELEVANT',array['RESEARCH','VALUATION']::text[],'Reported capitalized software cash investment, represented as a positive spend amount.','{"clean_room_primitive":true}'::jsonb,true),
('CASH_AND_INVESTMENTS','Unrestricted cash, cash equivalents and investments','NUMERIC','USD B','DECISION_RELEVANT',array['RESEARCH','VALUATION']::text[],'Unrestricted cash, cash equivalents and investment securities used by the valuation equity bridge.','{"clean_room_primitive":true}'::jsonb,true),
('TOTAL_DEBT','Total carrying debt outstanding','NUMERIC','USD B','DECISION_RELEVANT',array['RESEARCH','VALUATION']::text[],'Total carrying debt outstanding used by the valuation equity bridge.','{"clean_room_primitive":true}'::jsonb,true),
('GROSS_DOLLAR_VOLUME','Gross dollar volume','NUMERIC','USD B','DECISION_RELEVANT',array['RESEARCH','VALUATION']::text[],'Gross dollar volume converted to USD billions for the stated period.','{"clean_room_primitive":true}'::jsonb,true)
on conflict(metric_code) do nothing;

CREATE OR REPLACE FUNCTION fwios.apply_metric_derivation_v1(p_ticker text, p_formula text, p_source_observation_keys text[], p_period_type text, p_fiscal_year integer DEFAULT NULL::integer, p_fiscal_quarter smallint DEFAULT NULL::smallint, p_period_start date DEFAULT NULL::date, p_period_end date DEFAULT NULL::date, p_as_of_date date DEFAULT NULL::date, p_human_authorized boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
declare
  v_preview jsonb;
  v_obs_id uuid;
  v_existing fwios.metric_observations%rowtype;
  v_source_ids uuid[];
  v_evidence_ids text[];
  v_sync jsonb;
begin
  if not coalesce(p_human_authorized,false) then
    return jsonb_build_object('status','BLOCKED','reason','HUMAN_AUTHORIZATION_REQUIRED',
                              'production_changes','NONE','auto_trade',false);
  end if;
  v_preview:=fwios.preview_metric_derivation_v1(
    p_ticker,p_formula,p_source_observation_keys,p_period_type,p_fiscal_year,p_fiscal_quarter,
    p_period_start,p_period_end,p_as_of_date
  );
  if coalesce(v_preview->>'status','BLOCKED')<>'PASS' then
    return jsonb_build_object('status','BLOCKED','reason','DERIVATION_PREVIEW_NOT_PASS','preview',v_preview,
                              'production_changes','NONE','auto_trade',false);
  end if;

  select * into v_existing
  from fwios.metric_observations
  where observation_key=v_preview->>'observation_key';

  if found then
    if v_existing.instrument_id=(v_preview->>'instrument_id')::uuid
       and v_existing.metric_code=v_preview->>'metric_code'
       and v_existing.value_numeric=(v_preview->>'value_numeric')::numeric
       and v_existing.provenance_status='PASS'
       and v_existing.quality_gate='PASS'
    then
      v_sync:=fwios.sync_metric_lineage_v1(p_ticker);
      return jsonb_build_object('status','NOOP_ALREADY_APPLIED','ticker',upper(btrim(p_ticker)),
        'observation_id',v_existing.observation_id,'observation_key',v_existing.observation_key,
        'metric_code',v_existing.metric_code,'value_numeric',v_existing.value_numeric,
        'lineage_sync',v_sync,'production_changes','NONE','auto_trade',false);
    end if;
    return jsonb_build_object('status','BLOCKED','reason','DERIVATION_OBSERVATION_KEY_COLLISION',
                              'observation_key',v_preview->>'observation_key','production_changes','NONE','auto_trade',false);
  end if;

  select array_agg(o.observation_id order by o.observation_key) into v_source_ids
  from fwios.metric_observations o where o.observation_key=any(p_source_observation_keys);

  select array_agg(distinct x order by x) into v_evidence_ids
  from (
    select unnest(coalesce(o.evidence_ids,'{}'::text[])) x
    from fwios.metric_observations o where o.observation_key=any(p_source_observation_keys)
    union
    select o.primary_evidence_id
    from fwios.metric_observations o
    where o.observation_key=any(p_source_observation_keys) and o.primary_evidence_id is not null
  ) s where x is not null and btrim(x)<>'';

  insert into fwios.metric_observations(
    observation_key,instrument_id,metric_code,observation_layer,
    value_numeric,value_text,value_boolean,canonical_unit,
    source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
    period_start,period_end,as_of_date,period_label,reported_at,effective_at,
    normalization_version,derivation_method,source_observation_ids,
    primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
    valuation_model_id,provenance_status,quality_gate,raw_payload
  ) values (
    v_preview->>'observation_key',(v_preview->>'instrument_id')::uuid,v_preview->>'metric_code','DERIVED',
    (v_preview->>'value_numeric')::numeric,null,null,v_preview->>'canonical_unit',
    v_preview->>'value_numeric',v_preview->>'canonical_unit',p_period_type,p_fiscal_year,p_fiscal_quarter,
    p_period_start,p_period_end,coalesce(p_as_of_date,p_period_end),
    concat_ws(' ',p_period_type,p_fiscal_year,case when p_fiscal_quarter is null then null else 'Q'||p_fiscal_quarter end),
    nullif(v_preview->>'reported_at','')::timestamptz,now(),
    'CLEAN_ROOM_DERIVATION_V1',upper(btrim(p_formula)),coalesce(v_source_ids,'{}'::uuid[]),
    v_preview->>'primary_evidence_id',coalesce(v_evidence_ids,'{}'::text[]),
    'fwios.metric_observations',upper(btrim(p_formula))||':'||substr(md5(array_to_string(p_source_observation_keys,'|')),1,16),
    'CLEAN_ROOM_DERIVATION_V1',null,'PASS','PASS',
    jsonb_build_object('formula',upper(btrim(p_formula)),'source_observation_keys',to_jsonb(p_source_observation_keys),
                       'ticker_only_clean_room',true,'human_execution_only',true,'auto_trade',false)
  ) returning observation_id into v_obs_id;

  v_sync:=fwios.sync_metric_lineage_v1(p_ticker);

  return jsonb_build_object(
    'status','APPLIED','ticker',upper(btrim(p_ticker)),'observation_id',v_obs_id,
    'observation_key',v_preview->>'observation_key','metric_code',v_preview->>'metric_code',
    'value_numeric',(v_preview->>'value_numeric')::numeric,'lineage_sync',v_sync,
    'portfolio_mutation',false,'approval_mutation',false,'execution_mutation',false,'auto_trade',false
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION fwios.preview_metric_derivation_v1(p_ticker text, p_formula text, p_source_observation_keys text[], p_period_type text, p_fiscal_year integer DEFAULT NULL::integer, p_fiscal_quarter smallint DEFAULT NULL::smallint, p_period_start date DEFAULT NULL::date, p_period_end date DEFAULT NULL::date, p_as_of_date date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
declare
  v_ticker text := upper(btrim(coalesce(p_ticker,'')));
  v_formula text := upper(btrim(coalesce(p_formula,'')));
  v_instrument_id uuid;
  v_actual_count int;
  v_bad_count int;
  v_value numeric;
  v_metric_code text;
  v_unit text;
  v_primary_evidence_id text;
  v_reported_at timestamptz;
  v_source_ids uuid[];
  v_evidence_ids text[];
  v_key text;
  v_annual numeric;
  v_old_ytd numeric;
  v_new_ytd numeric;
  v_num numeric;
  v_den numeric;
begin
  if v_ticker='' or v_formula='' then
    return jsonb_build_object('status','BLOCKED','reason','TICKER_AND_FORMULA_REQUIRED');
  end if;
  if p_source_observation_keys is null or cardinality(p_source_observation_keys)=0 then
    return jsonb_build_object('status','BLOCKED','reason','SOURCE_OBSERVATIONS_REQUIRED','ticker',v_ticker);
  end if;
  if cardinality(p_source_observation_keys) <> (
    select count(distinct x) from unnest(p_source_observation_keys) x
  ) then
    return jsonb_build_object('status','BLOCKED','reason','DUPLICATE_SOURCE_OBSERVATION_KEY','ticker',v_ticker);
  end if;
  if p_as_of_date is not null and p_as_of_date>current_date then
    return jsonb_build_object('status','BLOCKED','reason','FUTURE_AS_OF_DATE','ticker',v_ticker);
  end if;

  v_instrument_id := fwios.resolve_instrument_id_v1(v_ticker,'Stock',null,null);
  if v_instrument_id is null then
    return jsonb_build_object('status','BLOCKED','reason','TICKER_NOT_RESOLVED','ticker',v_ticker);
  end if;

  select count(*),array_agg(o.observation_id order by o.observation_key),max(o.reported_at)
    into v_actual_count,v_source_ids,v_reported_at
  from fwios.metric_observations o
  where o.observation_key=any(p_source_observation_keys)
    and o.instrument_id=v_instrument_id;

  if v_actual_count<>cardinality(p_source_observation_keys) then
    return jsonb_build_object('status','BLOCKED','reason','SOURCE_OBSERVATION_MISSING_OR_WRONG_INSTRUMENT',
                              'ticker',v_ticker,'expected',cardinality(p_source_observation_keys),'resolved',v_actual_count);
  end if;

  select count(*) into v_bad_count
  from fwios.metric_observations o
  where o.observation_key=any(p_source_observation_keys)
    and (
      o.provenance_status<>'PASS' or coalesce(o.quality_gate,'BLOCKED')<>'PASS' or
      o.primary_evidence_id is null or
      not exists(
        select 1 from fwios.evidence_records e
        where e.evidence_id=o.primary_evidence_id
          and (e.instrument_id=v_instrument_id or upper(coalesce(e.ticker,''))=v_ticker)
          and upper(coalesce(e.source_tier,''))='A'
          and upper(coalesce(e.verification_status,'')) in ('VERIFIED','PASS')
          and upper(coalesce(e.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','')
          and e.source_url like 'https://%'
      )
    );
  if v_bad_count>0 then
    return jsonb_build_object('status','BLOCKED','reason','SOURCE_PROVENANCE_OR_QUALITY_FAILED',
                              'ticker',v_ticker,'bad_source_count',v_bad_count);
  end if;

  if v_formula='FCF_CFO_LESS_CAPEX_SOFTWARE' then
    v_metric_code:='FREE_CASH_FLOW'; v_unit:='USD B';
    if v_actual_count<>3 then
      return jsonb_build_object('status','BLOCKED','reason','FCF_REQUIRES_THREE_SOURCES','ticker',v_ticker);
    end if;
    if (select count(distinct metric_code) from fwios.metric_observations
        where observation_key=any(p_source_observation_keys)
          and metric_code in ('OPERATING_CASH_FLOW','CAPEX_PROPERTY_EQUIPMENT','CAPITALIZED_SOFTWARE'))<>3 then
      return jsonb_build_object('status','BLOCKED','reason','FCF_SOURCE_METRIC_SET_INVALID','ticker',v_ticker);
    end if;
    select
      max(value_numeric) filter(where metric_code='OPERATING_CASH_FLOW') -
      max(value_numeric) filter(where metric_code='CAPEX_PROPERTY_EQUIPMENT') -
      max(value_numeric) filter(where metric_code='CAPITALIZED_SOFTWARE')
      into v_value
    from fwios.metric_observations where observation_key=any(p_source_observation_keys);
    if v_value<=0 then
      return jsonb_build_object('status','BLOCKED','reason','DERIVED_FCF_NOT_POSITIVE','ticker',v_ticker,'value',v_value);
    end if;
  elsif v_formula='LTM_FCF_BRIDGE' then
    v_metric_code:='FREE_CASH_FLOW'; v_unit:='USD B';
    if v_actual_count<>3 or
       (select count(*) from fwios.metric_observations where observation_key=any(p_source_observation_keys) and metric_code='FREE_CASH_FLOW')<>3 then
      return jsonb_build_object('status','BLOCKED','reason','LTM_FCF_REQUIRES_THREE_FCF_SOURCES','ticker',v_ticker);
    end if;
    select value_numeric into v_annual
    from fwios.metric_observations
    where observation_key=any(p_source_observation_keys) and metric_code='FREE_CASH_FLOW' and period_type='YEAR'
    order by period_end desc nulls last limit 1;
    select value_numeric into v_old_ytd
    from fwios.metric_observations
    where observation_key=any(p_source_observation_keys) and metric_code='FREE_CASH_FLOW' and period_type='YTD'
    order by period_end asc nulls last limit 1;
    select value_numeric into v_new_ytd
    from fwios.metric_observations
    where observation_key=any(p_source_observation_keys) and metric_code='FREE_CASH_FLOW' and period_type='YTD'
    order by period_end desc nulls last limit 1;
    if v_annual is null or v_old_ytd is null or v_new_ytd is null or
       (select count(*) from fwios.metric_observations
        where observation_key=any(p_source_observation_keys) and metric_code='FREE_CASH_FLOW' and period_type='YTD')<>2 then
      return jsonb_build_object('status','BLOCKED','reason','LTM_FCF_PERIOD_SET_INVALID','ticker',v_ticker);
    end if;
    v_value:=v_annual-v_old_ytd+v_new_ytd;
    if v_value<=0 then
      return jsonb_build_object('status','BLOCKED','reason','DERIVED_LTM_FCF_NOT_POSITIVE','ticker',v_ticker,'value',v_value);
    end if;
  elsif v_formula='NET_CASH_CASH_INVESTMENTS_LESS_DEBT' then
    v_metric_code:='NET_CASH'; v_unit:='USD B';
    if v_actual_count<>2 or
       (select count(distinct metric_code) from fwios.metric_observations
        where observation_key=any(p_source_observation_keys)
          and metric_code in ('CASH_AND_INVESTMENTS','TOTAL_DEBT'))<>2 then
      return jsonb_build_object('status','BLOCKED','reason','NET_CASH_SOURCE_METRIC_SET_INVALID','ticker',v_ticker);
    end if;
    select max(value_numeric) filter(where metric_code='CASH_AND_INVESTMENTS'),
           max(value_numeric) filter(where metric_code='TOTAL_DEBT')
      into v_num,v_den
    from fwios.metric_observations where observation_key=any(p_source_observation_keys);
    v_value:=v_num-v_den;
  elsif v_formula='TAKE_RATE_REVENUE_OVER_GDV' then
    v_metric_code:='TAKE_RATE'; v_unit:='ratio';
    if v_actual_count<>2 or
       (select count(distinct metric_code) from fwios.metric_observations
        where observation_key=any(p_source_observation_keys)
          and metric_code in ('REVENUE','GROSS_DOLLAR_VOLUME'))<>2 then
      return jsonb_build_object('status','BLOCKED','reason','TAKE_RATE_SOURCE_METRIC_SET_INVALID','ticker',v_ticker);
    end if;
    select max(value_numeric) filter(where metric_code='REVENUE'),
           max(value_numeric) filter(where metric_code='GROSS_DOLLAR_VOLUME')
      into v_num,v_den
    from fwios.metric_observations where observation_key=any(p_source_observation_keys);
    if v_den is null or v_den<=0 or v_num is null or v_num<=0 then
      return jsonb_build_object('status','BLOCKED','reason','TAKE_RATE_NUMERATOR_OR_DENOMINATOR_INVALID','ticker',v_ticker);
    end if;
    v_value:=v_num/v_den;
    if v_value<=0 or v_value>=0.1 then
      return jsonb_build_object('status','BLOCKED','reason','TAKE_RATE_OUT_OF_PLAUSIBLE_RANGE','ticker',v_ticker,'value',v_value);
    end if;
  else
    return jsonb_build_object('status','BLOCKED','reason','UNSUPPORTED_DERIVATION_FORMULA','ticker',v_ticker,'formula',v_formula);
  end if;

  select e.evidence_id into v_primary_evidence_id
  from fwios.metric_observations o
  join fwios.evidence_records e on e.evidence_id=o.primary_evidence_id
  where o.observation_key=any(p_source_observation_keys)
  order by o.reported_at desc nulls last,e.created_at desc
  limit 1;

  select array_agg(distinct x order by x) into v_evidence_ids
  from (
    select unnest(coalesce(o.evidence_ids,'{}'::text[])) x
    from fwios.metric_observations o where o.observation_key=any(p_source_observation_keys)
    union
    select o.primary_evidence_id
    from fwios.metric_observations o
    where o.observation_key=any(p_source_observation_keys) and o.primary_evidence_id is not null
  ) s
  where x is not null and btrim(x)<>'';

  v_key := 'DERIVED_V1:'||v_ticker||':'||v_formula||':'||
           coalesce(p_period_type,'OTHER')||':'||coalesce(p_period_end::text,coalesce(p_as_of_date::text,''))||':'||
           substr(md5(array_to_string((select array_agg(x order by x) from unnest(p_source_observation_keys) x),'|')),1,16);

  return jsonb_build_object(
    'status','PASS','ticker',v_ticker,'instrument_id',v_instrument_id,'formula',v_formula,
    'observation_key',v_key,'metric_code',v_metric_code,'canonical_unit',v_unit,'value_numeric',v_value,
    'period_type',p_period_type,'fiscal_year',p_fiscal_year,'fiscal_quarter',p_fiscal_quarter,
    'period_start',p_period_start,'period_end',p_period_end,'as_of_date',coalesce(p_as_of_date,p_period_end),
    'reported_at',v_reported_at,'primary_evidence_id',v_primary_evidence_id,
    'evidence_ids',coalesce(to_jsonb(v_evidence_ids),'[]'::jsonb),
    'source_observation_ids',coalesce(to_jsonb(v_source_ids),'[]'::jsonb),
    'production_changes','NONE','auto_trade',false
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION fwios.sync_metric_lineage_v1(p_ticker text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
declare
  v_ticker text := upper(btrim(coalesce(p_ticker,'')));
  v_instrument_id uuid;
  v_obs fwios.metric_observations%rowtype;
  v_src fwios.metric_observations%rowtype;
  v_ev fwios.evidence_records%rowtype;
  v_metric_artifact uuid;
  v_src_artifact uuid;
  v_ev_artifact uuid;
  v_evidence_id text;
  v_source_id uuid;
  v_edges int := 0;
begin
  v_instrument_id := fwios.resolve_instrument_id_v1(v_ticker,'Stock',null,null);
  if v_instrument_id is null then
    return jsonb_build_object('status','BLOCKED','reason','TICKER_NOT_RESOLVED','ticker',v_ticker);
  end if;

  for v_obs in
    select *
    from fwios.metric_observations
    where instrument_id=v_instrument_id
      and provenance_status='PASS'
      and coalesce(quality_gate,'PASS')='PASS'
    order by created_at,observation_id
  loop
    insert into fwios.lineage_artifacts(
      artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
    ) values (
      'METRIC_OBS:'||v_obs.observation_id::text,'METRIC_OBSERVATION','fwios','metric_observations',
      v_obs.observation_id::text,v_instrument_id,'RESOLVED',
      jsonb_build_object('ticker',v_ticker,'metric_code',v_obs.metric_code,'observation_key',v_obs.observation_key)
    ) on conflict(artifact_key) do nothing;

    select artifact_id into v_metric_artifact
    from fwios.lineage_artifacts where artifact_key='METRIC_OBS:'||v_obs.observation_id::text;

    for v_evidence_id in
      select distinct x
      from unnest(
        coalesce(v_obs.evidence_ids,'{}'::text[]) ||
        case when v_obs.primary_evidence_id is null then '{}'::text[] else array[v_obs.primary_evidence_id] end
      ) x
      where x is not null and btrim(x)<>''
    loop
      select * into v_ev
      from fwios.evidence_records
      where evidence_id=v_evidence_id
        and (instrument_id=v_instrument_id or upper(coalesce(ticker,''))=v_ticker);
      if found then
        insert into fwios.lineage_artifacts(
          artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
        ) values (
          'EVIDENCE:'||v_evidence_id,'EVIDENCE','fwios','evidence_records',v_evidence_id,
          v_instrument_id,'RESOLVED',
          jsonb_build_object('ticker',v_ticker,'source_url',v_ev.source_url,'source_tier',v_ev.source_tier,
                             'verification_status',v_ev.verification_status,'canonical_metric_gate',v_ev.canonical_metric_gate)
        ) on conflict(artifact_key) do nothing;

        select artifact_id into v_ev_artifact
        from fwios.lineage_artifacts where artifact_key='EVIDENCE:'||v_evidence_id;

        insert into fwios.lineage_edges(
          from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
        )
        select v_ev_artifact,v_metric_artifact,'EVIDENCE_SUPPORTS_METRIC',v_obs.metric_code,'RESOLVED',
               coalesce(v_ev.source_url,v_obs.source_reference),
               jsonb_build_object('observation_key',v_obs.observation_key)
        where not exists(
          select 1 from fwios.lineage_edges e
          where e.from_artifact_id=v_ev_artifact and e.to_artifact_id=v_metric_artifact
            and e.edge_type='EVIDENCE_SUPPORTS_METRIC' and e.edge_role=v_obs.metric_code
        );
        if found then v_edges := v_edges + 1; end if;
      end if;
    end loop;

    foreach v_source_id in array coalesce(v_obs.source_observation_ids,'{}'::uuid[])
    loop
      select * into v_src
      from fwios.metric_observations
      where observation_id=v_source_id and instrument_id=v_instrument_id;
      if found then
        insert into fwios.lineage_artifacts(
          artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
        ) values (
          'METRIC_OBS:'||v_source_id::text,'METRIC_OBSERVATION','fwios','metric_observations',
          v_source_id::text,v_instrument_id,'RESOLVED',
          jsonb_build_object('ticker',v_ticker,'metric_code',v_src.metric_code,'observation_key',v_src.observation_key)
        ) on conflict(artifact_key) do nothing;

        select artifact_id into v_src_artifact
        from fwios.lineage_artifacts where artifact_key='METRIC_OBS:'||v_source_id::text;

        insert into fwios.lineage_edges(
          from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
        )
        select v_src_artifact,v_metric_artifact,'METRIC_DERIVES_METRIC',v_obs.derivation_method,'RESOLVED',
               v_obs.source_reference,jsonb_build_object('output_metric_code',v_obs.metric_code)
        where not exists(
          select 1 from fwios.lineage_edges e
          where e.from_artifact_id=v_src_artifact and e.to_artifact_id=v_metric_artifact
            and e.edge_type='METRIC_DERIVES_METRIC' and e.edge_role=v_obs.derivation_method
        );
        if found then v_edges := v_edges + 1; end if;
      end if;
    end loop;
  end loop;

  return jsonb_build_object(
    'status','PASS','ticker',v_ticker,'instrument_id',v_instrument_id,
    'lineage_edges_added',v_edges,'auto_trade',false,'portfolio_mutation',false
  );
end;
$function$
;
