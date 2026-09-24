-- Dashboard Valuation Map v1 regression checks
with tests as (
  select 'V01_SCENARIO_ROWS_PRESENT' test_id,
    ((select count(*) from fwios.v_dashboard_valuation_map) > 0) passed
  union all select 'V02_ALL_ROWS_HAVE_SCENARIOS',
    (not exists (
      select 1 from fwios.v_dashboard_valuation_map
      where bear_fv is null or base_fv is null or high_fv is null or fair_value is null
    ))
  union all select 'V03_SCENARIO_ORDER',
    (not exists (
      select 1 from fwios.v_dashboard_valuation_map
      where not (bear_fv <= base_fv and base_fv <= high_fv)
    ))
  union all select 'V04_PRICE_VERIFY_FAIL_CLOSED',
    (not exists (
      select 1 from fwios.v_dashboard_valuation_map
      where price_gate <> 'PASS' and system_signal <> 'PRICE VERIFY'
    ))
  union all select 'V05_BUY_REVIEW_REQUIRES_PRICE_PASS',
    (not exists (
      select 1 from fwios.v_dashboard_valuation_map
      where system_signal='BUY REVIEW' and price_gate <> 'PASS'
    ))
  union all select 'V06_PAYLOAD_INCLUDES_VALUATION_MAP',
    (jsonb_array_length(fwios.dashboard_refresh_payload_v1()#>'{data,valuation_map}') =
     (select count(*) from fwios.v_dashboard_valuation_map))
  union all select 'V07_REFRESH_SCHEMA',
    (fwios.dashboard_refresh_payload_v1()->>'schema_version'='DASHBOARD_REFRESH_PAYLOAD_V1_1')
  union all select 'V08_NO_AUTO_TRADE_CHANGE',
    (((fwios.dashboard_refresh_payload_v1()#>>'{data,system_health,0,auto_trade}')::boolean)=false)
)
select test_id, case when passed then 'PASS' else 'FAIL' end status
from tests
order by test_id;
