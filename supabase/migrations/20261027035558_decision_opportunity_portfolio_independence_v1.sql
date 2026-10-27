-- FWIOS MVP-1 Portfolio-independent Decision / Opportunity cutover
-- Live migration: 20261027035558 decision_opportunity_portfolio_independence_v1
-- Historical portfolio / fit / ranking records are retained for audit.
-- Valuation and Quality Hardening thresholds are unchanged.
-- auto_trade=false; human execution only.

update fwios.portfolio_fit_policies
set active=false, updated_at=now()
where policy_id='FWB-PORTFOLIO-FIT-V1' and active=true;

update fwios.policy_registry
set lifecycle_status='RETIRED', updated_at=now()
where policy_key in ('PORTFOLIO_FIT','DECISION_RANKING_REFRESH_BRIDGE','OPPORTUNITY_QUALITY_V2');

update fwios.policy_versions
set lifecycle_status='RETIRED'
where policy_version_id in (
  'POL-PORTFOLIO-FIT-V1',
  'POL-DECISION-RANKING-REFRESH-BRIDGE-V1',
  'POL-OPPORTUNITY-QUALITY-V2',
  'POL-DATA-SCORING-V3-DURABILITY'
);

update fwios.data_scoring_policies
set active=false, updated_at=now()
where policy_id='FWB-DATA-SCORING-V3-DURABILITY' and active=true;

alter table fwios.candidate_decision_scores
  alter column portfolio_fit_snapshot_id drop not null,
  alter column portfolio_fit_score drop not null;

alter table fwios.decision_snapshots
  alter column portfolio_batch_id drop not null,
  alter column portfolio_fit_snapshot_id drop not null;

insert into fwios.data_scoring_policies(
  policy_id,business_thesis_weight,expected_return_weight,portfolio_fit_weight,downside_risk_weight,
  quality_gate_min,portfolio_fit_min,chase_risk_max,
  expected_return_base_weight,expected_return_pw_weight,
  mispricing_required,revision_required,chase_required,
  source_reference,active,created_at,updated_at
) values (
  'FWB-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT',
  0.40,0.40,0.00,0.20,
  70,50,60,
  0.60,0.40,
  true,true,true,
  'FWIOS MVP-1 portfolio-independent Decision scoring: legacy 30/30/15 components normalized to 40/40/20; Portfolio Fit retired from discovery/Decision.',
  true,now(),now()
)
on conflict(policy_id) do update set
  business_thesis_weight=excluded.business_thesis_weight,
  expected_return_weight=excluded.expected_return_weight,
  portfolio_fit_weight=0,
  downside_risk_weight=excluded.downside_risk_weight,
  quality_gate_min=excluded.quality_gate_min,
  portfolio_fit_min=excluded.portfolio_fit_min,
  chase_risk_max=excluded.chase_risk_max,
  expected_return_base_weight=excluded.expected_return_base_weight,
  expected_return_pw_weight=excluded.expected_return_pw_weight,
  mispricing_required=excluded.mispricing_required,
  revision_required=excluded.revision_required,
  chase_required=excluded.chase_required,
  source_reference=excluded.source_reference,
  active=true,
  updated_at=now();

update fwios.policy_registry
set lifecycle_status='ACTIVE',
    purpose='40/40/20 portfolio-independent production Decision scoring: Business Thesis / Expected Return / Downside Risk. Portfolio Fit is not scored or gated.',
    backing_object='fwios.data_scoring_policies',
    updated_at=now()
where policy_key='DATA_SCORING';

insert into fwios.policy_versions(
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,
  config,source_reference,effective_at
) values (
  'POL-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT',
  'DATA_SCORING','4.0','ACTIVE',true,
  jsonb_build_object(
    'backing_policy_id','FWB-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT',
    'business_thesis_weight',0.40,
    'expected_return_weight',0.40,
    'portfolio_fit_weight',0,
    'downside_risk_weight',0.20,
    'quality_gate_min',70,
    'chase_risk_max',60,
    'expected_return_base_weight',0.60,
    'expected_return_pw_weight',0.40,
    'portfolio_fit_gate_active',false,
    'portfolio_fit_required',false,
    'valuation_threshold_changes',false,
    'hardening_threshold_changes',false,
    'human_execution_only',true,
    'auto_trade',false
  ),
  'FWIOS MVP-1 Decision scoring v4 portfolio-independent cutover 2026-10-27',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status='ACTIVE',
  deterministic_scoring=true,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status,updated_at
) values (
  'DECISION_OPPORTUNITY_REFRESH_BRIDGE',
  'DECISION',
  'Decision Opportunity Refresh Bridge v2',
  'Refresh current Decision lineage without Portfolio Fit or portfolio batch dependencies, then feed the active portfolio-independent Opportunity Quality path.',
  'fwios.apply_decision_refresh_bridge_v2',
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
  'POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2',
  'DECISION_OPPORTUNITY_REFRESH_BRIDGE',
  '2.0','ACTIVE',true,
  jsonb_build_object(
    'current_valuation_required',true,
    'current_mispricing_alignment_required',true,
    'current_hardening_required',true,
    'portfolio_fit_required',false,
    'portfolio_batch_required',false,
    'scoring_policy','POL-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT',
    'revision_chase_semantics','PRESERVE_LATEST_FAIL_CLOSED',
    'historical_snapshots_immutable',true,
    'valuation_threshold_changes',false,
    'hardening_threshold_changes',false,
    'portfolio_mutation',false,
    'approval_mutation',false,
    'execution_mutation',false,
    'human_execution_only',true,
    'auto_trade',false
  ),
  'FWIOS MVP-1 portfolio-independent Decision / Opportunity cutover 2026-10-27',
  now()
)
on conflict(policy_version_id) do update set
  lifecycle_status='ACTIVE',
  deterministic_scoring=true,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

