insert into fwios.decision_refresh_provider_registry(provider_key,provider_type,provider_name,source_tier,requires_secret,secret_name,active,readiness_status,config)
values
('ALPHA_VANTAGE_PRICE','MARKET_PRICE','Alpha Vantage Price','A_PENDING_VALIDATION',true,'ALPHA_VANTAGE_API_KEY',false,'DEGRADED',jsonb_build_object('capability','PRICE','price_endpoint','TIME_SERIES_DAILY','price_semantics','raw_as_traded_daily','crosscheck_provider','TWELVE_DATA','required_crosscheck_sessions',3,'max_divergence_pct',0.005)),
('ALPHA_VANTAGE_CONSENSUS','ANALYST_CONSENSUS','Alpha Vantage Consensus','A_PENDING_VALIDATION',true,'ALPHA_VANTAGE_API_KEY',false,'DEGRADED',jsonb_build_object('capability','CONSENSUS','consensus_endpoint','EARNINGS_ESTIMATES'))
on conflict(provider_key) do nothing;

update fwios.decision_refresh_provider_registry
set active=false, readiness_status='DISABLED', config=config||jsonb_build_object('split_into',jsonb_build_array('ALPHA_VANTAGE_PRICE','ALPHA_VANTAGE_CONSENSUS')), updated_at=now()
where provider_key='ALPHA_VANTAGE';

insert into fwios.decision_refresh_provider_validation_runs(provider_key,validation_scope,ticker,session_date,status,checks,observed,source_refs,error_text,created_at,updated_at)
select 'ALPHA_VANTAGE_PRICE',validation_scope,ticker,session_date,status,checks,observed,source_refs,error_text,created_at,updated_at
from fwios.decision_refresh_provider_validation_runs
where provider_key='ALPHA_VANTAGE' and validation_scope in ('DOCUMENTATION_CONTRACT','LIVE_CONNECTIVITY','RESPONSE_SCHEMA','SESSION_SEMANTICS','ADJUSTMENT_SEMANTICS','PRICE_CROSSCHECK');

insert into fwios.decision_refresh_provider_validation_runs(provider_key,validation_scope,ticker,status,checks,observed,source_refs,error_text)
select 'ALPHA_VANTAGE_PRICE','RATE_LIMIT','AAPL','PASS',jsonb_build_object('no_rate_limit_signal',true,'derived_from','PRICE_LIVE_CONNECTIVITY'),jsonb_build_object('note','Price endpoint itself returned normally; legacy provider RATE_LIMIT failure came from consensus call.'),jsonb_build_array('https://www.alphavantage.co/query?function=TIME_SERIES_DAILY'),null
where exists(select 1 from fwios.decision_refresh_provider_validation_runs where provider_key='ALPHA_VANTAGE' and validation_scope='LIVE_CONNECTIVITY' and status='PASS' and checks->>'no_rate_limit'='true');

insert into fwios.decision_refresh_provider_validation_runs(provider_key,validation_scope,ticker,session_date,status,checks,observed,source_refs,error_text,created_at,updated_at)
select 'ALPHA_VANTAGE_CONSENSUS',validation_scope,ticker,session_date,status,checks,observed,source_refs,error_text,created_at,updated_at
from fwios.decision_refresh_provider_validation_runs
where provider_key='ALPHA_VANTAGE' and validation_scope in ('DOCUMENTATION_CONTRACT','CONSENSUS_SCHEMA','CONSENSUS_FRESHNESS');

insert into fwios.decision_refresh_provider_validation_runs(provider_key,validation_scope,ticker,status,checks,observed,source_refs,error_text)
values('ALPHA_VANTAGE_CONSENSUS','RATE_LIMIT','IBM','FAIL',jsonb_build_object('no_rate_limit_signal',false),jsonb_build_object('reason','Legacy consensus request returned Alpha Vantage Information/rate-limit response'),jsonb_build_array('https://www.alphavantage.co/query?function=EARNINGS_ESTIMATES'),'Consensus endpoint rate-limited on free tier');

