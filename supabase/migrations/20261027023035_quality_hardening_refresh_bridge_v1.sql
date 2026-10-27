-- Quality Hardening Refresh Bridge v1
-- Live history alignment: 20261027023035_quality_hardening_refresh_bridge_v1
-- Additive/fail-closed. This migration does not retune POL-QUALITY-HARDENING-V1.

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status
) values (
  'QUALITY_HARDENING_REFRESH',
  'decision_intelligence',
  'Quality Hardening Refresh Bridge v1',
  'Deterministically refresh price-sensitive quality hardening after a production valuation cutover without weakening hardening policy or bypassing canonical evidence boundaries.',
  'fwios.preview_quality_hardening_refresh_v1 / fwios.apply_quality_hardening_refresh_v1',
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
  'POL-QUALITY-HARDENING-REFRESH-V1',
  'QUALITY_HARDENING_REFRESH',
  '1.0',
  'ACTIVE',
  true,
  jsonb_build_object(
    'hardening_policy_id','POL-QUALITY-HARDENING-V1',
    'readiness_policy_id','POL-RESEARCH-READINESS-V1',
    'price_source','fwios.market_daily_closes',
    'price_requires_existing_verification_gate_pass',true,
    'carry_forward_requires_unexpired_prior_hardening',true,
    'business_durability_never_auto_upgraded',true,
    'owner_earnings_never_auto_upgraded',true,
    'value_trap_recomputed_from_current_mispricing',true,
    'valuation_robustness_recomputed_from_current_valuation_and_price',true,
    'shadow_evidence_direct_promotion',false,
    'human_authorization_required_for_apply',true,
    'portfolio_mutation',false,
    'approval_mutation',false,
    'execution_mutation',false,
    'auto_trade',false,
    'human_execution_only',true
  ),
  'FWIOS Quality Hardening Refresh Bridge v1',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status=excluded.lifecycle_status,
  deterministic_scoring=excluded.deterministic_scoring,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

create or replace function fwios.preview_quality_hardening_refresh_v1(p_ticker text)
returns jsonb
language plpgsql
stable
security invoker
set search_path = pg_catalog, fwios
as $$
declare
  v_ticker text := upper(btrim(coalesce(p_ticker,'')));
  v_readiness_policy jsonb;
  v_hardening_policy jsonb;
  v_valuation fwios.valuation_runs%rowtype;
  v_price fwios.market_daily_closes%rowtype;
  v_verification fwios.market_verification_sets%rowtype;
  v_prior fwios.candidate_quality_hardening_snapshots%rowtype;
  v_mispricing_policy fwios.mispricing_policies%rowtype;
  v_prior_found boolean := false;
  v_prior_valid boolean := false;
  v_policy_count integer := 0;
  v_price_max_age_days integer;
  v_hardening_max_age_days integer;
  v_durability_min_years integer;
  v_counter_thesis_min integer;
  v_bear_review_below numeric;
  v_bear_fail_below numeric;
  v_sbc_pass_max numeric;
  v_sbc_hard_review_above numeric;
  v_sbc_fail_above numeric;
  v_bear_upside numeric;
  v_base_upside numeric;
  v_bull_upside numeric;
  v_pw_upside numeric;
  v_business_gate text := 'BLOCKED';
  v_owner_gate text := 'BLOCKED';
  v_value_trap_gate text := 'BLOCKED';
  v_robustness_gate text := 'BLOCKED';
  v_overall_gate text;
  v_confidence numeric;
  v_mispricing_gate text;
  v_extreme_mispricing boolean := false;
  v_hash text;
  v_primary_quote_id text;
  v_secondary_quote_id text;
  v_price_snapshot_id text;
  v_mispricing_snapshot_id text;
  v_hardening_snapshot_id text;
  v_valuation_artifact_id uuid;
begin
  if v_ticker='' then
    return jsonb_build_object(
      'refresh_status','BLOCKED',
      'reason','TICKER_REQUIRED',
      'policy_version_id','POL-QUALITY-HARDENING-REFRESH-V1',
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  select config into v_readiness_policy
  from fwios.policy_versions
  where policy_version_id='POL-RESEARCH-READINESS-V1'
    and lifecycle_status='ACTIVE';

  select config into v_hardening_policy
  from fwios.policy_versions
  where policy_version_id='POL-QUALITY-HARDENING-V1'
    and lifecycle_status='ACTIVE';

  if v_readiness_policy is null or v_hardening_policy is null then
    return jsonb_build_object(
      'refresh_status','BLOCKED',
      'reason','REQUIRED_POLICY_NOT_ACTIVE',
      'ticker',v_ticker,
      'policy_version_id','POL-QUALITY-HARDENING-REFRESH-V1',
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  v_price_max_age_days := (v_readiness_policy->>'price_max_age_days')::integer;
  v_hardening_max_age_days := (v_readiness_policy->>'hardening_max_age_days')::integer;
  v_durability_min_years := (v_hardening_policy->>'durability_anchor_min_years')::integer;
  v_counter_thesis_min := (v_hardening_policy->>'counter_thesis_evidence_min')::integer;
  v_bear_review_below := (v_hardening_policy->>'bear_case_review_below')::numeric;
  v_bear_fail_below := (v_hardening_policy->>'bear_case_fail_below')::numeric;
  v_sbc_pass_max := (v_hardening_policy->'owner_earnings'->>'sbc_pass_max')::numeric;
  v_sbc_hard_review_above := (v_hardening_policy->'owner_earnings'->>'sbc_hard_review_above')::numeric;
  v_sbc_fail_above := (v_hardening_policy->'owner_earnings'->>'sbc_fail_above')::numeric;

  select * into v_valuation
  from fwios.valuation_runs
  where ticker=v_ticker
    and production_eligible=true
    and valuation_readiness='PASS'
    and router_gate='PASS'
    and valuation_gate='PASS'
    and schema_gate='PASS'
  order by created_at desc,run_id desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'refresh_status','BLOCKED',
      'reason','CURRENT_PRODUCTION_VALUATION_NOT_FOUND',
      'ticker',v_ticker,
      'policy_version_id','POL-QUALITY-HARDENING-REFRESH-V1',
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  if v_valuation.bear_fv_per_share is null
     or v_valuation.base_fv_per_share is null
     or v_valuation.bull_fv_per_share is null
     or v_valuation.probability_weighted_fv_per_share is null
  then
    return jsonb_build_object(
      'refresh_status','BLOCKED',
      'reason','CURRENT_PRODUCTION_FAIR_VALUES_INCOMPLETE',
      'ticker',v_ticker,
      'valuation_run_id',v_valuation.run_id,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  select artifact_id into v_valuation_artifact_id
  from fwios.lineage_artifacts
  where artifact_key='VALUATION:'||v_valuation.run_id
    and artifact_type='VALUATION_RUN';

  if v_valuation_artifact_id is null then
    return jsonb_build_object(
      'refresh_status','BLOCKED',
      'reason','CURRENT_PRODUCTION_VALUATION_LINEAGE_MISSING',
      'ticker',v_ticker,
      'valuation_run_id',v_valuation.run_id,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  select * into v_price
  from fwios.market_daily_closes m
  where m.asset_symbol=v_ticker
    and m.close_price>0
    and m.session_date >= current_date-v_price_max_age_days
    and exists (
      select 1
      from jsonb_array_elements_text(v_readiness_policy->'accepted_price_verification_statuses') x(value)
      where x.value=m.verification_status
    )
    and exists (
      select 1
      from jsonb_array_elements_text(v_readiness_policy->'accepted_price_provenance_statuses') x(value)
      where x.value=m.provenance_status
    )
  order by m.session_date desc,m.retrieved_at desc,m.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'refresh_status','BLOCKED',
      'reason','ACCEPTED_CANONICAL_DAILY_CLOSE_NOT_FOUND',
      'ticker',v_ticker,
      'valuation_run_id',v_valuation.run_id,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  if v_price.instrument_id is null
     or v_price.primary_observation_id is null
     or v_price.market_verification_id is null
  then
    return jsonb_build_object(
      'refresh_status','BLOCKED',
      'reason','CANONICAL_DAILY_CLOSE_LINEAGE_INCOMPLETE',
      'ticker',v_ticker,
      'valuation_run_id',v_valuation.run_id,
      'session_date',v_price.session_date,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  select * into v_verification
  from fwios.market_verification_sets
  where verification_id=v_price.market_verification_id
    and instrument_id=v_price.instrument_id
    and session_date=v_price.session_date
    and gate='PASS';

  if not found
     or v_verification.selected_value is null
     or abs(v_verification.selected_value-v_price.close_price) > 0.00000001
  then
    return jsonb_build_object(
      'refresh_status','BLOCKED',
      'reason','CANONICAL_PRICE_VERIFICATION_SET_NOT_PASS',
      'ticker',v_ticker,
      'valuation_run_id',v_valuation.run_id,
      'session_date',v_price.session_date,
      'market_verification_id',v_price.market_verification_id,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  select count(*) into v_policy_count
  from fwios.mispricing_policies
  where active=true;

  if v_policy_count<>1 then
    return jsonb_build_object(
      'refresh_status','BLOCKED',
      'reason','ACTIVE_MISPRICING_POLICY_NOT_SINGULAR',
      'ticker',v_ticker,
      'active_policy_count',v_policy_count,
      'production_changes','NONE',
      'auto_trade',false
    );
  end if;

  select * into v_mispricing_policy
  from fwios.mispricing_policies
  where active=true
  limit 1;

  v_bear_upside := v_valuation.bear_fv_per_share/v_price.close_price-1;
  v_base_upside := v_valuation.base_fv_per_share/v_price.close_price-1;
  v_bull_upside := v_valuation.bull_fv_per_share/v_price.close_price-1;
  v_pw_upside := v_valuation.probability_weighted_fv_per_share/v_price.close_price-1;

  v_mispricing_gate := case
    when v_base_upside>=v_mispricing_policy.base_upside_min
     and v_pw_upside>=v_mispricing_policy.probability_weighted_upside_min
      then 'PASS'
    else 'FAIL - INSUFFICIENT MISPRICING'
  end;

  select * into v_prior
  from fwios.candidate_quality_hardening_snapshots
  where ticker=v_ticker
  order by created_at desc,hardening_snapshot_id desc
  limit 1;

  v_prior_found := found;
  v_prior_valid := v_prior_found
    and v_prior.created_at >= now()-make_interval(days=>v_hardening_max_age_days);

  if v_prior_valid then
    if v_prior.business_durability_gate='FAIL' then
      v_business_gate := 'FAIL';
    elsif coalesce(v_prior.durability_anchor_years,0)>=v_durability_min_years
       and v_prior.durability_evidence_count>0
       and v_prior.growth_anchor_verified is true
    then
      v_business_gate := case
        when v_prior.business_durability_gate='PASS' then 'PASS'
        when v_prior.business_durability_gate='REVIEW' then 'REVIEW'
        else 'BLOCKED'
      end;
    else
      v_business_gate := 'BLOCKED';
    end if;

    if v_prior.owner_earnings_gate='FAIL' then
      v_owner_gate := 'FAIL';
    elsif v_prior.sbc_to_revenue is null then
      v_owner_gate := 'BLOCKED';
    elsif v_prior.sbc_to_revenue>v_sbc_fail_above then
      v_owner_gate := 'FAIL';
    elsif v_prior.sbc_to_revenue>v_sbc_hard_review_above then
      v_owner_gate := 'REVIEW';
    elsif v_prior.sbc_to_revenue>v_sbc_pass_max then
      if v_prior.dilution_reconciliation_pass is true
         and v_prior.owner_fcf_conversion_pass is true
      then
        v_owner_gate := 'REVIEW';
      else
        v_owner_gate := 'BLOCKED';
      end if;
    elsif v_prior.owner_fcf_conversion_pass is true then
      v_owner_gate := case
        when v_prior.owner_earnings_gate='PASS' then 'PASS'
        when v_prior.owner_earnings_gate='REVIEW' then 'REVIEW'
        else 'BLOCKED'
      end;
    else
      v_owner_gate := 'BLOCKED';
    end if;
  else
    v_business_gate := 'BLOCKED';
    v_owner_gate := 'BLOCKED';
  end if;

  v_extreme_mispricing := greatest(v_base_upside,v_pw_upside) >=
    (v_hardening_policy->>'extreme_mispricing_trigger')::numeric;

  if not v_extreme_mispricing then
    v_value_trap_gate := 'PASS';
  elsif v_prior_valid
    and v_prior.counter_thesis_evidence_count>=v_counter_thesis_min
    and v_prior.structural_risk_review_pass is true
  then
    v_value_trap_gate := 'PASS';
  else
    v_value_trap_gate := 'BLOCKED';
  end if;

  v_robustness_gate := case
    when v_bear_upside<v_bear_fail_below then 'FAIL'
    when v_bear_upside<v_bear_review_below then 'REVIEW'
    else 'PASS'
  end;

  v_overall_gate := fwios.quality_hardening_overall_gate_v1(
    v_business_gate,v_owner_gate,v_value_trap_gate,v_robustness_gate
  );
  v_confidence := fwios.valuation_confidence_v1(
    v_business_gate,v_owner_gate,v_value_trap_gate,v_robustness_gate
  );

  v_hash := substr(md5(v_valuation.run_id||':'||v_price.primary_observation_id::text),1,12);
  v_primary_quote_id := 'Q-DCL-'||v_ticker||'-'||to_char(v_price.session_date,'YYYYMMDD')||'-'||substr(md5(v_price.primary_observation_id::text),1,10);
  if v_price.secondary_observation_id is not null then
    v_secondary_quote_id := 'Q-DCL-'||v_ticker||'-'||to_char(v_price.session_date,'YYYYMMDD')||'-'||substr(md5(v_price.secondary_observation_id::text),1,10);
  end if;
  v_price_snapshot_id := 'PX-DCL-'||v_ticker||'-'||to_char(v_price.session_date,'YYYYMMDD')||'-'||substr(md5(v_price.market_verification_id||':'||v_price.primary_observation_id::text),1,10);
  v_mispricing_snapshot_id := 'MIS-QHR-'||v_ticker||'-'||to_char(v_price.session_date,'YYYYMMDD')||'-'||substr(md5(v_valuation.run_id||':'||v_price_snapshot_id||':'||v_mispricing_policy.policy_id),1,10);
  v_hardening_snapshot_id := 'HARD-QHR-'||v_ticker||'-'||to_char(v_price.session_date,'YYYYMMDD')||'-'||v_hash;

  return jsonb_build_object(
    'refresh_status','READY_TO_APPLY',
    'policy_version_id','POL-QUALITY-HARDENING-REFRESH-V1',
    'hardening_policy_id','POL-QUALITY-HARDENING-V1',
    'ticker',v_ticker,
    'valuation_run_id',v_valuation.run_id,
    'price',jsonb_build_object(
      'session_date',v_price.session_date,
      'close_price',v_price.close_price,
      'currency',v_price.currency,
      'exchange',v_price.exchange,
      'verification_status',v_price.verification_status,
      'provenance_status',v_price.provenance_status,
      'primary_observation_id',v_price.primary_observation_id,
      'secondary_observation_id',v_price.secondary_observation_id,
      'market_verification_id',v_price.market_verification_id
    ),
    'mispricing',jsonb_build_object(
      'policy_id',v_mispricing_policy.policy_id,
      'gate',v_mispricing_gate,
      'bear_upside',v_bear_upside,
      'base_upside',v_base_upside,
      'bull_upside',v_bull_upside,
      'probability_weighted_upside',v_pw_upside
    ),
    'prior_hardening_snapshot_id',case when v_prior_found then v_prior.hardening_snapshot_id else null end,
    'prior_hardening_valid_for_carry_forward',v_prior_valid,
    'projected',jsonb_build_object(
      'business_durability_gate',v_business_gate,
      'owner_earnings_gate',v_owner_gate,
      'value_trap_gate',v_value_trap_gate,
      'valuation_robustness_gate',v_robustness_gate,
      'overall_gate',v_overall_gate,
      'valuation_confidence',v_confidence,
      'extreme_mispricing_triggered',v_extreme_mispricing
    ),
    'proposed_ids',jsonb_build_object(
      'primary_quote_id',v_primary_quote_id,
      'secondary_quote_id',v_secondary_quote_id,
      'price_snapshot_id',v_price_snapshot_id,
      'mispricing_snapshot_id',v_mispricing_snapshot_id,
      'hardening_snapshot_id',v_hardening_snapshot_id
    ),
    'shadow_evidence_used_for_production_gate',false,
    'human_authorization_required',true,
    'portfolio_mutation',false,
    'approval_mutation',false,
    'execution_mutation',false,
    'auto_trade',false,
    'production_changes','PREVIEW_NONE'
  );
end;
$$;

create or replace function fwios.apply_quality_hardening_refresh_v1(
  p_ticker text,
  p_human_authorized boolean default false
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = pg_catalog, fwios
as $$
declare
  v_preview jsonb;
  v_ticker text;
  v_valuation fwios.valuation_runs%rowtype;
  v_price fwios.market_daily_closes%rowtype;
  v_primary_obs fwios.market_observations%rowtype;
  v_secondary_obs fwios.market_observations%rowtype;
  v_verification fwios.market_verification_sets%rowtype;
  v_prior fwios.candidate_quality_hardening_snapshots%rowtype;
  v_prior_valid boolean := false;
  v_primary_quote_id text;
  v_secondary_quote_id text;
  v_price_snapshot_id text;
  v_mispricing_snapshot_id text;
  v_hardening_snapshot_id text;
  v_policy_id text;
  v_price_max_age_days integer;
  v_conflict_status text;
  v_existing_hardening fwios.candidate_quality_hardening_snapshots%rowtype;
  v_valuation_artifact_id uuid;
  v_hardening_artifact_id uuid;
begin
  if not coalesce(p_human_authorized,false) then
    return jsonb_build_object(
      'status','BLOCKED','reason','HUMAN_AUTHORIZATION_REQUIRED',
      'production_changes','NONE','auto_trade',false,'human_execution_only',true
    );
  end if;

  v_preview := fwios.preview_quality_hardening_refresh_v1(p_ticker);
  if coalesce(v_preview->>'refresh_status','BLOCKED')<>'READY_TO_APPLY' then
    return jsonb_build_object(
      'status','BLOCKED','reason','REFRESH_PREVIEW_NOT_READY','preview',v_preview,
      'production_changes','NONE','auto_trade',false,'human_execution_only',true
    );
  end if;

  v_ticker := v_preview->>'ticker';
  v_primary_quote_id := v_preview->'proposed_ids'->>'primary_quote_id';
  v_secondary_quote_id := v_preview->'proposed_ids'->>'secondary_quote_id';
  v_price_snapshot_id := v_preview->'proposed_ids'->>'price_snapshot_id';
  v_mispricing_snapshot_id := v_preview->'proposed_ids'->>'mispricing_snapshot_id';
  v_hardening_snapshot_id := v_preview->'proposed_ids'->>'hardening_snapshot_id';
  v_policy_id := v_preview->'mispricing'->>'policy_id';

  select * into v_existing_hardening
  from fwios.candidate_quality_hardening_snapshots
  where hardening_snapshot_id=v_hardening_snapshot_id;

  if found then
    if v_existing_hardening.ticker=v_ticker
       and v_existing_hardening.valuation_run_id=v_preview->>'valuation_run_id'
    then
      return jsonb_build_object(
        'status','NOOP_ALREADY_REFRESHED','ticker',v_ticker,
        'hardening_snapshot_id',v_hardening_snapshot_id,
        'overall_gate',v_existing_hardening.overall_gate,
        'production_changes','NONE','auto_trade',false,'human_execution_only',true
      );
    end if;
    raise exception 'QUALITY_HARDENING_REFRESH_ID_COLLISION';
  end if;

  select * into v_valuation
  from fwios.valuation_runs
  where run_id=v_preview->>'valuation_run_id';

  select * into v_price
  from fwios.market_daily_closes
  where asset_symbol=v_ticker
    and primary_observation_id=(v_preview->'price'->>'primary_observation_id')::uuid
    and session_date=(v_preview->'price'->>'session_date')::date
  order by retrieved_at desc,created_at desc
  limit 1;

  if not found then
    raise exception 'QUALITY_HARDENING_REFRESH_PRICE_STATE_CHANGED';
  end if;

  select * into v_primary_obs
  from fwios.market_observations
  where observation_id=v_price.primary_observation_id;

  if not found or v_primary_obs.provenance_status<>'PASS' or v_primary_obs.source_url is null then
    raise exception 'QUALITY_HARDENING_REFRESH_PRIMARY_OBSERVATION_INVALID';
  end if;

  if v_price.secondary_observation_id is not null then
    select * into v_secondary_obs
    from fwios.market_observations
    where observation_id=v_price.secondary_observation_id;

    if not found or v_secondary_obs.provenance_status<>'PASS' or v_secondary_obs.source_url is null then
      raise exception 'QUALITY_HARDENING_REFRESH_SECONDARY_OBSERVATION_INVALID';
    end if;
  end if;

  select * into v_verification
  from fwios.market_verification_sets
  where verification_id=v_price.market_verification_id
    and gate='PASS';

  if not found then
    raise exception 'QUALITY_HARDENING_REFRESH_VERIFICATION_STATE_CHANGED';
  end if;

  select (config->>'price_max_age_days')::integer into v_price_max_age_days
  from fwios.policy_versions
  where policy_version_id='POL-RESEARCH-READINESS-V1'
    and lifecycle_status='ACTIVE';

  if v_price_max_age_days is null then
    raise exception 'QUALITY_HARDENING_REFRESH_READINESS_POLICY_MISSING';
  end if;

  insert into fwios.market_price_quotes(
    quote_id,asset_symbol,asset_class,exchange,currency,price_type,price,session_date,quote_at,
    market_status,source_provider,source_url,source_tier,retrieved_at,provenance_status,raw_payload,
    instrument_id,market_observation_id
  ) values (
    v_primary_quote_id,v_ticker,'Stock',v_price.exchange,v_primary_obs.value_currency,
    'REGULAR_CLOSE',v_primary_obs.observation_value,v_primary_obs.session_date,v_primary_obs.observed_at,
    coalesce(v_primary_obs.market_status,'CLOSED'),v_primary_obs.provider,v_primary_obs.source_url,
    v_primary_obs.source_tier,v_price.retrieved_at,'PASS',
    jsonb_build_object(
      'bridge_policy','POL-QUALITY-HARDENING-REFRESH-V1',
      'canonical_market_observation_id',v_primary_obs.observation_id,
      'canonical_market_verification_id',v_price.market_verification_id,
      'derived_compatibility_record',true
    ),
    v_price.instrument_id,v_primary_obs.observation_id
  )
  on conflict(quote_id) do nothing;

  if v_price.secondary_observation_id is not null then
    insert into fwios.market_price_quotes(
      quote_id,asset_symbol,asset_class,exchange,currency,price_type,price,session_date,quote_at,
      market_status,source_provider,source_url,source_tier,retrieved_at,provenance_status,raw_payload,
      instrument_id,market_observation_id
    ) values (
      v_secondary_quote_id,v_ticker,'Stock',v_price.exchange,v_secondary_obs.value_currency,
      'REGULAR_CLOSE',v_secondary_obs.observation_value,v_secondary_obs.session_date,v_secondary_obs.observed_at,
      coalesce(v_secondary_obs.market_status,'CLOSED'),v_secondary_obs.provider,v_secondary_obs.source_url,
      v_secondary_obs.source_tier,v_price.retrieved_at,'PASS',
      jsonb_build_object(
        'bridge_policy','POL-QUALITY-HARDENING-REFRESH-V1',
        'canonical_market_observation_id',v_secondary_obs.observation_id,
        'canonical_market_verification_id',v_price.market_verification_id,
        'derived_compatibility_record',true
      ),
      v_price.instrument_id,v_secondary_obs.observation_id
    )
    on conflict(quote_id) do nothing;
  end if;

  v_conflict_status := case
    when v_price.secondary_observation_id is null then 'NO_CROSSCHECK'
    when coalesce(v_price.divergence_pct,0)<=coalesce(v_verification.max_allowed_divergence_pct,0.005) then 'PASS'
    else 'CONFLICT'
  end;

  if v_conflict_status='CONFLICT' then
    raise exception 'QUALITY_HARDENING_REFRESH_PRICE_CONFLICT';
  end if;

  insert into fwios.market_price_snapshots(
    snapshot_id,asset_symbol,asset_class,primary_quote_id,crosscheck_quote_id,selected_price,currency,
    session_date,market_status,divergence_pct,max_allowed_divergence_pct,fresh_until,conflict_status,
    provenance_status,price_gate,notes,instrument_id,primary_observation_id,crosscheck_observation_id,
    selected_observation_id,market_verification_id
  ) values (
    v_price_snapshot_id,v_ticker,'Stock',v_primary_quote_id,
    case when v_price.secondary_observation_id is not null then v_secondary_quote_id else null end,
    v_price.close_price,coalesce(v_price.currency,v_primary_obs.value_currency),
    v_price.session_date,coalesce(v_primary_obs.market_status,'CLOSED'),v_price.divergence_pct,
    coalesce(v_verification.max_allowed_divergence_pct,0.005),
    ((v_price.session_date+v_price_max_age_days)::timestamp at time zone 'UTC'),
    v_conflict_status,'PASS','PASS',
    'Canonical daily-close compatibility snapshot created by POL-QUALITY-HARDENING-REFRESH-V1; no external price refetch.',
    v_price.instrument_id,v_price.primary_observation_id,v_price.secondary_observation_id,
    coalesce(v_verification.selected_observation_id,v_price.primary_observation_id),v_price.market_verification_id
  )
  on conflict(snapshot_id) do nothing;

  insert into fwios.valuation_mispricing_snapshots(
    mispricing_snapshot_id,valuation_run_id,ticker,price_snapshot_id,policy_id,current_price,
    bear_fv_per_share,base_fv_per_share,bull_fv_per_share,probability_weighted_fv_per_share,
    bear_upside,base_upside,bull_upside,probability_weighted_upside,reward_risk,
    mispricing_gate,mispricing_class,mispricing_note
  ) values (
    v_mispricing_snapshot_id,v_valuation.run_id,v_ticker,v_price_snapshot_id,v_policy_id,v_price.close_price,
    v_valuation.bear_fv_per_share,v_valuation.base_fv_per_share,v_valuation.bull_fv_per_share,
    v_valuation.probability_weighted_fv_per_share,
    (v_preview->'mispricing'->>'bear_upside')::numeric,
    (v_preview->'mispricing'->>'base_upside')::numeric,
    (v_preview->'mispricing'->>'bull_upside')::numeric,
    (v_preview->'mispricing'->>'probability_weighted_upside')::numeric,
    null,
    v_preview->'mispricing'->>'gate',
    case when v_preview->'mispricing'->>'gate'='PASS' then 'UNDERVALUED' else 'INSUFFICIENT_MISPRICING' end,
    'Recomputed from current production valuation and canonical daily close by POL-QUALITY-HARDENING-REFRESH-V1.'
  )
  on conflict(valuation_run_id,price_snapshot_id,policy_id) do nothing;

  v_prior_valid := coalesce((v_preview->>'prior_hardening_valid_for_carry_forward')::boolean,false);
  if v_prior_valid and v_preview->>'prior_hardening_snapshot_id' is not null then
    select * into v_prior
    from fwios.candidate_quality_hardening_snapshots
    where hardening_snapshot_id=v_preview->>'prior_hardening_snapshot_id';
  end if;

  insert into fwios.candidate_quality_hardening_snapshots(
    hardening_snapshot_id,ticker,valuation_run_id,mispricing_snapshot_id,policy_version_id,
    business_durability_gate,owner_earnings_gate,value_trap_gate,valuation_robustness_gate,overall_gate,
    valuation_confidence,sbc_to_revenue,bear_upside,base_upside,probability_weighted_upside,
    durability_anchor_years,durability_evidence_count,dilution_reconciliation_pass,owner_fcf_conversion_pass,
    counter_thesis_evidence_count,structural_risk_review_pass,growth_anchor_verified,evidence_payload,source_reference
  ) values (
    v_hardening_snapshot_id,v_ticker,v_valuation.run_id,v_mispricing_snapshot_id,'POL-QUALITY-HARDENING-V1',
    v_preview->'projected'->>'business_durability_gate',
    v_preview->'projected'->>'owner_earnings_gate',
    v_preview->'projected'->>'value_trap_gate',
    v_preview->'projected'->>'valuation_robustness_gate',
    v_preview->'projected'->>'overall_gate',
    (v_preview->'projected'->>'valuation_confidence')::numeric,
    case when v_prior_valid then v_prior.sbc_to_revenue else null end,
    (v_preview->'mispricing'->>'bear_upside')::numeric,
    (v_preview->'mispricing'->>'base_upside')::numeric,
    (v_preview->'mispricing'->>'probability_weighted_upside')::numeric,
    case when v_prior_valid then v_prior.durability_anchor_years else null end,
    case when v_prior_valid then v_prior.durability_evidence_count else 0 end,
    case when v_prior_valid then v_prior.dilution_reconciliation_pass else null end,
    case when v_prior_valid then v_prior.owner_fcf_conversion_pass else null end,
    case when v_prior_valid then v_prior.counter_thesis_evidence_count else 0 end,
    case when v_prior_valid then v_prior.structural_risk_review_pass else null end,
    case when v_prior_valid then v_prior.growth_anchor_verified else null end,
    jsonb_build_object(
      'refresh_policy','POL-QUALITY-HARDENING-REFRESH-V1',
      'hardening_policy','POL-QUALITY-HARDENING-V1',
      'valuation_run_id',v_valuation.run_id,
      'canonical_daily_close_session',v_price.session_date,
      'canonical_market_observation_id',v_price.primary_observation_id,
      'canonical_market_verification_id',v_price.market_verification_id,
      'compatibility_price_snapshot_id',v_price_snapshot_id,
      'mispricing_snapshot_id',v_mispricing_snapshot_id,
      'prior_hardening_snapshot_id',case when v_prior_valid then v_prior.hardening_snapshot_id else null end,
      'prior_evidence_carry_forward_valid',v_prior_valid,
      'shadow_evidence_used_for_production_gate',false,
      'human_execution_only',true,
      'auto_trade',false
    ),
    'POL-QUALITY-HARDENING-REFRESH-V1:'||v_valuation.run_id||':'||v_price.market_verification_id
  );

  select artifact_id into v_valuation_artifact_id
  from fwios.lineage_artifacts
  where artifact_key='VALUATION:'||v_valuation.run_id
    and artifact_type='VALUATION_RUN';

  insert into fwios.lineage_artifacts(
    artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
  ) values (
    'HARDENING:'||v_hardening_snapshot_id,
    'HARDENING_SNAPSHOT','fwios','candidate_quality_hardening_snapshots',v_hardening_snapshot_id,
    v_price.instrument_id,'RESOLVED',
    jsonb_build_object(
      'ticker',v_ticker,
      'valuation_run_id',v_valuation.run_id,
      'mispricing_snapshot_id',v_mispricing_snapshot_id,
      'refresh_policy','POL-QUALITY-HARDENING-REFRESH-V1'
    )
  )
  on conflict(artifact_key) do nothing;

  select artifact_id into v_hardening_artifact_id
  from fwios.lineage_artifacts
  where artifact_key='HARDENING:'||v_hardening_snapshot_id;

  if v_valuation_artifact_id is null or v_hardening_artifact_id is null then
    raise exception 'QUALITY_HARDENING_REFRESH_LINEAGE_ARTIFACT_MISSING';
  end if;

  insert into fwios.lineage_edges(
    from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
  )
  select
    v_valuation_artifact_id,v_hardening_artifact_id,
    'VALUATION_SUPPORTS_HARDENING','VALUATION_RUN','RESOLVED',
    'POL-QUALITY-HARDENING-REFRESH-V1',
    jsonb_build_object(
      'price_snapshot_id',v_price_snapshot_id,
      'mispricing_snapshot_id',v_mispricing_snapshot_id,
      'canonical_market_verification_id',v_price.market_verification_id
    )
  where not exists (
    select 1 from fwios.lineage_edges e
    where e.from_artifact_id=v_valuation_artifact_id
      and e.to_artifact_id=v_hardening_artifact_id
      and e.edge_type='VALUATION_SUPPORTS_HARDENING'
      and e.edge_role='VALUATION_RUN'
  );

  return jsonb_build_object(
    'status','APPLIED','ticker',v_ticker,'valuation_run_id',v_valuation.run_id,
    'price_snapshot_id',v_price_snapshot_id,'mispricing_snapshot_id',v_mispricing_snapshot_id,
    'hardening_snapshot_id',v_hardening_snapshot_id,
    'overall_gate',v_preview->'projected'->>'overall_gate',
    'projected',v_preview->'projected',
    'portfolio_mutation',false,'approval_mutation',false,'execution_mutation',false,
    'auto_trade',false,'human_execution_only',true
  );
end;
$$;

revoke all on function fwios.preview_quality_hardening_refresh_v1(text) from public,anon,authenticated;
revoke all on function fwios.apply_quality_hardening_refresh_v1(text,boolean) from public,anon,authenticated;
grant execute on function fwios.preview_quality_hardening_refresh_v1(text) to service_role;
grant execute on function fwios.apply_quality_hardening_refresh_v1(text,boolean) to service_role;
