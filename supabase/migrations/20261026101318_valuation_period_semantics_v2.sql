-- FWIOS valuation period semantics v2
-- Live migration version: 20261026101318
-- Applied 2026-10-26 after transaction dry-run.
--
-- Scope:
-- 1) resolve SEMIS/SAAS production-version authority;
-- 2) add generic period-aware metric semantics without deleting legacy rows;
-- 3) add semantic alias observations with explicit lineage;
-- 4) register ACN period-aware model contract 2.0 as EXPERIMENTAL only.
-- No valuation run or production resolver cutover is performed.

do $$
begin
  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='SEMIS_MIDCYCLE_DCF_V1::1.1'
      and status='PRODUCTION'
      and supersedes_version_id='SEMIS_MIDCYCLE_DCF_V1::1.0'
  ) then raise exception 'Expected SEMIS 1.1 production successor not found'; end if;

  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='SAAS_EV_FCF_REVERSE_DCF_V1::1.1-EXPERIMENTAL'
      and status='PRODUCTION'
      and regression_status='PASS'
  ) then raise exception 'Expected SAAS 1.1-EXPERIMENTAL production source not found'; end if;

  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='IT_SERVICES_FCF_COMPOUNDER_V1::1.0'
      and status='PRODUCTION'
  ) then raise exception 'Expected ACN v1 production model not found'; end if;
end $$;

update fwios.valuation_model_versions
set status='RETIRED'
where version_id='SEMIS_MIDCYCLE_DCF_V1::1.0'
  and status='PRODUCTION';

insert into fwios.valuation_model_versions(
  version_id,model_id,version_label,status,kernel_family,input_contract,model_policy,assumptions,
  confidence_tier,regression_status,effective_from,source_system,source_ref,supersedes_version_id
)
select
  'SAAS_EV_FCF_REVERSE_DCF_V1::1.1',
  model_id,'1.1','PRODUCTION',kernel_family,input_contract,model_policy,assumptions,
  confidence_tier,regression_status,date '2026-10-26','supabase',
  'VALUATION_VERSION_GOVERNANCE_20261026',version_id
from fwios.valuation_model_versions
where version_id='SAAS_EV_FCF_REVERSE_DCF_V1::1.1-EXPERIMENTAL'
on conflict(version_id) do update set
  status=excluded.status,
  kernel_family=excluded.kernel_family,
  input_contract=excluded.input_contract,
  model_policy=excluded.model_policy,
  assumptions=excluded.assumptions,
  confidence_tier=excluded.confidence_tier,
  regression_status=excluded.regression_status,
  effective_from=excluded.effective_from,
  source_system=excluded.source_system,
  source_ref=excluded.source_ref,
  supersedes_version_id=excluded.supersedes_version_id;

update fwios.valuation_model_versions
set status='RETIRED'
where version_id='SAAS_EV_FCF_REVERSE_DCF_V1::1.1-EXPERIMENTAL'
  and status='PRODUCTION';

insert into fwios.metric_definitions(
  metric_code,metric_name,value_kind,canonical_unit,scope_status,decision_uses,description,metadata,active
) values
(
  'BOOK_TO_BILL','Bookings to revenue ratio','NUMERIC','ratio','DECISION_RELEVANT',
  array['RESEARCH','VALUATION']::text[],
  'Bookings divided by revenue for the explicitly identified reporting period. Fiscal quarter/year belongs to observation metadata, not the metric code.',
  '{"period_identity_separate":true,"semantic_version":"METRIC_PERIOD_AWARE_V1"}'::jsonb,true
),
(
  'REVENUE_GROWTH_GUIDANCE_LC_MID','Revenue growth guidance midpoint (local currency)','NUMERIC','ratio','DECISION_RELEVANT',
  array['RESEARCH','VALUATION']::text[],
  'Midpoint of company revenue-growth guidance stated in local-currency terms for the explicitly identified guidance fiscal period.',
  '{"period_identity_separate":true,"semantic_version":"METRIC_PERIOD_AWARE_V1"}'::jsonb,true
),
(
  'FREE_CASH_FLOW_GUIDANCE','Free cash flow guidance','NUMERIC','USD B','DECISION_RELEVANT',
  array['RESEARCH','VALUATION']::text[],
  'Company free-cash-flow guidance for the explicitly identified fiscal period. Point guidance is distinct from low/high range-bound metrics.',
  '{"period_identity_separate":true,"semantic_version":"METRIC_PERIOD_AWARE_V1"}'::jsonb,true
)
on conflict(metric_code) do nothing;

