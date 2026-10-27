-- FWIOS MVP-1 Decision / Ranking Refresh Bridge v1
-- Live migration: 20261027033605_decision_ranking_refresh_bridge_v1
-- Append-only, fail-closed downstream lineage repair.
-- No valuation, mispricing, quality-hardening, scoring, revision/chase,
-- portfolio-fit, or ranking thresholds are changed.

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status,updated_at
) values (
  'DECISION_RANKING_REFRESH_BRIDGE',
  'DECISION',
  'Decision Ranking Refresh Bridge v1',
  'Refresh stale Decision Snapshot lineage from current production valuation/mispricing/hardening while preserving existing core/revision/chase semantics and fail-closing stale or missing portfolio-fit dependencies; refresh Opportunity Ranking as an auditable snapshot without reactivating a retired ranking policy.',
  'fwios.apply_decision_refresh_bridge_v1',
  'ACTIVE',
  now()
)
on conflict(policy_key) do update set
  policy_domain=excluded.policy_domain,
  policy_name=excluded.policy_name,
  purpose=excluded.purpose,
  backing_object=excluded.backing_object,
  lifecycle_status='ACTIVE',
  updated_at=now();

insert into fwios.policy_versions(
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,
  config,source_reference,effective_at
) values (
  'POL-DECISION-RANKING-REFRESH-BRIDGE-V1',
  'DECISION_RANKING_REFRESH_BRIDGE',
  '1.0',
  'ACTIVE',
  true,
  jsonb_build_object(
    'current_valuation_required',true,
    'current_hardening_required',true,
    'existing_core_score_semantics_preserved',true,
    'portfolio_fit_missing_policy','BLOCK',
    'portfolio_fit_stale_policy','ALLOW_AUDIT_DECISION_BUT_BLOCK_INPUT_INTEGRITY_AND_PROMOTION',
    'revision_chase_semantics','PRESERVE_LATEST_SNAPSHOTS_FAIL_CLOSED',
    'historical_snapshots_immutable',true,
    'ranking_policy_lifecycle_respected',true,
    'reactivate_retired_ranking_policy',false,
    'valuation_threshold_changes',false,
    'hardening_threshold_changes',false,
    'portfolio_mutation',false,
    'approval_mutation',false,
    'execution_mutation',false,
    'human_execution_only',true,
    'auto_trade',false
  ),
  'FWIOS MVP-1 Decision / Ranking lineage refresh 2026-10-27',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status='ACTIVE',
  deterministic_scoring=true,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

CREATE OR REPLACE FUNCTION fwios.preview_decision_refresh_bridge_v1(p_ticker text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_ticker text := upper(btrim(coalesce(p_ticker,'')));
  v_val fwios.valuation_runs%rowtype;
  v_hard fwios.candidate_quality_hardening_snapshots%rowtype;
  v_mis fwios.valuation_mispricing_snapshots%rowtype;
  v_fit fwios.candidate_portfolio_fit_snapshots%rowtype;
  v_base fwios.candidate_decision_scores%rowtype;
  v_rev fwios.candidate_revision_snapshots%rowtype;
  v_chase fwios.candidate_chase_snapshots%rowtype;
  v_score_policy fwios.data_scoring_policies%rowtype;
  v_current_batch text;
  v_rc_business numeric;
  v_rc_downside numeric;
  v_expected numeric;
  v_core numeric;
  v_portfolio_gate text;
  v_revision_gate text;
  v_chase_gate text;
  v_core_gate text;
  v_input_gate text;
  v_promotion_gate text;
  v_decision_state text;
  v_hash text;
  v_score_id text;
  v_decision_id text;
  v_latest_score_id text;
  v_latest_decision_id text;
begin
  if v_ticker='' then
    return jsonb_build_object(
      'refresh_status','BLOCKED','reason','TICKER_REQUIRED',
      'policy_version_id','POL-DECISION-RANKING-REFRESH-BRIDGE-V1',
      'production_changes','NONE','auto_trade',false,'human_execution_only',true
    );
  end if;

  select * into v_val
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
      'refresh_status','BLOCKED','reason','CURRENT_PRODUCTION_VALUATION_NOT_FOUND',
      'ticker',v_ticker,'production_changes','NONE','auto_trade',false
    );
  end if;

  select * into v_hard
  from fwios.candidate_quality_hardening_snapshots
  where ticker=v_ticker
  order by created_at desc,hardening_snapshot_id desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'refresh_status','BLOCKED','reason','CURRENT_HARDENING_SNAPSHOT_NOT_FOUND',
      'ticker',v_ticker,'valuation_run_id',v_val.run_id,
      'production_changes','NONE','auto_trade',false
    );
  end if;

  if v_hard.valuation_run_id is distinct from v_val.run_id then
    return jsonb_build_object(
      'refresh_status','BLOCKED','reason','HARDENING_NOT_ALIGNED_TO_CURRENT_VALUATION',
      'ticker',v_ticker,'valuation_run_id',v_val.run_id,
      'hardening_snapshot_id',v_hard.hardening_snapshot_id,
      'hardening_valuation_run_id',v_hard.valuation_run_id,
      'production_changes','NONE','auto_trade',false
    );
  end if;

  select * into v_mis
  from fwios.valuation_mispricing_snapshots
  where mispricing_snapshot_id=v_hard.mispricing_snapshot_id
    and valuation_run_id=v_val.run_id
    and ticker=v_ticker;

  if not found then
    return jsonb_build_object(
      'refresh_status','BLOCKED','reason','CURRENT_HARDENING_MISPRICING_NOT_FOUND',
      'ticker',v_ticker,'valuation_run_id',v_val.run_id,
      'hardening_snapshot_id',v_hard.hardening_snapshot_id,
      'production_changes','NONE','auto_trade',false
    );
  end if;

  select batch_id into v_current_batch
  from fwios.v_latest_portfolio_batch
  limit 1;

  if v_current_batch is null then
    return jsonb_build_object(
      'refresh_status','BLOCKED','reason','CURRENT_PORTFOLIO_BATCH_NOT_FOUND',
      'ticker',v_ticker,'production_changes','NONE','auto_trade',false
    );
  end if;

  select * into v_fit
  from fwios.candidate_portfolio_fit_snapshots
  where ticker=v_ticker
  order by created_at desc,fit_snapshot_id desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'refresh_status','BLOCKED','reason','PORTFOLIO_FIT_SNAPSHOT_MISSING',
      'ticker',v_ticker,'valuation_run_id',v_val.run_id,
      'hardening_snapshot_id',v_hard.hardening_snapshot_id,
      'hardening_gate',v_hard.overall_gate,
      'current_portfolio_batch_id',v_current_batch,
      'production_changes','NONE','auto_trade',false,'human_execution_only',true
    );
  end if;

  select * into v_base
  from fwios.candidate_decision_scores
  where ticker=v_ticker
  order by created_at desc,score_snapshot_id desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'refresh_status','BLOCKED','reason','BASE_SCORE_SNAPSHOT_MISSING',
      'ticker',v_ticker,'valuation_run_id',v_val.run_id,
      'hardening_snapshot_id',v_hard.hardening_snapshot_id,
      'hardening_gate',v_hard.overall_gate,
      'portfolio_fit_snapshot_id',v_fit.fit_snapshot_id,
      'portfolio_fit_batch_id',v_fit.portfolio_batch_id,
      'current_portfolio_batch_id',v_current_batch,
      'production_changes','NONE','auto_trade',false,'human_execution_only',true
    );
  end if;

  if v_base.portfolio_fit_snapshot_id is distinct from v_fit.fit_snapshot_id then
    return jsonb_build_object(
      'refresh_status','BLOCKED','reason','BASE_SCORE_NOT_ALIGNED_TO_LATEST_PORTFOLIO_FIT',
      'ticker',v_ticker,'base_score_snapshot_id',v_base.score_snapshot_id,
      'base_score_fit_snapshot_id',v_base.portfolio_fit_snapshot_id,
      'latest_fit_snapshot_id',v_fit.fit_snapshot_id,
      'production_changes','NONE','auto_trade',false
    );
  end if;

  select * into v_score_policy
  from fwios.data_scoring_policies
  where active=true
  order by updated_at desc,created_at desc
  limit 1;

  if not found
     or v_score_policy.policy_id is distinct from 'FWB-DATA-SCORING-V3-DURABILITY'
     or v_base.scoring_policy_id is distinct from v_score_policy.policy_id
  then
    return jsonb_build_object(
      'refresh_status','BLOCKED','reason','ACTIVE_SCORING_POLICY_BASELINE_MISMATCH',
      'ticker',v_ticker,'base_score_snapshot_id',v_base.score_snapshot_id,
      'base_scoring_policy_id',v_base.scoring_policy_id,
      'active_scoring_policy_id',v_score_policy.policy_id,
      'production_changes','NONE','auto_trade',false
    );
  end if;

  select business_thesis_score,downside_risk_score
    into v_rc_business,v_rc_downside
  from fwios.research_candidates
  where ticker=v_ticker;

  if v_rc_business is null or v_rc_downside is null
     or v_base.business_thesis_score is distinct from v_rc_business
     or v_base.downside_risk_score is distinct from v_rc_downside
  then
    return jsonb_build_object(
      'refresh_status','BLOCKED','reason','CORE_RESEARCH_SCORE_CHANGED_OR_MISSING',
      'ticker',v_ticker,'base_score_snapshot_id',v_base.score_snapshot_id,
      'production_changes','NONE','auto_trade',false
    );
  end if;

  select * into v_rev
  from fwios.candidate_revision_snapshots
  where ticker=v_ticker
  order by created_at desc,revision_snapshot_id desc
  limit 1;

  select * into v_chase
  from fwios.candidate_chase_snapshots
  where ticker=v_ticker
  order by created_at desc,chase_snapshot_id desc
  limit 1;

  v_expected := fwios.expected_return_score_v3(
    v_mis.base_upside,
    v_mis.probability_weighted_upside,
    v_hard.valuation_confidence
  );

  if v_expected is null then
    return jsonb_build_object(
      'refresh_status','BLOCKED','reason','EXPECTED_RETURN_SCORE_NOT_COMPUTABLE',
      'ticker',v_ticker,'production_changes','NONE','auto_trade',false
    );
  end if;

  v_core := round(
    v_base.business_thesis_score*v_score_policy.business_thesis_weight
    + v_expected*v_score_policy.expected_return_weight
    + v_fit.portfolio_fit_score*v_score_policy.portfolio_fit_weight
    + v_base.downside_risk_score*v_score_policy.downside_risk_weight
  ,4);

  v_portfolio_gate := case
    when v_fit.portfolio_batch_id is distinct from v_current_batch
      then 'BLOCKED - STALE PORTFOLIO FIT'
    when v_fit.portfolio_fit_gate='PASS' then 'PASS'
    else coalesce(v_fit.portfolio_fit_gate,'BLOCKED - PORTFOLIO FIT')
  end;

  v_revision_gate := coalesce(v_rev.revision_gate,'BLOCKED - REVISION SNAPSHOT MISSING');
  v_chase_gate := coalesce(v_chase.chase_gate,'BLOCKED - CHASE SNAPSHOT MISSING');

  v_core_gate := case
    when v_base.quality_gate<>'PASS' then v_base.quality_gate
    when v_val.valuation_gate<>'PASS' then v_val.valuation_gate
    when v_portfolio_gate<>'PASS' then v_portfolio_gate
    when v_base.downside_gate<>'PASS' then v_base.downside_gate
    else 'PASS'
  end;

  v_input_gate := case
    when v_fit.portfolio_batch_id is distinct from v_current_batch then 'BLOCKED - STALE PORTFOLIO FIT'
    when v_revision_gate like 'BLOCKED%' then v_revision_gate
    when v_chase_gate like 'BLOCKED%' then v_chase_gate
    else 'PASS'
  end;

  v_promotion_gate := case
    when v_hard.overall_gate='FAIL' then 'FAIL - QUALITY HARDENING'
    when v_hard.overall_gate<>'PASS' then 'BLOCKED - QUALITY HARDENING'
    when v_core_gate<>'PASS' then v_core_gate
    when v_input_gate<>'PASS' then v_input_gate
    when v_mis.mispricing_gate<>'PASS' then v_mis.mispricing_gate
    when v_revision_gate<>'PASS' then v_revision_gate
    when v_chase_gate<>'PASS' then v_chase_gate
    else 'PASS'
  end;

  v_decision_state := case
    when v_hard.overall_gate='FAIL' then 'FAIL - QUALITY HARDENING'
    when v_hard.overall_gate='REVIEW' then 'REVIEW - QUALITY HARDENING'
    when v_hard.overall_gate='BLOCKED' then 'BLOCKED - QUALITY HARDENING'
    when v_input_gate<>'PASS' then 'DATA BLOCKED'
    when v_promotion_gate='PASS' then 'READY FOR HUMAN REVIEW'
    when v_mis.mispricing_gate='FAIL - INSUFFICIENT MISPRICING' then 'WAIT - MISPRICING'
    when v_revision_gate<>'PASS' then 'WAIT - REVISION'
    when v_chase_gate<>'PASS' then 'WAIT - CHASE RISK'
    else 'WATCHLIST ONLY'
  end;

  v_hash := substr(md5(
    concat_ws('|',
      v_ticker,v_val.run_id,v_hard.hardening_snapshot_id,v_mis.mispricing_snapshot_id,
      v_fit.fit_snapshot_id,coalesce(v_rev.revision_snapshot_id,'NONE'),
      coalesce(v_chase.chase_snapshot_id,'NONE'),v_score_policy.policy_id
    )
  ),1,16);

  v_score_id := 'SCORE-DRB-'||v_ticker||'-'||v_hash;
  v_decision_id := 'DEC-DRB-'||v_ticker||'-'||v_hash;

  select score_snapshot_id into v_latest_score_id
  from fwios.candidate_decision_scores
  where ticker=v_ticker
  order by created_at desc,score_snapshot_id desc
  limit 1;

  select decision_snapshot_id into v_latest_decision_id
  from fwios.decision_snapshots
  where ticker=v_ticker
  order by created_at desc,decision_snapshot_id desc
  limit 1;

  return jsonb_build_object(
    'refresh_status','READY_TO_APPLY',
    'policy_version_id','POL-DECISION-RANKING-REFRESH-BRIDGE-V1',
    'ticker',v_ticker,
    'current_upstream',jsonb_build_object(
      'valuation_run_id',v_val.run_id,
      'mispricing_snapshot_id',v_mis.mispricing_snapshot_id,
      'price_snapshot_id',v_mis.price_snapshot_id,
      'hardening_snapshot_id',v_hard.hardening_snapshot_id,
      'hardening_gate',v_hard.overall_gate,
      'valuation_confidence',v_hard.valuation_confidence
    ),
    'core_baseline',jsonb_build_object(
      'base_score_snapshot_id',v_base.score_snapshot_id,
      'scoring_policy_id',v_score_policy.policy_id,
      'business_thesis_score',v_base.business_thesis_score,
      'portfolio_fit_score',v_fit.portfolio_fit_score,
      'downside_risk_score',v_base.downside_risk_score,
      'quality_gate',v_base.quality_gate,
      'downside_gate',v_base.downside_gate
    ),
    'portfolio_fit',jsonb_build_object(
      'fit_snapshot_id',v_fit.fit_snapshot_id,
      'fit_snapshot_batch_id',v_fit.portfolio_batch_id,
      'current_portfolio_batch_id',v_current_batch,
      'fit_gate',v_fit.portfolio_fit_gate,
      'freshness_gate',v_portfolio_gate
    ),
    'revision_chase',jsonb_build_object(
      'revision_snapshot_id',v_rev.revision_snapshot_id,
      'revision_gate',v_revision_gate,
      'chase_snapshot_id',v_chase.chase_snapshot_id,
      'chase_gate',v_chase_gate
    ),
    'computed',jsonb_build_object(
      'business_thesis_score',v_base.business_thesis_score,
      'expected_return_score',v_expected,
      'portfolio_fit_score',v_fit.portfolio_fit_score,
      'downside_risk_score',v_base.downside_risk_score,
      'core_score',v_core,
      'quality_gate',v_base.quality_gate,
      'valuation_gate',v_val.valuation_gate,
      'mispricing_gate',v_mis.mispricing_gate,
      'portfolio_gate',v_portfolio_gate,
      'downside_gate',v_base.downside_gate,
      'revision_gate',v_revision_gate,
      'chase_gate',v_chase_gate,
      'core_scoring_gate',v_core_gate,
      'hardening_gate',v_hard.overall_gate,
      'promotion_gate',v_promotion_gate,
      'decision_state',v_decision_state,
      'input_integrity_gate',v_input_gate
    ),
    'prior_latest',jsonb_build_object(
      'score_snapshot_id',v_latest_score_id,
      'decision_snapshot_id',v_latest_decision_id
    ),
    'proposed_ids',jsonb_build_object(
      'score_snapshot_id',v_score_id,
      'decision_snapshot_id',v_decision_id
    ),
    'stale_portfolio_fit_allowed_only_for_blocked_audit_decision',
      (v_fit.portfolio_batch_id is distinct from v_current_batch),
    'human_authorization_required',true,
    'portfolio_mutation',false,
    'approval_mutation',false,
    'execution_mutation',false,
    'auto_trade',false,
    'production_changes','PREVIEW_NONE'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION fwios.apply_decision_refresh_bridge_v1(p_ticker text, p_human_authorized boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_preview jsonb;
  v_ticker text;
  v_score_id text;
  v_decision_id text;
  v_existing_score fwios.candidate_decision_scores%rowtype;
  v_existing_decision fwios.decision_snapshots%rowtype;
  v_decision_artifact_id uuid;
  v_val_artifact_id uuid;
  v_hard_artifact_id uuid;
  v_rev_artifact_id uuid;
  v_instrument_id uuid;
begin
  if not coalesce(p_human_authorized,false) then
    return jsonb_build_object(
      'status','BLOCKED','reason','HUMAN_AUTHORIZATION_REQUIRED',
      'production_changes','NONE','auto_trade',false,'human_execution_only',true
    );
  end if;

  v_preview := fwios.preview_decision_refresh_bridge_v1(p_ticker);
  if coalesce(v_preview->>'refresh_status','BLOCKED')<>'READY_TO_APPLY' then
    return jsonb_build_object(
      'status','BLOCKED','reason','REFRESH_PREVIEW_NOT_READY',
      'preview',v_preview,'production_changes','NONE',
      'auto_trade',false,'human_execution_only',true
    );
  end if;

  v_ticker := v_preview->>'ticker';
  v_score_id := v_preview->'proposed_ids'->>'score_snapshot_id';
  v_decision_id := v_preview->'proposed_ids'->>'decision_snapshot_id';

  select * into v_existing_decision
  from fwios.decision_snapshots
  where decision_snapshot_id=v_decision_id;

  if found then
    if v_existing_decision.ticker=v_ticker
       and v_existing_decision.valuation_run_id=v_preview->'current_upstream'->>'valuation_run_id'
       and v_existing_decision.hardening_snapshot_id=v_preview->'current_upstream'->>'hardening_snapshot_id'
       and v_existing_decision.mispricing_snapshot_id=v_preview->'current_upstream'->>'mispricing_snapshot_id'
    then
      return jsonb_build_object(
        'status','NOOP_ALREADY_REFRESHED','ticker',v_ticker,
        'score_snapshot_id',v_existing_decision.score_snapshot_id,
        'decision_snapshot_id',v_decision_id,
        'decision_state',v_existing_decision.decision_state,
        'promotion_gate',v_existing_decision.promotion_gate,
        'input_integrity_gate',v_existing_decision.input_integrity_gate,
        'production_changes','NONE',
        'auto_trade',false,'human_execution_only',true
      );
    end if;
    raise exception 'DECISION_REFRESH_ID_COLLISION';
  end if;

  select * into v_existing_score
  from fwios.candidate_decision_scores
  where ticker=v_ticker
    and scoring_policy_id=v_preview->'core_baseline'->>'scoring_policy_id'
    and mispricing_snapshot_id=v_preview->'current_upstream'->>'mispricing_snapshot_id'
    and portfolio_fit_snapshot_id=v_preview->'portfolio_fit'->>'fit_snapshot_id'
  limit 1;

  if found then
    if v_existing_score.valuation_run_id is distinct from v_preview->'current_upstream'->>'valuation_run_id'
       or v_existing_score.hardening_snapshot_id is distinct from v_preview->'current_upstream'->>'hardening_snapshot_id'
    then
      raise exception 'DECISION_REFRESH_EXISTING_SCORE_LINEAGE_CONFLICT';
    end if;
    v_score_id := v_existing_score.score_snapshot_id;
  else
    insert into fwios.candidate_decision_scores(
      score_snapshot_id,ticker,scoring_policy_id,valuation_run_id,mispricing_snapshot_id,
      portfolio_fit_snapshot_id,business_thesis_score,expected_return_score,
      portfolio_fit_score,downside_risk_score,core_score,
      quality_gate,valuation_gate,mispricing_gate,portfolio_gate,downside_gate,
      revision_gate,chase_gate,core_scoring_gate,promotion_gate,decision_state,
      decision_note,source_reference,hardening_snapshot_id,valuation_confidence,hardening_gate
    ) values (
      v_score_id,
      v_ticker,
      v_preview->'core_baseline'->>'scoring_policy_id',
      v_preview->'current_upstream'->>'valuation_run_id',
      v_preview->'current_upstream'->>'mispricing_snapshot_id',
      v_preview->'portfolio_fit'->>'fit_snapshot_id',
      (v_preview->'computed'->>'business_thesis_score')::numeric,
      (v_preview->'computed'->>'expected_return_score')::numeric,
      (v_preview->'computed'->>'portfolio_fit_score')::numeric,
      (v_preview->'computed'->>'downside_risk_score')::numeric,
      (v_preview->'computed'->>'core_score')::numeric,
      v_preview->'computed'->>'quality_gate',
      v_preview->'computed'->>'valuation_gate',
      v_preview->'computed'->>'mispricing_gate',
      v_preview->'computed'->>'portfolio_gate',
      v_preview->'computed'->>'downside_gate',
      v_preview->'computed'->>'revision_gate',
      v_preview->'computed'->>'chase_gate',
      v_preview->'computed'->>'core_scoring_gate',
      v_preview->'computed'->>'promotion_gate',
      v_preview->'computed'->>'decision_state',
      'Decision/Ranking Refresh Bridge v1: current valuation/mispricing/hardening; legacy core semantics preserved; stale portfolio fit is explicit and fail-closed.',
      'POL-DECISION-RANKING-REFRESH-BRIDGE-V1:'||
        (v_preview->'current_upstream'->>'valuation_run_id')||':'||
        (v_preview->'current_upstream'->>'hardening_snapshot_id'),
      v_preview->'current_upstream'->>'hardening_snapshot_id',
      (v_preview->'current_upstream'->>'valuation_confidence')::numeric,
      v_preview->'computed'->>'hardening_gate'
    );
  end if;

  insert into fwios.decision_snapshots(
    decision_snapshot_id,ticker,portfolio_batch_id,price_snapshot_id,valuation_run_id,
    mispricing_snapshot_id,portfolio_fit_snapshot_id,revision_snapshot_id,chase_snapshot_id,
    score_snapshot_id,scoring_policy_version_id,revision_policy_version_id,chase_policy_version_id,
    core_score,decision_state,promotion_gate,input_integrity_gate,decision_payload,hardening_snapshot_id
  ) values (
    v_decision_id,
    v_ticker,
    v_preview->'portfolio_fit'->>'fit_snapshot_batch_id',
    v_preview->'current_upstream'->>'price_snapshot_id',
    v_preview->'current_upstream'->>'valuation_run_id',
    v_preview->'current_upstream'->>'mispricing_snapshot_id',
    v_preview->'portfolio_fit'->>'fit_snapshot_id',
    nullif(v_preview->'revision_chase'->>'revision_snapshot_id',''),
    nullif(v_preview->'revision_chase'->>'chase_snapshot_id',''),
    v_score_id,
    'POL-DATA-SCORING-V3-DURABILITY',
    case when nullif(v_preview->'revision_chase'->>'revision_snapshot_id','') is not null
      then 'POL-REVISION-SCORE-V2-CROSS-SECTOR' else null end,
    case when nullif(v_preview->'revision_chase'->>'chase_snapshot_id','') is not null
      then 'POL-CHASE-SCORE-V2-CROSS-SECTOR' else null end,
    (v_preview->'computed'->>'core_score')::numeric,
    v_preview->'computed'->>'decision_state',
    v_preview->'computed'->>'promotion_gate',
    v_preview->'computed'->>'input_integrity_gate',
    jsonb_build_object(
      'bridge_policy','POL-DECISION-RANKING-REFRESH-BRIDGE-V1',
      'current_valuation_run_id',v_preview->'current_upstream'->>'valuation_run_id',
      'current_mispricing_snapshot_id',v_preview->'current_upstream'->>'mispricing_snapshot_id',
      'current_hardening_snapshot_id',v_preview->'current_upstream'->>'hardening_snapshot_id',
      'hardening_gate',v_preview->'computed'->>'hardening_gate',
      'fit_snapshot_id',v_preview->'portfolio_fit'->>'fit_snapshot_id',
      'fit_snapshot_batch_id',v_preview->'portfolio_fit'->>'fit_snapshot_batch_id',
      'current_portfolio_batch_id',v_preview->'portfolio_fit'->>'current_portfolio_batch_id',
      'portfolio_fit_freshness_gate',v_preview->'portfolio_fit'->>'freshness_gate',
      'revision_snapshot_id',v_preview->'revision_chase'->>'revision_snapshot_id',
      'revision_gate',v_preview->'revision_chase'->>'revision_gate',
      'chase_snapshot_id',v_preview->'revision_chase'->>'chase_snapshot_id',
      'chase_gate',v_preview->'revision_chase'->>'chase_gate',
      'historical_snapshots_rewritten',false,
      'valuation_threshold_changes',false,
      'hardening_threshold_changes',false,
      'portfolio_mutation',false,
      'approval_mutation',false,
      'execution_mutation',false,
      'human_execution_only',true,
      'auto_trade',false
    ),
    v_preview->'current_upstream'->>'hardening_snapshot_id'
  );

  v_instrument_id := fwios.resolve_instrument_id_v1(v_ticker,'Stock',null,null);

  insert into fwios.lineage_artifacts(
    artifact_key,artifact_type,object_schema,object_table,object_key,
    instrument_id,resolution_status,metadata
  ) values (
    'DECISION:'||v_decision_id,
    'DECISION_SNAPSHOT','fwios','decision_snapshots',v_decision_id,
    v_instrument_id,'RESOLVED',
    jsonb_build_object(
      'ticker',v_ticker,
      'decision_state',v_preview->'computed'->>'decision_state',
      'promotion_gate',v_preview->'computed'->>'promotion_gate',
      'core_score',(v_preview->'computed'->>'core_score')::numeric,
      'bridge_policy','POL-DECISION-RANKING-REFRESH-BRIDGE-V1'
    )
  )
  on conflict(artifact_key) do nothing;

  select artifact_id into v_decision_artifact_id
  from fwios.lineage_artifacts
  where artifact_key='DECISION:'||v_decision_id;

  select artifact_id into v_val_artifact_id
  from fwios.lineage_artifacts
  where artifact_key='VALUATION:'||(v_preview->'current_upstream'->>'valuation_run_id');

  select artifact_id into v_hard_artifact_id
  from fwios.lineage_artifacts
  where artifact_key='HARDENING:'||(v_preview->'current_upstream'->>'hardening_snapshot_id');

  if v_decision_artifact_id is null or v_val_artifact_id is null or v_hard_artifact_id is null then
    raise exception 'DECISION_REFRESH_REQUIRED_LINEAGE_ARTIFACT_MISSING';
  end if;

  insert into fwios.lineage_edges(
    from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
  )
  select v_val_artifact_id,v_decision_artifact_id,
         'VALUATION_SUPPORTS_DECISION','VALUATION_RUN','RESOLVED',
         'POL-DECISION-RANKING-REFRESH-BRIDGE-V1',
         jsonb_build_object('mispricing_snapshot_id',v_preview->'current_upstream'->>'mispricing_snapshot_id')
  where not exists(
    select 1 from fwios.lineage_edges
    where from_artifact_id=v_val_artifact_id and to_artifact_id=v_decision_artifact_id
      and edge_type='VALUATION_SUPPORTS_DECISION' and edge_role='VALUATION_RUN'
  );

  insert into fwios.lineage_edges(
    from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
  )
  select v_hard_artifact_id,v_decision_artifact_id,
         'HARDENING_SUPPORTS_DECISION','HARDENING_SNAPSHOT','RESOLVED',
         'POL-DECISION-RANKING-REFRESH-BRIDGE-V1',
         jsonb_build_object('hardening_gate',v_preview->'computed'->>'hardening_gate')
  where not exists(
    select 1 from fwios.lineage_edges
    where from_artifact_id=v_hard_artifact_id and to_artifact_id=v_decision_artifact_id
      and edge_type='HARDENING_SUPPORTS_DECISION' and edge_role='HARDENING_SNAPSHOT'
  );

  if nullif(v_preview->'revision_chase'->>'revision_snapshot_id','') is not null then
    insert into fwios.lineage_artifacts(
      artifact_key,artifact_type,object_schema,object_table,object_key,
      instrument_id,resolution_status,metadata
    )
    select
      'REVISION:'||r.revision_snapshot_id,
      'REVISION_SNAPSHOT','fwios','candidate_revision_snapshots',r.revision_snapshot_id,
      v_instrument_id,'RESOLVED',
      jsonb_build_object('ticker',r.ticker,'revision_score',r.revision_score,'revision_gate',r.revision_gate)
    from fwios.candidate_revision_snapshots r
    where r.revision_snapshot_id=v_preview->'revision_chase'->>'revision_snapshot_id'
    on conflict(artifact_key) do nothing;

    select artifact_id into v_rev_artifact_id
    from fwios.lineage_artifacts
    where artifact_key='REVISION:'||(v_preview->'revision_chase'->>'revision_snapshot_id');

    if v_rev_artifact_id is not null then
      insert into fwios.lineage_edges(
        from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
      )
      select v_rev_artifact_id,v_decision_artifact_id,
             'REVISION_SUPPORTS_DECISION','REVISION_SNAPSHOT','RESOLVED',
             'POL-DECISION-RANKING-REFRESH-BRIDGE-V1','{}'::jsonb
      where not exists(
        select 1 from fwios.lineage_edges
        where from_artifact_id=v_rev_artifact_id and to_artifact_id=v_decision_artifact_id
          and edge_type='REVISION_SUPPORTS_DECISION' and edge_role='REVISION_SNAPSHOT'
      );
    end if;
  end if;

  return jsonb_build_object(
    'status','APPLIED','ticker',v_ticker,
    'score_snapshot_id',v_score_id,
    'decision_snapshot_id',v_decision_id,
    'decision_state',v_preview->'computed'->>'decision_state',
    'hardening_gate',v_preview->'computed'->>'hardening_gate',
    'promotion_gate',v_preview->'computed'->>'promotion_gate',
    'input_integrity_gate',v_preview->'computed'->>'input_integrity_gate',
    'portfolio_fit_freshness_gate',v_preview->'portfolio_fit'->>'freshness_gate',
    'portfolio_mutation',false,'approval_mutation',false,'execution_mutation',false,
    'auto_trade',false,'human_execution_only',true
  );
end;
$function$;

CREATE OR REPLACE FUNCTION fwios.preview_opportunity_ranking_refresh_bridge_v1(p_tickers text[] DEFAULT ARRAY['ACN'::text, 'EOG'::text, 'NFLX'::text, 'PINS'::text])
 RETURNS TABLE(ticker text, decision_snapshot_id text, score_snapshot_id text, decision_lineage_gate text, portfolio_fit_freshness_gate text, ranking_policy_status text, proposed_bucket text, proposed_eligibility_gate text, rationale_code text, priority_score numeric, expected_return_score numeric, portfolio_fit_score numeric, downside_risk_score numeric, business_thesis_score numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
with requested as (
  select distinct upper(btrim(x)) ticker
  from unnest(coalesce(p_tickers,'{}'::text[])) x
  where x is not null and btrim(x)<>''
),
current_batch as (
  select batch_id from fwios.v_latest_portfolio_batch limit 1
),
ranking_policy as (
  select lifecycle_status
  from fwios.policy_versions
  where policy_version_id='POL-OPPORTUNITY-RANKING-V2'
),
latest_decision as (
  select d.*
  from fwios.v_latest_decision_snapshots d
  join requested r using(ticker)
),
base as (
  select
    r.ticker,
    d.decision_snapshot_id,
    d.score_snapshot_id,
    d.input_integrity_gate,
    d.promotion_gate,
    d.valuation_run_id decision_valuation_run_id,
    d.mispricing_snapshot_id decision_mispricing_snapshot_id,
    d.hardening_snapshot_id decision_hardening_snapshot_id,
    d.portfolio_fit_snapshot_id,
    s.valuation_run_id score_valuation_run_id,
    s.mispricing_snapshot_id score_mispricing_snapshot_id,
    s.hardening_snapshot_id score_hardening_snapshot_id,
    s.quality_gate,s.valuation_gate,s.mispricing_gate,s.portfolio_gate,s.downside_gate,
    s.revision_gate,s.chase_gate,s.core_scoring_gate,s.hardening_gate,
    s.core_score,s.expected_return_score,s.portfolio_fit_score,s.downside_risk_score,s.business_thesis_score,
    h.hardening_snapshot_id current_hardening_snapshot_id,
    h.valuation_run_id current_valuation_run_id,
    h.mispricing_snapshot_id current_mispricing_snapshot_id,
    f.portfolio_batch_id fit_batch_id,
    cb.batch_id current_batch_id,
    coalesce(rp.lifecycle_status,'MISSING') ranking_policy_status
  from requested r
  left join latest_decision d using(ticker)
  left join fwios.candidate_decision_scores s on s.score_snapshot_id=d.score_snapshot_id
  left join fwios.v_candidate_quality_hardening_current h on h.ticker=r.ticker
  left join fwios.candidate_portfolio_fit_snapshots f on f.fit_snapshot_id=d.portfolio_fit_snapshot_id
  cross join current_batch cb
  left join ranking_policy rp on true
),
gated as (
  select b.*,
    case
      when b.decision_snapshot_id is null then 'BLOCKED - DECISION SNAPSHOT MISSING'
      when b.score_snapshot_id is null then 'BLOCKED - SCORE SNAPSHOT MISSING'
      when b.current_hardening_snapshot_id is null then 'BLOCKED - CURRENT HARDENING MISSING'
      when b.decision_valuation_run_id is distinct from b.current_valuation_run_id
        or b.decision_mispricing_snapshot_id is distinct from b.current_mispricing_snapshot_id
        or b.decision_hardening_snapshot_id is distinct from b.current_hardening_snapshot_id
        or b.score_valuation_run_id is distinct from b.current_valuation_run_id
        or b.score_mispricing_snapshot_id is distinct from b.current_mispricing_snapshot_id
        or b.score_hardening_snapshot_id is distinct from b.current_hardening_snapshot_id
        then 'BLOCKED - STALE DECISION LINEAGE'
      else 'PASS'
    end decision_lineage_gate,
    case
      when b.portfolio_fit_snapshot_id is null then 'BLOCKED - PORTFOLIO FIT MISSING'
      when b.fit_batch_id is distinct from b.current_batch_id then 'BLOCKED - STALE PORTFOLIO FIT'
      else 'PASS'
    end portfolio_fit_freshness_gate
  from base b
),
classified as (
  select g.*,
    case
      when g.ranking_policy_status<>'ACTIVE' then 'EXCLUDED'
      when g.decision_lineage_gate<>'PASS' then 'EXCLUDED'
      when g.portfolio_fit_freshness_gate<>'PASS' then 'EXCLUDED'
      else fwios.opportunity_bucket_v2(
        g.promotion_gate,g.mispricing_gate,g.quality_gate,g.valuation_gate,g.portfolio_gate,
        g.downside_gate,g.revision_gate,g.chase_gate,g.core_scoring_gate,g.input_integrity_gate,
        g.hardening_gate
      )
    end proposed_bucket
  from gated g
)
select
  c.ticker,c.decision_snapshot_id,c.score_snapshot_id,c.decision_lineage_gate,
  c.portfolio_fit_freshness_gate,c.ranking_policy_status,c.proposed_bucket,
  case
    when c.ranking_policy_status<>'ACTIVE' then 'BLOCKED - RANKING POLICY RETIRED'
    when c.decision_lineage_gate<>'PASS' then c.decision_lineage_gate
    when c.portfolio_fit_freshness_gate<>'PASS' then c.portfolio_fit_freshness_gate
    when c.proposed_bucket='IMMEDIATE_BUY_CANDIDATE' then 'PASS'
    when c.proposed_bucket in ('WATCHLIST_VALUE_WAIT','WATCHLIST_MODEL_REVIEW') then 'PASS - RESEARCH ONLY'
    else 'BLOCKED - DECISION GATES'
  end proposed_eligibility_gate,
  case
    when c.decision_snapshot_id is null then 'DECISION_SNAPSHOT_MISSING'
    when c.decision_lineage_gate='BLOCKED - STALE DECISION LINEAGE' then 'STALE_DECISION_LINEAGE'
    when c.portfolio_fit_freshness_gate='BLOCKED - STALE PORTFOLIO FIT' then 'STALE_PORTFOLIO_FIT'
    when c.ranking_policy_status<>'ACTIVE' then 'RANKING_POLICY_RETIRED'
    when c.hardening_gate='FAIL' then 'QUALITY_HARDENING_FAIL'
    when c.hardening_gate is distinct from 'PASS' then 'QUALITY_HARDENING_REVIEW'
    when c.mispricing_gate='FAIL - INSUFFICIENT MISPRICING' then 'INSUFFICIENT_MISPRICING'
    when c.revision_gate<>'PASS' then 'REVISION_GATE'
    when c.chase_gate<>'PASS' then 'CHASE_GATE'
    else 'PROMOTION_GATE'
  end rationale_code,
  c.core_score,c.expected_return_score,c.portfolio_fit_score,c.downside_risk_score,c.business_thesis_score
from classified c
order by c.ticker;
$function$;

CREATE OR REPLACE FUNCTION fwios.apply_opportunity_ranking_refresh_bridge_v1(p_tickers text[] DEFAULT ARRAY['ACN'::text, 'EOG'::text, 'NFLX'::text, 'PINS'::text], p_human_authorized boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_current_batch text;
  v_policy_status text;
  v_fingerprint text;
  v_run_id text;
  v_existing_status text;
  v_inserted integer := 0;
  v_visible integer := 0;
  v_missing integer := 0;
  v_max_immediate integer := 3;
  v_max_watchlist integer := 5;
begin
  if not coalesce(p_human_authorized,false) then
    return jsonb_build_object(
      'status','BLOCKED','reason','HUMAN_AUTHORIZATION_REQUIRED',
      'production_changes','NONE','auto_trade',false,'human_execution_only',true
    );
  end if;

  if coalesce(array_length(p_tickers,1),0)=0 then
    return jsonb_build_object(
      'status','BLOCKED','reason','TICKERS_REQUIRED',
      'production_changes','NONE','auto_trade',false,'human_execution_only',true
    );
  end if;

  select batch_id into v_current_batch
  from fwios.v_latest_portfolio_batch
  limit 1;

  select lifecycle_status,
         coalesce((config->>'max_immediate')::integer,3),
         coalesce((config->>'max_watchlist')::integer,5)
    into v_policy_status,v_max_immediate,v_max_watchlist
  from fwios.policy_versions
  where policy_version_id='POL-OPPORTUNITY-RANKING-V2';

  if v_current_batch is null or v_policy_status is null then
    return jsonb_build_object(
      'status','BLOCKED','reason','RANKING_CONTEXT_MISSING',
      'current_portfolio_batch_id',v_current_batch,
      'ranking_policy_status',v_policy_status,
      'production_changes','NONE','auto_trade',false
    );
  end if;

  select md5(
    v_current_batch||'|POL-OPPORTUNITY-RANKING-V2|'||v_policy_status||'|'||
    coalesce(string_agg(
      p.ticker||':'||coalesce(p.decision_snapshot_id,'NONE')||':'||
      p.decision_lineage_gate||':'||p.portfolio_fit_freshness_gate||':'||
      p.proposed_bucket||':'||p.proposed_eligibility_gate,
      '|' order by p.ticker
    ),'')
  ),
  count(*) filter(where p.decision_snapshot_id is null)
  into v_fingerprint,v_missing
  from fwios.preview_opportunity_ranking_refresh_bridge_v1(p_tickers) p;

  v_run_id := 'OPPRANK-DRB-'||substr(v_fingerprint,1,16);

  select status into v_existing_status
  from fwios.opportunity_ranking_runs
  where ranking_run_id=v_run_id;

  if found then
    return jsonb_build_object(
      'status','NOOP_ALREADY_REFRESHED',
      'ranking_run_id',v_run_id,
      'ranking_run_status',v_existing_status,
      'ranking_policy_status',v_policy_status,
      'visible_current_count',(select count(*) from fwios.v_opportunity_ranking_current),
      'production_changes','NONE',
      'auto_trade',false,'human_execution_only',true
    );
  end if;

  insert into fwios.opportunity_ranking_runs(
    ranking_run_id,policy_version_id,portfolio_batch_id,status,source_reference,completed_at
  ) values (
    v_run_id,'POL-OPPORTUNITY-RANKING-V2',v_current_batch,'PASS',
    'POL-DECISION-RANKING-REFRESH-BRIDGE-V1; audit refresh over requested tickers; ranking policy lifecycle='||
      v_policy_status||'; retired policy is never reactivated by this bridge.',
    now()
  );

  with p as (
    select *
    from fwios.preview_opportunity_ranking_refresh_bridge_v1(p_tickers)
    where decision_snapshot_id is not null and score_snapshot_id is not null
  ),
  ranked as (
    select p.*,
      case when p.proposed_bucket<>'EXCLUDED'
        then row_number() over(
          partition by p.proposed_bucket
          order by p.priority_score desc,p.expected_return_score desc,
                   p.portfolio_fit_score desc,p.downside_risk_score desc,
                   p.business_thesis_score desc,p.ticker
        )::integer
        else null end raw_rank
    from p
  ),
  capped as (
    select r.*,
      case
        when r.proposed_bucket='IMMEDIATE_BUY_CANDIDATE' and r.raw_rank>v_max_immediate then 'EXCLUDED'
        when r.proposed_bucket in ('WATCHLIST_VALUE_WAIT','WATCHLIST_MODEL_REVIEW') and r.raw_rank>v_max_watchlist then 'EXCLUDED'
        else r.proposed_bucket
      end final_bucket,
      case
        when r.proposed_bucket='IMMEDIATE_BUY_CANDIDATE' and r.raw_rank>v_max_immediate then 'BLOCKED - RANK CAP'
        when r.proposed_bucket in ('WATCHLIST_VALUE_WAIT','WATCHLIST_MODEL_REVIEW') and r.raw_rank>v_max_watchlist then 'BLOCKED - RANK CAP'
        else r.proposed_eligibility_gate
      end final_eligibility,
      case
        when (r.proposed_bucket='IMMEDIATE_BUY_CANDIDATE' and r.raw_rank>v_max_immediate)
          or (r.proposed_bucket in ('WATCHLIST_VALUE_WAIT','WATCHLIST_MODEL_REVIEW') and r.raw_rank>v_max_watchlist)
        then 'RANK_CAP'
        else r.rationale_code
      end final_rationale
    from ranked r
  )
  insert into fwios.opportunity_ranked_candidates(
    ranking_candidate_id,ranking_run_id,ticker,decision_snapshot_id,score_snapshot_id,
    opportunity_bucket,bucket_rank,priority_score,expected_return_score,portfolio_fit_score,
    downside_risk_score,business_thesis_score,eligibility_gate,rationale_code,source_reference
  )
  select
    'RANK-DRB-'||c.ticker||'-'||substr(md5(v_run_id||'|'||c.ticker||'|'||c.decision_snapshot_id),1,14),
    v_run_id,c.ticker,c.decision_snapshot_id,c.score_snapshot_id,
    c.final_bucket,
    case when c.final_bucket='EXCLUDED' then null else c.raw_rank end,
    c.priority_score,c.expected_return_score,c.portfolio_fit_score,
    c.downside_risk_score,c.business_thesis_score,c.final_eligibility,c.final_rationale,
    'POL-DECISION-RANKING-REFRESH-BRIDGE-V1:'||c.decision_lineage_gate||':'||c.portfolio_fit_freshness_gate
  from capped c;

  get diagnostics v_inserted=row_count;

  select count(*) into v_visible
  from fwios.v_opportunity_ranking_current;

  return jsonb_build_object(
    'status','APPLIED',
    'ranking_run_id',v_run_id,
    'ranking_policy_version_id','POL-OPPORTUNITY-RANKING-V2',
    'ranking_policy_status',v_policy_status,
    'ranking_policy_reactivated',false,
    'current_portfolio_batch_id',v_current_batch,
    'candidate_rows_inserted',v_inserted,
    'requested_missing_decision_count',v_missing,
    'visible_current_count',v_visible,
    'portfolio_mutation',false,'approval_mutation',false,'execution_mutation',false,
    'auto_trade',false,'human_execution_only',true
  );
end;
$function$;


revoke all on function fwios.preview_decision_refresh_bridge_v1(text)
  from public,anon,authenticated;
revoke all on function fwios.apply_decision_refresh_bridge_v1(text,boolean)
  from public,anon,authenticated;
revoke all on function fwios.preview_opportunity_ranking_refresh_bridge_v1(text[])
  from public,anon,authenticated;
revoke all on function fwios.apply_opportunity_ranking_refresh_bridge_v1(text[],boolean)
  from public,anon,authenticated;

grant execute on function fwios.preview_decision_refresh_bridge_v1(text) to service_role;
grant execute on function fwios.apply_decision_refresh_bridge_v1(text,boolean) to service_role;
grant execute on function fwios.preview_opportunity_ranking_refresh_bridge_v1(text[]) to service_role;
grant execute on function fwios.apply_opportunity_ranking_refresh_bridge_v1(text[],boolean) to service_role;
