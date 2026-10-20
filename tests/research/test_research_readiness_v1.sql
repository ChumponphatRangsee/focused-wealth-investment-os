-- PR4 Research Readiness & Fail-Closed Gates v1 acceptance tests.
-- Read-only against production state except for the temporary results table.

begin;

create temporary table pr4_research_readiness_results(
  test_id text primary key,
  passed boolean not null
) on commit drop;

insert into pr4_research_readiness_results values
('PR4_01_POLICY_ACTIVE',
  exists(
    select 1 from fwios.policy_versions
    where policy_version_id='POL-RESEARCH-READINESS-V1'
      and lifecycle_status='ACTIVE'
      and deterministic_scoring=true
      and config->>'auto_trade'='false'
      and config->>'production_read_cutover'='false'
      and config->>'scanner_score_requires_investment_review_ready'='true'
  )),
('PR4_02_VIEW_SECURITY_INVOKER',
  exists(
    select 1
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='fwios'
      and c.relname='v_research_readiness_current_v1'
      and c.relkind='v'
      and coalesce(c.reloptions,'{}'::text[]) @> array['security_invoker=true']
  )),
('PR4_03_SERVICE_ROLE_ONLY',
  has_table_privilege('service_role','fwios.v_research_readiness_current_v1','SELECT')
  and not has_table_privilege('anon','fwios.v_research_readiness_current_v1','SELECT')
  and not has_table_privilege('authenticated','fwios.v_research_readiness_current_v1','SELECT')),
('PR4_04_ACTIVE_STOCK_UNIVERSE_PARITY',
  (select count(*) from fwios.v_research_readiness_current_v1)
  =
  (select count(*) from fwios.v_instrument_identity_current
   where asset_class='Stock' and lifecycle_status='ACTIVE')),
('PR4_05_ONE_ROW_PER_INSTRUMENT',
  not exists(
    select instrument_id
    from fwios.v_research_readiness_current_v1
    group by instrument_id
    having count(*)<>1
  )),
('PR4_06_STAGE_HIERARCHY',
  not exists(
    select 1 from fwios.v_research_readiness_current_v1
    where (investment_review_ready and not quality_hardened)
       or (quality_hardened and not valuation_ready)
       or (valuation_ready and not research_ready)
       or (research_ready and not discovery_ready)
  )),
('PR4_07_RESEARCH_GATE_FAIL_CLOSED',
  not exists(
    select 1 from fwios.v_research_readiness_current_v1 r
    join fwios.policy_versions p
      on p.policy_version_id='POL-RESEARCH-READINESS-V1'
    where r.research_ready
      and (
        r.evidence_count<=0
        or r.primary_verified_evidence_count<=0
        or r.conflicting_evidence_count<>0
        or r.stale_evidence_count<>0
        or r.research_as_of is null
        or r.research_as_of < current_date - (p.config->>'research_max_age_days')::integer
        or (r.evidence_gate is not null and upper(r.evidence_gate)<>'PASS')
      )
  )),
('PR4_08_VALUATION_GATE_FAIL_CLOSED',
  not exists(
    select 1
    from fwios.v_research_readiness_current_v1 r
    left join fwios.valuation_runs v on v.run_id=r.valuation_run_id
    join fwios.policy_versions p on p.policy_version_id='POL-RESEARCH-READINESS-V1'
    where r.valuation_ready
      and (
        v.run_id is null
        or upper(coalesce(v.valuation_readiness,'')) not in ('PASS','READY')
        or upper(coalesce(v.router_gate,''))<>'PASS'
        or upper(coalesce(v.valuation_gate,''))<>'PASS'
        or upper(coalesce(v.schema_gate,''))<>'PASS'
        or not coalesce(v.production_eligible,false)
        or v.created_at < now() - make_interval(days => (p.config->>'valuation_max_age_days')::integer)
      )
  )),
('PR4_09_HARDENING_MUST_PASS',
  not exists(
    select 1 from fwios.v_research_readiness_current_v1
    where quality_hardened and upper(coalesce(hardening_gate_raw,''))<>'PASS'
  )),
('PR4_10_HARDENING_LINEAGE_CURRENT',
  not exists(
    select 1 from fwios.v_research_readiness_current_v1
    where quality_hardened
      and hardening_valuation_run_id is distinct from valuation_run_id
  )),
('PR4_11_PRICE_GATE_FAIL_CLOSED',
  not exists(
    select 1
    from fwios.v_research_readiness_current_v1 r
    join fwios.policy_versions p on p.policy_version_id='POL-RESEARCH-READINESS-V1'
    where r.price_ready
      and (
        r.latest_price is null or r.latest_price<=0
        or not ((p.config->'accepted_price_verification_statuses') ? upper(coalesce(r.price_verification_status,'')))
        or not ((p.config->'accepted_price_provenance_statuses') ? upper(coalesce(r.price_provenance_status,'')))
        or r.price_as_of is null
        or r.price_as_of < current_date - (p.config->>'price_max_age_days')::integer
      )
  )),
