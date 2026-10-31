-- FWIOS market observations retention preflight — READ ONLY.
-- No BEGIN/DELETE/UPDATE/TRUNCATE/ALTER/DROP. Never run as a cleanup migration.
-- Production baseline (2026-10-30, Asia/Bangkok): 18,659 observations, 10 instruments.
-- This is a candidate report, not permission to delete. See accompanying docs.
-- Run separately from EOD live ingestion, and save the output before any backup/restore rehearsal.

-- 1. Inventory by provider/kind and backing JSONB representation.
SELECT provider, observation_type, jsonb_typeof(raw_payload) AS payload_json_type,
       COUNT(*) AS rows, COUNT(DISTINCT session_date) AS sessions,
       MIN(session_date) AS min_session, MAX(session_date) AS max_session
FROM fwios.market_observations
GROUP BY provider, observation_type, jsonb_typeof(raw_payload)
ORDER BY rows DESC;

-- 2. Current canonical price-observation references. All 10 must resolve.
SELECT s.symbol,
       price.data ->> 'observation_id' AS selected_observation_id,
       price.data ->> 'provider' AS selected_provider,
       price.data ->> 'session_date' AS selected_session,
       price.data ->> 'status' AS status,
       (o.observation_id IS NOT NULL) AS selected_row_exists
FROM fwios.instrument_symbols s
CROSS JOIN LATERAL (
  SELECT fwios.pr7_native_usd_price_read_v1(s.symbol) AS data
) price
LEFT JOIN fwios.market_observations o
  ON o.observation_id=(price.data->>'observation_id')::uuid
WHERE s.is_primary AND s.active
ORDER BY s.symbol;

-- 3. Conservative candidate classification. The 14-day window slides with now().
-- Ranking is a reporting heuristic, not an assertion that daily samples are valid
-- historical closes. Never use this query to delete observations in production.
WITH selected AS (
  SELECT (fwios.pr7_native_usd_price_read_v1(s.symbol)->>'observation_id')::uuid AS observation_id
  FROM fwios.instrument_symbols s
  WHERE s.is_primary AND s.active
), ranked AS (
  SELECT o.*, ROW_NUMBER() OVER (
    PARTITION BY o.instrument_id,o.provider,o.observation_type,o.session_date
    ORDER BY o.observed_at DESC,o.created_at DESC,o.observation_id DESC
  ) AS per_day_rank
  FROM fwios.market_observations o
), classified AS (
  SELECT r.observation_id,r.provider,r.observation_type,r.created_at,r.session_date,
    CASE
      WHEN r.observation_id IN (SELECT observation_id FROM selected)
        OR r.observation_type='REGULAR_CLOSE'
        OR r.provider IN ('FRANKFURTER_FX','ALPHA_VANTAGE_PRICE')
        OR coalesce(r.raw_payload->>'price_only','false')='true'
        OR coalesce(r.raw_payload->>'price_only_stock_eod','false')='true'
        THEN 'KEEP_PROTECTED'
      WHEN jsonb_typeof(r.raw_payload) IS DISTINCT FROM 'object'
        THEN 'MANUAL_REVIEW_JSON_PAYLOAD'
      WHEN r.created_at >= now()-interval '14 days'
        THEN 'KEEP_RECENT'
      WHEN r.provider IN ('COINGECKO','TWELVE_DATA_FX','TWELVE_DATA_QUOTE')
        AND r.per_day_rank=1 THEN 'KEEP_DAILY_SAMPLE'
      WHEN r.provider IN ('COINGECKO','TWELVE_DATA_FX','TWELVE_DATA_QUOTE')
        AND r.per_day_rank>1 THEN 'ARCHIVE_REVIEW_ONLY'
      ELSE 'MANUAL_REVIEW'
    END AS disposition
  FROM ranked r
)
SELECT disposition,COUNT(*) AS row_count,
       MIN(session_date) AS earliest_session,MAX(session_date) AS latest_session
FROM classified
GROUP BY disposition
ORDER BY row_count DESC;

-- 4. Database protection/dependencies. External consumers and Sheet references
-- are NOT represented by FKs: check them separately before any deletion.
SELECT (SELECT COUNT(*) FROM pg_constraint
        WHERE contype='f'
          AND confrelid='fwios.market_observations'::regclass) AS inbound_foreign_keys,
       (SELECT COUNT(*) FROM pg_trigger
        WHERE tgrelid='fwios.market_observations'::regclass
          AND tgname='market_observations_append_only'
          AND tgenabled='O') AS append_only_guard_enabled,
       pg_size_pretty(pg_total_relation_size('fwios.market_observations'::regclass))
         AS total_size;

-- 5. US Stock EOD acceptance gate. Do not start destructive steps until
-- GitHub issue #106 is resolved with verified #17 and #18 HTTP 200/readback.
SELECT COUNT(*) AS certified_eod_rows,
       COUNT(DISTINCT instrument_id) AS certified_instruments,
       MAX(session_date) AS latest_certified_session
FROM fwios.market_observations
WHERE provider='ALPHA_VANTAGE_PRICE'
  AND observation_type='REGULAR_CLOSE'
  AND raw_payload->>'price_only_stock_eod'='true';

-- Required external gates: backup+restore rehearsal, independent consumer search,
-- live _Market_Data observation_id readback, matching 10 read-model results, unchanged
-- 44/44 price SQL regression, provider HTTP success; no accounting/trade mutation.
