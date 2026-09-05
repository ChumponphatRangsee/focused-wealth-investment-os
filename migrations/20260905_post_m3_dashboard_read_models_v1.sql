-- Post-M3 Dashboard Read Models v1
-- Read-only monitoring layer. Supabase remains System of Record; Google Sheets is display-only.

create or replace view fwios.v_dashboard_holdings
with (security_invoker = true)
as
with latest_batch as (
  select batch_id, observed_at from fwios.v_latest_portfolio_batch
), open_positions as (
  select p.* from fwios.v_portfolio_positions_current p
  join latest_batch b on b.batch_id=p.batch_id
  where upper(p.source_position_status)='OPEN'
    and coalesce(p.source_snapshot_value_thb,0)>0
), all_rows as (
  select 'ALL'::text account_view_key,'All Accounts'::text account_view_name,
         asset_symbol,asset_class,sum(quantity)::numeric quantity,
         sum(cost_basis_thb)::numeric cost_basis_thb,
         sum(source_snapshot_value_thb)::numeric value_thb,
         sum(source_unrealized_pnl_thb)::numeric unrealized_pnl_thb
  from open_positions group by asset_symbol,asset_class
), account_rows as (
  select account_key account_view_key,account_name account_view_name,
         asset_symbol,asset_class,sum(quantity)::numeric quantity,
         sum(cost_basis_thb)::numeric cost_basis_thb,
         sum(source_snapshot_value_thb)::numeric value_thb,
         sum(source_unrealized_pnl_thb)::numeric unrealized_pnl_thb
  from open_positions group by account_key,account_name,asset_symbol,asset_class
), combined as (
  select * from all_rows union all select * from account_rows
)
select c.account_view_key,c.account_view_name,c.asset_symbol,c.asset_class,c.quantity,
       c.cost_basis_thb,c.value_thb,c.unrealized_pnl_thb,
       case when c.cost_basis_thb<>0 then c.unrealized_pnl_thb/c.cost_basis_thb end unrealized_return_pct,
       case when sum(c.value_thb) over(partition by c.account_view_key)<>0
            then c.value_thb/sum(c.value_thb) over(partition by c.account_view_key) end view_weight,
       b.batch_id,b.observed_at
from combined c cross join latest_batch b;

create or replace view fwios.v_dashboard_account_summary
with (security_invoker = true)
as
with latest_batch as (
  select batch_id,observed_at,status batch_status from fwios.v_latest_portfolio_batch
), realized_by_account as (
  select t.account_key,coalesce(sum(t.source_realized_pnl_thb),0)::numeric realized_pnl_thb
  from fwios.portfolio_transactions t join latest_batch b on b.batch_id=t.batch_id
  group by t.account_key
), realized_all as (
  select coalesce(sum(realized_pnl_thb),0)::numeric realized_pnl_thb from realized_by_account
), base as (
  select h.account_view_key,h.account_view_name,sum(h.value_thb)::numeric portfolio_value_thb,
         sum(h.cost_basis_thb)::numeric open_cost_basis_thb,
         sum(h.unrealized_pnl_thb)::numeric unrealized_pnl_thb,
         count(*)::integer unique_open_assets,
         coalesce(sum(h.value_thb) filter(where upper(h.asset_class)='CRYPTO'),0)::numeric crypto_value_thb
  from fwios.v_dashboard_holdings h group by h.account_view_key,h.account_view_name
), largest as (
  select distinct on(h.account_view_key) h.account_view_key,h.asset_symbol largest_position_symbol,h.view_weight largest_position_weight
  from fwios.v_dashboard_holdings h order by h.account_view_key,h.value_thb desc,h.asset_symbol
)
select b.account_view_key,b.account_view_name,b.portfolio_value_thb,b.open_cost_basis_thb,b.unrealized_pnl_thb,
       case when b.account_view_key='ALL' then ra.realized_pnl_thb else coalesce(r.realized_pnl_thb,0) end realized_pnl_thb,
       b.unrealized_pnl_thb + case when b.account_view_key='ALL' then ra.realized_pnl_thb else coalesce(r.realized_pnl_thb,0) end total_pnl_thb,
       b.unique_open_assets,
       case when b.portfolio_value_thb<>0 then b.crypto_value_thb/b.portfolio_value_thb end crypto_weight,
       l.largest_position_symbol,l.largest_position_weight,
       1000000::numeric phase1_goal_thb,b.portfolio_value_thb/1000000::numeric phase1_goal_progress,
       lb.batch_id,lb.observed_at,lb.batch_status