('PR4_12_INVESTMENT_REVIEW_EXACT_GATE',
  not exists(
    select 1 from fwios.v_research_readiness_current_v1
    where investment_review_ready is distinct from (quality_hardened and price_ready)
  )),
('PR4_13_BLOCKED_HAS_REASON',
  not exists(
    select 1 from fwios.v_research_readiness_current_v1
    where not investment_review_ready
      and (blocking_reason is null or coalesce(array_length(blocking_reasons,1),0)=0)
  )),
('PR4_14_SCORE_ELIGIBILITY_FAIL_CLOSED',
  not exists(
    select 1 from fwios.v_research_readiness_current_v1
    where scanner_score_eligible is distinct from investment_review_ready
  )),
('PR4_15_BLOCKER_TAXONOMY_BOUNDED',
  not exists(
    select 1
    from fwios.v_research_readiness_current_v1 r,
         unnest(r.blocking_reasons) b(reason)
    where b.reason not in (
      'READINESS_POLICY_NOT_ACTIVE',
      'CONFLICTING_EVIDENCE',
      'MISSING_PRIMARY_EVIDENCE',
      'STALE_RESEARCH',
      'RESEARCH_NOT_READY',
      'VALUATION_BLOCKED',
      'QUALITY_HARDENING_FAIL',
      'PRICE_NOT_VERIFIED'
    )
  )),
('PR4_16_NO_PORTFOLIO_OR_EXECUTION_DEPENDENCY',
  (
    select lower(pg_get_viewdef(c.oid,true))
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='fwios' and c.relname='v_research_readiness_current_v1'
  ) !~ '(portfolio_assets|portfolio_transactions|portfolio_positions|holdings|approval|execution|cash_balance|cost_basis)');

-- Review hardening regressions.

do $test$
declare
  p_empty jsonb;
  p_old jsonb;
  p_fresh jsonb;
  a jsonb;
