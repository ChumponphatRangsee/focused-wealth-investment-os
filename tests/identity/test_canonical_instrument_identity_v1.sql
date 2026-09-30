-- Canonical Instrument Identity v1 regression checks
with tests as (
  select 'ID01_POLICY_ACTIVE' test_id,
    exists(
      select 1 from fwios.policy_versions
      where policy_version_id='POL-INSTRUMENT-IDENTITY-V1'
        and lifecycle_status='ACTIVE'
        and config->>'production_read_cutover'='false'
        and config->>'auto_trade'='false'
        and config->>'human_execution_only'='true'
    ) passed

  union all select 'ID02_70_INSTRUMENTS',
    (select count(*)=70 from fwios.instruments where legacy_seed_key is not null)

  union all select 'ID03_64_STOCK_6_CRYPTO',
    (select count(*)=64 from fwios.instruments where asset_class='Stock' and legacy_seed_key is not null)
    and
    (select count(*)=6 from fwios.instruments where asset_class='Crypto' and legacy_seed_key is not null)

  union all select 'ID04_CURRENT_PRIMARY_SYMBOL_COVERAGE',
    not exists(
      select 1 from fwios.instruments i
      where i.legacy_seed_key is not null
        and not exists(
          select 1 from fwios.instrument_symbols s
          where s.instrument_id=i.instrument_id
            and s.active=true and s.valid_to is null and s.is_primary=true
        )
    )

  union all select 'ID05_NO_ACTIVE_SYMBOL_COLLISION',
    not exists(
      select upper(symbol),upper(venue),upper(symbol_namespace)
      from fwios.instrument_symbols
      where active=true and valid_to is null
      group by 1,2,3
      having count(*)>1
    )

  union all select 'ID06_ADBE_DETERMINISTIC',
    fwios.resolve_instrument_id_v1('ADBE','Stock',null,null)
      =(select instrument_id from fwios.companies where ticker='ADBE')

  union all select 'ID07_PINS_DETERMINISTIC',
    fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
      =(select instrument_id from fwios.companies where ticker='PINS')

  union all select 'ID08_BTC_DETERMINISTIC',
    fwios.resolve_instrument_id_v1('BTC','Crypto',null,null)
      =(select instrument_id from fwios.portfolio_assets where asset_symbol='BTC')

  union all select 'ID09_COMPANIES_BACKFILLED',
    not exists(select 1 from fwios.companies where instrument_id is null)

  union all select 'ID10_RESEARCH_BACKFILLED',
    not exists(select 1 from fwios.research_candidates where instrument_id is null)

  union all select 'ID11_THESIS_BACKFILLED',
    not exists(select 1 from fwios.thesis_registry where instrument_id is null)

  union all select 'ID12_PORTFOLIO_ASSETS_BACKFILLED',
    not exists(select 1 from fwios.portfolio_assets where instrument_id is null)

  union all select 'ID13_PORTFOLIO_TX_BACKFILLED',
    not exists(select 1 from fwios.portfolio_transactions where instrument_id is null)

  union all select 'ID14_MARKET_DAILY_BACKFILLED',
    not exists(select 1 from fwios.market_daily_closes where instrument_id is null)

  union all select 'ID15_MARKET_QUOTES_BACKFILLED',
    not exists(select 1 from fwios.market_price_quotes where instrument_id is null)

  union all select 'ID16_MARKET_SNAPSHOTS_BACKFILLED',
    not exists(select 1 from fwios.market_price_snapshots where instrument_id is null)

  union all select 'ID17_LEGACY_COMPANY_SYMBOL_PARITY',
    not exists(
      select 1
      from fwios.companies c
      join fwios.v_instrument_identity_current i using(instrument_id)
      where c.ticker<>i.ticker
    )

  union all select 'ID18_LEGACY_PORTFOLIO_SYMBOL_PARITY',
    not exists(
      select 1
      from fwios.portfolio_assets p
      join fwios.v_instrument_identity_current i using(instrument_id)
      where p.asset_symbol<>i.asset_symbol or p.asset_class<>i.asset_class
    )

  union all select 'ID19_PRIVATE_RLS',
    not exists(
      select 1
      from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='fwios'
        and c.relname in ('asset_entities','instruments','instrument_symbols','instrument_identifiers')
        and c.relrowsecurity=false
    )

  union all select 'ID20_REGISTERED_REGRESSIONS_PASS',
    not exists(
      select 1 from fwios.decision_policy_regression_runs
      where policy_version_id='POL-INSTRUMENT-IDENTITY-V1'
        and status<>'PASS'
    )
)
select test_id,case when passed then 'PASS' else 'FAIL' end status
from tests
order by test_id;