create or replace function fwios.preview_decision_refresh_bridge_v2(p_ticker text)
returns jsonb
language plpgsql
stable
security invoker
set search_path=''
as $function$
declare
  v_ticker text := upper(btrim(coalesce(p_ticker,'')));
  v_val fwios.valuation_runs%rowtype;
  v_hard fwios.candidate_quality_hardening_snapshots%rowtype;
  v_mis fwios.v_valuation_mispricing_current%rowtype;
  v_rc fwios.research_candidates%rowtype;
  v_rev fwios.candidate_revision_snapshots%rowtype;
  v_chase fwios.candidate_chase_snapshots%rowtype;
  v_score_policy fwios.data_scoring_policies%rowtype;
  v_expected numeric;
  v_core numeric;
  v_quality_gate text;
  v_downside_gate text;
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
    return jsonb_build_object('refresh_status','BLOCKED','reason','TICKER_REQUIRED',
      'policy_version_id','POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2',
      'portfolio_dependency',false,'production_changes','NONE','auto_trade',false);
  end if;

  select * into v_val
  from fwios.valuation_runs
  where ticker=v_ticker and production_eligible=true and valuation_readiness='PASS'
    and router_gate='PASS' and valuation_gate='PASS' and schema_gate='PASS'
  order by created_at desc,run_id desc limit 1;

  if not found then
    return jsonb_build_object('refresh_status','BLOCKED','reason','CURRENT_PRODUCTION_VALUATION_NOT_FOUND',
      'ticker',v_ticker,'portfolio_dependency',false,'production_changes','NONE','auto_trade',false);
  end if;

  select * into v_hard
  from fwios.candidate_quality_hardening_snapshots
  where ticker=v_ticker
  order by created_at desc,hardening_snapshot_id desc limit 1;

  if not found then
    return jsonb_build_object('refresh_status','BLOCKED','reason','CURRENT_HARDENING_SNAPSHOT_NOT_FOUND',
      'ticker',v_ticker,'valuation_run_id',v_val.run_id,
      'portfolio_dependency',false,'production_changes','NONE','auto_trade',false);
  end if;

  if v_hard.valuation_run_id is distinct from v_val.run_id then
    return jsonb_build_object('refresh_status','BLOCKED','reason','HARDENING_NOT_ALIGNED_TO_CURRENT_VALUATION',
      'ticker',v_ticker,'valuation_run_id',v_val.run_id,
      'hardening_snapshot_id',v_hard.hardening_snapshot_id,
      'hardening_valuation_run_id',v_hard.valuation_run_id,
      'portfolio_dependency',false,'production_changes','NONE','auto_trade',false);
  end if;

  select * into v_mis from fwios.v_valuation_mispricing_current where ticker=v_ticker;
  if not found then
    return jsonb_build_object('refresh_status','BLOCKED','reason','CURRENT_MISPRICING_NOT_FOUND',
      'ticker',v_ticker,'valuation_run_id',v_val.run_id,
      'hardening_snapshot_id',v_hard.hardening_snapshot_id,
      'portfolio_dependency',false,'production_changes','NONE','auto_trade',false);
  end if;

  if v_mis.valuation_run_id is distinct from v_val.run_id
     or v_mis.mispricing_snapshot_id is distinct from v_hard.mispricing_snapshot_id then
    return jsonb_build_object('refresh_status','BLOCKED','reason','CURRENT_MISPRICING_NOT_ALIGNED_TO_HARDENING',
      'ticker',v_ticker,'valuation_run_id',v_val.run_id,
      'hardening_snapshot_id',v_hard.hardening_snapshot_id,
      'hardening_mispricing_snapshot_id',v_hard.mispricing_snapshot_id,
      'current_mispricing_snapshot_id',v_mis.mispricing_snapshot_id,
      'current_price_gate',v_mis.effective_price_gate,
      'portfolio_dependency',false,'production_changes','NONE','auto_trade',false);
  end if;

  select * into v_rc from fwios.research_candidates where ticker=v_ticker;
  if not found or v_rc.business_thesis_score is null or v_rc.quality_score is null
     or v_rc.downside_risk_score is null then
    return jsonb_build_object('refresh_status','BLOCKED','reason','CORE_RESEARCH_SCORE_MISSING',
      'ticker',v_ticker,'portfolio_dependency',false,'production_changes','NONE','auto_trade',false);
  end if;

  select * into v_score_policy from fwios.data_scoring_policies
  where policy_id='FWB-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT' and active=true;
  if not found then
    return jsonb_build_object('refresh_status','BLOCKED',
      'reason','ACTIVE_PORTFOLIO_INDEPENDENT_SCORING_POLICY_MISSING',
      'ticker',v_ticker,'portfolio_dependency',false,'production_changes','NONE','auto_trade',false);
  end if;

  select * into v_rev from fwios.candidate_revision_snapshots
  where ticker=v_ticker order by created_at desc,revision_snapshot_id desc limit 1;
  select * into v_chase from fwios.candidate_chase_snapshots
  where ticker=v_ticker order by created_at desc,chase_snapshot_id desc limit 1;

  v_expected := fwios.expected_return_score_v3(v_mis.base_upside,v_mis.probability_weighted_upside,v_hard.valuation_confidence);
  if v_expected is null then
    return jsonb_build_object('refresh_status','BLOCKED','reason','EXPECTED_RETURN_SCORE_NOT_COMPUTABLE',
      'ticker',v_ticker,'portfolio_dependency',false,'production_changes','NONE','auto_trade',false);
  end if;

  v_quality_gate := case when v_rc.quality_score>=v_score_policy.quality_gate_min then 'PASS' else 'FAIL - QUALITY SCORE' end;
  v_downside_gate := case when v_rc.risk_gate='PASS' then 'PASS'
    when v_rc.risk_gate is null then 'BLOCKED - RISK GATE MISSING'
    else 'BLOCKED - RISK GATE '||v_rc.risk_gate end;
  v_revision_gate := coalesce(v_rev.revision_gate,'BLOCKED - REVISION SNAPSHOT MISSING');
  v_chase_gate := coalesce(v_chase.chase_gate,'BLOCKED - CHASE SNAPSHOT MISSING');

  v_core := round(
      v_rc.business_thesis_score*v_score_policy.business_thesis_weight
    + v_expected*v_score_policy.expected_return_weight
    + v_rc.downside_risk_score*v_score_policy.downside_risk_weight,4);

  v_core_gate := case
    when v_quality_gate<>'PASS' then v_quality_gate
    when v_val.valuation_gate<>'PASS' then v_val.valuation_gate
    when v_downside_gate<>'PASS' then v_downside_gate
    else 'PASS' end;

  v_input_gate := case
    when coalesce(v_mis.effective_price_gate,'MISSING')<>'PASS' then coalesce(v_mis.effective_price_gate,'BLOCKED - PRICE')
    when v_revision_gate like 'BLOCKED%' then v_revision_gate
    when v_chase_gate like 'BLOCKED%' then v_chase_gate
    else 'PASS' end;

  v_promotion_gate := case
    when v_hard.overall_gate='FAIL' then 'FAIL - QUALITY HARDENING'
    when v_hard.overall_gate<>'PASS' then 'BLOCKED - QUALITY HARDENING'
    when v_core_gate<>'PASS' then v_core_gate
    when v_input_gate<>'PASS' then v_input_gate
    when v_mis.mispricing_gate<>'PASS' then v_mis.mispricing_gate
    when v_revision_gate<>'PASS' then v_revision_gate
    when v_chase_gate<>'PASS' then v_chase_gate
    else 'PASS' end;

  v_decision_state := case
    when v_hard.overall_gate='FAIL' then 'FAIL - QUALITY HARDENING'
    when v_hard.overall_gate='REVIEW' then 'REVIEW - QUALITY HARDENING'
    when v_hard.overall_gate='BLOCKED' then 'BLOCKED - QUALITY HARDENING'
    when v_input_gate<>'PASS' then 'DATA BLOCKED'
    when v_promotion_gate='PASS' then 'READY FOR HUMAN REVIEW'
    when v_mis.mispricing_gate='FAIL - INSUFFICIENT MISPRICING' then 'WAIT - MISPRICING'
    when v_revision_gate<>'PASS' then 'WAIT - REVISION'
    when v_chase_gate<>'PASS' then 'WAIT - CHASE RISK'
    else 'WATCHLIST ONLY' end;

  v_hash := substr(md5(concat_ws('|',v_ticker,v_val.run_id,v_hard.hardening_snapshot_id,
    v_mis.mispricing_snapshot_id,coalesce(v_rev.revision_snapshot_id,'NONE'),
    coalesce(v_chase.chase_snapshot_id,'NONE'),v_score_policy.policy_id)),1,16);
  v_score_id := 'SCORE-DPI-'||v_ticker||'-'||v_hash;
  v_decision_id := 'DEC-DPI-'||v_ticker||'-'||v_hash;

  select score_snapshot_id into v_latest_score_id from fwios.candidate_decision_scores
  where ticker=v_ticker order by created_at desc,score_snapshot_id desc limit 1;
  select decision_snapshot_id into v_latest_decision_id from fwios.decision_snapshots
  where ticker=v_ticker order by created_at desc,decision_snapshot_id desc limit 1;

  return jsonb_build_object(
    'refresh_status','READY_TO_APPLY','policy_version_id','POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2','ticker',v_ticker,
    'current_upstream',jsonb_build_object('valuation_run_id',v_val.run_id,'mispricing_snapshot_id',v_mis.mispricing_snapshot_id,
      'price_snapshot_id',v_mis.price_snapshot_id,'price_gate',v_mis.effective_price_gate,
      'hardening_snapshot_id',v_hard.hardening_snapshot_id,'hardening_gate',v_hard.overall_gate,
      'valuation_confidence',v_hard.valuation_confidence),
    'core_baseline',jsonb_build_object('scoring_policy_id',v_score_policy.policy_id,
      'scoring_policy_version_id','POL-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT',
      'business_thesis_score',v_rc.business_thesis_score,'quality_score',v_rc.quality_score,
      'downside_risk_score',v_rc.downside_risk_score,
      'weights',jsonb_build_object('business_thesis',v_score_policy.business_thesis_weight,
        'expected_return',v_score_policy.expected_return_weight,'portfolio_fit',v_score_policy.portfolio_fit_weight,
        'downside_risk',v_score_policy.downside_risk_weight)),
    'revision_chase',jsonb_build_object('revision_snapshot_id',v_rev.revision_snapshot_id,
      'revision_policy_version_id',v_rev.policy_version_id,'revision_gate',v_revision_gate,
      'chase_snapshot_id',v_chase.chase_snapshot_id,'chase_policy_version_id',v_chase.policy_version_id,'chase_gate',v_chase_gate),
    'computed',jsonb_build_object('business_thesis_score',v_rc.business_thesis_score,'expected_return_score',v_expected,
      'portfolio_fit_score',null,'downside_risk_score',v_rc.downside_risk_score,'core_score',v_core,
      'quality_gate',v_quality_gate,'valuation_gate',v_val.valuation_gate,'mispricing_gate',v_mis.mispricing_gate,
      'portfolio_gate','NOT_APPLICABLE - PORTFOLIO INDEPENDENT','downside_gate',v_downside_gate,
      'revision_gate',v_revision_gate,'chase_gate',v_chase_gate,'core_scoring_gate',v_core_gate,
      'hardening_gate',v_hard.overall_gate,'promotion_gate',v_promotion_gate,
      'decision_state',v_decision_state,'input_integrity_gate',v_input_gate),
    'prior_latest',jsonb_build_object('score_snapshot_id',v_latest_score_id,'decision_snapshot_id',v_latest_decision_id),
    'proposed_ids',jsonb_build_object('score_snapshot_id',v_score_id,'decision_snapshot_id',v_decision_id),
    'portfolio_dependency',false,'portfolio_fit_required',false,'portfolio_batch_required',false,
    'human_authorization_required',true,'portfolio_mutation',false,'approval_mutation',false,
    'execution_mutation',false,'auto_trade',false,'production_changes','PREVIEW_NONE');
