-- Portfolio Mark-to-Market V1 regression checks
with tests as (
  select 'MTM01_POLICY_ACTIVE' test_id,
    exists(select 1 from fwios.policy_versions where policy_version_id='POL-PORTFOLIO-MTM-V1' and lifecycle_status='ACTIVE') passed
  union all select 'MTM02_OPEN_ASSETS_10',
    (select open_asset_count from fwios.v_portfolio_market_price_health)=10
  union all select 'MTM03_FRESH_10',
    (select fresh_asset_count from fwios.v_portfolio_market_price_health)=10
  union all select 'MTM04_NO_MISSING',
    (select missing_asset_count from fwios.v_portfolio_market_price_health)=0
  union all select 'MTM05_NO_STALE',
    (select stale_asset_count from fwios.v_portfolio_market_price_health)=0
  union all select 'MTM06_PRICING_PASS',
    (select pricing_gate from fwios.v_portfolio_market_price_health)='PASS'
  union all select 'MTM07_STOCK_PROVIDER_AUTOMATED',
    not exists(select 1 from fwios.v_portfolio_market_quote_current
      where asset_class='Stock' and provider not in ('TWELVE_DATA_QUOTE','TWELVE_DATA_DAILY_CLOSE_FALLBACK'))
  union all select 'MTM08_CRYPTO_PROVIDER_AUTOMATED',
    not exists(select 1 from fwios.v_portfolio_market_quote_current
      where asset_class='Crypto' and provider<>'COINGECKO')
  union all select 'MTM09_DASHBOARD_VALUE_LIVE',
    exists(select 1 from fwios.v_dashboard_account_summary
      where account_view_key='ALL' and portfolio_value_thb>300000 and portfolio_value_thb<500000 and batch_status='PASS')
  union all select 'MTM10_COST_BASIS_UNCHANGED',
    abs((select open_cost_basis_thb from fwios.v_dashboard_account_summary where account_view_key='ALL')
        -335340.093379774860703875)<0.01
  union all select 'MTM11_REALIZED_UNCHANGED',
    abs((select realized_pnl_thb from fwios.v_dashboard_account_summary where account_view_key='ALL')
        -21794.0460747930374)<0.01
  union all select 'MTM12_EXPOSURE_MATCH',
    abs((select total_value_thb from fwios.v_portfolio_exposure_current limit 1)
        -(select portfolio_value_thb from fwios.v_dashboard_account_summary where account_view_key='ALL'))<0.01
  union all select 'MTM13_CRON_ACTIVE',
    exists(select 1 from cron.job where jobname='fwios-portfolio-mtm-refresh' and active=true and schedule='*/15 * * * *')
  union all select 'MTM14_LATEST_RUN_PASS',
    (select pricing_gate from fwios.portfolio_mtm_runs order by started_at desc limit 1)='PASS'
  union all select 'MTM15_REFRESH_GATE_PASS',
    (fwios.dashboard_refresh_payload_v1()->>'refresh_gate')='PASS'
  union all select 'MTM16_NO_AUTO_TRADE',
    coalesce((select (state_value->>'auto_trade')::boolean from fwios.system_state
      where state_key='architecture_consolidation_v1'),false)=false
)
select test_id,case when passed then 'PASS' else 'FAIL' end status
from tests order by test_id;
