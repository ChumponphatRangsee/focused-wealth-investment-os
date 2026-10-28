-- FWIOS TTWO Clean-Room Test #1 — controlled SEC->canonical PREVIEW (SELECT ONLY).
-- Existing source snapshot, no HTTP/API invocation; no data writes, auto_trade=false.
-- SEC XBRL fy can be the filing FY for comparatives; verify start/end/accession/form/unit.
WITH
periods(period_key,period_type,fiscal_year,fiscal_quarter,starts,ends,accn,form_name,filed,sec_url,ev_ref) AS (
 VALUES
 ('FY2026'::text,'YEAR'::text,2026,NULL::int,DATE '2025-04-01',DATE '2026-03-31',
  '0001628280-26-037434','10-K',DATE '2026-05-22',
  'https://www.sec.gov/Archives/edgar/data/946581/000162828026037434/ttwo-20260331.htm','TTWO-FY26-10K'),
 ('Q1FY2027','QUARTER',2027,1,DATE '2026-04-01',DATE '2026-06-30',
  '0001628280-26-054870','10-Q',DATE '2026-08-07',
  'https://www.sec.gov/Archives/edgar/data/946581/000162828026054870/ttwo-20260630.htm','TTWO-Q1FY27-10Q')
),
metric_map(metric_code,xbrl_tag) AS (
 VALUES
 ('REVENUE'::text,'RevenueFromContractWithCustomerExcludingAssessedTax'::text),
 ('OPERATING_CASH_FLOW','NetCashProvidedByUsedInOperatingActivities'),
 ('CAPEX_PROPERTY_EQUIPMENT','PaymentsToAcquirePropertyPlantAndEquipment'),
 ('SHARE_BASED_COMPENSATION','ShareBasedCompensation')
),
companyfacts AS (
 SELECT payload,observed_at,payload_fingerprint FROM fwios.decision_refresh_shadow_evidence
 WHERE ticker='TTWO' AND fact_class='SEC_COMPANY_FACTS' AND source_provider='SEC_EDGAR'
 AND collection_status='PASS' ORDER BY observed_at DESC LIMIT 1
),
submissions AS (
 SELECT payload,observed_at,payload_fingerprint FROM fwios.decision_refresh_shadow_evidence
 WHERE ticker='TTWO' AND fact_class='SEC_SUBMISSIONS' AND source_provider='SEC_EDGAR'
 AND collection_status='PASS' ORDER BY observed_at DESC LIMIT 1
),
facts AS (
 SELECT p.*,mm.metric_code,mm.xbrl_tag,f.value->>'val' raw_usd
 FROM periods p CROSS JOIN metric_map mm CROSS JOIN companyfacts cf
 CROSS JOIN LATERAL jsonb_array_elements(
   COALESCE(cf.payload->'facts'->mm.xbrl_tag->'units'->'USD','[]'::jsonb)
 ) f(value)
 WHERE f.value->>'start'=p.starts::text AND f.value->>'end'=p.ends::text
 AND f.value->>'accn'=p.accn AND f.value->>'form'=p.form_name
 AND EXISTS (
   SELECT 1 FROM submissions s CROSS JOIN LATERAL
   jsonb_array_elements(coalesce(s.payload->'latest_filings','[]'::jsonb)) x(value)
   WHERE x.value->>'accession_number'=p.accn AND x.value->>'form'=p.form_name
   AND x.value->>'report_date'=p.ends::text
 )
),
integrity AS (
 SELECT COUNT(*) exact_fact_count,COUNT(DISTINCT (period_key,metric_code)) distinct_metric_periods,
 COUNT(*) FILTER(WHERE raw_usd !~ '^[-+]?[0-9]+$') invalid_values
 FROM facts
),
candidate AS (
 SELECT jsonb_build_object(
   'schema_version','chatgpt_research_payload_v1','mode','PREVIEW','ticker','TTWO',
   'research_as_of',cf.observed_at,
   'evidence',(SELECT jsonb_agg(jsonb_build_object(
     'evidence_ref',p.ev_ref,'fact_class','REPORTED_FINANCIALS',
     'source_type','WEB_PRIMARY','source_tier','A',
     'source_url',p.sec_url,'verification_status','VERIFIED',
     'claim','SEC '||p.form_name||' XBRL for '||p.period_key||
             '; exact accession/financial duration matched',
     'retrieved_at',cf.observed_at,
     'reported_at',p.filed::text||'T00:00:00Z',
     'reporting_period',p.period_key||' '||p.starts||' through '||p.ends
   ) ORDER BY p.starts) FROM periods p),
   'metrics',(SELECT jsonb_agg(jsonb_build_object(
     'metric_code',x.metric_code,
     'value_numeric',x.raw_usd::numeric/1000000000,
     'source_unit','USD B','currency','USD',
     'period_type',x.period_type,'fiscal_year',x.fiscal_year,
     'fiscal_quarter',x.fiscal_quarter,'period_start',x.starts,
     'period_end',x.ends,'period_label',x.period_key,'as_of_date',x.ends,
     'reported_at',x.filed::text||'T00:00:00Z',
     'evidence_refs',jsonb_build_array(x.ev_ref)
   ) ORDER BY x.starts,x.metric_code) FROM facts x)
 ) payload
 FROM integrity g CROSS JOIN companyfacts cf
 WHERE g.exact_fact_count=8 AND g.distinct_metric_periods=8 AND g.invalid_values=0
)
SELECT g.exact_fact_count,g.distinct_metric_periods,g.invalid_values,
 CASE WHEN c.payload IS NULL THEN 'BLOCKED_SOURCE_CONTEXT_MISMATCH'
      ELSE (fwios.preview_research_ingest_v1(c.payload))->>'overall_status' END AS preview_status,
 CASE WHEN c.payload IS NOT NULL THEN fwios.preview_research_ingest_v1(c.payload) ELSE NULL END AS preview_receipt,
 (SELECT payload_fingerprint FROM companyfacts) sec_facts_fingerprint,
 (SELECT payload_fingerprint FROM submissions) sec_filings_fingerprint,
 FALSE AS apply_authorized,FALSE AS auto_trade
FROM integrity g LEFT JOIN candidate c ON TRUE;
