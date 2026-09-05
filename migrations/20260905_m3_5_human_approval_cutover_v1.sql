-- M3.5 Human Approval / Cutover v1
-- Recommendation snapshot -> immutable approval packet -> append-only approval event.
-- Human approval never submits broker orders and never mutates portfolio accounting.

alter table fwios.rebalancing_recommendation_runs
  add column run_scope text not null default 'PRODUCTION_USER_REQUESTED';
alter table fwios.rebalancing_recommendation_runs
  add constraint rebalancing_recommendation_runs_run_scope_check
  check (run_scope in ('PRODUCTION_USER_REQUESTED','CUTOVER_VALIDATION','SYNTHETIC_TEST'));

create table fwios.human_approval_packets (
  approval_packet_id text primary key,
  policy_version_id text not null references fwios.policy_versions(policy_version_id),
  recommendation_run_id text not null unique references fwios.rebalancing_recommendation_runs(recommendation_run_id),
  request_scope text not null check (request_scope in ('PRODUCTION_USER_REQUESTED','CUTOVER_VALIDATION','SYNTHETIC_TEST')),
  packet_status text not null check (packet_status in ('PENDING','VALIDATION_ONLY','BLOCKED')),
  portfolio_batch_id text not null references fwios.portfolio_import_batches(batch_id),
  ranking_run_id text not null references fwios.opportunity_ranking_runs(ranking_run_id),
  recommendation_policy_version_id text not null references fwios.policy_versions(policy_version_id),
  candidate_ticker text not null,
  source_ticker text,
  new_cash_thb numeric not null check (new_cash_thb >= 0),
  add_amount_thb numeric not null check (add_amount_thb >= 0),
  trim_amount_thb numeric not null check (trim_amount_thb >= 0),
  candidate_decision_snapshot_id text references fwios.decision_snapshots(decision_snapshot_id),
  source_valuation_run_id text references fwios.valuation_runs(run_id),
  candidate_price_snapshot_id text references fwios.market_price_snapshots(snapshot_id),
  source_price_snapshot_id text references fwios.market_price_snapshots(snapshot_id),
  recommendation_fingerprint text not null,
  traceability_gate text not null,
  freshness_gate text not null,
  input_fresh_until timestamptz not null,
  approval_required boolean not null default true check (approval_required = true),
  auto_trade boolean not null default false check (auto_trade = false),
  source_reference text not null,
  created_at timestamptz not null default now()
);

create table fwios.human_approval_events (
  approval_event_id text primary key,
  approval_packet_id text not null references fwios.human_approval_packets(approval_packet_id),
  event_type text not null check (event_type in ('APPROVED','REJECTED','EXPIRED','STALE')),
  prior_state text not null check (prior_state in ('PENDING','APPROVED','REJECTED','EXPIRED','STALE','VALIDATION_ONLY')),
  resulting_state text not null check (resulting_state in ('APPROVED','REJECTED','EXPIRED','STALE')),
  actor_type text not null check (actor_type in ('HUMAN','SYSTEM')),
  actor_ref text not null,
  revalidation_gate text not null,
  broker_order_created boolean not null default false check (broker_order_created = false),
  portfolio_mutation_applied boolean not null default false check (portfolio_mutation_applied = false),
  notes text,
  created_at timestamptz not null default now(),
  unique (approval_packet_id,event_type)
);

create table fwios.m3_cutover_validations (
  validation_id text primary key,
  contract_version text not null,
  portfolio_batch_id text not null references fwios.portfolio_import_batches(batch_id),
  recommendation_run_id text not null references fwios.rebalancing_recommendation_runs(recommendation_run_id),
  approval_packet_id text not null references fwios.human_approval_packets(approval_packet_id),
  transaction_reconciliation_gate text not null,
  position_reconciliation_gate text not null,
  recommendation_traceability_gate text not null,
  approval_packet_integrity_gate text not null,
  non_mutation_gate text not null,
  auto_trade_gate text not null,
  overall_status text not null check (overall_status in ('PASS','FAIL')),
  source_reference text not null,
  created_at timestamptz not null default now()
);

