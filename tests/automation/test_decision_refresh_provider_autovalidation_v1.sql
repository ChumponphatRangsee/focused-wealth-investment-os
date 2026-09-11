with checks as (
 select 'promotion_gate_exists' n, to_regprocedure('fwios.decision_refresh_provider_promotion_gate(text)') is not null ok union all
 select 'autopromotion_exists', to_regprocedure('fwios.apply_decision_refresh_provider_promotion(text)') is not null union all
 select 'cron_exists', exists(select 1 from cron.job where jobname='fwios-provider-validator-v1' and active) union all
 select 'cron_hourly_17', exists(select 1 from cron.job where jobname='fwios-provider-validator-v1' and schedule='17 * * * *') union all
 select 'state_auto_when_keys_appear', (select state_value->>'provider_validator_mode'='AUTO_WHEN_KEYS_APPEAR' from fwios.system_state where state_key='auto_decision_refresh_v1') union all
 select 'td_validator_config', exists(select 1 from fwios.decision_refresh_provider_registry where provider_key='TWELVE_DATA' and config->>'validator_symbol'='AAPL') union all
 select 'av_validator_config', exists(select 1 from fwios.decision_refresh_provider_registry where provider_key='ALPHA_VANTAGE' and config->>'validator_consensus_symbol'='IBM') union all
 select 'public_cannot_promote', not has_function_privilege('public','fwios.apply_decision_refresh_provider_promotion(text)','EXECUTE') union all
 select 'fresh_live_gate', position('7 days' in pg_get_functiondef('fwios.decision_refresh_provider_promotion_gate(text)'::regprocedure))>0 union all
 select 'fresh_price_gate', position('14' in pg_get_functiondef('fwios.decision_refresh_provider_promotion_gate(text)'::regprocedure))>0
)
select case when bool_and(ok) then 'PASS 10/10' else 'FAIL' end result, jsonb_object_agg(n,ok) detail from checks;
