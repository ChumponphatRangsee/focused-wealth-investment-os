-- FWIOS: ACN Research State Resolver v1 (read-only, tested against live Supabase 2026-10-28)
-- ACN-only; 10-K FY2026. This is NOT a migration, view, function, trigger or collector.
-- Never treat SEC XBRL "fy" in isolation as proof of accounting period.
-- Do not run controlled APPLY or promote decisions based on this report.
WITH
scope AS (
  SELECT 'ACN'::text AS ticker, 2026::integer AS fiscal_year,
         DATE '2025-09-01' AS fiscal_start, DATE '2026-08-31' AS fiscal_end
),
identity AS (
  SELECT s.instrument_id, s.symbol
  FROM fwios.instrument_symbols s JOIN scope p ON p.ticker=s.symbol
  WHERE s.is_primary IS TRUE AND s.active IS TRUE
  ORDER BY s.updated_at DESC LIMIT 1
),
base AS (
  SELECT p.*, id.instrument_id, sec.sec_checked_at, sec.latest_sec_form,
         sec.latest_sec_accession_number, sec.latest_sec_filing_date,
         sec.latest_sec_report_date, sec.sec_source_url,
         r.valuation_run_id, r.readiness_state, r.hardening_gate_raw,
         r.hardening_snapshot_id, r.hardening_valuation_run_id,
         r.blocking_reason, r.price_as_of, r.latest_price,
         v.model_id, v.model_version_id, v.production_eligible,
         v.probability_weighted_fv_per_share
  FROM scope p
  LEFT JOIN identity id ON TRUE
  LEFT JOIN fwios.v_thesis_sec_filing_current sec ON sec.ticker=p.ticker
  LEFT JOIN fwios.v_research_readiness_current_v1 r ON r.ticker=p.ticker
  LEFT JOIN fwios.valuation_runs v ON v.run_id=r.valuation_run_id AND v.ticker=p.ticker
),
shadow AS (
  SELECT sh.payload, sh.payload_fingerprint, sh.observed_at,
         sh.collection_status, sh.source_url
  FROM fwios.decision_refresh_shadow_evidence sh
  JOIN scope p ON p.ticker=sh.ticker
  WHERE sh.fact_class='SEC_COMPANY_FACTS'
  ORDER BY sh.observed_at DESC, sh.created_at DESC LIMIT 1
),
input_checks AS (
  SELECT i.input_key, i.input_role, i.required, i.gate_status,
         i.source_key, i.input_unit, m.observation_key, m.metric_code,
         m.period_type, m.fiscal_year, m.period_end, m.as_of_date,
         m.primary_evidence_id,
         (i.gate_status='PASS'
          AND i.input_value_text ~ '^-?[0-9]+(\.[0-9]+)?$'
          AND m.value_numeric = CASE
            WHEN i.input_value_text ~ '^-?[0-9]+(\.[0-9]+)?$'
            THEN i.input_value_text::numeric ELSE NULL END
          AND (
            (i.input_role='GUIDANCE' AND m.period_type='GUIDANCE'
             AND m.fiscal_year=b.fiscal_year+1)
            OR (i.input_key='fcf_ltm' AND m.period_type='LTM'
                AND m.fiscal_year=b.fiscal_year AND m.period_end=b.fiscal_end)
            OR (i.input_key IN ('net_cash','shares_outstanding')
                AND m.period_type='INSTANT'
                AND m.fiscal_year=b.fiscal_year AND m.period_end=b.fiscal_end)
          )
          AND m.observation_key IS NOT NULL
          AND m.provenance_status='PASS'
          AND m.quality_gate='PASS'
          AND m.canonical_unit=i.input_unit
          AND e.verification_status='VERIFIED'
          AND e.conflict_status='NO_CONFLICT') AS lineage_verified
  FROM base b
  JOIN fwios.valuation_run_inputs i ON i.run_id=b.valuation_run_id
  LEFT JOIN fwios.metric_observations m
    ON m.observation_key=i.source_key AND m.instrument_id=b.instrument_id
  LEFT JOIN fwios.evidence_records e ON e.evidence_id=m.primary_evidence_id
),
input_summary AS (
  SELECT COUNT(*) FILTER (WHERE required) AS required_total,
         COUNT(*) FILTER (WHERE required AND lineage_verified IS TRUE) AS required_verified,
         COALESCE(jsonb_agg(
           jsonb_build_object('input',input_key,'metric',metric_code,
             'source_observation',observation_key,'primary_evidence',primary_evidence_id,
             'period_type',period_type,'fiscal_year',fiscal_year,
             'period_end',period_end,'as_of_date',as_of_date,
             'lineage_verified',COALESCE(lineage_verified,FALSE))
           ORDER BY input_key) FILTER (WHERE required),'[]'::jsonb) AS required_inputs
  FROM input_checks
),
expected_metrics(metric_code,sec_xbrl_tag) AS (
  VALUES ('REVENUE'::text,'Revenues'::text),
         ('OPERATING_CASH_FLOW','NetCashProvidedByUsedInOperatingActivities'),
         ('CAPEX_PROPERTY_EQUIPMENT','PaymentsToAcquirePropertyPlantAndEquipment'),
         ('SHARE_BASED_COMPENSATION','ShareBasedCompensation')
),
annual_checks AS (
  SELECT x.metric_code, x.sec_xbrl_tag,
         cm.observation_key AS canonical_observation_key,
         cm.primary_evidence_id AS canonical_evidence_id,
         xf.raw_value_usd, xf.sec_accession AS xbrl_accession,
         CASE WHEN cm.observation_key IS NOT NULL THEN 'CANONICAL_READY'
              WHEN xf.raw_value_usd IS NOT NULL THEN 'STORED_SEC_FACT_NEEDS_PREVIEW'
              ELSE 'SOURCE_FACT_MISSING_REVIEW' END AS metric_status
  FROM expected_metrics x CROSS JOIN base b
  LEFT JOIN shadow sh ON TRUE
  LEFT JOIN LATERAL (
    SELECT m.observation_key, m.primary_evidence_id
    FROM fwios.metric_observations m
    JOIN fwios.evidence_records ev ON ev.evidence_id=m.primary_evidence_id
    WHERE m.instrument_id=b.instrument_id
      AND m.metric_code=x.metric_code
      AND m.period_type='YEAR' AND m.fiscal_year=b.fiscal_year
      AND m.period_start=b.fiscal_start AND m.period_end=b.fiscal_end
      AND m.canonical_unit='USD B' AND m.value_numeric IS NOT NULL
      AND m.provenance_status='PASS' AND m.quality_gate='PASS'
      AND ev.verification_status='VERIFIED' AND ev.conflict_status='NO_CONFLICT'
    ORDER BY m.reported_at DESC NULLS LAST, m.created_at DESC LIMIT 1
  ) cm ON TRUE
  LEFT JOIN LATERAL (
    SELECT f.value->>'val' AS raw_value_usd, f.value->>'accn' AS sec_accession
    FROM jsonb_array_elements(
      COALESCE(sh.payload->'facts'->x.sec_xbrl_tag->'units'->'USD','[]'::jsonb)
    ) AS f(value)
    WHERE sh.collection_status='PASS'
      AND f.value->>'start'=b.fiscal_start::text
      AND f.value->>'end'=b.fiscal_end::text
      AND f.value->>'accn'=b.latest_sec_accession_number
      AND f.value->>'form'='10-K'
    ORDER BY (f.value->>'filed') DESC LIMIT 1
  ) xf ON TRUE
),
annual_summary AS (
  SELECT COUNT(*) FILTER (WHERE metric_status='CANONICAL_READY') AS canonical_ready_count,
         COUNT(*) FILTER (WHERE metric_status='STORED_SEC_FACT_NEEDS_PREVIEW') AS stored_fact_gap_count,
         COUNT(*) FILTER (WHERE metric_status='SOURCE_FACT_MISSING_REVIEW') AS missing_source_count,
         jsonb_agg(jsonb_build_object('metric_code',metric_code,'sec_xbrl_tag',sec_xbrl_tag,
           'status',metric_status,'canonical_observation',canonical_observation_key,
           'canonical_evidence',canonical_evidence_id,
           'stored_sec_raw_usd',raw_value_usd,'sec_accession',xbrl_accession)
           ORDER BY metric_code) AS annual_metric_audit
  FROM annual_checks
)
SELECT b.ticker, b.instrument_id, b.fiscal_year, b.fiscal_start, b.fiscal_end,
       b.latest_sec_form, b.latest_sec_accession_number, b.latest_sec_filing_date,
       b.latest_sec_report_date, b.sec_checked_at, b.sec_source_url,
       sh.payload_fingerprint AS stored_companyfacts_fingerprint,
       sh.observed_at AS stored_companyfacts_observed_at,
       b.valuation_run_id, b.model_id, b.model_version_id,
       b.production_eligible, b.probability_weighted_fv_per_share,
       inp.required_total, inp.required_verified, inp.required_inputs,
       CASE WHEN inp.required_total>0 AND inp.required_total=inp.required_verified
                 AND b.production_eligible IS TRUE
            THEN 'VALUATION_INPUTS_READY' ELSE 'BLOCKED_MODEL_INPUT_LINEAGE' END
         AS valuation_input_state,
       an.canonical_ready_count, an.stored_fact_gap_count,
       an.missing_source_count, an.annual_metric_audit,
       b.readiness_state, b.hardening_gate_raw, b.hardening_snapshot_id,
       b.hardening_valuation_run_id, b.blocking_reason, b.price_as_of,
       b.latest_price,
       CASE WHEN b.latest_sec_form IS DISTINCT FROM '10-K'
                     OR b.latest_sec_report_date IS DISTINCT FROM b.fiscal_end::text
                     OR b.latest_sec_accession_number IS NULL THEN 'REVIEW_NEW_OR_MISSING_FILING'
            WHEN inp.required_total=0 OR inp.required_total<>inp.required_verified
              THEN 'REVIEW_VALUATION_INPUT_LINEAGE'
            WHEN an.missing_source_count>0 THEN 'REVIEW_SOURCE_FACT_GAPS'
            WHEN an.stored_fact_gap_count>0
              THEN 'PREVIEW_CANONICAL_ENRICHMENT_FROM_STORED_SEC'
            ELSE 'NOOP_NO_ANNUAL_METRIC_GAPS' END AS proposed_research_action,
       FALSE AS apply_authorized, FALSE AS auto_trade
FROM base b CROSS JOIN input_summary inp CROSS JOIN annual_summary an
LEFT JOIN shadow sh ON TRUE;
