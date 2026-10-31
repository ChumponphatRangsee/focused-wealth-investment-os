-- FWIOS retention projected-removal assertions (READ ONLY).
-- Executes entirely via CTEs; NO production DELETE/UPDATE/TRUNCATE/ALTER/INSERT.
-- Audit canonical USD price selection and FX after hypothetically filtering
-- Archive-review candidates, WITHOUT modifying source rows.
WITH selected AS (
  SELECT s.symbol,s.instrument_id,i.asset_class,
         fwios.pr7_native_usd_price_read_v1(s.symbol) AS canonical
  FROM fwios.instrument_symbols s
  JOIN fwios.instruments i ON i.instrument_id=s.instrument_id
  WHERE s.active AND s.is_primary
), ranked AS (
  SELECT o.*,ROW_NUMBER() OVER (
    PARTITION BY o.instrument_id,o.provider,o.observation_type,o.session_date
    ORDER BY o.observed_at DESC,o.created_at DESC,o.observation_id DESC
  ) AS per_day_rank
  FROM fwios.market_observations o
), classified AS (
  SELECT r.*,CASE
    WHEN r.observation_id IN (
      SELECT (canonical->>'observation_id')::uuid FROM selected
    )
      OR r.observation_type='REGULAR_CLOSE'
      OR r.provider IN ('FRANKFURTER_FX','ALPHA_VANTAGE_PRICE')
      OR coalesce(r.raw_payload->>'price_only','false')='true'
      OR coalesce(r.raw_payload->>'price_only_stock_eod','false')='true'
      THEN 'KEEP_PROTECTED'
    WHEN jsonb_typeof(r.raw_payload) IS DISTINCT FROM 'object'
      THEN 'MANUAL_REVIEW_JSON_PAYLOAD'
    WHEN r.created_at>=now()-interval '14 days'
      THEN 'KEEP_RECENT'
    WHEN r.provider IN ('COINGECKO','TWELVE_DATA_FX','TWELVE_DATA_QUOTE')
      AND r.per_day_rank=1 THEN 'KEEP_DAILY_SAMPLE'
    WHEN r.provider IN ('COINGECKO','TWELVE_DATA_FX','TWELVE_DATA_QUOTE')
      AND r.per_day_rank>1 THEN 'ARCHIVE_REVIEW_ONLY'
    ELSE 'MANUAL_REVIEW'
  END AS disposition FROM ranked r
), retained AS (
  SELECT * FROM classified WHERE disposition <> 'ARCHIVE_REVIEW_ONLY'
), simulated_current AS (
  SELECT DISTINCT ON (s.symbol) s.symbol,r.observation_id,
         r.observation_value,r.provider,r.session_date
  FROM selected s JOIN retained r ON r.instrument_id=s.instrument_id
  WHERE r.value_currency='USD'
    AND r.provenance_status='PASS' AND r.observation_value>0
    AND r.observed_at<=now()+interval '5 seconds'
    AND coalesce(r.raw_payload->'fwios_pr4'->>'qa_only','false')<>'true'
    AND (
      (s.asset_class='Crypto' AND r.provider='COINGECKO'
       AND r.source_tier='B' AND r.observation_type='LIVE_QUOTE'
       AND r.market_status='24X7'
       AND r.session_date<=(now() at time zone 'UTC')::date)
      OR
      (s.asset_class='Stock' AND r.source_tier='A'
       AND r.session_date<=(now() at time zone 'America/New_York')::date
       AND (
         (r.observation_type='REGULAR_CLOSE' AND r.market_status='CLOSED'
          AND r.provider IN ('TWELVE_DATA','ALPHA_VANTAGE_PRICE'))
         OR (r.observation_type='LIVE_QUOTE' AND r.market_status='OPEN'
          AND r.provider='TWELVE_DATA_QUOTE'
          AND r.observed_at>=now()-interval '15 minutes')
       ))
    )
  ORDER BY s.symbol,r.observed_at DESC,r.created_at DESC
), comparison AS (
  SELECT s.*,v.observation_id AS simulated_id,v.observation_value AS simulated_price,
         v.provider AS simulated_provider,v.session_date AS simulated_session
  FROM selected s LEFT JOIN simulated_current v ON v.symbol=s.symbol
), tests(test_name,passed) AS (
  SELECT '01_ALL_ROWS_CLASSIFIED',
    (SELECT COUNT(*) FROM classified)=(SELECT COUNT(*) FROM fwios.market_observations)
  UNION ALL SELECT '02_TEN_CURRENT_SYMBOLS',(SELECT COUNT(*)=10 FROM selected)
  UNION ALL SELECT '03_TEN_CANONICAL_SELECTED_ROWS_RETAINED',
    (SELECT COUNT(*)=10 FROM comparison s JOIN retained r
      ON r.observation_id=(s.canonical->>'observation_id')::uuid)
  UNION ALL SELECT '04_TEN_SIMULATED_PRICES_FOUND',
    (SELECT COUNT(*)=10 FROM simulated_current)
  UNION ALL SELECT '05_ALL_CANONICAL_OBSERVATION_IDS_UNCHANGED',
    (SELECT COUNT(*)=10 AND bool_and((canonical->>'observation_id')::uuid=simulated_id)
      FROM comparison)
  UNION ALL SELECT '06_ALL_CANONICAL_USD_PRICES_UNCHANGED',
    (SELECT COUNT(*)=10 AND bool_and((canonical->>'price_usd')::numeric=simulated_price)
      FROM comparison)
  UNION ALL SELECT '07_ALL_CANONICAL_PROVIDERS_UNCHANGED',
    (SELECT COUNT(*)=10 AND bool_and(canonical->>'provider'=simulated_provider)
      FROM comparison)
  UNION ALL SELECT '08_ALL_CANONICAL_SESSIONS_UNCHANGED',
    (SELECT COUNT(*)=10 AND bool_and(canonical->>'session_date'=simulated_session::text)
      FROM comparison)
  UNION ALL SELECT '09_TEN_VALUATION_ELIGIBLE_BASELINE',
    (SELECT COUNT(*)=10 AND bool_and((canonical->>'valuation_eligible')::boolean)
      FROM comparison)
  UNION ALL SELECT '10_NO_STOCK_REGULAR_CLOSE_ARCHIVED',
    NOT EXISTS(SELECT 1 FROM classified WHERE disposition='ARCHIVE_REVIEW_ONLY'
               AND observation_type='REGULAR_CLOSE')
  UNION ALL SELECT '11_NO_FRANKFURTER_FX_ARCHIVED',
    NOT EXISTS(SELECT 1 FROM classified WHERE disposition='ARCHIVE_REVIEW_ONLY'
               AND provider='FRANKFURTER_FX')
  UNION ALL SELECT '12_LATEST_FX_OBSERVATION_UNCHANGED',
    (SELECT observation_id FROM fwios.market_observations
      WHERE provider='FRANKFURTER_FX' AND fx_base_currency='USD'
        AND fx_quote_currency='THB'
      ORDER BY observed_at DESC,created_at DESC LIMIT 1)
    =
    (SELECT observation_id FROM retained
      WHERE provider='FRANKFURTER_FX' AND fx_base_currency='USD'
        AND fx_quote_currency='THB'
      ORDER BY observed_at DESC,created_at DESC LIMIT 1)
  UNION ALL SELECT '13_NO_NON_OBJECT_JSON_PAYLOAD_ARCHIVED',
    NOT EXISTS(SELECT 1 FROM classified WHERE disposition='ARCHIVE_REVIEW_ONLY'
      AND jsonb_typeof(raw_payload) IS DISTINCT FROM 'object')
  UNION ALL SELECT '14_NO_RECENT_14_DAY_ROW_ARCHIVED',
    NOT EXISTS(SELECT 1 FROM classified WHERE disposition='ARCHIVE_REVIEW_ONLY'
      AND created_at>=now()-interval '14 days')
  UNION ALL SELECT '15_NO_EXPLICIT_PRICE_ONLY_PROVENANCE_ARCHIVED',
    NOT EXISTS(SELECT 1 FROM classified WHERE disposition='ARCHIVE_REVIEW_ONLY'
      AND (raw_payload->>'price_only'='true'
        OR raw_payload->>'price_only_stock_eod'='true'))
  UNION ALL SELECT '16_ONLY_SUPERSEDED_SAME_DAY_ROWS_CANDIDATES',
    NOT EXISTS(SELECT 1 FROM classified WHERE disposition='ARCHIVE_REVIEW_ONLY'
      AND per_day_rank<=1)
  UNION ALL SELECT '17_ONLY_ALLOWED_INTRADAY_SOURCES_CANDIDATES',
    NOT EXISTS(SELECT 1 FROM classified WHERE disposition='ARCHIVE_REVIEW_ONLY'
      AND (provider NOT IN ('COINGECKO','TWELVE_DATA_FX','TWELVE_DATA_QUOTE')
        OR observation_type NOT IN ('LIVE_QUOTE','FX')))
  UNION ALL SELECT '18_ARCHIVE_CANDIDATES_PRESENT',
    (SELECT COUNT(*)>0 FROM classified WHERE disposition='ARCHIVE_REVIEW_ONLY')
  UNION ALL SELECT '19_NO_CURRENT_INSTRUMENT_LOST_FROM_RETENTION',
    (SELECT COUNT(DISTINCT instrument_id)=10 FROM retained)
  UNION ALL SELECT '20_CURRENT_PRICE_FALLBACK_HISTORY_REMAINS',
    (SELECT COUNT(*)=10 FROM (
      SELECT s.instrument_id FROM selected s JOIN retained r
        ON r.instrument_id=s.instrument_id
      WHERE r.value_currency='USD' AND r.provenance_status='PASS'
        AND r.observation_value>0
        AND (
          (s.asset_class='Crypto' AND r.provider='COINGECKO'
            AND r.observation_type='LIVE_QUOTE')
          OR (s.asset_class='Stock' AND r.observation_type='REGULAR_CLOSE'
            AND r.provider IN ('TWELVE_DATA','ALPHA_VANTAGE_PRICE'))
        )
      GROUP BY s.instrument_id HAVING count(*)>=2
    ) f)
  UNION ALL SELECT '21_APPEND_ONLY_TRIGGER_STILL_ENABLED',
    (SELECT COUNT(*)=1 FROM pg_trigger WHERE
      tgrelid='fwios.market_observations'::regclass
      AND tgname='market_observations_append_only' AND tgenabled='O')
)
SELECT test_name,CASE WHEN passed IS TRUE THEN 'PASS' ELSE 'FAIL' END AS result
FROM tests ORDER BY test_name;