alter table fwios.human_approval_packets enable row level security;
alter table fwios.human_approval_events enable row level security;
alter table fwios.m3_cutover_validations enable row level security;
revoke all on fwios.human_approval_packets from anon,authenticated;
revoke all on fwios.human_approval_events from anon,authenticated;
revoke all on fwios.m3_cutover_validations from anon,authenticated;

create or replace function fwios.immutable_snapshot_guard_v1()
returns trigger language plpgsql
set search_path = pg_catalog, fwios
as $$
begin
  raise exception 'IMMUTABLE_SNAPSHOT: % cannot be updated or deleted',tg_table_name;
end;
$$;

create trigger rebalancing_recommendation_runs_immutable_v1 before update or delete on fwios.rebalancing_recommendation_runs for each row execute function fwios.immutable_snapshot_guard_v1();
create trigger rebalancing_recommendation_actions_immutable_v1 before update or delete on fwios.rebalancing_recommendation_actions for each row execute function fwios.immutable_snapshot_guard_v1();
create trigger rebalancing_recommendation_metrics_immutable_v1 before update or delete on fwios.rebalancing_recommendation_metrics for each row execute function fwios.immutable_snapshot_guard_v1();
create trigger human_approval_packets_immutable_v1 before update or delete on fwios.human_approval_packets for each row execute function fwios.immutable_snapshot_guard_v1();
create trigger human_approval_events_immutable_v1 before update or delete on fwios.human_approval_events for each row execute function fwios.immutable_snapshot_guard_v1();
create trigger m3_cutover_validations_immutable_v1 before update or delete on fwios.m3_cutover_validations for each row execute function fwios.immutable_snapshot_guard_v1();

insert into fwios.policy_registry(policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status)
values ('HUMAN_APPROVAL','Capital Allocation','Human Approval / Cutover','Gate immutable recommendations through explicit human decision with freshness revalidation and no trade execution','fwios.human_approval_packets','DRAFT')
on conflict (policy_key) do nothing;

insert into fwios.policy_versions(policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference)
values ('POL-HUMAN-APPROVAL-V1','HUMAN_APPROVAL','1.0','DRAFT',false,
 jsonb_build_object('human_approval_required',true,'approvable_scope','PRODUCTION_USER_REQUESTED','validation_scope_not_approvable',true,'freshness_revalidation_required',true,'terminal_states',jsonb_build_array('APPROVED','REJECTED','EXPIRED','STALE'),'approval_places_order',false,'approval_mutates_portfolio',false,'new_packet_required_after_stale_or_expired',true),
 'migrations/20260905_m3_5_human_approval_cutover_v1.sql')
on conflict (policy_version_id) do nothing;

create or replace function fwios.recommendation_snapshot_fingerprint_v1(p_recommendation_run_id text)
returns text language sql stable
set search_path = pg_catalog, fwios
as $$
select md5(concat_ws('|',r.recommendation_run_id,r.policy_version_id,r.portfolio_batch_id,r.ranking_run_id,r.status,r.new_cash_thb,r.run_scope,r.source_reference,
 coalesce((select string_agg(concat_ws(':',a.sequence_no,a.asset_symbol,a.action_type,a.amount_thb,coalesce(a.decision_snapshot_id,''),coalesce(a.valuation_run_id,''),coalesce(a.rationale_code,'')),'|' order by a.sequence_no) from fwios.rebalancing_recommendation_actions a where a.recommendation_run_id=r.recommendation_run_id),''),
 coalesce((select string_agg(concat_ws(':',m.metric_name,coalesce(m.before_value::text,''),coalesce(m.after_value::text,''),coalesce(m.unit,''),coalesce(m.gate,''),coalesce(m.note,'')),'|' order by m.metric_name) from fwios.rebalancing_recommendation_metrics m where m.recommendation_run_id=r.recommendation_run_id),'')))
from fwios.rebalancing_recommendation_runs r where r.recommendation_run_id=p_recommendation_run_id;
$$;

