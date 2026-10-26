-- FWIOS Valuation Input Resolver v1 regression
-- Read-only. No writes or valuation cutover.

do $$
declare
  v_impl int;
  v_period_red int;
  v_red_ids text[];
  v_gov_bad int;
  v_gov_ids text[];
  v_required_blocked int;
  v_required_pass int;
  v_before_obs bigint;
  v_after_obs bigint;
begin
  select count(*) into v_before_obs from fwios.metric_observations;

  select count(*) into v_impl
  from fwios.valuation_models
  where production_status='IMPLEMENTED';
  if v_impl <> 20 then
    raise exception 'VALRES-01 implemented model count changed: %', v_impl;
  end if;

  with flagged as (
    select m.model_id
    from fwios.valuation_models m
    where m.production_status='IMPLEMENTED'
      and exists (
        select 1
        from unnest(coalesce(m.required_metric_ids,'{}'::text[])) x(metric_id)
        where metric_id ~* '(fy[0-9]{2,4}|(^|_)q[1-4]($|_))'
      )
  )
  select count(*),array_agg(model_id order by model_id)
    into v_period_red,v_red_ids
  from flagged;

  if v_period_red <> 3
     or v_red_ids <> array[
       'E&P_NORMALIZED_FCF_YIELD_V1',
       'IT_SERVICES_FCF_COMPOUNDER_V1',
       'STREAMING_FCF_DCF_V1'
     ]::text[] then
    raise exception 'VALRES-02 period-identity RED set changed: %',v_red_ids;
  end if;

  with g as (
    select m.model_id
    from fwios.valuation_models m
    left join fwios.valuation_model_versions v on v.model_id=m.model_id
    where m.production_status='IMPLEMENTED'
    group by m.model_id,m.model_version
    having count(*) filter (where v.status='PRODUCTION') <> 1
       or not bool_or(v.status='PRODUCTION' and v.version_label=m.model_version)
  )
  select count(*),array_agg(model_id order by model_id)
    into v_gov_bad,v_gov_ids
  from g;

  if v_gov_bad <> 2
     or v_gov_ids <> array[
       'SAAS_EV_FCF_REVERSE_DCF_V1',
       'SEMIS_MIDCYCLE_DCF_V1'
     ]::text[] then
    raise exception 'VALRES-03 version-governance anomaly set changed: %',v_gov_ids;
  end if;

  if not exists (
    select 1 from fwios.metric_legacy_mappings
    where lower(legacy_metric_id)='gross_margin_q3'
      and metric_code='GROSS_MARGIN'
  ) or not exists (
    select 1 from fwios.metric_legacy_mappings
    where lower(legacy_metric_id)='operating_margin_q3'
      and metric_code='OPERATING_MARGIN'
  ) then
    raise exception 'VALRES-04 generic margin mappings missing';
  end if;

  if exists (
    select 1 from fwios.metric_definitions
    where metric_code in ('BOOK_TO_BILL','REVENUE_GROWTH_GUIDANCE_LC_MID')
  ) then
    raise exception 'VALRES-05 generic identity fixture changed; review resolver contract before cutover';
  end if;

  with context as (
    select fwios.resolve_instrument_id_v1('ACN','Stock',null,null) instrument_id,
           date '2026-10-26' valuation_as_of
  ),
  spec(input_key,metric_code,period_type,required,min_fiscal_year,min_period_end) as (
    values
      ('fcf_guidance_low','FCF_GUIDANCE_LOW','GUIDANCE',true,2027,null::date),
      ('fcf_guidance_midpoint','FCF_GUIDANCE_MIDPOINT','GUIDANCE',true,2027,null::date),
      ('fcf_guidance_high','FCF_GUIDANCE_HIGH','GUIDANCE',true,2027,null::date),
      ('revenue_growth_guidance_lc_mid','REVENUE_GROWTH_GUIDANCE_LC_MID','GUIDANCE',true,2027,null::date),
      ('fcf_ltm','FREE_CASH_FLOW','LTM',true,null,date '2026-08-31'),
      ('net_cash','NET_CASH','INSTANT',true,null,date '2026-08-31'),
      ('shares_outstanding','SHARES_OUTSTANDING',null,true,null,date '2026-08-31')
  ),
  defs as (
    select s.*,d.metric_code is not null metric_defined
    from spec s
    left join fwios.metric_definitions d
      on d.metric_code=s.metric_code and d.active
  ),
  ranked as (
    select
      d.*,
      mo.observation_key,
      mo.fiscal_year,
      mo.period_end,
      mo.as_of_date,
      row_number() over (
        partition by d.input_key
        order by coalesce(mo.period_end,mo.as_of_date) desc nulls last,
                 mo.reported_at desc nulls last,
                 mo.created_at desc
      ) rn
    from defs d
    cross join context c
    left join fwios.metric_observations mo
      on mo.instrument_id=c.instrument_id
     and mo.metric_code=d.metric_code
     and (d.period_type is null or mo.period_type=d.period_type)
     and mo.provenance_status='PASS'
     and mo.value_numeric is not null
     and coalesce(mo.reported_at,mo.effective_at,mo.created_at)
         <= c.valuation_as_of::timestamptz + interval '1 day'
  ),
  resolved as (
    select *,
      case
        when not metric_defined then 'BLOCKED_METRIC_CODE_NOT_DEFINED'
        when observation_key is null then 'BLOCKED_NO_OBSERVATION'
        when min_fiscal_year is not null
         and coalesce(fiscal_year,-1)<min_fiscal_year
          then 'BLOCKED_WRONG_FISCAL_PERIOD'
        when min_period_end is not null
         and coalesce(period_end,as_of_date,date '0001-01-01')<min_period_end
          then 'BLOCKED_STALE_PERIOD'
        else 'PASS'
      end status
    from ranked
    where rn=1
  )
  select
    count(*) filter(where required and status<>'PASS'),
    count(*) filter(where required and status='PASS')
  into v_required_blocked,v_required_pass
  from resolved;

  if v_required_blocked <> 7 or v_required_pass <> 0 then
    raise exception 'VALRES-06 ACN rollover resolver no longer fails closed: blocked %, pass %',
      v_required_blocked,v_required_pass;
  end if;

  select count(*) into v_after_obs from fwios.metric_observations;
  if v_after_obs <> v_before_obs then
    raise exception 'VALRES-07 read-only audit/resolver mutated metric observations';
  end if;
end $$;

select 'FWIOS VALUATION INPUT RESOLVER V1: PASS (7/7, READ-ONLY)' as result;
