-- FWIOS PR4 / Supabase-only on-demand canary price read
-- Run from the Supabase project's SQL Editor (privileged administrator).
-- No new tables, views, quote history, Google Sheets sync, provider calls,
-- portfolio valuation, holdings changes or trading actions.
-- Prices are tagged by freshness state, never assumed live.
with assets(asset, sort_order) as (
  values ('BTC'::text, 1), ('NVDA'::text, 2),
         ('TTWO'::text, 3), ('USDTHB'::text, 4)
),
observations as materialized (
  select a.asset, a.sort_order,
         fwios.pr4_market_canary_quote_v2(a.asset) as quote
  from assets a
)
select
  asset,
  quote->>'status' as freshness_status,
  (quote->>'price')::numeric as price,
  quote->>'currency' as currency,
  quote->>'quote_kind' as quote_kind,
  quote->>'provider' as provider,
  quote->>'session_date' as session_date,
  (quote->>'observed_at')::timestamptz as observed_at,
  (quote->>'valid_until')::timestamptz as valid_until,
  (quote->>'checked_at')::timestamptz as checked_at,
  (quote->>'accounting_eligible')::boolean as accounting_eligible,
  (quote->>'valuation_eligible')::boolean as valuation_eligible,
  (quote->>'canary_only')::boolean as canary_only
from observations
order by sort_order;