create or replace function fwios.recommendation_traceability_gate_v1(p_recommendation_run_id text)
returns text language plpgsql stable
set search_path = pg_catalog, fwios
as $$
declare r fwios.rebalancing_recommendation_runs%rowtype;
begin
 select * into r from fwios.rebalancing_recommendation_runs where recommendation_run_id=p_recommendation_run_id;
 if not found then return 'BLOCKED - RECOMMENDATION RUN MISSING'; end if;
 if r.status<>'READY' then return 'BLOCKED - RECOMMENDATION NOT READY'; end if;
 if not exists(select 1 from fwios.policy_versions pv join fwios.policy_registry pr using(policy_key) where pv.policy_version_id=r.policy_version_id and pv.lifecycle_status='ACTIVE' and pr.lifecycle_status='ACTIVE') then return 'BLOCKED - REBALANCE POLICY INACTIVE'; end if;
 if not exists(select 1 from fwios.portfolio_import_batches b where b.batch_id=r.portfolio_batch_id and b.status='PASS' and b.transaction_pass_count=b.source_transaction_count and b.position_pass_count=b.source_position_count) then return 'BLOCKED - PORTFOLIO BATCH NOT RECONCILED'; end if;
 if not exists(select 1 from fwios.opportunity_ranking_runs o join fwios.policy_versions pv on pv.policy_version_id=o.policy_version_id join fwios.policy_registry pr using(policy_key) where o.ranking_run_id=r.ranking_run_id and o.portfolio_batch_id=r.portfolio_batch_id and o.status='PASS' and pv.lifecycle_status='ACTIVE' and pr.lifecycle_status='ACTIVE') then return 'BLOCKED - RANKING LINEAGE INVALID'; end if;
 if not exists(select 1 from fwios.rebalancing_recommendation_actions a where a.recommendation_run_id=r.recommendation_run_id and a.action_type='ADD' and a.amount_thb>0) then return 'BLOCKED - ADD ACTION MISSING'; end if;
 if exists(select 1 from fwios.rebalancing_recommendation_actions a left join fwios.decision_snapshots d on d.decision_snapshot_id=a.decision_snapshot_id left join fwios.market_price_snapshots px on px.snapshot_id=d.price_snapshot_id where a.recommendation_run_id=r.recommendation_run_id and a.action_type='ADD' and (d.decision_snapshot_id is null or d.portfolio_batch_id<>r.portfolio_batch_id or d.input_integrity_gate<>'PASS' or d.promotion_gate<>'PASS' or px.price_gate<>'PASS' or px.provenance_status<>'PASS' or px.fresh_until<=now() or not exists(select 1 from fwios.opportunity_ranked_candidates c where c.ranking_run_id=r.ranking_run_id and c.ticker=a.asset_symbol and c.decision_snapshot_id=a.decision_snapshot_id and c.opportunity_bucket='IMMEDIATE_BUY_CANDIDATE' and c.eligibility_gate='PASS'))) then return 'BLOCKED - ADD LINEAGE OR PRICE STALE'; end if;
 if exists(select 1 from fwios.rebalancing_recommendation_actions a where a.recommendation_run_id=r.recommendation_run_id and a.action_type='TRIM' and (a.valuation_run_id is null or not exists(select 1 from fwios.v_portfolio_exposure_current pe where pe.asset_symbol=a.asset_symbol and pe.value_thb>=a.amount_thb) or not exists(select 1 from fwios.v_holding_valuation_coverage_current h where h.ticker=a.asset_symbol and h.run_id=a.valuation_run_id) or not exists(select 1 from fwios.valuation_runs vr join fwios.market_price_snapshots px on px.snapshot_id=vr.source_snapshot where vr.run_id=a.valuation_run_id and px.price_gate='PASS' and px.provenance_status='PASS' and px.fresh_until>now()))) then return 'BLOCKED - TRIM LINEAGE OR PRICE STALE'; end if;
 if exists(select 1 from fwios.rebalancing_recommendation_actions a where a.recommendation_run_id=r.recommendation_run_id and a.action_type='HOLD' and a.asset_symbol<>'CASH_THB') then return 'BLOCKED - INVALID HOLD ACTION'; end if;
 return 'PASS';