from base b left join realized_by_account r on r.account_key=b.account_view_key
cross join realized_all ra cross join latest_batch lb
left join largest l on l.account_view_key=b.account_view_key;

create or replace view fwios.v_dashboard_opportunities
with (security_invoker = true)
as
select r.opportunity_bucket,r.bucket_rank,r.ticker,r.priority_score core_score,
       r.business_thesis_score,r.expected_return_score,r.portfolio_fit_score,r.downside_risk_score,
       r.eligibility_gate,r.rationale_code,d.decision_state,d.promotion_gate,d.input_integrity_gate,
       m.current_price,m.probability_weighted_fv_per_share,m.probability_weighted_upside,
       m.effective_mispricing_gate mispricing_gate,m.effective_mispricing_class mispricing_class,
       r.ranking_run_id,r.decision_snapshot_id,r.created_at
from fwios.v_opportunity_ranking_current r
join fwios.v_latest_decision_snapshots d on d.decision_snapshot_id=r.decision_snapshot_id
left join fwios.v_valuation_mispricing_current m on m.mispricing_snapshot_id=d.mispricing_snapshot_id;

create or replace view fwios.v_dashboard_current_action
with (security_invoker = true)
as
with prod_packet as (
  select * from fwios.v_human_approval_current
  where request_scope='PRODUCTION_USER_REQUESTED'
  order by created_at desc limit 1
), top_immediate as (
  select * from fwios.v_dashboard_opportunities
  where opportunity_bucket='IMMEDIATE_BUY_CANDIDATE'
  order by bucket_rank limit 1
)
select case
         when p.approval_packet_id is not null and p.current_state='PENDING' then 'HUMAN_REVIEW_REQUIRED'
         when p.approval_packet_id is not null and p.current_state='APPROVED' then 'APPROVED_AWAITING_HUMAN_BROKER_STEP'
         when p.approval_packet_id is not null and p.current_state in('REJECTED','EXPIRED','STALE') then 'NO_LIVE_ACTIONABLE_PACKET'
         when i.ticker is not null then 'READY_FOR_CAPITAL_INPUT'
         else 'NO_ACTIONABLE_OPPORTUNITY' end action_state,
       coalesce(p.candidate_ticker,i.ticker) candidate_ticker,p.source_ticker,p.new_cash_thb,p.add_amount_thb,p.trim_amount_thb,
       p.current_state approval_state,p.traceability_gate,p.freshness_gate,
       i.core_score candidate_core_score,i.portfolio_fit_score candidate_portfolio_fit_score,
       case when p.approval_packet_id is not null then 'Live production-user approval packet state.'
            when i.ticker is not null then 'Immediate candidate exists, but no production-user capital/rebalance request has been materialized.'
            else 'No Immediate candidate currently clears the production gates.' end action_note,
       false::boolean auto_trade,true::boolean human_execution_only
from (select 1) x left join prod_packet p on true left join top_immediate i on true;

