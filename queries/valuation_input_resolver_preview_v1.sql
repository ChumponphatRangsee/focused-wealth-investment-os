-- FWIOS Valuation Input Resolver PREVIEW v1
-- ACN rollover pilot using existing Metric Observation v2.
-- Read-only: no schema/data/model/valuation writes.
--
-- Contract principle:
--   semantic metric identity is stable;
--   period identity and selection policy are separate.
--
-- This pilot intentionally uses generic identities that do not yet exist
-- (BOOK_TO_BILL, REVENUE_GROWTH_GUIDANCE_LC_MID) to prove fail-closed
-- behavior before a future controlled metric-definition migration.

with context as (
  select
    'ACN'::text ticker,
    fwios.resolve_instrument_id_v1('ACN','Stock',null,null) instrument_id,
    date '2026-10-26' as valuation_as_of,
    2026::int as closed_fiscal_year,
    date '2026-08-31' as closed_fiscal_period_end
),
spec(input_key,metric_code,period_type,selection_rule,required,min_fiscal_year,min_period_end) as (
  values
    ('fcf_guidance_low','FCF_GUIDANCE_LOW','GUIDANCE','NEXT_FY_GUIDANCE',true,2027,null::date),
    ('fcf_guidance_midpoint','FCF_GUIDANCE_MIDPOINT','GUIDANCE','NEXT_FY_GUIDANCE',true,2027,null::date),
    ('fcf_guidance_high','FCF_GUIDANCE_HIGH','GUIDANCE','NEXT_FY_GUIDANCE',true,2027,null::date),
    ('revenue_growth_guidance_lc_mid','REVENUE_GROWTH_GUIDANCE_LC_MID','GUIDANCE','NEXT_FY_GUIDANCE',true,2027,null::date),
    ('fcf_ltm','FREE_CASH_FLOW','LTM','LATEST_AT_OR_AFTER_CLOSED_PERIOD',true,null,date '2026-08-31'),
    ('net_cash','NET_CASH','INSTANT','LATEST_AT_OR_AFTER_CLOSED_PERIOD',true,null,date '2026-08-31'),
    ('shares_outstanding','SHARES_OUTSTANDING',null,'LATEST_AT_OR_AFTER_CLOSED_PERIOD',true,null,date '2026-08-31'),
    ('book_to_bill','BOOK_TO_BILL','QUARTER','LATEST_DIAGNOSTIC',false,null,date '2026-08-31'),
    ('operating_margin','OPERATING_MARGIN','QUARTER','LATEST_DIAGNOSTIC',false,null,date '2026-08-31'),
    ('gross_margin','GROSS_MARGIN','QUARTER','LATEST_DIAGNOSTIC',false,null,date '2026-08-31')
),
defs as (
  select s.*, d.metric_code is not null as metric_defined
  from spec s
  left join fwios.metric_definitions d
    on d.metric_code=s.metric_code
   and d.active=true
),
ranked as (
  select
    d.*,
    mo.observation_key,
    mo.value_numeric,
    mo.canonical_unit,
    mo.fiscal_year,
    mo.fiscal_quarter,
    mo.period_end,
    mo.as_of_date,
    mo.reported_at,
    mo.observation_layer,
    row_number() over (
      partition by d.input_key
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
  select
    r.*,
    case
      when not metric_defined then 'BLOCKED_METRIC_CODE_NOT_DEFINED'
      when observation_key is null then 'BLOCKED_NO_OBSERVATION'
      when min_fiscal_year is not null
       and coalesce(fiscal_year,-1) < min_fiscal_year
        then 'BLOCKED_WRONG_FISCAL_PERIOD'
      when min_period_end is not null
       and coalesce(period_end,as_of_date,date '0001-01-01') < min_period_end
        then 'BLOCKED_STALE_PERIOD'
      else 'PASS'
    end as input_status
  from ranked r
  where rn=1
)
select
  input_key,
  metric_code,
  selection_rule,
  required,
  input_status,
  observation_key,
  value_numeric,
  canonical_unit,
  fiscal_year,
  fiscal_quarter,
  period_end,
  as_of_date,
  case
    when input_status='PASS' then null
    when input_status='BLOCKED_METRIC_CODE_NOT_DEFINED'
      then 'Generic metric identity must be introduced before cutover.'
    when input_status='BLOCKED_NO_OBSERVATION'
      then 'No canonical observation satisfies this semantic metric.'
    when input_status='BLOCKED_WRONG_FISCAL_PERIOD'
      then 'Latest observation belongs to a closed/old fiscal year.'
    when input_status='BLOCKED_STALE_PERIOD'
      then 'Latest observation predates the latest closed fiscal period.'
  end as blocker_reason
from resolved
order by required desc,input_key;
