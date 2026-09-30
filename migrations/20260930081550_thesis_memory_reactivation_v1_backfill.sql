
-- Normalize existing COMPLETE thesis baselines into explicit conditions + KPI bindings.

with condition_rows as (
  select
    tr.ticker,tr.instrument_id,
    coalesce(tr.metadata->>'baseline_version','LEGACY_BASELINE') baseline_version,
    'MUST_REMAIN_TRUE'::text condition_type,
    x.ordinality::int ordinal,
    x.item source_payload,
    coalesce(x.item->>'statement',x.item::text) statement,
    null::text severity,
    null::text horizon,
    null::date target_date,
    tr.source_reference
  from fwios.thesis_registry tr
  cross join lateral jsonb_array_elements(tr.must_remain_true) with ordinality x(item,ordinality)
  where tr.baseline_status='COMPLETE'

  union all

  select
    tr.ticker,tr.instrument_id,
    coalesce(tr.metadata->>'baseline_version','LEGACY_BASELINE'),
    'CATALYST',
    x.ordinality::int,
    x.item,
    coalesce(x.item->>'catalyst',x.item::text),
    null::text,
    x.item->>'horizon',
    case when coalesce(x.item->>'date','') ~ '^\d{4}-\d{2}-\d{2}$' then (x.item->>'date')::date else null end,
    tr.source_reference
  from fwios.thesis_registry tr
  cross join lateral jsonb_array_elements(tr.catalysts) with ordinality x(item,ordinality)
  where tr.baseline_status='COMPLETE'

  union all

  select
    tr.ticker,tr.instrument_id,
    coalesce(tr.metadata->>'baseline_version','LEGACY_BASELINE'),
    'INVALIDATION',
    x.ordinality::int,
    x.item,
    coalesce(x.item->>'criterion',x.item::text),
    x.item->>'severity',
    null::text,
    null::date,
    tr.source_reference
  from fwios.thesis_registry tr
  cross join lateral jsonb_array_elements(tr.invalidation_criteria) with ordinality x(item,ordinality)
  where tr.baseline_status='COMPLETE'
)
insert into fwios.thesis_conditions(
  condition_id,ticker,instrument_id,baseline_version,condition_type,ordinal,
  statement,severity,horizon,target_date,source_payload,source_payload_hash,source_reference
)
select
  'THC-'||ticker||'-'||
    case condition_type when 'MUST_REMAIN_TRUE' then 'MRT' when 'CATALYST' then 'CAT' else 'INV' end||
    '-'||lpad(ordinal::text,2,'0')||'-'||substr(md5(source_payload::text),1,10),
  ticker,instrument_id,baseline_version,condition_type,ordinal,
  statement,severity,horizon,target_date,source_payload,md5(source_payload::text),source_reference
from condition_rows
on conflict(condition_id) do nothing;

with kpi_rows as (
  select
    tr.ticker,tr.instrument_id,
    coalesce(tr.metadata->>'baseline_version','LEGACY_BASELINE') baseline_version,
    x.ordinality::int ordinal,
    x.item source_payload,
    coalesce(x.item->>'metric','UNNAMED KPI') kpi_label,
    x.item->>'baseline' baseline_text,
    x.item->>'frequency' frequency
  from fwios.thesis_registry tr
  cross join lateral jsonb_array_elements(tr.monitoring_kpis) with ordinality x(item,ordinality)
  where tr.baseline_status='COMPLETE'
)
insert into fwios.thesis_kpi_bindings(
  binding_id,ticker,instrument_id,baseline_version,ordinal,kpi_label,baseline_text,frequency,
  mapping_status,source_payload,source_payload_hash
)
select
  'THK-'||ticker||'-'||lpad(ordinal::text,2,'0')||'-'||substr(md5(source_payload::text),1,10),
  ticker,instrument_id,baseline_version,ordinal,kpi_label,baseline_text,frequency,
  'UNMAPPED',source_payload,md5(source_payload::text)
from kpi_rows
on conflict(binding_id) do nothing;

