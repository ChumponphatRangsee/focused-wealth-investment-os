-- Preserve production health-change event behavior after holding baseline upgrade.
CREATE OR REPLACE FUNCTION fwios.refresh_thesis_health_v1(p_as_of_date date DEFAULT CURRENT_DATE, p_source text DEFAULT 'SYSTEM'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
  event_agg as (
    select
      tr.ticker,
      coalesce(sum(e.impact_score) filter(
        where e.event_date between p_as_of_date-119 and p_as_of_date
          and e.direction in ('SUPPORTS','CONTRADICTS')
      ),0) recent_event_score,
      count(*) filter(
        where e.event_date between p_as_of_date-119 and p_as_of_date
          and e.direction='SUPPORTS'
      )::int support_events_120d,
      count(*) filter(
        where e.event_date between p_as_of_date-119 and p_as_of_date
          and e.direction='CONTRADICTS'
      )::int contradict_events_120d,
      min(e.impact_score) filter(
        where e.event_date between p_as_of_date-119 and p_as_of_date
          and e.direction='CONTRADICTS'
      ) strongest_negative_120d
    from fwios.thesis_registry tr
    left join fwios.thesis_events e on e.ticker=tr.ticker
    where tr.active=true
    group by tr.ticker
  ),
  signals as (
    select
      tr.ticker,
      tr.baseline_status,
      tr.baseline_completeness,
      tr.manual_health_override,
      rc.business_thesis_score,
      rc.risk_gate,
      rc.valuation_gate,
      rc.mispricing_gate,
      rc.promotion_gate,
      rc.final_decision,
      rev.revision_score,
      rev.revision_gate,
      ch.chase_risk,
      ch.chase_gate,
      q.overall_gate hardening_gate,
      q.valuation_confidence,
      coalesce(bl.blocker_count,0) blocker_count,
      vm.price_zone,
      vm.fair_value_upside,
      vm.system_signal,
      coalesce(ea.recent_event_score,0) recent_event_score,
      coalesce(ea.support_events_120d,0) support_events_120d,
      coalesce(ea.contradict_events_120d,0) contradict_events_120d,
      ea.strongest_negative_120d,
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
    left join event_agg ea on ea.ticker=tr.ticker
    where tr.active=true
  ),
  calc as (
    select s.*,
      case
        when s.manual_health_override is not null then s.manual_health_override
        when s.explicit_invalidation then 'BROKEN'
        when s.baseline_status='BASELINE_REQUIRED' then 'BASELINE_REQUIRED'
        when coalesce(s.revision_gate,'') like 'FAIL%'
          or s.hardening_gate='FAIL'
          or s.recent_event_score<=-25
          or coalesce(s.strongest_negative_120d,0)<=-40 then 'WEAKENING'
        when s.risk_gate='WATCH'
          or s.hardening_gate='REVIEW'
          or coalesce(s.revision_gate,'') like 'BLOCKED%'
          or coalesce(s.chase_gate,'') like 'BLOCKED%'
          or s.recent_event_score<0 then 'WATCH'
        when s.baseline_status='COMPLETE'
          and s.recent_event_score>=15
          and coalesce(s.strongest_negative_120d,0)>-20 then 'STRONG'
        when s.baseline_status='COMPLETE'
          and s.revision_gate='PASS'
          and s.hardening_gate='PASS'
          and coalesce(s.risk_gate,'PASS')='PASS' then 'STRONG'
        else 'STABLE'
      end health_status,
      case
        when s.business_thesis_score is null then null
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
          + greatest(-30,least(15,s.recent_event_score))
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
      final_decision,blocker_count,entry_status,health_reason,source_reference,
      recent_event_score,support_events_120d,contradict_events_120d,strongest_negative_120d,
      payload,updated_at
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
        when c.health_status='WEAKENING' and c.recent_event_score<=-25 then 'Recent thesis evidence is materially net-negative.'
        when c.health_status='WATCH' and c.recent_event_score<0 then 'Recent thesis evidence is net-negative and requires monitoring.'
        when c.health_status='WATCH' then 'Thesis is intact but one or more monitoring gates require review or remain incomplete.'
        when c.health_status='STRONG' and c.recent_event_score>=15 then 'Recent verified evidence materially supports the completed baseline thesis.'
        when c.health_status='STRONG' then 'Revision and quality hardening both pass with a clean risk gate.'
        else 'No explicit invalidation or material negative fundamental signal is active.'
      end,
      p_source,
      c.recent_event_score,c.support_events_120d,c.contradict_events_120d,c.strongest_negative_120d,
      jsonb_build_object(
        'price_zone',c.price_zone,
        'fair_value_upside',c.fair_value_upside,
        'system_signal',c.system_signal,
        'health_price_separation',true,
        'recent_event_window_days',120
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
      recent_event_score=excluded.recent_event_score,
      support_events_120d=excluded.support_events_120d,
      contradict_events_120d=excluded.contradict_events_120d,
      strongest_negative_120d=excluded.strongest_negative_120d,
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
      0,
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
    'event_window_days',120,
    'broken_requires_explicit_invalidation',true
  );
end
$function$
;

revoke all on function fwios.refresh_thesis_health_v1(date,text) from public,anon,authenticated;
grant execute on function fwios.refresh_thesis_health_v1(date,text) to service_role;