end;
$$;

create or replace function fwios.human_approval_transition_v1(p_current_state text,p_event_type text,p_request_scope text,p_revalidation_gate text)
returns text language sql immutable
set search_path = pg_catalog, fwios
as $$
select case
 when p_request_scope<>'PRODUCTION_USER_REQUESTED' then 'BLOCKED - NONACTIONABLE SCOPE'
 when p_current_state in ('APPROVED','REJECTED','EXPIRED','STALE') then 'BLOCKED - TERMINAL STATE'
 when p_current_state<>'PENDING' then 'BLOCKED - INVALID CURRENT STATE'
 when p_event_type='APPROVED' and p_revalidation_gate='PASS' then 'APPROVED'
 when p_event_type='APPROVED' then 'BLOCKED - REVALIDATION FAILED'
 when p_event_type='REJECTED' then 'REJECTED'
 when p_event_type='EXPIRED' then 'EXPIRED'
 when p_event_type='STALE' then 'STALE'
 else 'BLOCKED - INVALID EVENT' end;
$$;

create or replace function fwios.materialize_rebalancing_recommendation_snapshot_v1(p_recommendation_run_id text,p_new_cash_thb numeric,p_run_scope text,p_source_reference text)
returns text language plpgsql volatile
set search_path = pg_catalog, fwios
as $$
declare x record; v_decision text; v_source_val text; v_residual numeric;
begin
 if p_recommendation_run_id is null or btrim(p_recommendation_run_id)='' then raise exception 'recommendation_run_id required'; end if;
 if p_run_scope not in ('PRODUCTION_USER_REQUESTED','CUTOVER_VALIDATION','SYNTHETIC_TEST') then raise exception 'invalid run_scope'; end if;
 if exists(select 1 from fwios.rebalancing_recommendation_runs where recommendation_run_id=p_recommendation_run_id) then raise exception 'recommendation run already exists'; end if;
 select * into x from fwios.preview_rebalancing_recommendation_v1(p_new_cash_thb) limit 1;
 if not found then raise exception 'no recommendation preview'; end if;
 if x.total_candidate_add_thb<=0 then raise exception 'no deployable candidate amount'; end if;
 if x.recommendation_gate like 'BLOCKED%' then raise exception 'recommendation preview blocked: %',x.recommendation_gate; end if;
 select decision_snapshot_id into v_decision from fwios.v_opportunity_ranking_current where ticker=x.candidate_ticker and opportunity_bucket='IMMEDIATE_BUY_CANDIDATE' and eligibility_gate='PASS' order by bucket_rank limit 1;
 if x.source_ticker is not null then select run_id into v_source_val from fwios.v_holding_valuation_coverage_current where ticker=x.source_ticker limit 1; end if;
 insert into fwios.rebalancing_recommendation_runs(recommendation_run_id,policy_version_id,portfolio_batch_id,ranking_run_id,status,new_cash_thb,source_reference,created_at,completed_at,run_scope)
 select p_recommendation_run_id,'POL-REBALANCE-V1',c.portfolio_batch_id,c.ranking_run_id,'READY',greatest(p_new_cash_thb,0),p_source_reference,now(),now(),p_run_scope from fwios.v_new_cash_allocation_current_context c limit 1;
 if x.recommended_trim_thb>0 then insert into fwios.rebalancing_recommendation_actions(recommendation_action_id,recommendation_run_id,sequence_no,asset_symbol,action_type,amount_thb,valuation_run_id,rationale_code) values (p_recommendation_run_id||':TRIM:1',p_recommendation_run_id,1,x.source_ticker,'TRIM',x.recommended_trim_thb,v_source_val,x.rationale_code); end if;
 insert into fwios.rebalancing_recommendation_actions(recommendation_action_id,recommendation_run_id,sequence_no,asset_symbol,action_type,amount_thb,decision_snapshot_id,rationale_code) values (p_recommendation_run_id||':ADD:2',p_recommendation_run_id,2,x.candidate_ticker,'ADD',x.total_candidate_add_thb,v_decision,case when x.recommended_trim_thb>0 then x.rationale_code else 'NEW_CASH_FIRST' end);
 v_residual:=greatest(p_new_cash_thb,0)-x.new_cash_add_thb;
 if v_residual>0 then insert into fwios.rebalancing_recommendation_actions(recommendation_action_id,recommendation_run_id,sequence_no,asset_symbol,action_type,amount_thb,rationale_code) values (p_recommendation_run_id||':HOLD:3',p_recommendation_run_id,3,'CASH_THB','HOLD',v_residual,'RESIDUAL_CASH_HELD'); end if;
 insert into fwios.rebalancing_recommendation_metrics(recommendation_metric_id,recommendation_run_id,metric_name,before_value,after_value,unit,gate,note) values
 (p_recommendation_run_id||':METRIC:EDGE',p_recommendation_run_id,'opportunity_edge',x.source_pw_upside,x.candidate_pw_upside,'ratio',case when x.opportunity_edge is null or x.opportunity_edge>=0.25 then 'PASS' else 'BLOCKED' end,'Candidate PW upside minus source holding PW upside.'),
 (p_recommendation_run_id||':METRIC:EV',p_recommendation_run_id,'modeled_expected_value_change_thb',0,x.modeled_expected_value_change_thb,'THB',case when x.modeled_expected_value_change_thb is null and x.recommended_trim_thb>0 then 'BLOCKED' else 'PASS' end,'Changed-assets modeled expected-value delta.'),
 (p_recommendation_run_id||':METRIC:SOURCE_WEIGHT',p_recommendation_run_id,'source_stock_weight',x.source_before_weight,x.source_after_weight,'ratio','PASS','30% is review threshold, not forced target.'),
 (p_recommendation_run_id||':METRIC:CAND_WEIGHT',p_recommendation_run_id,'candidate_weight',0,x.candidate_after_weight,'ratio','PASS','Post-recommendation candidate weight.');
 return p_recommendation_run_id;
