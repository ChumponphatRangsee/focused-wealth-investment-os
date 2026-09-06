-- Quality / durability hardening v1
-- Adds fail-closed promotion gates without changing 30/30/25/15 core weights.

create table if not exists fwios.candidate_quality_hardening_snapshots (
  hardening_snapshot_id text primary key,
  ticker text not null references fwios.companies(ticker) on delete restrict,
  valuation_run_id text not null references fwios.valuation_runs(run_id) on delete restrict,
  mispricing_snapshot_id text not null references fwios.valuation_mispricing_snapshots(mispricing_snapshot_id) on delete restrict,
  policy_version_id text not null references fwios.policy_versions(policy_version_id) on delete restrict,
  business_durability_gate text not null check (business_durability_gate in ('PASS','REVIEW','BLOCKED','FAIL')),
  owner_earnings_gate text not null check (owner_earnings_gate in ('PASS','REVIEW','BLOCKED','FAIL')),
  value_trap_gate text not null check (value_trap_gate in ('PASS','REVIEW','BLOCKED','FAIL')),
  valuation_robustness_gate text not null check (valuation_robustness_gate in ('PASS','REVIEW','BLOCKED','FAIL')),
  overall_gate text not null check (overall_gate in ('PASS','REVIEW','BLOCKED','FAIL')),
  valuation_confidence numeric not null check (valuation_confidence between 0 and 1),
  sbc_to_revenue numeric,
  bear_upside numeric,
  base_upside numeric,
  probability_weighted_upside numeric,
  durability_anchor_years integer,
  durability_evidence_count integer not null default 0 check (durability_evidence_count >= 0),
  dilution_reconciliation_pass boolean,
  owner_fcf_conversion_pass boolean,
  counter_thesis_evidence_count integer not null default 0 check (counter_thesis_evidence_count >= 0),
  structural_risk_review_pass boolean,
  growth_anchor_verified boolean,
  evidence_payload jsonb not null default '{}'::jsonb,
  source_reference text not null,
  created_at timestamptz not null default now()
);

alter table fwios.candidate_quality_hardening_snapshots enable row level security;
revoke all on fwios.candidate_quality_hardening_snapshots from anon, authenticated;

do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema='fwios' and table_name='candidate_decision_scores' and column_name='hardening_snapshot_id'
  ) then
    alter table fwios.candidate_decision_scores add column hardening_snapshot_id text references fwios.candidate_quality_hardening_snapshots(hardening_snapshot_id) on delete restrict;
    alter table fwios.candidate_decision_scores add column valuation_confidence numeric check (valuation_confidence between 0 and 1);
    alter table fwios.candidate_decision_scores add column hardening_gate text check (hardening_gate is null or hardening_gate in ('PASS','REVIEW','BLOCKED','FAIL'));
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='fwios' and table_name='decision_snapshots' and column_name='hardening_snapshot_id'
  ) then
    alter table fwios.decision_snapshots add column hardening_snapshot_id text references fwios.candidate_quality_hardening_snapshots(hardening_snapshot_id) on delete restrict;
  end if;
end $$;

create or replace function fwios.hardening_gate_factor_v1(gate_status text)
returns numeric
language sql
immutable parallel safe
set search_path = pg_catalog, fwios
as $$
select case upper(coalesce(gate_status,''))
  when 'PASS' then 1.00::numeric
  when 'REVIEW' then 0.70::numeric
  when 'BLOCKED' then 0.40::numeric
  when 'FAIL' then 0.00::numeric
  else 0.00::numeric
end;
$$;

create or replace function fwios.quality_hardening_overall_gate_v1(
  business_durability_gate text,
  owner_earnings_gate text,
  value_trap_gate text,
  valuation_robustness_gate text
)
returns text
language sql
immutable parallel safe
set search_path = pg_catalog, fwios
as $$
select case
  when 'FAIL' = any(array[upper(coalesce(business_durability_gate,'')),upper(coalesce(owner_earnings_gate,'')),upper(coalesce(value_trap_gate,'')),upper(coalesce(valuation_robustness_gate,''))]) then 'FAIL'
  when upper(coalesce(business_durability_gate,''))='PASS'
   and upper(coalesce(owner_earnings_gate,''))='PASS'
   and upper(coalesce(value_trap_gate,''))='PASS'
   and upper(coalesce(valuation_robustness_gate,''))='PASS' then 'PASS'
  when 'BLOCKED' = any(array[upper(coalesce(business_durability_gate,'')),upper(coalesce(owner_earnings_gate,'')),upper(coalesce(value_trap_gate,'')),upper(coalesce(valuation_robustness_gate,''))]) then 'BLOCKED'
  else 'REVIEW'
