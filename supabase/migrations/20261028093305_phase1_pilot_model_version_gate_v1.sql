-- FWIOS Phase 1 scoped fail-closed live Valuation Map model-version guard.
-- Only ACN, ADBE, PINS are gated. All other valuation rows are byte-for-byte preserved by predicate.
-- Reviewed preflight: 29 -> 28 valued; ONLY ADBE loses untrusted RETIRED model FV.
-- Not an override of price/quality/decision/trading; no DELETE/UPDATE, no new schedule.
CREATE OR REPLACE VIEW fwios.v_dashboard_valuation_map WITH (security_invoker=true) AS
WITH latest_valuation AS (
         SELECT DISTINCT ON (v.ticker) v.ticker,
            v.run_id AS valuation_run_id,
            v.model_id,
            v.as_of_text AS valuation_as_of,
            v.created_at AS valuation_created_at,
            v.current_price AS valuation_reference_price,
            v.bear_fv_per_share,
            v.base_fv_per_share,
            v.bull_fv_per_share,
            v.probability_weighted_fv_per_share
           FROM fwios.valuation_runs v
          WHERE v.production_eligible = true AND v.bear_fv_per_share IS NOT NULL AND v.base_fv_per_share IS NOT NULL AND v.bull_fv_per_share IS NOT NULL AND v.probability_weighted_fv_per_share IS NOT NULL
            AND (
              v.ticker NOT IN ('ACN','ADBE','PINS')
              OR EXISTS (
                SELECT 1 FROM fwios.valuation_model_versions mv
                WHERE mv.version_id=v.model_version_id
                  AND mv.status='PRODUCTION'
                  AND mv.regression_status='PASS'
              )
            )
          ORDER BY v.ticker, v.created_at DESC
        ), latest_candidate AS (
         SELECT DISTINCT ON (r.ticker) r.ticker,
            r.promotion_gate,
            r.mispricing_gate AS candidate_mispricing_gate,
            r.final_decision,
            r.updated_at
           FROM fwios.research_candidates r
          ORDER BY r.ticker, r.updated_at DESC
        ), latest_mispricing AS (
         SELECT DISTINCT ON (m.ticker) m.ticker,
            m.effective_mispricing_gate,
            m.effective_mispricing_class,
            m.created_at
           FROM fwios.v_valuation_mispricing_current m
          ORDER BY m.ticker, m.created_at DESC
        ), base AS (
         SELECT c.sector,
            v.ticker,
            c.company_name,
            COALESCE(dc.close_price, p.selected_price, v.valuation_reference_price) AS current_price,
            COALESCE(dc.session_date, p.session_date) AS price_session_date,
                CASE
                    WHEN dc.asset_symbol IS NOT NULL THEN 'DAILY CLOSE - '::text || dc.verification_status
                    ELSE COALESCE(p.effective_price_gate, 'BLOCKED - NO CURRENT PRICE'::text)
                END AS price_gate,
            COALESCE(p.effective_price_gate, 'BLOCKED - NO VERIFIED DECISION PRICE'::text) AS decision_price_gate,
            v.bear_fv_per_share AS bear_fv,
            v.base_fv_per_share AS base_fv,
            v.bull_fv_per_share AS high_fv,
            v.probability_weighted_fv_per_share AS fair_value,
                CASE
                    WHEN COALESCE(dc.close_price, p.selected_price, v.valuation_reference_price) > 0::numeric THEN v.bear_fv_per_share / COALESCE(dc.close_price, p.selected_price, v.valuation_reference_price) - 1::numeric
                    ELSE NULL::numeric
                END AS bear_upside,
                CASE
                    WHEN COALESCE(dc.close_price, p.selected_price, v.valuation_reference_price) > 0::numeric THEN v.base_fv_per_share / COALESCE(dc.close_price, p.selected_price, v.valuation_reference_price) - 1::numeric
                    ELSE NULL::numeric
                END AS base_upside,
                CASE
                    WHEN COALESCE(dc.close_price, p.selected_price, v.valuation_reference_price) > 0::numeric THEN v.bull_fv_per_share / COALESCE(dc.close_price, p.selected_price, v.valuation_reference_price) - 1::numeric
                    ELSE NULL::numeric
                END AS high_upside,
                CASE
                    WHEN COALESCE(dc.close_price, p.selected_price, v.valuation_reference_price) > 0::numeric THEN v.probability_weighted_fv_per_share / COALESCE(dc.close_price, p.selected_price, v.valuation_reference_price) - 1::numeric
                    ELSE NULL::numeric
                END AS fair_value_upside,
            v.valuation_as_of,
            v.model_id,
            v.valuation_run_id,
            lc.promotion_gate,
            COALESCE(lm.effective_mispricing_gate, lc.candidate_mispricing_gate, 'PENDING PRICE'::text) AS mispricing_gate
           FROM latest_valuation v
             LEFT JOIN fwios.companies c ON c.ticker = v.ticker
             LEFT JOIN fwios.v_market_daily_close_latest dc ON dc.asset_symbol = v.ticker
             LEFT JOIN fwios.v_market_price_latest p ON p.asset_symbol = v.ticker
             LEFT JOIN latest_candidate lc ON lc.ticker = v.ticker
             LEFT JOIN latest_mispricing lm ON lm.ticker = v.ticker
        )
 SELECT sector,
    ticker,
    company_name,
    current_price,
    price_session_date,
    price_gate,
    bear_fv,
    base_fv,
    high_fv,
    fair_value,
    bear_upside,
    base_upside,
    high_upside,
    fair_value_upside,
        CASE
            WHEN current_price IS NULL THEN 'PRICE MISSING'::text
            WHEN current_price <= bear_fv THEN 'HIGH UPSIDE / BELOW BEAR FV'::text
            WHEN current_price <= base_fv THEN 'BASE VALUE ZONE'::text
            WHEN current_price <= high_fv THEN 'BULL CASE ONLY'::text
            ELSE 'ABOVE BULL FV'::text
        END AS price_zone,
        CASE
            WHEN decision_price_gate <> 'PASS'::text THEN 'PRICE VERIFY'::text
            WHEN mispricing_gate = 'PASS'::text AND promotion_gate = 'PASS'::text THEN 'BUY REVIEW'::text
            WHEN current_price <= base_fv THEN 'VALUE WATCH'::text
            ELSE 'WAIT'::text
        END AS system_signal,
    mispricing_gate,
    valuation_as_of,
    model_id,
    valuation_run_id
   FROM base
  ORDER BY (
        CASE
            WHEN decision_price_gate = 'PASS'::text AND mispricing_gate = 'PASS'::text AND promotion_gate = 'PASS'::text THEN 0
            WHEN current_price <= bear_fv THEN 1
            WHEN current_price <= base_fv THEN 2
            WHEN current_price <= high_fv THEN 3
            ELSE 4
        END), fair_value_upside DESC NULLS LAST, ticker;
