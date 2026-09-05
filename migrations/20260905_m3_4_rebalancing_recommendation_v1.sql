-- M3.4 Rebalancing Recommendation v1 foundation + activation contract.
create table if not exists fwios.rebalancing_recommendation_runs(
 recommendation_run_id text primary key, policy_version_id text references fwios.policy_versions(policy_version_id), portfolio_batch_id text references fwios.portfolio_import_batches(batch_id), ranking_run_id text references fwios.opportunity_ranking_runs(ranking_run_id), status text not null check(status in ('DRAFT','BLOCKED','READY','REJECTED','APPROVED')), new_cash_thb numeric not null default 0 check(new_cash_thb>=0), source_reference text not null, created_at timestamptz not null default now(), completed_at timestamptz);
create table if not exists fwios.rebalancing_recommendation_actions(
 recommendation_action_id text primary key,recommendation_run_id text not null references fwios.rebalancing_recommendation_runs(recommendation_run_id) on delete cascade,sequence_no integer not null,asset_symbol text not null,action_type text not null check(action_type in ('ADD','TRIM','HOLD')),amount_thb numeric not null check(amount_thb>=0),decision_snapshot_id text references fwios.decision_snapshots(decision_snapshot_id),valuation_run_id text references fwios.valuation_runs(run_id),rationale_code text not null,created_at timestamptz not null default now(),unique(recommendation_run_id,sequence_no));
create table if not exists fwios.rebalancing_recommendation_metrics(
 recommendation_metric_id text primary key,recommendation_run_id text not null references fwios.rebalancing_recommendation_runs(recommendation_run_id) on delete cascade,metric_name text not null,before_value numeric,after_value numeric,unit text,gate text not null,note text,created_at timestamptz not null default now(),unique(recommendation_run_id,metric_name));
alter table fwios.rebalancing_recommendation_runs enable row level security;
alter table fwios.rebalancing_recommendation_actions enable row level security;
alter table fwios.rebalancing_recommendation_metrics enable row level security;
revoke all on fwios.rebalancing_recommendation_runs,fwios.rebalancing_recommendation_actions,fwios.rebalancing_recommendation_metrics from public,anon,authenticated;

-- Holding coverage may use a fresh production holding valuation directly. ADD assets still use Decision Snapshot valuation lineage.
create or replace view fwios.v_holding_valuation_coverage_current with(security_invoker=true) as
with ranked as (
 select vr.*,row_number() over(partition by vr.ticker order by vr.created_at desc,vr.run_id desc) rn
 from fwios.valuation_runs vr
 join fwios.valuation_model_versions mv on mv.version_id=vr.model_version_id and mv.status='PRODUCTION' and mv.regression_status='PASS'
 join fwios.v_market_price_latest mp on mp.asset_symbol=vr.ticker and mp.snapshot_id=vr.source_snapshot and mp.effective_price_gate='PASS'
 join fwios.v_portfolio_exposure_current pe on pe.asset_symbol=vr.ticker and pe.asset_class='Stock'
 where vr.production_eligible=true and vr.valuation_gate='PASS' and vr.schema_gate='PASS')
select ticker,run_id,model_id,model_version_id,source_snapshot,current_price,base_upside,probability_weighted_upside,created_at from ranked where rn=1;
revoke all on fwios.v_holding_valuation_coverage_current from public,anon,authenticated;

-- The live preview function is versioned in Supabase and must preserve these invariants:
-- new cash first; Immediate candidate only; source valuation coverage required; >30% concentration review; >=25pp PW edge;
-- trim <= remaining candidate capacity and <= concentration excess; appreciation-only rationale forbidden; no mutation.
insert into fwios.policy_versions(policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference,effective_at)
values('POL-REBALANCE-V1','REBALANCE','1.0','ACTIVE',true,
'{"new_cash_first":true,"source_holding_requires_traceable_valuation":true,"candidate_requires_immediate_bucket":true,"candidate_requires_traceable_decision_valuation":true,"min_probability_weighted_opportunity_edge":0.25,"trim_requires_concentration_review":true,"trim_floor_weight":0.30,"trim_only_to_fund_remaining_candidate_capacity":true,"max_new_positions_per_cycle":1,"appreciation_only_trim_forbidden":true,"full_portfolio_valuation_not_required_for_changed_asset_comparison":true,"coverage_scope":"only valuation-covered source holdings may be selected; uncovered holdings are excluded, not proxied","regression_suite":"12/12 PASS","human_approval_required":true,"auto_trade":false,"portfolio_mutation":false}'::jsonb,
'M3_4_REBALANCING_RECOMMENDATION_V1',now())
on conflict(policy_version_id) do update set lifecycle_status='ACTIVE',config=excluded.config,source_reference=excluded.source_reference;
update fwios.policy_registry set lifecycle_status='ACTIVE',backing_object='fwios.rebalancing_recommendation_runs',updated_at=now() where policy_key='REBALANCE';