create or replace view fwios.v_decision_refresh_api_quota_today as
select q.provider_group,q.daily_limit,q.price_budget,q.validator_budget,q.reserve_budget,
       count(u.usage_id) filter (where u.endpoint_class='PRICE')::int as price_used,
       count(u.usage_id) filter (where u.endpoint_class='VALIDATOR')::int as validator_used,
       count(u.usage_id) filter (where u.endpoint_class='RESERVE')::int as reserve_used,
       count(u.usage_id)::int as total_used,
       greatest(q.daily_limit-count(u.usage_id),0)::int as total_remaining,
       greatest(q.price_budget-count(u.usage_id) filter (where u.endpoint_class='PRICE'),0)::int as price_remaining,
       greatest(q.validator_budget-count(u.usage_id) filter (where u.endpoint_class='VALIDATOR'),0)::int as validator_remaining,
       greatest(q.reserve_budget-count(u.usage_id) filter (where u.endpoint_class='RESERVE'),0)::int as reserve_remaining,
       (now() at time zone 'America/New_York')::date as usage_date_et
from fwios.decision_refresh_api_quota_policy q
left join fwios.decision_refresh_api_usage u on u.provider_group=q.provider_group and u.usage_date_et=(now() at time zone 'America/New_York')::date
where q.active=true
group by q.provider_group,q.daily_limit,q.price_budget,q.validator_budget,q.reserve_budget;
revoke all on fwios.v_decision_refresh_api_quota_today from anon,authenticated;

update fwios.decision_refresh_provider_registry
set config=config||jsonb_build_object('crosscheck_provider','ALPHA_VANTAGE_PRICE','eod_availability_policy','after 00:00 ET on next trading day','scheduler_utc','05:20 Mon-Fri','quota_aware',true),updated_at=now()
where provider_key='TWELVE_DATA';
update fwios.decision_refresh_provider_registry
set config=config||jsonb_build_object('shared_daily_limit',25,'daily_price_budget',20,'validator_budget',2,'reserve_budget',3,'scheduler_utc','05:20 Mon-Fri','quota_aware',true),updated_at=now()
where provider_key='ALPHA_VANTAGE_PRICE';
update fwios.decision_refresh_provider_registry
set config=config||jsonb_build_object('shared_daily_limit',25,'daily_scheduler',false,'event_driven_only',true,'quota_aware',true),updated_at=now()
where provider_key='ALPHA_VANTAGE_CONSENSUS';

update fwios.system_state
set state_value=state_value||jsonb_build_object(
  'price_scheduler_version','QUOTA_AWARE_EOD_V1','price_scheduler_cron_utc','20 5 * * 1-5',
  'price_target_policy','PREVIOUS_US_WEEKDAY; EXACT_SESSION_REQUIRED','alpha_daily_limit',25,'alpha_price_budget',20,
  'alpha_validator_budget',2,'alpha_reserve_budget',3,'provider_validator_cron_utc','17 6 * * 1,3,5',
  'provider_validator_cooldown_hours',20,'consensus_daily_enqueue',false,'quota_guard_runtime','worker_v12_validator_v4'
),updated_at=now()
where state_key='auto_decision_refresh_v1';
