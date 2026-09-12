-- Decision Refresh quota-aware scheduler regression
select case when (select daily_limit=25 and price_budget=20 and validator_budget=2 and reserve_budget=3 from fwios.decision_refresh_api_quota_policy where provider_group='ALPHA_VANTAGE_SHARED') then 'PASS' else 'FAIL' end as quota_policy;
select case when fwios.decision_refresh_target_session_v1('2026-09-14 05:20+00'::timestamptz)='2026-09-11'::date then 'PASS' else 'FAIL' end as monday_targets_friday;
select case when fwios.decision_refresh_target_session_v1('2026-09-15 05:20+00'::timestamptz)='2026-09-14'::date then 'PASS' else 'FAIL' end as tuesday_targets_monday;
select case when (select count(*) from fwios.decision_refresh_price_plan_v1('2026-09-11',20))=20 then 'PASS' else 'FAIL' end as price_plan_capped_20;
select case when (select ticker from fwios.decision_refresh_price_plan_v1('2026-09-11',20) where plan_rank=1)='ADBE' then 'PASS' else 'FAIL' end as material_event_priority;
select case when exists(select 1 from cron.job where jobname='fwios-shadow-decision-refresh-enqueue' and schedule='20 5 * * 1-5' and active) then 'PASS' else 'FAIL' end as eod_cron;
select case when exists(select 1 from cron.job where jobname='fwios-provider-validator-v1' and schedule='17 6 * * 1,3,5' and active) then 'PASS' else 'FAIL' end as validator_cron;
select case when (select state_value->>'quota_guard_runtime'='worker_v12_validator_v4' from fwios.system_state where state_key='auto_decision_refresh_v1') then 'PASS' else 'FAIL' end as runtime_state;
select case when (fwios.dashboard_refresh_payload_v1()->'data'->'current_action'->0->>'auto_trade')::boolean=false and (fwios.dashboard_refresh_payload_v1()->'data'->'current_action'->0->>'human_execution_only')::boolean=true then 'PASS' else 'FAIL' end as execution_isolation;
