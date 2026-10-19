-- PR2 Controlled Research Ingestion v1 acceptance tests
-- The test writes only inside this transaction and rolls everything back.

begin;

create temporary table pr2_controlled_research_ingest_results(
  test_id text primary key,
  passed boolean not null
) on commit drop;

do $test$
declare
  p jsonb;
  p_bad jsonb;
  p_conflict jsonb;
  preview jsonb;
  bad_preview jsonb;
  apply_preview_mode jsonb;
  apply_one jsonb;
  apply_two jsonb;
  conflict_preview jsonb;
  evidence_id text;
  observation_key text;
  receipts_before bigint;
  evidence_before bigint;
  observations_before bigint;
  candidate_max_before timestamptz;
begin
  p := jsonb_build_object(
    'schema_version','chatgpt_research_payload_v1',
    'mode','APPLY',
    'command','Research ADBE and update FWIOS',
    'ticker','ADBE',
    'research_as_of',now(),
    'evidence',jsonb_build_array(
      jsonb_build_object(
        'evidence_ref','ev-local-001',
        'fact_class','REPORTED_FINANCIALS',
        'claim','Q3 FY2026 revenue was USD 6.760B.',
        'source_name','Adobe Investor Relations',
        'source_url','https://www.adobe.com/cc-shared/assets/investor-relations/pdfs/01906202/au56y4ter.pdf',
        'source_type','WEB_PRIMARY',
        'source_tier','A',
        'retrieved_at',now(),
        'reported_at','2026-09-10T00:00:00Z',
        'reporting_period','Q3 FY2026',
        'verification_status','VERIFIED',
        'conflict_group',null,
        'notes','PR2 transactional acceptance fixture'
      )
    ),
    'metrics',jsonb_build_array(
      jsonb_build_object(
        'metric_code','REVENUE',
        'value_kind','NUMERIC',
        'value_numeric',6.760,
        'value_text',null,
        'value_boolean',null,
        'canonical_unit','USD B',
        'source_unit','USD B',
        'currency','USD',
        'period_type','QUARTER',
        'fiscal_year',2026,
        'fiscal_quarter',3,
        'period_start',null,
        'period_end','2026-08-28',
        'as_of_date','2026-08-28',
        'period_label','Q3 FY2026',
        'reported_at','2026-09-10T00:00:00Z',
        'evidence_refs',jsonb_build_array('ev-local-001'),
        'verification_status','VERIFIED'
      )
    ),
    'guidance','[]'::jsonb,
    'risks',jsonb_build_array(
      jsonb_build_object('category','COMPETITION','statement','Acceptance fixture risk context','evidence_refs',jsonb_build_array('ev-local-001'),'status','OPEN')
    ),
    'research_summary',jsonb_build_object('key_findings',jsonb_build_array('Acceptance fixture'))
  );

  select count(*) into receipts_before from fwios.research_ingest_receipts_v1;
  select count(*) into evidence_before from fwios.evidence_records;
  select count(*) into observations_before from fwios.metric_observations;
  select max(updated_at) into candidate_max_before from fwios.research_candidates;

  preview := fwios.preview_research_ingest_v1(p);

  insert into pr2_controlled_research_ingest_results values
    ('PR2_01_POLICY_ACTIVE',
      exists(
        select 1 from fwios.policy_versions
        where policy_version_id='POL-CONTROLLED-RESEARCH-INGEST-V1'
          and lifecycle_status='ACTIVE'
          and config->>'auto_trade'='false'
          and config->>'research_candidates_mutated'='false'
      )),
    ('PR2_02_VALID_PREVIEW_PASS', preview->>'overall_status'='PASS'),
    ('PR2_03_PREVIEW_NO_MUTATION',
      (select count(*) from fwios.research_ingest_receipts_v1)=receipts_before
      and (select count(*) from fwios.evidence_records)=evidence_before
      and (select count(*) from fwios.metric_observations)=observations_before),
    ('PR2_04_IDENTITY_RESOLVED',
      preview->>'instrument_id'=fwios.resolve_instrument_id_v1('ADBE','Stock',null,null)::text),
    ('PR2_05_SECURITY_INVOKER',
      not (select p.prosecdef from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='fwios' and p.proname='preview_research_ingest_v1')
      and not (select p.prosecdef from pg_proc p join pg_namespace n on n.oid=p.pronamespace
               where n.nspname='fwios' and p.proname='apply_research_ingest_v1')),
    ('PR2_06_RPC_SERVICE_ROLE_ONLY',
      has_function_privilege('service_role','fwios.preview_research_ingest_v1(jsonb)','EXECUTE')
      and has_function_privilege('service_role','fwios.apply_research_ingest_v1(jsonb)','EXECUTE')
      and not has_function_privilege('anon','fwios.preview_research_ingest_v1(jsonb)','EXECUTE')
      and not has_function_privilege('authenticated','fwios.apply_research_ingest_v1(jsonb)','EXECUTE'));

  p_bad := jsonb_set(p,'{evidence,0,source_url}','"http://not-allowed.example"'::jsonb);
  bad_preview := fwios.preview_research_ingest_v1(p_bad);
  insert into pr2_controlled_research_ingest_results values
    ('PR2_07_BAD_URL_BLOCKED', bad_preview->>'overall_status'='BLOCKED');

  p_bad := jsonb_set(p,'{evidence,0,source_tier}','"B"'::jsonb);
  bad_preview := fwios.preview_research_ingest_v1(p_bad);
  insert into pr2_controlled_research_ingest_results values
    ('PR2_08_SECONDARY_CRITICAL_BLOCKED',
      bad_preview->>'overall_status'='BLOCKED'
      and bad_preview::text like '%PRIMARY_TIER_REQUIRED%');

  p_bad := jsonb_set(p,'{metrics,0,metric_code}','"NOT_A_REAL_METRIC"'::jsonb);
  bad_preview := fwios.preview_research_ingest_v1(p_bad);
  insert into pr2_controlled_research_ingest_results values
    ('PR2_09_UNKNOWN_METRIC_BLOCKED',
      bad_preview->>'overall_status'='BLOCKED'
      and bad_preview::text like '%UNKNOWN_OR_INACTIVE_METRIC_CODE%');

  p_bad := jsonb_set(p,'{mode}','"PREVIEW"'::jsonb);
  apply_preview_mode := fwios.apply_research_ingest_v1(p_bad);
  insert into pr2_controlled_research_ingest_results values
    ('PR2_10_APPLY_REQUIRES_EXPLICIT_MODE',
      apply_preview_mode->>'status'='APPLY_BLOCKED_EXPLICIT_MODE_REQUIRED'
      and apply_preview_mode->>'production_changes'='NONE');

  apply_one := fwios.apply_research_ingest_v1(p);
  evidence_id := apply_one->'preview'->>'unused'; -- deliberately null; derive below.
  select fwios.research_evidence_id_v1(
    fwios.resolve_instrument_id_v1('ADBE','Stock',null,null),
    (p->'evidence')->0
  ) into evidence_id;
  select fwios.research_observation_key_v1(
    fwios.resolve_instrument_id_v1('ADBE','Stock',null,null),
    (p->'metrics')->0,
    evidence_id
  ) into observation_key;

  insert into pr2_controlled_research_ingest_results values
    ('PR2_11_APPLY_WRITES_GATEWAY_ONLY',
      apply_one->>'status'='APPLIED'
      and (select count(*) from fwios.evidence_records where evidence_id=evidence_id)=1
      and (select count(*) from fwios.metric_observations where observation_key=observation_key)=1
      and (select count(*) from fwios.research_ingest_receipts_v1
           where payload_fingerprint=apply_one->>'payload_fingerprint')=1),
    ('PR2_12_RESEARCH_CANDIDATES_UNCHANGED',
      (select max(updated_at) from fwios.research_candidates) is not distinct from candidate_max_before);

  apply_two := fwios.apply_research_ingest_v1(p);
  insert into pr2_controlled_research_ingest_results values
    ('PR2_13_REPEAT_APPLY_IDEMPOTENT',
      apply_two->>'status'='NOOP_ALREADY_APPLIED'
      and (select count(*) from fwios.evidence_records where evidence_id=evidence_id)=1
      and (select count(*) from fwios.metric_observations where observation_key=observation_key)=1
      and (select count(*) from fwios.research_ingest_receipts_v1
           where payload_fingerprint=apply_one->>'payload_fingerprint')=1);

  p_conflict := jsonb_set(p,'{metrics,0,value_numeric}','6.761'::jsonb);
  conflict_preview := fwios.preview_research_ingest_v1(p_conflict);
  insert into pr2_controlled_research_ingest_results values
    ('PR2_14_CONFLICTING_VERIFIED_METRIC_BLOCKED',
      conflict_preview->>'overall_status'='BLOCKED'
      and conflict_preview::text like '%CONFLICTING_VERIFIED_OBSERVATION%');

  insert into pr2_controlled_research_ingest_results values
    ('PR2_15_RECEIPT_RLS_ENABLED',
      exists(
        select 1
        from pg_class c join pg_namespace n on n.oid=c.relnamespace
        where n.nspname='fwios'
          and c.relname='research_ingest_receipts_v1'
          and c.relrowsecurity=true
      ));
end
$test$;

select
  test_id,
  case when passed then 'PASS' else 'FAIL' end as status
from pr2_controlled_research_ingest_results
order by test_id;

rollback;
