-- FWIOS M2 Promotion-Gate Hardening v1
-- Contract: FWIOS-CONTRACT-0.87.4
-- Applied live on 2026-09-05. Human execution only.

create table if not exists fwios.candidate_revision_component_inputs (
  component_input_id text primary key,
  ticker text not null,
  revision_snapshot_id text,
  component_code text not null check (component_code in ('GUIDANCE','CONSENSUS','KPI_ACCELERATION','MARGIN_FCF')),
  raw_value numeric not null,
  raw_unit text not null,
  component_score numeric not null check (component_score between 0 and 100),
  policy_version_id text not null references fwios.policy_versions(policy_version_id),
  evidence_ids text[] not null default '{}',
  source_reference text not null,
  provenance_status text not null check (provenance_status in ('PASS','BLOCKED')),
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists fwios.candidate_chase_component_inputs (
  component_input_id text primary key,
  ticker text not null,
  chase_snapshot_id text,
  component_code text not null check (component_code in ('PRICE_EXTENSION','PRICE_VS_REVISION','MULTIPLE_EXPANSION','PRICE_VS_FV')),
  raw_value numeric not null,
  raw_unit text not null,
  component_score numeric not null check (component_score between 0 and 100),
  policy_version_id text not null references fwios.policy_versions(policy_version_id),
  source_quote_ids text[] not null default '{}',
  source_reference text not null,
  provenance_status text not null check (provenance_status in ('PASS','BLOCKED')),
  raw_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists fwios.decision_policy_regression_runs (
  regression_id text primary key,
  policy_key text not null references fwios.policy_registry(policy_key),
  policy_version_id text not null references fwios.policy_versions(policy_version_id),
  test_case text not null,
  input_payload jsonb not null,
  expected_payload jsonb not null,
  actual_payload jsonb not null,
  status text not null check (status in ('PASS','FAIL')),
  tolerance numeric,
  notes text,
  created_at timestamptz not null default now()
);

alter table fwios.candidate_revision_snapshots
  add column if not exists policy_version_id text references fwios.policy_versions(policy_version_id),
  add column if not exists component_input_ids text[] not null default '{}';

alter table fwios.candidate_chase_snapshots
  add column if not exists policy_version_id text references fwios.policy_versions(policy_version_id),
  add column if not exists component_input_ids text[] not null default '{}';

alter table fwios.candidate_revision_component_inputs enable row level security;
alter table fwios.candidate_chase_component_inputs enable row level security;
alter table fwios.decision_policy_regression_runs enable row level security;
revoke all on fwios.candidate_revision_component_inputs from anon, authenticated;
revoke all on fwios.candidate_chase_component_inputs from anon, authenticated;
revoke all on fwios.decision_policy_regression_runs from anon, authenticated;

create or replace function fwios.score_revision_delta_v1(delta_pct numeric)
returns numeric language sql immutable strict parallel safe
as $$ select round(greatest(0::numeric, least(100::numeric, 50::numeric + 5::numeric * delta_pct)), 4) $$;

create or replace function fwios.calculate_revision_score_v1(guidance_score numeric, consensus_score numeric, kpi_acceleration_score numeric, margin_fcf_score numeric)
returns numeric language sql immutable strict parallel safe
as $$ select round(guidance_score*0.30 + consensus_score*0.25 + kpi_acceleration_score*0.25 + margin_fcf_score*0.20, 4) $$;

create or replace function fwios.revision_gate_v1(guidance_score numeric, consensus_score numeric, kpi_acceleration_score numeric, margin_fcf_score numeric, freshness_gate text, consensus_gate text)
returns text language sql immutable parallel safe
as $$
select case
  when guidance_score is null or consensus_score is null or kpi_acceleration_score is null or margin_fcf_score is null then 'BLOCKED - COMPONENT SCORING INCOMPLETE'
  when freshness_gate <> 'PASS' then 'BLOCKED - REVISION EVIDENCE STALE'
  when consensus_gate <> 'PASS - COMPARABLE CONSENSUS EVIDENCE' then 'BLOCKED - CONSENSUS EVIDENCE'
  when fwios.calculate_revision_score_v1(guidance_score,consensus_score,kpi_acceleration_score,margin_fcf_score) >= 50 then 'PASS'
  else 'FAIL - NEGATIVE FUNDAMENTAL REVISION'
end $$;

create or replace function fwios.score_chase_excess_v1(excess_pct numeric)
returns numeric language sql immutable strict parallel safe
as $$ select round(greatest(0::numeric, least(100::numeric, greatest(excess_pct, 0::numeric) * 2.5::numeric)), 4) $$;

create or replace function fwios.score_price_vs_fv_risk_v1(premium_pct numeric)
returns numeric language sql immutable strict parallel safe
as $$
select round(case
  when premium_pct <= -20 then 0
  when premium_pct <= -10 then (premium_pct + 20) * 1.5
  when premium_pct <= 0 then 15 + (premium_pct + 10) * 2.5
  when premium_pct <= 10 then 40 + premium_pct * 2.5
  when premium_pct <= 25 then 65 + (premium_pct - 10) * (35.0/15.0)
  else 100
end::numeric,4) $$;

create or replace function fwios.calculate_chase_risk_v1(price_extension_risk numeric, price_vs_revision_risk numeric, multiple_expansion_risk numeric, price_vs_fv_risk numeric)
returns numeric language sql immutable strict parallel safe
as $$ select round(price_extension_risk*0.25 + price_vs_revision_risk*0.30 + multiple_expansion_risk*0.25 + price_vs_fv_risk*0.20,4) $$;

create or replace function fwios.chase_gate_v1(price_extension_risk numeric, price_vs_revision_risk numeric, multiple_expansion_risk numeric, price_vs_fv_risk numeric, risk_max numeric)
returns text language sql immutable parallel safe
as $$
select case
  when price_extension_risk is null or price_vs_revision_risk is null or multiple_expansion_risk is null or price_vs_fv_risk is null then 'BLOCKED - INCOMPLETE CHASE DATA'
  when fwios.calculate_chase_risk_v1(price_extension_risk,price_vs_revision_risk,multiple_expansion_risk,price_vs_fv_risk) > risk_max then 'FAIL - CHASE RISK'
  else 'PASS'
end $$;

-- Production activation is data-governed: active policy versions may be inserted only after
-- `tests/decision/test_m2_promotion_policy_v1.sql` and recorded live regressions pass.
