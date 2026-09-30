-- Research Lifecycle v1 regression checks
with tests as (
  select 'RL01_POLICY_ACTIVE' test_id,
    exists(
      select 1 from fwios.policy_versions
      where policy_version_id='POL-RESEARCH-LIFECYCLE-V1'
        and lifecycle_status='ACTIVE'
        and config->>'production_read_cutover'='false'
        and config->>'human_execution_only'='true'
        and config->>'auto_trade'='false'
    ) passed

  union all select 'RL02_EIGHT_STATES',
    (select jsonb_array_length(config->'states')=8
     from fwios.policy_versions
     where policy_version_id='POL-RESEARCH-LIFECYCLE-V1')

  union all select 'RL03_UNIVERSE_TO_SCREENED',
    fwios.research_lifecycle_transition_gate_v1(
      'UNIVERSE','SCREENED','UNSUPPORTED',false,false,false
    )='PASS'

  union all select 'RL04_NO_SHALLOW_TO_FULL_THESIS_JUMP',
    fwios.research_lifecycle_transition_gate_v1(
      'UNIVERSE','FULL_THESIS','ARCHETYPE_SUPPORTED',false,false,false
    )='BLOCKED - ILLEGAL LIFECYCLE TRANSITION'

  union all select 'RL05_UNSUPPORTED_BLOCKS_DEEP_PROMOTION',
    fwios.research_lifecycle_transition_gate_v1(
      'RESEARCH_CANDIDATE','FULL_THESIS','UNSUPPORTED',false,false,false
    )='BLOCKED - ARCHETYPE UNSUPPORTED FOR DEEP PROMOTION'

  union all select 'RL06_UNSUPPORTED_DOES_NOT_FORCE_REJECTION',
    fwios.research_lifecycle_transition_gate_v1(
      'WATCH','RESEARCH_CANDIDATE','UNSUPPORTED',false,false,false
    )='PASS'

  union all select 'RL07_SUPPORTED_DEEP_PROMOTION',
    fwios.research_lifecycle_transition_gate_v1(
      'RESEARCH_CANDIDATE','FULL_THESIS','ARCHETYPE_SUPPORTED',false,false,false
    )='PASS'

  union all select 'RL08_REJECT_REQUIRES_MEMORY',
    fwios.research_lifecycle_transition_gate_v1(
      'RESEARCH_CANDIDATE','REJECTED','ARCHETYPE_SUPPORTED',false,false,false
    )='BLOCKED - DECISION MEMORY REQUIRED'

  union all select 'RL09_REACTIVATION_FAIL_CLOSED',
    fwios.research_lifecycle_transition_gate_v1(
      'REJECTED','WATCH','ARCHETYPE_SUPPORTED',false,true,false
    )='BLOCKED - REACTIVATION TRIGGER REQUIRED'

  union all select 'RL10_REACTIVATION_PASS',
    fwios.research_lifecycle_transition_gate_v1(
      'REJECTED','WATCH','ARCHETYPE_SUPPORTED',true,true,false
    )='PASS'

  union all select 'RL11_PORTFOLIO_REQUIRES_RECONCILIATION',
    fwios.research_lifecycle_transition_gate_v1(
      'FULL_THESIS','PORTFOLIO','ARCHETYPE_SUPPORTED',false,false,false
    )='BLOCKED - RECONCILED PORTFOLIO HOLDING REQUIRED'

  union all select 'RL12_PORTFOLIO_CONFIRMED_PASS',
    fwios.research_lifecycle_transition_gate_v1(
      'FULL_THESIS','PORTFOLIO','ARCHETYPE_SUPPORTED',false,false,true
    )='PASS'

  union all select 'RL13_PORTFOLIO_CANNOT_DEMOTE_WHILE_HELD',
    fwios.research_lifecycle_transition_gate_v1(
      'PORTFOLIO','FULL_THESIS','ARCHETYPE_SUPPORTED',false,false,true
    )='BLOCKED - PORTFOLIO STILL HELD'

  union all select 'RL14_ATTENTION_TIER_MAPPING',
    fwios.research_attention_tier_v1('UNIVERSE')=0
    and fwios.research_attention_tier_v1('RESEARCH_CANDIDATE')=2
    and fwios.research_attention_tier_v1('FULL_THESIS')=3
    and fwios.research_attention_tier_v1('PORTFOLIO')=4
    and fwios.research_attention_tier_v1('REJECTED')=0

  union all select 'RL15_REJECTED_DECISION_MEMORY_REQUIRED_DATA',
    coalesce(
      fwios.research_lifecycle_profile_v1('REJECTED')
        ->'profile'->'required_active_data' ? 'DECISION_MEMORY',
      false
    )

  union all select 'RL16_NO_PRODUCTION_READ_CUTOVER',
    coalesce(
      (fwios.research_lifecycle_profile_v1('FULL_THESIS')
        ->>'production_read_cutover')::boolean,
      true
    )=false

  union all select 'RL17_REGISTERED_REGRESSIONS_PASS',
    not exists(
      select 1
      from fwios.decision_policy_regression_runs
      where policy_version_id='POL-RESEARCH-LIFECYCLE-V1'
        and status<>'PASS'
    )
)
select test_id,case when passed then 'PASS' else 'FAIL' end status
from tests
order by test_id;
