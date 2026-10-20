-- PR4 Research Readiness & Fail-Closed Gates v1
-- Additive readiness layer only. Does not modify scanner v1, lifecycle state,
-- research facts, valuation outputs, portfolio accounting, approval, or execution.

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status,updated_at
) values (
  'RESEARCH_READINESS',
  'RESEARCH',
  'Research Readiness & Fail-Closed Gates v1',
  'Deterministically evaluate discovery, research, valuation, quality-hardening and investment-review readiness without mutating research, scoring, portfolio, approval or execution state.',
  'fwios.v_research_readiness_current_v1',
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
  'POL-RESEARCH-READINESS-V1',
  'RESEARCH_READINESS',
  '1.0',
  'ACTIVE',
  true,
  $json$
  {
    "research_max_age_days": 120,
    "valuation_max_age_days": 180,
    "hardening_max_age_days": 180,
    "price_max_age_days": 7,
    "primary_source_min_rank": 100,
    "accepted_price_verification_statuses": ["VERIFIED", "PRIMARY_ONLY"],
    "accepted_price_provenance_statuses": ["PASS"],
    "quality_hardening_requires_current_valuation_lineage": true,
    "scanner_score_requires_investment_review_ready": true,
    "production_read_cutover": false,
    "portfolio_mutation": false,
    "approval_mutation": false,
    "execution_mutation": false,
    "human_execution_only": true,
    "auto_trade": false
  }
  $json$::jsonb,
  'docs/implementation/PR4_RESEARCH_READINESS_FAIL_CLOSED_V1.md',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status=excluded.lifecycle_status,
  deterministic_scoring=excluded.deterministic_scoring,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

create or replace view fwios.v_research_readiness_current_v1
with (security_invoker = true)
as
with policy as (
  select (
    select pv.config
    from fwios.policy_versions pv
    where pv.policy_version_id='POL-RESEARCH-READINESS-V1'
      and pv.lifecycle_status='ACTIVE'
    limit 1
  ) as config
),
universe as (
  select
    i.instrument_id,
    i.asset_symbol as ticker
  from fwios.v_instrument_identity_current i
  where i.asset_class='Stock'
    and i.lifecycle_status='ACTIVE'
),
latest_receipt as (
  select distinct on (r.instrument_id)
    r.instrument_id,
    r.receipt_id,
    r.research_as_of,
    r.applied_at
  from fwios.research_ingest_receipts_v1 r
  where r.status='APPLIED'
  order by r.instrument_id, r.research_as_of desc, r.applied_at desc, r.receipt_id desc
),
evidence_stats as (
  select
    e.instrument_id,
    count(*)::integer as evidence_count,
    count(*) filter (
      where upper(coalesce(e.verification_status,'')) in ('VERIFIED','PASS')
    )::integer as verified_evidence_count,
    count(*) filter (
      where upper(coalesce(e.verification_status,'')) in ('VERIFIED','PASS')
        and fwios.research_source_tier_rank_v1(e.source_tier)
          >= coalesce((p.config->>'primary_source_min_rank')::integer,100)
    )::integer as primary_verified_evidence_count,
    count(*) filter (
      where upper(coalesce(e.conflict_status,'NONE')) not in
        ('NO','PASS','NO_CONFLICT','NONE','RESOLVED_BY_EXPLICIT_USD_TABLE')
    )::integer as conflicting_evidence_count,
    count(*) filter (
      where upper(coalesce(e.freshness_status,'')) in ('STALE','EXPIRED','FAIL','BLOCKED')
    )::integer as stale_evidence_count,
    max(e.created_at) as latest_evidence_at
  from fwios.evidence_records e
  cross join policy p
  where e.instrument_id is not null
  group by e.instrument_id
),
latest_valuation as (
  select distinct on (v.ticker)
    v.ticker,
    v.run_id,
    v.valuation_readiness,
    v.router_gate,
    v.valuation_gate,
    v.schema_gate,
    v.model_decision,
    v.production_eligible,
    v.created_at
  from fwios.valuation_runs v
  order by v.ticker, v.created_at desc, v.run_id desc
),
base as (
  select
    u.instrument_id,
    u.ticker,
    p.config,
    rc.ticker as research_candidate_ticker,
    rc.evidence_gate,
    rc.evidence_pass_count,
    rc.as_of_date as legacy_research_as_of,
    rc.updated_at as legacy_research_updated_at,
    lr.receipt_id as latest_research_receipt_id,
    lr.research_as_of as receipt_research_as_of,
    lr.applied_at as receipt_applied_at,
    coalesce(es.evidence_count,0) as evidence_count,
    coalesce(es.verified_evidence_count,0) as verified_evidence_count,
    coalesce(es.primary_verified_evidence_count,0) as primary_verified_evidence_count,
    coalesce(es.conflicting_evidence_count,0) as conflicting_evidence_count,
    coalesce(es.stale_evidence_count,0) as stale_evidence_count,
    es.latest_evidence_at,
    lv.run_id as valuation_run_id,
    lv.valuation_readiness as valuation_readiness_raw,
    lv.router_gate,
    lv.valuation_gate,
    lv.schema_gate,
    lv.model_decision,
    lv.production_eligible,
    lv.created_at as valuation_as_of,
    h.hardening_snapshot_id,
    h.valuation_run_id as hardening_valuation_run_id,
    h.overall_gate as hardening_gate_raw,
    h.valuation_confidence,
    h.created_at as hardening_as_of,
    dc.close_price as latest_price,
    dc.session_date as price_as_of,
    dc.verification_status as price_verification_status,
    dc.provenance_status as price_provenance_status,
    dc.retrieved_at as price_retrieved_at
  from universe u
  cross join policy p
  left join fwios.research_candidates rc on rc.instrument_id=u.instrument_id
  left join latest_receipt lr on lr.instrument_id=u.instrument_id
  left join evidence_stats es on es.instrument_id=u.instrument_id
  left join latest_valuation lv on lv.ticker=u.ticker
  left join fwios.v_candidate_quality_hardening_current h on h.ticker=u.ticker
  left join fwios.v_market_daily_close_latest dc on dc.asset_symbol=u.ticker
),
derived as (
  select
    b.*,
    (b.config is not null) as policy_active,
    (b.research_candidate_ticker is not null or b.latest_research_receipt_id is not null) as research_attempted,
    greatest(
      b.legacy_research_as_of,
      b.receipt_research_as_of::date,
      b.latest_evidence_at::date
    ) as research_as_of,
    (
      b.config is not null
      and b.latest_price is not null
      and b.latest_price > 0
      and (b.config->'accepted_price_verification_statuses') ? upper(coalesce(b.price_verification_status,''))
      and (b.config->'accepted_price_provenance_statuses') ? upper(coalesce(b.price_provenance_status,''))
      and b.price_as_of is not null
      and b.price_as_of >= current_date - coalesce((b.config->>'price_max_age_days')::integer,0)
    ) as price_ready
  from base b
),
research_flags as (
  select
    d.*,
    d.policy_active as discovery_ready,
    (
      d.policy_active
      and d.research_attempted
      and d.evidence_count > 0
      and d.primary_verified_evidence_count > 0
      and d.conflicting_evidence_count = 0
      and d.stale_evidence_count = 0
      and d.research_as_of is not null
      and d.research_as_of >= current_date - coalesce((d.config->>'research_max_age_days')::integer,0)
      and (
        d.research_candidate_ticker is null
        or upper(coalesce(d.evidence_gate,''))='PASS'
      )
    ) as research_ready
  from derived d
),
valuation_flags as (
  select
    r.*,
    (
      r.research_ready
      and r.valuation_run_id is not null
      and upper(coalesce(r.valuation_readiness_raw,'')) in ('PASS','READY')
      and upper(coalesce(r.router_gate,''))='PASS'
      and upper(coalesce(r.valuation_gate,''))='PASS'
      and upper(coalesce(r.schema_gate,''))='PASS'
      and coalesce(r.production_eligible,false)
      and r.valuation_as_of >= now() - make_interval(days => coalesce((r.config->>'valuation_max_age_days')::integer,0))
    ) as valuation_ready
  from research_flags r
),
quality_flags as (
  select
    v.*,
    (
      v.valuation_ready
      and v.hardening_snapshot_id is not null
      and upper(coalesce(v.hardening_gate_raw,''))='PASS'
      and v.hardening_valuation_run_id=v.valuation_run_id
      and v.hardening_as_of >= now() - make_interval(days => coalesce((v.config->>'hardening_max_age_days')::integer,0))
    ) as quality_hardened
  from valuation_flags v
),
ready as (
  select
    q.*,
    (q.quality_hardened and q.price_ready) as investment_review_ready
  from quality_flags q
),
with_blockers as (
  select
    r.*,
    array_remove(array[
      case when not r.policy_active then 'READINESS_POLICY_NOT_ACTIVE' end,
      case when r.policy_active and r.research_attempted and r.conflicting_evidence_count > 0
        then 'CONFLICTING_EVIDENCE' end,
      case when r.policy_active and r.research_attempted and r.primary_verified_evidence_count = 0
        then 'MISSING_PRIMARY_EVIDENCE' end,
      case when r.policy_active and r.research_attempted and (
          r.stale_evidence_count > 0
          or r.research_as_of is null
          or r.research_as_of < current_date - coalesce((r.config->>'research_max_age_days')::integer,0)
        ) then 'STALE_RESEARCH' end,
      case when r.policy_active and not r.research_ready
             and r.conflicting_evidence_count = 0
             and (not r.research_attempted or r.primary_verified_evidence_count > 0)
             and r.stale_evidence_count = 0
             and (not r.research_attempted or r.research_as_of is not null)
        then 'RESEARCH_NOT_READY' end,
      case when r.policy_active and r.research_ready and not r.valuation_ready
        then 'VALUATION_BLOCKED' end,
      case when r.policy_active and r.valuation_ready and not r.quality_hardened
        then 'QUALITY_HARDENING_FAIL' end,
      case when r.policy_active and not r.price_ready
        then 'PRICE_NOT_VERIFIED' end
    ]::text[], null) as blocking_reasons
  from ready r
)
select
  instrument_id,
  ticker,
  discovery_ready,
  research_ready,
  valuation_ready,
  quality_hardened,
  investment_review_ready,
  case
    when investment_review_ready then 'INVESTMENT_REVIEW_READY'
    when quality_hardened then 'QUALITY_HARDENED'
    when valuation_ready then 'VALUATION_READY'
    when research_ready then 'RESEARCH_READY'
    when discovery_ready then 'DISCOVERY_READY'
    else 'BLOCKED'
  end as readiness_state,
  case when research_ready then 'READY' else 'BLOCKED' end as research_readiness,
  research_as_of,
  case when valuation_ready then 'READY' else 'BLOCKED' end as valuation_readiness,
  valuation_as_of,
  case
    when quality_hardened then 'PASS'
    when hardening_snapshot_id is null then 'MISSING'
    when hardening_valuation_run_id is distinct from valuation_run_id then 'STALE'
    else coalesce(hardening_gate_raw,'BLOCKED')
  end as quality_hardening,
  valuation_confidence,
  case when investment_review_ready then 'READY' else 'BLOCKED' end as investment_review_status,
  blocking_reasons[1] as blocking_reason,
  blocking_reasons,
  investment_review_ready as scanner_score_eligible,
  price_ready,
  latest_price,
  price_as_of,
  price_verification_status,
  price_provenance_status,
  evidence_gate,
  evidence_pass_count,
  evidence_count,
  verified_evidence_count,
  primary_verified_evidence_count,
  conflicting_evidence_count,
  stale_evidence_count,
  latest_research_receipt_id,
  valuation_run_id,
  hardening_snapshot_id,
  hardening_gate_raw,
  hardening_valuation_run_id,
  policy_active,
  'POL-RESEARCH-READINESS-V1'::text as readiness_policy_id
from with_blockers;

comment on view fwios.v_research_readiness_current_v1 is
  'Additive deterministic PR4 readiness surface. Scanner v1 is unchanged; PR5 must null score/rank unless scanner_score_eligible=true.';

revoke all on fwios.v_research_readiness_current_v1 from public,anon,authenticated;
grant select on fwios.v_research_readiness_current_v1 to service_role;
