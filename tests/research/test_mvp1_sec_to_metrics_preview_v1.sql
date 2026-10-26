-- FWIOS MVP-1 SEC-to-Metrics PREVIEW regression
-- Non-mutating: all checks are reads plus PREVIEW RPC calls.

do $$
declare
  v_payload jsonb;
  v_preview1 jsonb;
  v_preview2 jsonb;
  v_bad jsonb;
  v_receipts_before bigint;
  v_evidence_before bigint;
  v_observations_before bigint;
  v_annual_revenue_count integer;
  v_q4_fp text;
  v_q4_frame text;
  v_revenue_b numeric;
  v_ocf_b numeric;
  v_capex_b numeric;
  v_fcf_b numeric;
  v_observed_at timestamptz;
  v_primary_document text;
  v_required text[];
begin
  select count(*) into v_receipts_before from fwios.research_ingest_receipts_v1;
  select count(*) into v_evidence_before from fwios.evidence_records;
  select count(*) into v_observations_before from fwios.metric_observations;

  select e.observed_at
    into v_observed_at
  from fwios.decision_refresh_shadow_evidence e
  where e.ticker='ACN'
    and e.fact_class='SEC_COMPANY_FACTS'
    and e.collection_status='PASS'
  order by e.observed_at desc
  limit 1;

  if v_observed_at is null then
    raise exception 'MVP1-SEC-01: latest ACN SEC_COMPANY_FACTS SHADOW row missing';
  end if;

  select f->>'primary_document'
    into v_primary_document
  from fwios.decision_refresh_shadow_evidence e
  cross join lateral jsonb_array_elements(coalesce(e.payload->'latest_filings','[]'::jsonb)) f
  where e.ticker='ACN'
    and e.fact_class='SEC_SUBMISSIONS'
    and e.collection_status='PASS'
    and f->>'form'='10-K'
    and f->>'accession_number'='0001467373-26-000049'
  order by e.observed_at desc
  limit 1;

  if v_primary_document <> 'acn-20260831.htm' then
    raise exception 'MVP1-SEC-02: target FY2026 10-K primary document not resolved';
  end if;

  with latest as (
    select payload
    from fwios.decision_refresh_shadow_evidence
    where ticker='ACN'
      and fact_class='SEC_COMPANY_FACTS'
      and collection_status='PASS'
    order by observed_at desc
    limit 1
  ), rows as (
    select r
    from latest
    cross join lateral jsonb_array_elements(
      coalesce(payload->'facts'->'Revenues'->'units'->'USD','[]'::jsonb)
    ) r
    where r->>'form'='10-K'
      and r->>'accn'='0001467373-26-000049'
  )
  select
    count(*) filter (
      where r->>'start'='2025-09-01' and r->>'end'='2026-08-31'
    ),
    max(r->>'fp') filter (
      where r->>'start'='2026-06-01' and r->>'end'='2026-08-31'
    ),
    max(r->>'frame') filter (
      where r->>'start'='2026-06-01' and r->>'end'='2026-08-31'
    )
  into v_annual_revenue_count, v_q4_fp, v_q4_frame
  from rows;

  if v_annual_revenue_count <> 1 then
    raise exception 'MVP1-SEC-03: exact annual revenue row is not unique';
  end if;
  if v_q4_fp <> 'FY' or v_q4_frame <> 'CY2026Q3' then
    raise exception 'MVP1-SEC-04: fixture no longer proves FP/frame cannot identify ACN fiscal Q4 safely';
  end if;

  with latest as (
    select payload
    from fwios.decision_refresh_shadow_evidence
    where ticker='ACN'
      and fact_class='SEC_COMPANY_FACTS'
      and collection_status='PASS'
    order by observed_at desc
    limit 1
  )
  select
    (
      select (r->>'val')::numeric/1000000000.0
      from jsonb_array_elements(coalesce(payload->'facts'->'Revenues'->'units'->'USD','[]'::jsonb)) r
      where r->>'form'='10-K' and r->>'accn'='0001467373-26-000049'
        and r->>'start'='2025-09-01' and r->>'end'='2026-08-31'
      limit 1
    ),
    (
      select (r->>'val')::numeric/1000000000.0
      from jsonb_array_elements(coalesce(payload->'facts'->'NetCashProvidedByUsedInOperatingActivities'->'units'->'USD','[]'::jsonb)) r
      where r->>'form'='10-K' and r->>'accn'='0001467373-26-000049'
        and r->>'start'='2025-09-01' and r->>'end'='2026-08-31'
      limit 1
    ),
    (
      select (r->>'val')::numeric/1000000000.0
      from jsonb_array_elements(coalesce(payload->'facts'->'PaymentsToAcquirePropertyPlantAndEquipment'->'units'->'USD','[]'::jsonb)) r
      where r->>'form'='10-K' and r->>'accn'='0001467373-26-000049'
        and r->>'start'='2025-09-01' and r->>'end'='2026-08-31'
      limit 1
    )
  into v_revenue_b, v_ocf_b, v_capex_b
  from latest;

  v_fcf_b := v_ocf_b-v_capex_b;
  if v_revenue_b <> 74.183445 or v_fcf_b <> 11.620598 then
    raise exception 'MVP1-SEC-05: ACN normalized annual arithmetic changed: revenue %, fcf %', v_revenue_b, v_fcf_b;
  end if;

  v_payload := jsonb_build_object(
    'schema_version','chatgpt_research_payload_v1',
    'mode','PREVIEW',
    'ticker','ACN',
    'research_as_of',to_jsonb(v_observed_at),
    'evidence',jsonb_build_array(
      jsonb_build_object(
        'evidence_ref','acn-10k-2026-0001467373-26-000049',
        'fact_class','REPORTED_FINANCIALS',
        'claim','ACN FY2026 10-K reports revenue USD 74.183445B, operating cash flow USD 12.363346B and capex USD 0.742748B for the year ended 2026-08-31.',
        'source_name','SEC EDGAR - Accenture plc FY2026 Form 10-K',
        'source_url','https://www.sec.gov/Archives/edgar/data/1467373/000146737326000049/acn-20260831.htm',
        'source_type','WEB_PRIMARY',
        'source_tier','A',
        'retrieved_at',to_jsonb(v_observed_at),
        'reported_at','2026-10-16T10:22:21Z',
        'reporting_period','FY2026 ended 2026-08-31',
        'verification_status','VERIFIED',
        'conflict_group',null
      )
    ),
    'metrics',jsonb_build_array(
      jsonb_build_object(
        'metric_code','REVENUE',
        'value_kind','NUMERIC',
        'value_numeric',v_revenue_b,
        'canonical_unit','USD B',
        'source_unit','USD B',
        'currency','USD',
        'period_type','LTM',
        'fiscal_year',2026,
        'period_start','2025-09-01',
        'period_end','2026-08-31',
        'as_of_date','2026-08-31',
        'period_label','LTM / FY2026 ended 2026-08-31',
        'reported_at','2026-10-16T10:22:21Z',
        'evidence_refs',jsonb_build_array('acn-10k-2026-0001467373-26-000049'),
        'verification_status','VERIFIED'
      ),
      jsonb_build_object(
        'metric_code','FREE_CASH_FLOW',
        'value_kind','NUMERIC',
        'value_numeric',v_fcf_b,
        'canonical_unit','USD B',
        'source_unit','USD B',
        'currency','USD',
        'period_type','LTM',
        'fiscal_year',2026,
        'period_start','2025-09-01',
        'period_end','2026-08-31',
        'as_of_date','2026-08-31',
        'period_label','LTM / FY2026 ended 2026-08-31',
        'reported_at','2026-10-16T10:22:21Z',
        'evidence_refs',jsonb_build_array('acn-10k-2026-0001467373-26-000049'),
        'verification_status','VERIFIED',
        'derivation_method','OCF_MINUS_CAPEX'
      )
    )
  );

  v_preview1 := fwios.preview_research_ingest_v1(v_payload);
  v_preview2 := fwios.preview_research_ingest_v1(v_payload);

  if v_preview1->>'overall_status' <> 'PASS'
     or v_preview1->>'production_changes' <> 'NONE'
     or (v_preview1->'summary'->>'metric_count')::integer <> 2 then
    raise exception 'MVP1-SEC-06: controlled PREVIEW did not pass: %', v_preview1;
  end if;

  if v_preview1->>'payload_fingerprint' <> v_preview2->>'payload_fingerprint'
     or v_preview1->'metrics'->0->>'observation_key' <> v_preview2->'metrics'->0->>'observation_key'
     or v_preview1->'metrics'->1->>'observation_key' <> v_preview2->'metrics'->1->>'observation_key' then
    raise exception 'MVP1-SEC-07: repeated PREVIEW is not deterministic';
  end if;

  v_bad := jsonb_set(v_payload,'{evidence,0,verification_status}','"UNVERIFIED"'::jsonb);
  if fwios.preview_research_ingest_v1(v_bad)->>'overall_status' <> 'BLOCKED' then
    raise exception 'MVP1-SEC-08: unverified evidence did not fail closed';
  end if;

  select required_metric_ids into v_required
  from fwios.valuation_models
  where model_id='IT_SERVICES_FCF_COMPOUNDER_V1'
    and production_status='IMPLEMENTED';

  if v_required is null then
    raise exception 'MVP1-SEC-09: supported ACN valuation model not found';
  end if;
  if not (v_required && array[
      'fcf_guidance_low','fcf_guidance_midpoint','fcf_guidance_high',
      'fy2026_revenue_growth_guidance_lc_mid','book_to_bill_q3',
      'operating_margin_q3','gross_margin_q3'
    ]::text[]) then
    raise exception 'MVP1-SEC-10: ACN model no longer exposes the period-specific rollover condition';
  end if;

  if exists (
    select 1 from fwios.valuation_models
    where model_id='MVP1_TEST_UNSUPPORTED_MODEL'
      and production_status='IMPLEMENTED'
  ) then
    raise exception 'MVP1-SEC-11: unsupported-model guard fixture unexpectedly became supported';
  end if;

  if (select count(*) from fwios.research_ingest_receipts_v1) <> v_receipts_before
     or (select count(*) from fwios.evidence_records) <> v_evidence_before
     or (select count(*) from fwios.metric_observations) <> v_observations_before then
    raise exception 'MVP1-SEC-12: PREVIEW mutated production research state';
  end if;
end $$;

select 'FWIOS MVP1 SEC-TO-METRICS PREVIEW: PASS (12/12, READ-ONLY)' as result;
