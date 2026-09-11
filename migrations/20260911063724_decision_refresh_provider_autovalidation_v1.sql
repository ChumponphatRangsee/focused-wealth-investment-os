create or replace function fwios.decision_refresh_provider_promotion_gate(p_provider_key text)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  p record;
  v_has_secret boolean := false;
  v_doc boolean := false;
  v_connect boolean := false;
  v_schema boolean := false;
  v_session boolean := false;
  v_adjust boolean := false;
  v_rate boolean := false;
  v_consensus_schema boolean := true;
  v_consensus_fresh boolean := true;
  v_crosscheck_sessions integer := 0;
  v_required_sessions integer := 3;
  v_eligible boolean := false;
  v_live_cutoff timestamptz := now() - interval '7 days';
  v_px_cutoff date := (now() at time zone 'America/New_York')::date - 14;
begin
  select * into p from fwios.decision_refresh_provider_registry where provider_key=p_provider_key;
  if p is null then return jsonb_build_object('provider_key',p_provider_key,'eligible',false,'reason','PROVIDER_NOT_FOUND'); end if;
  if p.requires_secret and p.secret_name is not null then
    select exists(select 1 from vault.secrets where name=p.secret_name) into v_has_secret;
  else v_has_secret := true; end if;
  select exists(select 1 from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='DOCUMENTATION_CONTRACT' and status='PASS') into v_doc;
  select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='LIVE_CONNECTIVITY' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_connect;
  select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='RESPONSE_SCHEMA' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_schema;
  select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='SESSION_SEMANTICS' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_session;
  select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='ADJUSTMENT_SEMANTICS' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_adjust;
  select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='RATE_LIMIT' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_rate;
  select coalesce((p.config->>'required_crosscheck_sessions')::integer,3) into v_required_sessions;
  select count(distinct session_date) into v_crosscheck_sessions from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='PRICE_CROSSCHECK' and status='PASS' and session_date>=v_px_cutoff;
  if p_provider_key='ALPHA_VANTAGE' then
    select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='CONSENSUS_SCHEMA' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_consensus_schema;
    select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='CONSENSUS_FRESHNESS' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_consensus_fresh;
  end if;
  v_eligible := v_has_secret and v_doc and v_connect and v_schema and v_session and v_adjust and v_rate and v_crosscheck_sessions >= v_required_sessions and v_consensus_schema and v_consensus_fresh;
  return jsonb_build_object('provider_key',p_provider_key,'eligible',v_eligible,'current_state',jsonb_build_object('active',p.active,'readiness_status',p.readiness_status,'source_tier',p.source_tier),'checks',jsonb_build_object('secret_present',v_has_secret,'documentation_contract',v_doc,'live_connectivity',v_connect,'response_schema',v_schema,'session_semantics',v_session,'adjustment_semantics',v_adjust,'rate_limit',v_rate,'price_crosscheck_sessions',v_crosscheck_sessions,'required_crosscheck_sessions',v_required_sessions,'consensus_schema',v_consensus_schema,'consensus_freshness',v_consensus_fresh,'live_validation_max_age_days',7,'price_crosscheck_window_days',14),'promotion_target',case when v_eligible then jsonb_build_object('active',true,'readiness_status','READY','source_tier','A') else null end);
end $$;

create or replace function fwios.apply_decision_refresh_provider_promotion(p_provider_key text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare g jsonb; ok boolean;
begin
  if p_provider_key not in ('TWELVE_DATA','ALPHA_VANTAGE') then return jsonb_build_object('provider_key',p_provider_key,'promoted',false,'reason','PROVIDER_NOT_AUTOPROMOTABLE'); end if;
  g := fwios.decision_refresh_provider_promotion_gate(p_provider_key);
  ok := coalesce((g->>'eligible')::boolean,false);
  if ok then update fwios.decision_refresh_provider_registry set active=true,readiness_status='READY',source_tier='A',updated_at=now() where provider_key=p_provider_key; end if;
  return g || jsonb_build_object('promoted',ok);
end $$;

revoke all on function fwios.apply_decision_refresh_provider_promotion(text) from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname='fwios-provider-validator-v1';
select cron.schedule('fwios-provider-validator-v1','17 * * * *',$cron$
select net.http_post(
  url := (select decrypted_secret from vault.decrypted_secrets where name='fwios_project_url' limit 1) || '/functions/v1/decision-refresh-provider-validator-v1',
  headers := jsonb_build_object('Content-Type','application/json','x-fwios-automation-token',(select decrypted_secret from vault.decrypted_secrets where name='fwios_automation_token' limit 1)),
  body := jsonb_build_object('source','PG_CRON','requested_at',now()),
  timeout_milliseconds := 20000
);
$cron$);

update fwios.system_state
set state_value = state_value || jsonb_build_object('provider_validator','decision-refresh-provider-validator-v1','provider_validator_schedule','17 * * * *','provider_validator_mode','AUTO_WHEN_KEYS_APPEAR','provider_autopromotion','TIER_A_READY_ONLY_AFTER_FRESH_GATE_PASS'),
as_of_text=to_char(now() at time zone 'Asia/Bangkok','YYYY-MM-DD HH24:MI Asia/Bangkok'),updated_at=now()
where state_key='auto_decision_refresh_v1';
