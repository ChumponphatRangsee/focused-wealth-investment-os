-- FWIOS valuation v2 production cutover validation
-- READ ONLY.

select
  d.ticker,
  d.valuation_run_id,
  d.valuation_as_of,
  d.current_price,
  d.bear_fv,
  d.base_fv,
  d.high_fv,
  d.fair_value,
  d.fair_value_upside,
  r.model_version_id,
  r.production_eligible,
  r.raw_payload->>'rollback_run_id' as rollback_run_id,
  r.raw_payload->>'rollback_model_version_id' as rollback_model_version_id
from fwios.v_dashboard_valuation_map d
join fwios.valuation_runs r on r.run_id=d.valuation_run_id
where d.ticker in ('ACN','EOG','NFLX')
order by d.ticker;

select
  v.model_id,
  v.version_id,
  v.version_label,
  v.status,
  v.regression_status,
  v.confidence_tier,
  v.input_contract->>'production_read_cutover' as production_read_cutover,
  m.model_version as registry_model_version,
  m.confidence_status as registry_confidence_status
from fwios.valuation_model_versions v
join fwios.valuation_models m on m.model_id=v.model_id
where v.model_id in (
  'IT_SERVICES_FCF_COMPOUNDER_V1',
  'E&P_NORMALIZED_FCF_YIELD_V1',
  'STREAMING_FCF_DCF_V1'
)
order by v.model_id,v.version_id;

select
  to_object_key,
  count(*) as lineage_edges
from fwios.v_lineage_edges_resolved
where to_object_key in (
  'VAL-PROD-ACN-ITSERV-V2-20261026',
  'VAL-PROD-EOG-EP-V2-20261026',
  'VAL-PROD-NFLX-STREAM-V2-20261026'
)
group by to_object_key
order by to_object_key;
