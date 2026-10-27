-- FWIOS Quality Hardening Canonical Evidence v1
-- Post-production acceptance checks.
-- Assumes the authorized EOG/NFLX production refresh receipts described in the implementation receipt exist.

select 'QCE-01 policy active' as test_case,
  case when exists(
    select 1 from fwios.policy_versions
    where policy_version_id='POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1'
      and lifecycle_status='ACTIVE'
  ) then 'PASS' else 'FAIL' end as status

union all
select 'QCE-02 hardening thresholds unchanged',
  case when exists(
    select 1 from fwios.policy_versions
    where policy_version_id='POL-QUALITY-HARDENING-V1'
      and (config->>'bear_case_review_below')::numeric=-0.30
      and (config->>'bear_case_fail_below')::numeric=-0.50
      and (config->'owner_earnings'->>'sbc_pass_max')::numeric=0.10
      and (config->'owner_earnings'->>'sbc_hard_review_above')::numeric=0.20
      and (config->'owner_earnings'->>'sbc_fail_above')::numeric=0.30
  ) then 'PASS' else 'FAIL' end

union all
select 'QCE-03 EOG controlled receipt',
  case when exists(
    select 1 from fwios.research_ingest_receipts_v1
    where receipt_id='45a398e2-ac66-4ea9-a204-79747787ae40'::uuid
      and status='APPLIED' and evidence_inserted=1 and observations_inserted=2
  ) then 'PASS' else 'FAIL' end

union all
select 'QCE-04 NFLX controlled receipt',
  case when exists(
    select 1 from fwios.research_ingest_receipts_v1
    where receipt_id='92d634fe-4281-44a4-8177-9d9c0364c8be'::uuid
      and status='APPLIED' and evidence_inserted=2 and observations_inserted=5
  ) then 'PASS' else 'FAIL' end

union all
select 'QCE-05 EOG owner canonical PASS',
  case when
    fwios.preview_quality_hardening_canonical_evidence_v1('EOG')->'owner_earnings'->>'gate'='PASS'
    and (fwios.preview_quality_hardening_canonical_evidence_v1('EOG')->'owner_earnings'->>'sbc_to_revenue')::numeric < 0.10
  then 'PASS' else 'FAIL' end

union all
select 'QCE-06 NFLX durability canonical PASS',
  case when
    fwios.preview_quality_hardening_canonical_evidence_v1('NFLX')->'business_durability'->>'gate'='PASS'
    and (fwios.preview_quality_hardening_canonical_evidence_v1('NFLX')->'business_durability'->>'anchor_years')::integer>=3
  then 'PASS' else 'FAIL' end

union all
select 'QCE-07 NFLX owner canonical PASS',
  case when
    fwios.preview_quality_hardening_canonical_evidence_v1('NFLX')->'owner_earnings'->>'gate'='PASS'
    and (fwios.preview_quality_hardening_canonical_evidence_v1('NFLX')->'owner_earnings'->>'sbc_to_revenue')::numeric < 0.10
  then 'PASS' else 'FAIL' end

union all
select 'QCE-08 EOG final FAIL robustness',
  case when exists(
    select 1 from fwios.v_candidate_quality_hardening_current
    where ticker='EOG'
      and hardening_snapshot_id='HARD-QCE-EOG-20261026-8094977faaad'
      and business_durability_gate='PASS'
      and owner_earnings_gate='PASS'
      and valuation_robustness_gate='FAIL'
      and overall_gate='FAIL'
  ) then 'PASS' else 'FAIL' end

union all
select 'QCE-09 NFLX final REVIEW robustness',
  case when exists(
    select 1 from fwios.v_candidate_quality_hardening_current
    where ticker='NFLX'
      and hardening_snapshot_id='HARD-QCE-NFLX-20261026-2d4df8695276'
      and business_durability_gate='PASS'
      and owner_earnings_gate='PASS'
      and valuation_robustness_gate='REVIEW'
      and overall_gate='REVIEW'
  ) then 'PASS' else 'FAIL' end

union all
select 'QCE-10 no investment-review promotion',
  case when (
    select count(*)
    from fwios.v_research_readiness_current_v1
    where ticker in ('EOG','NFLX') and investment_review_ready
  )=0 then 'PASS' else 'FAIL' end

union all
select 'QCE-11 current valuation lineage',
  case when (
    select count(*)
    from fwios.v_research_readiness_current_v1
    where ticker in ('EOG','NFLX')
      and valuation_run_id=hardening_valuation_run_id
  )=2 then 'PASS' else 'FAIL' end

union all
select 'QCE-12 canonical hardening lineage present',
  case when (
    select count(*)
    from fwios.v_lineage_edges_resolved
    where to_object_key in (
      'HARD-QCE-EOG-20261026-8094977faaad',
      'HARD-QCE-NFLX-20261026-2d4df8695276'
    )
      and edge_type in ('EVIDENCE_SUPPORTS_HARDENING','METRIC_SUPPORTS_HARDENING')
  )>=12 then 'PASS' else 'FAIL' end

union all
select 'QCE-13 unauthorized apply blocked',
  case when
    fwios.apply_quality_hardening_canonical_refresh_v1('EOG',false)->>'status'='BLOCKED'
    and fwios.apply_quality_hardening_canonical_refresh_v1('EOG',false)->>'reason'='HUMAN_AUTHORIZATION_REQUIRED'
  then 'PASS' else 'FAIL' end

union all
select 'QCE-14 repeat apply idempotent',
  case when
    fwios.apply_quality_hardening_canonical_refresh_v1('EOG',true)->>'status'='NOOP_ALREADY_REFRESHED'
    and fwios.apply_quality_hardening_canonical_refresh_v1('NFLX',true)->>'status'='NOOP_ALREADY_REFRESHED'
  then 'PASS' else 'FAIL' end

union all
select 'QCE-15 service-role-only functions',
  case when
    has_function_privilege('service_role','fwios.preview_quality_hardening_canonical_evidence_v1(text)','EXECUTE')
    and has_function_privilege('service_role','fwios.preview_quality_hardening_canonical_refresh_v1(text)','EXECUTE')
    and has_function_privilege('service_role','fwios.apply_quality_hardening_canonical_refresh_v1(text,boolean)','EXECUTE')
    and not has_function_privilege('anon','fwios.preview_quality_hardening_canonical_evidence_v1(text)','EXECUTE')
    and not has_function_privilege('authenticated','fwios.preview_quality_hardening_canonical_evidence_v1(text)','EXECUTE')
    and not has_function_privilege('anon','fwios.apply_quality_hardening_canonical_refresh_v1(text,boolean)','EXECUTE')
    and not has_function_privilege('authenticated','fwios.apply_quality_hardening_canonical_refresh_v1(text,boolean)','EXECUTE')
  then 'PASS' else 'FAIL' end

union all
select 'QCE-16 safety flags',
  case when exists(
    select 1 from fwios.policy_versions
    where policy_version_id='POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1'
      and (config->>'portfolio_mutation')::boolean=false
      and (config->>'approval_mutation')::boolean=false
      and (config->>'execution_mutation')::boolean=false
      and (config->>'auto_trade')::boolean=false
      and (config->>'human_execution_only')::boolean=true
      and (config->>'shadow_evidence_direct_promotion')::boolean=false
  ) then 'PASS' else 'FAIL' end;