insert into fwios.metric_legacy_mappings(
  source_layer,legacy_metric_id,definition_standard,metric_code,mapping_version,notes
) values
('COMPANY_METRICS','book_to_bill_q3','','BOOK_TO_BILL','METRIC_PERIOD_AWARE_V1','Q3 moves to observation fiscal_quarter metadata.'),
('NORMALIZED_METRICS','book_to_bill_q3','BOOK_TO_BILL_Q3','BOOK_TO_BILL','METRIC_PERIOD_AWARE_V1','Q3 moves to observation fiscal_quarter metadata.'),
('COMPANY_METRICS','fy2026_revenue_growth_guidance_lc_mid','','REVENUE_GROWTH_GUIDANCE_LC_MID','METRIC_PERIOD_AWARE_V1','FY2026 moves to observation fiscal_year metadata.'),
('NORMALIZED_METRICS','fy2026_revenue_growth_guidance_lc_mid','FY2026_REVENUE_GROWTH_GUIDANCE_LC_MID','REVENUE_GROWTH_GUIDANCE_LC_MID','METRIC_PERIOD_AWARE_V1','FY2026 moves to observation fiscal_year metadata.'),
('COMPANY_METRICS','fcf_fy2025','','FREE_CASH_FLOW','METRIC_PERIOD_AWARE_V1','FY2025 moves to YEAR observation metadata.'),
('NORMALIZED_METRICS','fcf_fy2025','COMPANY_NON_GAAP_FCF','FREE_CASH_FLOW','METRIC_PERIOD_AWARE_V1','FY2025 moves to YEAR observation metadata.'),
('COMPANY_METRICS','fcf_guidance_fy2026','','FREE_CASH_FLOW_GUIDANCE','METRIC_PERIOD_AWARE_V1','FY2026 moves to GUIDANCE fiscal_year metadata.'),
('NORMALIZED_METRICS','fcf_guidance_fy2026','STREAMING_V1','FREE_CASH_FLOW_GUIDANCE','METRIC_PERIOD_AWARE_V1','FY2026 moves to GUIDANCE fiscal_year metadata.')
on conflict do nothing;

insert into fwios.metric_observations(
  observation_key,instrument_id,metric_code,observation_layer,
  value_numeric,value_text,value_boolean,canonical_unit,
  source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
  period_start,period_end,as_of_date,period_label,reported_at,effective_at,
  normalization_version,derivation_method,source_observation_ids,
  primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
  valuation_model_id,provenance_status,quality_gate,raw_payload
)
select
  'SEMANTIC_V1:'||s.observation_key,
  s.instrument_id,'BOOK_TO_BILL','NORMALIZED',
  s.value_numeric,null,null,'ratio',
  s.source_value_text,s.source_unit,'QUARTER',s.fiscal_year,s.fiscal_quarter,
  s.period_start,s.period_end,s.as_of_date,s.period_label,s.reported_at,s.effective_at,
  'SEMANTIC_V1-PERIOD-AWARE','SEMANTIC_ALIAS',array[s.observation_id]::uuid[],
  s.primary_evidence_id,s.evidence_ids,'fwios.metric_observations',s.observation_key,s.source_reference,
  s.valuation_model_id,s.provenance_status,s.quality_gate,
  coalesce(s.raw_payload,'{}'::jsonb) || jsonb_build_object(
    'semantic_alias_version','METRIC_PERIOD_AWARE_V1',
    'semantic_alias_source_observation_key',s.observation_key
  )
