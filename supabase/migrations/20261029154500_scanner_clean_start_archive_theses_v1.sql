-- FWIOS scanner clean-start 2026-10-29. NON-DESTRUCTIVE reset. No portfolio, instrument identity, market prices, fundamentals or historical hard deletes.
-- The existing scanner view queried market_daily_closes directly: disabling theses alone would NOT reset the scanner.
-- This migration adds an explicit, initially empty new-generation enrollment gate to the existing scanner.
-- Thesis rows and all related events/conditions/health remain intact as inactive historical records.
CREATE TABLE IF NOT EXISTS fwios.scanner_reset_batches_v1(
 reset_id text PRIMARY KEY,
 reset_mode text NOT NULL CHECK(reset_mode='NON_DESTRUCTIVE_ARCHIVE'),
 archived_thesis_count integer NOT NULL,
 prior_scanner_count integer NOT NULL,
 prior_research_candidate_count integer NOT NULL,
 prior_tickers jsonb NOT NULL,
 reset_reason text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS fwios.scanner_discovery_enrollments_v1(
 ticker text PRIMARY KEY,
 generation text NOT NULL DEFAULT 'SCAN-RESET-20261029' CHECK(generation='SCAN-RESET-20261029'),
 discovered_at timestamptz NOT NULL DEFAULT now(),
 source_run_id text,
 evidence_ref text,
 active boolean NOT NULL DEFAULT true,
 CHECK (ticker ~ '^[A-Z][A-Z0-9. -]{0,14}$')
);
ALTER TABLE fwios.scanner_reset_batches_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE fwios.scanner_discovery_enrollments_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON fwios.scanner_reset_batches_v1,fwios.scanner_discovery_enrollments_v1 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON fwios.scanner_reset_batches_v1 TO service_role;
GRANT SELECT,INSERT,UPDATE ON fwios.scanner_discovery_enrollments_v1 TO service_role;
DO $fwios_reset$
DECLARE v_count integer; v_scanner integer; v_rc integer;
BEGIN
 SELECT COUNT(*) INTO v_count FROM fwios.thesis_registry WHERE active=true;
 SELECT COUNT(*) INTO v_scanner FROM fwios.v_scanner_current_v1;
 SELECT COUNT(*) INTO v_rc FROM fwios.research_candidates;
 IF v_count<>63 OR v_scanner<>64 THEN
  RAISE EXCEPTION 'RESET_PREFLIGHT_DRIFT theses=%,scanner=%: fail closed',v_count,v_scanner;
 END IF;
 IF EXISTS(SELECT 1 FROM fwios.scanner_discovery_enrollments_v1) THEN
  RAISE EXCEPTION 'RESET_REFUSED_DISCOVERY_ENROLLMENTS_NONEMPTY';
 END IF;
 INSERT INTO fwios.scanner_reset_batches_v1(reset_id,reset_mode,archived_thesis_count,
  prior_scanner_count,prior_research_candidate_count,prior_tickers,reset_reason)
 SELECT 'SCAN-RESET-20261029','NON_DESTRUCTIVE_ARCHIVE',v_count,v_scanner,v_rc,
 jsonb_build_object(
  'active_thesis_tickers',(SELECT jsonb_agg(ticker ORDER BY ticker) FROM fwios.thesis_registry WHERE active=true),
  'scanner_tickers',(SELECT jsonb_agg(ticker ORDER BY ticker) FROM fwios.v_scanner_current_v1)),
 'User-directed scanner clean-start: start new stock discovery with empty universe; preserve shared price and portfolio data';
 UPDATE fwios.thesis_registry SET active=false,updated_at=now(),
 metadata=metadata||jsonb_build_object('archived_by_scanner_reset','SCAN-RESET-20261029')
 WHERE active=true;
END $fwios_reset$;
CREATE OR REPLACE VIEW fwios.v_scanner_current_v1 AS 
 WITH universe AS (
         SELECT dc.asset_symbol AS ticker,
            COALESCE(NULLIF(c.company_name, ''::text), NULLIF(tr.company_name, ''::text), dc.asset_symbol) AS company,
            COALESCE(NULLIF(c.sector, ''::text), NULLIF(tr.sector, ''::text), 'Unclassified'::text) AS sector,
            dc.close_price AS latest_price,
            dc.session_date AS price_as_of,
            dc.primary_provider AS price_provider,
            dc.verification_status AS price_verification_status,
            dc.provenance_status AS price_provenance_status,
            dc.retrieved_at AS price_retrieved_at
           FROM fwios.v_market_daily_close_latest dc
             INNER JOIN fwios.scanner_discovery_enrollments_v1 se ON se.ticker=dc.asset_symbol AND se.active=true AND se.generation='SCAN-RESET-20261029'
             JOIN fwios.v_instrument_identity_current i ON i.asset_symbol = dc.asset_symbol AND i.asset_class = 'Stock'::text AND i.lifecycle_status = 'ACTIVE'::text
             LEFT JOIN fwios.companies c ON c.ticker = dc.asset_symbol AND c.active = true
             LEFT JOIN fwios.thesis_registry tr ON tr.ticker = dc.asset_symbol AND tr.active = true
        ), features AS (
         SELECT u.ticker,
            u.company,
            u.sector,
            u.latest_price,
            u.price_as_of,
            u.price_provider,
            u.price_verification_status,
            u.price_provenance_status,
            u.price_retrieved_at,
            rc.business_thesis_score,
            rc.quality_score,
            rc.downside_risk_score,
            rc.updated_at AS research_updated_at,
            th.thesis_score,
            vm.bear_fv,
            vm.base_fv,
            vm.high_fv,
            vm.fair_value,
                CASE
                    WHEN u.latest_price > 0::numeric AND vm.fair_value IS NOT NULL THEN vm.fair_value / u.latest_price - 1::numeric
                    ELSE NULL::numeric
                END AS upside_pct
           FROM universe u
             LEFT JOIN fwios.research_candidates rc ON rc.ticker = u.ticker
             LEFT JOIN fwios.v_thesis_tracking_current th ON th.ticker = u.ticker
             LEFT JOIN fwios.v_dashboard_valuation_map vm ON vm.ticker = u.ticker
        ), scored AS (
         SELECT f.ticker,
            f.company,
            f.sector,
            f.latest_price,
            f.price_as_of,
            f.price_provider,
            f.price_verification_status,
            f.price_provenance_status,
            f.price_retrieved_at,
            f.business_thesis_score,
            f.quality_score,
            f.downside_risk_score,
            f.research_updated_at,
            f.thesis_score,
            f.bear_fv,
            f.base_fv,
            f.high_fv,
            f.fair_value,
            f.upside_pct,
                CASE
                    WHEN f.business_thesis_score IS NOT NULL AND f.quality_score IS NOT NULL AND f.downside_risk_score IS NOT NULL AND f.upside_pct IS NOT NULL THEN fwios.opportunity_quality_score_v2(f.business_thesis_score, f.upside_pct, f.quality_score, f.downside_risk_score)
                    ELSE NULL::numeric
                END AS scanner_score,
                CASE
                    WHEN f.latest_price IS NULL OR f.price_provenance_status <> 'PASS'::text THEN 'PRICE BLOCKED'::text
                    WHEN f.fair_value IS NULL THEN 'NO VALUATION'::text
                    WHEN f.latest_price <= f.bear_fv THEN 'STRONG UNDERVALUED'::text
                    WHEN f.latest_price <= f.base_fv THEN 'UNDERVALUED'::text
                    WHEN f.latest_price <= f.fair_value THEN 'FAIR VALUE'::text
                    WHEN f.latest_price <= f.high_fv THEN 'EXPENSIVE'::text
                    ELSE 'VERY EXPENSIVE'::text
                END AS valuation_status,
                CASE
                    WHEN f.latest_price IS NULL OR f.price_provenance_status <> 'PASS'::text THEN 'PRICE_BLOCKED'::text
                    WHEN f.fair_value IS NULL THEN 'PRICE_ONLY'::text
                    WHEN f.business_thesis_score IS NULL OR f.quality_score IS NULL OR f.downside_risk_score IS NULL THEN 'VALUATION_ONLY'::text
                    ELSE 'SCORED'::text
                END AS scan_status,
            GREATEST(f.price_retrieved_at, f.research_updated_at) AS refreshed_at
           FROM features f
        )
 SELECT
        CASE
            WHEN scanner_score IS NOT NULL THEN row_number() OVER (ORDER BY scanner_score DESC NULLS LAST, ticker)::integer
            ELSE NULL::integer
        END AS scan_rank,
    ticker,
    company,
    sector,
    scanner_score,
    quality_score,
    latest_price,
    price_as_of,
    bear_fv,
    base_fv,
    high_fv,
    fair_value AS probability_weighted_fv,
    upside_pct,
    valuation_status,
    thesis_score,
    scan_status,
    refreshed_at,
    price_verification_status,
    price_provenance_status
   FROM scored s
  ORDER BY (
        CASE
            WHEN scanner_score IS NOT NULL THEN row_number() OVER (ORDER BY scanner_score DESC NULLS LAST, ticker)::integer
            ELSE NULL::integer
        END), upside_pct DESC NULLS LAST, ticker;
-- Guard re-entrant consumer behavior by requiring explicit approved new-generation discovery enrollments.
