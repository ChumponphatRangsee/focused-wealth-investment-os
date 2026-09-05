-- Architecture Consolidation v1
-- Applied to Supabase project ysjbmeukwbfnxnwqchuq on 2026-09-05.
-- Additive only: no holdings/transactions are modified and no trading surface is created.

create table if not exists fwios.policy_registry (
  policy_key text primary key,
  policy_domain text not null,
  policy_name text not null,
  purpose text not null,
  backing_object text,
  lifecycle_status text not null check (lifecycle_status in ('ACTIVE','DRAFT','RETIRED')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists fwios.policy_versions (
  policy_version_id text primary key,
  policy_key text not null references fwios.policy_registry(policy_key),
  version text not null,
  lifecycle_status text not null check (lifecycle_status in ('ACTIVE','DRAFT','RETIRED')),
  deterministic_scoring boolean not null default false,
  config jsonb not null default '{}'::jsonb,
  source_reference text not null,
  effective_at timestamptz,
  created_at timestamptz not null default now(),
  unique (policy_key, version)
);

create table if not exists fwios.decision_snapshots (
  decision_snapshot_id text primary key,
  ticker text not null references fwios.companies(ticker),
  portfolio_batch_id text not null references fwios.portfolio_import_batches(batch_id),
  price_snapshot_id text not null references fwios.market_price_snapshots(snapshot_id),
  valuation_run_id text not null references fwios.valuation_runs(run_id),
  mispricing_snapshot_id text not null references fwios.valuation_mispricing_snapshots(mispricing_snapshot_id),
  portfolio_fit_snapshot_id text not null references fwios.candidate_portfolio_fit_snapshots(fit_snapshot_id),
  revision_snapshot_id text references fwios.candidate_revision_snapshots(revision_snapshot_id),
  chase_snapshot_id text references fwios.candidate_chase_snapshots(chase_snapshot_id),
  score_snapshot_id text not null references fwios.candidate_decision_scores(score_snapshot_id),
  scoring_policy_version_id text references fwios.policy_versions(policy_version_id),
  revision_policy_version_id text references fwios.policy_versions(policy_version_id),
  chase_policy_version_id text references fwios.policy_versions(policy_version_id),
  core_score numeric not null,
  decision_state text not null,
  promotion_gate text not null,
  input_integrity_gate text not null,
  decision_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists fwios.capital_allocation_runs (
  allocation_run_id text primary key,
  portfolio_batch_id text not null references fwios.portfolio_import_batches(batch_id),
  policy_version_id text references fwios.policy_versions(policy_version_id),
  run_mode text not null check (run_mode in ('NO_SELL','SOFT_REBALANCE','ACTIVE_REBALANCE')),
  status text not null check (status in ('DRAFT','BLOCKED','READY','COMPLETE','REJECTED')),
  source_reference text not null,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists fwios.capital_allocation_actions (
  action_id text primary key,
  allocation_run_id text not null references fwios.capital_allocation_runs(allocation_run_id) on delete cascade,
  sequence_no integer not null,
  asset_symbol text not null,
  action_type text not null check (action_type in ('HOLD','ADD','TRIM','STOP_DCA','START_DCA')),
  amount_thb numeric,
  target_weight numeric,
  decision_snapshot_id text references fwios.decision_snapshots(decision_snapshot_id),
  rationale_code text not null,
  created_at timestamptz not null default now(),
  unique (allocation_run_id, sequence_no)
);

create table if not exists fwios.capital_allocation_metrics (
  metric_id text primary key,
  allocation_run_id text not null references fwios.capital_allocation_runs(allocation_run_id) on delete cascade,
  metric_name text not null,
  before_value numeric,
  after_value numeric,
  unit text not null,
  gate text not null,
  note text,
  created_at timestamptz not null default now(),
  unique (allocation_run_id, metric_name)
);

create table if not exists fwios.system_events (
  event_id text primary key,
  event_type text not null,
  entity_type text not null,
  entity_id text not null,
  occurred_at timestamptz not null,
  source_reference text not null,
  payload jsonb not null default '{}'::jsonb,
  processing_status text not null default 'RECORDED' check (processing_status in ('RECORDED','QUEUED','PROCESSED','BLOCKED','IGNORED')),
  created_at timestamptz not null default now()
);

create index if not exists idx_policy_versions_policy on fwios.policy_versions(policy_key, lifecycle_status);
create index if not exists idx_decision_snapshots_ticker_created on fwios.decision_snapshots(ticker, created_at desc);
create index if not exists idx_allocation_runs_portfolio on fwios.capital_allocation_runs(portfolio_batch_id, created_at desc);
create index if not exists idx_system_events_entity on fwios.system_events(entity_type, entity_id, occurred_at desc);
create index if not exists idx_system_events_type on fwios.system_events(event_type, occurred_at desc);

alter table fwios.policy_registry enable row level security;
alter table fwios.policy_versions enable row level security;
alter table fwios.decision_snapshots enable row level security;
alter table fwios.capital_allocation_runs enable row level security;
alter table fwios.capital_allocation_actions enable row level security;
alter table fwios.capital_allocation_metrics enable row level security;
alter table fwios.system_events enable row level security;

revoke all on fwios.policy_registry from anon, authenticated;
revoke all on fwios.policy_versions from anon, authenticated;
revoke all on fwios.decision_snapshots from anon, authenticated;
revoke all on fwios.capital_allocation_runs from anon, authenticated;
revoke all on fwios.capital_allocation_actions from anon, authenticated;
revoke all on fwios.capital_allocation_metrics from anon, authenticated;
revoke all on fwios.system_events from anon, authenticated;