-- Conservative metric mappings: only map semantics already represented by canonical metric definitions.
update fwios.thesis_kpi_bindings k
set metric_code='REVENUE_GROWTH_YOY',
    mapping_status='METRIC_ONLY',
    mapping_note='Canonical metric definition exists; no exact Q3 FY26 ADBE baseline observation is currently present.'
where ticker='ADBE' and kpi_label='Total Adobe revenue growth';

update fwios.thesis_kpi_bindings k
set metric_code='RECURRING_REVENUE_GROWTH_YOY',
    baseline_observation_id=(
      select o.observation_id from fwios.metric_observations o
      where o.instrument_id=k.instrument_id
        and o.metric_code='RECURRING_REVENUE_GROWTH_YOY'
        and o.source_key='ADBE:recurring_growth_yoy'
      order by o.created_at desc limit 1
    ),
    mapping_status='PARTIAL',
    mapping_note='Binding covers the YoY ARR growth portion of the KPI; total ending ARR level remains text-only.'
where ticker='ADBE' and kpi_label='Total Adobe ending ARR';

update fwios.thesis_kpi_bindings
set metric_code='OPERATING_CASH_FLOW_LTM',
    mapping_status='METRIC_ONLY',
    mapping_note='Canonical operating-cash-flow definition exists; exact Q3 FY26 quarterly baseline observation is not present.'
where ticker='ADBE' and kpi_label='Cash flow from operations';

update fwios.thesis_kpi_bindings
set metric_code='RPO',
    mapping_status='METRIC_ONLY',
    mapping_note='Canonical RPO definition exists; cRPO share remains text-only and exact baseline observation is not present.'
where ticker='ADBE' and kpi_label='RPO / cRPO';

update fwios.thesis_kpi_bindings k
set metric_code='REVENUE_GROWTH_YOY',
    baseline_observation_id=(
      select o.observation_id from fwios.metric_observations o
      where o.instrument_id=k.instrument_id and o.metric_code='REVENUE_GROWTH_YOY'
        and o.source_key='PINS:revenue_growth_yoy'
      order by o.created_at desc limit 1
    ),
    mapping_status='RESOLVED',
    mapping_note='Q2 2026 +18% YoY baseline is represented by a canonical metric observation.'
where ticker='PINS' and kpi_label='Revenue growth';

update fwios.thesis_kpi_bindings k
set metric_code='GLOBAL_MAU_GROWTH_YOY',
    baseline_observation_id=(
      select o.observation_id from fwios.metric_observations o
      where o.instrument_id=k.instrument_id and o.metric_code='GLOBAL_MAU_GROWTH_YOY'
        and o.source_key='PINS:engagement_growth'
      order by o.created_at desc limit 1
    ),
    mapping_status='PARTIAL',
    mapping_note='Canonical observation covers +11% YoY growth; absolute 640M MAU baseline remains text-only.'
where ticker='PINS' and kpi_label='Global MAUs';

update fwios.thesis_kpi_bindings k
set metric_code='GLOBAL_ARPU',
    baseline_observation_id=(
      select o.observation_id from fwios.metric_observations o
      where o.instrument_id=k.instrument_id and o.metric_code='GLOBAL_ARPU'
        and o.source_key='PINS:monitoring_kpis:Global ARPU'
      order by o.created_at desc limit 1
    ),
    mapping_status='RESOLVED',
    mapping_note='Q2 2026 $1.86 Global ARPU baseline is canonical.'
where ticker='PINS' and kpi_label='Global ARPU';

update fwios.thesis_kpi_bindings k
set metric_code='ADJUSTED_EBITDA_MARGIN',
    baseline_observation_id=(
      select o.observation_id from fwios.metric_observations o
      where o.instrument_id=k.instrument_id and o.metric_code='ADJUSTED_EBITDA_MARGIN'
        and o.source_key='PINS:adjusted_ebitda_margin'
      order by o.created_at desc limit 1
    ),
    mapping_status='RESOLVED',
    mapping_note='Q2 2026 26% adjusted EBITDA margin baseline is canonical.'
