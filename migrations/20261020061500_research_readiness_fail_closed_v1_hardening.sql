-- PR4 Research Readiness v1 hardening
-- Fixes review findings without changing Scanner v1 or any mutable investment state.
-- 1) Controlled-ingest readiness requires evidence + canonical metrics with a fresh source-period date.
-- 2) Valuation readiness selects the latest production-eligible valuation run.
-- 3) Lifecycle gating is explicitly deferred while POL-RESEARCH-LIFECYCLE-V1 has no production read cutover.

update fwios.policy_versions
set config = config || $json$
{
  "controlled_receipt_requires_metric": true,
  "controlled_receipt_requires_fresh_metric": true,
  "controlled_research_freshness_source": "METRIC_REPORTED_AS_OF_OR_PERIOD_END",
  "legacy_research_freshness_source": "RESEARCH_CANDIDATE_AS_OF_DATE",
  "lifecycle_gate_enforced": false,
  "lifecycle_gate_reason": "POL-RESEARCH-LIFECYCLE-V1_NO_PRODUCTION_READ_CUTOVER"
}
$json$::jsonb,
source_reference='docs/implementation/PR4_RESEARCH_READINESS_FAIL_CLOSED_V1.md; PR4 readiness hardening'
where policy_version_id='POL-RESEARCH-READINESS-V1';

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
  select i.instrument_id, i.asset_symbol as ticker
  from fwios.v_instrument_identity_current i
  where i.asset_class='Stock' and i.lifecycle_status='ACTIVE'
),
latest_receipt as (
  select distinct on (r.instrument_id)
    r.instrument_id,
    r.receipt_id,
    r.research_as_of,
    r.applied_at,
    case when jsonb_typeof(r.payload->'evidence')='array'
      then jsonb_array_length(r.payload->'evidence') else 0 end as receipt_evidence_count,
    case when jsonb_typeof(r.payload->'metrics')='array'
      then jsonb_array_length(r.payload->'metrics') else 0 end as receipt_metric_count,
    (
      select count(*)::integer
      from jsonb_array_elements(
        case when jsonb_typeof(r.payload->'evidence')='array'
          then r.payload->'evidence' else '[]'::jsonb end
      ) e(value)
      where upper(coalesce(e.value->>'verification_status','')) in ('VERIFIED','PASS')
        and fwios.research_source_tier_rank_v1(e.value->>'source_tier')
            >= coalesce((p.config->>'primary_source_min_rank')::integer,100)
    ) as receipt_primary_verified_evidence_count,
    (
      select count(*)::integer
      from (
        select greatest(
          fwios.research_try_timestamptz_v1(m.value->>'reported_at')::date,
          fwios.research_try_date_v1(m.value->>'as_of_date'),
          fwios.research_try_date_v1(m.value->>'period_end')
        ) as metric_date
        from jsonb_array_elements(
          case when jsonb_typeof(r.payload->'metrics')='array'
            then r.payload->'metrics' else '[]'::jsonb end
        ) m(value)
      ) x
      where x.metric_date is not null
        and x.metric_date <= current_date + 1
        and x.metric_date >= current_date - coalesce((p.config->>'research_max_age_days')::integer,0)
    ) as receipt_fresh_metric_count,
    (
      select max(greatest(
        fwios.research_try_timestamptz_v1(m.value->>'reported_at')::date,
        fwios.research_try_date_v1(m.value->>'as_of_date'),
        fwios.research_try_date_v1(m.value->>'period_end')
      ))
      from jsonb_array_elements(
        case when jsonb_typeof(r.payload->'metrics')='array'
          then r.payload->'metrics' else '[]'::jsonb end
      ) m(value)
    ) as receipt_metric_data_as_of
  from fwios.research_ingest_receipts_v1 r
  cross join policy p
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
  where v.production_eligible=true
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
    coalesce(lr.receipt_evidence_count,0) as receipt_evidence_count,
    coalesce(lr.receipt_metric_count,0) as receipt_metric_count,
    coalesce(lr.receipt_primary_verified_evidence_count,0) as receipt_primary_verified_evidence_count,
    coalesce(lr.receipt_fresh_metric_count,0) as receipt_fresh_metric_count,
    lr.receipt_metric_data_as_of,
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
      case when b.research_candidate_ticker is not null then b.legacy_research_as_of end,
      case when b.latest_research_receipt_id is not null then b.receipt_metric_data_as_of end
    ) as research_as_of,
    (
      b.config is not null
      and b.research_candidate_ticker is not null
      and upper(coalesce(b.evidence_gate,''))='PASS'
      and b.evidence_count > 0
      and b.primary_verified_evidence_count > 0
      and b.conflicting_evidence_count = 0
      and b.stale_evidence_count = 0
      and b.legacy_research_as_of is not null
      and b.legacy_research_as_of >= current_date - coalesce((b.config->>'research_max_age_days')::integer,0)
    ) as legacy_research_ready,
    (
      b.config is not null
      and b.latest_research_receipt_id is not null
      and b.receipt_evidence_count > 0
      and b.receipt_metric_count > 0
      and b.receipt_primary_verified_evidence_count > 0
      and b.receipt_fresh_metric_count > 0
      and b.receipt_metric_data_as_of is not null
      and b.receipt_metric_data_as_of >= current_date - coalesce((b.config->>'research_max_age_days')::integer,0)
    ) as controlled_research_ready,
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
  select d.*, d.policy_active as discovery_ready,
         (d.legacy_research_ready or d.controlled_research_ready) as research_ready
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
  select q.*, (q.quality_hardened and q.price_ready) as investment_review_ready
  from quality_flags q
),
with_blockers as (
  select
    r.*,
    array_remove(array[
      case when not r.policy_active then 'READINESS_POLICY_NOT_ACTIVE' end,
      case when r.policy_active and not r.research_ready and r.research_candidate_ticker is not null
                and r.conflicting_evidence_count > 0
        then 'CONFLICTING_EVIDENCE' end,
      case when r.policy_active and not r.research_ready and r.research_attempted
                and (
                  (r.research_candidate_ticker is null or r.primary_verified_evidence_count=0)
                  and (r.latest_research_receipt_id is null or r.receipt_primary_verified_evidence_count=0)
                )
        then 'MISSING_PRIMARY_EVIDENCE' end,
      case when r.policy_active and not r.research_ready and r.research_attempted
                and (
                  (r.research_candidate_ticker is not null and (
                    r.stale_evidence_count > 0
                    or r.legacy_research_as_of is null
                    or r.legacy_research_as_of < current_date - coalesce((r.config->>'research_max_age_days')::integer,0)
                  ))
                  or
                  (r.latest_research_receipt_id is not null and r.receipt_metric_count > 0 and (
                    r.receipt_metric_data_as_of is null
                    or r.receipt_fresh_metric_count=0
                  ))
                )
        then 'STALE_RESEARCH' end,
      case when r.policy_active and not r.research_ready then 'RESEARCH_NOT_READY' end,
      case when r.policy_active and r.research_ready and not r.valuation_ready then 'VALUATION_BLOCKED' end,
      case when r.policy_active and r.valuation_ready and not r.quality_hardened then 'QUALITY_HARDENING_FAIL' end,
      case when r.policy_active and not r.price_ready then 'PRICE_NOT_VERIFIED' end
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
  'POL-RESEARCH-READINESS-V1'::text as readiness_policy_id,
  case
    when legacy_research_ready and controlled_research_ready then 'LEGACY_AND_CONTROLLED'
    when controlled_research_ready then 'CONTROLLED_GATEWAY'
    when legacy_research_ready then 'LEGACY_CANDIDATE'
    when latest_research_receipt_id is not null then 'CONTROLLED_INCOMPLETE'
    when research_candidate_ticker is not null then 'LEGACY_INCOMPLETE'
    else 'NONE'
  end as research_route,
  receipt_evidence_count as controlled_receipt_evidence_count,
  receipt_metric_count as controlled_receipt_metric_count,
  receipt_primary_verified_evidence_count as controlled_receipt_primary_verified_evidence_count,
  receipt_fresh_metric_count as controlled_receipt_fresh_metric_count,
  receipt_metric_data_as_of as controlled_receipt_metric_data_as_of,
  legacy_research_ready,
  controlled_research_ready,
  false as lifecycle_gate_enforced,
  'DEFERRED_NO_PRODUCTION_READ_CUTOVER'::text as lifecycle_gate_status
from with_blockers;

comment on view fwios.v_research_readiness_current_v1 is
  'PR4 additive deterministic readiness surface. Controlled research requires validated evidence plus at least one fresh canonical metric; valuation selects latest production-eligible run. Lifecycle gate remains explicitly deferred until lifecycle production read cutover. Scanner v1 remains unchanged.';

revoke all on fwios.v_research_readiness_current_v1 from public,anon,authenticated;
grant select on fwios.v_research_readiness_current_v1 to service_role;
