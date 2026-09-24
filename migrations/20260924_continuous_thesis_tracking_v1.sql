-- Continuous Thesis Tracking v1
-- Portfolio holdings are Priority 0. Thesis health is fundamental-only; valuation/price is separate entry status.
-- BROKEN requires an explicit THESIS_INVALIDATION event; no auto-trading behavior is introduced.

create table if not exists fwios.thesis_registry (
  ticker text primary key,
  company_name text,
  sector text,
  archetype text,
  tracking_priority integer not null default 2 check (tracking_priority between 0 and 9),
  ownership_status text not null default 'WATCHLIST'
    check (ownership_status in ('PORTFOLIO','RESEARCH_CANDIDATE','WATCHLIST')),
  baseline_status text not null default 'BASELINE_REQUIRED'
    check (baseline_status in ('BASELINE_REQUIRED','MIGRATED_RESEARCH','COMPLETE')),
  baseline_completeness numeric not null default 0 check (baseline_completeness between 0 and 1),
  thesis_statement text,
  must_remain_true jsonb not null default '[]'::jsonb,
  monitoring_kpis jsonb not null default '[]'::jsonb,
  catalysts jsonb not null default '[]'::jsonb,
  invalidation_criteria jsonb not null default '[]'::jsonb,
  manual_health_override text
    check (manual_health_override is null or manual_health_override in ('STRONG','STABLE','WATCH','WEAKENING','BROKEN')),
  source_reference text,
  metadata jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists fwios.thesis_events (
  event_id uuid primary key default gen_random_uuid(),
  event_key text unique,
  ticker text not null references fwios.thesis_registry(ticker) on delete cascade,
  event_date date not null,
  event_type text not null,
  direction text not null check (direction in ('SUPPORTS','NEUTRAL','CONTRADICTS','SYSTEM')),
  impact_score numeric not null default 0 check (impact_score between -100 and 100),
  thesis_dimension text,
  summary text not null,
  evidence_source text,
  source_reference text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists thesis_events_ticker_date_idx
  on fwios.thesis_events(ticker,event_date desc,created_at desc);

create table if not exists fwios.thesis_health_snapshots (
  snapshot_id uuid primary key default gen_random_uuid(),
  ticker text not null references fwios.thesis_registry(ticker) on delete cascade,
  as_of_date date not null,
  health_status text not null
    check (health_status in ('BASELINE_REQUIRED','STRONG','STABLE','WATCH','WEAKENING','BROKEN')),
  health_score numeric,
  thesis_score numeric,
  risk_gate text,
  revision_score numeric,
  revision_gate text,
  chase_risk numeric,
  chase_gate text,
  hardening_gate text,
  valuation_confidence numeric,
  valuation_gate text,
  mispricing_gate text,
  promotion_gate text,
  final_decision text,
  blocker_count integer not null default 0,
  entry_status text,
  health_reason text,
  source_reference text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(ticker,as_of_date)
);

create index if not exists thesis_health_snapshots_date_idx
  on fwios.thesis_health_snapshots(as_of_date desc,ticker);

alter table fwios.thesis_registry enable row level security;
alter table fwios.thesis_events enable row level security;
alter table fwios.thesis_health_snapshots enable row level security;

revoke all on fwios.thesis_registry from public,anon,authenticated;
revoke all on fwios.thesis_events from public,anon,authenticated;
revoke all on fwios.thesis_health_snapshots from public,anon,authenticated;
grant select,insert,update,delete on fwios.thesis_registry to service_role;
grant select,insert,update,delete on fwios.thesis_events to service_role;
grant select,insert,update,delete on fwios.thesis_health_snapshots to service_role;

create or replace function fwios.sync_thesis_registry_v1()
returns jsonb
language plpgsql
set search_path to ''
as $function$
declare
  v_total int;
  v_p0 int;
  v_p1 int;
  v_p2 int;
begin
  with universe as (
    select
      h.asset_symbol ticker,
      coalesce(rc.company_name,c.company_name,h.asset_symbol) company_name,
      coalesce(rc.sector,c.sector) sector,
      coalesce(rc.archetype,c.archetype) archetype,
      0 priority,
      'PORTFOLIO' ownership_status,
      case when rc.ticker is not null then 'MIGRATED_RESEARCH' else 'BASELINE_REQUIRED' end baseline_status,
      case when rc.ticker is not null then 0.50::numeric else 0::numeric end baseline_completeness,
      case when rc.ticker is not null then 'research_candidates:'||rc.ticker else 'portfolio_holdings:'||h.asset_symbol end source_reference
    from fwios.v_dashboard_holdings h
    left join fwios.research_candidates rc on rc.ticker=h.asset_symbol
    left join fwios.companies c on c.ticker=h.asset_symbol
    where h.account_view_key='ALL' and h.asset_class='Stock'

    union all

    select
      rc.ticker,rc.company_name,rc.sector,rc.archetype,
      1,'RESEARCH_CANDIDATE','MIGRATED_RESEARCH',0.50::numeric,
      'research_candidates:'||rc.ticker
    from fwios.research_candidates rc

    union all

    select
      c.ticker,c.company_name,c.sector,c.archetype,
      2,'WATCHLIST','BASELINE_REQUIRED',0::numeric,
      'companies:'||c.ticker
    from fwios.companies c
    where c.active=true
  ),
  dedup as (
    select distinct on (ticker)
      ticker,company_name,sector,archetype,priority,ownership_status,
      baseline_status,baseline_completeness,source_reference
    from universe
    where ticker is not null and ticker<>''
    order by ticker,priority
  )
  insert into fwios.thesis_registry(
    ticker,company_name,sector,archetype,tracking_priority,ownership_status,
    baseline_status,baseline_completeness,source_reference,metadata,active,updated_at
  )
  select
    d.ticker,d.company_name,d.sector,d.archetype,d.priority,d.ownership_status,
    d.baseline_status,d.baseline_completeness,d.source_reference,
    jsonb_build_object(
      'contract','THESIS_TRACKING_V1',
      'baseline_generated',false,
      'explicit_invalidation_required_for_broken',true
    ),
    true,now()
  from dedup d
  on conflict(ticker) do update set
    company_name=coalesce(excluded.company_name,fwios.thesis_registry.company_name),
    sector=coalesce(excluded.sector,fwios.thesis_registry.sector),
    archetype=coalesce(excluded.archetype,fwios.thesis_registry.archetype),
    tracking_priority=excluded.tracking_priority,
    ownership_status=excluded.ownership_status,
    baseline_status=case
      when fwios.thesis_registry.baseline_status='COMPLETE' then 'COMPLETE'
      when excluded.baseline_status='MIGRATED_RESEARCH' then 'MIGRATED_RESEARCH'
      else fwios.thesis_registry.baseline_status
    end,
    baseline_completeness=greatest(fwios.thesis_registry.baseline_completeness,excluded.baseline_completeness),
    source_reference=coalesce(fwios.thesis_registry.source_reference,excluded.source_reference),
    active=true,
    updated_at=now();

  insert into fwios.thesis_events(
    event_key,ticker,event_date,event_type,direction,impact_score,thesis_dimension,
    summary,evidence_source,source_reference,payload
  )
  select
    'BASELINE|'||tr.ticker,
    tr.ticker,
    current_date,
    case when tr.baseline_status='BASELINE_REQUIRED' then 'BASELINE_REQUIRED' else 'BASELINE_MIGRATION' end,
    'SYSTEM',
    0,
    'BASELINE',
    case
      when tr.baseline_status='BASELINE_REQUIRED'
        then 'Thesis tracker created; explicit baseline thesis, KPIs, catalysts and invalidation criteria are still required.'
      else 'Existing research candidate migrated into continuous thesis tracking without inventing missing thesis criteria.'
    end,
    'FWIOS',
    tr.source_reference,
    jsonb_build_object(
      'baseline_status',tr.baseline_status,
      'tracking_priority',tr.tracking_priority,
      'ownership_status',tr.ownership_status
    )
  from fwios.thesis_registry tr
  on conflict(event_key) do nothing;

  select count(*),
         count(*) filter(where tracking_priority=0),
         count(*) filter(where tracking_priority=1),
         count(*) filter(where tracking_priority=2)
  into v_total,v_p0,v_p1,v_p2
  from fwios.thesis_registry
  where active=true;

  return jsonb_build_object(
    'total_active',v_total,
    'priority_0_portfolio',v_p0,
    'priority_1_candidates',v_p1,
    'priority_2_watchlist',v_p2,
    'auto_generated_thesis_statements',false
  );
end
$function$;

revoke all on function fwios.sync_thesis_registry_v1() from public,anon,authenticated;
grant execute on function fwios.sync_thesis_registry_v1() to service_role;

create or replace function fwios.record_thesis_event_v1(
  p_ticker text,
  p_event_date date,
  p_event_type text,
  p_direction text,
  p_impact_score numeric,
  p_summary text,
  p_thesis_dimension text default null,
  p_evidence_source text default null,
  p_source_reference text default null,
  p_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
set search_path to ''
as $function$
declare
  v_event_id uuid;
begin
  if not exists(select 1 from fwios.thesis_registry where ticker=p_ticker and active=true) then
    raise exception 'THESIS_TICKER_NOT_REGISTERED: %',p_ticker;
  end if;
  if p_direction not in ('SUPPORTS','NEUTRAL','CONTRADICTS','SYSTEM') then
    raise exception 'INVALID_THESIS_DIRECTION';
  end if;
  if p_impact_score < -100 or p_impact_score > 100 then
    raise exception 'INVALID_IMPACT_SCORE';
  end if;

  insert into fwios.thesis_events(
    ticker,event_date,event_type,direction,impact_score,thesis_dimension,summary,
    evidence_source,source_reference,payload
  )
  values(
    p_ticker,p_event_date,p_event_type,p_direction,p_impact_score,p_thesis_dimension,p_summary,
    p_evidence_source,p_source_reference,coalesce(p_payload,'{}'::jsonb)
  )
  returning event_id into v_event_id;

  return v_event_id;
end
$function$;

revoke all on function fwios.record_thesis_event_v1(text,date,text,text,numeric,text,text,text,text,jsonb)
  from public,anon,authenticated;
grant execute on function fwios.record_thesis_event_v1(text,date,text,text,numeric,text,text,text,text,jsonb)
  to service_role;

create or replace function fwios.refresh_thesis_health_v1(
  p_as_of_date date default current_date,
  p_source text default 'SYSTEM'
)
returns jsonb
language plpgsql
set search_path to ''
as $function$
declare
  v_rows int := 0;
  v_changes int := 0;
begin
  perform fwios.sync_thesis_registry_v1();

  with blockers as (
    select ticker,count(*) filter(where current_status='BLOCKED')::int blocker_count
    from fwios.blockers
    group by ticker
  ),
  signals as (
    select
      tr.ticker,tr.baseline_status,tr.manual_health_override,
      rc.business_thesis_score,rc.risk_gate,rc.valuation_gate,rc.mispricing_gate,
      rc.promotion_gate,rc.final_decision,
      rev.revision_score,rev.revision_gate,
      ch.chase_risk,ch.chase_gate,
      q.overall_gate hardening_gate,q.valuation_confidence,
      coalesce(bl.blocker_count,0) blocker_count,
      vm.price_zone,vm.fair_value_upside,vm.system_signal,
      exists(
        select 1 from fwios.thesis_events e
        where e.ticker=tr.ticker
          and e.event_type='THESIS_INVALIDATION'
          and e.direction='CONTRADICTS'
          and e.impact_score<=-80
          and e.event_date<=p_as_of_date
      ) explicit_invalidation
    from fwios.thesis_registry tr
    left join fwios.research_candidates rc on rc.ticker=tr.ticker
    left join fwios.v_candidate_revision_current rev on rev.ticker=tr.ticker
    left join fwios.v_candidate_chase_current ch on ch.ticker=tr.ticker
    left join fwios.v_candidate_quality_hardening_current q on q.ticker=tr.ticker
    left join blockers bl on bl.ticker=tr.ticker
    left join fwios.v_dashboard_valuation_map vm on vm.ticker=tr.ticker
    where tr.active=true
  ),
  calc as (
    select s.*,
      case
        when s.manual_health_override is not null then s.manual_health_override
        when s.explicit_invalidation then 'BROKEN'
        when s.baseline_status='BASELINE_REQUIRED' then 'BASELINE_REQUIRED'
        when coalesce(s.revision_gate,'') like 'FAIL%' then 'WEAKENING'
        when s.hardening_gate='FAIL' then 'WEAKENING'
        when s.risk_gate='WATCH'
          or s.hardening_gate='REVIEW'
          or coalesce(s.revision_gate,'') like 'BLOCKED%'
          or coalesce(s.chase_gate,'') like 'BLOCKED%' then 'WATCH'
        when s.revision_gate='PASS' and s.hardening_gate='PASS' and s.risk_gate='PASS' then 'STRONG'
        else 'STABLE'
      end health_status,
      case
        when s.baseline_status='BASELINE_REQUIRED' or s.business_thesis_score is null then null
        else greatest(0,least(100,
          s.business_thesis_score
          + case when s.revision_gate='PASS' then 5
                 when coalesce(s.revision_gate,'') like 'FAIL%' then -20
                 when coalesce(s.revision_gate,'') like 'BLOCKED%' then -5
                 else 0 end
          + case when s.hardening_gate='PASS' then 5
                 when s.hardening_gate='REVIEW' then -10
                 when s.hardening_gate='FAIL' then -25
                 else 0 end
          + case when s.risk_gate='WATCH' then -5 else 0 end
          + case when s.explicit_invalidation then -50 else 0 end
        ))
      end health_score,
      case
        when s.price_zone is null then 'NO VALUATION MAP'
        when s.system_signal='BUY REVIEW' then 'BUY REVIEW'
        when s.system_signal='VALUE WATCH' then 'VALUE WATCH'
        when s.system_signal='PRICE VERIFY' then 'PRICE VERIFY'
        else coalesce(s.price_zone,'NO ENTRY SIGNAL')
      end entry_status
    from signals s
  ),
  prev as (
    select distinct on (ticker)
      ticker,health_status prev_health,health_score prev_score
    from fwios.thesis_health_snapshots
    where as_of_date < p_as_of_date
    order by ticker,as_of_date desc,created_at desc
  ),
  upserted as (
    insert into fwios.thesis_health_snapshots(
      ticker,as_of_date,health_status,health_score,thesis_score,risk_gate,
      revision_score,revision_gate,chase_risk,chase_gate,hardening_gate,
      valuation_confidence,valuation_gate,mispricing_gate,promotion_gate,
      final_decision,blocker_count,entry_status,health_reason,source_reference,payload,updated_at
    )
    select
      c.ticker,p_as_of_date,c.health_status,c.health_score,c.business_thesis_score,c.risk_gate,
      c.revision_score,c.revision_gate,c.chase_risk,c.chase_gate,c.hardening_gate,
      c.valuation_confidence,c.valuation_gate,c.mispricing_gate,c.promotion_gate,
      c.final_decision,c.blocker_count,c.entry_status,
      case
        when c.health_status='BROKEN' then 'Explicit thesis invalidation event recorded.'
        when c.health_status='BASELINE_REQUIRED' then 'No explicit thesis baseline exists yet.'
        when c.health_status='WEAKENING' and coalesce(c.revision_gate,'') like 'FAIL%' then 'Negative fundamental revision is weakening the thesis.'
        when c.health_status='WEAKENING' and c.hardening_gate='FAIL' then 'Quality/durability hardening failed.'
        when c.health_status='WATCH' then 'Thesis is intact but one or more monitoring gates require review or remain incomplete.'
        when c.health_status='STRONG' then 'Revision and quality hardening both pass with a clean risk gate.'
        else 'No explicit invalidation or negative fundamental gate is active.'
      end,
      p_source,
      jsonb_build_object(
        'price_zone',c.price_zone,
        'fair_value_upside',c.fair_value_upside,
        'system_signal',c.system_signal,
        'health_price_separation',true
      ),
      now()
    from calc c
    on conflict(ticker,as_of_date) do update set
      health_status=excluded.health_status,
      health_score=excluded.health_score,
      thesis_score=excluded.thesis_score,
      risk_gate=excluded.risk_gate,
      revision_score=excluded.revision_score,
      revision_gate=excluded.revision_gate,
      chase_risk=excluded.chase_risk,
      chase_gate=excluded.chase_gate,
      hardening_gate=excluded.hardening_gate,
      valuation_confidence=excluded.valuation_confidence,
      valuation_gate=excluded.valuation_gate,
      mispricing_gate=excluded.mispricing_gate,
      promotion_gate=excluded.promotion_gate,
      final_decision=excluded.final_decision,
      blocker_count=excluded.blocker_count,
      entry_status=excluded.entry_status,
      health_reason=excluded.health_reason,
      source_reference=excluded.source_reference,
      payload=excluded.payload,
      updated_at=now()
    returning ticker,health_status,health_score
  ),
  changes as (
    select u.ticker,p.prev_health,u.health_status,p.prev_score,u.health_score
    from upserted u
    join prev p on p.ticker=u.ticker
    where p.prev_health is distinct from u.health_status
  ),
  events as (
    insert into fwios.thesis_events(
      event_key,ticker,event_date,event_type,direction,impact_score,thesis_dimension,
      summary,evidence_source,source_reference,payload
    )
    select
      'HEALTH|'||c.ticker||'|'||p_as_of_date::text||'|'||coalesce(c.prev_health,'NONE')||'>'||c.health_status,
      c.ticker,p_as_of_date,'HEALTH_CHANGE',
      case
        when (case c.health_status when 'STRONG' then 4 when 'STABLE' then 3 when 'WATCH' then 2 when 'WEAKENING' then 1 when 'BROKEN' then 0 else 2 end)
           > (case c.prev_health when 'STRONG' then 4 when 'STABLE' then 3 when 'WATCH' then 2 when 'WEAKENING' then 1 when 'BROKEN' then 0 else 2 end)
          then 'SUPPORTS'
        when (case c.health_status when 'STRONG' then 4 when 'STABLE' then 3 when 'WATCH' then 2 when 'WEAKENING' then 1 when 'BROKEN' then 0 else 2 end)
           < (case c.prev_health when 'STRONG' then 4 when 'STABLE' then 3 when 'WATCH' then 2 when 'WEAKENING' then 1 when 'BROKEN' then 0 else 2 end)
          then 'CONTRADICTS'
        else 'SYSTEM'
      end,
      coalesce(c.health_score,0)-coalesce(c.prev_score,0),
      'OVERALL',
      'Thesis health changed from '||c.prev_health||' to '||c.health_status||'.',
      'FWIOS',
      p_source,
      jsonb_build_object(
        'previous_health',c.prev_health,
        'new_health',c.health_status,
        'previous_score',c.prev_score,
        'new_score',c.health_score
      )
    from changes c
    on conflict(event_key) do nothing
    returning event_id
  )
  select (select count(*) from upserted),(select count(*) from events)
  into v_rows,v_changes;

  return jsonb_build_object(
    'as_of_date',p_as_of_date,
    'snapshots_refreshed',v_rows,
    'health_change_events',v_changes,
    'price_affects_thesis_health',false,
    'broken_requires_explicit_invalidation',true
  );
end
$function$;

revoke all on function fwios.refresh_thesis_health_v1(date,text) from public,anon,authenticated;
grant execute on function fwios.refresh_thesis_health_v1(date,text) to service_role;

create or replace view fwios.v_thesis_tracking_current
with (security_invoker = true)
as
with latest_health as (
  select distinct on (ticker) *
  from fwios.thesis_health_snapshots
  order by ticker,as_of_date desc,created_at desc
),
latest_event as (
  select distinct on (ticker)
    ticker,event_date,event_type,direction,impact_score,summary
  from fwios.thesis_events
  order by ticker,event_date desc,created_at desc
)
select
  tr.tracking_priority,tr.ownership_status,tr.ticker,tr.company_name,tr.sector,tr.archetype,
  tr.baseline_status,tr.baseline_completeness,tr.thesis_statement,
  lh.health_status,lh.health_score,lh.thesis_score,lh.risk_gate,lh.revision_score,lh.revision_gate,
  lh.chase_risk,lh.chase_gate,lh.hardening_gate,lh.valuation_confidence,lh.entry_status,
  vm.current_price,vm.price_session_date,vm.fair_value,vm.fair_value_upside,vm.price_zone,vm.system_signal,
  lh.promotion_gate,lh.final_decision,lh.blocker_count,
  le.event_date last_event_date,le.event_type last_event_type,le.direction last_event_direction,
  le.summary last_event_summary,
  case
    when lh.health_status='BROKEN' then 'REVIEW INVALIDATION / EXIT THESIS'
    when lh.health_status='WEAKENING' then 'REVIEW FUNDAMENTALS'
    when tr.baseline_status='BASELINE_REQUIRED' then 'BUILD BASELINE'
    when tr.baseline_completeness < 1 then 'COMPLETE THESIS BASELINE'
    when coalesce(lh.revision_gate,'') like 'BLOCKED%' then 'COMPLETE REVISION EVIDENCE'
    when coalesce(lh.chase_gate,'') like 'BLOCKED%' then 'COMPLETE CHASE EVIDENCE'
    when lh.hardening_gate in ('FAIL','REVIEW') then 'REVIEW QUALITY HARDENING'
    when vm.system_signal='PRICE VERIFY' then 'VERIFY PRICE'
    when vm.system_signal='BUY REVIEW' then 'HUMAN BUY REVIEW'
    else 'MONITOR'
  end next_action,
  lh.as_of_date health_as_of
from fwios.thesis_registry tr
left join latest_health lh on lh.ticker=tr.ticker
left join latest_event le on le.ticker=tr.ticker
left join fwios.v_dashboard_valuation_map vm on vm.ticker=tr.ticker
where tr.active=true
order by tr.tracking_priority,
  case coalesce(lh.health_status,'BASELINE_REQUIRED')
    when 'BROKEN' then 0
    when 'WEAKENING' then 1
    when 'WATCH' then 2
    when 'BASELINE_REQUIRED' then 3
    when 'STABLE' then 4
    when 'STRONG' then 5
    else 6
  end,
  tr.ticker;

revoke all on fwios.v_thesis_tracking_current from public,anon,authenticated;
grant select on fwios.v_thesis_tracking_current to service_role;

create or replace function fwios.dashboard_refresh_payload_v1()
returns jsonb
language sql
stable
set search_path to 'pg_catalog','fwios'
as $function$
with
account_summary as (
  select coalesce(jsonb_agg(to_jsonb(a) order by case when a.account_view_key='ALL' then 0 else 1 end,a.account_view_name),'[]'::jsonb) v
  from fwios.v_dashboard_account_summary a
),
holdings as (
  select coalesce(jsonb_agg(to_jsonb(h) order by case when h.account_view_key='ALL' then 0 else 1 end,h.account_view_key,h.value_thb desc,h.asset_symbol),'[]'::jsonb) v
  from fwios.v_dashboard_holdings h
),
opportunities as (
  select coalesce(jsonb_agg(to_jsonb(o) order by case o.opportunity_bucket when 'IMMEDIATE_BUY_CANDIDATE' then 0 when 'WATCHLIST_VALUE_WAIT' then 1 else 2 end,o.bucket_rank,o.ticker),'[]'::jsonb) v
  from fwios.v_dashboard_opportunities o
),
valuation_map as (
  select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) v
  from fwios.v_dashboard_valuation_map v
),
thesis_tracking as (
  select coalesce(jsonb_agg(to_jsonb(t) order by t.tracking_priority,
    case t.health_status when 'BROKEN' then 0 when 'WEAKENING' then 1 when 'WATCH' then 2
      when 'BASELINE_REQUIRED' then 3 when 'STABLE' then 4 when 'STRONG' then 5 else 6 end,
    t.ticker),'[]'::jsonb) v
  from fwios.v_thesis_tracking_current t
),
current_action as (
  select coalesce(jsonb_agg(to_jsonb(c)),'[]'::jsonb) v
  from fwios.v_dashboard_current_action c
),
alerts as (
  select coalesce(jsonb_agg(to_jsonb(a) order by a.alert_order),'[]'::jsonb) v
  from fwios.v_dashboard_alerts a
),
system_health as (
  select coalesce(jsonb_agg(to_jsonb(s)-'read_model_checked_at'),'[]'::jsonb) v,
         max(s.portfolio_batch_status) portfolio_batch_status,
         max(s.source_transaction_count) source_transaction_count,
         max(s.transaction_pass_count) transaction_pass_count,
         max(s.source_position_count) source_position_count,
         max(s.position_pass_count) position_pass_count,
         bool_or(s.auto_trade) auto_trade,
         bool_and(s.human_execution_only) human_execution_only,
         max(s.contract_id) contract_id,
         max(s.portfolio_batch_id) portfolio_batch_id
  from fwios.v_dashboard_system_health s
),
payload as (
  select jsonb_build_object(
    'account_summary',account_summary.v,
    'holdings',holdings.v,
    'opportunities',opportunities.v,
    'valuation_map',valuation_map.v,
    'thesis_tracking',thesis_tracking.v,
    'current_action',current_action.v,
    'alerts',alerts.v,
    'system_health',system_health.v
  ) data,
  system_health.*
  from account_summary,holdings,opportunities,valuation_map,thesis_tracking,current_action,alerts,system_health
)
select jsonb_build_object(
  'schema_version','DASHBOARD_REFRESH_PAYLOAD_V1_2',
  'sheet_id','17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8',
  'generated_at',now(),
  'contract_id',contract_id,
  'portfolio_batch_id',portfolio_batch_id,
  'refresh_gate',case
    when portfolio_batch_status='PASS'
     and source_transaction_count=transaction_pass_count
     and source_position_count=position_pass_count
     and coalesce(auto_trade,false)=false
     and coalesce(human_execution_only,false)=true
    then 'PASS' else 'BLOCKED' end,
  'source_fingerprint',md5(data::text),
  'data',data
)
from payload;
$function$;

revoke all on function fwios.dashboard_refresh_payload_v1() from public,anon,authenticated;
grant execute on function fwios.dashboard_refresh_payload_v1() to service_role;

select fwios.sync_thesis_registry_v1();
select fwios.refresh_thesis_health_v1(current_date,'THESIS_TRACKING_V1_CUTOVER');

select cron.unschedule(jobid)
from cron.job
where jobname='fwios-thesis-health-refresh';

select cron.schedule(
  'fwios-thesis-health-refresh',
  '40 6 * * 1-5',
  $$select fwios.refresh_thesis_health_v1(current_date,'CRON_POST_DECISION_REFRESH');$$
);

update fwios.system_state
set state_value=state_value||jsonb_build_object(
      'thesis_tracking','LIVE_CONTINUOUS_V1',
      'thesis_registry','fwios.thesis_registry',
      'thesis_events','fwios.thesis_events',
      'thesis_health_history','fwios.thesis_health_snapshots',
      'thesis_current_view','fwios.v_thesis_tracking_current',
      'portfolio_priority',0,
      'candidate_priority',1,
      'watchlist_priority',2,
      'health_price_separation',true,
      'broken_requires_explicit_invalidation',true,
      'thesis_refresh_schedule_utc','06:40 Mon-Fri',
      'auto_trade',false
    ),
    as_of_text='2026-09-24',
    updated_at=now()
where state_key='architecture_consolidation_v1';