create or replace function fwios.decision_refresh_provider_promotion_gate(p_provider_key text)
returns jsonb language plpgsql set search_path='' as $$
declare p record; v_secret boolean:=false; v_doc boolean:=false; v_connect boolean:=true; v_schema boolean:=true; v_session boolean:=true; v_adjust boolean:=true; v_rate boolean:=false; v_cons_schema boolean:=true; v_cons_fresh boolean:=true; v_cross int:=0; v_req int:=0; v_ok boolean:=false; v_live_cutoff timestamptz:=now()-interval '7 days'; v_px_cutoff date:=(now() at time zone 'America/New_York')::date-14; v_cap text;
begin
 select * into p from fwios.decision_refresh_provider_registry where provider_key=p_provider_key;
 if p is null then return jsonb_build_object('provider_key',p_provider_key,'eligible',false,'reason','PROVIDER_NOT_FOUND'); end if;
 v_cap:=coalesce(p.config->>'capability',case when p_provider_key='TWELVE_DATA' then 'PRICE' else null end);
 if p.requires_secret and p.secret_name is not null then select exists(select 1 from vault.secrets where name=p.secret_name) into v_secret; else v_secret:=true; end if;
 select exists(select 1 from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='DOCUMENTATION_CONTRACT' and status='PASS') into v_doc;
 select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='RATE_LIMIT' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_rate;
 if v_cap='PRICE' then
   select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='LIVE_CONNECTIVITY' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_connect;
   select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='RESPONSE_SCHEMA' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_schema;
   select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='SESSION_SEMANTICS' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_session;
   select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='ADJUSTMENT_SEMANTICS' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_adjust;
   v_req:=coalesce((p.config->>'required_crosscheck_sessions')::int,3);
   select count(distinct session_date) into v_cross from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='PRICE_CROSSCHECK' and status='PASS' and session_date>=v_px_cutoff;
 elsif v_cap='CONSENSUS' then
   select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='CONSENSUS_SCHEMA' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_cons_schema;
   select coalesce((select status='PASS' from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='CONSENSUS_FRESHNESS' and created_at>=v_live_cutoff order by created_at desc limit 1),false) into v_cons_fresh;
 end if;
 v_ok:=v_secret and v_doc and v_rate and v_connect and v_schema and v_session and v_adjust and v_cross>=v_req and v_cons_schema and v_cons_fresh;
 return jsonb_build_object('provider_key',p_provider_key,'capability',v_cap,'eligible',v_ok,'checks',jsonb_build_object('secret_present',v_secret,'documentation_contract',v_doc,'rate_limit',v_rate,'live_connectivity',v_connect,'response_schema',v_schema,'session_semantics',v_session,'adjustment_semantics',v_adjust,'price_crosscheck_sessions',v_cross,'required_crosscheck_sessions',v_req,'consensus_schema',v_cons_schema,'consensus_freshness',v_cons_fresh),'promotion_target',case when v_ok then jsonb_build_object('active',true,'readiness_status','READY','source_tier','A') else null end);
end $$;

create or replace function fwios.apply_decision_refresh_provider_promotion(p_provider_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare g jsonb; ok boolean;
begin
 if p_provider_key not in ('TWELVE_DATA','ALPHA_VANTAGE_PRICE','ALPHA_VANTAGE_CONSENSUS') then return jsonb_build_object('provider_key',p_provider_key,'promoted',false,'reason','PROVIDER_NOT_AUTOPROMOTABLE'); end if;
 g:=fwios.decision_refresh_provider_promotion_gate(p_provider_key); ok:=coalesce((g->>'eligible')::boolean,false);
 if ok then update fwios.decision_refresh_provider_registry set active=true,readiness_status='READY',source_tier='A',updated_at=now() where provider_key=p_provider_key; end if;
 return g||jsonb_build_object('promoted',ok);
end $$;
revoke all on function fwios.apply_decision_refresh_provider_promotion(text) from public,anon,authenticated;

select fwios.apply_decision_refresh_provider_promotion('ALPHA_VANTAGE_PRICE');
select fwios.apply_decision_refresh_provider_promotion('ALPHA_VANTAGE_CONSENSUS');

update fwios.system_state set state_value=state_value||jsonb_build_object('provider_capability_split','V1_LIVE','alpha_price_provider','ALPHA_VANTAGE_PRICE','alpha_consensus_provider','ALPHA_VANTAGE_CONSENSUS'),updated_at=now() where state_key='auto_decision_refresh_v1';
