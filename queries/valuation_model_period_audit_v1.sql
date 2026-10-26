-- FWIOS Valuation Model Period/Version Audit v1
-- Read-only. No production writes, no model cutover, no valuation run.

with implemented as (
  select
    m.model_id,
    m.archetype,
    m.model_family,
    m.model_version,
    m.required_metric_ids,
    mv.version_id,
    mv.input_contract,
    mv.model_policy,
    mv.assumptions
  from fwios.valuation_models m
  left join lateral (
    select v.*
    from fwios.valuation_model_versions v
    where v.model_id=m.model_id
      and v.status='PRODUCTION'
    order by
      case when v.version_label=m.model_version then 0 else 1 end,
      v.effective_from desc nulls last,
      v.created_at desc
    limit 1
  ) mv on true
  where m.production_status='IMPLEMENTED'
),
flags as (
  select
    i.*,
    exists (
      select 1
      from unnest(coalesce(i.required_metric_ids,'{}'::text[])) x(metric_id)
      where metric_id ~* '(fy[0-9]{2,4}|(^|_)q[1-4]($|_))'
    ) as period_encoded_required_metric,
    exists (
      select 1
      from jsonb_array_elements_text(
        coalesce(i.input_contract->'required_metrics',
                 i.input_contract->'required_metric_ids',
                 i.input_contract->'required_inputs',
                 '[]'::jsonb)
      ) x(metric_id)
      where metric_id ~* '(fy[0-9]{2,4}|(^|_)q[1-4]($|_))'
    ) as period_encoded_required_contract,
    (
      coalesce(i.input_contract::text,'') ~* '(fy[0-9]{2,4}|(^|[^a-z0-9])q[1-4]([^a-z0-9]|$))'
      and not exists (
        select 1
        from jsonb_array_elements_text(
          coalesce(i.input_contract->'required_metrics',
                   i.input_contract->'required_metric_ids',
                   i.input_contract->'required_inputs',
                   '[]'::jsonb)
        ) x(metric_id)
        where metric_id ~* '(fy[0-9]{2,4}|(^|_)q[1-4]($|_))'
      )
    ) as period_encoded_nonrequired_contract,
    concat_ws(' ',coalesce(i.model_policy::text,''),coalesce(i.assumptions::text,''))
      ~* '(fy[0-9]{2,4}|(^|[^a-z0-9])q[1-4]([^a-z0-9]|$))'
      as temporal_anchor_in_policy_or_assumptions
  from implemented i
),
latest_tickers as (
  select model_id, array_agg(ticker order by ticker) tickers
  from (
    select distinct on (ticker) ticker, model_id
    from fwios.valuation_runs
    where production_eligible=true
    order by ticker, created_at desc
  ) x
  group by model_id
),
version_governance as (
  select
    m.model_id,
    m.model_version,
    count(*) filter (where v.status='PRODUCTION') as production_version_count,
    bool_or(v.status='PRODUCTION' and v.version_label=m.model_version) as registry_version_has_matching_production_version,
    array_agg(v.version_id order by v.effective_from,v.created_at)
      filter (where v.status='PRODUCTION') as production_version_ids
  from fwios.valuation_models m
  left join fwios.valuation_model_versions v on v.model_id=m.model_id
  where m.production_status='IMPLEMENTED'
  group by m.model_id,m.model_version
)
select
  f.model_id,
  f.archetype,
  f.version_id,
  coalesce(t.tickers,'{}'::text[]) as latest_production_tickers,
  case
    when f.period_encoded_required_metric or f.period_encoded_required_contract then 'RED'
    when f.period_encoded_nonrequired_contract or f.temporal_anchor_in_policy_or_assumptions then 'AMBER'
    else 'GREEN'
  end as period_audit_status,
  array(
    select metric_id
    from unnest(coalesce(f.required_metric_ids,'{}'::text[])) metric_id
    where metric_id ~* '(fy[0-9]{2,4}|(^|_)q[1-4]($|_))'
    order by metric_id
  ) as period_encoded_required_metrics,
  f.period_encoded_nonrequired_contract,
  f.temporal_anchor_in_policy_or_assumptions,
  case
    when vg.production_version_count <> 1
      or not coalesce(vg.registry_version_has_matching_production_version,false)
      then 'RED'
    else 'GREEN'
  end as version_governance_status,
  vg.model_version as registry_model_version,
  vg.production_version_count,
  vg.production_version_ids
from flags f
left join latest_tickers t using(model_id)
left join version_governance vg using(model_id)
order by
  case
    when f.period_encoded_required_metric or f.period_encoded_required_contract then 1
    when f.period_encoded_nonrequired_contract or f.temporal_anchor_in_policy_or_assumptions then 2
    else 3
  end,
  f.model_id;
