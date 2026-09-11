with checks as (
 select 'alpha_price_ready' n, exists(select 1 from fwios.decision_refresh_provider_registry where provider_key='ALPHA_VANTAGE_PRICE' and active and readiness_status='READY' and source_tier='A') ok
 union all select 'alpha_consensus_isolated', exists(select 1 from fwios.decision_refresh_provider_registry where provider_key='ALPHA_VANTAGE_CONSENSUS' and not active and readiness_status='DEGRADED')
 union all select 'legacy_alpha_disabled', exists(select 1 from fwios.decision_refresh_provider_registry where provider_key='ALPHA_VANTAGE' and not active and readiness_status='DISABLED')
 union all select 'price_gate_eligible', coalesce((fwios.decision_refresh_provider_promotion_gate('ALPHA_VANTAGE_PRICE')->>'eligible')::boolean,false)
 union all select 'consensus_gate_not_eligible', not coalesce((fwios.decision_refresh_provider_promotion_gate('ALPHA_VANTAGE_CONSENSUS')->>'eligible')::boolean,false)
 union all select 'four_price_jobs_pass', (select count(*)=4 from fwios.decision_refresh_jobs where run_id='44aab470-c45d-4e73-9a05-85dada616433'::uuid and job_type='PRICE_PAIR' and ticker in ('HWM','WM','WCN','AMAT') and status='PASS' and output->>'session_date'='2026-09-10' and (output->>'divergence_pct')::numeric<=0.005)
 union all select 'worker_cron_restored', exists(select 1 from cron.job where jobname='fwios-shadow-decision-refresh-worker' and schedule='*/5 * * * *' and active)
 union all select 'provider_validator_hourly', exists(select 1 from cron.job where jobname='fwios-provider-validator-v1' and schedule='17 * * * *' and active)
 union all select 'capability_aware_enqueue', position('ALPHA_VANTAGE_CONSENSUS' in pg_get_functiondef((select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='fwios' and p.proname='start_decision_refresh_shadow' limit 1)))>0
 union all select 'shadow_only', exists(select 1 from fwios.system_state where state_key='auto_decision_refresh_v1' and state_value->>'mode'='SHADOW' and coalesce((state_value->>'authoritative_write')::boolean,false)=false)
)
select sum(case when ok then 1 else 0 end)||'/'||count(*)||' PASS' as result, jsonb_object_agg(n,ok) detail from checks;
