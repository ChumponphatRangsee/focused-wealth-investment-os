-- Research Lifecycle Contract v1
-- Issue #32 / Epic #31
-- Contract-only foundation: no production research read-path cutover and no portfolio mutation.
-- Broad universes remain shallow; deep research is selective and fail-closed.

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status,updated_at
) values (
  'RESEARCH_LIFECYCLE',
  'RESEARCH',
  'Research Lifecycle v1',
  'Deterministic research-state transitions, attention-depth semantics, archetype coverage gates, and retention requirements.',
  'fwios.research_lifecycle_transition_gate_v1',
  'ACTIVE',
  now()
)
on conflict(policy_key) do update set
  policy_domain=excluded.policy_domain,
  policy_name=excluded.policy_name,
  purpose=excluded.purpose,
  backing_object=excluded.backing_object,
  lifecycle_status=excluded.lifecycle_status,
  updated_at=now();

insert into fwios.policy_versions(
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference,effective_at
) values (
  'POL-RESEARCH-LIFECYCLE-V1',
  'RESEARCH_LIFECYCLE',
  '1.0',
  'ACTIVE',
  true,
  $json$
  {
    "states": [
      "UNIVERSE",
      "SCREENED",
      "WATCH",
      "RESEARCH_CANDIDATE",
      "FULL_THESIS",
      "PORTFOLIO",
      "REJECTED",
      "ARCHIVED"
    ],
    "pipeline_states": [
      "UNIVERSE",
      "SCREENED",
      "WATCH",
      "RESEARCH_CANDIDATE",
      "FULL_THESIS",
      "PORTFOLIO"
    ],
    "side_states": ["REJECTED", "ARCHIVED"],
    "deep_states": ["FULL_THESIS", "PORTFOLIO"],
    "legal_transitions": {
      "UNIVERSE": ["SCREENED", "ARCHIVED"],
      "SCREENED": ["UNIVERSE", "WATCH", "REJECTED", "ARCHIVED"],
      "WATCH": ["SCREENED", "RESEARCH_CANDIDATE", "REJECTED", "ARCHIVED"],
      "RESEARCH_CANDIDATE": ["WATCH", "FULL_THESIS", "REJECTED", "ARCHIVED"],
      "FULL_THESIS": ["RESEARCH_CANDIDATE", "WATCH", "PORTFOLIO", "REJECTED", "ARCHIVED"],
      "PORTFOLIO": ["FULL_THESIS", "WATCH"],
      "REJECTED": ["SCREENED", "WATCH", "ARCHIVED"],
      "ARCHIVED": ["UNIVERSE", "SCREENED"]
    },
    "archetype_coverage_states": {
      "GENERIC": {
        "deep_promotion_allowed": true,
        "meaning": "Universal/generic research coverage exists; downstream valuation/model gates remain independently fail-closed."
      },
      "ARCHETYPE_SUPPORTED": {
        "deep_promotion_allowed": true,
        "meaning": "A reusable validated archetype pack is available."
      },
      "CUSTOM": {
        "deep_promotion_allowed": true,
        "meaning": "A validated company-specific model or research pack is available."
      },
      "UNSUPPORTED": {
        "deep_promotion_allowed": false,
        "meaning": "No validated deep model is available; do not reject automatically, but block promotion into deep states."
      }
    },
    "state_profiles": {
      "UNIVERSE": {
        "attention_tier": 0,
        "resource_mode": "BROAD_BATCH",
        "refresh_mode": "LOW_COST_BATCH",
        "required_active_data": ["IDENTITY", "CLASSIFICATION", "BASIC_MARKET_METADATA", "UNIVERSAL_SCREEN_SNAPSHOT"]
      },
      "SCREENED": {
        "attention_tier": 1,
        "resource_mode": "SIGNAL_MONITOR",
        "refresh_mode": "PERIODIC_SIGNAL",
        "required_active_data": ["IDENTITY", "SCREEN_RESULT", "SCREEN_REASON", "SELECTED_CANONICAL_METRICS"]
      },
      "WATCH": {
        "attention_tier": 1,
        "resource_mode": "WATCH_MONITOR",
        "refresh_mode": "EVENT_OR_PERIODIC",
        "required_active_data": ["WATCH_RATIONALE", "REVIEW_TRIGGER", "NEXT_REVIEW_AT", "LIMITED_VALUATION_SIGNAL"]
      },
      "RESEARCH_CANDIDATE": {
        "attention_tier": 2,
        "resource_mode": "TARGETED_RESEARCH",
        "refresh_mode": "ON_DEMAND_PLUS_EVENTS",
        "required_active_data": ["RESEARCH_HYPOTHESIS", "TARGETED_EVIDENCE", "SELECTED_METRICS", "ARCHETYPE_COVERAGE", "OPEN_RESEARCH_BLOCKERS"]
      },
      "FULL_THESIS": {
        "attention_tier": 3,
        "resource_mode": "DEEP_THESIS",
        "refresh_mode": "MATERIAL_EVENT_PLUS_PERIODIC",
        "required_active_data": ["THESIS_STATEMENT", "MUST_REMAIN_TRUE", "MONITORING_KPIS", "INVALIDATION_RULES", "VALUATION_STATE", "REVISION_STATE", "CHASE_STATE", "HARDENING_STATE", "EVIDENCE_LINEAGE"]
      },
      "PORTFOLIO": {
        "attention_tier": 4,
        "resource_mode": "CAPITAL_CRITICAL",
        "refresh_mode": "CONTINUOUS_MATERIAL_EVENT",
        "required_active_data": ["FULL_THESIS_STATE", "RECONCILED_PORTFOLIO_LINK", "POSITION_RISK", "MARK_TO_MARKET", "CAPITAL_DECISION_STATE"]
      },
      "REJECTED": {
        "attention_tier": 0,
        "resource_mode": "TRIGGER_ONLY",
        "refresh_mode": "REACTIVATION_TRIGGER_ONLY",
        "required_active_data": ["DECISION_MEMORY", "REJECTION_REASONS", "DECISION_CONTEXT", "REACTIVATION_CONDITIONS"]
      },
      "ARCHIVED": {
        "attention_tier": 0,
        "resource_mode": "DORMANT",
        "refresh_mode": "NONE_EXCEPT_MANUAL_REACTIVATION",
        "required_active_data": ["ARCHIVE_REASON", "PRIOR_STATE_REFERENCE", "AUDIT_LINEAGE"]
      }
    },
    "reactivation_required_from": ["REJECTED", "ARCHIVED"],
    "decision_memory_required_for_rejected": true,
    "portfolio_state_requires_reconciled_holding": true,
    "retention_invariant": "Lifecycle demotion never deletes prior evidence, thesis, decision, approval, or portfolio audit lineage.",
    "broad_universe_is_shallow": true,
    "full_thesis_is_selective": true,
    "sector_completeness_required": false,
    "archetype_build_is_demand_driven": true,
    "production_read_cutover": false,
    "human_execution_only": true,
    "auto_trade": false
  }
  $json$::jsonb,
  'GitHub policies/research/RESEARCH_LIFECYCLE_V1.md; Epic #31 Issue #32',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status=excluded.lifecycle_status,
  deterministic_scoring=excluded.deterministic_scoring,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

create or replace function fwios.research_lifecycle_transition_gate_v1(
  p_from_state text,
  p_to_state text,
  p_archetype_coverage text default 'UNSUPPORTED',
  p_reactivation_trigger boolean default false,
  p_decision_memory_recorded boolean default false,
  p_portfolio_holding_confirmed boolean default false
)
returns text
language plpgsql
stable
set search_path to ''
as $function$
declare
  v_config jsonb;
  v_from text := upper(trim(coalesce(p_from_state,'')));
  v_to text := upper(trim(coalesce(p_to_state,'')));
  v_coverage text := upper(trim(coalesce(p_archetype_coverage,'')));
begin
  select pv.config
    into v_config
  from fwios.policy_versions pv
  where pv.policy_version_id='POL-RESEARCH-LIFECYCLE-V1'
    and pv.lifecycle_status='ACTIVE';

  if v_config is null then
    return 'BLOCKED - POLICY NOT ACTIVE';
  end if;

  if not ((v_config->'states') ? v_from) then
    return 'BLOCKED - INVALID FROM STATE';
  end if;

  if not ((v_config->'states') ? v_to) then
    return 'BLOCKED - INVALID TO STATE';
  end if;

  if not ((v_config->'archetype_coverage_states') ? v_coverage) then
    return 'BLOCKED - INVALID ARCHETYPE COVERAGE';
  end if;

  if v_from=v_to then
    return 'PASS - NOOP';
  end if;

  if not coalesce((v_config->'legal_transitions'->v_from) ? v_to,false) then
    return 'BLOCKED - ILLEGAL LIFECYCLE TRANSITION';
  end if;

  if coalesce((v_config->'deep_states') ? v_to,false)
     and v_coverage='UNSUPPORTED' then
    return 'BLOCKED - ARCHETYPE UNSUPPORTED FOR DEEP PROMOTION';
  end if;

  if v_to='REJECTED' and not p_decision_memory_recorded then
    return 'BLOCKED - DECISION MEMORY REQUIRED';
  end if;

  if v_from in ('REJECTED','ARCHIVED')
     and v_to not in ('REJECTED','ARCHIVED')
     and not p_reactivation_trigger then
    return 'BLOCKED - REACTIVATION TRIGGER REQUIRED';
  end if;

  if v_to='PORTFOLIO' and not p_portfolio_holding_confirmed then
    return 'BLOCKED - RECONCILED PORTFOLIO HOLDING REQUIRED';
  end if;

  if v_from='PORTFOLIO'
     and v_to<>'PORTFOLIO'
     and p_portfolio_holding_confirmed then
    return 'BLOCKED - PORTFOLIO STILL HELD';
  end if;

  return 'PASS';
end
$function$;

create or replace function fwios.research_attention_tier_v1(p_state text)
returns integer
language sql
stable
set search_path to ''
as $function$
  select case
    when pv.config is null then null
    when not ((pv.config->'states') ? upper(trim(coalesce(p_state,'')))) then null
    else (pv.config->'state_profiles'->upper(trim(p_state))->>'attention_tier')::integer
  end
  from (
    select config
    from fwios.policy_versions
    where policy_version_id='POL-RESEARCH-LIFECYCLE-V1'
      and lifecycle_status='ACTIVE'
  ) pv;
$function$;

create or replace function fwios.research_lifecycle_profile_v1(p_state text)
returns jsonb
language sql
stable
set search_path to ''
as $function$
  select case
    when pv.config is null then null
    when not ((pv.config->'states') ? upper(trim(coalesce(p_state,'')))) then null
    else jsonb_build_object(
      'state',upper(trim(p_state)),
      'profile',pv.config->'state_profiles'->upper(trim(p_state)),
      'policy_version_id','POL-RESEARCH-LIFECYCLE-V1',
      'production_read_cutover',false
    )
  end
  from (
    select config
    from fwios.policy_versions
    where policy_version_id='POL-RESEARCH-LIFECYCLE-V1'
      and lifecycle_status='ACTIVE'
  ) pv;
$function$;

revoke all on function fwios.research_lifecycle_transition_gate_v1(text,text,text,boolean,boolean,boolean)
  from public,anon,authenticated;
revoke all on function fwios.research_attention_tier_v1(text)
  from public,anon,authenticated;
revoke all on function fwios.research_lifecycle_profile_v1(text)
  from public,anon,authenticated;

grant execute on function fwios.research_lifecycle_transition_gate_v1(text,text,text,boolean,boolean,boolean)
  to service_role;
grant execute on function fwios.research_attention_tier_v1(text)
  to service_role;
grant execute on function fwios.research_lifecycle_profile_v1(text)
  to service_role;

with cases(
  case_id,from_state,to_state,coverage,reactivation,decision_memory,holding_confirmed,expected_gate,notes
) as (
  values
    ('01','UNIVERSE','SCREENED','UNSUPPORTED',false,false,false,'PASS','Broad discovery may enter screened state without deep model coverage.'),
    ('02','UNIVERSE','FULL_THESIS','ARCHETYPE_SUPPORTED',false,false,false,'BLOCKED - ILLEGAL LIFECYCLE TRANSITION','No shallow-to-deep jump.'),
    ('03','RESEARCH_CANDIDATE','FULL_THESIS','UNSUPPORTED',false,false,false,'BLOCKED - ARCHETYPE UNSUPPORTED FOR DEEP PROMOTION','Unsupported does not reject; it blocks deep promotion.'),
    ('04','RESEARCH_CANDIDATE','FULL_THESIS','ARCHETYPE_SUPPORTED',false,false,false,'PASS','Validated archetype pack allows deep promotion.'),
    ('05','REJECTED','WATCH','ARCHETYPE_SUPPORTED',false,true,false,'BLOCKED - REACTIVATION TRIGGER REQUIRED','Rejected names are dormant until an explicit trigger.'),
    ('06','REJECTED','WATCH','ARCHETYPE_SUPPORTED',true,true,false,'PASS','Explicit reactivation may return a rejected idea to active research.'),
    ('07','FULL_THESIS','PORTFOLIO','ARCHETYPE_SUPPORTED',false,false,false,'BLOCKED - RECONCILED PORTFOLIO HOLDING REQUIRED','Research state cannot manufacture portfolio ownership.'),
    ('08','FULL_THESIS','PORTFOLIO','ARCHETYPE_SUPPORTED',false,false,true,'PASS','Portfolio state reflects an already reconciled holding.'),
    ('09','PORTFOLIO','FULL_THESIS','ARCHETYPE_SUPPORTED',false,false,true,'BLOCKED - PORTFOLIO STILL HELD','Do not demote while the asset remains held.'),
    ('10','RESEARCH_CANDIDATE','REJECTED','ARCHETYPE_SUPPORTED',false,false,false,'BLOCKED - DECISION MEMORY REQUIRED','Rejection requires persistent decision memory.'),
    ('11','RESEARCH_CANDIDATE','REJECTED','ARCHETYPE_SUPPORTED',false,true,false,'PASS','Recorded decision memory permits rejection.')
),
evaluated as (
  select
    c.*,
    fwios.research_lifecycle_transition_gate_v1(
      c.from_state,c.to_state,c.coverage,c.reactivation,c.decision_memory,c.holding_confirmed
    ) actual_gate
  from cases c
)
insert into fwios.decision_policy_regression_runs(
  regression_id,policy_key,policy_version_id,test_case,input_payload,
  expected_payload,actual_payload,status,tolerance,notes
)
select
  'REG-RL-V1-'||case_id,
  'RESEARCH_LIFECYCLE',
  'POL-RESEARCH-LIFECYCLE-V1',
  notes,
  jsonb_build_object(
    'from_state',from_state,
    'to_state',to_state,
    'archetype_coverage',coverage,
    'reactivation_trigger',reactivation,
    'decision_memory_recorded',decision_memory,
    'portfolio_holding_confirmed',holding_confirmed
  ),
  jsonb_build_object('gate',expected_gate),
  jsonb_build_object('gate',actual_gate),
  case when actual_gate=expected_gate then 'PASS' else 'FAIL' end,
  null,
  notes
from evaluated
on conflict(regression_id) do update set
  input_payload=excluded.input_payload,
  expected_payload=excluded.expected_payload,
  actual_payload=excluded.actual_payload,
  status=excluded.status,
  notes=excluded.notes;
