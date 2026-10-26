-- FWIOS Valuation Period Semantics v2 regression
-- Verifies version authority, semantic aliases, ACN v2 contract safety and fail-closed resolution.

do $$
declare
  v_bad int;
  v_prod int;
  v_maps int;
  v_alias int;
  v_required_blocked int;
  v_required_pass int;
begin
  if (select count(*) from fwios.valuation_models where production_status='IMPLEMENTED') <> 20 then
    raise exception 'VALSEM-01 implemented model count changed';
  end if;

  select count(*) into v_prod
  from fwios.valuation_model_versions
  where status='PRODUCTION';
  if v_prod <> 20 then
    raise exception 'VALSEM-02 expected 20 production model versions, got %',v_prod;
  end if;

  select count(*) into v_bad
  from (
    select m.model_id
    from fwios.valuation_models m
    left join fwios.valuation_model_versions v on v.model_id=m.model_id
    where m.production_status='IMPLEMENTED'
    group by m.model_id,m.model_version
    having count(*) filter(where v.status='PRODUCTION') <> 1
       or not bool_or(v.status='PRODUCTION' and v.version_label=m.model_version)
  ) x;
  if v_bad <> 0 then
    raise exception 'VALSEM-03 production version authority ambiguous for % models',v_bad;
  end if;

  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='SEMIS_MIDCYCLE_DCF_V1::1.0' and status='RETIRED'
  ) or not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='SEMIS_MIDCYCLE_DCF_V1::1.1' and status='PRODUCTION'
  ) then
    raise exception 'VALSEM-04 SEMIS authority incorrect';
  end if;

  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='SAAS_EV_FCF_REVERSE_DCF_V1::1.1-EXPERIMENTAL' and status='RETIRED'
  ) or not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='SAAS_EV_FCF_REVERSE_DCF_V1::1.1' and status='PRODUCTION'
  ) then
    raise exception 'VALSEM-05 SAAS authority incorrect';
  end if;

  if not exists (
    select 1
    from fwios.valuation_model_versions oldv
    join fwios.valuation_model_versions newv
      on newv.version_id='SAAS_EV_FCF_REVERSE_DCF_V1::1.1'
    where oldv.version_id='SAAS_EV_FCF_REVERSE_DCF_V1::1.1-EXPERIMENTAL'
      and oldv.kernel_family=newv.kernel_family
      and oldv.input_contract=newv.input_contract
      and oldv.model_policy=newv.model_policy
      and oldv.assumptions=newv.assumptions
  ) then
    raise exception 'VALSEM-06 SAAS canonical version is not an exact policy clone';
  end if;

  if (select count(*) from fwios.metric_definitions
      where metric_code in ('BOOK_TO_BILL','REVENUE_GROWTH_GUIDANCE_LC_MID','FREE_CASH_FLOW_GUIDANCE')
        and active) <> 3 then
    raise exception 'VALSEM-07 generic metric definitions incomplete';
  end if;

  select count(*) into v_maps
  from fwios.metric_legacy_mappings
  where mapping_version='METRIC_PERIOD_AWARE_V1'
    and legacy_metric_id in (
      'book_to_bill_q3',
      'fy2026_revenue_growth_guidance_lc_mid',
      'fcf_fy2025',
      'fcf_guidance_fy2026'
    );
  if v_maps <> 8 then
    raise exception 'VALSEM-08 legacy mappings expected 8, got %',v_maps;
  end if;

  select count(*) into v_alias
  from fwios.metric_observations
  where observation_key in (
    'SEMANTIC_V1:NM:ACN:book_to_bill_q3:NORM_V1-IT-SERVICES',
    'SEMANTIC_V1:NM:ACN:fy2026_revenue_growth_guidance_lc_mid:NORM_V1-IT-SERVICES',
    'SEMANTIC_V1:NM:EOG:fcf_fy2025:NORM_V1',
    'SEMANTIC_V1:NM:NFLX:fcf_guidance_fy2026:NORM_V1-STREAMING'
  );
  if v_alias <> 4 then
    raise exception 'VALSEM-09 semantic aliases expected 4, got %',v_alias;
  end if;

  if not exists (
    select 1 from fwios.metric_observations
    where observation_key='SEMANTIC_V1:NM:EOG:fcf_fy2025:NORM_V1'
      and metric_code='FREE_CASH_FLOW'
      and period_type='YEAR'
      and fiscal_year=2025
  ) or not exists (
    select 1 from fwios.metric_observations
    where observation_key='SEMANTIC_V1:NM:NFLX:fcf_guidance_fy2026:NORM_V1-STREAMING'
      and metric_code='FREE_CASH_FLOW_GUIDANCE'
      and period_type='GUIDANCE'
      and observation_layer='GUIDANCE'
      and fiscal_year=2026
  ) then
    raise exception 'VALSEM-10 EOG/NFLX semantic aliases invalid';
  end if;

  if not exists (
    select 1 from fwios.valuation_model_versions
    where version_id='IT_SERVICES_FCF_COMPOUNDER_V1::2.0'
      and status='EXPERIMENTAL'
      and input_contract->>'production_read_cutover'='false'
      and assumptions::text not like '%starting_fcf_b%'
  ) then
    raise exception 'VALSEM-11 ACN v2 experimental contract invalid';
  end if;

  with ctx as (
    select
      fwios.resolve_instrument_id_v1('ACN','Stock',null,null) instrument_id,
      date '2026-10-26' valuation_as_of,
      2026 closed_fy,
      date '2026-08-31' closed_period_end
  ),
  selectors as (
    select
      x->>'input_key' input_key,
      x->>'metric_code' metric_code,
      nullif(x->>'period_type','') period_type,
      x->>'period_rule' period_rule,
      coalesce((x->>'required')::boolean,false) required
    from fwios.valuation_model_versions v
    cross join lateral jsonb_array_elements(v.input_contract->'input_selectors') x
    where v.version_id='IT_SERVICES_FCF_COMPOUNDER_V1::2.0'
  ),
  ranked as (
    select
      s.*,
      mo.observation_key,
      mo.fiscal_year,
      mo.period_end,
      mo.as_of_date,
      row_number() over(
        partition by s.input_key
        order by
          coalesce(mo.period_end,mo.as_of_date) desc nulls last,
          mo.reported_at desc nulls last,
          case mo.observation_layer
            when 'NORMALIZED' then 1
            when 'DERIVED' then 2
            when 'REPORTED' then 3
            when 'GUIDANCE' then 4
            else 9
          end,
          mo.created_at desc
      ) rn
    from selectors s
    cross join ctx c
    left join fwios.metric_observations mo
      on mo.instrument_id=c.instrument_id
     and mo.metric_code=s.metric_code
     and (s.period_type is null or mo.period_type=s.period_type)
     and mo.provenance_status='PASS'
     and mo.value_numeric is not null
     and coalesce(mo.reported_at,mo.effective_at,mo.created_at)
         <= c.valuation_as_of::timestamptz + interval '1 day'
  ),
  resolved as (
    select
      r.*,
      case
        when observation_key is null then 'BLOCKED_NO_OBSERVATION'
        when period_rule='NEXT_FISCAL_YEAR_GUIDANCE'
         and coalesce(fiscal_year,-1) <> 2027
          then 'BLOCKED_WRONG_FISCAL_PERIOD'
        when period_rule in (
          'LATEST_AT_OR_AFTER_CLOSED_FISCAL_PERIOD',
          'LATEST_PERIOD_END_SHARE_COUNT_AT_OR_AFTER_CLOSED_FISCAL_PERIOD'
        )
         and coalesce(period_end,as_of_date,date '0001-01-01') < date '2026-08-31'
          then 'BLOCKED_STALE_PERIOD'
        else 'PASS'
      end status
    from ranked r
    where rn=1
  )
  select
    count(*) filter(where required and status<>'PASS'),
    count(*) filter(where required and status='PASS')
  into v_required_blocked,v_required_pass
  from resolved;

  if v_required_blocked <> 7 or v_required_pass <> 0 then
    raise exception 'VALSEM-12 ACN v2 resolver must remain fail-closed: blocked %, pass %',
      v_required_blocked,v_required_pass;
  end if;
end $$;

select 'FWIOS VALUATION PERIOD SEMANTICS V2: PASS (12/12)' as result;
