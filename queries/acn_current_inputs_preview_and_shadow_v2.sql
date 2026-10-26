-- ACN current-period primary evidence -> controlled PREVIEW -> read-only shadow valuation v2
-- Date: 2026-10-26
-- No APPLY, no canonical writes, no valuation_run insert, no dashboard change.
--
-- Primary evidence:
-- - Accenture Q4/FY2026 earnings release/presentation, 2026-10-01
-- - Accenture FY2026 Form 10-K, accession 0001467373-26-000049
--
-- Required ACN v2 inputs supplied in PREVIEW:
-- FREE_CASH_FLOW 11.620598 USD B (FY2026 actual)
-- NET_CASH 2.726011 USD B (2026-08-31)
-- SHARES_OUTSTANDING 596.1 M shares (2026-08-31)
-- FCF_GUIDANCE_LOW/MID/HIGH 11.0/11.4/11.8 USD B (FY2027)
-- REVENUE_GROWTH_GUIDANCE_LC_MID 0.045 (FY2027)

with
payload as (
  select jsonb_build_object(
    'schema_version','chatgpt_research_payload_v1',
    'mode','PREVIEW',
    'command','FWIOS ACN FY2026 close + FY2027 guidance period-aware PREVIEW',
    'ticker','ACN',
    'research_as_of','2026-10-26T10:22:00Z',
    'evidence',jsonb_build_array(
      jsonb_build_object(
        'evidence_ref','acn-q4fy26-earnings-20261001',
        'fact_class','REPORTED_FINANCIALS',
        'claim','Accenture Q4/FY2026 release reports FY2026 free cash flow of USD 11.6B, approximately 596.1M total shares outstanding at 2026-08-31, FY2027 FCF guidance of USD 11.0B-11.8B, and FY2027 revenue growth guidance of 3%-6% in local currency.',
        'source_name','Accenture Q4 FY2026 Earnings Release / Presentation',
        'source_url','https://investor.accenture.com/~/media/Files/A/accenture-v4/investors/earnings-reports/2026/accentures-fourth-quarter-fiscal-2026-earnings-release.pdf',
        'source_type','WEB_PRIMARY','source_tier','A',
        'retrieved_at','2026-10-26T10:22:00Z',
        'reported_at','2026-10-01T00:00:00Z',
        'reporting_period','FY2026 ended 2026-08-31 / FY2027 outlook as of 2026-10-01',
        'verification_status','VERIFIED',
        'conflict_group',null,
        'notes','Primary issuer earnings release and presentation.'
      ),
      jsonb_build_object(
        'evidence_ref','acn-10k-2026-0001467373-26-000049',
        'fact_class','REPORTED_FINANCIALS',
        'claim','Accenture FY2026 Form 10-K reports cash USD 12.831471B, short-term investments USD 0.006298B, current debt and bank borrowings USD 0.113069B, long-term debt USD 9.998689B, operating cash flow USD 12.363346B and capex USD 0.742748B for FY2026.',
        'source_name','SEC EDGAR - Accenture plc FY2026 Form 10-K',
        'source_url','https://www.sec.gov/Archives/edgar/data/1467373/000146737326000049/acn-20260831.htm',
        'source_type','WEB_PRIMARY','source_tier','A',
        'retrieved_at','2026-10-26T10:22:00Z',
        'reported_at','2026-10-16T10:22:21Z',
        'reporting_period','FY2026 ended 2026-08-31',
        'verification_status','VERIFIED',
        'conflict_group',null,
        'notes','Primary SEC filing.'
      )
    ),
    'metrics',jsonb_build_array(
      jsonb_build_object(
        'metric_code','FREE_CASH_FLOW','value_kind','NUMERIC','value_numeric',11.620598,
        'canonical_unit','USD B','source_unit','USD B','currency','USD','period_type','LTM',
        'fiscal_year',2026,'period_start','2025-09-01','period_end','2026-08-31','as_of_date','2026-08-31',
        'period_label','LTM / FY2026 ended 2026-08-31','reported_at','2026-10-16T10:22:21Z',
        'evidence_refs',jsonb_build_array('acn-10k-2026-0001467373-26-000049'),
        'verification_status','VERIFIED','derivation_method','OCF_MINUS_CAPEX',
        'derivation_inputs',jsonb_build_object(
          'NetCashProvidedByUsedInOperatingActivities_USD_B',12.363346,
          'PaymentsToAcquirePropertyPlantAndEquipment_USD_B',0.742748
        )
      ),
      jsonb_build_object(
        'metric_code','NET_CASH','value_kind','NUMERIC','value_numeric',2.726011,
        'canonical_unit','USD B','source_unit','USD B','currency','USD','period_type','INSTANT',
        'fiscal_year',2026,'period_end','2026-08-31','as_of_date','2026-08-31',
        'period_label','FY2026 year-end balance sheet','reported_at','2026-10-16T10:22:21Z',
        'evidence_refs',jsonb_build_array('acn-10k-2026-0001467373-26-000049'),
        'verification_status','VERIFIED',
        'derivation_method','CASH_PLUS_ST_INVESTMENTS_MINUS_CURRENT_DEBT_MINUS_LONG_TERM_DEBT',
        'derivation_inputs',jsonb_build_object(
          'cash_and_cash_equivalents_USD_B',12.831471,
          'short_term_investments_USD_B',0.006298,
          'current_debt_and_bank_borrowings_USD_B',0.113069,
          'long_term_debt_USD_B',9.998689
        )
      ),
      jsonb_build_object(
        'metric_code','SHARES_OUTSTANDING','value_kind','NUMERIC','value_numeric',596.1,
        'canonical_unit','M shares','source_unit','M shares','period_type','INSTANT',
        'fiscal_year',2026,'period_end','2026-08-31','as_of_date','2026-08-31',
        'period_label','FY2026 year-end total shares outstanding','reported_at','2026-10-01T00:00:00Z',
        'evidence_refs',jsonb_build_array('acn-q4fy26-earnings-20261001'),'verification_status','VERIFIED'
      ),
      jsonb_build_object(
        'metric_code','FCF_GUIDANCE_LOW','value_kind','NUMERIC','value_numeric',11.0,
        'canonical_unit','USD B','source_unit','USD B','currency','USD','period_type','GUIDANCE',
        'fiscal_year',2027,'as_of_date','2026-10-01','period_label','FY2027 guidance',
        'reported_at','2026-10-01T00:00:00Z','evidence_refs',jsonb_build_array('acn-q4fy26-earnings-20261001'),
        'verification_status','VERIFIED'
      ),
      jsonb_build_object(
        'metric_code','FCF_GUIDANCE_MIDPOINT','value_kind','NUMERIC','value_numeric',11.4,
        'canonical_unit','USD B','source_unit','USD B','currency','USD','period_type','GUIDANCE',
        'fiscal_year',2027,'as_of_date','2026-10-01','period_label','FY2027 guidance midpoint',
        'reported_at','2026-10-01T00:00:00Z','evidence_refs',jsonb_build_array('acn-q4fy26-earnings-20261001'),
        'verification_status','VERIFIED','derivation_method','(GUIDANCE_LOW + GUIDANCE_HIGH) / 2',
        'derivation_inputs',jsonb_build_object('guidance_low_USD_B',11.0,'guidance_high_USD_B',11.8)
      ),
      jsonb_build_object(
        'metric_code','FCF_GUIDANCE_HIGH','value_kind','NUMERIC','value_numeric',11.8,
        'canonical_unit','USD B','source_unit','USD B','currency','USD','period_type','GUIDANCE',
        'fiscal_year',2027,'as_of_date','2026-10-01','period_label','FY2027 guidance',
        'reported_at','2026-10-01T00:00:00Z','evidence_refs',jsonb_build_array('acn-q4fy26-earnings-20261001'),
        'verification_status','VERIFIED'
      ),
      jsonb_build_object(
        'metric_code','REVENUE_GROWTH_GUIDANCE_LC_MID','value_kind','NUMERIC','value_numeric',0.045,
        'canonical_unit','ratio','source_unit','ratio','period_type','GUIDANCE',
        'fiscal_year',2027,'as_of_date','2026-10-01',
        'period_label','FY2027 local-currency revenue growth guidance midpoint',
        'reported_at','2026-10-01T00:00:00Z','evidence_refs',jsonb_build_array('acn-q4fy26-earnings-20261001'),
        'verification_status','VERIFIED','derivation_method','(GUIDANCE_LOW + GUIDANCE_HIGH) / 2',
        'derivation_inputs',jsonb_build_object('guidance_low_ratio',0.03,'guidance_high_ratio',0.06)
      )
    ),
    'guidance','[]'::jsonb,
    'risks','[]'::jsonb
  ) as payload
),
preview as (
  select fwios.preview_research_ingest_v1(payload) result from payload
),
resolved_preview as (
  select
    (select (x->>'canonical_value_numeric')::numeric
       from preview p cross join lateral jsonb_array_elements(p.result->'metrics') x
      where x->>'metric_code'='FCF_GUIDANCE_LOW') fcf_low,
    (select (x->>'canonical_value_numeric')::numeric
       from preview p cross join lateral jsonb_array_elements(p.result->'metrics') x
      where x->>'metric_code'='FCF_GUIDANCE_MIDPOINT') fcf_mid,
    (select (x->>'canonical_value_numeric')::numeric
       from preview p cross join lateral jsonb_array_elements(p.result->'metrics') x
      where x->>'metric_code'='FCF_GUIDANCE_HIGH') fcf_high,
    (select (x->>'canonical_value_numeric')::numeric
       from preview p cross join lateral jsonb_array_elements(p.result->'metrics') x
      where x->>'metric_code'='NET_CASH') net_cash_b,
    (select (x->>'canonical_value_numeric')::numeric
       from preview p cross join lateral jsonb_array_elements(p.result->'metrics') x
      where x->>'metric_code'='SHARES_OUTSTANDING') shares_m
),
model as (
  select assumptions
  from fwios.valuation_model_versions
  where version_id='IT_SERVICES_FCF_COMPOUNDER_V1::2.0'
    and status='EXPERIMENTAL'
    and input_contract->>'production_read_cutover'='false'
),
scenario_inputs as (
  select 'BEAR'::text scenario,0.25::numeric probability,r.fcf_low starting_fcf_b,
         (m.assumptions->'bear'->>'g1_5')::numeric g1_5,
         (m.assumptions->'bear'->>'g6_10')::numeric g6_10,
         (m.assumptions->'bear'->>'discount')::numeric discount_rate,
         (m.assumptions->'bear'->>'terminal')::numeric terminal_growth,
         r.net_cash_b,r.shares_m
  from resolved_preview r cross join model m
  union all
  select 'BASE',0.50,r.fcf_mid,
         (m.assumptions->'base'->>'g1_5')::numeric,
         (m.assumptions->'base'->>'g6_10')::numeric,
         (m.assumptions->'base'->>'discount')::numeric,
         (m.assumptions->'base'->>'terminal')::numeric,
         r.net_cash_b,r.shares_m
  from resolved_preview r cross join model m
  union all
  select 'BULL',0.25,r.fcf_high,
         (m.assumptions->'bull'->>'g1_5')::numeric,
         (m.assumptions->'bull'->>'g6_10')::numeric,
         (m.assumptions->'bull'->>'discount')::numeric,
         (m.assumptions->'bull'->>'terminal')::numeric,
         r.net_cash_b,r.shares_m
  from resolved_preview r cross join model m
),
recursive_forecast as (
  select s.*,1 year_no,s.starting_fcf_b*(1+s.g1_5) fcf_b
  from scenario_inputs s
  union all
  select f.scenario,f.probability,f.starting_fcf_b,f.g1_5,f.g6_10,f.discount_rate,f.terminal_growth,
         f.net_cash_b,f.shares_m,f.year_no+1,
         f.fcf_b*(1+case when f.year_no+1<=5 then f.g1_5 else f.g6_10 end)
  from recursive_forecast f
  where f.year_no<10
),
scenario_calc as (
  select
    scenario,probability,max(starting_fcf_b) starting_fcf_b,max(net_cash_b) net_cash_b,max(shares_m) shares_m,
    max(discount_rate) discount_rate,max(terminal_growth) terminal_growth,
    sum(fcf_b/power(1+discount_rate,year_no)) pv_explicit_b,
    max(fcf_b) filter(where year_no=10) year10_fcf_b
  from recursive_forecast
  group by scenario,probability
),
shadow as (
  select
    s.*,
    (
      s.pv_explicit_b
      + s.year10_fcf_b*(1+s.terminal_growth)/(s.discount_rate-s.terminal_growth)
        / power(1+s.discount_rate,10)
      + s.net_cash_b
    )*1000/s.shares_m as shadow_fv
  from scenario_calc s
),
shadow_summary as (
  select sum(probability*shadow_fv) probability_weighted_fv from shadow
),
production as (
  select bear_fv_per_share,base_fv_per_share,bull_fv_per_share,probability_weighted_fv_per_share
  from fwios.valuation_runs
  where run_id='VAL-SUPA-ACN-ITSERV-20260905'
),
price as (
  select current_price from fwios.v_dashboard_valuation_map where ticker='ACN'
)
select
  p.result->>'overall_status' controlled_preview_status,
  (p.result->'summary'->>'metric_count')::int preview_metric_count,
  (p.result->'summary'->>'blocker_count')::int preview_blocker_count,
  p.result->>'production_changes' production_changes,
  p.result->>'payload_fingerprint' payload_fingerprint,
  s.scenario,
  s.probability,
  s.starting_fcf_b,
  s.net_cash_b,
  s.shares_m,
  round(s.shadow_fv,8) shadow_fv,
  round(case s.scenario
    when 'BEAR' then prod.bear_fv_per_share
    when 'BASE' then prod.base_fv_per_share
    when 'BULL' then prod.bull_fv_per_share end,8) production_v1_fv,
  round(
    s.shadow_fv / case s.scenario
      when 'BEAR' then prod.bear_fv_per_share
      when 'BASE' then prod.base_fv_per_share
      when 'BULL' then prod.bull_fv_per_share end - 1
  ,8) change_vs_v1,
  round(s.shadow_fv/pr.current_price-1,8) upside_vs_current_price,
  round(ss.probability_weighted_fv,8) shadow_probability_weighted_fv,
  round(prod.probability_weighted_fv_per_share,8) production_v1_probability_weighted_fv,
  round(ss.probability_weighted_fv/prod.probability_weighted_fv_per_share-1,8) pw_change_vs_v1,
  round(ss.probability_weighted_fv/pr.current_price-1,8) shadow_pw_upside_vs_current_price
from preview p
cross join shadow s
cross join shadow_summary ss
cross join production prod
cross join price pr
order by case s.scenario when 'BEAR' then 1 when 'BASE' then 2 else 3 end;
