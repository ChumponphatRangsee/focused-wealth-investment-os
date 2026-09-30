
create or replace function fwios.record_thesis_decision_memory_v1(
  p_ticker text,
  p_decision_class text,
  p_lifecycle_state text,
  p_decision_summary text,
  p_rationale text,
  p_decision_snapshot_id text default null,
  p_source_reference text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_reactivation_trigger_type text default null,
  p_reactivation_summary text default null,
  p_reactivation_metric_code text default null,
  p_reactivation_operator text default null,
  p_reactivation_threshold numeric default null,
  p_reactivation_target_state text default null
)
returns text
language plpgsql
set search_path to ''
as $function$
declare
  v_ticker text:=upper(trim(p_ticker));
  v_class text:=upper(trim(p_decision_class));
  v_state text:=upper(trim(p_lifecycle_state));
  v_target text:=upper(trim(coalesce(p_reactivation_target_state,'WATCH')));
  v_instrument uuid;
  v_memory_id text;
  v_rule_id text;
  v_gate text;
begin
  select instrument_id into v_instrument
  from fwios.thesis_registry
  where ticker=v_ticker and active=true;

  if v_instrument is null then
    raise exception 'THESIS_TICKER_NOT_REGISTERED: %',v_ticker;
  end if;

  if v_class not in ('REJECT','DEFER','WATCH','PROMOTE') then
    raise exception 'INVALID_THESIS_DECISION_CLASS';
  end if;

  if v_state not in ('UNIVERSE','SCREENED','WATCH','RESEARCH_CANDIDATE','FULL_THESIS','PORTFOLIO','REJECTED','ARCHIVED') then
    raise exception 'INVALID_RESEARCH_LIFECYCLE_STATE';
  end if;

  if coalesce(trim(p_decision_summary),'')='' or coalesce(trim(p_rationale),'')='' then
    raise exception 'DECISION_SUMMARY_AND_RATIONALE_REQUIRED';
  end if;

  if v_class='PROMOTE' and v_state='PORTFOLIO' then
    raise exception 'PROMOTE_MEMORY_CANNOT_DIRECTLY_ENTER_PORTFOLIO';
  end if;

  if v_class='REJECT' then
    if v_state<>'REJECTED' then
      raise exception 'REJECT_MEMORY_REQUIRES_REJECTED_STATE';
    end if;

    if p_reactivation_trigger_type is null or coalesce(trim(p_reactivation_summary),'')='' then
      raise exception 'REJECT_MEMORY_REQUIRES_REACTIVATION_RULE';
    end if;

    v_gate:=fwios.thesis_reactivation_transition_gate_v1('REJECTED',v_target,true,true);
    if v_gate not like 'PASS%' then
      raise exception '%',v_gate;
    end if;

    if upper(p_reactivation_trigger_type)='METRIC_THRESHOLD'
       and (p_reactivation_metric_code is null or p_reactivation_operator is null or p_reactivation_threshold is null) then
      raise exception 'METRIC_REACTIVATION_RULE_REQUIRES_METRIC_OPERATOR_THRESHOLD';
    end if;
  end if;

  v_memory_id:='MEM-'||v_ticker||'-'||replace(gen_random_uuid()::text,'-','');

  insert into fwios.thesis_decision_memory(
    decision_memory_id,ticker,instrument_id,decision_class,lifecycle_state,
    decision_snapshot_id,decision_summary,rationale,reactivation_required,
    source_reference,metadata
  ) values (
    v_memory_id,v_ticker,v_instrument,v_class,v_state,
    p_decision_snapshot_id,p_decision_summary,p_rationale,(v_class='REJECT'),
    p_source_reference,coalesce(p_metadata,'{}'::jsonb)
  );

  if v_class='REJECT' then
    v_rule_id:='RTR-'||v_ticker||'-'||replace(gen_random_uuid()::text,'-','');

    insert into fwios.thesis_reactivation_rules(
      rule_id,decision_memory_id,ticker,instrument_id,trigger_type,metric_code,
      comparison_operator,threshold_numeric,target_lifecycle_state,trigger_summary,
      source_reference,metadata
    ) values (
      v_rule_id,v_memory_id,v_ticker,v_instrument,upper(p_reactivation_trigger_type),
      p_reactivation_metric_code,upper(p_reactivation_operator),p_reactivation_threshold,
      v_target,p_reactivation_summary,p_source_reference,
      jsonb_build_object('created_with_memory',true)
    );
  end if;

  return v_memory_id;