end;
$$;

create or replace function fwios.valuation_confidence_v1(
  business_durability_gate text,
  owner_earnings_gate text,
  value_trap_gate text,
  valuation_robustness_gate text
)
returns numeric
language sql
immutable parallel safe
set search_path = pg_catalog, fwios
as $$
select round((
  fwios.hardening_gate_factor_v1(business_durability_gate)
 +fwios.hardening_gate_factor_v1(owner_earnings_gate)
 +fwios.hardening_gate_factor_v1(value_trap_gate)
 +fwios.hardening_gate_factor_v1(valuation_robustness_gate)
)/4.0,4);
$$;

create or replace function fwios.continuous_upside_score_v1(upside numeric)
returns numeric
language sql
immutable parallel safe
set search_path = pg_catalog, fwios
as $$
select case when upside is null then null
  else round(greatest(0::numeric,least(100::numeric,50::numeric + 100::numeric*upside)),4)
end;
$$;

create or replace function fwios.expected_return_score_v3(
  base_upside numeric,
  probability_weighted_upside numeric,
  valuation_confidence numeric
)
returns numeric
language sql
immutable parallel safe
set search_path = pg_catalog, fwios
as $$
select case
  when base_upside is null or probability_weighted_upside is null or valuation_confidence is null then null
  else round((
    0.60*fwios.continuous_upside_score_v1(base_upside)
   +0.40*fwios.continuous_upside_score_v1(probability_weighted_upside)
  ) * greatest(0::numeric,least(1::numeric,valuation_confidence)),4)
end;
$$;

-- Immediate promotion must clear quality hardening. Model-review names stay visible but can never receive capital.
create or replace function fwios.opportunity_bucket_v2(
  promotion_gate text,
  mispricing_gate text,
  quality_gate text,
  valuation_gate text,
  portfolio_gate text,
  downside_gate text,
  revision_gate text,
  chase_gate text,
  core_scoring_gate text,
  input_integrity_gate text,
  hardening_gate text
)
returns text
language sql
immutable parallel safe
set search_path = pg_catalog, fwios
as $$
select case
  when input_integrity_gate <> 'PASS' then 'EXCLUDED'
  when promotion_gate = 'PASS' and hardening_gate = 'PASS' then 'IMMEDIATE_BUY_CANDIDATE'
  when mispricing_gate = 'FAIL - INSUFFICIENT MISPRICING'
   and quality_gate='PASS' and valuation_gate='PASS' and portfolio_gate='PASS'
   and downside_gate='PASS' and revision_gate='PASS' and chase_gate='PASS'
    then 'WATCHLIST_VALUE_WAIT'
  when mispricing_gate = 'PASS'
   and quality_gate='PASS' and valuation_gate='PASS' and portfolio_gate='PASS'
   and downside_gate='PASS' and revision_gate='PASS' and chase_gate='PASS'
   and hardening_gate <> 'PASS'
    then 'WATCHLIST_MODEL_REVIEW'
  else 'EXCLUDED'
end;
$$;

do $$ begin
  alter table fwios.opportunity_ranked_candidates drop constraint if exists opportunity_ranked_candidates_opportunity_bucket_check;
  alter table fwios.opportunity_ranked_candidates add constraint opportunity_ranked_candidates_opportunity_bucket_check
    check (opportunity_bucket in ('IMMEDIATE_BUY_CANDIDATE','WATCHLIST_VALUE_WAIT','WATCHLIST_MODEL_REVIEW','EXCLUDED'));
end $$;

create or replace view fwios.v_candidate_quality_hardening_current
with (security_invoker=true)
as
select distinct on (ticker) *
from fwios.candidate_quality_hardening_snapshots
order by ticker, created_at desc, hardening_snapshot_id desc;

