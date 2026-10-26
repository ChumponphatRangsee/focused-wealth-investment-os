-- ACN v2 post-APPLY / shadow validation receipt
-- READ ONLY.

with receipt as (
  select *
  from fwios.research_ingest_receipts_v1
  where payload_fingerprint='451a19fcd56e8487161a173ed8ecc340'
),
shadow as (
  select *
  from fwios.valuation_runs
  where run_id='VAL-SHADOW-ACN-ITSERV-V2-20261026'
),
inputs as (
  select
    count(*) total_inputs,
    count(*) filter(where required) required_inputs,
    count(*) filter(where required and gate_status='PASS') required_pass,
    count(*) filter(where gate_status='PASS') all_pass
  from fwios.valuation_run_inputs
  where run_id='VAL-SHADOW-ACN-ITSERV-V2-20261026'
),
lineage as (
  select count(*) lineage_edges
  from fwios.v_lineage_edges_resolved
  where to_object_key='VAL-SHADOW-ACN-ITSERV-V2-20261026'
    and edge_type='METRIC_INPUT_TO_VALUATION'
),
dashboard as (
  select *
  from fwios.v_dashboard_valuation_map
  where ticker='ACN'
)
select
  r.status apply_status,
  r.evidence_inserted,
  r.observations_inserted,
  s.production_eligible shadow_production_eligible,
  s.model_version_id shadow_model_version,
  s.bear_fv_per_share shadow_bear,
  s.base_fv_per_share shadow_base,
  s.bull_fv_per_share shadow_bull,
  s.probability_weighted_fv_per_share shadow_pw,
  i.total_inputs,i.required_inputs,i.required_pass,i.all_pass,
  l.lineage_edges,
  d.valuation_run_id dashboard_run_id,
  d.fair_value dashboard_pw,
  case
    when r.status='APPLIED'
     and s.production_eligible=false
     and i.total_inputs=10 and i.required_inputs=7 and i.required_pass=7 and i.all_pass=10
     and l.lineage_edges=10
     and d.valuation_run_id='VAL-SUPA-ACN-ITSERV-20260905'
     and abs(s.probability_weighted_fv_per_share-240.7142520975)<0.0000001
    then 'PASS'
    else 'FAIL'
  end validation_status
from receipt r cross join shadow s cross join inputs i cross join lineage l cross join dashboard d;