from fwios.metric_observations s
where s.observation_key='NM:ACN:book_to_bill_q3:NORM_V1-IT-SERVICES'
on conflict(observation_key) do nothing;

insert into fwios.metric_observations(
  observation_key,instrument_id,metric_code,observation_layer,
  value_numeric,value_text,value_boolean,canonical_unit,
  source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
  period_start,period_end,as_of_date,period_label,reported_at,effective_at,
  normalization_version,derivation_method,source_observation_ids,
  primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
  valuation_model_id,provenance_status,quality_gate,raw_payload
)
select
  'SEMANTIC_V1:'||s.observation_key,
  s.instrument_id,'REVENUE_GROWTH_GUIDANCE_LC_MID','NORMALIZED',
  s.value_numeric,null,null,'ratio',
  s.source_value_text,s.source_unit,'GUIDANCE',s.fiscal_year,null,
  null,null,s.as_of_date,'FY'||s.fiscal_year||' guidance',s.reported_at,s.effective_at,
  'SEMANTIC_V1-PERIOD-AWARE','SEMANTIC_ALIAS',array[s.observation_id]::uuid[],
  s.primary_evidence_id,s.evidence_ids,'fwios.metric_observations',s.observation_key,s.source_reference,
  s.valuation_model_id,s.provenance_status,s.quality_gate,
  coalesce(s.raw_payload,'{}'::jsonb) || jsonb_build_object(
    'semantic_alias_version','METRIC_PERIOD_AWARE_V1',
    'semantic_alias_source_observation_key',s.observation_key
  )
from fwios.metric_observations s
where s.observation_key='NM:ACN:fy2026_revenue_growth_guidance_lc_mid:NORM_V1-IT-SERVICES'
on conflict(observation_key) do nothing;

insert into fwios.metric_observations(
  observation_key,instrument_id,metric_code,observation_layer,
  value_numeric,value_text,value_boolean,canonical_unit,
  source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
  period_start,period_end,as_of_date,period_label,reported_at,effective_at,
  normalization_version,derivation_method,source_observation_ids,
  primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
  valuation_model_id,provenance_status,quality_gate,raw_payload
)
select
  'SEMANTIC_V1:'||s.observation_key,
  s.instrument_id,'FREE_CASH_FLOW','NORMALIZED',
  s.value_numeric,null,null,'USD B',
  s.source_value_text,s.source_unit,'YEAR',s.fiscal_year,null,
  s.period_start,s.period_end,s.as_of_date,s.period_label,s.reported_at,s.effective_at,
  'SEMANTIC_V1-PERIOD-AWARE','SEMANTIC_ALIAS',array[s.observation_id]::uuid[],
  s.primary_evidence_id,s.evidence_ids,'fwios.metric_observations',s.observation_key,s.source_reference,
  s.valuation_model_id,s.provenance_status,s.quality_gate,
  coalesce(s.raw_payload,'{}'::jsonb) || jsonb_build_object(
    'semantic_alias_version','METRIC_PERIOD_AWARE_V1',
    'semantic_alias_source_observation_key',s.observation_key
  )
from fwios.metric_observations s
where s.observation_key='NM:EOG:fcf_fy2025:NORM_V1'
on conflict(observation_key) do nothing;

