-- Decision-Relevant Metric Observation Model v2 regression checks
with tests as (
  select 'MET01_POLICY_ACTIVE' test_id,
    exists(
      select 1 from fwios.policy_versions
      where policy_version_id='POL-METRIC-OBSERVATION-V2'
        and lifecycle_status='ACTIVE'
        and config->>'production_read_cutover'='false'
        and config->>'auto_trade'='false'
    ) passed

  union all select 'MET02_LEGACY_IDENTITY_BACKFILLED',
    not exists(select 1 from fwios.company_metrics where instrument_id is null)
    and not exists(select 1 from fwios.normalized_metrics where instrument_id is null)
    and not exists(select 1 from fwios.evidence_records where ticker is not null and instrument_id is null)

  union all select 'MET03_COMPANY_COMPAT_COUNT',
    (select count(*) from fwios.metric_observations where source_table='fwios.company_metrics')
    =(select count(*) from fwios.company_metrics)

  union all select 'MET04_NORMALIZED_COMPAT_COUNT',
    (select count(*) from fwios.metric_observations where source_table='fwios.normalized_metrics')
    =(select count(*) from fwios.normalized_metrics)

  union all select 'MET05_TYPED_VALUE_EXCLUSIVE',
    not exists(
      select 1 from fwios.metric_observations
      where ((value_numeric is not null)::int+(value_text is not null)::int+(value_boolean is not null)::int)<>1
    )

  union all select 'MET06_ADBE_ARR_Q2_Q3',
    (select count(distinct fiscal_quarter) from fwios.metric_observations
     where instrument_id=fwios.resolve_instrument_id_v1('ADBE','Stock',null,null)
       and metric_code='RECURRING_REVENUE_GROWTH_YOY'
       and fiscal_year=2026 and fiscal_quarter in (2,3)
       and observation_layer in ('REPORTED','DERIVED'))=2

  union all select 'MET07_PINS_MAU_Q1_Q2',
    (select count(distinct fiscal_quarter) from fwios.metric_observations
     where instrument_id=fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
       and metric_code='GLOBAL_MAU_GROWTH_YOY'
       and fiscal_year=2026 and fiscal_quarter in (1,2))=2

  union all select 'MET08_PINS_REVENUE_GROWTH_Q1_Q2',
    (select count(distinct fiscal_quarter) from fwios.metric_observations
     where instrument_id=fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
       and metric_code='REVENUE_GROWTH_YOY'
       and fiscal_year=2026 and fiscal_quarter in (1,2))=2

  union all select 'MET09_PINS_FCF_YOY',
    (select count(distinct fiscal_year) from fwios.metric_observations
     where instrument_id=fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
       and metric_code='FREE_CASH_FLOW'
       and period_type='QUARTER'
       and fiscal_quarter=2 and fiscal_year in (2025,2026))=2

  union all select 'MET10_PINS_ARPU_BASELINE',
    exists(
      select 1 from fwios.metric_observations
      where observation_key='THESIS:PINS:GLOBAL_ARPU:Q2-2026'
        and value_numeric=1.86 and fiscal_year=2026 and fiscal_quarter=2
    )

  union all select 'MET11_PINS_SBC_PERIODS',
    exists(
      select 1 from fwios.metric_observations
      where instrument_id=fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
        and metric_code='SHARE_BASED_COMPENSATION'
        and period_type='YTD' and fiscal_year=2026
    )
    and exists(
      select 1 from fwios.metric_observations
      where instrument_id=fwios.resolve_instrument_id_v1('PINS','Stock',null,null)
        and metric_code='SBC_TO_REVENUE' and period_type='LTM'
    )

  union all select 'MET12_NORMALIZED_HAS_SOURCE_OBSERVATION',
    not exists(
      select 1 from fwios.metric_observations
      where source_table='fwios.normalized_metrics'
        and source_observation_ids='{}'::uuid[]
    )

  union all select 'MET13_NO_RUNTIME_TEXT_CAST_NEEDED',
    not exists(
      select 1 from fwios.metric_observations o
      join fwios.metric_definitions d using(metric_code)
      where d.value_kind='NUMERIC' and o.value_numeric is null
    )

  union all select 'MET14_PRIVATE_RLS',
    not exists(
      select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='fwios'
        and c.relname in ('metric_definitions','metric_legacy_mappings','metric_observations')
        and c.relrowsecurity=false
    )

  union all select 'MET15_REGISTERED_REGRESSIONS_PASS',
    not exists(
      select 1 from fwios.decision_policy_regression_runs
      where policy_version_id='POL-METRIC-OBSERVATION-V2'
        and status<>'PASS'
    )
)
select test_id,case when passed then 'PASS' else 'FAIL' end status
from tests
order by test_id;
