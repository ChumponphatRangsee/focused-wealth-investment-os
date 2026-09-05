begin;

insert into fwios.policy_registry (policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status)
values (
  'OPPORTUNITY_RANKING',
  'CAPITAL_ALLOCATION',
  'Opportunity Ranking',
  'Rank production Decision Snapshots without creating a second weighted investment score. Promotion PASS enters Immediate; value-only mispricing failures with all other gates PASS enter Watchlist.',
  'fwios.opportunity_ranked_candidates',
  'DRAFT'
)
on conflict (policy_key) do nothing;

insert into fwios.policy_versions (policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference)
values (
  'POL-OPPORTUNITY-RANKING-V1-DRAFT',
  'OPPORTUNITY_RANKING',
  '1.0-draft',
  'DRAFT',
  true,
  jsonb_build_object(
    'source','latest production decision snapshot per ticker',
    'priority_score','core_score only; no additional weighted score',
    'immediate_rule','input_integrity PASS + promotion_gate PASS',
    'watchlist_rule','input_integrity PASS + only mispricing FAIL - INSUFFICIENT MISPRICING while quality/valuation/portfolio/downside/revision/chase/core_scoring PASS',
    'tie_break_order',jsonb_build_array('expected_return_score DESC','portfolio_fit_score DESC','downside_risk_score DESC','business_thesis_score DESC','ticker ASC'),
    'max_immediate',3,
    'max_watchlist',5,
    'excluded_policy','all other states remain visible in audit table but are not surfaced in current opportunity view',
    'human_execution_only',true
  ),
  'FWIOS M3 Opportunity Ranking v1 design; core score already embeds 30/30/25/15 so ranking must not double-count components'
)
on conflict (policy_version_id) do nothing;

create table if not exists fwios.opportunity_ranking_runs (
  ranking_run_id text primary key,
  policy_version_id text not null references fwios.policy_versions(policy_version_id),
  portfolio_batch_id text not null,
  status text not null check (status in ('RUNNING','PASS','BLOCKED','FAILED')),
  source_reference text not null,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists fwios.opportunity_ranked_candidates (
  ranking_candidate_id text primary key,
  ranking_run_id text not null references fwios.opportunity_ranking_runs(ranking_run_id) on delete cascade,
  ticker text not null,
  decision_snapshot_id text not null references fwios.decision_snapshots(decision_snapshot_id),
  score_snapshot_id text not null,
  opportunity_bucket text not null check (opportunity_bucket in ('IMMEDIATE_BUY_CANDIDATE','WATCHLIST_VALUE_WAIT','EXCLUDED')),
  bucket_rank integer,
  priority_score numeric not null,
  expected_return_score numeric not null,
  portfolio_fit_score numeric not null,
  downside_risk_score numeric not null,
  business_thesis_score numeric not null,
  eligibility_gate text not null,
  rationale_code text not null,
  source_reference text not null,
  created_at timestamptz not null default now(),
  unique (ranking_run_id,ticker)
);

alter table fwios.opportunity_ranking_runs enable row level security;
alter table fwios.opportunity_ranked_candidates enable row level security;
revoke all on fwios.opportunity_ranking_runs from anon, authenticated;
revoke all on fwios.opportunity_ranked_candidates from anon, authenticated;

create or replace function fwios.opportunity_bucket_v1(
  promotion_gate text,
  mispricing_gate text,
  quality_gate text,
  valuation_gate text,
  portfolio_gate text,
  downside_gate text,
  revision_gate text,
  chase_gate text,
  core_scoring_gate text,
  input_integrity_gate text
) returns text
language sql
immutable
parallel safe
set search_path to 'pg_catalog','fwios'
as $function$
select case
  when input_integrity_gate <> 'PASS' then 'EXCLUDED'
  when promotion_gate = 'PASS' then 'IMMEDIATE_BUY_CANDIDATE'
  when mispricing_gate = 'FAIL - INSUFFICIENT MISPRICING'
   and quality_gate = 'PASS'
   and valuation_gate = 'PASS'
   and portfolio_gate = 'PASS'
   and downside_gate = 'PASS'
   and revision_gate = 'PASS'
   and chase_gate = 'PASS'
   and core_scoring_gate = 'PASS'
    then 'WATCHLIST_VALUE_WAIT'
  else 'EXCLUDED'
end
$function$;

create or replace function fwios.opportunity_priority_score_v1(core_score numeric)
returns numeric
language sql
immutable
parallel safe
strict
set search_path to 'pg_catalog','fwios'
as $function$
select round(core_score,4)
$function$;

create or replace view fwios.v_latest_decision_snapshots
with (security_invoker=true)
as
select * from (
  select d.*,
         row_number() over (partition by d.ticker order by d.created_at desc,d.decision_snapshot_id desc) as rn
  from fwios.decision_snapshots d
) x
where rn=1;

create or replace view fwios.v_opportunity_ranking_current
with (security_invoker=true)
as
with latest_run as (
  select ranking_run_id
  from fwios.opportunity_ranking_runs
  where status='PASS'
  order by completed_at desc nulls last,created_at desc,ranking_run_id desc
  limit 1
)
select c.*
from fwios.opportunity_ranked_candidates c
join latest_run r using (ranking_run_id)
where c.opportunity_bucket <> 'EXCLUDED';

commit;
