
update fwios.market_daily_closes d
set instrument_id=fwios.resolve_instrument_id_v1(d.asset_symbol,'Stock',null,null)
where d.instrument_id is null
  and fwios.resolve_instrument_id_v1(d.asset_symbol,'Stock',null,null) is not null;

update fwios.portfolio_market_quote_snapshots p
set instrument_id=fwios.resolve_instrument_id_v1(p.asset_symbol,p.asset_class,null,null)
where p.instrument_id is null
  and fwios.resolve_instrument_id_v1(p.asset_symbol,p.asset_class,null,null) is not null;

update fwios.market_price_quotes q
set market_observation_id=fwios.ensure_market_observation_v1(
  q.instrument_id,fwios.market_observation_type_v1(q.price_type,q.market_status),
  q.price,q.currency,q.session_date,coalesce(q.quote_at,q.retrieved_at,q.created_at),
  q.market_status,q.source_provider,q.source_tier,q.source_url,q.provenance_status,
  q.raw_payload || jsonb_build_object('legacy_source_table','fwios.market_price_quotes','legacy_quote_id',q.quote_id)
)
where q.instrument_id is not null;

insert into fwios.market_observation_legacy_links(source_table,source_key,link_role,observation_id)
select 'fwios.market_price_quotes',q.quote_id,'PRICE',q.market_observation_id
from fwios.market_price_quotes q
where q.market_observation_id is not null
on conflict(source_table,source_key,link_role) do update set observation_id=excluded.observation_id;

update fwios.market_daily_closes d
set primary_observation_id=fwios.ensure_market_observation_v1(
  d.instrument_id,'REGULAR_CLOSE',d.close_price,coalesce(d.currency,'USD'),d.session_date,
  ((d.session_date::text||' 16:00 America/New_York')::timestamptz),'CLOSED',
  d.primary_provider,d.source_tier,d.source_url,d.provenance_status,
  d.raw_payload || jsonb_build_object('legacy_source_table','fwios.market_daily_closes','legacy_role','PRIMARY')
)
where d.instrument_id is not null;

update fwios.market_daily_closes d
set secondary_observation_id=fwios.ensure_market_observation_v1(
  d.instrument_id,'REGULAR_CLOSE',d.secondary_close,coalesce(d.currency,'USD'),d.session_date,
  ((d.session_date::text||' 16:00 America/New_York')::timestamptz),'CLOSED',
  d.secondary_provider,d.source_tier,d.source_url,d.provenance_status,
  d.raw_payload || jsonb_build_object('legacy_source_table','fwios.market_daily_closes','legacy_role','SECONDARY')
)
where d.instrument_id is not null and d.secondary_provider is not null and d.secondary_close is not null;

insert into fwios.market_observation_legacy_links(source_table,source_key,link_role,observation_id)
select 'fwios.market_daily_closes',d.asset_symbol||'|'||d.session_date::text,'PRIMARY',d.primary_observation_id
from fwios.market_daily_closes d where d.primary_observation_id is not null
on conflict(source_table,source_key,link_role) do update set observation_id=excluded.observation_id;

insert into fwios.market_observation_legacy_links(source_table,source_key,link_role,observation_id)
select 'fwios.market_daily_closes',d.asset_symbol||'|'||d.session_date::text,'SECONDARY',d.secondary_observation_id
from fwios.market_daily_closes d where d.secondary_observation_id is not null
on conflict(source_table,source_key,link_role) do update set observation_id=excluded.observation_id;

insert into fwios.market_verification_sets(
  verification_id,verification_scope,instrument_id,session_date,primary_observation_id,
  secondary_observation_id,selected_observation_id,selected_value,divergence_pct,
  max_allowed_divergence_pct,conflict_status,verification_status,gate,source_table,source_key,metadata
)
select
  'DCL:'||d.asset_symbol||':'||d.session_date::text,'DAILY_CLOSE',d.instrument_id,d.session_date,
  d.primary_observation_id,d.secondary_observation_id,d.primary_observation_id,d.close_price,d.divergence_pct,0.005,
  case when d.verification_status='CONFLICT' then 'CONFLICT'
       when d.secondary_observation_id is null then 'NO_CROSSCHECK' else 'PASS' end,
  d.verification_status,
  case when d.provenance_status<>'PASS' then 'BLOCKED - PROVENANCE'
       when d.verification_status='CONFLICT' then 'BLOCKED - PRICE CONFLICT'
       else 'PASS' end,
  'fwios.market_daily_closes',d.asset_symbol||'|'||d.session_date::text,
  jsonb_build_object('primary_provider',d.primary_provider,'secondary_provider',d.secondary_provider)