begin
  p_empty := jsonb_build_object(
    'schema_version','chatgpt_research_payload_v1','mode','APPLY','command','PR4 hardening empty metrics',
    'ticker','ALL','research_as_of',now(),
    'evidence',jsonb_build_array(jsonb_build_object(
      'evidence_ref','pr4-empty-ev','fact_class','REPORTED_FINANCIALS','claim','Old primary evidence only',
      'source_name','Fixture','source_url','https://example.com/pr4-empty','source_type','WEB_PRIMARY','source_tier','A',
      'retrieved_at',now(),'reported_at','2024-01-01T00:00:00Z','reporting_period','FY2023',
      'verification_status','VERIFIED','conflict_group',null
    )),
    'metrics','[]'::jsonb,'guidance','[]'::jsonb,'risks','[]'::jsonb,'research_summary','{}'::jsonb
  );
  a := fwios.apply_research_ingest_v1(p_empty);
  insert into pr4_research_readiness_results values (
    'PR4_17_CONTROLLED_EMPTY_METRICS_BLOCKED',
    a->>'status'='APPLIED'
    and not (select research_ready from fwios.v_research_readiness_current_v1 where ticker='ALL')
    and (select controlled_receipt_metric_count=0 from fwios.v_research_readiness_current_v1 where ticker='ALL')
  );

  p_old := jsonb_build_object(
    'schema_version','chatgpt_research_payload_v1','mode','APPLY','command','PR4 hardening stale metric',
    'ticker','APO','research_as_of',now(),
    'evidence',jsonb_build_array(jsonb_build_object(
      'evidence_ref','pr4-old-ev','fact_class','REPORTED_FINANCIALS','claim','Old reported revenue',
      'source_name','Fixture','source_url','https://example.com/pr4-old','source_type','WEB_PRIMARY','source_tier','A',
      'retrieved_at',now(),'reported_at','2024-01-01T00:00:00Z','reporting_period','FY2023',
      'verification_status','VERIFIED','conflict_group',null
    )),
    'metrics',jsonb_build_array(jsonb_build_object(
      'metric_code','REVENUE','value_kind','NUMERIC','value_numeric',1.0,'canonical_unit','USD B','source_unit','USD B',
      'currency','USD','period_type','YEAR','fiscal_year',2023,'fiscal_quarter',null,
      'period_start','2023-01-01','period_end','2023-12-31','as_of_date','2023-12-31',
      'period_label','FY2023','reported_at','2024-01-01T00:00:00Z',
      'evidence_refs',jsonb_build_array('pr4-old-ev'),'verification_status','VERIFIED'
    )),
    'guidance','[]'::jsonb,'risks','[]'::jsonb,'research_summary','{}'::jsonb
  );
  a := fwios.apply_research_ingest_v1(p_old);
  insert into pr4_research_readiness_results values (
    'PR4_18_OLD_CONTROLLED_METRIC_STALE',
    a->>'status'='APPLIED'
    and not (select research_ready from fwios.v_research_readiness_current_v1 where ticker='APO')
    and (select blocking_reasons @> array['STALE_RESEARCH']::text[]
         from fwios.v_research_readiness_current_v1 where ticker='APO')
    and (select controlled_receipt_fresh_metric_count=0
         from fwios.v_research_readiness_current_v1 where ticker='APO')
  );

  p_fresh := jsonb_build_object(
    'schema_version','chatgpt_research_payload_v1','mode','APPLY','command','PR4 hardening fresh metric',
    'ticker','AXP','research_as_of',now(),
    'evidence',jsonb_build_array(jsonb_build_object(
      'evidence_ref','pr4-fresh-ev','fact_class','REPORTED_FINANCIALS','claim','Fresh reported revenue',
      'source_name','Fixture','source_url','https://example.com/pr4-fresh','source_type','WEB_PRIMARY','source_tier','A',
      'retrieved_at',now(),'reported_at',now()-interval '30 days','reporting_period','Q3 FY2026',
      'verification_status','VERIFIED','conflict_group',null
    )),
    'metrics',jsonb_build_array(jsonb_build_object(
      'metric_code','REVENUE','value_kind','NUMERIC','value_numeric',1.0,'canonical_unit','USD B','source_unit','USD B',
      'currency','USD','period_type','QUARTER','fiscal_year',2026,'fiscal_quarter',3,
      'period_start',(current_date-interval '120 days')::date,'period_end',(current_date-interval '45 days')::date,
      'as_of_date',(current_date-interval '45 days')::date,'period_label','Q3 FY2026',
      'reported_at',now()-interval '30 days','evidence_refs',jsonb_build_array('pr4-fresh-ev'),
      'verification_status','VERIFIED'
    )),
    'guidance','[]'::jsonb,'risks','[]'::jsonb,'research_summary','{}'::jsonb
  );
  a := fwios.apply_research_ingest_v1(p_fresh);
  insert into pr4_research_readiness_results values (
    'PR4_19_FRESH_CONTROLLED_METRIC_READY',
    a->>'status'='APPLIED'
    and (select research_ready from fwios.v_research_readiness_current_v1 where ticker='AXP')
    and (select research_route='CONTROLLED_GATEWAY' from fwios.v_research_readiness_current_v1 where ticker='AXP')
    and (select controlled_receipt_metric_count>0 and controlled_receipt_fresh_metric_count>0
         from fwios.v_research_readiness_current_v1 where ticker='AXP')
  );
end
$test$;

create temporary table pr4_prod_val_anchor as
select valuation_run_id as run_id
from fwios.v_research_readiness_current_v1
where ticker='ADBE';

with src as (
  select *
  from fwios.valuation_runs
  where ticker='ADBE' and production_eligible=true
  order by created_at desc,run_id desc
  limit 1
)
insert into fwios.valuation_runs
select (jsonb_populate_record(
  null::fwios.valuation_runs,
  to_jsonb(src) || jsonb_build_object(
    'run_id','PR4-HARDENING-NONPROD-ADBE',
    'production_eligible',false,
    'created_at',(now()+interval '1 day')::text
  )
)).*
from src;

insert into pr4_research_readiness_results values (
  'PR4_20_LATEST_PRODUCTION_VALUATION_ONLY',
  (select valuation_run_id from fwios.v_research_readiness_current_v1 where ticker='ADBE')
  =
  (select run_id from pr4_prod_val_anchor)
);

insert into pr4_research_readiness_results values (
  'PR4_21_LIFECYCLE_DEFERRED_EXPLICIT',
  exists(
    select 1 from fwios.policy_versions
    where policy_version_id='POL-RESEARCH-READINESS-V1'
      and config->>'lifecycle_gate_enforced'='false'
      and config->>'lifecycle_gate_reason'='POL-RESEARCH-LIFECYCLE-V1_NO_PRODUCTION_READ_CUTOVER'
  )
  and not exists(
    select 1 from fwios.v_research_readiness_current_v1
    where lifecycle_gate_enforced
       or lifecycle_gate_status<>'DEFERRED_NO_PRODUCTION_READ_CUTOVER'
  )
);

select test_id, case when passed then 'PASS' else 'FAIL' end as status
from pr4_research_readiness_results
order by test_id;

rollback;
