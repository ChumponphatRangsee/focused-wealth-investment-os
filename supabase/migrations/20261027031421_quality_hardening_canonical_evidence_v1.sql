-- FWIOS Quality Hardening Canonical Evidence v1
-- Live migration: 20261027031421_quality_hardening_canonical_evidence_v1
-- Additive/fail-closed. Does not retune POL-QUALITY-HARDENING-V1.

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status
) values (
  'QUALITY_HARDENING_CANONICAL_EVIDENCE',
  'decision_intelligence',
  'Quality Hardening Canonical Evidence v1',
  'Resolve Quality Hardening Business Durability and Owner Earnings from canonical Tier-A verified metrics, while preserving fail-closed price-sensitive gates.',
  'fwios.preview_quality_hardening_canonical_evidence_v1 / fwios.preview_quality_hardening_canonical_refresh_v1 / fwios.apply_quality_hardening_canonical_refresh_v1',
  'ACTIVE'
)
on conflict(policy_key) do update set
  policy_domain=excluded.policy_domain,
  policy_name=excluded.policy_name,
  purpose=excluded.purpose,
  backing_object=excluded.backing_object,
  lifecycle_status=excluded.lifecycle_status,
  updated_at=now();

insert into fwios.policy_versions(
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,
  config,source_reference,effective_at
) values (
  'POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1',
  'QUALITY_HARDENING_CANONICAL_EVIDENCE',
  '1.0','ACTIVE',true,
  jsonb_build_object(
    'hardening_policy_id','POL-QUALITY-HARDENING-V1',
    'base_refresh_policy_id','POL-QUALITY-HARDENING-REFRESH-V1',
    'canonical_metric_table','fwios.metric_observations',
    'canonical_evidence_table','fwios.evidence_records',
    'durability_metric','REVENUE',
    'durability_min_years_inherited',true,
    'owner_earnings_metrics',jsonb_build_array('REVENUE','SHARE_BASED_COMPENSATION','FREE_CASH_FLOW'),
    'tier_a_verified_required',true,
    'same_period_revenue_sbc_required',true,
    'positive_verified_fcf_required_for_clean_pass',true,
    'sbc_thresholds_inherited',true,
    'shadow_evidence_direct_promotion',false,
    'human_authorization_required_for_apply',true,
    'portfolio_mutation',false,
    'approval_mutation',false,
    'execution_mutation',false,
    'auto_trade',false,
    'human_execution_only',true
  ),
  'FWIOS Quality Hardening Canonical Evidence v1',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status=excluded.lifecycle_status,
  deterministic_scoring=excluded.deterministic_scoring,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

CREATE OR REPLACE FUNCTION fwios.preview_quality_hardening_canonical_evidence_v1(p_ticker text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
declare
  v_ticker text := upper(btrim(coalesce(p_ticker,'')));
  v_instrument_id uuid;
  v_hardening_policy jsonb;
  v_readiness_policy jsonb;
  v_research_max_age_days integer;
  v_durability_min_years integer;
  v_sbc_pass_max numeric;
  v_sbc_hard_review_above numeric;
  v_sbc_fail_above numeric;

  v_annual_count integer := 0;
  v_annual_latest_year integer;
  v_annual_earliest_of_latest integer;
  v_annual_evidence_ids text[];
  v_annual_observation_ids uuid[];
  v_business_gate text := 'BLOCKED';
  v_durability_anchor_years integer := 0;
  v_durability_evidence_count integer := 0;

  v_owner_revenue_obs fwios.metric_observations%rowtype;
  v_owner_sbc_obs fwios.metric_observations%rowtype;
  v_owner_fcf_obs fwios.metric_observations%rowtype;
  v_owner_revenue_evidence text;
  v_owner_sbc_evidence text;
  v_owner_fcf_evidence text;
  v_sbc_to_revenue numeric;
  v_owner_gate text := 'BLOCKED';
  v_owner_fcf_conversion_pass boolean := false;
  v_dilution_reconciliation_required boolean := false;
  v_dilution_reconciliation_pass boolean;
begin
  if v_ticker='' then
    return jsonb_build_object('status','BLOCKED','reason','TICKER_REQUIRED');
  end if;

  v_instrument_id := fwios.resolve_instrument_id_v1(v_ticker,'Stock',null,null);
  if v_instrument_id is null then
    return jsonb_build_object('status','BLOCKED','reason','TICKER_NOT_RESOLVED_TO_ACTIVE_STOCK_INSTRUMENT','ticker',v_ticker);
  end if;

  select config into v_hardening_policy
  from fwios.policy_versions
  where policy_version_id='POL-QUALITY-HARDENING-V1'
    and lifecycle_status='ACTIVE';

  select config into v_readiness_policy
  from fwios.policy_versions
  where policy_version_id='POL-RESEARCH-READINESS-V1'
    and lifecycle_status='ACTIVE';

  if v_hardening_policy is null or v_readiness_policy is null then
    return jsonb_build_object('status','BLOCKED','reason','REQUIRED_POLICY_NOT_ACTIVE','ticker',v_ticker);
  end if;

  v_research_max_age_days := (v_readiness_policy->>'research_max_age_days')::integer;
  v_durability_min_years := (v_hardening_policy->>'durability_anchor_min_years')::integer;
  v_sbc_pass_max := (v_hardening_policy->'owner_earnings'->>'sbc_pass_max')::numeric;
  v_sbc_hard_review_above := (v_hardening_policy->'owner_earnings'->>'sbc_hard_review_above')::numeric;
  v_sbc_fail_above := (v_hardening_policy->'owner_earnings'->>'sbc_fail_above')::numeric;

  with annual as (
    select distinct on (o.fiscal_year)
      o.fiscal_year,o.observation_id,o.primary_evidence_id,o.value_numeric,o.reported_at
    from fwios.metric_observations o
    join fwios.evidence_records e on e.evidence_id=o.primary_evidence_id
    where o.instrument_id=v_instrument_id
      and o.metric_code='REVENUE'
      and o.period_type='YEAR'
      and o.fiscal_year is not null
      and o.value_numeric is not null
      and o.value_numeric>0
      and o.provenance_status='PASS'
      and o.quality_gate='PASS'
      and upper(coalesce(e.source_tier,''))='A'
      and upper(coalesce(e.verification_status,'')) in ('VERIFIED','PASS')
      and upper(coalesce(e.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','')
      and e.source_url is not null
    order by o.fiscal_year desc,o.reported_at desc nulls last,o.created_at desc
  ), latest_years as (
    select *
    from annual
    order by fiscal_year desc
    limit greatest(v_durability_min_years,3)
  )
  select count(*),
         max(fiscal_year),
         min(fiscal_year),
         array_agg(distinct primary_evidence_id order by primary_evidence_id),
         array_agg(observation_id order by fiscal_year)
    into v_annual_count,v_annual_latest_year,v_annual_earliest_of_latest,
         v_annual_evidence_ids,v_annual_observation_ids
  from latest_years;

  if v_annual_count>=v_durability_min_years
     and v_annual_latest_year is not null
     and v_annual_latest_year >= extract(year from current_date)::integer-1
     and v_annual_latest_year-v_annual_earliest_of_latest=v_annual_count-1
  then
    v_business_gate := 'PASS';
    v_durability_anchor_years := v_annual_count;
    v_durability_evidence_count := coalesce(cardinality(v_annual_evidence_ids),0);
  end if;

  select r.*
    into v_owner_revenue_obs
  from fwios.metric_observations r
  join fwios.evidence_records re on re.evidence_id=r.primary_evidence_id
  where r.instrument_id=v_instrument_id
    and r.metric_code='REVENUE'
    and r.value_numeric>0
    and r.period_type in ('YTD','QUARTER','YEAR','LTM')
    and r.provenance_status='PASS'
    and r.quality_gate='PASS'
    and r.reported_at >= now()-make_interval(days=>v_research_max_age_days)
    and upper(coalesce(re.source_tier,''))='A'
    and upper(coalesce(re.verification_status,'')) in ('VERIFIED','PASS')
    and upper(coalesce(re.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','')
    and exists (
      select 1
      from fwios.metric_observations s
      join fwios.evidence_records se on se.evidence_id=s.primary_evidence_id
      where s.instrument_id=r.instrument_id
        and s.metric_code='SHARE_BASED_COMPENSATION'
        and s.value_numeric is not null
        and s.value_numeric>=0
        and s.period_type=r.period_type
        and s.period_start is not distinct from r.period_start
        and s.period_end is not distinct from r.period_end
        and s.fiscal_year is not distinct from r.fiscal_year
        and s.fiscal_quarter is not distinct from r.fiscal_quarter
        and s.provenance_status='PASS'
        and s.quality_gate='PASS'
        and upper(coalesce(se.source_tier,''))='A'
        and upper(coalesce(se.verification_status,'')) in ('VERIFIED','PASS')
        and upper(coalesce(se.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','')
    )
  order by coalesce(r.period_end,r.as_of_date,r.reported_at::date) desc,
           r.reported_at desc nulls last,r.created_at desc
  limit 1;

  if found then
    select s.*
      into v_owner_sbc_obs
    from fwios.metric_observations s
    join fwios.evidence_records se on se.evidence_id=s.primary_evidence_id
    where s.instrument_id=v_instrument_id
      and s.metric_code='SHARE_BASED_COMPENSATION'
      and s.value_numeric is not null
      and s.value_numeric>=0
      and s.period_type=v_owner_revenue_obs.period_type
      and s.period_start is not distinct from v_owner_revenue_obs.period_start
      and s.period_end is not distinct from v_owner_revenue_obs.period_end
      and s.fiscal_year is not distinct from v_owner_revenue_obs.fiscal_year
      and s.fiscal_quarter is not distinct from v_owner_revenue_obs.fiscal_quarter
      and s.provenance_status='PASS'
      and s.quality_gate='PASS'
      and upper(coalesce(se.source_tier,''))='A'
      and upper(coalesce(se.verification_status,'')) in ('VERIFIED','PASS')
      and upper(coalesce(se.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','')
    order by s.reported_at desc nulls last,s.created_at desc
    limit 1;

    v_sbc_to_revenue := v_owner_sbc_obs.value_numeric/v_owner_revenue_obs.value_numeric;
    v_owner_revenue_evidence := v_owner_revenue_obs.primary_evidence_id;
    v_owner_sbc_evidence := v_owner_sbc_obs.primary_evidence_id;
  end if;

  select f.*
    into v_owner_fcf_obs
  from fwios.metric_observations f
  join fwios.evidence_records fe on fe.evidence_id=f.primary_evidence_id
  where f.instrument_id=v_instrument_id
    and f.metric_code='FREE_CASH_FLOW'
    and f.value_numeric is not null
    and f.value_numeric>0
    and f.provenance_status='PASS'
    and f.quality_gate='PASS'
    and f.reported_at >= now()-make_interval(days=>v_research_max_age_days)
    and upper(coalesce(fe.source_tier,''))='A'
    and upper(coalesce(fe.verification_status,'')) in ('VERIFIED','PASS')
    and upper(coalesce(fe.conflict_status,'')) in ('NO','NO_CONFLICT','NONE','')
    and fe.source_url is not null
  order by coalesce(f.period_end,f.as_of_date,f.reported_at::date) desc,
           f.reported_at desc nulls last,f.created_at desc
  limit 1;

  if found then
    v_owner_fcf_conversion_pass := true;
    v_owner_fcf_evidence := v_owner_fcf_obs.primary_evidence_id;
  end if;

  if v_sbc_to_revenue is not null then
    v_dilution_reconciliation_required := v_sbc_to_revenue>v_sbc_pass_max;
    v_dilution_reconciliation_pass := case
      when not v_dilution_reconciliation_required then true
      else null
    end;

    v_owner_gate := case
      when not v_owner_fcf_conversion_pass then 'BLOCKED'
      when v_sbc_to_revenue>v_sbc_fail_above then 'FAIL'
      when v_sbc_to_revenue>v_sbc_hard_review_above then 'REVIEW'
      when v_sbc_to_revenue>v_sbc_pass_max then 'BLOCKED'
      else 'PASS'
    end;
  end if;

  return jsonb_build_object(
    'status','PASS',
    'ticker',v_ticker,
    'instrument_id',v_instrument_id,
    'business_durability',jsonb_build_object(
      'gate',v_business_gate,
      'anchor_years',v_durability_anchor_years,
      'evidence_count',v_durability_evidence_count,
      'growth_anchor_verified',v_business_gate='PASS',
      'annual_revenue_observation_ids',coalesce(to_jsonb(v_annual_observation_ids),'[]'::jsonb),
      'annual_revenue_evidence_ids',coalesce(to_jsonb(v_annual_evidence_ids),'[]'::jsonb)
    ),
    'owner_earnings',jsonb_build_object(
      'gate',v_owner_gate,
      'sbc_to_revenue',v_sbc_to_revenue,
      'dilution_reconciliation_required',v_dilution_reconciliation_required,
      'dilution_reconciliation_pass',v_dilution_reconciliation_pass,
      'owner_fcf_conversion_pass',v_owner_fcf_conversion_pass,
      'revenue_observation_id',v_owner_revenue_obs.observation_id,
      'sbc_observation_id',v_owner_sbc_obs.observation_id,
      'fcf_observation_id',v_owner_fcf_obs.observation_id,
      'revenue_evidence_id',v_owner_revenue_evidence,
      'sbc_evidence_id',v_owner_sbc_evidence,
      'fcf_evidence_id',v_owner_fcf_evidence,
      'period_type',v_owner_revenue_obs.period_type,
      'period_start',v_owner_revenue_obs.period_start,
      'period_end',v_owner_revenue_obs.period_end
    ),
    'policy_version_id','POL-QUALITY-HARDENING-V1',
    'production_changes','NONE'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION fwios.preview_quality_hardening_canonical_refresh_v1(p_ticker text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
declare
  v_ticker text := upper(btrim(coalesce(p_ticker,'')));
  v_base jsonb;
  v_canonical jsonb;
  v_prior fwios.candidate_quality_hardening_snapshots%rowtype;
  v_hardening_policy jsonb;
  v_business_gate text;
  v_owner_gate text;
  v_value_trap_gate text;
  v_robustness_gate text;
  v_overall_gate text;
  v_confidence numeric;
  v_ratio numeric;
  v_sbc_pass_max numeric;
  v_sbc_hard_review_above numeric;
  v_sbc_fail_above numeric;
  v_fcf_pass boolean;
  v_effective_durability_years integer;
  v_effective_durability_evidence_count integer;
  v_effective_growth_anchor_verified boolean;
  v_effective_dilution_reconciliation_pass boolean;
  v_effective_owner_fcf_conversion_pass boolean;
  v_fingerprint text;
  v_hardening_snapshot_id text;
begin
  v_base := fwios.preview_quality_hardening_refresh_v1(v_ticker);
  if coalesce(v_base->>'refresh_status','BLOCKED')<>'READY_TO_APPLY' then
    return jsonb_build_object(
      'refresh_status','BLOCKED',
      'reason','BASE_REFRESH_NOT_READY',
      'base_refresh',v_base,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  v_canonical := fwios.preview_quality_hardening_canonical_evidence_v1(v_ticker);
  if coalesce(v_canonical->>'status','BLOCKED')<>'PASS' then
    return jsonb_build_object(
      'refresh_status','BLOCKED',
      'reason','CANONICAL_EVIDENCE_RESOLVER_NOT_READY',
      'ticker',v_ticker,
      'canonical_evidence',v_canonical,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  select * into v_prior
  from fwios.candidate_quality_hardening_snapshots
  where ticker=v_ticker
  order by created_at desc,hardening_snapshot_id desc
  limit 1;

  select config into v_hardening_policy
  from fwios.policy_versions
  where policy_version_id='POL-QUALITY-HARDENING-V1'
    and lifecycle_status='ACTIVE';

  if v_hardening_policy is null then
    return jsonb_build_object(
      'refresh_status','BLOCKED',
      'reason','HARDENING_POLICY_NOT_ACTIVE',
      'ticker',v_ticker,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  v_sbc_pass_max := (v_hardening_policy->'owner_earnings'->>'sbc_pass_max')::numeric;
  v_sbc_hard_review_above := (v_hardening_policy->'owner_earnings'->>'sbc_hard_review_above')::numeric;
  v_sbc_fail_above := (v_hardening_policy->'owner_earnings'->>'sbc_fail_above')::numeric;

  v_business_gate := v_base->'projected'->>'business_durability_gate';
  v_effective_durability_years := coalesce(v_prior.durability_anchor_years,0);
  v_effective_durability_evidence_count := coalesce(v_prior.durability_evidence_count,0);
  v_effective_growth_anchor_verified := coalesce(v_prior.growth_anchor_verified,false);

  if v_canonical->'business_durability'->>'gate'='PASS' then
    v_business_gate := 'PASS';
    v_effective_durability_years := coalesce((v_canonical->'business_durability'->>'anchor_years')::integer,0);
    v_effective_durability_evidence_count := coalesce((v_canonical->'business_durability'->>'evidence_count')::integer,0);
    v_effective_growth_anchor_verified := coalesce((v_canonical->'business_durability'->>'growth_anchor_verified')::boolean,false);
  end if;

  v_owner_gate := v_base->'projected'->>'owner_earnings_gate';
  v_ratio := nullif(v_canonical->'owner_earnings'->>'sbc_to_revenue','')::numeric;
  v_fcf_pass := coalesce((v_canonical->'owner_earnings'->>'owner_fcf_conversion_pass')::boolean,false);
  v_effective_dilution_reconciliation_pass := v_prior.dilution_reconciliation_pass;
  v_effective_owner_fcf_conversion_pass := v_prior.owner_fcf_conversion_pass;

  if v_ratio is not null then
    if v_ratio>v_sbc_fail_above then
      v_owner_gate := 'FAIL';
      v_effective_dilution_reconciliation_pass := false;
      v_effective_owner_fcf_conversion_pass := v_fcf_pass;
    elsif not v_fcf_pass then
      v_owner_gate := 'BLOCKED';
      v_effective_owner_fcf_conversion_pass := false;
    elsif v_ratio>v_sbc_hard_review_above then
      v_owner_gate := 'REVIEW';
      v_effective_owner_fcf_conversion_pass := true;
      v_effective_dilution_reconciliation_pass := coalesce(v_prior.dilution_reconciliation_pass,false);
    elsif v_ratio>v_sbc_pass_max then
      if coalesce(v_prior.dilution_reconciliation_pass,false)
         and coalesce(v_prior.owner_fcf_conversion_pass,false)
      then
        v_owner_gate := 'REVIEW';
        v_effective_dilution_reconciliation_pass := true;
        v_effective_owner_fcf_conversion_pass := true;
      else
        v_owner_gate := 'BLOCKED';
        v_effective_dilution_reconciliation_pass := false;
        v_effective_owner_fcf_conversion_pass := true;
      end if;
    else
      v_owner_gate := 'PASS';
      v_effective_dilution_reconciliation_pass := true;
      v_effective_owner_fcf_conversion_pass := true;
    end if;
  end if;

  v_value_trap_gate := v_base->'projected'->>'value_trap_gate';
  v_robustness_gate := v_base->'projected'->>'valuation_robustness_gate';

  v_overall_gate := fwios.quality_hardening_overall_gate_v1(
    v_business_gate,v_owner_gate,v_value_trap_gate,v_robustness_gate
  );
  v_confidence := fwios.valuation_confidence_v1(
    v_business_gate,v_owner_gate,v_value_trap_gate,v_robustness_gate
  );

  v_fingerprint := md5(
    coalesce(v_base->>'valuation_run_id','')||':'||
    coalesce(v_base->'price'->>'primary_observation_id','')||':'||
    coalesce(v_canonical::text,'{}')||':'||
    coalesce(v_business_gate,'')||':'||
    coalesce(v_owner_gate,'')||':'||
    coalesce(v_value_trap_gate,'')||':'||
    coalesce(v_robustness_gate,'')||':'||
    coalesce(v_effective_durability_years::text,'')||':'||
    coalesce(v_effective_durability_evidence_count::text,'')||':'||
    coalesce(v_effective_growth_anchor_verified::text,'')||':'||
    coalesce(v_effective_dilution_reconciliation_pass::text,'')||':'||
    coalesce(v_effective_owner_fcf_conversion_pass::text,'')||':'||
    coalesce(v_ratio::text,coalesce(v_prior.sbc_to_revenue::text,''))
  );
  v_hardening_snapshot_id :=
    'HARD-QCE-'||v_ticker||'-'||
    to_char((v_base->'price'->>'session_date')::date,'YYYYMMDD')||'-'||
    substr(v_fingerprint,1,12);

  return jsonb_build_object(
    'refresh_status','READY_TO_APPLY',
    'policy_version_id','POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1',
    'hardening_policy_id','POL-QUALITY-HARDENING-V1',
    'ticker',v_ticker,
    'valuation_run_id',v_base->>'valuation_run_id',
    'base_refresh',v_base,
    'canonical_evidence',v_canonical,
    'prior_hardening_snapshot_id',v_prior.hardening_snapshot_id,
    'effective_hardening_inputs',jsonb_build_object(
      'sbc_to_revenue',coalesce(v_ratio,v_prior.sbc_to_revenue),
      'durability_anchor_years',v_effective_durability_years,
      'durability_evidence_count',v_effective_durability_evidence_count,
      'dilution_reconciliation_pass',v_effective_dilution_reconciliation_pass,
      'owner_fcf_conversion_pass',v_effective_owner_fcf_conversion_pass,
      'growth_anchor_verified',v_effective_growth_anchor_verified,
      'counter_thesis_evidence_count',coalesce(v_prior.counter_thesis_evidence_count,0),
      'structural_risk_review_pass',v_prior.structural_risk_review_pass
    ),
    'projected',jsonb_build_object(
      'business_durability_gate',v_business_gate,
      'owner_earnings_gate',v_owner_gate,
      'value_trap_gate',v_value_trap_gate,
      'valuation_robustness_gate',v_robustness_gate,
      'overall_gate',v_overall_gate,
      'valuation_confidence',v_confidence,
      'extreme_mispricing_triggered',coalesce((v_base->'projected'->>'extreme_mispricing_triggered')::boolean,false)
    ),
    'proposed_ids',jsonb_build_object(
      'price_snapshot_id',v_base->'proposed_ids'->>'price_snapshot_id',
      'mispricing_snapshot_id',v_base->'proposed_ids'->>'mispricing_snapshot_id',
      'hardening_snapshot_id',v_hardening_snapshot_id
    ),
    'canonical_evidence_fingerprint',v_fingerprint,
    'shadow_evidence_used_for_production_gate',false,
    'human_authorization_required',true,
    'portfolio_mutation',false,
    'approval_mutation',false,
    'execution_mutation',false,
    'auto_trade',false,
    'production_changes','PREVIEW_NONE'
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION fwios.apply_quality_hardening_canonical_refresh_v1(p_ticker text, p_human_authorized boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
declare
  v_preview jsonb;
  v_base_apply jsonb;
  v_ticker text;
  v_valuation_run_id text;
  v_price_snapshot_id text;
  v_mispricing_snapshot_id text;
  v_hardening_snapshot_id text;
  v_existing fwios.candidate_quality_hardening_snapshots%rowtype;
  v_prior fwios.candidate_quality_hardening_snapshots%rowtype;
  v_instrument_id uuid;
  v_valuation_artifact_id uuid;
  v_hardening_artifact_id uuid;
  v_artifact_id uuid;
  v_id text;
  v_obs_id uuid;
  v_role text;
  v_evidence fwios.evidence_records%rowtype;
  v_observation fwios.metric_observations%rowtype;
begin
  if not coalesce(p_human_authorized,false) then
    return jsonb_build_object(
      'status','BLOCKED',
      'reason','HUMAN_AUTHORIZATION_REQUIRED',
      'production_changes','NONE',
      'auto_trade',false,
      'human_execution_only',true
    );
  end if;

  v_preview := fwios.preview_quality_hardening_canonical_refresh_v1(p_ticker);
  if coalesce(v_preview->>'refresh_status','BLOCKED')<>'READY_TO_APPLY' then
    return jsonb_build_object(
      'status','BLOCKED',
      'reason','CANONICAL_REFRESH_PREVIEW_NOT_READY',
      'preview',v_preview,
      'production_changes','NONE',
      'auto_trade',false,
      'human_execution_only',true
    );
  end if;

  v_ticker := v_preview->>'ticker';
  v_valuation_run_id := v_preview->>'valuation_run_id';
  v_price_snapshot_id := v_preview->'proposed_ids'->>'price_snapshot_id';
  v_mispricing_snapshot_id := v_preview->'proposed_ids'->>'mispricing_snapshot_id';
  v_hardening_snapshot_id := v_preview->'proposed_ids'->>'hardening_snapshot_id';

  select * into v_existing
  from fwios.candidate_quality_hardening_snapshots
  where hardening_snapshot_id=v_hardening_snapshot_id;

  if found then
    if v_existing.ticker=v_ticker and v_existing.valuation_run_id=v_valuation_run_id then
      return jsonb_build_object(
        'status','NOOP_ALREADY_REFRESHED',
        'ticker',v_ticker,
        'hardening_snapshot_id',v_hardening_snapshot_id,
        'overall_gate',v_existing.overall_gate,
        'production_changes','NONE',
        'auto_trade',false,
        'human_execution_only',true
      );
    end if;
    raise exception 'QUALITY_HARDENING_CANONICAL_REFRESH_ID_COLLISION';
  end if;

  v_base_apply := fwios.apply_quality_hardening_refresh_v1(v_ticker,true);
  if coalesce(v_base_apply->>'status','BLOCKED') not in ('APPLIED','NOOP_ALREADY_REFRESHED') then
    return jsonb_build_object(
      'status','BLOCKED',
      'reason','BASE_REFRESH_APPLY_NOT_READY',
      'base_apply',v_base_apply,
      'production_changes','NONE',
      'auto_trade',false,
      'human_execution_only',true
    );
  end if;

  if not exists(
    select 1 from fwios.valuation_mispricing_snapshots
    where mispricing_snapshot_id=v_mispricing_snapshot_id
      and valuation_run_id=v_valuation_run_id
  ) then
    raise exception 'QUALITY_HARDENING_CANONICAL_REFRESH_MISPRICING_MISSING';
  end if;

  select * into v_prior
  from fwios.candidate_quality_hardening_snapshots
  where ticker=v_ticker
  order by created_at desc,hardening_snapshot_id desc
  limit 1;

  v_instrument_id := (v_preview->'canonical_evidence'->>'instrument_id')::uuid;

  insert into fwios.candidate_quality_hardening_snapshots(
    hardening_snapshot_id,ticker,valuation_run_id,mispricing_snapshot_id,policy_version_id,
    business_durability_gate,owner_earnings_gate,value_trap_gate,valuation_robustness_gate,overall_gate,
    valuation_confidence,sbc_to_revenue,bear_upside,base_upside,probability_weighted_upside,
    durability_anchor_years,durability_evidence_count,dilution_reconciliation_pass,owner_fcf_conversion_pass,
    counter_thesis_evidence_count,structural_risk_review_pass,growth_anchor_verified,evidence_payload,source_reference
  ) values (
    v_hardening_snapshot_id,
    v_ticker,
    v_valuation_run_id,
    v_mispricing_snapshot_id,
    'POL-QUALITY-HARDENING-V1',
    v_preview->'projected'->>'business_durability_gate',
    v_preview->'projected'->>'owner_earnings_gate',
    v_preview->'projected'->>'value_trap_gate',
    v_preview->'projected'->>'valuation_robustness_gate',
    v_preview->'projected'->>'overall_gate',
    (v_preview->'projected'->>'valuation_confidence')::numeric,
    nullif(v_preview->'effective_hardening_inputs'->>'sbc_to_revenue','')::numeric,
    (v_preview->'base_refresh'->'mispricing'->>'bear_upside')::numeric,
    (v_preview->'base_refresh'->'mispricing'->>'base_upside')::numeric,
    (v_preview->'base_refresh'->'mispricing'->>'probability_weighted_upside')::numeric,
    coalesce((v_preview->'effective_hardening_inputs'->>'durability_anchor_years')::integer,0),
    coalesce((v_preview->'effective_hardening_inputs'->>'durability_evidence_count')::integer,0),
    nullif(v_preview->'effective_hardening_inputs'->>'dilution_reconciliation_pass','')::boolean,
    nullif(v_preview->'effective_hardening_inputs'->>'owner_fcf_conversion_pass','')::boolean,
    coalesce((v_preview->'effective_hardening_inputs'->>'counter_thesis_evidence_count')::integer,0),
    nullif(v_preview->'effective_hardening_inputs'->>'structural_risk_review_pass','')::boolean,
    coalesce((v_preview->'effective_hardening_inputs'->>'growth_anchor_verified')::boolean,false),
    jsonb_build_object(
      'refresh_policy','POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1',
      'base_refresh_policy','POL-QUALITY-HARDENING-REFRESH-V1',
      'hardening_policy','POL-QUALITY-HARDENING-V1',
      'valuation_run_id',v_valuation_run_id,
      'compatibility_price_snapshot_id',v_price_snapshot_id,
      'mispricing_snapshot_id',v_mispricing_snapshot_id,
      'prior_hardening_snapshot_id',v_preview->>'prior_hardening_snapshot_id',
      'canonical_evidence',v_preview->'canonical_evidence',
      'canonical_evidence_fingerprint',v_preview->>'canonical_evidence_fingerprint',
      'shadow_evidence_used_for_production_gate',false,
      'human_execution_only',true,
      'auto_trade',false
    ),
    'POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1:'||
      v_valuation_run_id||':'||(v_preview->>'canonical_evidence_fingerprint')
  );

  select artifact_id into v_valuation_artifact_id
  from fwios.lineage_artifacts
  where artifact_key='VALUATION:'||v_valuation_run_id
    and artifact_type='VALUATION_RUN';

  insert into fwios.lineage_artifacts(
    artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
  ) values (
    'HARDENING:'||v_hardening_snapshot_id,
    'HARDENING_SNAPSHOT','fwios','candidate_quality_hardening_snapshots',v_hardening_snapshot_id,
    v_instrument_id,'RESOLVED',
    jsonb_build_object(
      'ticker',v_ticker,
      'valuation_run_id',v_valuation_run_id,
      'mispricing_snapshot_id',v_mispricing_snapshot_id,
      'refresh_policy','POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1'
    )
  )
  on conflict(artifact_key) do nothing;

  select artifact_id into v_hardening_artifact_id
  from fwios.lineage_artifacts
  where artifact_key='HARDENING:'||v_hardening_snapshot_id;

  if v_valuation_artifact_id is null or v_hardening_artifact_id is null then
    raise exception 'QUALITY_HARDENING_CANONICAL_REFRESH_LINEAGE_ARTIFACT_MISSING';
  end if;

  insert into fwios.lineage_edges(
    from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
  )
  select v_valuation_artifact_id,v_hardening_artifact_id,
         'VALUATION_SUPPORTS_HARDENING','VALUATION_RUN','RESOLVED',
         'POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1',
         jsonb_build_object('mispricing_snapshot_id',v_mispricing_snapshot_id)
  where not exists(
    select 1 from fwios.lineage_edges e
    where e.from_artifact_id=v_valuation_artifact_id
      and e.to_artifact_id=v_hardening_artifact_id
      and e.edge_type='VALUATION_SUPPORTS_HARDENING'
      and e.edge_role='VALUATION_RUN'
  );

  -- Durability evidence artifacts + edges.
  for v_id in
    select distinct value
    from jsonb_array_elements_text(
      coalesce(v_preview->'canonical_evidence'->'business_durability'->'annual_revenue_evidence_ids','[]'::jsonb)
    )
  loop
    select * into v_evidence from fwios.evidence_records where evidence_id=v_id;
    if found then
      insert into fwios.lineage_artifacts(
        artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
      ) values (
        'EVIDENCE:'||v_id,'EVIDENCE','fwios','evidence_records',v_id,v_instrument_id,'RESOLVED',
        jsonb_build_object(
          'ticker',v_ticker,'source_id',v_evidence.source_id,'source_url',v_evidence.source_url,
          'verification_status',v_evidence.verification_status,'canonical_metric_gate',v_evidence.canonical_metric_gate
        )
      ) on conflict(artifact_key) do nothing;

      select artifact_id into v_artifact_id
      from fwios.lineage_artifacts where artifact_key='EVIDENCE:'||v_id;

      insert into fwios.lineage_edges(
        from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
      )
      select v_artifact_id,v_hardening_artifact_id,'EVIDENCE_SUPPORTS_HARDENING',
             'DURABILITY_REVENUE','RESOLVED',
             'POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1','{}'::jsonb
      where not exists(
        select 1 from fwios.lineage_edges e
        where e.from_artifact_id=v_artifact_id and e.to_artifact_id=v_hardening_artifact_id
          and e.edge_type='EVIDENCE_SUPPORTS_HARDENING' and e.edge_role='DURABILITY_REVENUE'
      );
    end if;
  end loop;

  -- Durability metric artifacts + edges.
  for v_obs_id in
    select value::uuid
    from jsonb_array_elements_text(
      coalesce(v_preview->'canonical_evidence'->'business_durability'->'annual_revenue_observation_ids','[]'::jsonb)
    )
  loop
    select * into v_observation from fwios.metric_observations where observation_id=v_obs_id;
    if found then
      insert into fwios.lineage_artifacts(
        artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
      ) values (
        'METRIC_OBS:'||v_obs_id::text,'METRIC_OBSERVATION','fwios','metric_observations',
        v_obs_id::text,v_instrument_id,'RESOLVED',
        jsonb_build_object('metric_code',v_observation.metric_code,'observation_key',v_observation.observation_key)
      ) on conflict(artifact_key) do nothing;

      select artifact_id into v_artifact_id
      from fwios.lineage_artifacts where artifact_key='METRIC_OBS:'||v_obs_id::text;

      insert into fwios.lineage_edges(
        from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
      )
      select v_artifact_id,v_hardening_artifact_id,'METRIC_SUPPORTS_HARDENING',
             'DURABILITY_REVENUE','RESOLVED',
             'POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1','{}'::jsonb
      where not exists(
        select 1 from fwios.lineage_edges e
        where e.from_artifact_id=v_artifact_id and e.to_artifact_id=v_hardening_artifact_id
          and e.edge_type='METRIC_SUPPORTS_HARDENING' and e.edge_role='DURABILITY_REVENUE'
      );
    end if;
  end loop;

  -- Owner earnings evidence artifacts + edges.
  for v_id,v_role in
    select x.evidence_id,x.edge_role
    from (
      values
        (nullif(v_preview->'canonical_evidence'->'owner_earnings'->>'revenue_evidence_id',''),'OWNER_EARNINGS_REVENUE'),
        (nullif(v_preview->'canonical_evidence'->'owner_earnings'->>'sbc_evidence_id',''),'OWNER_EARNINGS_SBC'),
        (nullif(v_preview->'canonical_evidence'->'owner_earnings'->>'fcf_evidence_id',''),'OWNER_EARNINGS_FCF')
    ) as x(evidence_id,edge_role)
    where x.evidence_id is not null
  loop
    select * into v_evidence from fwios.evidence_records where evidence_id=v_id;
    if found then
      insert into fwios.lineage_artifacts(
        artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
      ) values (
        'EVIDENCE:'||v_id,'EVIDENCE','fwios','evidence_records',v_id,v_instrument_id,'RESOLVED',
        jsonb_build_object(
          'ticker',v_ticker,'source_id',v_evidence.source_id,'source_url',v_evidence.source_url,
          'verification_status',v_evidence.verification_status,'canonical_metric_gate',v_evidence.canonical_metric_gate
        )
      ) on conflict(artifact_key) do nothing;

      select artifact_id into v_artifact_id
      from fwios.lineage_artifacts where artifact_key='EVIDENCE:'||v_id;

      insert into fwios.lineage_edges(
        from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
      )
      select v_artifact_id,v_hardening_artifact_id,'EVIDENCE_SUPPORTS_HARDENING',
             v_role,'RESOLVED','POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1','{}'::jsonb
      where not exists(
        select 1 from fwios.lineage_edges e
        where e.from_artifact_id=v_artifact_id and e.to_artifact_id=v_hardening_artifact_id
          and e.edge_type='EVIDENCE_SUPPORTS_HARDENING' and e.edge_role=v_role
      );
    end if;
  end loop;

  -- Owner earnings metric artifacts + edges.
  for v_obs_id,v_role in
    select x.observation_id::uuid,x.edge_role
    from (
      values
        (nullif(v_preview->'canonical_evidence'->'owner_earnings'->>'revenue_observation_id',''),'OWNER_EARNINGS_REVENUE'),
        (nullif(v_preview->'canonical_evidence'->'owner_earnings'->>'sbc_observation_id',''),'OWNER_EARNINGS_SBC'),
        (nullif(v_preview->'canonical_evidence'->'owner_earnings'->>'fcf_observation_id',''),'OWNER_EARNINGS_FCF')
    ) as x(observation_id,edge_role)
    where x.observation_id is not null
  loop
    select * into v_observation from fwios.metric_observations where observation_id=v_obs_id;
    if found then
      insert into fwios.lineage_artifacts(
        artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
      ) values (
        'METRIC_OBS:'||v_obs_id::text,'METRIC_OBSERVATION','fwios','metric_observations',
        v_obs_id::text,v_instrument_id,'RESOLVED',
        jsonb_build_object('metric_code',v_observation.metric_code,'observation_key',v_observation.observation_key)
      ) on conflict(artifact_key) do nothing;

      select artifact_id into v_artifact_id
      from fwios.lineage_artifacts where artifact_key='METRIC_OBS:'||v_obs_id::text;

      insert into fwios.lineage_edges(
        from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
      )
      select v_artifact_id,v_hardening_artifact_id,'METRIC_SUPPORTS_HARDENING',
             v_role,'RESOLVED','POL-QUALITY-HARDENING-CANONICAL-EVIDENCE-V1','{}'::jsonb
      where not exists(
        select 1 from fwios.lineage_edges e
        where e.from_artifact_id=v_artifact_id and e.to_artifact_id=v_hardening_artifact_id
          and e.edge_type='METRIC_SUPPORTS_HARDENING' and e.edge_role=v_role
      );
    end if;
  end loop;

  return jsonb_build_object(
    'status','APPLIED',
    'ticker',v_ticker,
    'valuation_run_id',v_valuation_run_id,
    'price_snapshot_id',v_price_snapshot_id,
    'mispricing_snapshot_id',v_mispricing_snapshot_id,
    'hardening_snapshot_id',v_hardening_snapshot_id,
    'overall_gate',v_preview->'projected'->>'overall_gate',
    'projected',v_preview->'projected',
    'canonical_evidence',v_preview->'canonical_evidence',
    'portfolio_mutation',false,
    'approval_mutation',false,
    'execution_mutation',false,
    'auto_trade',false,
    'human_execution_only',true
  );
end;
$function$
;

revoke all on function fwios.preview_quality_hardening_canonical_evidence_v1(text) from public,anon,authenticated;
revoke all on function fwios.preview_quality_hardening_canonical_refresh_v1(text) from public,anon,authenticated;
revoke all on function fwios.apply_quality_hardening_canonical_refresh_v1(text,boolean) from public,anon,authenticated;
grant execute on function fwios.preview_quality_hardening_canonical_evidence_v1(text) to service_role;
grant execute on function fwios.preview_quality_hardening_canonical_refresh_v1(text) to service_role;
grant execute on function fwios.apply_quality_hardening_canonical_refresh_v1(text,boolean) to service_role;
