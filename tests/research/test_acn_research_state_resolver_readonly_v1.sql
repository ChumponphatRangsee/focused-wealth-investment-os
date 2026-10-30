-- ACN Resolver v1 read-only live acceptance. All rows must report PASS.
-- Run manually: no assertions mutate data; FAIL is a visible result, not an exception.
WITH
identity AS (
 SELECT instrument_id FROM fwios.instrument_symbols
 WHERE symbol='ACN' AND is_primary IS TRUE AND active IS TRUE
),
filing AS (
 SELECT * FROM fwios.v_thesis_sec_filing_current WHERE ticker='ACN'
),
r AS (
 SELECT * FROM fwios.v_research_readiness_current_v1 WHERE ticker='ACN'
),
model AS (
 SELECT v.* FROM fwios.valuation_runs v
 JOIN r ON r.valuation_run_id=v.run_id WHERE v.ticker='ACN'
),
inputs AS (
 SELECT i.*, m.observation_key,m.metric_code,m.period_type,m.fiscal_year,m.period_end,
        m.value_numeric,m.provenance_status,m.quality_gate,m.canonical_unit,
        e.verification_status,e.conflict_status
 FROM fwios.valuation_run_inputs i
 JOIN model v ON i.run_id=v.run_id
 LEFT JOIN fwios.metric_observations m
   ON m.observation_key=i.source_key AND m.instrument_id IN (SELECT instrument_id FROM identity)
 LEFT JOIN fwios.evidence_records e ON e.evidence_id=m.primary_evidence_id
),
required_audit AS (
 SELECT COUNT(*) FILTER(WHERE required) required_total,
        COUNT(*) FILTER (
          WHERE required AND gate_status='PASS' AND observation_key IS NOT NULL
            AND input_value_text ~ '^-?[0-9]+(\.[0-9]+)?$'
            AND value_numeric=CASE WHEN input_value_text ~ '^-?[0-9]+(\.[0-9]+)?$'
                                   THEN input_value_text::numeric ELSE NULL END
            AND provenance_status='PASS' AND quality_gate='PASS'
            AND canonical_unit=input_unit
            AND verification_status='VERIFIED' AND conflict_status='NO_CONFLICT'
            AND (
              (input_role='GUIDANCE' AND period_type='GUIDANCE' AND fiscal_year=2027)
              OR (input_key='fcf_ltm' AND period_type='LTM' AND fiscal_year=2026 AND period_end='2026-08-31')
              OR (input_key IN ('net_cash','shares_outstanding') AND period_type='INSTANT'
                  AND fiscal_year=2026 AND period_end='2026-08-31')
            )
        ) required_verified
 FROM inputs
),
shadow AS (
 SELECT payload,collection_status,payload_fingerprint,observed_at
 FROM fwios.decision_refresh_shadow_evidence
 WHERE ticker='ACN' AND fact_class='SEC_COMPANY_FACTS'
 ORDER BY observed_at DESC,created_at DESC LIMIT 1
),
expected(metric_code,sec_tag) AS (
 VALUES ('REVENUE'::text,'Revenues'::text),
        ('OPERATING_CASH_FLOW','NetCashProvidedByUsedInOperatingActivities'),
        ('CAPEX_PROPERTY_EQUIPMENT','PaymentsToAcquirePropertyPlantAndEquipment'),
        ('SHARE_BASED_COMPENSATION','ShareBasedCompensation')
),
raw_facts AS (
 SELECT x.metric_code, x.sec_tag, f.value->>'val' AS raw_usd
 FROM expected x CROSS JOIN shadow sh CROSS JOIN filing fmeta
 CROSS JOIN LATERAL jsonb_array_elements(
   COALESCE(sh.payload->'facts'->x.sec_tag->'units'->'USD','[]'::jsonb)
 ) AS f(value)
 WHERE sh.collection_status='PASS'
   AND f.value->>'start'='2025-09-01' AND f.value->>'end'='2026-08-31'
   AND f.value->>'accn'=fmeta.latest_sec_accession_number AND f.value->>'form'='10-K'
),
canonical_year AS (
 SELECT metric_code FROM fwios.metric_observations
 WHERE instrument_id IN (SELECT instrument_id FROM identity)
 AND metric_code IN (SELECT metric_code FROM expected)
 AND period_type='YEAR' AND fiscal_year=2026
 AND period_start='2025-09-01' AND period_end='2026-08-31'
 AND quality_gate='PASS' AND provenance_status='PASS'
),
fcf_observation AS (
 SELECT value_numeric FROM fwios.metric_observations
 WHERE instrument_id IN (SELECT instrument_id FROM identity)
   AND metric_code='FREE_CASH_FLOW' AND period_type='LTM'
   AND period_start='2025-09-01' AND period_end='2026-08-31'
   AND provenance_status='PASS' AND quality_gate='PASS'
 ORDER BY reported_at DESC LIMIT 1
),
facts_aggregate AS (
 SELECT COUNT(DISTINCT metric_code) distinct_annual_facts,
 MAX(raw_usd::numeric) FILTER(WHERE metric_code='OPERATING_CASH_FLOW') cfo_usd,
 MAX(raw_usd::numeric) FILTER(WHERE metric_code='CAPEX_PROPERTY_EQUIPMENT') capex_usd,
 MAX(raw_usd::numeric) FILTER(WHERE metric_code='REVENUE') revenue_usd,
 MAX(raw_usd::numeric) FILTER(WHERE metric_code='SHARE_BASED_COMPENSATION') sbc_usd
 FROM raw_facts
),
checks AS (
 SELECT '01_active_primary_acn' AS check_name,(SELECT COUNT(*)=1 FROM identity) AS pass
 UNION ALL SELECT '02_sec_10k_identity',(SELECT latest_sec_form='10-K'
    AND latest_sec_accession_number='0001467373-26-000049'
    AND latest_sec_report_date='2026-08-31' FROM filing)
 UNION ALL SELECT '03_latest_shadow_pass',(SELECT collection_status='PASS' FROM shadow)
 UNION ALL SELECT '04_required_model_inputs_7',(SELECT required_total=7 FROM required_audit)
 UNION ALL SELECT '05_required_input_lineage_7',(SELECT required_verified=7 FROM required_audit)
 UNION ALL SELECT '06_annual_sec_facts_4',(SELECT distinct_annual_facts=4 FROM facts_aggregate)
 UNION ALL SELECT '07_revenue_raw_sec_usd',(SELECT revenue_usd=74183445000 FROM facts_aggregate)
 UNION ALL SELECT '08_no_complete_canonical_annual',(SELECT COUNT(*)=0 FROM canonical_year)
 UNION ALL SELECT '09_reuse_fcf_reconciliation',(SELECT ABS((cfo_usd-capex_usd)/1000000000
    - (SELECT value_numeric FROM fcf_observation)) < 0.00000001 FROM facts_aggregate)
 UNION ALL SELECT '10_valuation_model_production',(SELECT production_eligible IS TRUE
    AND model_version_id='IT_SERVICES_FCF_COMPOUNDER_V1::2.0' FROM model)
 UNION ALL SELECT '11_fv_matches_record',(SELECT ABS(probability_weighted_fv_per_share-240.7142520975)<0.0000001 FROM model)
 UNION ALL SELECT '12_hardening_still_review',(SELECT hardening_gate_raw='REVIEW'
    AND hardening_valuation_run_id=valuation_run_id FROM r)
)
SELECT check_name, CASE WHEN pass IS TRUE THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks ORDER BY check_name;
