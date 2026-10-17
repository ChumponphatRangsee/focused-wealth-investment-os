-- FWIOS PR4 / Supabase-only on-demand USD-oriented canary read
-- Run from the Supabase project's SQL Editor (privileged administrator).
-- No new tables, views, quote history, Google Sheets sync, provider calls,
-- portfolio valuation, holdings changes or trading actions.
-- Stock prices are native USD. BTC/USD is derived from canonical BTC/THB\n-- and USDTHB reference (FX older than 30m => BTC/USD STALE).\n-- USDTHB remains THB per 1 USD. All prices remain canary-only,\n-- accounting/valuation/trading ineligible and never assumed live.
with assets(asset, sort_order) as (
  values ('BTC'::text, 1), ('NVDA'::text, 2),
         ('TTWO'::text, 3), ('USDTHB'::text, 4)
),
observations as materialized (
  select a.asset, a.sort_order,
         fwios.pr4_market_canary_usd_v1(a.asset) as quote
  from assets a
)
select
  asset,
  quote->>'status' as freshness_status,
  (quote->>'price')::numeric as price,
  quote->>'currency' as currency,
  (quote->>'price_is_derived')::boolean as price_is_derived,
  quote->>'fx_status' as fx_status,
  (quote->>'fx_rate_thb_per_usd')::numeric as fx_rate_thb_per_usd,
  quote->>'quote_kind' as quote_kind,
  quote->>'provider' as provider,
  quote->>'fx_provider' as fx_provider,
  quote->>'session_date' as session_date,
  (quote->>'observed_at')::timestamptz as observed_at,
  (quote->>'valid_until')::timestamptz as valid_until,
  (quote->>'checked_at')::timestamptz as checked_at,
  quote->>'origin' as origin,
  (quote->>'accounting_eligible')::boolean as accounting_eligible,
  (quote->>'valuation_eligible')::boolean as valuation_eligible,
  (quote->>'canary_only')::boolean as canary_only,
  (quote->>'new_provider_calls')::integer as new_provider_calls
from observations
order by sort_order;
