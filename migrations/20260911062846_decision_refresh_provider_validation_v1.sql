create table if not exists fwios.decision_refresh_provider_validation_runs (
  validation_id uuid primary key default gen_random_uuid(),
  provider_key text not null references fwios.decision_refresh_provider_registry(provider_key),
  validation_scope text not null,
  ticker text,
  session_date date,
  status text not null,
  checks jsonb not null default '{}'::jsonb,
  observed jsonb not null default '{}'::jsonb,
  source_refs jsonb not null default '[]'::jsonb,
  error_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status in ('PASS','BLOCKED','FAIL','ERROR')),
  check (validation_scope in ('DOCUMENTATION_CONTRACT','LIVE_CONNECTIVITY','RESPONSE_SCHEMA','SESSION_SEMANTICS','ADJUSTMENT_SEMANTICS','RATE_LIMIT','PRICE_CROSSCHECK','CONSENSUS_SCHEMA','CONSENSUS_FRESHNESS'))
);

create index if not exists idx_decision_refresh_provider_validation_lookup
  on fwios.decision_refresh_provider_validation_runs(provider_key, validation_scope, created_at desc);

alter table fwios.decision_refresh_provider_validation_runs enable row level security;
revoke all on fwios.decision_refresh_provider_validation_runs from anon, authenticated;

update fwios.decision_refresh_provider_registry
set config = jsonb_build_object(
      'validation_contract_version','PRICE_PROVIDER_CONTRACT_V1',
      'endpoint','https://api.twelvedata.com/time_series',
      'interval','1day',
      'adjust','none',
      'session_bound','end_date',
      'daily_timezone_semantics','exchange_local',
      'price_field','close',
      'required_meta',jsonb_build_array('symbol','currency','exchange','exchange_timezone'),
      'crosscheck_provider','ALPHA_VANTAGE',
      'max_divergence_pct',0.005,
      'required_crosscheck_sessions',3,
      'docs',jsonb_build_array(
        'https://twelvedata.com/docs',
        'https://support.twelvedata.com/en/articles/5656039-how-to-get-historical-prices'
      )
    ),
    updated_at=now()
where provider_key='TWELVE_DATA';

update fwios.decision_refresh_provider_registry
set config = jsonb_build_object(
      'validation_contract_version','PRICE_CONSENSUS_PROVIDER_CONTRACT_V1',
      'price_endpoint','TIME_SERIES_DAILY',
      'price_semantics','raw_as_traded_daily',
      'price_series_key','Time Series (Daily)',
      'price_field','4. close',
      'consensus_endpoint','EARNINGS_ESTIMATES',
      'crosscheck_provider','TWELVE_DATA',
      'max_divergence_pct',0.005,
      'required_crosscheck_sessions',3,
      'docs',jsonb_build_array('https://www.alphavantage.co/documentation/')
    ),
    updated_at=now()
where provider_key='ALPHA_VANTAGE';

insert into fwios.decision_refresh_provider_validation_runs
(provider_key,validation_scope,status,checks,observed,source_refs)
values
('TWELVE_DATA','DOCUMENTATION_CONTRACT','PASS',
 jsonb_build_object(
   'daily_interval','1day',
   'daily_timezone','exchange_local',
   'explicit_adjustment','none',
   'session_bound','end_date',
   'crosscheck_required',true,
   'max_divergence_pct',0.005
 ),
 jsonb_build_object('note','Contract pinned from current Twelve Data documentation; live API validation still required.'),
 jsonb_build_array('https://twelvedata.com/docs','https://support.twelvedata.com/en/articles/5656039-how-to-get-historical-prices')),
('ALPHA_VANTAGE','DOCUMENTATION_CONTRACT','PASS',
 jsonb_build_object(
   'price_endpoint','TIME_SERIES_DAILY',
   'price_semantics','raw_as_traded_daily',
   'consensus_endpoint','EARNINGS_ESTIMATES',
   'crosscheck_required',true,
   'max_divergence_pct',0.005
 ),
 jsonb_build_object('note','Contract pinned from current Alpha Vantage documentation; live API validation still required.'),
 jsonb_build_array('https://www.alphavantage.co/documentation/'));

create or replace function fwios.decision_refresh_provider_promotion_gate(p_provider_key text)
returns jsonb
language plpgsql
set search_path=''
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
begin
  select * into p from fwios.decision_refresh_provider_registry where provider_key=p_provider_key;
  if p is null then
    return jsonb_build_object('provider_key',p_provider_key,'eligible',false,'reason','PROVIDER_NOT_FOUND');
  end if;

  if p.requires_secret and p.secret_name is not null then
    select exists(select 1 from vault.secrets where name=p.secret_name) into v_has_secret;
  else
    v_has_secret := true;
  end if;

  select exists(select 1 from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='DOCUMENTATION_CONTRACT' and status='PASS') into v_doc;
  select exists(select 1 from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='LIVE_CONNECTIVITY' and status='PASS') into v_connect;
  select exists(select 1 from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='RESPONSE_SCHEMA' and status='PASS') into v_schema;
  select exists(select 1 from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='SESSION_SEMANTICS' and status='PASS') into v_session;
  select exists(select 1 from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='ADJUSTMENT_SEMANTICS' and status='PASS') into v_adjust;
  select exists(select 1 from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='RATE_LIMIT' and status='PASS') into v_rate;

  select coalesce((p.config->>'required_crosscheck_sessions')::integer,3) into v_required_sessions;
  select count(distinct session_date) into v_crosscheck_sessions
  from fwios.decision_refresh_provider_validation_runs
  where provider_key=p_provider_key and validation_scope='PRICE_CROSSCHECK' and status='PASS' and session_date is not null;

  if p_provider_key='ALPHA_VANTAGE' then
    select exists(select 1 from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='CONSENSUS_SCHEMA' and status='PASS') into v_consensus_schema;
    select exists(select 1 from fwios.decision_refresh_provider_validation_runs where provider_key=p_provider_key and validation_scope='CONSENSUS_FRESHNESS' and status='PASS') into v_consensus_fresh;
  end if;

  v_eligible := v_has_secret and v_doc and v_connect and v_schema and v_session and v_adjust and v_rate
                and v_crosscheck_sessions >= v_required_sessions and v_consensus_schema and v_consensus_fresh;

  return jsonb_build_object(
    'provider_key',p_provider_key,
    'eligible',v_eligible,
    'current_state',jsonb_build_object('active',p.active,'readiness_status',p.readiness_status,'source_tier',p.source_tier),
    'checks',jsonb_build_object(
      'secret_present',v_has_secret,
      'documentation_contract',v_doc,
      'live_connectivity',v_connect,
      'response_schema',v_schema,
      'session_semantics',v_session,
      'adjustment_semantics',v_adjust,
      'rate_limit',v_rate,
      'price_crosscheck_sessions',v_crosscheck_sessions,
      'required_crosscheck_sessions',v_required_sessions,
      'consensus_schema',v_consensus_schema,
      'consensus_freshness',v_consensus_fresh
    ),
    'promotion_target',case when v_eligible then jsonb_build_object('active',true,'readiness_status','READY','source_tier','A') else null end
  );
end $$;

revoke all on function fwios.decision_refresh_provider_promotion_gate(text) from public, anon, authenticated;