end;
$$;

create or replace function fwios.materialize_human_approval_packet_v1(p_approval_packet_id text,p_recommendation_run_id text,p_request_scope text,p_source_reference text)
returns text language plpgsql volatile
set search_path = pg_catalog, fwios
as $$
declare r fwios.rebalancing_recommendation_runs%rowtype; a_add record; a_trim record; v_candidate_px text; v_source_px text; v_candidate_until timestamptz; v_source_until timestamptz; v_fresh_until timestamptz; v_trace text; v_fresh text; v_status text;
begin
 select * into r from fwios.rebalancing_recommendation_runs where recommendation_run_id=p_recommendation_run_id;
 if not found then raise exception 'recommendation run missing'; end if;
 if r.run_scope<>p_request_scope then raise exception 'request_scope must match recommendation run scope'; end if;
 if exists(select 1 from fwios.human_approval_packets where approval_packet_id=p_approval_packet_id or recommendation_run_id=p_recommendation_run_id) then raise exception 'approval packet already exists'; end if;
 select * into a_add from fwios.rebalancing_recommendation_actions where recommendation_run_id=p_recommendation_run_id and action_type='ADD' order by sequence_no limit 1;
 select * into a_trim from fwios.rebalancing_recommendation_actions where recommendation_run_id=p_recommendation_run_id and action_type='TRIM' order by sequence_no limit 1;
 if a_add.recommendation_action_id is null then raise exception 'ADD action missing'; end if;
 select d.price_snapshot_id,px.fresh_until into v_candidate_px,v_candidate_until from fwios.decision_snapshots d join fwios.market_price_snapshots px on px.snapshot_id=d.price_snapshot_id where d.decision_snapshot_id=a_add.decision_snapshot_id;
 if a_trim.recommendation_action_id is not null then select vr.source_snapshot,px.fresh_until into v_source_px,v_source_until from fwios.valuation_runs vr join fwios.market_price_snapshots px on px.snapshot_id=vr.source_snapshot where vr.run_id=a_trim.valuation_run_id; end if;
 v_fresh_until:=case when v_source_until is null then v_candidate_until else least(v_candidate_until,v_source_until) end;
 v_trace:=fwios.recommendation_traceability_gate_v1(p_recommendation_run_id);
 v_fresh:=case when v_fresh_until>now() then 'PASS' else 'BLOCKED - INPUT STALE' end;
 v_status:=case when p_request_scope='PRODUCTION_USER_REQUESTED' and v_trace='PASS' and v_fresh='PASS' then 'PENDING' when p_request_scope in ('CUTOVER_VALIDATION','SYNTHETIC_TEST') and v_trace='PASS' and v_fresh='PASS' then 'VALIDATION_ONLY' else 'BLOCKED' end;
 insert into fwios.human_approval_packets(approval_packet_id,policy_version_id,recommendation_run_id,request_scope,packet_status,portfolio_batch_id,ranking_run_id,recommendation_policy_version_id,candidate_ticker,source_ticker,new_cash_thb,add_amount_thb,trim_amount_thb,candidate_decision_snapshot_id,source_valuation_run_id,candidate_price_snapshot_id,source_price_snapshot_id,recommendation_fingerprint,traceability_gate,freshness_gate,input_fresh_until,source_reference)
 values (p_approval_packet_id,'POL-HUMAN-APPROVAL-V1',p_recommendation_run_id,p_request_scope,v_status,r.portfolio_batch_id,r.ranking_run_id,r.policy_version_id,a_add.asset_symbol,case when a_trim.recommendation_action_id is null then null else a_trim.asset_symbol end,r.new_cash_thb,a_add.amount_thb,coalesce(a_trim.amount_thb,0),a_add.decision_snapshot_id,a_trim.valuation_run_id,v_candidate_px,v_source_px,fwios.recommendation_snapshot_fingerprint_v1(p_recommendation_run_id),v_trace,v_fresh,v_fresh_until,p_source_reference);
 return p_approval_packet_id;