insert into fwios.metric_observations(
  observation_key,instrument_id,metric_code,observation_layer,
  value_numeric,value_text,value_boolean,canonical_unit,
  source_value_text,source_unit,period_type,fiscal_year,fiscal_quarter,
  period_start,period_end,as_of_date,period_label,reported_at,effective_at,
  normalization_version,derivation_method,source_observation_ids,
  primary_evidence_id,evidence_ids,source_table,source_key,source_reference,
  valuation_model_id,provenance_status,quality_gate,raw_payload
)
select
  'SEMANTIC_V1:'||s.observation_key,
  s.instrument_id,'FREE_CASH_FLOW_GUIDANCE','GUIDANCE',
  s.value_numeric,null,null,'USD B',
  s.source_value_text,s.source_unit,'GUIDANCE',s.fiscal_year,null,
  null,null,s.as_of_date,'FY'||s.fiscal_year||' guidance',s.reported_at,s.effective_at,
  'SEMANTIC_V1-PERIOD-AWARE','SEMANTIC_ALIAS_FROM_COMPANY_GUIDANCE',array[s.observation_id]::uuid[],
  s.primary_evidence_id,s.evidence_ids,'fwios.metric_observations',s.observation_key,s.source_reference,
  s.valuation_model_id,s.provenance_status,s.quality_gate,
  coalesce(s.raw_payload,'{}'::jsonb) || jsonb_build_object(
    'semantic_alias_version','METRIC_PERIOD_AWARE_V1',
    'semantic_alias_source_observation_key',s.observation_key
  )
from fwios.metric_observations s
where s.observation_key='NM:NFLX:fcf_guidance_fy2026:NORM_V1-STREAMING'
on conflict(observation_key) do nothing;

insert into fwios.valuation_model_versions(
  version_id,model_id,version_label,status,kernel_family,input_contract,model_policy,assumptions,
  confidence_tier,regression_status,effective_from,source_system,source_ref,supersedes_version_id
) values (
  'IT_SERVICES_FCF_COMPOUNDER_V1::2.0',
  'IT_SERVICES_FCF_COMPOUNDER_V1',
  '2.0','EXPERIMENTAL','FCF_COMPOUNDER',
  '{
    "contract_version":"PERIOD_AWARE_INPUT_V2",
    "resolver_policy":"VALUATION_INPUT_RESOLVER_V1",
    "production_read_cutover":false,
    "required_metrics":["FCF_GUIDANCE_LOW","FCF_GUIDANCE_MIDPOINT","FCF_GUIDANCE_HIGH","REVENUE_GROWTH_GUIDANCE_LC_MID","FREE_CASH_FLOW","NET_CASH","SHARES_OUTSTANDING"],
    "optional_diagnostics":["BOOK_TO_BILL","OPERATING_MARGIN","GROSS_MARGIN"],
    "input_selectors":[
      {"input_key":"fcf_guidance_low","metric_code":"FCF_GUIDANCE_LOW","period_type":"GUIDANCE","period_rule":"NEXT_FISCAL_YEAR_GUIDANCE","required":true},
      {"input_key":"fcf_guidance_midpoint","metric_code":"FCF_GUIDANCE_MIDPOINT","period_type":"GUIDANCE","period_rule":"NEXT_FISCAL_YEAR_GUIDANCE","required":true},
      {"input_key":"fcf_guidance_high","metric_code":"FCF_GUIDANCE_HIGH","period_type":"GUIDANCE","period_rule":"NEXT_FISCAL_YEAR_GUIDANCE","required":true},
      {"input_key":"revenue_growth_guidance_lc_mid","metric_code":"REVENUE_GROWTH_GUIDANCE_LC_MID","period_type":"GUIDANCE","period_rule":"NEXT_FISCAL_YEAR_GUIDANCE","required":true},
      {"input_key":"fcf_ltm","metric_code":"FREE_CASH_FLOW","period_type":"LTM","period_rule":"LATEST_AT_OR_AFTER_CLOSED_FISCAL_PERIOD","required":true},
      {"input_key":"net_cash","metric_code":"NET_CASH","period_type":"INSTANT","period_rule":"LATEST_AT_OR_AFTER_CLOSED_FISCAL_PERIOD","required":true},
      {"input_key":"shares_outstanding","metric_code":"SHARES_OUTSTANDING","period_rule":"LATEST_PERIOD_END_SHARE_COUNT_AT_OR_AFTER_CLOSED_FISCAL_PERIOD","required":true},
      {"input_key":"book_to_bill","metric_code":"BOOK_TO_BILL","period_type":"QUARTER","period_rule":"LATEST_REPORTED_QUARTER","required":false},
      {"input_key":"operating_margin","metric_code":"OPERATING_MARGIN","period_type":"QUARTER","period_rule":"LATEST_REPORTED_QUARTER","required":false},
      {"input_key":"gross_margin","metric_code":"GROSS_MARGIN","period_type":"QUARTER","period_rule":"LATEST_REPORTED_QUARTER","required":false}
    ],
    "fiscal_rollover_policy":"After a fiscal year closes, prior-fiscal-year guidance cannot satisfy NEXT_FISCAL_YEAR_GUIDANCE.",
    "normalization_version":"NORM_V2-IT-SERVICES-PERIOD-AWARE"
  }'::jsonb,
  '{
    "policy":"IT_SERVICES_FCF_COMPOUNDER_V2_PERIOD_AWARE",
    "method":"10-year equity FCF DCF",
    "probabilities":"25/50/25",
    "starting_fcf_policy":"Resolve company FCF guidance low/mid/high from the next fiscal-year guidance observations; never hardcode reported guidance values in assumptions.",
    "growth_anchor_policy":"Latest valid next-fiscal-year local-currency revenue-growth guidance is a sanity anchor; long-duration growth remains a versioned valuation assumption.",
    "bookings_policy":"Book-to-bill is optional visibility context; approximately 1.0 is neutral and cannot create a valuation uplift by itself.",
    "margin_policy":"Operating and gross margins are optional diagnostics unless a future model version makes them mathematically required.",
    "hardware_policy":"NOT_COVERED_FAIL_CLOSED",
    "human_execution_only":true
  }'::jsonb,
  '{
    "base":{"g1_5":0.04,"g6_10":0.03,"discount":0.12,"terminal":0.03},
    "bear":{"g1_5":0.01,"g6_10":0.02,"discount":0.13,"terminal":0.025},
    "bull":{"g1_5":0.07,"g6_10":0.04,"discount":0.11,"terminal":0.035}
  }'::jsonb,
  'PREVIEW_ONLY','PASS',date '2026-10-26','supabase',
  'ACN_PERIOD_AWARE_CONTRACT_V2_20261026',
  'IT_SERVICES_FCF_COMPOUNDER_V1::1.0'
)
on conflict(version_id) do update set
  status='EXPERIMENTAL',
  kernel_family=excluded.kernel_family,
  input_contract=excluded.input_contract,
  model_policy=excluded.model_policy,
  assumptions=excluded.assumptions,
  confidence_tier=excluded.confidence_tier,
  regression_status=excluded.regression_status,
  effective_from=excluded.effective_from,
  source_system=excluded.source_system,
  source_ref=excluded.source_ref,
  supersedes_version_id=excluded.supersedes_version_id;