end
$function$;

create or replace function fwios.thesis_reactivation_evaluate_v1(
  p_rule_id text,
  p_metric_observation_id uuid default null,
  p_thesis_event_id uuid default null,
  p_manual_confirmed boolean default false
)
returns jsonb
language plpgsql
stable
set search_path to ''
as $function$
declare
  r fwios.thesis_reactivation_rules%rowtype;
  m fwios.thesis_decision_memory%rowtype;
  o fwios.metric_observations%rowtype;
  e fwios.thesis_events%rowtype;
  v_memory_gate text;
  v_transition_gate text;
  v_trigger_gate text:='BLOCKED - TRIGGER NOT SATISFIED';
  v_period_count integer:=0;
  v_pass_count integer:=0;
begin
  select * into r from fwios.thesis_reactivation_rules where rule_id=p_rule_id and active=true;
  if not found then
    return jsonb_build_object('gate','BLOCKED - REACTIVATION RULE MISSING');
  end if;

  select * into m from fwios.thesis_decision_memory where decision_memory_id=r.decision_memory_id;
  if not found then
    return jsonb_build_object('gate','BLOCKED - DECISION MEMORY MISSING');
  end if;

  v_memory_gate:=fwios.thesis_decision_memory_gate_v1(m.decision_memory_id);
  if v_memory_gate<>'PASS' then
    return jsonb_build_object('gate',v_memory_gate,'decision_memory_id',m.decision_memory_id);
  end if;

  if r.trigger_type='METRIC_THRESHOLD' then
    if p_metric_observation_id is null then
      return jsonb_build_object('gate','BLOCKED - METRIC OBSERVATION REQUIRED','rule_id',r.rule_id);
    end if;

    select * into o from fwios.metric_observations where observation_id=p_metric_observation_id;
    if not found
       or o.instrument_id<>r.instrument_id
       or o.metric_code<>r.metric_code
       or o.provenance_status<>'PASS'
       or o.value_numeric is null then
      return jsonb_build_object('gate','BLOCKED - METRIC OBSERVATION INVALID','rule_id',r.rule_id);
    end if;

    with period_rows as (
      select distinct on (
        coalesce(mo.period_label,mo.period_end::text,mo.as_of_date::text,mo.observation_id::text)
      )
        mo.value_numeric,
        coalesce(mo.period_end,mo.as_of_date,mo.effective_at::date,mo.reported_at::date,mo.created_at::date) period_sort,
        mo.created_at
      from fwios.metric_observations mo
      where mo.instrument_id=r.instrument_id
        and mo.metric_code=r.metric_code
        and mo.provenance_status='PASS'
        and mo.value_numeric is not null
        and mo.created_at<=o.created_at
      order by
        coalesce(mo.period_label,mo.period_end::text,mo.as_of_date::text,mo.observation_id::text),
        mo.created_at desc
    ),
    recent as (
      select value_numeric
      from period_rows
      order by period_sort desc nulls last,created_at desc
      limit r.consecutive_periods
    )
    select
      count(*)::int,
      count(*) filter(where
        case r.comparison_operator
          when 'LT' then value_numeric<r.threshold_numeric
          when 'LTE' then value_numeric<=r.threshold_numeric
          when 'GT' then value_numeric>r.threshold_numeric
          when 'GTE' then value_numeric>=r.threshold_numeric
          when 'EQ' then value_numeric=r.threshold_numeric
          when 'NE' then value_numeric<>r.threshold_numeric
          else false
        end
      )::int
    into v_period_count,v_pass_count
    from recent;

    if v_period_count=r.consecutive_periods and v_pass_count=r.consecutive_periods then
      v_trigger_gate:='PASS';
    elsif v_period_count<r.consecutive_periods then
      v_trigger_gate:='BLOCKED - INSUFFICIENT CONSECUTIVE PERIODS';
    else
      v_trigger_gate:='BLOCKED - METRIC THRESHOLD NOT SATISFIED';
    end if;

  elsif r.trigger_type in ('THESIS_EVENT','MATERIAL_CHANGE') then
    if p_thesis_event_id is null then
      return jsonb_build_object('gate','BLOCKED - THESIS EVENT REQUIRED','rule_id',r.rule_id);
    end if;

    select * into e from fwios.thesis_events where event_id=p_thesis_event_id;
    if not found or e.ticker<>r.ticker then
      return jsonb_build_object('gate','BLOCKED - THESIS EVENT INVALID','rule_id',r.rule_id);
    end if;

    if r.threshold_text is not null and e.event_type<>r.threshold_text then
      v_trigger_gate:='BLOCKED - EVENT TYPE NOT SATISFIED';
    else
      v_trigger_gate:='PASS';
    end if;

  elsif r.trigger_type='MANUAL_REVIEW' then
    v_trigger_gate:=case when p_manual_confirmed then 'PASS' else 'BLOCKED - MANUAL CONFIRMATION REQUIRED' end;
  else
    v_trigger_gate:='BLOCKED - UNSUPPORTED TRIGGER';
  end if;

  if v_trigger_gate<>'PASS' then
    return jsonb_build_object(
      'gate',v_trigger_gate,
      'rule_id',r.rule_id,
      'decision_memory_id',m.decision_memory_id,
      'target_lifecycle_state',r.target_lifecycle_state
    );
  end if;

  v_transition_gate:=fwios.thesis_reactivation_transition_gate_v1(
    m.lifecycle_state,r.target_lifecycle_state,true,true
  );

  return jsonb_build_object(
    'gate',v_transition_gate,
    'trigger_gate',v_trigger_gate,
    'rule_id',r.rule_id,
    'decision_memory_id',m.decision_memory_id,
    'ticker',r.ticker,
    'prior_lifecycle_state',m.lifecycle_state,
    'target_lifecycle_state',r.target_lifecycle_state,
    'reactivation_action','RESEARCH_REVIEW_ONLY',
    'direct_buy_promotion',false,
    'history_preserved',true
  );
