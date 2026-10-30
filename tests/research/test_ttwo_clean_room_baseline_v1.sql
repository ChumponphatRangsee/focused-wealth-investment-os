-- TTWO Clean Room Test #1: READ-ONLY pre-ingest regression (2026-10-28).
-- A baseline PASS does NOT certify valuation, Quality Hardening, Decision or production APPLY.
WITH
identity AS (
 SELECT s.instrument_id FROM fwios.instrument_symbols s
 JOIN fwios.instruments i ON i.instrument_id=s.instrument_id
 WHERE s.symbol='TTWO' AND s.is_primary AND s.active
 AND i.lifecycle_status='ACTIVE' AND i.asset_class='Stock'
),
sec AS (
 SELECT payload FROM fwios.decision_refresh_shadow_evidence
 WHERE ticker='TTWO' AND fact_class='SEC_SUBMISSIONS' AND collection_status='PASS'
 ORDER BY observed_at DESC LIMIT 1
),
facts AS (
 SELECT payload FROM fwios.decision_refresh_shadow_evidence
 WHERE ticker='TTWO' AND fact_class='SEC_COMPANY_FACTS' AND collection_status='PASS'
 ORDER BY observed_at DESC LIMIT 1
),
expected(pkey,accn,form_name,starts,ends) AS (
 VALUES ('FY26'::text,'0001628280-26-037434','10-K',DATE '2025-04-01',DATE '2026-03-31'),
        ('Q1FY27','0001628280-26-054870','10-Q',DATE '2026-04-01',DATE '2026-06-30')
),
mapping(metric,tag) AS (
 VALUES ('REVENUE'::text,'RevenueFromContractWithCustomerExcludingAssessedTax'::text),
        ('OPERATING_CASH_FLOW','NetCashProvidedByUsedInOperatingActivities'),
        ('CAPEX_PROPERTY_EQUIPMENT','PaymentsToAcquirePropertyPlantAndEquipment'),
        ('SHARE_BASED_COMPENSATION','ShareBasedCompensation')
),
rows AS (
 SELECT e.pkey,e.accn,e.form_name,e.starts,e.ends,m.metric,
  v.value->>'val' raw_usd
 FROM expected e CROSS JOIN mapping m CROSS JOIN facts f
 CROSS JOIN LATERAL jsonb_array_elements(
  COALESCE(f.payload->'facts'->m.tag->'units'->'USD','[]'::jsonb)) v(value)
 WHERE v.value->>'start'=e.starts::text AND v.value->>'end'=e.ends::text
 AND v.value->>'form'=e.form_name AND v.value->>'accn'=e.accn
),
checks(check_id,pass) AS (
 SELECT '01_TTWO_identity', (SELECT COUNT(*)=1 FROM identity)
 UNION ALL SELECT '02_TTWO_thesis_seed', (SELECT baseline_status='COMPLETE' FROM fwios.thesis_registry WHERE ticker='TTWO')
 UNION ALL SELECT '03_no_canonical_metrics', (SELECT COUNT(*)=0 FROM fwios.metric_observations WHERE instrument_id IN (SELECT instrument_id FROM identity))
 UNION ALL SELECT '04_no_evidence_records', (SELECT COUNT(*)=0 FROM fwios.evidence_records WHERE ticker='TTWO')
 UNION ALL SELECT '05_no_valuation_runs', (SELECT COUNT(*)=0 FROM fwios.valuation_runs WHERE ticker='TTWO')
 UNION ALL SELECT '06_no_decision_snapshots', (SELECT COUNT(*)=0 FROM fwios.decision_snapshots WHERE ticker='TTWO')
 UNION ALL SELECT '07_10k_in_stored_SEC', (SELECT EXISTS(SELECT 1 FROM sec s CROSS JOIN LATERAL jsonb_array_elements(s.payload->'latest_filings') x(value)
  WHERE x.value->>'accession_number'='0001628280-26-037434' AND x.value->>'report_date'='2026-03-31' AND x.value->>'form'='10-K'))
 UNION ALL SELECT '08_10q_in_stored_SEC', (SELECT EXISTS(SELECT 1 FROM sec s CROSS JOIN LATERAL jsonb_array_elements(s.payload->'latest_filings') x(value)
  WHERE x.value->>'accession_number'='0001628280-26-054870' AND x.value->>'report_date'='2026-06-30' AND x.value->>'form'='10-Q'))
 UNION ALL SELECT '09_exact_SEC_fact_coverage_8', (SELECT count(*)=8 AND count(distinct(pkey,metric))=8 FROM rows)
 UNION ALL SELECT '10_annual_revenue_6_6564B', (SELECT raw_usd::numeric=6656400000 FROM rows WHERE pkey='FY26' AND metric='REVENUE')
 UNION ALL SELECT '11_quarter_revenue_1_5339B', (SELECT raw_usd::numeric=1533900000 FROM rows WHERE pkey='Q1FY27' AND metric='REVENUE')
 UNION ALL SELECT '12_FY26_CFO_minus_capex', (SELECT (MAX(raw_usd::numeric) FILTER(WHERE metric='OPERATING_CASH_FLOW') -
   MAX(raw_usd::numeric) FILTER(WHERE metric='CAPEX_PROPERTY_EQUIPMENT'))=461500000 FROM rows WHERE pkey='FY26')
 UNION ALL SELECT '13_Q1_negative_CFO', (SELECT raw_usd::numeric=-168800000 FROM rows WHERE pkey='Q1FY27' AND metric='OPERATING_CASH_FLOW')
 UNION ALL SELECT '14_verified_EOD_price', (SELECT session_date=DATE '2026-10-27' AND close_price=201.25 AND secondary_close=201.28
  AND verification_status='VERIFIED' AND provenance_status='PASS' FROM fwios.market_daily_closes WHERE asset_symbol='TTWO' ORDER BY session_date DESC LIMIT 1)
 UNION ALL SELECT '15_TTWO_discovery_only', (SELECT readiness_state='DISCOVERY_READY' AND valuation_run_id IS NULL AND investment_review_ready IS FALSE
  FROM fwios.v_research_readiness_current_v1 WHERE ticker='TTWO')
 UNION ALL SELECT '16_no_exact_production_archetype', (SELECT COUNT(*)=0
  FROM fwios.valuation_models m JOIN fwios.thesis_registry t ON lower(t.archetype)=lower(m.archetype)
  WHERE t.ticker='TTWO' AND m.production_status='IMPLEMENTED')
 UNION ALL SELECT '17_64_stock_EOD_preserved', (SELECT COUNT(*)=64 FROM fwios.market_daily_closes WHERE session_date=DATE '2026-10-27')
 UNION ALL SELECT '18_no_research_apply_receipt', (SELECT COUNT(*)=0 FROM fwios.research_ingest_receipts_v1 WHERE ticker='TTWO')
)
SELECT check_id,CASE WHEN pass IS TRUE THEN 'PASS' ELSE 'FAIL' END result FROM checks ORDER BY check_id;