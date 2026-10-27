-- FWIOS Quality Hardening Refresh Bridge v1
-- Production acceptance / regression checks.
-- Read-only: this file does not call authorized APPLY.

select 'QHR-01 policy active' as test_case,
  case when exists(
    select 1
    from fwios.policy_versions
    where policy_version_id='POL-QUALITY-HARDENING-REFRESH-V1'
      and lifecycle_status='ACTIVE'
  ) then 'PASS' else 'FAIL' end as status

union all
select 'QHR-02 hardening thresholds unchanged',
  case when exists(
    select 1
    from fwios.policy_versions
    where policy_version_id='POL-QUALITY-HARDENING-V1'
      and (config->>'bear_case_review_below')::numeric=-0.30
      and (config->>'bear_case_fail_below')::numeric=-0.50
      and (config->'owner_earnings'->>'sbc_pass_max')::numeric=0.10
      and (config->>'extreme_mispricing_trigger')::numeric=0.75
  ) then 'PASS' else 'FAIL' end

union all
select 'QHR-03 ACN projects REVIEW',
  case when fwios.preview_quality_hardening_refresh_v1('ACN')->'projected'->>'overall_gate'='REVIEW'
       then 'PASS' else 'FAIL' end

union all
select 'QHR-04 EOG projects FAIL',
  case when fwios.preview_quality_hardening_refresh_v1('EOG')->'projected'->>'overall_gate'='FAIL'
       then 'PASS' else 'FAIL' end

union all
select 'QHR-05 NFLX projects BLOCKED',
  case when fwios.preview_quality_hardening_refresh_v1('NFLX')->'projected'->>'overall_gate'='BLOCKED'
       then 'PASS' else 'FAIL' end

union all
select 'QHR-06 current hardening lineage uses current valuation',
  case when (
    select count(*)
    from fwios.v_research_readiness_current_v1
    where ticker in ('ACN','EOG','NFLX')
      and valuation_run_id=hardening_valuation_run_id
  )=3 then 'PASS' else 'FAIL' end

union all
select 'QHR-07 no investment-review promotion',
  case when (
    select count(*)
    from fwios.v_research_readiness_current_v1
    where ticker in ('ACN','EOG','NFLX')
      and investment_review_ready
  )=0 then 'PASS' else 'FAIL' end

union all
select 'QHR-08 safety flags remain immutable',
  case when exists(
    select 1
    from fwios.policy_versions
    where policy_version_id='POL-QUALITY-HARDENING-REFRESH-V1'
      and (config->>'portfolio_mutation')::boolean=false
      and (config->>'approval_mutation')::boolean=false
      and (config->>'execution_mutation')::boolean=false
      and (config->>'auto_trade')::boolean=false
      and (config->>'human_execution_only')::boolean=true
  ) then 'PASS' else 'FAIL' end

union all
select 'QHR-09 canonical compatibility price snapshots',
  case when (
    select count(*)
    from fwios.market_price_snapshots
    where asset_symbol in ('ACN','EOG','NFLX')
      and session_date=date '2026-10-26'
      and snapshot_id like 'PX-DCL-%'
      and provenance_status='PASS'
      and price_gate='PASS'
  )=3 then 'PASS' else 'FAIL' end

union all
select 'QHR-10 v2-linked mispricing snapshots',
  case when (
    select count(*)
    from fwios.valuation_mispricing_snapshots
    where mispricing_snapshot_id like 'MIS-QHR-%-20261026-%'
      and valuation_run_id in (
        'VAL-PROD-ACN-ITSERV-V2-20261026',
        'VAL-PROD-EOG-EP-V2-20261026',
        'VAL-PROD-NFLX-STREAM-V2-20261026'
      )
  )=3 then 'PASS' else 'FAIL' end;
