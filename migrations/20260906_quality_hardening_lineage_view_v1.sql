-- Expose quality-hardening lineage while preserving all existing view column positions.
create or replace view fwios.v_latest_decision_snapshots
with (security_invoker=true)
as
select decision_snapshot_id,ticker,portfolio_batch_id,price_snapshot_id,valuation_run_id,
       mispricing_snapshot_id,portfolio_fit_snapshot_id,revision_snapshot_id,chase_snapshot_id,
       score_snapshot_id,scoring_policy_version_id,revision_policy_version_id,chase_policy_version_id,
       core_score,decision_state,promotion_gate,input_integrity_gate,decision_payload,created_at,rn,
       hardening_snapshot_id
from (
  select d.decision_snapshot_id,d.ticker,d.portfolio_batch_id,d.price_snapshot_id,d.valuation_run_id,
         d.mispricing_snapshot_id,d.portfolio_fit_snapshot_id,d.revision_snapshot_id,d.chase_snapshot_id,
         d.score_snapshot_id,d.scoring_policy_version_id,d.revision_policy_version_id,d.chase_policy_version_id,
         d.core_score,d.decision_state,d.promotion_gate,d.input_integrity_gate,d.decision_payload,d.created_at,
         row_number() over(partition by d.ticker order by d.created_at desc,d.decision_snapshot_id desc) as rn,
         d.hardening_snapshot_id
  from fwios.decision_snapshots d
) x
where rn=1;
