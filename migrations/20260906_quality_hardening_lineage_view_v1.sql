-- Expose quality-hardening lineage on the latest Decision Snapshot view.
create or replace view fwios.v_latest_decision_snapshots
with (security_invoker=true)
as
select *
from (
  select d.decision_snapshot_id,d.ticker,d.portfolio_batch_id,d.price_snapshot_id,d.valuation_run_id,
         d.mispricing_snapshot_id,d.portfolio_fit_snapshot_id,d.revision_snapshot_id,d.chase_snapshot_id,
         d.score_snapshot_id,d.scoring_policy_version_id,d.revision_policy_version_id,d.chase_policy_version_id,
         d.core_score,d.decision_state,d.promotion_gate,d.input_integrity_gate,d.decision_payload,
         d.hardening_snapshot_id,d.created_at,
         row_number() over(partition by d.ticker order by d.created_at desc,d.decision_snapshot_id desc) as rn
  from fwios.decision_snapshots d
) x
where rn=1;
