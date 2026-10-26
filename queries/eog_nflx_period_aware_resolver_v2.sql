-- EOG + NFLX period-aware resolver v2
-- Dated execution context: 2026-10-26
-- READ ONLY. Latest-primary-report floors are explicit so stale canonical data fails closed.

-- EOG: latest published primary financial period is Q2 2026 (2026-06-30).
with context as (
  select
    fwios.resolve_instrument_id_v1('EOG','Stock',null,null) instrument_id,
    date '2026-10-26' valuation_as_of,
    date '2026-06-30' latest_report_period_end,
    2025 latest_completed_fy
),
selectors as (
  select
    x->>'input_key' input_key,
    x->>'metric_code' metric_code,
    nullif(x->>'period_type','') period_type,
    x->>'period_rule' period_rule,
    (x->>'required')::boolean required
  from fwios.valuation_model_versions v
  cross join lateral jsonb_array_elements(v.input_contract->'input_selectors') x
  where v.version_id='E&P_NORMALIZED_FCF_YIELD_V1::2.0'
),
ranked as (
  select s.*,o.observation_key,o.value_numeric,o.canonical_unit,o.observation_layer,
         o.period_type observation_period_type,o.fiscal_year,o.fiscal_quarter,
         o.period_end,o.as_of_date,o.reported_at,
         row_number() over(
           partition by s.input_key
           order by coalesce(o.period_end,o.as_of_date) desc nulls last,
                    o.reported_at desc nulls last,
                    case o.observation_layer
                      when 'NORMALIZED' then 1
                      when 'DERIVED' then 2
                      when 'REPORTED' then 3
                      else 9
                    end,
                    o.created_at desc
         ) rn
  from selectors s cross join context c
  left join fwios.metric_observations o
    on o.instrument_id=c.instrument_id
   and o.metric_code=s.metric_code
   and (s.period_type is null or o.period_type=s.period_type)
   and o.provenance_status='PASS'
   and o.quality_gate='PASS'
   and o.value_numeric is not null
   and coalesce(o.reported_at,o.effective_at,o.created_at)
       <= c.valuation_as_of::timestamptz + interval '1 day'
),
resolved as (
  select r.*,
    case
      when observation_key is null then 'BLOCKED_NO_OBSERVATION'
      when period_rule='LATEST_COMPLETED_FISCAL_YEAR'
       and fiscal_year<>(select latest_completed_fy from context)
        then 'BLOCKED_WRONG_FISCAL_PERIOD'
      when period_rule in ('LATEST_REPORTED_QUARTER','LATEST_REPORTED_LTM')
       and coalesce(period_end,as_of_date,date '0001-01-01')
           <(select latest_report_period_end from context)
        then 'BLOCKED_STALE_PERIOD'
      when period_rule='LATEST_FILING_SHARE_COUNT'
       and coalesce(period_end,as_of_date,date '0001-01-01')
           <(select latest_report_period_end from context)
        then 'BLOCKED_STALE_SHARE_COUNT'
      else 'PASS'
    end input_status
  from ranked r where rn=1
)
select
  'EOG' ticker,input_key,metric_code,period_rule,required,input_status,
  observation_key,value_numeric,canonical_unit,observation_period_type,
  fiscal_year,fiscal_quarter,period_end,as_of_date,reported_at
from resolved
order by input_key;

-- NFLX: latest primary report is Q3 2026, filed/released 2026-10-20.
with context as (
  select
    fwios.resolve_instrument_id_v1('NFLX','Stock',null,null) instrument_id,
    date '2026-10-26' valuation_as_of,
    date '2026-09-30' latest_report_period_end,
    timestamptz '2026-10-20 16:01:55+00' latest_reported_at,
    2026 current_fy
),
selectors as (
  select
    x->>'input_key' input_key,
    x->>'metric_code' metric_code,
    nullif(x->>'period_type','') period_type,
    x->>'period_rule' period_rule,
    (x->>'required')::boolean required
  from fwios.valuation_model_versions v
  cross join lateral jsonb_array_elements(v.input_contract->'input_selectors') x
  where v.version_id='STREAMING_FCF_DCF_V1::2.0'
),
ranked as (
  select s.*,o.observation_key,o.value_numeric,o.canonical_unit,o.observation_layer,
         o.period_type observation_period_type,o.fiscal_year,o.fiscal_quarter,
         o.period_end,o.as_of_date,o.reported_at,
         row_number() over(
           partition by s.input_key
           order by coalesce(o.period_end,o.as_of_date) desc nulls last,
                    o.reported_at desc nulls last,
                    case o.observation_layer
                      when 'NORMALIZED' then 1
                      when 'GUIDANCE' then 2
                      when 'DERIVED' then 3
                      when 'REPORTED' then 4
                      else 9
                    end,
                    o.created_at desc
         ) rn
  from selectors s cross join context c
  left join fwios.metric_observations o
    on o.instrument_id=c.instrument_id
   and o.metric_code=s.metric_code
   and (s.period_type is null or o.period_type=s.period_type)
   and o.provenance_status='PASS'
   and o.quality_gate='PASS'
   and o.value_numeric is not null
   and coalesce(o.reported_at,o.effective_at,o.created_at)
       <= c.valuation_as_of::timestamptz + interval '1 day'
),
resolved as (
  select r.*,
    case
      when observation_key is null then 'BLOCKED_NO_OBSERVATION'
      when period_rule='CURRENT_FISCAL_YEAR_GUIDANCE'
       and (
         fiscal_year<>(select current_fy from context)
         or reported_at<(select latest_reported_at from context)
       )
        then 'BLOCKED_STALE_OR_WRONG_GUIDANCE'
      when period_rule='LATEST_REPORTED_QUARTER'
       and coalesce(period_end,as_of_date,date '0001-01-01')
           <(select latest_report_period_end from context)
        then 'BLOCKED_STALE_PERIOD'
      else 'PASS'
    end input_status
  from ranked r where rn=1
)
select
  'NFLX' ticker,input_key,metric_code,period_rule,required,input_status,
  observation_key,value_numeric,canonical_unit,observation_period_type,
  fiscal_year,fiscal_quarter,period_end,as_of_date,reported_at
from resolved
order by required desc,input_key;
