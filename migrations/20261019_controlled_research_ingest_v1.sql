-- PR2 Controlled Research Ingestion v1
-- Stacked after CHATGPT_RESEARCH_WORKFLOW_V1.
-- Adds a fail-closed PREVIEW/APPLY gateway without changing scanner, scoring,
-- lifecycle state, portfolio accounting, approval, or execution.

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status,updated_at
) values (
  'CONTROLLED_RESEARCH_INGEST',
  'RESEARCH',
  'Controlled Research Ingestion v1',
  'Validate structured ChatGPT research payloads before idempotent evidence/metric ingestion. No direct scoring, lifecycle, portfolio, approval, or execution mutation.',
  'fwios.preview_research_ingest_v1 / fwios.apply_research_ingest_v1',
  'ACTIVE',
  now()
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
) values (
  'POL-CONTROLLED-RESEARCH-INGEST-V1',
  'CONTROLLED_RESEARCH_INGEST',
  '1.0',
  'ACTIVE',
  true,
  $json$
  {
    "payload_schema": "chatgpt_research_payload_v1",
    "preview_mutates": false,
    "apply_requires_explicit_mode": "APPLY",
    "direct_table_write_fallback": false,
    "canonical_identity_required": true,
    "critical_primary_evidence_required": true,
    "metric_primary_evidence_required": true,
    "unknown_metric_fails_closed": true,
    "conflicting_verified_metric_fails_closed": true,
    "idempotency_keys": ["payload_fingerprint", "evidence_id", "observation_key"],
    "existing_rows_are_never_overwritten": true,
    "research_candidates_mutated": false,
    "scanner_score_mutated": false,
    "portfolio_mutation": false,
    "approval_mutation": false,
    "execution_mutation": false,
    "human_execution_only": true,
    "auto_trade": false
  }
  $json$::jsonb,
  'docs/implementation/CHATGPT_RESEARCH_WORKFLOW_V1.md; PR2 Controlled Research Ingestion v1',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status=excluded.lifecycle_status,
  deterministic_scoring=excluded.deterministic_scoring,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

create table if not exists fwios.research_ingest_receipts_v1 (
  receipt_id uuid primary key default gen_random_uuid(),
  payload_fingerprint text not null unique,
  ticker text not null,
  instrument_id uuid not null references fwios.instruments(instrument_id) on delete restrict,
  research_as_of timestamptz not null,
  request_mode text not null check (request_mode='APPLY'),
  status text not null check (status='APPLIED'),
  evidence_inserted integer not null default 0 check (evidence_inserted >= 0),
  evidence_existing integer not null default 0 check (evidence_existing >= 0),
  observations_inserted integer not null default 0 check (observations_inserted >= 0),
  observations_existing integer not null default 0 check (observations_existing >= 0),
  payload jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  applied_at timestamptz not null default now()
);

alter table fwios.research_ingest_receipts_v1 enable row level security;
revoke all on fwios.research_ingest_receipts_v1 from public,anon,authenticated;
grant select,insert on fwios.research_ingest_receipts_v1 to service_role;

create or replace function fwios.research_source_tier_rank_v1(p_tier text)
returns integer
language sql
immutable
security invoker
set search_path to ''
as $function$
  select case upper(trim(coalesce(p_tier,'')))
    when 'OFFICIAL_LICENSED' then 120
    when 'OFFICIAL_ANNOUNCEMENT' then 115
    when 'A' then 100
    when 'TIER_A' then 100
    when 'PRIMARY' then 100
    when 'WEB_PRIMARY' then 100
    when 'A/B' then 80
    when 'B' then 70
    when 'TIER_B' then 70
    when 'SECONDARY' then 60
    when 'TRACKER_PROXY' then 50
    when 'MANUAL_VERIFIED' then 40
    else 0
  end;
$function$;

create or replace function fwios.research_try_timestamptz_v1(p_text text)
returns timestamptz
language plpgsql
immutable
security invoker
set search_path to ''
as $function$
begin
  if nullif(trim(coalesce(p_text,'')),'') is null then
    return null;
  end if;
  return trim(p_text)::timestamptz;
exception when others then
  return null;
end
$function$;

create or replace function fwios.research_try_date_v1(p_text text)
returns date
language plpgsql
immutable
security invoker
set search_path to ''
as $function$
begin
  if nullif(trim(coalesce(p_text,'')),'') is null then
    return null;
  end if;
  return trim(p_text)::date;
exception when others then
  return null;
end
$function$;

create or replace function fwios.research_evidence_id_v1(
  p_instrument_id uuid,
  p_evidence jsonb
)
returns text
language sql
immutable
security invoker
set search_path to ''
as $function$
  select 'AI-EV-' || upper(substr(md5(concat_ws('|',
    coalesce(p_instrument_id::text,''),
    upper(trim(coalesce(p_evidence->>'fact_class',''))),
    lower(trim(coalesce(p_evidence->>'source_url',''))),
    trim(coalesce(p_evidence->>'reporting_period','')),
    lower(trim(coalesce(p_evidence->>'claim','')))
  )),1,24));
$function$;

create or replace function fwios.research_observation_key_v1(
  p_instrument_id uuid,
  p_metric jsonb,
  p_primary_evidence_id text
)
returns text
language sql
immutable
security invoker
set search_path to ''
as $function$
  select 'AI-OBS-' || upper(substr(md5(concat_ws('|',
    coalesce(p_instrument_id::text,''),
    upper(trim(coalesce(p_metric->>'metric_code',''))),
    upper(trim(coalesce(p_metric->>'period_type',''))),
    trim(coalesce(p_metric->>'fiscal_year','')),
    trim(coalesce(p_metric->>'fiscal_quarter','')),
    trim(coalesce(p_metric->>'period_end','')),
    trim(coalesce(p_metric->>'as_of_date','')),
    trim(coalesce(p_metric->>'period_label','')),
    coalesce(p_primary_evidence_id,'')
  )),1,24));
$function$;

create or replace function fwios.preview_research_ingest_v1(p_payload jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path to ''
as $function$
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
$function$;

create or replace function fwios.apply_research_ingest_v1(p_payload jsonb)
returns jsonb
language plpgsql
volatile
security invoker
set search_path to ''
as $function$
declare
  v_preview jsonb;
  v_payload_fingerprint text;
  v_ticker text;
  v_instrument_id uuid;
  v_research_as_of timestamptz;
  v_existing_receipt record;
  v_item jsonb;
  v_metric jsonb;
  v_evidence_id text;
  v_metric_code text;
  v_def record;
  v_primary_ref text;
  v_primary_evidence_id text;
  v_evidence_ref text;
  v_evidence_ids text[];
  v_observation_key text;
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
  v_receipt_id uuid := gen_random_uuid();
  v_evidence_inserted integer := 0;
  v_evidence_existing integer := 0;
  v_observations_inserted integer := 0;
  v_observations_existing integer := 0;
  v_rows integer;
  v_result jsonb;
begin
  v_preview := fwios.preview_research_ingest_v1(p_payload);

  if upper(trim(coalesce(p_payload->>'mode',''))) <> 'APPLY' then
    return jsonb_build_object(
      'status','APPLY_BLOCKED_EXPLICIT_MODE_REQUIRED',
      'production_changes','NONE',
      'preview',v_preview
    );
  end if;

  if coalesce(v_preview->>'overall_status','BLOCKED') <> 'PASS' then
    return jsonb_build_object(
      'status','APPLY_BLOCKED_VALIDATION',
      'production_changes','NONE',
      'preview',v_preview
    );
  end if;

  v_payload_fingerprint := v_preview->>'payload_fingerprint';
  v_ticker := v_preview->>'ticker';
  v_instrument_id := (v_preview->>'instrument_id')::uuid;
  v_research_as_of := (v_preview->>'research_as_of')::timestamptz;

  select r.*
    into v_existing_receipt
  from fwios.research_ingest_receipts_v1 r
  where r.payload_fingerprint=v_payload_fingerprint;

  if found then
    return v_existing_receipt.result || jsonb_build_object(
      'status','NOOP_ALREADY_APPLIED',
      'receipt_id',v_existing_receipt.receipt_id,
      'production_changes','NONE'
    );
  end if;

  for v_item in
    select value from jsonb_array_elements(coalesce(p_payload->'evidence','[]'::jsonb))
  loop
    v_evidence_id := fwios.research_evidence_id_v1(v_instrument_id,v_item);

    insert into fwios.evidence_records(
      evidence_id,run_id,ticker,retrieved_at_text,evidence_date_text,period,
      data_type,metric_label,value_text,unit,direction,source_id,source_tier,
      source_url,published_at_text,evidence_role,evidence_class,confidence,
      comparable_status,conflict_status,verification_status,freshness_status,
      used_by,ai_note,retrieval_method,machine_status,metric_id,
      canonical_value_type,derivation_method,derivation_inputs,
      canonical_metric_gate,raw_payload,instrument_id
    ) values (
      v_evidence_id,
      'CHATGPT-RESEARCH-'||upper(substr(v_payload_fingerprint,1,16)),
      v_ticker,
      v_item->>'retrieved_at',
      v_item->>'reported_at',
      v_item->>'reporting_period',
      upper(trim(v_item->>'fact_class')),
      v_item->>'claim',
      v_item->>'claim',
      null,
      null,
      coalesce(nullif(v_item->>'source_name',''),v_item->>'evidence_ref'),
      upper(trim(v_item->>'source_tier')),
      v_item->>'source_url',
      v_item->>'reported_at',
      'RESEARCH_INPUT',
      upper(trim(v_item->>'fact_class')),
      'VERIFIED',
      'NOT_ASSESSED',
      'NO_CONFLICT',
      upper(trim(v_item->>'verification_status')),
      'FRESH',
      'CONTROLLED_RESEARCH_INGEST_V1',
      nullif(v_item->>'notes',''),
      'CHATGPT_RESEARCH_GATEWAY_V1',
      'PASS',
      null,
      null,
      null,
      null,
      'PASS',
      coalesce(v_item,'{}'::jsonb) || jsonb_build_object(
        'gateway','CONTROLLED_RESEARCH_INGEST_V1',
        'payload_fingerprint',v_payload_fingerprint,
        'research_as_of',v_research_as_of
      ),
      v_instrument_id
    )
    on conflict(evidence_id) do nothing;

    get diagnostics v_rows = row_count;
    if v_rows=1 then
      v_evidence_inserted := v_evidence_inserted + 1;
    else
      v_evidence_existing := v_evidence_existing + 1;
    end if;
  end loop;

  for v_metric in
    select value from jsonb_array_elements(coalesce(p_payload->'metrics','[]'::jsonb))
  loop
    v_metric_code := upper(trim(v_metric->>'metric_code'));
    select d.* into v_def
    from fwios.metric_definitions d
    where d.metric_code=v_metric_code and d.active=true;

    v_evidence_ids := '{}'::text[];
    v_primary_ref := null;
    v_primary_evidence_id := null;

    for v_evidence_ref in
      select value from jsonb_array_elements_text(coalesce(v_metric->'evidence_refs','[]'::jsonb))
    loop
      select fwios.research_evidence_id_v1(v_instrument_id,e.value)
        into v_evidence_id
      from jsonb_array_elements(coalesce(p_payload->'evidence','[]'::jsonb)) e(value)
      where e.value->>'evidence_ref'=v_evidence_ref
      limit 1;

      if v_primary_ref is null then
        v_primary_ref := v_evidence_ref;
        v_primary_evidence_id := v_evidence_id;
      end if;
      v_evidence_ids := array_append(v_evidence_ids,v_evidence_id);
    end loop;

    v_observation_key := fwios.research_observation_key_v1(
      v_instrument_id,v_metric,v_primary_evidence_id
    );
    v_source_unit := trim(coalesce(v_metric->>'source_unit',''));
    v_period_type := upper(trim(v_metric->>'period_type'));
    v_fiscal_year := case
      when trim(coalesce(v_metric->>'fiscal_year','')) ~ '^[0-9]{4}$'
      then (v_metric->>'fiscal_year')::integer else null end;
    v_fiscal_quarter := case
      when trim(coalesce(v_metric->>'fiscal_quarter','')) ~ '^[1-4]$'
      then (v_metric->>'fiscal_quarter')::smallint else null end;
    v_period_start := fwios.research_try_date_v1(v_metric->>'period_start');
    v_period_end := fwios.research_try_date_v1(v_metric->>'period_end');
    v_as_of_date := fwios.research_try_date_v1(v_metric->>'as_of_date');
    v_metric_reported_at := fwios.research_try_timestamptz_v1(v_metric->>'reported_at');

    v_value_numeric := null;
    v_value_text := null;
    v_value_boolean := null;

    if v_def.value_kind='NUMERIC' then
      v_value_numeric := fwios.canonical_metric_numeric_v2(
        v_metric->>'value_numeric',v_source_unit
      );
    elsif v_def.value_kind='TEXT' then
      v_value_text := v_metric->>'value_text';
    elsif v_def.value_kind='BOOLEAN' then
      v_value_boolean := (v_metric->>'value_boolean')::boolean;
    end if;

    insert into fwios.metric_observations(
      observation_key,instrument_id,metric_code,observation_layer,
      value_numeric,value_text,value_boolean,canonical_unit,
      source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
      period_start,period_end,as_of_date,period_label,reported_at,effective_at,
      normalization_version,derivation_method,source_observation_ids,
      primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
      valuation_model_id,provenance_status,quality_gate,raw_payload
    ) values (
      v_observation_key,
      v_instrument_id,
      v_metric_code,
      case when v_period_type='GUIDANCE' then 'GUIDANCE' else 'REPORTED' end,
      v_value_numeric,
      v_value_text,
      v_value_boolean,
      v_def.canonical_unit,
      coalesce(v_metric->>'value_numeric',v_metric->>'value_text',v_metric->>'value_boolean'),
      nullif(v_source_unit,''),
      v_period_type,
      v_fiscal_year,
      v_fiscal_quarter,
      v_period_start,
      v_period_end,
      v_as_of_date,
      nullif(v_metric->>'period_label',''),
      v_metric_reported_at,
      v_research_as_of,
      'CONTROLLED_RESEARCH_INGEST_V1',
      case when v_period_type='GUIDANCE' then 'REPORTED_GUIDANCE' else 'REPORTED_DIRECT' end,
      '{}'::uuid[],
      v_primary_evidence_id,
      v_evidence_ids,
      'fwios.evidence_records',
      v_primary_evidence_id,
      'CHATGPT_RESEARCH_GATEWAY_V1',
      null,
      'PASS',
      'PASS',
      coalesce(v_metric,'{}'::jsonb) || jsonb_build_object(
        'gateway','CONTROLLED_RESEARCH_INGEST_V1',
        'payload_fingerprint',v_payload_fingerprint,
        'research_as_of',v_research_as_of
      )
    )
    on conflict(observation_key) do nothing;

    get diagnostics v_rows = row_count;
    if v_rows=1 then
      v_observations_inserted := v_observations_inserted + 1;
    else
      v_observations_existing := v_observations_existing + 1;
    end if;
  end loop;

  v_result := jsonb_build_object(
    'schema_version','research_ingest_apply_result_v1',
    'status','APPLIED',
    'receipt_id',v_receipt_id,
    'payload_fingerprint',v_payload_fingerprint,
    'ticker',v_ticker,
    'instrument_id',v_instrument_id,
    'research_as_of',v_research_as_of,
    'evidence_inserted',v_evidence_inserted,
    'evidence_existing',v_evidence_existing,
    'observations_inserted',v_observations_inserted,
    'observations_existing',v_observations_existing,
    'research_context_retained_in_receipt',true,
    'research_candidates_mutated',false,
    'scanner_score_mutated',false,
    'portfolio_mutation',false,
    'auto_trade',false,
    'human_execution_only',true
  );

  insert into fwios.research_ingest_receipts_v1(
    receipt_id,payload_fingerprint,ticker,instrument_id,research_as_of,
    request_mode,status,evidence_inserted,evidence_existing,
    observations_inserted,observations_existing,payload,result
  ) values (
    v_receipt_id,v_payload_fingerprint,v_ticker,v_instrument_id,v_research_as_of,
    'APPLY','APPLIED',v_evidence_inserted,v_evidence_existing,
    v_observations_inserted,v_observations_existing,p_payload,v_result
  )
  on conflict(payload_fingerprint) do nothing;

  get diagnostics v_rows = row_count;
  if v_rows=0 then
    select r.*
      into v_existing_receipt
    from fwios.research_ingest_receipts_v1 r
    where r.payload_fingerprint=v_payload_fingerprint;

    return v_existing_receipt.result || jsonb_build_object(
      'status','NOOP_ALREADY_APPLIED',
      'receipt_id',v_existing_receipt.receipt_id,
      'production_changes','NONE'
    );
  end if;

  return v_result;
end
$function$;

revoke execute on function fwios.research_source_tier_rank_v1(text) from public,anon,authenticated;
revoke execute on function fwios.research_try_timestamptz_v1(text) from public,anon,authenticated;
revoke execute on function fwios.research_try_date_v1(text) from public,anon,authenticated;
revoke execute on function fwios.research_evidence_id_v1(uuid,jsonb) from public,anon,authenticated;
revoke execute on function fwios.research_observation_key_v1(uuid,jsonb,text) from public,anon,authenticated;
revoke execute on function fwios.preview_research_ingest_v1(jsonb) from public,anon,authenticated;
revoke execute on function fwios.apply_research_ingest_v1(jsonb) from public,anon,authenticated;

grant execute on function fwios.research_source_tier_rank_v1(text) to service_role;
grant execute on function fwios.research_try_timestamptz_v1(text) to service_role;
grant execute on function fwios.research_try_date_v1(text) to service_role;
grant execute on function fwios.research_evidence_id_v1(uuid,jsonb) to service_role;
grant execute on function fwios.research_observation_key_v1(uuid,jsonb,text) to service_role;
grant execute on function fwios.preview_research_ingest_v1(jsonb) to service_role;
grant execute on function fwios.apply_research_ingest_v1(jsonb) to service_role;