end
$function$;

create or replace function fwios.record_thesis_reactivation_event_v1(
  p_rule_id text,
  p_metric_observation_id uuid default null,
  p_thesis_event_id uuid default null,
  p_manual_confirmed boolean default false,
  p_source_reference text default null
)
returns uuid
language plpgsql
set search_path to ''
as $function$
declare
  r fwios.thesis_reactivation_rules%rowtype;
  m fwios.thesis_decision_memory%rowtype;
  v_eval jsonb;
  v_event_id uuid;
begin
  select * into r from fwios.thesis_reactivation_rules where rule_id=p_rule_id and active=true;
  if not found then raise exception 'REACTIVATION_RULE_MISSING'; end if;

  select * into m from fwios.thesis_decision_memory where decision_memory_id=r.decision_memory_id;
  if not found then raise exception 'DECISION_MEMORY_MISSING'; end if;

  v_eval:=fwios.thesis_reactivation_evaluate_v1(
    p_rule_id,p_metric_observation_id,p_thesis_event_id,p_manual_confirmed
  );

  if v_eval->>'gate' not like 'PASS%' then
    raise exception '%',v_eval->>'gate';
  end if;

  insert into fwios.thesis_reactivation_events(
    rule_id,decision_memory_id,ticker,instrument_id,
    trigger_observation_id,trigger_thesis_event_id,
    prior_lifecycle_state,resulting_lifecycle_state,evaluation_gate,
    evaluation_payload,source_reference
  ) values (
    r.rule_id,m.decision_memory_id,r.ticker,r.instrument_id,
    p_metric_observation_id,p_thesis_event_id,
    m.lifecycle_state,r.target_lifecycle_state,'PASS',
    v_eval,p_source_reference
  )
  returning reactivation_event_id into v_event_id;

  return v_event_id;
end
$function$;

create or replace view fwios.v_thesis_decision_memory_current
with (security_invoker=true)
as
select distinct on (m.ticker)
  m.*,
  fwios.thesis_decision_memory_gate_v1(m.decision_memory_id) memory_gate,
  (select count(*) from fwios.thesis_reactivation_rules r
    where r.decision_memory_id=m.decision_memory_id and r.active=true) reactivation_rule_count
from fwios.thesis_decision_memory m
order by m.ticker,m.created_at desc,m.decision_memory_id desc;

create or replace view fwios.v_thesis_reactivation_latest
with (security_invoker=true)
as
select distinct on (e.ticker)
  e.*
from fwios.thesis_reactivation_events e
order by e.ticker,e.created_at desc,e.reactivation_event_id desc;

revoke all on fwios.v_thesis_decision_memory_current from public,anon,authenticated;
revoke all on fwios.v_thesis_reactivation_latest from public,anon,authenticated;
grant select on fwios.v_thesis_decision_memory_current to service_role;
grant select on fwios.v_thesis_reactivation_latest to service_role;
