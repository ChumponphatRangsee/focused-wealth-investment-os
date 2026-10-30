-- TTWO SHADOW/EXPERIMENTAL AI-generated archetype routing + 10Y DCF (READ ONLY).
-- NOT a PRODUCTION Valuation run, Fair Value, investment decision, model authorization or trade signal.
-- Financial source: TTWO FY27 Q1 10-Q 0001628280-26-054870 (June 30, 2026);
-- issuer earnings release Aug 7 2026 guides FY27 Net Bookings $8.0-$8.2B, CFO >$1B, capex ~$290M.
-- Q1 10-Q balance sheet: cash 1.3649B; ST investments .4617B;
-- short/long debt .6299B / 1.8898B; 187M outstanding shares.
-- SCENARIO GROWTH/MARGINS/WACC/TERMINAL G/DILUTION/PROBABILITIES ARE UNAPPROVED HYPOTHESES.
WITH
identity AS (
 SELECT t.ticker,t.archetype,s.instrument_id,
  (SELECT COUNT(*) FROM fwios.valuation_models m
   JOIN fwios.valuation_model_versions v ON v.model_id=m.model_id
   WHERE LOWER(m.archetype)=LOWER(t.archetype)
    AND m.production_status='IMPLEMENTED'
    AND v.status='PRODUCTION' AND v.regression_status='PASS') production_matches
 FROM fwios.thesis_registry t JOIN fwios.instrument_symbols s
  ON s.symbol=t.ticker AND s.is_primary=true AND s.active=true
 JOIN fwios.instruments i ON i.instrument_id=s.instrument_id
 WHERE t.ticker='TTWO' AND i.asset_class='Stock' AND i.lifecycle_status='ACTIVE'
),
latest_facts AS (
 SELECT payload,observed_at FROM fwios.decision_refresh_shadow_evidence
 WHERE ticker='TTWO' AND fact_class='SEC_COMPANY_FACTS' AND source_provider='SEC_EDGAR'
 AND collection_status='PASS' ORDER BY observed_at DESC LIMIT 1
),
gates AS (
 SELECT
 (SELECT COUNT(*)=1 FROM identity) ticker_valid,
 (SELECT COUNT(*)=1 FROM identity WHERE production_matches=0) no_approved_archetype_model,
 EXISTS (
  SELECT 1 FROM fwios.decision_refresh_shadow_evidence s,
   LATERAL jsonb_array_elements(s.payload->'latest_filings') f(value)
  WHERE s.ticker='TTWO' AND s.fact_class='SEC_SUBMISSIONS'
   AND s.collection_status='PASS' AND f.value->>'accession_number'='0001628280-26-054870'
   AND f.value->>'form'='10-Q' AND f.value->>'report_date'='2026-06-30'
 ) sec_filing_verified,
 EXISTS (
  SELECT 1 FROM latest_facts f, LATERAL jsonb_array_elements(
     coalesce(f.payload->'facts'->'RevenueFromContractWithCustomerExcludingAssessedTax'->'units'->'USD','[]'::jsonb)
    ) x(value)
  WHERE x.value->>'accn'='0001628280-26-054870'
   AND x.value->>'start'='2026-04-01' AND x.value->>'end'='2026-06-30'
   AND (x.value->>'val')::numeric=1533900000
 ) sec_revenue_verified,
 EXISTS (
  SELECT 1 FROM fwios.market_daily_closes p WHERE p.asset_symbol='TTWO'
   AND p.session_date='2026-10-27' AND p.verification_status='VERIFIED'
   AND p.provenance_status='PASS' AND p.close_price>0 AND p.secondary_close>0
 ) verified_eod
),
issuer_anchor AS (
 SELECT 8.0::numeric bookings_guide_low_b,8.2::numeric bookings_guide_high_b,
 1.0::numeric cfo_guidance_lower_bound_b,0.29::numeric capex_guidance_b,
 1.3649::numeric cash_b,0.4617::numeric short_investments_b,
 0.6299::numeric short_debt_b,1.8898::numeric long_debt_b,
 187::numeric outstanding_shares_m
),
route AS (
 SELECT id.ticker,id.archetype,id.production_matches,
  'INTERACTIVE_ENTERTAINMENT_IP_DCF_V1'::text model_candidate,
  CASE WHEN g.ticker_valid AND g.no_approved_archetype_model
       AND g.sec_filing_verified AND g.sec_revenue_verified AND g.verified_eod
       THEN 'SHADOW_CANDIDATE_REQUIRES_REVIEW'
       ELSE 'BLOCKED_FAIL_CLOSED' END routing_status,
  a.* FROM identity id CROSS JOIN gates g CROSS JOIN issuer_anchor a
),
assumptions AS (
 SELECT * FROM (VALUES
  -- Scenario, weight, FY28 bookings shock, FY29-FY36 annual growth,
  -- assumed owner cash flow / bookings, discount, terminal g, prospective dilution.
  ('Bear'::text,.25::numeric,-.10::numeric,.025::numeric,.12::numeric,.12::numeric,.02::numeric,.04::numeric),
  ('Base',.50,.15,.07,.19,.105,.025,.03),
  ('Bull',.25,.30,.10,.25,.09,.03,.02)
 ) a(scenario,weight,fy28_bookings_change,later_booking_growth,owner_cash_margin,discount_rate,terminal_growth,prospective_dilution)
),
cashflows AS (
 SELECT r.ticker,r.model_candidate,r.routing_status,a.*,y.fy_index,
  CASE WHEN y.fy_index=1 THEN r.cfo_guidance_lower_bound_b-r.capex_guidance_b
       ELSE ((r.bookings_guide_low_b+r.bookings_guide_high_b)/2)
          *(1+a.fy28_bookings_change)
          *power(1+a.later_booking_growth,y.fy_index-2)
          *a.owner_cash_margin END AS cash_proxy_b,
  (r.cash_b+r.short_investments_b-r.short_debt_b-r.long_debt_b) net_cash_b,
  (r.outstanding_shares_m*(1+a.prospective_dilution)) modeled_shares_m
 FROM route r CROSS JOIN assumptions a CROSS JOIN generate_series(1,10) y(fy_index)
 WHERE r.routing_status='SHADOW_CANDIDATE_REQUIRES_REVIEW'
  AND a.owner_cash_margin BETWEEN 0 AND .3
  AND a.discount_rate>a.terminal_growth
  AND a.discount_rate<=.3 AND a.terminal_growth BETWEEN 0 AND .05
  AND a.prospective_dilution>=0
),
dcf AS (
 SELECT scenario,MAX(ticker) ticker,MAX(model_candidate) model_candidate,
  MAX(routing_status) routing_status,MAX(weight) weight,
  MAX(discount_rate) discount_rate,MAX(terminal_growth) terminal_growth,
  MAX(owner_cash_margin) assumed_cash_margin,
  MAX(net_cash_b) net_cash_b,MAX(modeled_shares_m) shares_m,
  SUM(cash_proxy_b/power(1+discount_rate,fy_index)) pv_10_years_b,
  MAX(CASE WHEN fy_index=10 THEN
   cash_proxy_b*(1+terminal_growth)/(discount_rate-terminal_growth)
   /power(1+discount_rate,10) END) terminal_pv_b
 FROM cashflows GROUP BY scenario
),
results AS (
 SELECT scenario,ticker,model_candidate,routing_status,weight,discount_rate,
  terminal_growth,assumed_cash_margin,net_cash_b,shares_m,
  pv_10_years_b,terminal_pv_b,
  ROUND((pv_10_years_b+terminal_pv_b+net_cash_b)*1000/shares_m,2)
     illustrative_unapproved_usd_per_share,
  'HYPOTHETICAL_SHADOW_ONLY_NOT_FAIR_VALUE'::text result_label
 FROM dcf
)
SELECT scenario,ticker,model_candidate,routing_status,weight,discount_rate,
 terminal_growth,assumed_cash_margin,ROUND(net_cash_b,4) net_cash_b,
 ROUND(shares_m,3) modeled_shares_m,ROUND(pv_10_years_b,5) pv_10_years_b,
 ROUND(terminal_pv_b,5) terminal_pv_b,illustrative_unapproved_usd_per_share,result_label
 FROM results ORDER BY CASE scenario WHEN 'Bear' THEN 1 WHEN 'Base' THEN 2 ELSE 3 END;