-- MVP-1: On-demand SELECT report only. Change the pilot tickers to choose 1-3 stocks.
-- Readiness != recommendation; legacy scanner ranks and signals are not buy permission.
WITH pilot(ticker) AS (
  VALUES ('ACN'::text), ('ADBE'::text), ('PINS'::text)
),
last_decision AS (
  SELECT ticker, decision_state, promotion_gate, input_integrity_gate,
         valuation_run_id AS decision_valuation_run_id, created_at AS decision_created_at
  FROM fwios.v_latest_decision_snapshots
  WHERE rn = 1
)
SELECT
  r.ticker,
  r.readiness_state,
  r.research_ready, r.valuation_ready, r.quality_hardened,
  r.investment_review_ready, r.blocking_reason, r.blocking_reasons,
  r.research_route, r.price_ready, r.price_as_of AS canonical_price_session,
  r.price_verification_status, r.price_provenance_status,
  v.current_price, v.price_session_date AS report_price_session,
  v.price_gate AS report_price_gate, v.bear_fv, v.base_fv,
  v.high_fv, v.fair_value AS probability_weighted_fv,
  v.fair_value_upside, v.valuation_as_of AS valuation_as_of,
  r.valuation_run_id AS readiness_valuation_run_id,
  v.valuation_run_id AS report_valuation_run_id,
  h.valuation_run_id AS hardening_run_id,
  h.overall_gate AS snapshot_hardening_gate,
  r.hardening_gate_raw,
  v.mispricing_gate AS report_mispricing_gate,
  v.system_signal AS legacy_map_signal,
  d.decision_state AS historical_decision_state,
  d.promotion_gate AS historical_decision_promotion_gate,
  d.input_integrity_gate AS historical_decision_input_integrity,
  d.decision_valuation_run_id,
  d.decision_created_at,
  s.scan_status AS legacy_scanner_status,
  s.scanner_score AS legacy_scanner_score_non_actionable,
  CASE
    WHEN NOT r.research_ready THEN 'RESEARCH_BLOCKED'
    WHEN NOT r.valuation_ready THEN 'VALUATION_BLOCKED'
    WHEN NOT r.quality_hardened THEN 'QUALITY_OR_LINEAGE_REVIEW'
    WHEN NOT r.price_ready THEN 'CANONICAL_PRICE_BLOCKED'
    WHEN NOT r.investment_review_ready THEN 'INVESTMENT_REVIEW_BLOCKED'
    ELSE 'REVIEW_READY_NOT_TRADE'
  END AS report_readiness_label,
  CASE
    WHEN h.valuation_run_id IS DISTINCT FROM r.valuation_run_id
      THEN 'HARDENING_RUN_DIFFERS_FROM_READINESS_VALUATION'
    WHEN v.valuation_run_id IS DISTINCT FROM r.valuation_run_id
      THEN 'REPORT_RUN_DIFFERS_FROM_READINESS_VALUATION'
    ELSE 'NONE'
  END AS lineage_diagnostic,
  CASE
    WHEN r.investment_review_ready AND (
      v.system_signal = 'PRICE VERIFY'
      OR d.input_integrity_gate IS DISTINCT FROM 'PASS'
      OR d.promotion_gate IS DISTINCT FROM 'PASS'
    ) THEN 'INDEPENDENT_LEGACY_GATES_REQUIRE_REVIEW'
    ELSE 'NO_LEGACY_CONFLICT_FLAG'
  END AS independent_gate_diagnostic
FROM pilot p
JOIN fwios.v_research_readiness_current_v1 r ON r.ticker=p.ticker
LEFT JOIN fwios.v_dashboard_valuation_map v ON v.ticker=r.ticker
LEFT JOIN fwios.v_candidate_quality_hardening_current h ON h.ticker=r.ticker
LEFT JOIN last_decision d ON d.ticker=r.ticker
LEFT JOIN fwios.v_scanner_current_v1 s ON s.ticker=r.ticker
ORDER BY r.ticker;