where ticker='PINS' and kpi_label='Adjusted EBITDA margin';

update fwios.thesis_kpi_bindings k
set metric_code='FREE_CASH_FLOW',
    baseline_observation_id=(
      select o.observation_id from fwios.metric_observations o
      where o.instrument_id=k.instrument_id and o.metric_code='FREE_CASH_FLOW'
        and o.source_key='PINS:fcf_q2'
      order by o.created_at desc limit 1
    ),
    mapping_status='RESOLVED',
    mapping_note='Q2 2026 free cash flow baseline is canonical.'
where ticker='PINS' and kpi_label='Free cash flow';

update fwios.thesis_kpi_bindings k
set metric_code='SBC_TO_REVENUE',
    baseline_observation_id=(
      select o.observation_id from fwios.metric_observations o
      where o.instrument_id=k.instrument_id and o.metric_code='SBC_TO_REVENUE'
        and o.source_key='PINS:sbc_to_revenue'
      order by o.created_at desc limit 1
    ),
    mapping_status='PARTIAL',
    mapping_note='Canonical ratio is LTM; thesis baseline text cites Q2 SBC as a percent of quarterly revenue.'
where ticker='PINS' and kpi_label='Stock-based compensation / revenue';

update fwios.thesis_kpi_bindings k
set metric_code='SHARE_REPURCHASES',
    baseline_observation_id=(
      select o.observation_id from fwios.metric_observations o
      where o.instrument_id=k.instrument_id and o.metric_code='SHARE_REPURCHASES'
        and o.source_key='QH-PINS-H1-26-BUYBACK-20260906'
      order by o.created_at desc limit 1
    ),
    mapping_status='RESOLVED',
    mapping_note='H1 2026 repurchase value is represented by a canonical metric observation.'
where ticker='PINS' and kpi_label='Share repurchases';

-- Explicit condition -> metric links for machine-actionable threshold clauses already supported by canonical metrics.
insert into fwios.thesis_condition_metric_links(
  link_id,condition_id,metric_code,baseline_observation_id,comparison_operator,
  threshold_numeric,threshold_unit,comparison_basis,consecutive_periods,clause_group,
  group_logic,mapping_status,notes
)
select
  'TCL-'||c.ticker||'-INV01-REVGR',
  c.condition_id,'REVENUE_GROWTH_YOY',
  (select o.observation_id from fwios.metric_observations o
    where o.instrument_id=c.instrument_id and o.metric_code='REVENUE_GROWTH_YOY'
      and o.source_key='PINS:revenue_growth_yoy'
    order by o.created_at desc limit 1),
  'LT',0.10,'ratio','YOY_GROWTH',2,1,'ALL','RESOLVED',
  'Revenue-growth clause of PINS invalidation #1.'
from fwios.thesis_conditions c
where c.ticker='PINS' and c.condition_type='INVALIDATION' and c.ordinal=1
on conflict(link_id) do nothing;

insert into fwios.thesis_condition_metric_links(
  link_id,condition_id,metric_code,baseline_observation_id,comparison_operator,
  threshold_numeric,threshold_unit,comparison_basis,consecutive_periods,clause_group,
  group_logic,mapping_status,notes
)
select
  'TCL-'||c.ticker||'-INV01-MAUGR',
  c.condition_id,'GLOBAL_MAU_GROWTH_YOY',
  (select o.observation_id from fwios.metric_observations o
    where o.instrument_id=c.instrument_id and o.metric_code='GLOBAL_MAU_GROWTH_YOY'
      and o.source_key='PINS:engagement_growth'
    order by o.created_at desc limit 1),
  'LT',0.05,'ratio','YOY_GROWTH',2,1,'ALL','RESOLVED',
  'MAU-growth clause of PINS invalidation #1.'
from fwios.thesis_conditions c
where c.ticker='PINS' and c.condition_type='INVALIDATION' and c.ordinal=1
on conflict(link_id) do nothing;