end;
$function$;

create or replace function fwios.apply_decision_refresh_bridge_v2(p_ticker text,p_human_authorized boolean)
returns jsonb
language plpgsql
security invoker
set search_path=''
as $function$
declare
  v_preview jsonb;
  v_ticker text;
  v_score_id text;
  v_decision_id text;
  v_existing_decision fwios.decision_snapshots%rowtype;
  v_decision_artifact_id uuid;
  v_val_artifact_id uuid;
  v_hard_artifact_id uuid;
  v_rev_artifact_id uuid;
  v_instrument_id uuid;
begin
  if not coalesce(p_human_authorized,false) then
    return jsonb_build_object('status','BLOCKED','reason','HUMAN_AUTHORIZATION_REQUIRED',
      'production_changes','NONE','portfolio_dependency',false,'auto_trade',false,'human_execution_only',true);
  end if;

  v_preview := fwios.preview_decision_refresh_bridge_v2(p_ticker);
  if coalesce(v_preview->>'refresh_status','BLOCKED')<>'READY_TO_APPLY' then
    return jsonb_build_object('status','BLOCKED','reason','REFRESH_PREVIEW_NOT_READY','preview',v_preview,
      'production_changes','NONE','portfolio_dependency',false,'auto_trade',false,'human_execution_only',true);
  end if;

  v_ticker := v_preview->>'ticker';
  v_score_id := v_preview->'proposed_ids'->>'score_snapshot_id';
  v_decision_id := v_preview->'proposed_ids'->>'decision_snapshot_id';

  select * into v_existing_decision from fwios.decision_snapshots where decision_snapshot_id=v_decision_id;
  if found then
    if v_existing_decision.ticker=v_ticker
       and v_existing_decision.valuation_run_id=v_preview->'current_upstream'->>'valuation_run_id'
       and v_existing_decision.hardening_snapshot_id=v_preview->'current_upstream'->>'hardening_snapshot_id'
       and v_existing_decision.mispricing_snapshot_id=v_preview->'current_upstream'->>'mispricing_snapshot_id'
       and v_existing_decision.portfolio_fit_snapshot_id is null
       and v_existing_decision.portfolio_batch_id is null then
      return jsonb_build_object('status','NOOP_ALREADY_REFRESHED','ticker',v_ticker,
        'score_snapshot_id',v_existing_decision.score_snapshot_id,'decision_snapshot_id',v_decision_id,
        'decision_state',v_existing_decision.decision_state,'promotion_gate',v_existing_decision.promotion_gate,
        'input_integrity_gate',v_existing_decision.input_integrity_gate,'portfolio_dependency',false,
        'production_changes','NONE','auto_trade',false,'human_execution_only',true);
    end if;
    raise exception 'DECISION_REFRESH_V2_ID_COLLISION';
  end if;

  if not exists(select 1 from fwios.candidate_decision_scores where score_snapshot_id=v_score_id) then
    insert into fwios.candidate_decision_scores(
      score_snapshot_id,ticker,scoring_policy_id,valuation_run_id,mispricing_snapshot_id,
      portfolio_fit_snapshot_id,business_thesis_score,expected_return_score,portfolio_fit_score,
      downside_risk_score,core_score,quality_gate,valuation_gate,mispricing_gate,portfolio_gate,
      downside_gate,revision_gate,chase_gate,core_scoring_gate,promotion_gate,decision_state,
      decision_note,source_reference,hardening_snapshot_id,valuation_confidence,hardening_gate
    ) values (
      v_score_id,v_ticker,v_preview->'core_baseline'->>'scoring_policy_id',
      v_preview->'current_upstream'->>'valuation_run_id',v_preview->'current_upstream'->>'mispricing_snapshot_id',
      null,(v_preview->'computed'->>'business_thesis_score')::numeric,
      (v_preview->'computed'->>'expected_return_score')::numeric,null,
      (v_preview->'computed'->>'downside_risk_score')::numeric,(v_preview->'computed'->>'core_score')::numeric,
      v_preview->'computed'->>'quality_gate',v_preview->'computed'->>'valuation_gate',
      v_preview->'computed'->>'mispricing_gate','NOT_APPLICABLE - PORTFOLIO INDEPENDENT',
      v_preview->'computed'->>'downside_gate',v_preview->'computed'->>'revision_gate',
      v_preview->'computed'->>'chase_gate',v_preview->'computed'->>'core_scoring_gate',
      v_preview->'computed'->>'promotion_gate',v_preview->'computed'->>'decision_state',
      'Decision/Opportunity Refresh Bridge v2: portfolio-independent current valuation/mispricing/hardening scoring.',
      'POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2:'||(v_preview->'current_upstream'->>'valuation_run_id')||':'||
      (v_preview->'current_upstream'->>'hardening_snapshot_id'),
      v_preview->'current_upstream'->>'hardening_snapshot_id',
      (v_preview->'current_upstream'->>'valuation_confidence')::numeric,
      v_preview->'computed'->>'hardening_gate');
  end if;

  insert into fwios.decision_snapshots(
    decision_snapshot_id,ticker,portfolio_batch_id,price_snapshot_id,valuation_run_id,mispricing_snapshot_id,
    portfolio_fit_snapshot_id,revision_snapshot_id,chase_snapshot_id,score_snapshot_id,
    scoring_policy_version_id,revision_policy_version_id,chase_policy_version_id,core_score,
    decision_state,promotion_gate,input_integrity_gate,decision_payload,hardening_snapshot_id
  ) values (
    v_decision_id,v_ticker,null,v_preview->'current_upstream'->>'price_snapshot_id',
    v_preview->'current_upstream'->>'valuation_run_id',v_preview->'current_upstream'->>'mispricing_snapshot_id',
    null,nullif(v_preview->'revision_chase'->>'revision_snapshot_id',''),
    nullif(v_preview->'revision_chase'->>'chase_snapshot_id',''),v_score_id,
    'POL-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT',
    nullif(v_preview->'revision_chase'->>'revision_policy_version_id',''),
    nullif(v_preview->'revision_chase'->>'chase_policy_version_id',''),
    (v_preview->'computed'->>'core_score')::numeric,v_preview->'computed'->>'decision_state',
    v_preview->'computed'->>'promotion_gate',v_preview->'computed'->>'input_integrity_gate',
    jsonb_build_object('bridge_policy','POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2',
      'scoring_policy','POL-DATA-SCORING-V4-PORTFOLIO-INDEPENDENT',
      'current_valuation_run_id',v_preview->'current_upstream'->>'valuation_run_id',
      'current_mispricing_snapshot_id',v_preview->'current_upstream'->>'mispricing_snapshot_id',
      'current_hardening_snapshot_id',v_preview->'current_upstream'->>'hardening_snapshot_id',
      'hardening_gate',v_preview->'computed'->>'hardening_gate',
      'revision_snapshot_id',v_preview->'revision_chase'->>'revision_snapshot_id',
      'revision_gate',v_preview->'revision_chase'->>'revision_gate',
      'chase_snapshot_id',v_preview->'revision_chase'->>'chase_snapshot_id',
      'chase_gate',v_preview->'revision_chase'->>'chase_gate',
      'portfolio_dependency',false,'portfolio_fit_snapshot_id',null,'portfolio_batch_id',null,
      'historical_snapshots_rewritten',false,'valuation_threshold_changes',false,
      'hardening_threshold_changes',false,'portfolio_mutation',false,'approval_mutation',false,
      'execution_mutation',false,'human_execution_only',true,'auto_trade',false),
    v_preview->'current_upstream'->>'hardening_snapshot_id');

  v_instrument_id := fwios.resolve_instrument_id_v1(v_ticker,'Stock',null,null);
  insert into fwios.lineage_artifacts(
    artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
  ) values (
    'DECISION:'||v_decision_id,'DECISION_SNAPSHOT','fwios','decision_snapshots',v_decision_id,
    v_instrument_id,'RESOLVED',jsonb_build_object('ticker',v_ticker,
      'decision_state',v_preview->'computed'->>'decision_state','promotion_gate',v_preview->'computed'->>'promotion_gate',
      'core_score',(v_preview->'computed'->>'core_score')::numeric,'portfolio_dependency',false,
      'bridge_policy','POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2'))
  on conflict(artifact_key) do nothing;

  select artifact_id into v_decision_artifact_id from fwios.lineage_artifacts where artifact_key='DECISION:'||v_decision_id;
  select artifact_id into v_val_artifact_id from fwios.lineage_artifacts
    where artifact_key='VALUATION:'||(v_preview->'current_upstream'->>'valuation_run_id');
  select artifact_id into v_hard_artifact_id from fwios.lineage_artifacts
    where artifact_key='HARDENING:'||(v_preview->'current_upstream'->>'hardening_snapshot_id');
  if v_decision_artifact_id is null or v_val_artifact_id is null or v_hard_artifact_id is null then
    raise exception 'DECISION_REFRESH_V2_REQUIRED_LINEAGE_ARTIFACT_MISSING';
  end if;

  insert into fwios.lineage_edges(from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata)
  select v_val_artifact_id,v_decision_artifact_id,'VALUATION_SUPPORTS_DECISION','VALUATION_RUN','RESOLVED',
    'POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2',
    jsonb_build_object('mispricing_snapshot_id',v_preview->'current_upstream'->>'mispricing_snapshot_id')
  where not exists(select 1 from fwios.lineage_edges
    where from_artifact_id=v_val_artifact_id and to_artifact_id=v_decision_artifact_id
      and edge_type='VALUATION_SUPPORTS_DECISION' and edge_role='VALUATION_RUN');

  insert into fwios.lineage_edges(from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata)
  select v_hard_artifact_id,v_decision_artifact_id,'HARDENING_SUPPORTS_DECISION','HARDENING_SNAPSHOT','RESOLVED',
    'POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2',
    jsonb_build_object('hardening_gate',v_preview->'computed'->>'hardening_gate')
  where not exists(select 1 from fwios.lineage_edges
    where from_artifact_id=v_hard_artifact_id and to_artifact_id=v_decision_artifact_id
      and edge_type='HARDENING_SUPPORTS_DECISION' and edge_role='HARDENING_SNAPSHOT');

  if nullif(v_preview->'revision_chase'->>'revision_snapshot_id','') is not null then
    insert into fwios.lineage_artifacts(
      artifact_key,artifact_type,object_schema,object_table,object_key,instrument_id,resolution_status,metadata
    )
    select 'REVISION:'||r.revision_snapshot_id,'REVISION_SNAPSHOT','fwios','candidate_revision_snapshots',
      r.revision_snapshot_id,v_instrument_id,'RESOLVED',
      jsonb_build_object('ticker',r.ticker,'revision_score',r.revision_score,'revision_gate',r.revision_gate)
    from fwios.candidate_revision_snapshots r
    where r.revision_snapshot_id=v_preview->'revision_chase'->>'revision_snapshot_id'
    on conflict(artifact_key) do nothing;
    select artifact_id into v_rev_artifact_id from fwios.lineage_artifacts
      where artifact_key='REVISION:'||(v_preview->'revision_chase'->>'revision_snapshot_id');
    if v_rev_artifact_id is not null then
      insert into fwios.lineage_edges(
        from_artifact_id,to_artifact_id,edge_type,edge_role,provenance_status,source_reference,metadata
      )
      select v_rev_artifact_id,v_decision_artifact_id,'REVISION_SUPPORTS_DECISION','REVISION_SNAPSHOT','RESOLVED',
        'POL-DECISION-OPPORTUNITY-REFRESH-BRIDGE-V2','{}'::jsonb
      where not exists(select 1 from fwios.lineage_edges
        where from_artifact_id=v_rev_artifact_id and to_artifact_id=v_decision_artifact_id
          and edge_type='REVISION_SUPPORTS_DECISION' and edge_role='REVISION_SNAPSHOT');
    end if;
  end if;

  return jsonb_build_object('status','APPLIED','ticker',v_ticker,'score_snapshot_id',v_score_id,
    'decision_snapshot_id',v_decision_id,'decision_state',v_preview->'computed'->>'decision_state',
    'hardening_gate',v_preview->'computed'->>'hardening_gate','promotion_gate',v_preview->'computed'->>'promotion_gate',
    'input_integrity_gate',v_preview->'computed'->>'input_integrity_gate','portfolio_dependency',false,
    'portfolio_fit_snapshot_id',null,'portfolio_batch_id',null,'portfolio_mutation',false,
    'approval_mutation',false,'execution_mutation',false,'auto_trade',false,'human_execution_only',true);
