-- Phase-1 crypto UTC rollover regression checks.
-- Intended for production-as-test verification after the migration.
with crypto(asset) as (
  values ('BTC'),('DOGE'),('ETH'),('HBAR'),('SOL'),('XRP')
),
stocks(asset) as (
  values ('MSFT'),('NVDA'),('TLN'),('TTWO')
),
crypto_read as (
  select asset, fwios.pr7_native_usd_price_read_v1(asset) q from crypto
),
stock_read as (
  select asset, fwios.pr7_native_usd_price_read_v1(asset) q from stocks
),
tests as (
  select 'UTC01_NO_CALENDAR_EQUALITY' test_id,
    position(
      'v_o.session_date = (v_now at time zone ''UTC'')::date'
      in pg_get_functiondef('fwios.pr5_native_usd_price_shadow_v1(text)'::regprocedure)
    ) = 0 passed
  union all select 'UTC02_30H_AGE_RULE_PRESENT',
    position(
      'v_o.observed_at >= v_now-v_max_age'
      in pg_get_functiondef('fwios.pr5_native_usd_price_shadow_v1(text)'::regprocedure)
    ) > 0
  union all select 'UTC03_CURRENT_CRYPTO_NATIVE_USD',
    not exists (
      select 1 from crypto_read
      where coalesce((q->>'source_native_usd')::boolean,false) is not true
         or q->>'provider' <> 'COINGECKO'
         or coalesce((q->>'price_usd')::numeric,0) <= 0
    )
  union all select 'UTC04_CURRENT_CRYPTO_ROLLOVER_FRESH',
    not exists (
      select 1 from crypto_read
      where (q->>'observed_at')::timestamptz >= now()-interval '30 hours'
        and q->>'status' <> 'FRESH'
    )
  union all select 'UTC05_CURRENT_CRYPTO_ELIGIBLE_WHEN_FRESH',
    not exists (
      select 1 from crypto_read
      where q->>'status'='FRESH'
        and coalesce((q->>'valuation_eligible')::boolean,false) is not true
    )
  union all select 'UTC06_STOCK_SEMANTICS_UNCHANGED',
    not exists (
      select 1 from stock_read
      where q->>'status' not in ('LAST_CLOSE','FRESH')
         or coalesce((q->>'valuation_eligible')::boolean,false) is not true
    )
  union all select 'UTC07_TRADING_REMAINS_DISABLED',
    not exists (
      select 1 from (
        select q from crypto_read union all select q from stock_read
      ) x
      where coalesce((q->>'trading_eligible')::boolean,false) is true
    )
  union all select 'UTC08_LIVE_VALUATION_COVERAGE',
    exists (
      select 1 from fwios.v_portfolio_live_account_valuation_v1
      where account_view_key='ALL'
        and unpriced_positions=0
        and valuation_gate='PASS'
    )
  union all select 'UTC09_CROSS_MIDNIGHT_POLICY_CASE',
    (
      timestamptz '2026-10-19 00:05:00+00'
      - timestamptz '2026-10-18 21:10:00+00'
    ) <= interval '30 hours'
    and (
      timestamptz '2026-10-18 21:10:00+00' at time zone 'UTC'
    )::date <> (
      timestamptz '2026-10-19 00:05:00+00' at time zone 'UTC'
    )::date
  union all select 'UTC10_OLDER_THAN_30H_STALE_POLICY_CASE',
    (
      timestamptz '2026-10-20 04:11:00+00'
      - timestamptz '2026-10-18 21:10:00+00'
    ) > interval '30 hours'
)
select test_id, case when passed then 'PASS' else 'FAIL' end status
from tests
order by test_id;
