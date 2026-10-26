-- ACN current-input PREVIEW + shadow valuation v2 regression
-- Read-only: preview RPC only, no APPLY and no valuation_run insert.

do $$
declare
  v_payload jsonb;
  v_p1 jsonb;
  v_p2 jsonb;
  v_receipts bigint;
  v_evidence bigint;
  v_obs bigint;
  v_bear numeric;
  v_base numeric;
  v_bull numeric;
  v_pw numeric;
begin
  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='IT_SERVICES_FCF_COMPOUNDER_V1::2.0'
      and status='EXPERIMENTAL'
      and input_contract->>'production_read_cutover'='false'
  ) then raise exception 'ACNSH-01 ACN v2 experimental contract missing'; end if;

  if (select count(*) from fwios.metric_definitions
      where metric_code in ('REVENUE_GROWTH_GUIDANCE_LC_MID','NET_CASH','SHARES_OUTSTANDING','FREE_CASH_FLOW')
        and active) <> 4 then
    raise exception 'ACNSH-02 required semantic definitions missing';
  end if;

  select count(*) into v_receipts from fwios.research_ingest_receipts_v1;
  select count(*) into v_evidence from fwios.evidence_records;
  select count(*) into v_obs from fwios.metric_observations;

  v_payload := jsonb_build_object(
    'schema_version','chatgpt_research_payload_v1','mode','PREVIEW',
    'command','FWIOS ACN FY2026 close + FY2027 guidance period-aware PREVIEW',
    'ticker','ACN','research_as_of','2026-10-26T10:22:00Z',
    'evidence',jsonb_build_array(
      jsonb_build_object(
        'evidence_ref','acn-q4fy26-earnings-20261001','fact_class','REPORTED_FINANCIALS',
        'claim','Accenture Q4/FY2026 release reports FY2026 free cash flow of USD 11.6B, approximately 596.1M total shares outstanding at 2026-08-31, FY2027 FCF guidance of USD 11.0B-11.8B, and FY2027 revenue growth guidance of 3%-6% in local currency.',
        'source_name','Accenture Q4 FY2026 Earnings Release / Presentation',
        'source_url','https://investor.accenture.com/~/media/Files/A/accenture-v4/investors/earnings-reports/2026/accentures-fourth-quarter-fiscal-2026-earnings-release.pdf',
        'source_type','WEB_PRIMARY','source_tier','A','retrieved_at','2026-10-26T10:22:00Z',
        'reported_at','2026-10-01T00:00:00Z','reporting_period','FY2026 ended 2026-08-31 / FY2027 outlook as of 2026-10-01',
        'verification_status','VERIFIED','conflict_group',null
      ),
      jsonb_build_object(
        'evidence_ref','acn-10k-2026-0001467373-26-000049','fact_class','REPORTED_FINANCIALS',
        'claim','Accenture FY2026 Form 10-K reports cash USD 12.831471B, short-term investments USD 0.006298B, current debt and bank borrowings USD 0.113069B, long-term debt USD 9.998689B, operating cash flow USD 12.363346B and capex USD 0.742748B for FY2026.',
        'source_name','SEC EDGAR - Accenture plc FY2026 Form 10-K',
        'source_url','https://www.sec.gov/Archives/edgar/data/1467373/000146737326000049/acn-20260831.htm',
        'source_type','WEB_PRIMARY','source_tier','A','retrieved_at','2026-10-26T10:22:00Z',
        'reported_at','2026-10-16T10:22:21Z','reporting_period','FY2026 ended 2026-08-31',
        'verification_status','VERIFIED','conflict_group',null
      )
    ),
    'metrics',jsonb_build_array(
      jsonb_build_object(
        'metric_code','FREE_CASH_FLOW','value_kind','NUMERIC','value_numeric',11.620598,
        'canonical_unit','USD B','source_unit','USD B','currency','USD','period_type','LTM',
        'fiscal_year',2026,'period_start','2025-09-01','period_end','2026-08-31','as_of_date','2026-08-31',
        'period_label','LTM / FY2026 ended 2026-08-31','reported_at','2026-10-16T10:22:21Z',
        'evidence_refs',jsonb_build_array('acn-10k-2026-0001467373-26-000049'),'verification_status','VERIFIED',
        'derivation_method','OCF_MINUS_CAPEX'
      ),
      jsonb_build_object(
        'metric_code','NET_CASH','value_kind','NUMERIC','value_numeric',2.726011,
        'canonical_unit','USD B','source_unit','USD B','currency','USD','period_type','INSTANT',
        'fiscal_year',2026,'period_end','2026-08-31','as_of_date','2026-08-31',
        'period_label','FY2026 year-end balance sheet','reported_at','2026-10-16T10:22:21Z',
        'evidence_refs',jsonb_build_array('acn-10k-2026-0001467373-26-000049'),'verification_status','VERIFIED',
        'derivation_method','CASH_PLUS_ST_INVESTMENTS_MINUS_CURRENT_DEBT_MINUS_LONG_TERM_DEBT'
      ),
      jsonb_build_object(
        'metric_code','SHARES_OUTSTANDING','value_kind','NUMERIC','value_numeric',596.1,
        'canonical_unit','M shares','source_unit','M shares','period_type','INSTANT','fiscal_year',2026,
        'period_end','2026-08-31','as_of_date','2026-08-31','period_label','FY2026 year-end total shares outstanding',
        'reported_at','2026-10-01T00:00:00Z','evidence_refs',jsonb_build_array('acn-q4fy26-earnings-20261001'),
        'verification_status','VERIFIED'
      ),
      jsonb_build_object(
        'metric_code','FCF_GUIDANCE_LOW','value_kind','NUMERIC','value_numeric',11.0,
        'canonical_unit','USD B','source_unit','USD B','currency','USD','period_type','GUIDANCE','fiscal_year',2027,
        'as_of_date','2026-10-01','period_label','FY2027 guidance','reported_at','2026-10-01T00:00:00Z',
        'evidence_refs',jsonb_build_array('acn-q4fy26-earnings-20261001'),'verification_status','VERIFIED'
      ),
      jsonb_build_object(
        'metric_code','FCF_GUIDANCE_MIDPOINT','value_kind','NUMERIC','value_numeric',11.4,
        'canonical_unit','USD B','source_unit','USD B','currency','USD','period_type','GUIDANCE','fiscal_year',2027,
        'as_of_date','2026-10-01','period_label','FY2027 guidance midpoint','reported_at','2026-10-01T00:00:00Z',
        'evidence_refs',jsonb_build_array('acn-q4fy26-earnings-20261001'),'verification_status','VERIFIED',
        'derivation_method','(GUIDANCE_LOW + GUIDANCE_HIGH) / 2'
      ),
      jsonb_build_object(
        'metric_code','FCF_GUIDANCE_HIGH','value_kind','NUMERIC','value_numeric',11.8,
        'canonical_unit','USD B','source_unit','USD B','currency','USD','period_type','GUIDANCE','fiscal_year',2027,
        'as_of_date','2026-10-01','period_label','FY2027 guidance','reported_at','2026-10-01T00:00:00Z',
        'evidence_refs',jsonb_build_array('acn-q4fy26-earnings-20261001'),'verification_status','VERIFIED'
      ),
      jsonb_build_object(
        'metric_code','REVENUE_GROWTH_GUIDANCE_LC_MID','value_kind','NUMERIC','value_numeric',0.045,
        'canonical_unit','ratio','source_unit','ratio','period_type','GUIDANCE','fiscal_year',2027,
        'as_of_date','2026-10-01','period_label','FY2027 local-currency revenue growth guidance midpoint',
        'reported_at','2026-10-01T00:00:00Z','evidence_refs',jsonb_build_array('acn-q4fy26-earnings-20261001'),
        'verification_status','VERIFIED','derivation_method','(GUIDANCE_LOW + GUIDANCE_HIGH) / 2'
      )
    ),
    'guidance','[]'::jsonb,'risks','[]'::jsonb
  );

  v_p1 := fwios.preview_research_ingest_v1(v_payload);
  v_p2 := fwios.preview_research_ingest_v1(v_payload);

  if v_p1->>'overall_status'<>'PASS'
     or (v_p1->'summary'->>'metric_count')::int<>7
     or (v_p1->'summary'->>'evidence_count')::int<>2
     or (v_p1->'summary'->>'blocker_count')::int<>0
     or v_p1->>'production_changes'<>'NONE' then
    raise exception 'ACNSH-03 controlled PREVIEW did not pass: %',v_p1;
  end if;

  if v_p1->>'payload_fingerprint'<>v_p2->>'payload_fingerprint' then
    raise exception 'ACNSH-04 PREVIEW fingerprint is not deterministic';
  end if;

  if (select count(*) from fwios.research_ingest_receipts_v1)<>v_receipts
     or (select count(*) from fwios.evidence_records)<>v_evidence
     or (select count(*) from fwios.metric_observations)<>v_obs then
    raise exception 'ACNSH-05 PREVIEW mutated controlled research state';
  end if;

  with recursive s(scenario,starting_fcf_b,g1,g2,disc,tg,net_cash_b,shares_m) as (
    values
      ('BEAR',11.0::numeric,0.01::numeric,0.02::numeric,0.13::numeric,0.025::numeric,2.726011::numeric,596.1::numeric),
      ('BASE',11.4::numeric,0.04::numeric,0.03::numeric,0.12::numeric,0.03::numeric,2.726011::numeric,596.1::numeric),
      ('BULL',11.8::numeric,0.07::numeric,0.04::numeric,0.11::numeric,0.035::numeric,2.726011::numeric,596.1::numeric)
  ),
  f as (
    select s.*,1 y,starting_fcf_b*(1+g1) fcf_b from s
    union all
    select f.scenario,f.starting_fcf_b,f.g1,f.g2,f.disc,f.tg,f.net_cash_b,f.shares_m,
           f.y+1,f.fcf_b*(1+case when f.y+1<=5 then f.g1 else f.g2 end)
    from f where f.y<10
  ),
  a as (
    select scenario,max(net_cash_b) net_cash_b,max(shares_m) shares_m,max(disc) disc,max(tg) tg,
           sum(fcf_b/power(1+disc,y)) pv_explicit,
           max(fcf_b) filter(where y=10) fcf10
    from f group by scenario
  ),
  fv as (
    select scenario,
      (pv_explicit+fcf10*(1+tg)/(disc-tg)/power(1+disc,10)+net_cash_b)*1000/shares_m val
    from a
  )
  select
    max(val) filter(where scenario='BEAR'),
    max(val) filter(where scenario='BASE'),
    max(val) filter(where scenario='BULL')
  into v_bear,v_base,v_bull
  from fv;

  v_pw := 0.25*v_bear+0.50*v_base+0.25*v_bull;

  if abs(v_bear-171.98535827)>0.0001
     or abs(v_base-232.65156828)>0.0001
     or abs(v_bull-325.56851356)>0.0001
     or abs(v_pw-240.71425210)>0.0001 then
    raise exception 'ACNSH-06 shadow values changed: %, %, %, %',v_bear,v_base,v_bull,v_pw;
  end if;

  if not exists (
    select 1 from fwios.valuation_runs
    where run_id='VAL-SUPA-ACN-ITSERV-20260905'
      and model_version_id='IT_SERVICES_FCF_COMPOUNDER_V1::1.0'
      and production_eligible=true
      and abs(probability_weighted_fv_per_share-233.0596473725)<0.0000001
  ) then
    raise exception 'ACNSH-07 production v1 valuation changed';
  end if;

  if exists (
    select 1 from fwios.valuation_runs
    where model_version_id='IT_SERVICES_FCF_COMPOUNDER_V1::2.0'
  ) then
    raise exception 'ACNSH-08 v2 valuation run exists before explicit creation step';
  end if;
end $$;

select 'FWIOS ACN CURRENT INPUTS + SHADOW V2: PASS (8/8, READ-ONLY)' result;