end;
$function$;

insert into fwios.policy_registry(
  policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status,updated_at
) values (
  'OPPORTUNITY_QUALITY_V3','DECISION','Opportunity Quality V3 Portfolio Independent',
  'Rank and gate stock opportunities independently of portfolio state. Final eligibility after research gates is human review, not a Portfolio Scenario dependency.',
  'fwios.v_opportunity_quality_current','ACTIVE',now()
)
on conflict(policy_key) do update set
  policy_domain=excluded.policy_domain,policy_name=excluded.policy_name,purpose=excluded.purpose,
  backing_object=excluded.backing_object,lifecycle_status='ACTIVE',updated_at=now();

insert into fwios.policy_versions(
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference,effective_at
) values (
  'POL-OPPORTUNITY-QUALITY-V3-PORTFOLIO-INDEPENDENT','OPPORTUNITY_QUALITY_V3','3.0','ACTIVE',true,
  jsonb_build_object('business_thesis_weight',0.35,'expected_return_weight',0.40,'resilience_weight',0.25,
    'resilience_formula','50% quality_score + 50% downside_risk_score','portfolio_fit_weight',0,
    'portfolio_fit_discovery_gate',false,'portfolio_scenario_required_before_buy_review',false,
    'final_gate_after_prebuy_research','HUMAN_REVIEW','mispricing_is_state_not_weight',true,
    'human_execution_only',true,'auto_trade',false),
  'FWIOS Opportunity Quality v3: portfolio-independent discovery, gating and final human-review eligibility.',now()
)
on conflict(policy_version_id) do update set lifecycle_status='ACTIVE',deterministic_scoring=true,
  config=excluded.config,source_reference=excluded.source_reference,effective_at=excluded.effective_at;

