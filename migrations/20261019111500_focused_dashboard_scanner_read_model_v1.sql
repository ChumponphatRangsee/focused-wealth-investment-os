-- Focused Wealth Dashboard scanner/read-model separation.
-- Additive only: no portfolio/accounting objects are dropped or mutated.

create or replace view fwios.v_scanner_current_v1
with (security_invoker = true)
as
with universe as (
  select
    dc.asset_symbol as ticker,
    coalesce(nullif(c.company_name,''), nullif(tr.company_name,''), dc.asset_symbol) as company,
    coalesce(nullif(c.sector,''), nullif(tr.sector,''), 'Unclassified') as sector,
    dc.close_price::numeric as latest_price,
    dc.session_date as price_as_of,
    dc.primary_provider as price_provider,
    dc.verification_status as price_verification_status,
    dc.provenance_status as price_provenance_status,
    dc.retrieved_at as price_retrieved_at
  from fwios.v_market_daily_close_latest dc
  join fwios.v_instrument_identity_current i
    on i.asset_symbol = dc.asset_symbol
   and i.asset_class = 'Stock'
   and i.lifecycle_status = 'ACTIVE'
  left join fwios.companies c
    on c.ticker = dc.asset_symbol
   and c.active = true
  left join fwios.thesis_registry tr
    on tr.ticker = dc.asset_symbol
   and tr.active = true
),
features as (
  select
    u.*,
    rc.business_thesis_score,
    rc.quality_score,
    rc.downside_risk_score,
    rc.updated_at as research_updated_at,
    th.thesis_score,
    vm.bear_fv,
    vm.base_fv,
    vm.high_fv,
    vm.fair_value,
    case
      when u.latest_price > 0 and vm.fair_value is not null
        then vm.fair_value / u.latest_price - 1
      else null
    end as upside_pct
  from universe u
  left join fwios.research_candidates rc
    on rc.ticker = u.ticker
  left join fwios.v_thesis_tracking_current th
    on th.ticker = u.ticker
  left join fwios.v_dashboard_valuation_map vm
    on vm.ticker = u.ticker
),
scored as (
  select
    f.*,
    case
      when f.business_thesis_score is not null
       and f.quality_score is not null
       and f.downside_risk_score is not null
       and f.upside_pct is not null
      then fwios.opportunity_quality_score_v2(
        f.business_thesis_score,
        f.upside_pct,
        f.quality_score,
        f.downside_risk_score
      )
      else null
    end as scanner_score,
    case
      when f.latest_price is null or f.price_provenance_status <> 'PASS' then 'PRICE BLOCKED'
      when f.fair_value is null then 'NO VALUATION'
      when f.latest_price <= f.bear_fv then 'STRONG UNDERVALUED'
      when f.latest_price <= f.base_fv then 'UNDERVALUED'
      when f.latest_price <= f.fair_value then 'FAIR VALUE'
      when f.latest_price <= f.high_fv then 'EXPENSIVE'
      else 'VERY EXPENSIVE'
    end as valuation_status,
    case
      when f.latest_price is null or f.price_provenance_status <> 'PASS' then 'PRICE_BLOCKED'
      when f.fair_value is null then 'PRICE_ONLY'
      when f.business_thesis_score is null
        or f.quality_score is null
        or f.downside_risk_score is null then 'VALUATION_ONLY'
      else 'SCORED'
    end as scan_status,
    greatest(f.price_retrieved_at, f.research_updated_at) as refreshed_at
  from features f
)
select
  case
    when s.scanner_score is not null
      then row_number() over(order by s.scanner_score desc nulls last, s.ticker)::integer
    else null
  end as scan_rank,
  s.ticker,
  s.company,
  s.sector,
  s.scanner_score,
  s.quality_score,
  s.latest_price,
  s.price_as_of,
  s.bear_fv,
  s.base_fv,
  s.high_fv,
  s.fair_value as probability_weighted_fv,
  s.upside_pct,
  s.valuation_status,
  s.thesis_score,
  s.scan_status,
  s.refreshed_at,
  s.price_verification_status,
  s.price_provenance_status
from scored s
order by scan_rank nulls last, s.upside_pct desc nulls last, s.ticker;

comment on view fwios.v_scanner_current_v1 is
  'Portfolio-independent Focused Wealth scanner read model. Uses canonical stock daily close, valuation, research quality and thesis signals; excludes holdings, account state, portfolio fit/scenario and execution state.';