from fwios.market_daily_closes d
where d.primary_observation_id is not null
on conflict(verification_id) do update set
  primary_observation_id=excluded.primary_observation_id,
  secondary_observation_id=excluded.secondary_observation_id,
  selected_observation_id=excluded.selected_observation_id,
  selected_value=excluded.selected_value,
  divergence_pct=excluded.divergence_pct,
  conflict_status=excluded.conflict_status,
  verification_status=excluded.verification_status,
  gate=excluded.gate,
  metadata=excluded.metadata,
  updated_at=now();

update fwios.market_daily_closes d
set market_verification_id='DCL:'||d.asset_symbol||':'||d.session_date::text
where d.primary_observation_id is not null;

update fwios.market_price_snapshots s
set
  primary_observation_id=(select q.market_observation_id from fwios.market_price_quotes q where q.quote_id=s.primary_quote_id),
  crosscheck_observation_id=(select q.market_observation_id from fwios.market_price_quotes q where q.quote_id=s.crosscheck_quote_id),
  selected_observation_id=(
    select case
      when s.selected_price=q1.price then q1.market_observation_id
      when q2.quote_id is not null and s.selected_price=q2.price then q2.market_observation_id
      else null
    end
    from fwios.market_price_quotes q1
    left join fwios.market_price_quotes q2 on q2.quote_id=s.crosscheck_quote_id
    where q1.quote_id=s.primary_quote_id
  );

insert into fwios.market_verification_sets(
  verification_id,verification_scope,instrument_id,session_date,primary_observation_id,
  secondary_observation_id,selected_observation_id,selected_value,divergence_pct,
  max_allowed_divergence_pct,conflict_status,verification_status,gate,source_table,source_key,metadata
)
select
  'DPR:'||s.snapshot_id,'DECISION_PRICE',s.instrument_id,s.session_date,
  s.primary_observation_id,s.crosscheck_observation_id,s.selected_observation_id,
  s.selected_price,s.divergence_pct,s.max_allowed_divergence_pct,s.conflict_status,
  case when s.price_gate='PASS' then 'VERIFIED' else 'BLOCKED' end,s.price_gate,
  'fwios.market_price_snapshots',s.snapshot_id,
  jsonb_build_object('legacy_primary_quote_id',s.primary_quote_id,'legacy_crosscheck_quote_id',s.crosscheck_quote_id)
from fwios.market_price_snapshots s
where s.primary_observation_id is not null
on conflict(verification_id) do update set
  primary_observation_id=excluded.primary_observation_id,
  secondary_observation_id=excluded.secondary_observation_id,
  selected_observation_id=excluded.selected_observation_id,
  selected_value=excluded.selected_value,
  divergence_pct=excluded.divergence_pct,
  max_allowed_divergence_pct=excluded.max_allowed_divergence_pct,
  conflict_status=excluded.conflict_status,
  verification_status=excluded.verification_status,
  gate=excluded.gate,
  metadata=excluded.metadata,
  updated_at=now();

update fwios.market_price_snapshots s
set market_verification_id='DPR:'||s.snapshot_id
where s.primary_observation_id is not null;

update fwios.portfolio_market_quote_snapshots p
set market_observation_id=fwios.ensure_market_observation_v1(
  p.instrument_id,
  case when upper(coalesce(p.market_status,''))='PRE_MARKET' then 'PRE_MARKET'
       when upper(coalesce(p.market_status,''))='AFTER_HOURS' then 'AFTER_HOURS'
       else 'LIVE_QUOTE' end,
  p.price_native,p.native_currency,
  case when p.asset_class='Stock' then (p.observed_at at time zone 'America/New_York')::date else p.observed_at::date end,
  p.observed_at,p.market_status,p.provider,p.source_tier,null,p.provenance_status,
  p.raw_payload || jsonb_build_object('legacy_source_table','fwios.portfolio_market_quote_snapshots','legacy_quote_id',p.quote_id::text)
)
where p.instrument_id is not null;