create or replace function fwios.refresh_opportunity_quality_v3(
  p_as_of_date date default current_date,p_source text default 'SYSTEM',p_human_authorized boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path=''
as $function$
declare v_rows int:=0;
begin
  if not coalesce(p_human_authorized,false) then
    return jsonb_build_object('status','BLOCKED','reason','HUMAN_AUTHORIZATION_REQUIRED','rows_refreshed',0,
      'portfolio_dependency',false,'auto_trade',false,'human_execution_only',true);
  end if;

  insert into fwios.opportunity_quality_snapshots(
    ticker,as_of_date,policy_version_id,business_thesis_score,expected_return_signal_score,quality_score,
    downside_risk_score,resilience_score,opportunity_score,probability_weighted_upside,base_upside,price_gate,
    mispricing_gate,mispricing_class,score_gate,opportunity_state,full_thesis_gate,prebuy_research_gate,
    portfolio_scenario_gate,source_reference,payload,updated_at
  )
  select rc.ticker,p_as_of_date,'POL-OPPORTUNITY-QUALITY-V3-PORTFOLIO-INDEPENDENT',
    rc.business_thesis_score,
    case when mp.probability_weighted_upside is not null then fwios.continuous_upside_score_v1(mp.probability_weighted_upside) end,
    rc.quality_score,rc.downside_risk_score,
    case when rc.quality_score is not null and rc.downside_risk_score is not null
      then round((rc.quality_score+rc.downside_risk_score)/2.0,4) end,
    fwios.opportunity_quality_score_v2(rc.business_thesis_score,mp.probability_weighted_upside,rc.quality_score,rc.downside_risk_score),
    mp.probability_weighted_upside,mp.base_upside,coalesce(mp.effective_price_gate,'MISSING'),
    coalesce(mp.mispricing_gate,rc.mispricing_gate,'MISSING'),coalesce(mp.mispricing_class,rc.mispricing_class),
    case when rc.business_thesis_score is null or rc.quality_score is null or rc.downside_risk_score is null
        then 'BLOCKED - CORE RESEARCH INPUT'
      when mp.probability_weighted_upside is null then 'BLOCKED - CURRENT VALUATION UPSIDE'
      when rc.valuation_gate<>'PASS' then 'BLOCKED - VALUATION'
      when rc.risk_gate<>'PASS' then 'BLOCKED - RISK' else 'PASS' end,
    case when mp.probability_weighted_upside is null then 'VALUATION_REQUIRED'
      when coalesce(mp.effective_price_gate,'MISSING')<>'PASS' then 'PRICE_VERIFY'
      when mp.mispricing_gate='PASS' then 'MISPRICED_CANDIDATE'
      when mp.mispricing_gate='FAIL - INSUFFICIENT MISPRICING' then 'VALUE_WAIT' else 'RESEARCH' end,
    case when tr.baseline_status='COMPLETE' and tr.baseline_completeness=1 then 'PASS'
      else 'BLOCKED - FULL THESIS REQUIRED' end,
    case when tr.baseline_status is distinct from 'COMPLETE' or coalesce(tr.baseline_completeness,0)<1
        then 'BLOCKED - FULL THESIS REQUIRED'
      when th.health_status in ('BROKEN','WEAKENING') then 'BLOCKED - THESIS HEALTH'
      when coalesce(mp.effective_price_gate,'MISSING')<>'PASS' then 'BLOCKED - PRICE VERIFY'
      when mp.mispricing_gate<>'PASS' then 'BLOCKED - MISPRICING'
      when rev.ticker is null then 'BLOCKED - REVISION EVIDENCE'
      when rev.revision_gate<>'PASS' then 'BLOCKED - REVISION'
      when ch.ticker is null then 'BLOCKED - CHASE EVIDENCE'
      when ch.chase_gate<>'PASS' then 'BLOCKED - CHASE'
      when q.ticker is null then 'BLOCKED - QUALITY HARDENING'
      when q.overall_gate<>'PASS' then 'BLOCKED - QUALITY HARDENING'
      else 'PASS - READY FOR HUMAN REVIEW' end,
    'NOT_APPLICABLE - PORTFOLIO INDEPENDENT',p_source,
    jsonb_build_object('portfolio_dependency',false,'portfolio_fit_in_opportunity_score',false,
      'portfolio_fit_discovery_gate',false,'portfolio_scenario_required_before_buy_review',false,
      'business_thesis_weight',0.35,'expected_return_weight',0.40,'resilience_weight',0.25,
      'human_execution_only',true,'auto_trade',false),now()
  from fwios.research_candidates rc
  left join fwios.v_valuation_mispricing_current mp on mp.ticker=rc.ticker
  left join fwios.thesis_registry tr on tr.ticker=rc.ticker
  left join fwios.v_thesis_tracking_current th on th.ticker=rc.ticker
  left join fwios.v_candidate_revision_current rev on rev.ticker=rc.ticker
  left join fwios.v_candidate_chase_current ch on ch.ticker=rc.ticker
  left join fwios.v_candidate_quality_hardening_current q on q.ticker=rc.ticker
  on conflict(ticker,as_of_date,policy_version_id) do update set
    business_thesis_score=excluded.business_thesis_score,expected_return_signal_score=excluded.expected_return_signal_score,
    quality_score=excluded.quality_score,downside_risk_score=excluded.downside_risk_score,resilience_score=excluded.resilience_score,
    opportunity_score=excluded.opportunity_score,probability_weighted_upside=excluded.probability_weighted_upside,
    base_upside=excluded.base_upside,price_gate=excluded.price_gate,mispricing_gate=excluded.mispricing_gate,
    mispricing_class=excluded.mispricing_class,score_gate=excluded.score_gate,opportunity_state=excluded.opportunity_state,
    full_thesis_gate=excluded.full_thesis_gate,prebuy_research_gate=excluded.prebuy_research_gate,
    portfolio_scenario_gate=excluded.portfolio_scenario_gate,source_reference=excluded.source_reference,
    payload=excluded.payload,updated_at=now();

  get diagnostics v_rows=row_count;
  return jsonb_build_object('status','APPLIED','as_of_date',p_as_of_date,'rows_refreshed',v_rows,
    'policy_version_id','POL-OPPORTUNITY-QUALITY-V3-PORTFOLIO-INDEPENDENT','portfolio_dependency',false,
    'portfolio_fit_weight',0,'portfolio_scenario_required_before_buy_review',false,
    'human_execution_only',true,'auto_trade',false);
end;
$function$;

create or replace view fwios.v_opportunity_quality_current
with (security_invoker=true)
as
with latest as (
  select distinct on (ticker) *
  from fwios.opportunity_quality_snapshots
  where policy_version_id='POL-OPPORTUNITY-QUALITY-V3-PORTFOLIO-INDEPENDENT'
  order by ticker,as_of_date desc,updated_at desc,opportunity_snapshot_id desc
)
select l.ticker,rc.company_name,rc.sector,rc.archetype,l.business_thesis_score,
  l.expected_return_signal_score,l.quality_score,l.downside_risk_score,l.resilience_score,l.opportunity_score,
  l.probability_weighted_upside,l.base_upside,l.price_gate,l.mispricing_gate,l.mispricing_class,l.score_gate,
  l.opportunity_state,l.full_thesis_gate,l.prebuy_research_gate,l.portfolio_scenario_gate,
  case when l.prebuy_research_gate='PASS - READY FOR HUMAN REVIEW' then 'PASS - HUMAN REVIEW ELIGIBLE'
    else l.prebuy_research_gate end as final_buy_review_gate,
  null::numeric as scenario_fit_score,null::numeric as scenario_add_amount_thb,null::timestamptz as scenario_reviewed_at,
  dense_rank() over(order by l.opportunity_score desc nulls last,l.business_thesis_score desc nulls last,l.ticker) as opportunity_rank,
  l.as_of_date,l.updated_at,
  dense_rank() over(order by case when l.score_gate='PASS' then 0 else 1 end,l.opportunity_score desc nulls last,l.ticker)
    as research_readiness_rank
from latest l join fwios.research_candidates rc on rc.ticker=l.ticker;

revoke execute on function fwios.preview_decision_refresh_bridge_v1(text) from public,anon,authenticated,service_role;
revoke execute on function fwios.apply_decision_refresh_bridge_v1(text,boolean) from public,anon,authenticated,service_role;
revoke execute on function fwios.preview_opportunity_ranking_refresh_bridge_v1(text[]) from public,anon,authenticated,service_role;
revoke execute on function fwios.apply_opportunity_ranking_refresh_bridge_v1(text[],boolean) from public,anon,authenticated,service_role;
revoke execute on function fwios.refresh_opportunity_quality_v2(date,text) from public,anon,authenticated,service_role;

revoke execute on function fwios.preview_decision_refresh_bridge_v2(text) from public,anon,authenticated;
grant execute on function fwios.preview_decision_refresh_bridge_v2(text) to service_role;
revoke execute on function fwios.apply_decision_refresh_bridge_v2(text,boolean) from public,anon,authenticated;
grant execute on function fwios.apply_decision_refresh_bridge_v2(text,boolean) to service_role;
revoke execute on function fwios.refresh_opportunity_quality_v3(date,text,boolean) from public,anon,authenticated;
grant execute on function fwios.refresh_opportunity_quality_v3(date,text,boolean) to service_role;