create or replace view fwios.v_candidate_decision_scores_current
with (security_invoker=true)
as
select distinct on (ticker)
  score_snapshot_id,ticker,scoring_policy_id,valuation_run_id,mispricing_snapshot_id,portfolio_fit_snapshot_id,
  business_thesis_score,expected_return_score,portfolio_fit_score,downside_risk_score,core_score,
  quality_gate,valuation_gate,mispricing_gate,portfolio_gate,downside_gate,revision_gate,chase_gate,
  core_scoring_gate,promotion_gate,decision_state,decision_note,source_reference,created_at,
  hardening_snapshot_id,valuation_confidence,hardening_gate
from fwios.candidate_decision_scores
order by ticker, created_at desc, score_snapshot_id desc;

insert into fwios.policy_registry(policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status)
values ('QUALITY_HARDENING','decision_intelligence','Quality / Durability Hardening','Prevent cheap-looking or low-chase candidates from promotion until business durability, owner economics, value-trap counter-thesis and valuation robustness are verified.','fwios.candidate_quality_hardening_snapshots','ACTIVE')
on conflict (policy_key) do update set purpose=excluded.purpose,backing_object=excluded.backing_object,lifecycle_status='ACTIVE',updated_at=now();

insert into fwios.policy_versions(policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference)
values
('POL-QUALITY-HARDENING-V1','QUALITY_HARDENING','1.0','DRAFT',true,
 '{"promotion_requires_all_gates_pass":true,"gates":["BUSINESS_DURABILITY","OWNER_EARNINGS","VALUE_TRAP","VALUATION_ROBUSTNESS"],"confidence_map":{"PASS":1.0,"REVIEW":0.7,"BLOCKED":0.4,"FAIL":0.0},"owner_earnings":{"sbc_pass_max":0.10,"sbc_reconciliation_required_above":0.10,"sbc_hard_review_above":0.20,"sbc_fail_above":0.30},"extreme_mispricing_trigger":0.75,"durability_anchor_min_years":3,"counter_thesis_evidence_min":2,"bear_case_fail_below":-0.30,"human_execution_only":true}'::jsonb,
 'Focused Wealth quality hardening v1; deterministic fail-closed gate foundation'),
('POL-DATA-SCORING-V3-DURABILITY','DATA_SCORING','3.0','DRAFT',true,
 '{"backing_policy_id":"FWB-DATA-SCORING-V3-DURABILITY","business_thesis_weight":0.3,"expected_return_weight":0.3,"portfolio_fit_weight":0.25,"downside_risk_weight":0.15,"expected_return_base_weight":0.6,"expected_return_pw_weight":0.4,"expected_return_curve":"continuous_upside_score_v1","valuation_confidence_required":true,"quality_hardening_policy":"POL-QUALITY-HARDENING-V1","promotion_requires_hardening_pass":true}'::jsonb,
 'Focused Wealth data scoring v3: confidence-adjusted expected return + quality hardening'),
('POL-OPPORTUNITY-RANKING-V2','OPPORTUNITY_RANKING','2.0','DRAFT',true,
 '{"max_immediate":3,"max_watchlist":5,"priority_score":"core_score","immediate_rule":"promotion PASS + hardening PASS","watchlist_value_wait":"mispricing insufficient while core gates pass","watchlist_model_review":"mispricing PASS but quality hardening not PASS","capital_eligible_buckets":["IMMEDIATE_BUY_CANDIDATE"],"human_execution_only":true}'::jsonb,
 'Focused Wealth opportunity ranking v2: model-review watchlist and hardening gate')
on conflict (policy_version_id) do nothing;

insert into fwios.data_scoring_policies(
 policy_id,business_thesis_weight,expected_return_weight,portfolio_fit_weight,downside_risk_weight,
 quality_gate_min,portfolio_fit_min,chase_risk_max,expected_return_base_weight,expected_return_pw_weight,
 mispricing_required,revision_required,chase_required,source_reference,active)
values ('FWB-DATA-SCORING-V3-DURABILITY',0.30,0.30,0.25,0.15,70,50,60,0.60,0.40,true,true,true,
 'POL-DATA-SCORING-V3-DURABILITY + POL-QUALITY-HARDENING-V1',false)
on conflict (policy_id) do nothing;
