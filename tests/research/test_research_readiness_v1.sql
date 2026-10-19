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

select test_id, case when passed then 'PASS' else 'FAIL' end as status
from pr4_research_readiness_results
order by test_id;

rollback;
