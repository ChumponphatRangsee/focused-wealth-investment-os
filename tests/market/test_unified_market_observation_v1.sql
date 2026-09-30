-- Unified Market Observation Layer v1 regression checks
with tests as (
 select 'MKT01_POLICY' test_id,
   exists(select 1 from fwios.policy_versions where policy_version_id='POL-MARKET-OBSERVATION-V1'
     and lifecycle_status='ACTIVE' and config->>'production_read_cutover'='false'
     and config->>'manual_web_price_bypass'='false') passed
 union all select 'MKT02_IDENTITY',
   not exists(select 1 from fwios.market_daily_closes where instrument_id is null)
   and not exists(select 1 from fwios.market_price_quotes where instrument_id is null)
   and not exists(select 1 from fwios.market_price_snapshots where instrument_id is null)
   and not exists(select 1 from fwios.portfolio_market_quote_snapshots where instrument_id is null)
 union all select 'MKT03_DECISION_QUOTES',
   not exists(select 1 from fwios.market_price_quotes where market_observation_id is null)
 union all select 'MKT04_DAILY_CLOSES',
   not exists(select 1 from fwios.market_daily_closes where primary_observation_id is null)
   and not exists(select 1 from fwios.market_daily_closes where secondary_close is not null and secondary_observation_id is null)
 union all select 'MKT05_DECISION_VERIFY',
   not exists(select 1 from fwios.market_price_snapshots where primary_observation_id is null or market_verification_id is null)
 union all select 'MKT06_PORTFOLIO_QUOTES',
   not exists(select 1 from fwios.portfolio_market_quote_snapshots where market_observation_id is null)
 union all select 'MKT07_FX',
   not exists(select 1 from fwios.portfolio_market_quote_snapshots where native_currency<>'THB' and fx_rate_thb is not null and fx_observation_id is null)
 union all select 'MKT08_PINS_DUAL',
   exists(select 1 from fwios.market_price_snapshots s
     join fwios.market_observations p on p.observation_id=s.primary_observation_id
     join fwios.market_observations x on x.observation_id=s.crosscheck_observation_id
     where s.snapshot_id='PX-PINS-QHREVAL-20260906' and p.observation_id<>x.observation_id
       and p.observation_value=20.28 and x.observation_value=20.30)
 union all select 'MKT09_PINS_PASS',
   exists(select 1 from fwios.market_price_snapshots where snapshot_id='PX-PINS-QHREVAL-20260906'
     and selected_price=20.28 and abs(divergence_pct-0.000986193293885602)<0.000000000001
     and conflict_status='PASS' and price_gate='PASS')
 union all select 'MKT10_PINS_CONFLICT',
   exists(select 1 from fwios.market_price_snapshots where snapshot_id='PX-PINS-20260910'
     and selected_price=18.655 and abs(divergence_pct-0.012597158938622352)<0.000000000001
     and conflict_status='CONFLICT' and price_gate='BLOCKED - PRICE CONFLICT')
 union all select 'MKT11_TYPES',
   exists(select 1 from fwios.market_observations where observation_type='REGULAR_CLOSE')
   and exists(select 1 from fwios.market_observations where observation_type='LIVE_QUOTE')
   and exists(select 1 from fwios.market_observations where observation_type='FX')
 union all select 'MKT12_RLS',
   not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='fwios' and c.relname in ('market_observations','market_observation_legacy_links','market_verification_sets')
       and not c.relrowsecurity)
 union all select 'MKT13_TRIGGERS',
   (select count(*) from pg_trigger where tgrelid in (
     'fwios.market_price_quotes'::regclass,'fwios.market_daily_closes'::regclass,
     'fwios.market_price_snapshots'::regclass,'fwios.portfolio_market_quote_snapshots'::regclass)
     and not tgisinternal and tgname in (
     'sync_market_price_quote_observation','sync_market_daily_close_observation',
     'sync_market_price_snapshot_observation','sync_portfolio_market_quote_observation'))=4
 union all select 'MKT14_REGISTERED',
   not exists(select 1 from fwios.decision_policy_regression_runs
     where policy_version_id='POL-MARKET-OBSERVATION-V1' and status<>'PASS')
)
select test_id,case when passed then 'PASS' else 'FAIL' end status
from tests order by test_id;
