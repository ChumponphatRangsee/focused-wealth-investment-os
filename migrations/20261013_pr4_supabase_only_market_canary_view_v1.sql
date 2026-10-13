-- FWIOS PR4 — Supabase-only canonical market canary read view.
-- VIEW ONLY: no materialized data, no Sheets writes, no vendor calls, no trades.
-- This canary is not approved for portfolio valuation or trading.
-- RLS: security_invoker on PostgreSQL 17; restrictive privileges on fwios.
create or replace view fwios.v_pr4_market_canary_current
with (security_invoker = true)
as
with allowlist(asset, sort_order) as (
  values ('BTC'::text,1),('NVDA'::text,2),('TTWO'::text,3),('USDTHB'::text,4)
),
observations as (
  select a.asset, a.sort_order,
         fwios.pr4_market_canary_quote_v2(a.asset) as payload
  from allowlist a
)
select
  sort_order,
  asset,
  payload->>'status' as freshness_status,
  (payload->>'price')::numeric as price,
  payload->>'currency' as currency,
  payload->>'quote_kind' as quote_kind,
  payload->>'provider' as provider,
  payload->>'observation_type' as observation_type,
  payload->>'source_tier' as source_tier,
  payload->>'session_date' as session_date,
  (payload->>'observed_at')::timestamptz as observed_at,
  (payload->>'valid_until')::timestamptz as valid_until,
  (payload->>'checked_at')::timestamptz as checked_at,
  (payload->>'observation_id')::uuid as observation_id,
  (payload->>'instrument_id')::uuid as instrument_id,
  (payload->>'accounting_eligible')::boolean as accounting_eligible,
  (payload->>'valuation_eligible')::boolean as valuation_eligible,
  (payload->>'trading_eligible')::boolean as trading_eligible,
  (payload->>'canary_only')::boolean as canary_only,
  (payload->>'read_only')::boolean as read_only
from observations
order by sort_order;

comment on view fwios.v_pr4_market_canary_current is
  'Read-on-query Supabase market canary from existing observations only. Not a Sheet sync, valuation feed or trade trigger; no persistent quotes or provider calls.';

revoke all on fwios.v_pr4_market_canary_current from public, anon, authenticated;
grant select on fwios.v_pr4_market_canary_current to service_role;