create or replace view fwios.v_dashboard_alerts
with (security_invoker = true)
as
with all_summary as (select * from fwios.v_dashboard_account_summary where account_view_key='ALL'),
largest as (select asset_symbol,view_weight from fwios.v_dashboard_holdings where account_view_key='ALL' order by value_thb desc,asset_symbol limit 1),
latest_batch as (select * from fwios.v_latest_portfolio_batch)
select * from (
  select 1 alert_order,'CONCENTRATION'::text alert_type,'Largest Position'::text label,l.asset_symbol::text subject,l.view_weight::numeric current_value,
         0.30::numeric lower_threshold,null::numeric upper_threshold,
         case when l.view_weight>0.30 then 'REVIEW' else 'OK' end::text status,
         case when l.view_weight>0.30 then 'Above exceptional single-stock review threshold' else 'Within concentration review threshold' end::text note
  from largest l
  union all
  select 2,'CRYPTO_EXPOSURE','Crypto Exposure','Crypto',s.crypto_weight,0.15::numeric,0.20::numeric,
         case when s.crypto_weight>0.20 then 'ABOVE_TARGET' when s.crypto_weight<0.15 then 'BELOW_TARGET' else 'OK' end,
         'Phase-1 target range 15–20%; deviation is a review flag, not an automatic sell signal' from all_summary s
  union all
  select 3,'FOCUS','Open Assets','Portfolio',s.unique_open_assets::numeric,5::numeric,8::numeric,
         case when s.unique_open_assets between 5 and 8 then 'OK' else 'REVIEW' end,
         'Focused Wealth preference is 5–8 meaningful positions' from all_summary s
  union all
  select 4,'PORTFOLIO_RECONCILIATION','Portfolio Batch','System',null::numeric,null::numeric,null::numeric,
         case when b.status='PASS' then 'PASS' else 'BLOCKED' end,coalesce(b.failure_reason,'Latest portfolio batch reconciled') from latest_batch b
) a;

create or replace view fwios.v_dashboard_system_health
with (security_invoker = true)
as
with foundation as (select state_value from fwios.system_state where state_key='foundation_version'),
arch as (select state_value from fwios.system_state where state_key='architecture_consolidation_v1'),
sector as (select state_value from fwios.system_state where state_key='sector_loop'),
m3 as (select state_value from fwios.system_state where state_key='m3_human_approval_cutover'),
batch as (select * from fwios.v_latest_portfolio_batch),
model_debt as (select count(*)::integer open_model_blockers from fwios.v_open_model_debt)
select f.state_value->>'version' foundation_version,f.state_value->>'contract' contract_id,f.state_value->>'status' foundation_status,
       a.state_value->>'github_merge_sha' github_merge_sha,m.state_value->>'m3_overall' m3_status,m.state_value->>'policy' approval_policy,
       m.state_value->>'regressions' approval_regressions,m.state_value->>'traceability_layers' cutover_traceability,
       s.state_value->>'automation_mode' sector_automation_mode,s.state_value->>'next_queued_sector' next_queued_sector,s.state_value->>'next_action' next_action,
       b.batch_id portfolio_batch_id,b.status portfolio_batch_status,b.source_transaction_count,b.transaction_pass_count,b.source_position_count,b.position_pass_count,
       d.open_model_blockers,false::boolean auto_trade,true::boolean human_execution_only,now() read_model_checked_at
from foundation f cross join arch a cross join sector s cross join m3 m cross join batch b cross join model_debt d;

revoke all on fwios.v_dashboard_holdings from public,anon,authenticated;
revoke all on fwios.v_dashboard_account_summary from public,anon,authenticated;
revoke all on fwios.v_dashboard_opportunities from public,anon,authenticated;
revoke all on fwios.v_dashboard_current_action from public,anon,authenticated;
revoke all on fwios.v_dashboard_alerts from public,anon,authenticated;
revoke all on fwios.v_dashboard_system_health from public,anon,authenticated;

comment on view fwios.v_dashboard_account_summary is 'Stable post-M3 dashboard account summaries. Total P&L = latest-batch realized P&L + current open-position unrealized P&L.';
comment on view fwios.v_dashboard_holdings is 'Stable post-M3 dashboard holdings for ALL and account-specific views. Display/read-only; no production decision logic.';
comment on view fwios.v_dashboard_opportunities is 'Stable post-M3 dashboard opportunity read model sourced from active ranking and Decision Snapshot lineage.';
comment on view fwios.v_dashboard_current_action is 'Dashboard state summary only. READY_FOR_CAPITAL_INPUT is not a trade recommendation; materialized recommendations require explicit user request.';
comment on view fwios.v_dashboard_alerts is 'Consolidated portfolio review alerts. REVIEW flags are not automatic sell signals.';
comment on view fwios.v_dashboard_system_health is 'Post-M3 dashboard system health/read-model handshake.';