-- Thesis Memory + Reactivation v1 acceptance suite
with tests as (
  select 'THM01_POLICY' test_id,
    exists(select 1 from fwios.policy_versions
      where policy_version_id='POL-THESIS-MEMORY-V1'
        and lifecycle_status='ACTIVE'
        and config->>'production_read_cutover'='false'
        and config->>'direct_buy_promotion'='false'
        and config->>'auto_trade'='false') passed

  union all select 'THM02_NORMALIZED_COUNTS',
    (select count(*) from fwios.thesis_conditions)=73
    and (select count(*) from fwios.thesis_kpi_bindings)=37

  union all select 'THM03_COMPLETE_BASELINE_JSON_PARITY',
    not exists(
      select 1
      from fwios.thesis_registry tr
      join fwios.v_thesis_memory_normalized_compat v using(ticker)
      where tr.baseline_status='COMPLETE'
        and (
          tr.must_remain_true is distinct from v.normalized_must_remain_true
          or tr.monitoring_kpis is distinct from v.normalized_monitoring_kpis
          or tr.catalysts is distinct from v.normalized_catalysts
          or tr.invalidation_criteria is distinct from v.normalized_invalidation_criteria
        )
    )

  union all select 'THM04_ADBE_BASELINE_HASH',
    exists(select 1 from fwios.thesis_registry
      where ticker='ADBE'
        and md5(coalesce(thesis_statement,''))='58990e39c4cd6093c3a72e4732338f10'
        and md5(must_remain_true::text)='eee28f0b04bd39d9fdf888ff58f7dbd5'
        and md5(monitoring_kpis::text)='82138db466a55e3e59b72a920427e715'
        and md5(catalysts::text)='3b84e2cc7fb908647d8d22b71408e0a9'
        and md5(invalidation_criteria::text)='41b49901bf21637c1b5b1fd945d65e53')

  union all select 'THM05_PINS_BASELINE_HASH',
    exists(select 1 from fwios.thesis_registry
      where ticker='PINS'
        and md5(coalesce(thesis_statement,''))='4b5f693e3257ea62b5f0808c9d1f7294'
        and md5(must_remain_true::text)='8d16f2c0590e70e4977040e571f0da2f'
        and md5(monitoring_kpis::text)='ba5adfed0e54cd41f09d6bed8e5ed3f4'
        and md5(catalysts::text)='eede79d638e96aa77c84468e339d554a'
        and md5(invalidation_criteria::text)='25872dcdcfc3a8af65ec9a1c8c3e9675')

  union all select 'THM06_PINS_KPI_BINDINGS',
    (select count(*) from fwios.thesis_kpi_bindings
      where ticker='PINS' and mapping_status<>'UNMAPPED')>=7
    and (select count(*) from fwios.thesis_kpi_bindings
      where ticker='PINS' and baseline_observation_id is not null)>=7

  union all select 'THM07_CONDITION_METRIC_LINKS',
    (select count(*) from fwios.thesis_condition_metric_links)>=8
    and not exists(
      select 1
      from fwios.thesis_condition_metric_links l
      join fwios.thesis_conditions c on c.condition_id=l.condition_id
      join fwios.metric_observations o on o.observation_id=l.baseline_observation_id
      where l.baseline_observation_id is not null
        and (o.instrument_id<>c.instrument_id or o.metric_code<>l.metric_code)
    )

  union all select 'THM08_CURRENT_DECISION_MEMORY',
    exists(select 1 from fwios.thesis_decision_memory
      where decision_memory_id='MEM-ADBE-CURRENT-20260930'
        and decision_class='DEFER'
        and decision_snapshot_id='DEC-ADBE-REFRESH-20260911')
    and exists(select 1 from fwios.thesis_decision_memory
      where decision_memory_id='MEM-PINS-CURRENT-20260930'
        and decision_class='WATCH'
        and decision_snapshot_id='DEC-PINS-REFRESH-20260911')

  union all select 'THM09_REJECTED_DORMANT_PROFILE',
    fwios.research_attention_tier_v1('REJECTED')=0
    and (fwios.research_lifecycle_profile_v1('REJECTED')->'profile'->>'refresh_mode')='REACTIVATION_TRIGGER_ONLY'

  union all select 'THM10_REACTIVATION_TRIGGER_REQUIRED',
    fwios.thesis_reactivation_transition_gate_v1('REJECTED','WATCH',false,true)
      ='BLOCKED - REACTIVATION TRIGGER REQUIRED'

  union all select 'THM11_REACTIVATION_EXPLICIT_PASS',
    fwios.thesis_reactivation_transition_gate_v1('REJECTED','WATCH',true,true)='PASS'

  union all select 'THM12_NO_DIRECT_DEEP_PROMOTION',
    fwios.thesis_reactivation_transition_gate_v1('REJECTED','FULL_THESIS',true,true)
      ='BLOCKED - REACTIVATION REVIEW ONLY'
    and fwios.thesis_reactivation_transition_gate_v1('REJECTED','PORTFOLIO',true,true)
      ='BLOCKED - REACTIVATION REVIEW ONLY'

  union all select 'THM13_APPEND_ONLY_MEMORY',
    (select count(*) from pg_trigger
      where tgrelid in (
        'fwios.thesis_decision_memory'::regclass,
        'fwios.thesis_reactivation_rules'::regclass,
        'fwios.thesis_reactivation_events'::regclass
      )
      and not tgisinternal
      and tgname in (
        'thesis_decision_memory_append_only',
        'thesis_reactivation_rules_append_only',
        'thesis_reactivation_events_append_only'
      ))=3

  union all select 'THM14_EXISTING_OUTPUT_PARITY',
    exists(select 1 from fwios.research_candidates
      where ticker='ADBE'
        and final_decision='WAIT - POST-EVENT PRICE / REVISION-CHASE'
        and promotion_gate='BLOCKED - MATERIAL EVENT REVALIDATION')
    and exists(select 1 from fwios.research_candidates
      where ticker='PINS'
        and final_decision='PRICE CONFLICT'
        and promotion_gate='BLOCKED - PRICE CONFLICT')

  union all select 'THM15_PRIVATE_RLS_AND_REGISTRY',
    not exists(
      select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='fwios'
        and c.relname in (
          'thesis_conditions','thesis_kpi_bindings','thesis_condition_metric_links',
          'thesis_decision_memory','thesis_reactivation_rules','thesis_reactivation_events'
        )
        and c.relrowsecurity=false
    )
    and (select count(*) from fwios.decision_policy_regression_runs
      where policy_version_id='POL-THESIS-MEMORY-V1')=15
    and not exists(select 1 from fwios.decision_policy_regression_runs
      where policy_version_id='POL-THESIS-MEMORY-V1' and status<>'PASS')
)
select test_id,case when passed then 'PASS' else 'FAIL' end status
from tests
order by test_id;
