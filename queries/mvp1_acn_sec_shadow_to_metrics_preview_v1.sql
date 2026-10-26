-- FWIOS MVP-1 — ACN SEC SHADOW -> controlled research PREVIEW pilot
-- Read-only by design. This query does not APPLY, mutate production tables,
-- create schema, change cron, or recalculate valuation.
--
-- Purpose:
--   1) select the exact ACN FY2026 10-K from existing SEC SHADOW evidence;
--   2) normalize only unambiguous model-relevant facts available in SHADOW;
--   3) validate them through fwios.preview_research_ingest_v1(jsonb);
--   4) fail closed on valuation-model period rollover and missing inputs.
--
-- Pilot scope is intentionally fixed to ACN / FY2026 / accession
-- 0001467373-26-000049. Generalization comes only after this slice is accepted.

with target as (
  select
    'ACN'::text as ticker,
    '0001467373-26-000049'::text as accession_number,
    'IT_SERVICES_FCF_COMPOUNDER_V1'::text as model_id,
    2026::integer as fiscal_year,
    date '2025-09-01' as period_start,
    date '2026-08-31' as period_end
),
latest_submissions as (
  select e.*
  from fwios.decision_refresh_shadow_evidence e
  join target t on t.ticker=e.ticker
  where e.fact_class='SEC_SUBMISSIONS'
    and e.collection_status='PASS'
  order by e.observed_at desc
  limit 1
),
filing as (
  select
    f->>'form' as form,
    f->>'accession_number' as accession_number,
    (f->>'filing_date')::date as filing_date,
    (f->>'report_date')::date as report_date,
    f->>'accepted_at' as accepted_at,
    f->>'primary_document' as primary_document
  from latest_submissions s
  cross join lateral jsonb_array_elements(coalesce(s.payload->'latest_filings','[]'::jsonb)) f
  join target t on f->>'accession_number'=t.accession_number
  where f->>'form'='10-K'
  limit 1
),
latest_facts as (
  select e.*
  from fwios.decision_refresh_shadow_evidence e
  join target t on t.ticker=e.ticker
  where e.fact_class='SEC_COMPANY_FACTS'
    and e.collection_status='PASS'
  order by e.observed_at desc
  limit 1
),
revenue_candidates as (
  select r
  from latest_facts f
  cross join lateral jsonb_array_elements(
    coalesce(f.payload->'facts'->'Revenues'->'units'->'USD','[]'::jsonb)
  ) r
  cross join target t
  where r->>'accn'=t.accession_number
    and r->>'form'='10-K'
    and (r->>'start')::date=t.period_start
    and (r->>'end')::date=t.period_end
),
ocf_candidates as (
  select r
  from latest_facts f
  cross join lateral jsonb_array_elements(
    coalesce(f.payload->'facts'->'NetCashProvidedByUsedInOperatingActivities'->'units'->'USD','[]'::jsonb)
  ) r
  cross join target t
  where r->>'accn'=t.accession_number
    and r->>'form'='10-K'
    and (r->>'start')::date=t.period_start
    and (r->>'end')::date=t.period_end
),
capex_candidates as (
  select r
  from latest_facts f
  cross join lateral jsonb_array_elements(
    coalesce(f.payload->'facts'->'PaymentsToAcquirePropertyPlantAndEquipment'->'units'->'USD','[]'::jsonb)
  ) r
  cross join target t
  where r->>'accn'=t.accession_number
    and r->>'form'='10-K'
    and (r->>'start')::date=t.period_start
    and (r->>'end')::date=t.period_end
),
selected_facts as (
  select
    (select count(*) from revenue_candidates) as revenue_row_count,
    (select (r->>'val')::numeric from revenue_candidates limit 1) as revenue_usd,
    (select count(*) from ocf_candidates) as ocf_row_count,
    (select (r->>'val')::numeric from ocf_candidates limit 1) as ocf_usd,
    (select count(*) from capex_candidates) as capex_row_count,
    (select (r->>'val')::numeric from capex_candidates limit 1) as capex_usd
),
source_blockers as (
  select array_remove(array[
    case when not exists(select 1 from filing) then 'TARGET_10K_NOT_FOUND_IN_LATEST_SEC_SUBMISSIONS' end,
    case when revenue_row_count <> 1 then 'REVENUE_ANNUAL_FACT_NOT_UNIQUE' end,
    case when ocf_row_count <> 1 then 'OCF_ANNUAL_FACT_NOT_UNIQUE' end,
    case when capex_row_count <> 1 then 'CAPEX_ANNUAL_FACT_NOT_UNIQUE' end,
    case when revenue_usd is null or revenue_usd <= 0 then 'REVENUE_VALUE_INVALID' end,
    case when ocf_usd is null or ocf_usd <= 0 then 'OCF_VALUE_INVALID' end,
    case when capex_usd is null or capex_usd < 0 then 'CAPEX_VALUE_INVALID' end,
    case when ocf_usd is not null and capex_usd is not null and ocf_usd <= capex_usd
      then 'FCF_DERIVATION_NON_POSITIVE' end
  ],null)::text[] as blockers
  from selected_facts
),
model_guard as (
  select
    t.model_id,
    m.production_status,
    m.required_metric_ids,
    case
      when m.model_id is null then 'BLOCKED_UNSUPPORTED_MODEL'
      when m.production_status <> 'IMPLEMENTED' then 'BLOCKED_UNSUPPORTED_MODEL'
      when m.required_metric_ids && array[
        'fcf_guidance_low',
        'fcf_guidance_midpoint',
        'fcf_guidance_high',
        'fy2026_revenue_growth_guidance_lc_mid',
        'book_to_bill_q3',
        'operating_margin_q3',
        'gross_margin_q3'
      ]::text[] then 'BLOCKED_MODEL_PERIOD_ROLLOVER_REQUIRED'
      else 'MODEL_INPUT_CONTRACT_REVIEW_REQUIRED'
    end as revaluation_status
  from target t
  left join fwios.valuation_models m on m.model_id=t.model_id
),
model_blockers as (
  select array_remove(array[
    case when g.revaluation_status='BLOCKED_UNSUPPORTED_MODEL'
      then 'VALUATION_MODEL_NOT_SUPPORTED' end,
    case when g.revaluation_status='BLOCKED_MODEL_PERIOD_ROLLOVER_REQUIRED'
      then 'MODEL_V1_IS_LOCKED_TO_FY2026_GUIDANCE_AND_Q3_SPECIFIC_INPUTS_AFTER_FY2026_CLOSE' end,
    case when 'net_cash'=any(coalesce(g.required_metric_ids,'{}'::text[]))
      and not coalesce((lf.payload->'facts') ? 'LongTermDebtCurrent',false)
      and not coalesce((lf.payload->'facts') ? 'LongTermDebtNoncurrent',false)
      then 'NET_CASH_BLOCKED_CURRENT_COMPACT_SHADOW_HAS_NO_DEBT_FACTS' end,
    case when 'shares_outstanding'=any(coalesce(g.required_metric_ids,'{}'::text[]))
      and coalesce((lf.payload->'facts') ? 'WeightedAverageNumberOfDilutedSharesOutstanding',false)
      then 'SHARES_OUTSTANDING_BLOCKED_WEIGHTED_AVERAGE_DILUTED_SHARES_IS_NOT_PERIOD_END_SHARES_OUTSTANDING' end,
    'FY2027_GUIDANCE_AND_BOOKINGS_ARE_NOT_PRESENT_IN_CURRENT_SEC_COMPANYFACTS_COMPACT_SHADOW'
  ],null)::text[] as blockers
  from model_guard g
  cross join latest_facts lf
),
payload as (
  select
    jsonb_build_object(
      'schema_version','chatgpt_research_payload_v1',
      'mode','PREVIEW',
      'command','FWIOS MVP-1 ACN SEC 10-K SHADOW-to-metrics PREVIEW',
      'ticker',t.ticker,
      'research_as_of',to_jsonb(lf.observed_at),
      'evidence',jsonb_build_array(
        jsonb_build_object(
          'evidence_ref','acn-10k-2026-'||t.accession_number,
          'fact_class','REPORTED_FINANCIALS',
          'claim',format(
            'ACN FY2026 10-K reports revenue USD %sB, operating cash flow USD %sB and capex USD %sB for the year ended %s.',
            trim(to_char(sf.revenue_usd/1000000000.0,'FM999999990.000000')),
            trim(to_char(sf.ocf_usd/1000000000.0,'FM999999990.000000')),
            trim(to_char(sf.capex_usd/1000000000.0,'FM999999990.000000')),
            t.period_end
          ),
          'source_name','SEC EDGAR - Accenture plc FY2026 Form 10-K',
          'source_url',format(
            'https://www.sec.gov/Archives/edgar/data/1467373/%s/%s',
            replace(t.accession_number,'-',''),
            f.primary_document
          ),
          'source_type','WEB_PRIMARY',
          'source_tier','A',
          'retrieved_at',to_jsonb(lf.observed_at),
          'reported_at',f.accepted_at,
          'reporting_period','FY2026 ended 2026-08-31',
          'verification_status','VERIFIED',
          'conflict_group',null,
          'notes','Deterministically selected from existing SEC_SUBMISSIONS + SEC_COMPANY_FACTS SHADOW evidence.'
        )
      ),
      'metrics',jsonb_build_array(
        jsonb_build_object(
          'metric_code','REVENUE',
          'value_kind','NUMERIC',
          'value_numeric',sf.revenue_usd/1000000000.0,
          'canonical_unit','USD B',
          'source_unit','USD B',
          'currency','USD',
          'period_type','LTM',
          'fiscal_year',t.fiscal_year,
          'period_start',t.period_start,
          'period_end',t.period_end,
          'as_of_date',t.period_end,
          'period_label','LTM / FY2026 ended 2026-08-31',
          'reported_at',f.accepted_at,
          'evidence_refs',jsonb_build_array('acn-10k-2026-'||t.accession_number),
          'verification_status','VERIFIED'
        ),
        jsonb_build_object(
          'metric_code','FREE_CASH_FLOW',
          'value_kind','NUMERIC',
          'value_numeric',(sf.ocf_usd-sf.capex_usd)/1000000000.0,
          'canonical_unit','USD B',
          'source_unit','USD B',
          'currency','USD',
          'period_type','LTM',
          'fiscal_year',t.fiscal_year,
          'period_start',t.period_start,
          'period_end',t.period_end,
          'as_of_date',t.period_end,
          'period_label','LTM / FY2026 ended 2026-08-31',
          'reported_at',f.accepted_at,
          'evidence_refs',jsonb_build_array('acn-10k-2026-'||t.accession_number),
          'verification_status','VERIFIED',
          'derivation_method','OCF_MINUS_CAPEX',
          'derivation_inputs',jsonb_build_object(
            'NetCashProvidedByUsedInOperatingActivities_USD',sf.ocf_usd,
            'PaymentsToAcquirePropertyPlantAndEquipment_USD',sf.capex_usd
          )
        )
      ),
      'guidance','[]'::jsonb,
      'risks','[]'::jsonb
    ) as payload
  from target t
  cross join latest_facts lf
  cross join filing f
  cross join selected_facts sf
  cross join source_blockers sb
  where cardinality(sb.blockers)=0
),
preview as (
  select fwios.preview_research_ingest_v1(p.payload) as result
  from payload p
)
select
  t.ticker,
  t.accession_number,
  f.filing_date,
  f.report_date,
  lf.observed_at as shadow_observed_at,
  lf.payload_fingerprint as companyfacts_payload_fingerprint,
  sb.blockers as source_blockers,
  mg.revaluation_status,
  mb.blockers as revaluation_blockers,
  p.payload as normalized_preview_payload,
  pr.result as controlled_preview_result
from target t
left join filing f on true
cross join latest_facts lf
cross join source_blockers sb
cross join model_guard mg
cross join model_blockers mb
left join payload p on true
left join preview pr on true;