end;
$$;

create or replace function fwios.human_approval_packet_integrity_gate_v1(p_approval_packet_id text)
returns text language plpgsql stable
set search_path = pg_catalog, fwios
as $$
declare p fwios.human_approval_packets%rowtype;
begin
 select * into p from fwios.human_approval_packets where approval_packet_id=p_approval_packet_id;
 if not found then return 'BLOCKED - APPROVAL PACKET MISSING'; end if;
 if p.recommendation_fingerprint<>fwios.recommendation_snapshot_fingerprint_v1(p.recommendation_run_id) then return 'BLOCKED - RECOMMENDATION FINGERPRINT MISMATCH'; end if;
 if fwios.recommendation_traceability_gate_v1(p.recommendation_run_id)<>'PASS' then return 'BLOCKED - RECOMMENDATION TRACEABILITY'; end if;
 if p.traceability_gate<>'PASS' then return 'BLOCKED - PACKET TRACEABILITY'; end if;
 return 'PASS';
end;
$$;

create or replace function fwios.human_approval_revalidation_gate_v1(p_approval_packet_id text)
returns text language plpgsql stable
set search_path = pg_catalog, fwios
as $$
declare p fwios.human_approval_packets%rowtype; c record;
begin
 select * into p from fwios.human_approval_packets where approval_packet_id=p_approval_packet_id;
 if not found then return 'BLOCKED - APPROVAL PACKET MISSING'; end if;
 if p.request_scope<>'PRODUCTION_USER_REQUESTED' then return 'BLOCKED - NONACTIONABLE SCOPE'; end if;
 if p.packet_status<>'PENDING' then return 'BLOCKED - PACKET NOT PENDING'; end if;
 if not exists(select 1 from fwios.policy_versions pv join fwios.policy_registry pr using(policy_key) where pv.policy_version_id=p.policy_version_id and pv.lifecycle_status='ACTIVE' and pr.lifecycle_status='ACTIVE') then return 'BLOCKED - APPROVAL POLICY INACTIVE'; end if;
 if fwios.human_approval_packet_integrity_gate_v1(p_approval_packet_id)<>'PASS' then return 'BLOCKED - PACKET INTEGRITY'; end if;
 if p.input_fresh_until<=now() then return 'BLOCKED - INPUT STALE'; end if;
 select * into c from fwios.v_new_cash_allocation_current_context limit 1;
 if c.portfolio_batch_id<>p.portfolio_batch_id then return 'BLOCKED - PORTFOLIO BATCH CHANGED'; end if;
 if c.ranking_run_id<>p.ranking_run_id or c.ranking_run_status<>'PASS' or c.ranking_policy_status<>'ACTIVE' then return 'BLOCKED - RANKING CHANGED'; end if;
 return 'PASS';