update fwios.portfolio_market_quote_snapshots p
set fx_observation_id=fwios.ensure_market_observation_v1(
  p.instrument_id,'FX',p.fx_rate_thb,'THB',p.observed_at::date,
  coalesce(
    case when (p.raw_payload->'fx_payload'->>'timestamp') ~ '^[0-9]+$'
      then to_timestamp((p.raw_payload->'fx_payload'->>'timestamp')::double precision) else null end,
    p.observed_at
  ),
  'FX',coalesce(p.raw_payload->>'fx_provider',p.provider||'_FX'),p.source_tier,null,p.provenance_status,
  coalesce(p.raw_payload->'fx_payload','{}'::jsonb) ||
    jsonb_build_object('legacy_source_table','fwios.portfolio_market_quote_snapshots','legacy_quote_id',p.quote_id::text),
  p.native_currency,'THB'
)
where p.instrument_id is not null and p.fx_rate_thb is not null and p.native_currency<>'THB';

insert into fwios.market_observation_legacy_links(source_table,source_key,link_role,observation_id)
select 'fwios.portfolio_market_quote_snapshots',p.quote_id::text,'PRICE',p.market_observation_id
from fwios.portfolio_market_quote_snapshots p where p.market_observation_id is not null
on conflict(source_table,source_key,link_role) do update set observation_id=excluded.observation_id;

insert into fwios.market_observation_legacy_links(source_table,source_key,link_role,observation_id)
select 'fwios.portfolio_market_quote_snapshots',p.quote_id::text,'FX',p.fx_observation_id
from fwios.portfolio_market_quote_snapshots p where p.fx_observation_id is not null
on conflict(source_table,source_key,link_role) do update set observation_id=excluded.observation_id;

create or replace view fwios.v_market_price_quotes_observation_compat
with (security_invoker=true) as
select q.*,o.observation_type,o.observation_value,o.observed_at as canonical_observed_at,o.provider as canonical_provider
from fwios.market_price_quotes q
left join fwios.market_observations o on o.observation_id=q.market_observation_id;

create or replace view fwios.v_market_daily_closes_observation_compat
with (security_invoker=true) as
select d.*,v.gate as canonical_verification_gate,p.observation_value as canonical_primary_close,
       x.observation_value as canonical_secondary_close
from fwios.market_daily_closes d
left join fwios.market_verification_sets v on v.verification_id=d.market_verification_id
left join fwios.market_observations p on p.observation_id=d.primary_observation_id
left join fwios.market_observations x on x.observation_id=d.secondary_observation_id;

create or replace view fwios.v_market_price_snapshots_observation_compat
with (security_invoker=true) as
select s.*,v.verification_scope,v.gate as canonical_verification_gate
from fwios.market_price_snapshots s
left join fwios.market_verification_sets v on v.verification_id=s.market_verification_id;

create or replace view fwios.v_portfolio_market_quotes_observation_compat
with (security_invoker=true) as
select p.*,o.observation_type,o.observation_value,o.observed_at as canonical_observed_at,
       fx.observation_value as canonical_fx_rate_thb
from fwios.portfolio_market_quote_snapshots p
left join fwios.market_observations o on o.observation_id=p.market_observation_id
left join fwios.market_observations fx on fx.observation_id=p.fx_observation_id;

revoke all on fwios.v_market_price_quotes_observation_compat from public,anon,authenticated;
revoke all on fwios.v_market_daily_closes_observation_compat from public,anon,authenticated;
revoke all on fwios.v_market_price_snapshots_observation_compat from public,anon,authenticated;
revoke all on fwios.v_portfolio_market_quotes_observation_compat from public,anon,authenticated;
grant select on fwios.v_market_price_quotes_observation_compat to service_role;
grant select on fwios.v_market_daily_closes_observation_compat to service_role;
grant select on fwios.v_market_price_snapshots_observation_compat to service_role;
grant select on fwios.v_portfolio_market_quotes_observation_compat to service_role;