insert into fwios.thesis_condition_metric_links(
  link_id,condition_id,metric_code,baseline_observation_id,comparison_operator,
  threshold_numeric,threshold_unit,comparison_basis,consecutive_periods,clause_group,
  group_logic,mapping_status,notes
)
select
  'TCL-'||c.ticker||'-INV02-ARPU',
  c.condition_id,'GLOBAL_ARPU',
  (select o.observation_id from fwios.metric_observations o
    where o.instrument_id=c.instrument_id and o.metric_code='GLOBAL_ARPU'
      and o.source_key='PINS:monitoring_kpis:Global ARPU'
    order by o.created_at desc limit 1),
  'DIRECTION_DOWN',null,'USD/user','YEAR_OVER_YEAR_LEVEL',2,1,'ALL','RESOLVED',
  'Two consecutive YoY declines in Global ARPU.'
from fwios.thesis_conditions c
where c.ticker='PINS' and c.condition_type='INVALIDATION' and c.ordinal=2
on conflict(link_id) do nothing;

insert into fwios.thesis_condition_metric_links(
  link_id,condition_id,metric_code,baseline_observation_id,comparison_operator,
  threshold_numeric,threshold_unit,comparison_basis,consecutive_periods,clause_group,
  group_logic,mapping_status,notes
)
select
  'TCL-'||c.ticker||'-INV03-EBITDA',
  c.condition_id,'ADJUSTED_EBITDA_MARGIN',
  (select o.observation_id from fwios.metric_observations o
    where o.instrument_id=c.instrument_id and o.metric_code='ADJUSTED_EBITDA_MARGIN'
      and o.source_key='PINS:adjusted_ebitda_margin'
    order by o.created_at desc limit 1),
  'LT',0.20,'ratio','ABSOLUTE_VALUE',2,1,'ALL','RESOLVED',
  'Adjusted EBITDA margin clause of PINS invalidation #3.'
from fwios.thesis_conditions c
where c.ticker='PINS' and c.condition_type='INVALIDATION' and c.ordinal=3
on conflict(link_id) do nothing;

insert into fwios.thesis_condition_metric_links(
  link_id,condition_id,metric_code,baseline_observation_id,comparison_operator,
  threshold_numeric,threshold_unit,comparison_basis,consecutive_periods,clause_group,
  group_logic,mapping_status,notes
)
select
  'TCL-'||c.ticker||'-INV03-REVGR',
  c.condition_id,'REVENUE_GROWTH_YOY',
  (select o.observation_id from fwios.metric_observations o
    where o.instrument_id=c.instrument_id and o.metric_code='REVENUE_GROWTH_YOY'
      and o.source_key='PINS:revenue_growth_yoy'
    order by o.created_at desc limit 1),
  'LT',0.12,'ratio','YOY_GROWTH',2,1,'ALL','RESOLVED',
  'Revenue-growth clause of PINS invalidation #3.'
from fwios.thesis_conditions c
where c.ticker='PINS' and c.condition_type='INVALIDATION' and c.ordinal=3
on conflict(link_id) do nothing;

insert into fwios.thesis_condition_metric_links(
  link_id,condition_id,metric_code,baseline_observation_id,comparison_operator,
  threshold_numeric,threshold_unit,comparison_basis,consecutive_periods,clause_group,
  group_logic,mapping_status,notes
)
select
  'TCL-'||c.ticker||'-INV04-SBC',
  c.condition_id,'SBC_TO_REVENUE',
  (select o.observation_id from fwios.metric_observations o
    where o.instrument_id=c.instrument_id and o.metric_code='SBC_TO_REVENUE'
      and o.source_key='PINS:sbc_to_revenue'
    order by o.created_at desc limit 1),
  'GT',0.30,'ratio','ABSOLUTE_VALUE',2,1,'ALL','PARTIAL',
  'SBC threshold is explicit; current linked canonical baseline is LTM rather than quarterly.'
from fwios.thesis_conditions c
where c.ticker='PINS' and c.condition_type='INVALIDATION' and c.ordinal=4
on conflict(link_id) do nothing;