end;
$$;

create or replace function fwios.record_human_approval_event_v1(p_approval_event_id text,p_approval_packet_id text,p_event_type text,p_actor_type text,p_actor_ref text,p_notes text default null)
returns text language plpgsql volatile
set search_path = pg_catalog, fwios
as $$
declare p fwios.human_approval_packets%rowtype; v_prior text; v_revalidation text; v_result text;
begin
 select * into p from fwios.human_approval_packets where approval_packet_id=p_approval_packet_id;
 if not found then raise exception 'approval packet missing'; end if;
 select resulting_state into v_prior from fwios.human_approval_events where approval_packet_id=p_approval_packet_id order by created_at desc,approval_event_id desc limit 1;
 if v_prior is null then v_prior:=p.packet_status; end if;
 if p_event_type in ('APPROVED','REJECTED') and p_actor_type<>'HUMAN' then raise exception 'human actor required for approve/reject'; end if;
 if p_event_type in ('EXPIRED','STALE') and p_actor_type<>'SYSTEM' then raise exception 'system actor required for expire/stale'; end if;
 v_revalidation:=case when p_event_type='APPROVED' then fwios.human_approval_revalidation_gate_v1(p_approval_packet_id) else 'PASS' end;
 v_result:=fwios.human_approval_transition_v1(v_prior,p_event_type,p.request_scope,v_revalidation);
 if v_result like 'BLOCKED%' then raise exception '%',v_result; end if;
 insert into fwios.human_approval_events(approval_event_id,approval_packet_id,event_type,prior_state,resulting_state,actor_type,actor_ref,revalidation_gate,notes)
 values (p_approval_event_id,p_approval_packet_id,p_event_type,v_prior,v_result,p_actor_type,p_actor_ref,v_revalidation,p_notes);
 return v_result;
end;
$$;

create or replace view fwios.v_human_approval_current
with (security_invoker=true)
as
select p.*,coalesce(e.resulting_state,p.packet_status) current_state,e.event_type latest_event_type,e.actor_type latest_actor_type,e.actor_ref latest_actor_ref,e.revalidation_gate latest_revalidation_gate,e.created_at latest_event_at
from fwios.human_approval_packets p
left join lateral (select * from fwios.human_approval_events x where x.approval_packet_id=p.approval_packet_id order by x.created_at desc,x.approval_event_id desc limit 1) e on true;

