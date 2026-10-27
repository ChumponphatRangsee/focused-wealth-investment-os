-- PINS current-price / hardening / Decision lineage repair acceptance.
-- Read-only regression. Every row must PASS.

with checks as (
  select 'PINS-01 current hardening id' test_id,
    exists(select 1 from fwios.v_candidate_quality_hardening_current
      where ticker='PINS' and hardening_snapshot_id='HARD-QHR-PINS-20261026-3b737f3fd20c') ok
  union all select 'PINS-02 current hardening remains REVIEW',
    exists(select 1 from fwios.v_candidate_quality_hardening_current
      where ticker='PINS' and overall_gate='REVIEW')
  union all select 'PINS-03 current hardening aligned to current mispricing',
    exists(
      select 1
      from fwios.v_candidate_quality_hardening_current h
      join fwios.v_valuation_mispricing_current m on m.ticker=h.ticker
      where h.ticker='PINS' and h.mispricing_snapshot_id=m.mispricing_snapshot_id
    )
  union all select 'PINS-04 current price gate PASS',
    exists(select 1 from fwios.v_valuation_mispricing_current
      where ticker='PINS'
        and price_snapshot_id='PX-DCL-PINS-20261026-9ea8129c68'
        and effective_price_gate='PASS')
  union all select 'PINS-05 current mispricing PASS',
    exists(select 1 from fwios.v_valuation_mispricing_current
      where ticker='PINS'
        and mispricing_snapshot_id='MIS-QHR-PINS-20261026-59a4494e51'
        and mispricing_gate='PASS')
  union all select 'PINS-06 current decision id',
    exists(select 1 from fwios.v_latest_decision_snapshots
      where ticker='PINS' and decision_snapshot_id='DEC-DPI-PINS-a77877e1ac450268')
  union all select 'PINS-07 decision remains REVIEW',
    exists(select 1 from fwios.v_latest_decision_snapshots
      where ticker='PINS'
        and decision_state='REVIEW - QUALITY HARDENING'
        and promotion_gate='BLOCKED - QUALITY HARDENING')
  union all select 'PINS-08 decision input fail-closed on chase',
    exists(select 1 from fwios.v_latest_decision_snapshots
      where ticker='PINS' and input_integrity_gate='BLOCKED - INCOMPLETE CHASE DATA')
  union all select 'PINS-09 decision portfolio-independent',
    exists(select 1 from fwios.v_latest_decision_snapshots
      where ticker='PINS'
        and portfolio_batch_id is null
        and portfolio_fit_snapshot_id is null)
  union all select 'PINS-10 core score v4 expected',
    exists(select 1 from fwios.v_latest_decision_snapshots
      where ticker='PINS' and core_score=83.8000)
  union all select 'PINS-11 opportunity no longer price-conflict',
    exists(select 1 from fwios.v_opportunity_quality_current
      where ticker='PINS'
        and price_gate='PASS'
        and mispricing_gate='PASS'
        and opportunity_state='MISPRICED_CANDIDATE')
  union all select 'PINS-12 opportunity still fail-closed',
    exists(select 1 from fwios.v_opportunity_quality_current
      where ticker='PINS'
        and score_gate='BLOCKED - RISK'
        and final_buy_review_gate='BLOCKED - CHASE')
  union all select 'PINS-13 no portfolio scenario dependency',
    exists(select 1 from fwios.v_opportunity_quality_current
      where ticker='PINS'
        and portfolio_scenario_gate='NOT_APPLICABLE - PORTFOLIO INDEPENDENT')
  union all select 'PINS-14 valuation to hardening lineage',
    exists(select 1 from fwios.v_lineage_edges_resolved
      where from_artifact_key='VALUATION:VAL-SUPA-PINS-DIGADS-20260905'
        and to_artifact_key='HARDENING:HARD-QHR-PINS-20261026-3b737f3fd20c'
        and edge_type='VALUATION_SUPPORTS_HARDENING')
  union all select 'PINS-15 hardening to decision lineage',
    exists(select 1 from fwios.v_lineage_edges_resolved
      where from_artifact_key='HARDENING:HARD-QHR-PINS-20261026-3b737f3fd20c'
        and to_artifact_key='DECISION:DEC-DPI-PINS-a77877e1ac450268'
        and edge_type='HARDENING_SUPPORTS_DECISION')
  union all select 'PINS-16 historical price-conflict decision retained',
    exists(select 1 from fwios.decision_snapshots
      where decision_snapshot_id='DEC-PINS-REFRESH-20260911'
        and decision_state='PRICE CONFLICT')
  union all select 'PINS-17 protected counts unchanged',
    (select count(*)=58 from fwios.portfolio_transactions)
    and (select count(*)=32 from fwios.portfolio_source_positions)
    and (select count(*)=15 from fwios.portfolio_live_holdings_rows_v1)
    and (select count(*)=3 from fwios.portfolio_accounts)
    and (select count(*)=1 from fwios.human_approval_packets)
    and (select count(*)=0 from fwios.human_approval_events)
  union all select 'PINS-18 auto-trade remains false',
    not exists(select 1 from fwios.policy_versions
      where policy_version_id in (
        'POL-QUALITY-HARDENING-REFRESH-V1',
        'POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2',
        'POL-OPPORTUNITY-QUALITY-V3-PORTFOLIO-INDEPENDENT'
      )
      and coalesce((config->>'auto_trade')::boolean,false)=true)
)
select test_id,case when ok then 'PASS' else 'FAIL' end status
from checks order by test_id;
