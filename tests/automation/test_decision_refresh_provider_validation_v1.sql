with checks as (
  select 'validation_table_exists' as test_name,
         to_regclass('fwios.decision_refresh_provider_validation_runs') is not null as pass
  union all
  select 'twelve_doc_contract_pass', exists(
    select 1 from fwios.decision_refresh_provider_validation_runs
    where provider_key='TWELVE_DATA' and validation_scope='DOCUMENTATION_CONTRACT' and status='PASS'
  )
  union all
  select 'alpha_doc_contract_pass', exists(
    select 1 from fwios.decision_refresh_provider_validation_runs
    where provider_key='ALPHA_VANTAGE' and validation_scope='DOCUMENTATION_CONTRACT' and status='PASS'
  )
  union all
  select 'twelve_adjust_none', (select config->>'adjust'='none' from fwios.decision_refresh_provider_registry where provider_key='TWELVE_DATA')
  union all
  select 'alpha_raw_daily', (select config->>'price_semantics'='raw_as_traded_daily' from fwios.decision_refresh_provider_registry where provider_key='ALPHA_VANTAGE')
  union all
  select 'twelve_not_active', not (select active from fwios.decision_refresh_provider_registry where provider_key='TWELVE_DATA')
  union all
  select 'alpha_not_active', not (select active from fwios.decision_refresh_provider_registry where provider_key='ALPHA_VANTAGE')
  union all
  select 'twelve_not_eligible_without_key', not ((fwios.decision_refresh_provider_promotion_gate('TWELVE_DATA')->>'eligible')::boolean)
  union all
  select 'alpha_not_eligible_without_key', not ((fwios.decision_refresh_provider_promotion_gate('ALPHA_VANTAGE')->>'eligible')::boolean)
  union all
  select 'crosscheck_sessions_required_3',
    (select (config->>'required_crosscheck_sessions')::int=3 from fwios.decision_refresh_provider_registry where provider_key='TWELVE_DATA')
    and
    (select (config->>'required_crosscheck_sessions')::int=3 from fwios.decision_refresh_provider_registry where provider_key='ALPHA_VANTAGE')
)
select case when bool_and(pass) then 'PASS 10/10' else 'FAIL' end as result,
       jsonb_object_agg(test_name,pass order by test_name) as detail
from checks;