insert into fwios.thesis_condition_metric_links(
  link_id,condition_id,metric_code,baseline_observation_id,comparison_operator,
  threshold_numeric,threshold_unit,comparison_basis,consecutive_periods,clause_group,
  group_logic,mapping_status,notes
)
select
  'TCL-'||c.ticker||'-INV04-SHARES',
  c.condition_id,'SHARES_OUTSTANDING',
  (select o.observation_id from fwios.metric_observations o
    where o.instrument_id=c.instrument_id and o.metric_code='SHARES_OUTSTANDING'
      and o.source_key='QH-PINS-Q2-26-SHARES-20260906'
    order by o.created_at desc limit 1),
  'GTE',null,'M shares','PRIOR_YEAR_LEVEL',2,1,'ALL','RESOLVED',
  'Does-not-decline diluted-share-count clause; comparison is against prior-year level.'
from fwios.thesis_conditions c
where c.ticker='PINS' and c.condition_type='INVALIDATION' and c.ordinal=4
on conflict(link_id) do nothing;

insert into fwios.thesis_condition_metric_links(
  link_id,condition_id,metric_code,baseline_observation_id,comparison_operator,
  threshold_numeric,threshold_unit,comparison_basis,consecutive_periods,clause_group,
  group_logic,mapping_status,notes
)
select
  'TCL-'||c.ticker||'-INV01-ARRGR',
  c.condition_id,'RECURRING_REVENUE_GROWTH_YOY',
  (select o.observation_id from fwios.metric_observations o
    where o.instrument_id=c.instrument_id and o.metric_code='RECURRING_REVENUE_GROWTH_YOY'
      and o.source_key='ADBE:recurring_growth_yoy'
    order by o.created_at desc limit 1),
  'LT',0.07,'ratio','YOY_GROWTH',2,1,'ALL','PARTIAL',
  'Adobe invalidation #1 ARR-growth clause is canonical; AI-first ARR deceleration clause remains text-only.'
from fwios.thesis_conditions c
where c.ticker='ADBE' and c.condition_type='INVALIDATION' and c.ordinal=1
on conflict(link_id) do nothing;

-- Current explicit decision-memory anchors; these do not change lifecycle state or downstream promotion.
insert into fwios.thesis_decision_memory(
  decision_memory_id,ticker,instrument_id,decision_class,lifecycle_state,decision_snapshot_id,
  decision_summary,rationale,reactivation_required,source_reference,metadata
)
select
  'MEM-ADBE-CURRENT-20260930','ADBE',tr.instrument_id,'DEFER','RESEARCH_CANDIDATE',
  'DEC-ADBE-REFRESH-20260911',
  rc.final_decision,
  coalesce(rc.research_reliability_note,'Current production research decision retained as normalized memory.'),
  false,'research_candidates:ADBE',
  jsonb_build_object('promotion_gate',rc.promotion_gate,'mispricing_gate',rc.mispricing_gate,'migration','THESIS_MEMORY_V1')
from fwios.thesis_registry tr
join fwios.research_candidates rc on rc.ticker=tr.ticker
where tr.ticker='ADBE'
on conflict(decision_memory_id) do nothing;

insert into fwios.thesis_decision_memory(
  decision_memory_id,ticker,instrument_id,decision_class,lifecycle_state,decision_snapshot_id,
  decision_summary,rationale,reactivation_required,source_reference,metadata
)
select
  'MEM-PINS-CURRENT-20260930','PINS',tr.instrument_id,'WATCH','RESEARCH_CANDIDATE',
  'DEC-PINS-REFRESH-20260911',
  rc.final_decision,
  coalesce(rc.research_reliability_note,'Current production research decision retained as normalized memory.'),
  false,'research_candidates:PINS',
  jsonb_build_object('promotion_gate',rc.promotion_gate,'mispricing_gate',rc.mispricing_gate,'migration','THESIS_MEMORY_V1')
from fwios.thesis_registry tr
join fwios.research_candidates rc on rc.ticker=tr.ticker
where tr.ticker='PINS'
on conflict(decision_memory_id) do nothing;
