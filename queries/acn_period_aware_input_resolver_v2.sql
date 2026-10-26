-- ACN period-aware valuation input resolver v2
-- Reads the EXPERIMENTAL 2.0 model contract and canonical Metric Observation v2.
-- Read-only. No valuation run or production cutover.

with context as (
  select
    'ACN'::text ticker,
    fwios.resolve_instrument_id_v1('ACN','Stock',null,null) instrument_id,
    date '2026-10-26' valuation_as_of,
    2026::int closed_fiscal_year,
    date '2026-08-31' closed_fiscal_period_end
),
contract as (
  select version_id,input_contract
  from fwios.valuation_model_versions
  where version_id='IT_SERVICES_FCF_COMPOUNDER_V1::2.0'
    and status='EXPERIMENTAL'
),
selectors as (
  select
    c.version_id,
    x->>'input_key' input_key,
    x->>'metric_code' metric_code,
    nullif(x->>'period_type','') period_type,
    x->>'period_rule' period_rule,
    coalesce((x->>'required')::boolean,false) required
  from contract c
  cross join lateral jsonb_array_elements(c.input_contract->'input_selectors') x
),
ranked as (
  select
    s.*,
    mo.observation_key,
    mo.value_numeric,
    mo.canonical_unit,
    mo.observation_layer,
    mo.fiscal_year,
    mo.fiscal_quarter,
    mo.period_end,
    mo.as_of_date,
    mo.reported_at,
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
  cross join context c
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
       and coalesce(fiscal_year,-1) <> (select closed_fiscal_year+1 from context)
        then 'BLOCKED_WRONG_FISCAL_PERIOD'
      when period_rule in (
        'LATEST_AT_OR_AFTER_CLOSED_FISCAL_PERIOD',
        'LATEST_PERIOD_END_SHARE_COUNT_AT_OR_AFTER_CLOSED_FISCAL_PERIOD'
      )
       and coalesce(period_end,as_of_date,date '0001-01-01')
           < (select closed_fiscal_period_end from context)
        then 'BLOCKED_STALE_PERIOD'
      else 'PASS'
    end input_status
  from ranked r
  where rn=1
),
summary as (
  select
    count(*) filter(where required) required_count,
    count(*) filter(where required and input_status='PASS') required_pass_count,
    count(*) filter(where required and input_status<>'PASS') required_blocked_count
  from resolved
)
select
  r.version_id,
  case when s.required_blocked_count=0 then 'PASS' else 'BLOCKED' end overall_status,
  s.required_count,
  s.required_pass_count,
  s.required_blocked_count,
  r.input_key,
  r.metric_code,
  r.period_rule,
  r.required,
  r.input_status,
  r.observation_key,
  r.value_numeric,
  r.canonical_unit,
  r.observation_layer,
  r.fiscal_year,
  r.fiscal_quarter,
  r.period_end,
  r.as_of_date
from resolved r
cross join summary s
order by r.required desc,r.input_key;