create or replace function fwios.m3_5_traceability_layers_v1(p_recommendation_run_id text,p_approval_packet_id text)
returns table(layer_name text,gate text,note text)
language sql stable
set search_path = pg_catalog, fwios
as $$
with r as (select * from fwios.rebalancing_recommendation_runs where recommendation_run_id=p_recommendation_run_id),p as (select * from fwios.human_approval_packets where approval_packet_id=p_approval_packet_id),b as (select b.* from fwios.portfolio_import_batches b join r on r.portfolio_batch_id=b.batch_id)
select 'SOURCE_TRANSACTIONS',case when source_transaction_count=transaction_pass_count and source_transaction_count>0 then 'PASS' else 'FAIL' end,transaction_pass_count||'/'||source_transaction_count||' reconciled' from b
union all select 'SOURCE_POSITIONS',case when source_position_count=position_pass_count and source_position_count>0 then 'PASS' else 'FAIL' end,position_pass_count||'/'||source_position_count||' reconciled' from b
union all select 'PORTFOLIO_BATCH',case when exists(select 1 from b where status='PASS') then 'PASS' else 'FAIL' end,(select batch_id from b)
union all select 'CANDIDATE_DECISION',case when exists(select 1 from fwios.rebalancing_recommendation_actions a join fwios.decision_snapshots d on d.decision_snapshot_id=a.decision_snapshot_id where a.recommendation_run_id=p_recommendation_run_id and a.action_type='ADD' and d.input_integrity_gate='PASS' and d.promotion_gate='PASS') then 'PASS' else 'FAIL' end,'ADD decision snapshot lineage'
union all select 'OPPORTUNITY_RANKING',case when exists(select 1 from r join fwios.opportunity_ranked_candidates c on c.ranking_run_id=r.ranking_run_id join fwios.rebalancing_recommendation_actions a on a.recommendation_run_id=r.recommendation_run_id and a.action_type='ADD' and a.asset_symbol=c.ticker and a.decision_snapshot_id=c.decision_snapshot_id where c.opportunity_bucket='IMMEDIATE_BUY_CANDIDATE' and c.eligibility_gate='PASS') then 'PASS' else 'FAIL' end,'Immediate candidate lineage'
union all select 'SOURCE_HOLDING_VALUATION',case when not exists(select 1 from fwios.rebalancing_recommendation_actions a where a.recommendation_run_id=p_recommendation_run_id and a.action_type='TRIM') or exists(select 1 from fwios.rebalancing_recommendation_actions a join fwios.valuation_runs v on v.run_id=a.valuation_run_id join fwios.valuation_model_versions mv on mv.version_id=v.model_version_id where a.recommendation_run_id=p_recommendation_run_id and a.action_type='TRIM' and mv.status='PRODUCTION' and mv.regression_status='PASS' and v.production_eligible=true) then 'PASS' else 'FAIL' end,'TRIM holding valuation lineage'
union all select 'RECOMMENDATION_SNAPSHOT',case when fwios.recommendation_snapshot_fingerprint_v1(p_recommendation_run_id) is not null then 'PASS' else 'FAIL' end,'Immutable recommendation fingerprint'
union all select 'APPROVAL_PACKET',case when exists(select 1 from p) and fwios.human_approval_packet_integrity_gate_v1(p_approval_packet_id)='PASS' then 'PASS' else 'FAIL' end,'Immutable approval packet fingerprint/traceability'
union all select 'EXECUTION_ISOLATION',case when exists(select 1 from p where auto_trade=false) and not exists(select 1 from fwios.human_approval_events e where e.approval_packet_id=p_approval_packet_id and (e.broker_order_created or e.portfolio_mutation_applied)) then 'PASS' else 'FAIL' end,'Approval layer cannot claim broker order or portfolio mutation';
$$;

revoke execute on function fwios.materialize_rebalancing_recommendation_snapshot_v1(text,numeric,text,text) from anon,authenticated;
revoke execute on function fwios.materialize_human_approval_packet_v1(text,text,text,text) from anon,authenticated;
revoke execute on function fwios.record_human_approval_event_v1(text,text,text,text,text,text) from anon,authenticated;
revoke execute on function fwios.recommendation_snapshot_fingerprint_v1(text) from anon,authenticated;
revoke execute on function fwios.recommendation_traceability_gate_v1(text) from anon,authenticated;
revoke execute on function fwios.human_approval_packet_integrity_gate_v1(text) from anon,authenticated;
revoke execute on function fwios.human_approval_revalidation_gate_v1(text) from anon,authenticated;
revoke execute on function fwios.human_approval_transition_v1(text,text,text,text) from anon,authenticated;
revoke execute on function fwios.m3_5_traceability_layers_v1(text,text) from anon,authenticated;
revoke all on fwios.v_human_approval_current from anon,authenticated;
