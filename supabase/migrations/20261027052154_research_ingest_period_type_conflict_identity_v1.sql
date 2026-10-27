-- Period-aware conflict identity fix for controlled research ingest replay.
-- Prevents QUARTER and YTD facts sharing period_end from being misclassified as conflicts.

CREATE OR REPLACE FUNCTION fwios.preview_research_ingest_v1(p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_schema_version text := trim(coalesce(p_payload->>'schema_version',''));
  v_mode text := upper(trim(coalesce(p_payload->>'mode','')));
  v_ticker text := upper(trim(coalesce(p_payload->>'ticker','')));
  v_research_as_of timestamptz := fwios.research_try_timestamptz_v1(p_payload->>'research_as_of');
  v_instrument_id uuid;
  v_payload_fingerprint text := md5(coalesce(p_payload,'{}'::jsonb)::text);
  v_blockers jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_evidence_results jsonb := '[]'::jsonb;
  v_metric_results jsonb := '[]'::jsonb;
  v_evidence_map jsonb := '{}'::jsonb;
  v_item jsonb;
  v_metric jsonb;
  v_reasons jsonb;
  v_ref text;
  v_evidence_id text;
  v_fact_class text;
  v_source_type text;
  v_source_tier text;
  v_tier_rank integer;
  v_retrieved_at timestamptz;
  v_reported_at timestamptz;
  v_route record;
  v_status text;
  v_metric_code text;
  v_def record;
  v_value_count integer;
  v_value_numeric numeric;
  v_value_text text;
  v_value_boolean boolean;
  v_source_unit text;
  v_period_type text;
  v_fiscal_year integer;
  v_fiscal_quarter smallint;
  v_period_start date;
  v_period_end date;
  v_as_of_date date;
  v_metric_reported_at timestamptz;
  v_evidence_refs jsonb;
  v_evidence_ref text;
  v_primary_ref text;
  v_primary_evidence_id text;
  v_primary_tier integer;
  v_observation_key text;
  v_conflict boolean;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return jsonb_build_object(
      'schema_version','research_ingest_preview_v1',
      'overall_status','BLOCKED',
      'blockers',jsonb_build_array('PAYLOAD_MUST_BE_JSON_OBJECT'),
      'production_changes','NONE'
    );
  end if;

  if v_schema_version <> 'chatgpt_research_payload_v1' then
    v_blockers := v_blockers || jsonb_build_array('INVALID_OR_MISSING_SCHEMA_VERSION');
  end if;

  if v_mode not in ('PREVIEW','APPLY') then
    v_blockers := v_blockers || jsonb_build_array('INVALID_OR_MISSING_MODE');
  end if;

  if v_ticker = '' then
    v_blockers := v_blockers || jsonb_build_array('MISSING_TICKER');
  else
    v_instrument_id := fwios.resolve_instrument_id_v1(v_ticker,'Stock',null,null);
    if v_instrument_id is null then
      v_blockers := v_blockers || jsonb_build_array('TICKER_NOT_RESOLVED_TO_ACTIVE_STOCK_INSTRUMENT');
    end if;
  end if;

  if v_research_as_of is null then
    v_blockers := v_blockers || jsonb_build_array('INVALID_OR_MISSING_RESEARCH_AS_OF');
  elsif v_research_as_of > now() + interval '10 minutes' then
    v_blockers := v_blockers || jsonb_build_array('RESEARCH_AS_OF_IN_FUTURE');
  end if;

  if coalesce(jsonb_typeof(p_payload->'evidence'),'null') <> 'array'
     or jsonb_array_length(coalesce(p_payload->'evidence','[]'::jsonb)) = 0 then
    v_blockers := v_blockers || jsonb_build_array('EVIDENCE_ARRAY_REQUIRED');
  end if;

  if p_payload ? 'metrics'
     and coalesce(jsonb_typeof(p_payload->'metrics'),'null') <> 'array' then
    v_blockers := v_blockers || jsonb_build_array('METRICS_MUST_BE_ARRAY');
  end if;

  if p_payload ? 'risks'
     and coalesce(jsonb_typeof(p_payload->'risks'),'null') <> 'array' then
    v_blockers := v_blockers || jsonb_build_array('RISKS_MUST_BE_ARRAY');
  end if;

  if p_payload ? 'guidance'
     and coalesce(jsonb_typeof(p_payload->'guidance'),'null') <> 'array' then
    v_blockers := v_blockers || jsonb_build_array('GUIDANCE_MUST_BE_ARRAY');
  end if;

  if p_payload ? 'research_summary'
     and coalesce(jsonb_typeof(p_payload->'research_summary'),'null') <> 'object' then
    v_blockers := v_blockers || jsonb_build_array('RESEARCH_SUMMARY_MUST_BE_OBJECT');
  end if;

  if jsonb_typeof(coalesce(p_payload->'evidence','[]'::jsonb))='array' then
    for v_item in
      select value from jsonb_array_elements(coalesce(p_payload->'evidence','[]'::jsonb))
    loop
      v_reasons := '[]'::jsonb;
      v_ref := trim(coalesce(v_item->>'evidence_ref',''));
      v_fact_class := upper(trim(coalesce(v_item->>'fact_class','')));
      v_source_type := upper(trim(coalesce(v_item->>'source_type','')));
      v_source_tier := upper(trim(coalesce(v_item->>'source_tier','')));
      v_tier_rank := fwios.research_source_tier_rank_v1(v_source_tier);
      v_retrieved_at := fwios.research_try_timestamptz_v1(v_item->>'retrieved_at');
      v_reported_at := fwios.research_try_timestamptz_v1(v_item->>'reported_at');

      if v_ref = '' then
        v_reasons := v_reasons || jsonb_build_array('MISSING_EVIDENCE_REF');
      elsif v_evidence_map ? v_ref then
        v_reasons := v_reasons || jsonb_build_array('DUPLICATE_EVIDENCE_REF');
      end if;

      if v_fact_class = '' then
        v_reasons := v_reasons || jsonb_build_array('MISSING_FACT_CLASS');
      else
        select r.*
          into v_route
        from fwios.source_routing_rules r
        where r.active=true
          and upper(r.fact_class)=v_fact_class
        order by r.routing_order
        limit 1;

        if not found then
          v_reasons := v_reasons || jsonb_build_array('UNSUPPORTED_FACT_CLASS');
        else
          if v_route.primary_source_required and v_tier_rank < 100 then
            v_reasons := v_reasons || jsonb_build_array('PRIMARY_TIER_REQUIRED');
          end if;
          if v_route.primary_source_required
             and v_source_type <> upper(v_route.preferred_source_type) then
            v_reasons := v_reasons || jsonb_build_array('PRIMARY_SOURCE_TYPE_REQUIRED');
          end if;
        end if;
      end if;

      if nullif(trim(coalesce(v_item->>'claim','')),'') is null then
        v_reasons := v_reasons || jsonb_build_array('MISSING_CLAIM');
      end if;

      if trim(coalesce(v_item->>'source_url','')) !~ '^https://[^[:space:]]+$' then
        v_reasons := v_reasons || jsonb_build_array('INVALID_SOURCE_URL');
      end if;

      if v_tier_rank = 0 then
        v_reasons := v_reasons || jsonb_build_array('UNKNOWN_SOURCE_TIER');
      end if;

      if v_retrieved_at is null then
        v_reasons := v_reasons || jsonb_build_array('INVALID_OR_MISSING_RETRIEVED_AT');
      elsif v_research_as_of is not null then
        if v_retrieved_at > v_research_as_of + interval '10 minutes' then
          v_reasons := v_reasons || jsonb_build_array('RETRIEVED_AFTER_RESEARCH_AS_OF');
        elsif v_research_as_of - v_retrieved_at > interval '7 days' then
          v_reasons := v_reasons || jsonb_build_array('STALE_RETRIEVAL_OVER_7_DAYS');
        end if;
      end if;

      if v_reported_at is null then
        v_reasons := v_reasons || jsonb_build_array('INVALID_OR_MISSING_REPORTED_AT');
      end if;

      if nullif(trim(coalesce(v_item->>'reporting_period','')),'') is null then
        v_reasons := v_reasons || jsonb_build_array('MISSING_REPORTING_PERIOD');
      end if;

      if upper(trim(coalesce(v_item->>'verification_status',''))) not in ('VERIFIED','PASS') then
        v_reasons := v_reasons || jsonb_build_array('EVIDENCE_NOT_VERIFIED');
      end if;

      if nullif(trim(coalesce(v_item->>'conflict_group','')),'') is not null then
        v_reasons := v_reasons || jsonb_build_array('UNRESOLVED_CONFLICT_GROUP');
      end if;

      v_evidence_id := case
        when v_instrument_id is null then null
        else fwios.research_evidence_id_v1(v_instrument_id,v_item)
      end;
      v_status := case when jsonb_array_length(v_reasons)=0 then 'PASS' else 'BLOCKED' end;

      v_evidence_results := v_evidence_results || jsonb_build_array(
        jsonb_build_object(
          'evidence_ref',nullif(v_ref,''),
          'evidence_id',v_evidence_id,
          'fact_class',nullif(v_fact_class,''),
          'source_tier',nullif(v_source_tier,''),
          'source_tier_rank',v_tier_rank,
          'status',v_status,
          'reasons',v_reasons
        )
      );

      if v_ref <> '' and not (v_evidence_map ? v_ref) then
        v_evidence_map := jsonb_set(
          v_evidence_map,
          array[v_ref],
          jsonb_build_object(
            'status',v_status,
            'evidence_id',v_evidence_id,
            'source_tier_rank',v_tier_rank,
            'fact_class',v_fact_class
          ),
          true
        );
      end if;

      if v_status='BLOCKED' then
        v_blockers := v_blockers || jsonb_build_array(
          jsonb_build_object('kind','EVIDENCE','ref',nullif(v_ref,''),'reasons',v_reasons)
        );
      end if;
    end loop;
  end if;

  if jsonb_typeof(coalesce(p_payload->'metrics','[]'::jsonb))='array' then
    for v_metric in
      select value from jsonb_array_elements(coalesce(p_payload->'metrics','[]'::jsonb))
    loop
      v_reasons := '[]'::jsonb;
      v_metric_code := upper(trim(coalesce(v_metric->>'metric_code','')));
      v_value_count :=
        (case when nullif(trim(coalesce(v_metric->>'value_numeric','')),'') is not null then 1 else 0 end) +
        (case when nullif(trim(coalesce(v_metric->>'value_text','')),'') is not null then 1 else 0 end) +
        (case when v_metric ? 'value_boolean' and jsonb_typeof(v_metric->'value_boolean')='boolean' then 1 else 0 end);
      v_source_unit := trim(coalesce(v_metric->>'source_unit',''));
      v_period_type := upper(trim(coalesce(v_metric->>'period_type','')));
      v_fiscal_year := case
        when trim(coalesce(v_metric->>'fiscal_year','')) ~ '^[0-9]{4}$'
        then (v_metric->>'fiscal_year')::integer
        else null
      end;
      v_fiscal_quarter := case
        when trim(coalesce(v_metric->>'fiscal_quarter','')) ~ '^[1-4]$'
        then (v_metric->>'fiscal_quarter')::smallint
        else null
      end;
      v_period_start := fwios.research_try_date_v1(v_metric->>'period_start');
      v_period_end := fwios.research_try_date_v1(v_metric->>'period_end');
      v_as_of_date := fwios.research_try_date_v1(v_metric->>'as_of_date');
      v_metric_reported_at := fwios.research_try_timestamptz_v1(v_metric->>'reported_at');
      v_value_numeric := null;
      v_value_text := null;
      v_value_boolean := null;
      v_primary_ref := null;
      v_primary_evidence_id := null;
      v_primary_tier := 0;

      if v_metric_code = '' then
        v_reasons := v_reasons || jsonb_build_array('MISSING_METRIC_CODE');
      else
        select d.*
          into v_def
        from fwios.metric_definitions d
        where d.metric_code=v_metric_code
          and d.active=true;

        if not found then
          v_reasons := v_reasons || jsonb_build_array('UNKNOWN_OR_INACTIVE_METRIC_CODE');
        else
          if v_value_count <> 1 then
            v_reasons := v_reasons || jsonb_build_array('EXACTLY_ONE_TYPED_VALUE_REQUIRED');
          elsif v_def.value_kind='NUMERIC' then
            if nullif(trim(coalesce(v_metric->>'value_numeric','')),'') is null then
              v_reasons := v_reasons || jsonb_build_array('NUMERIC_VALUE_REQUIRED');
            else
              v_value_numeric := fwios.canonical_metric_numeric_v2(v_metric->>'value_numeric',v_source_unit);
              if v_value_numeric is null then
                v_reasons := v_reasons || jsonb_build_array('INVALID_NUMERIC_VALUE');
              end if;
            end if;

            if v_source_unit='' then
              v_reasons := v_reasons || jsonb_build_array('SOURCE_UNIT_REQUIRED');
            elsif fwios.canonical_metric_unit_v2(v_source_unit,v_metric_code) <> v_def.canonical_unit then
              v_reasons := v_reasons || jsonb_build_array('UNIT_NOT_COMPATIBLE_WITH_CANONICAL_METRIC');
            end if;
          elsif v_def.value_kind='TEXT' then
            v_value_text := nullif(v_metric->>'value_text','');
            if v_value_text is null then
              v_reasons := v_reasons || jsonb_build_array('TEXT_VALUE_REQUIRED');
            end if;
          elsif v_def.value_kind='BOOLEAN' then
            if not (v_metric ? 'value_boolean' and jsonb_typeof(v_metric->'value_boolean')='boolean') then
              v_reasons := v_reasons || jsonb_build_array('BOOLEAN_VALUE_REQUIRED');
            else
              v_value_boolean := (v_metric->>'value_boolean')::boolean;
            end if;
          end if;

          if upper(v_def.canonical_unit) like 'USD%'
             and upper(trim(coalesce(v_metric->>'currency',''))) <> 'USD' then
            v_reasons := v_reasons || jsonb_build_array('USD_CURRENCY_REQUIRED');
          end if;
        end if;
      end if;

      if v_period_type not in (
        'QUARTER','YEAR','YTD','LTM','INSTANT','GUIDANCE',
        'STRUCTURAL','SCENARIO','MATERIAL_EVENT','OTHER'
      ) then
        v_reasons := v_reasons || jsonb_build_array('INVALID_OR_MISSING_PERIOD_TYPE');
      end if;

      if v_metric ? 'fiscal_year'
         and nullif(trim(coalesce(v_metric->>'fiscal_year','')),'') is not null
         and v_fiscal_year is null then
        v_reasons := v_reasons || jsonb_build_array('INVALID_FISCAL_YEAR');
      end if;

      if v_metric ? 'fiscal_quarter'
         and nullif(trim(coalesce(v_metric->>'fiscal_quarter','')),'') is not null
         and v_fiscal_quarter is null then
        v_reasons := v_reasons || jsonb_build_array('INVALID_FISCAL_QUARTER');
      end if;

      if v_period_type='QUARTER' and (v_fiscal_year is null or v_fiscal_quarter is null) then
        v_reasons := v_reasons || jsonb_build_array('QUARTER_REQUIRES_FISCAL_YEAR_AND_QUARTER');
      elsif v_period_type='YEAR' and v_fiscal_year is null then
        v_reasons := v_reasons || jsonb_build_array('YEAR_REQUIRES_FISCAL_YEAR');
      end if;

      if nullif(trim(coalesce(v_metric->>'period_label','')),'') is null
         and v_period_end is null
         and v_as_of_date is null then
        v_reasons := v_reasons || jsonb_build_array('PERIOD_CONTEXT_REQUIRED');
      end if;

      if v_metric_reported_at is null then
        v_reasons := v_reasons || jsonb_build_array('INVALID_OR_MISSING_METRIC_REPORTED_AT');
      end if;

      v_evidence_refs := coalesce(v_metric->'evidence_refs','[]'::jsonb);
      if jsonb_typeof(v_evidence_refs) <> 'array'
         or jsonb_array_length(v_evidence_refs)=0 then
        v_reasons := v_reasons || jsonb_build_array('METRIC_EVIDENCE_REFS_REQUIRED');
      else
        for v_evidence_ref in
          select value from jsonb_array_elements_text(v_evidence_refs)
        loop
          if not (v_evidence_map ? v_evidence_ref) then
            v_reasons := v_reasons || jsonb_build_array('UNKNOWN_EVIDENCE_REF:'||v_evidence_ref);
          elsif v_evidence_map->v_evidence_ref->>'status' <> 'PASS' then
            v_reasons := v_reasons || jsonb_build_array('BLOCKED_EVIDENCE_REF:'||v_evidence_ref);
          else
            if v_primary_ref is null then
              v_primary_ref := v_evidence_ref;
              v_primary_evidence_id := v_evidence_map->v_evidence_ref->>'evidence_id';
              v_primary_tier := coalesce((v_evidence_map->v_evidence_ref->>'source_tier_rank')::integer,0);
            end if;
          end if;
        end loop;
      end if;

      if v_primary_ref is not null and v_primary_tier < 100 then
        v_reasons := v_reasons || jsonb_build_array('METRIC_REQUIRES_PRIMARY_TIER_EVIDENCE');
      end if;

      v_conflict := false;
      if v_instrument_id is not null
         and v_metric_code <> ''
         and v_primary_evidence_id is not null
         and jsonb_array_length(v_reasons)=0 then
        select exists(
          select 1
          from fwios.metric_observations o
          left join fwios.evidence_records e on e.evidence_id=o.primary_evidence_id
          where o.instrument_id=v_instrument_id
            and o.metric_code=v_metric_code
            and upper(coalesce(e.verification_status,'')) in ('VERIFIED','PASS')
            and (
              (v_period_type='QUARTER' and o.period_type='QUARTER'
                and o.fiscal_year=v_fiscal_year and o.fiscal_quarter=v_fiscal_quarter)
              or
              (v_period_type='YEAR' and o.period_type='YEAR'
                and o.fiscal_year=v_fiscal_year)
              or
              (v_period_type not in ('QUARTER','YEAR')
                and o.period_type=v_period_type
                and (
                  (v_period_end is not null and o.period_end=v_period_end)
                  or (v_as_of_date is not null and o.as_of_date=v_as_of_date)
                  or (nullif(trim(coalesce(v_metric->>'period_label','')),'') is not null
                      and o.period_label=v_metric->>'period_label')
                ))
            )
            and (
              (v_def.value_kind='NUMERIC' and o.value_numeric is distinct from v_value_numeric)
              or (v_def.value_kind='TEXT' and o.value_text is distinct from v_value_text)
              or (v_def.value_kind='BOOLEAN' and o.value_boolean is distinct from v_value_boolean)
            )
        ) into v_conflict;

        if v_conflict then
          v_reasons := v_reasons || jsonb_build_array('CONFLICTING_VERIFIED_OBSERVATION');
        end if;
      end if;

      v_observation_key := case
        when v_instrument_id is null or v_metric_code='' or v_primary_evidence_id is null then null
        else fwios.research_observation_key_v1(v_instrument_id,v_metric,v_primary_evidence_id)
      end;
      v_status := case when jsonb_array_length(v_reasons)=0 then 'PASS' else 'BLOCKED' end;

      v_metric_results := v_metric_results || jsonb_build_array(
        jsonb_build_object(
          'metric_code',nullif(v_metric_code,''),
          'observation_key',v_observation_key,
          'primary_evidence_ref',v_primary_ref,
          'primary_evidence_id',v_primary_evidence_id,
          'canonical_value_numeric',v_value_numeric,
          'canonical_value_text',v_value_text,
          'canonical_value_boolean',v_value_boolean,
          'canonical_unit',case when v_def.metric_code is null then null else v_def.canonical_unit end,
          'status',v_status,
          'reasons',v_reasons
        )
      );

      if v_status='BLOCKED' then
        v_blockers := v_blockers || jsonb_build_array(
          jsonb_build_object('kind','METRIC','metric_code',nullif(v_metric_code,''),'reasons',v_reasons)
        );
      end if;
    end loop;
  end if;

  if jsonb_array_length(coalesce(p_payload->'risks','[]'::jsonb)) > 0 then
    v_warnings := v_warnings || jsonb_build_array(
      'RISKS_RETAINED_IN_APPLY_RECEIPT_NOT_WRITTEN_TO_SCORING_TABLES'
    );
  end if;

  if jsonb_array_length(coalesce(p_payload->'guidance','[]'::jsonb)) > 0 then
    v_warnings := v_warnings || jsonb_build_array(
      'GUIDANCE_CONTEXT_RETAINED_IN_RECEIPT;_CANONICAL_GUIDANCE_REQUIRES_A_GUIDANCE_METRIC_WITH_PRIMARY_EVIDENCE'
    );
  end if;

  if coalesce(p_payload->'research_summary','{}'::jsonb) <> '{}'::jsonb then
    v_warnings := v_warnings || jsonb_build_array(
      'RESEARCH_SUMMARY_RETAINED_IN_APPLY_RECEIPT_NOT_WRITTEN_TO_SCORING_TABLES'
    );
  end if;

  return jsonb_build_object(
    'schema_version','research_ingest_preview_v1',
    'overall_status',case when jsonb_array_length(v_blockers)=0 then 'PASS' else 'BLOCKED' end,
    'payload_fingerprint',v_payload_fingerprint,
    'request_mode',nullif(v_mode,''),
    'ticker',nullif(v_ticker,''),
    'instrument_id',v_instrument_id,
    'research_as_of',v_research_as_of,
    'evidence',v_evidence_results,
    'metrics',v_metric_results,
    'blockers',v_blockers,
    'warnings',v_warnings,
    'summary',jsonb_build_object(
      'evidence_count',jsonb_array_length(v_evidence_results),
      'metric_count',jsonb_array_length(v_metric_results),
      'blocker_count',jsonb_array_length(v_blockers),
      'warning_count',jsonb_array_length(v_warnings)
    ),
    'production_changes','NONE'
  );
end
$function$
;