do $$
declare
  v_bad int;
  v_aliases int;
  v_maps int;
  v_prod_versions int;
  v_acn_prod_count int;
begin
  select count(*) into v_bad
  from (
    select m.model_id
    from fwios.valuation_models m
    left join fwios.valuation_model_versions v on v.model_id=m.model_id
    where m.production_status='IMPLEMENTED'
      and m.model_id in ('SEMIS_MIDCYCLE_DCF_V1','SAAS_EV_FCF_REVERSE_DCF_V1')
    group by m.model_id,m.model_version
    having count(*) filter(where v.status='PRODUCTION') <> 1
       or not bool_or(v.status='PRODUCTION' and v.version_label=m.model_version)
  ) x;
  if v_bad <> 0 then raise exception 'Version governance cleanup failed: % bad models',v_bad; end if;

  if (select status from fwios.valuation_model_versions where version_id='SEMIS_MIDCYCLE_DCF_V1::1.0') <> 'RETIRED'
     or (select status from fwios.valuation_model_versions where version_id='SEMIS_MIDCYCLE_DCF_V1::1.1') <> 'PRODUCTION'
    then raise exception 'SEMIS version authority not resolved'; end if;

  if (select status from fwios.valuation_model_versions where version_id='SAAS_EV_FCF_REVERSE_DCF_V1::1.1-EXPERIMENTAL') <> 'RETIRED'
     or (select status from fwios.valuation_model_versions where version_id='SAAS_EV_FCF_REVERSE_DCF_V1::1.1') <> 'PRODUCTION'
    then raise exception 'SAAS version authority not resolved'; end if;

  select count(*) into v_prod_versions from fwios.valuation_model_versions where status='PRODUCTION';
  if v_prod_versions <> 20 then raise exception 'Expected 20 authoritative production version rows, got %',v_prod_versions; end if;

  if (select count(*) from fwios.metric_definitions
      where metric_code in ('BOOK_TO_BILL','REVENUE_GROWTH_GUIDANCE_LC_MID','FREE_CASH_FLOW_GUIDANCE')
        and active=true) <> 3
    then raise exception 'Generic metric definitions incomplete'; end if;

  select count(*) into v_maps
  from fwios.metric_legacy_mappings
  where mapping_version='METRIC_PERIOD_AWARE_V1'
    and legacy_metric_id in ('book_to_bill_q3','fy2026_revenue_growth_guidance_lc_mid','fcf_fy2025','fcf_guidance_fy2026');
  if v_maps <> 8 then raise exception 'Expected 8 period-aware legacy mappings, got %',v_maps; end if;

  select count(*) into v_aliases
  from fwios.metric_observations
  where observation_key in (
    'SEMANTIC_V1:NM:ACN:book_to_bill_q3:NORM_V1-IT-SERVICES',
    'SEMANTIC_V1:NM:ACN:fy2026_revenue_growth_guidance_lc_mid:NORM_V1-IT-SERVICES',
    'SEMANTIC_V1:NM:EOG:fcf_fy2025:NORM_V1',
    'SEMANTIC_V1:NM:NFLX:fcf_guidance_fy2026:NORM_V1-STREAMING'
  );
  if v_aliases <> 4 then raise exception 'Expected 4 semantic alias observations, got %',v_aliases; end if;

  if not exists (
    select 1 from fwios.metric_observations
    where observation_key='SEMANTIC_V1:NM:NFLX:fcf_guidance_fy2026:NORM_V1-STREAMING'
      and metric_code='FREE_CASH_FLOW_GUIDANCE'
      and observation_layer='GUIDANCE'
      and period_type='GUIDANCE'
      and fiscal_year=2026
  ) then raise exception 'NFLX guidance semantic alias invalid'; end if;

  if not exists (
    select 1 from fwios.metric_observations
    where observation_key='SEMANTIC_V1:NM:EOG:fcf_fy2025:NORM_V1'
      and metric_code='FREE_CASH_FLOW'
      and period_type='YEAR'
      and fiscal_year=2025
  ) then raise exception 'EOG FY2025 FCF semantic alias invalid'; end if;

  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='IT_SERVICES_FCF_COMPOUNDER_V1::2.0'
      and status='EXPERIMENTAL'
      and input_contract->>'production_read_cutover'='false'
      and assumptions::text not like '%starting_fcf_b%'
  ) then raise exception 'ACN period-aware v2 contract invalid'; end if;

  if exists (
    select 1
    from fwios.valuation_model_versions v
    cross join lateral jsonb_array_elements_text(v.input_contract->'required_metrics') x(metric_code)
    where v.version_id='IT_SERVICES_FCF_COMPOUNDER_V1::2.0'
      and metric_code ~* '(fy[0-9]{2,4}|(^|_)q[1-4]($|_))'
  ) then raise exception 'ACN v2 still has period-encoded required metric identity'; end if;

  select count(*) into v_acn_prod_count
  from fwios.valuation_model_versions
  where model_id='IT_SERVICES_FCF_COMPOUNDER_V1' and status='PRODUCTION';
  if v_acn_prod_count <> 1
     or (select model_version from fwios.valuation_models where model_id='IT_SERVICES_FCF_COMPOUNDER_V1') <> '1.0'
    then raise exception 'ACN production authority changed before cutover'; end if;
end $$;
