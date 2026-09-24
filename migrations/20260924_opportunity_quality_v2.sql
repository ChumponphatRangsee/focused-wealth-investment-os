
-- Opportunity Quality V2 + post-selection Portfolio Scenario Fit V2
-- Discovery = Thesis + Expected Return + Resilience. Portfolio Fit has zero discovery weight.
-- Human execution only; no automatic trading.

insert into fwios.policy_registry(policy_key,policy_domain,policy_name,purpose,backing_object,lifecycle_status)
values
('OPPORTUNITY_QUALITY_V2','CAPITAL_ALLOCATION','Opportunity Quality V2',
 'Rank stock opportunities independently of current portfolio fit. Portfolio compatibility is evaluated only after selection through a directional scenario review.',
 'fwios.v_opportunity_quality_current','ACTIVE'),
('PORTFOLIO_SCENARIO_FIT_V2','PORTFOLIO_RISK','Portfolio Scenario Fit V2',
 'Evaluate portfolio compatibility only after a candidate is selected, using directional before/after guardrails rather than suppressing discovery.',
 'fwios.preview_candidate_portfolio_fit_v2','ACTIVE')
on conflict(policy_key) do update set
 policy_domain=excluded.policy_domain,policy_name=excluded.policy_name,purpose=excluded.purpose,
 backing_object=excluded.backing_object,lifecycle_status='ACTIVE',updated_at=now();

insert into fwios.policy_versions(policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference,effective_at)
values
('POL-OPPORTUNITY-QUALITY-V2','OPPORTUNITY_QUALITY_V2','2.0','ACTIVE',true,
 jsonb_build_object('business_thesis_weight',0.35,'expected_return_weight',0.40,'resilience_weight',0.25,
 'resilience_formula','50% quality_score + 50% downside_risk_score','portfolio_fit_weight',0,
 'portfolio_fit_discovery_gate',false,'mispricing_is_state_not_weight',true,
 'full_thesis_required_before_portfolio_scenario',true,'portfolio_scenario_required_before_buy_review',true,
 'human_execution_only',true),
 'FWIOS Opportunity Quality V2',now()),
('POL-PORTFOLIO-SCENARIO-FIT-V2','PORTFOLIO_SCENARIO_FIT_V2','2.0','ACTIVE',true,
 jsonb_build_object('candidate_weight_block_threshold',0.30,'max_stock_worsening_review_delta',0.02,
 'sector_review_threshold',0.40,'sector_worsening_review_delta',0.02,'crypto_target_mid',0.175,
 'crypto_target_band',0.025,'crypto_worsening_review_delta',0.01,'preferred_positions_min',5,
 'preferred_positions_max',8,'preexisting_deviation_is_not_candidate_failure',true,
 'portfolio_fit_enters_opportunity_score',false,'human_execution_only',true),
 'FWIOS Portfolio Scenario Fit V2',now())
on conflict(policy_version_id) do update set lifecycle_status='ACTIVE',deterministic_scoring=true,
 config=excluded.config,source_reference=excluded.source_reference,
 effective_at=coalesce(fwios.policy_versions.effective_at,excluded.effective_at);

create table if not exists fwios.opportunity_quality_snapshots (
 opportunity_snapshot_id uuid primary key default gen_random_uuid(),
 ticker text not null, as_of_date date not null,
 policy_version_id text not null references fwios.policy_versions(policy_version_id),
 business_thesis_score numeric, expected_return_signal_score numeric, quality_score numeric,
 downside_risk_score numeric, resilience_score numeric, opportunity_score numeric,
 probability_weighted_upside numeric, base_upside numeric, price_gate text, mispricing_gate text,
 mispricing_class text, score_gate text not null, opportunity_state text not null,
 full_thesis_gate text not null, prebuy_research_gate text not null,
 portfolio_scenario_gate text not null default 'NOT_RUN', source_reference text,
 payload jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), unique(ticker,as_of_date,policy_version_id)
);
alter table fwios.opportunity_quality_snapshots enable row level security;
revoke all on fwios.opportunity_quality_snapshots from public,anon,authenticated;
grant select,insert,update,delete on fwios.opportunity_quality_snapshots to service_role;
create index if not exists opportunity_quality_snapshots_rank_idx
 on fwios.opportunity_quality_snapshots(as_of_date desc,opportunity_score desc nulls last,ticker);

create table if not exists fwios.candidate_portfolio_scenario_reviews_v2 (
 review_id uuid primary key default gen_random_uuid(), ticker text not null, portfolio_batch_id text not null,
 add_amount_thb numeric not null check(add_amount_thb>0), trim_symbols text[] not null default '{}'::text[],
 trim_amounts_thb numeric[] not null default '{}'::numeric[], scenario_fit_score numeric not null,
 scenario_fit_gate text not null, candidate_weight_before numeric, candidate_weight_after numeric,
 max_stock_weight_before numeric, max_stock_weight_after numeric, candidate_sector_weight_before numeric,
 candidate_sector_weight_after numeric, crypto_weight_before numeric, crypto_weight_after numeric,
 unique_assets_before integer, unique_assets_after integer, metrics jsonb not null default '{}'::jsonb,
 source_reference text, created_at timestamptz not null default now()
);
alter table fwios.candidate_portfolio_scenario_reviews_v2 enable row level security;
revoke all on fwios.candidate_portfolio_scenario_reviews_v2 from public,anon,authenticated;
grant select,insert,update,delete on fwios.candidate_portfolio_scenario_reviews_v2 to service_role;
create index if not exists candidate_portfolio_scenario_reviews_v2_latest_idx
 on fwios.candidate_portfolio_scenario_reviews_v2(ticker,created_at desc);


CREATE OR REPLACE FUNCTION fwios.opportunity_quality_score_v2(p_business_thesis numeric, p_probability_weighted_upside numeric, p_quality numeric, p_downside numeric)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
select case
  when p_business_thesis is null or p_probability_weighted_upside is null
    or p_quality is null or p_downside is null then null
  else round(
    0.35*p_business_thesis
    + 0.40*fwios.continuous_upside_score_v1(p_probability_weighted_upside)
    + 0.25*((p_quality+p_downside)/2.0),
    4
  )
end
$function$
;
revoke all on function fwios.opportunity_quality_score_v2(numeric,numeric,numeric,numeric) from public,anon,authenticated;
grant execute on function fwios.opportunity_quality_score_v2(numeric,numeric,numeric,numeric) to service_role;

CREATE OR REPLACE FUNCTION fwios.refresh_opportunity_quality_v2(p_as_of_date date DEFAULT CURRENT_DATE, p_source text DEFAULT 'SYSTEM'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_rows int:=0;
begin
  insert into fwios.opportunity_quality_snapshots(
    ticker,as_of_date,policy_version_id,business_thesis_score,
    expected_return_signal_score,quality_score,downside_risk_score,resilience_score,
    opportunity_score,probability_weighted_upside,base_upside,price_gate,
    mispricing_gate,mispricing_class,score_gate,opportunity_state,
    full_thesis_gate,prebuy_research_gate,portfolio_scenario_gate,
    source_reference,payload,updated_at
  )
  select
    rc.ticker,
    p_as_of_date,
    'POL-OPPORTUNITY-QUALITY-V2',
    rc.business_thesis_score,
    case when mp.probability_weighted_upside is not null
      then fwios.continuous_upside_score_v1(mp.probability_weighted_upside)
      else null end,
    rc.quality_score,
    rc.downside_risk_score,
    case when rc.quality_score is not null and rc.downside_risk_score is not null
      then round((rc.quality_score+rc.downside_risk_score)/2.0,4) else null end,
    fwios.opportunity_quality_score_v2(
      rc.business_thesis_score,mp.probability_weighted_upside,rc.quality_score,rc.downside_risk_score
    ),
    mp.probability_weighted_upside,
    mp.base_upside,
    coalesce(mp.effective_price_gate,'MISSING'),
    coalesce(mp.mispricing_gate,rc.mispricing_gate,'MISSING'),
    coalesce(mp.mispricing_class,rc.mispricing_class),
    case
      when rc.business_thesis_score is null or rc.quality_score is null or rc.downside_risk_score is null
        then 'BLOCKED - CORE RESEARCH INPUT'
      when mp.probability_weighted_upside is null
        then 'BLOCKED - CURRENT VALUATION UPSIDE'
      when rc.valuation_gate<>'PASS' then 'BLOCKED - VALUATION'
      when rc.risk_gate<>'PASS' then 'BLOCKED - RISK'
      else 'PASS'
    end,
    case
      when mp.probability_weighted_upside is null then 'VALUATION_REQUIRED'
      when coalesce(mp.effective_price_gate,'MISSING')<>'PASS' then 'PRICE_VERIFY'
      when mp.mispricing_gate='PASS' then 'MISPRICED_CANDIDATE'
      when mp.mispricing_gate='FAIL - INSUFFICIENT MISPRICING' then 'VALUE_WAIT'
      else 'RESEARCH'
    end,
    case
      when tr.baseline_status='COMPLETE' and tr.baseline_completeness=1 then 'PASS'
      else 'BLOCKED - FULL THESIS REQUIRED'
    end,
    case
      when tr.baseline_status is distinct from 'COMPLETE' or coalesce(tr.baseline_completeness,0)<1
        then 'BLOCKED - FULL THESIS REQUIRED'
      when th.health_status in ('BROKEN','WEAKENING')
        then 'BLOCKED - THESIS HEALTH'
      when coalesce(mp.effective_price_gate,'MISSING')<>'PASS'
        then 'BLOCKED - PRICE VERIFY'
      when mp.mispricing_gate<>'PASS'
        then 'BLOCKED - MISPRICING'
      when rev.ticker is null then 'BLOCKED - REVISION EVIDENCE'
      when rev.revision_gate<>'PASS' then 'BLOCKED - REVISION'
      when ch.ticker is null then 'BLOCKED - CHASE EVIDENCE'
      when ch.chase_gate<>'PASS' then 'BLOCKED - CHASE'
      when q.ticker is null then 'BLOCKED - QUALITY HARDENING'
      when q.overall_gate<>'PASS' then 'BLOCKED - QUALITY HARDENING'
      else 'PASS - READY FOR PORTFOLIO SCENARIO'
    end,
    'NOT_RUN',
    p_source,
    jsonb_build_object(
      'portfolio_fit_in_opportunity_score',false,
      'portfolio_fit_discovery_gate',false,
      'business_thesis_weight',0.35,
      'expected_return_weight',0.40,
      'resilience_weight',0.25
    ),
    now()
  from fwios.research_candidates rc
  left join fwios.v_valuation_mispricing_current mp on mp.ticker=rc.ticker
  left join fwios.thesis_registry tr on tr.ticker=rc.ticker
  left join fwios.v_thesis_tracking_current th on th.ticker=rc.ticker
  left join fwios.v_candidate_revision_current rev on rev.ticker=rc.ticker
  left join fwios.v_candidate_chase_current ch on ch.ticker=rc.ticker
  left join fwios.v_candidate_quality_hardening_current q on q.ticker=rc.ticker
  on conflict(ticker,as_of_date,policy_version_id) do update set
    business_thesis_score=excluded.business_thesis_score,
    expected_return_signal_score=excluded.expected_return_signal_score,
    quality_score=excluded.quality_score,
    downside_risk_score=excluded.downside_risk_score,
    resilience_score=excluded.resilience_score,
    opportunity_score=excluded.opportunity_score,
    probability_weighted_upside=excluded.probability_weighted_upside,
    base_upside=excluded.base_upside,
    price_gate=excluded.price_gate,
    mispricing_gate=excluded.mispricing_gate,
    mispricing_class=excluded.mispricing_class,
    score_gate=excluded.score_gate,
    opportunity_state=excluded.opportunity_state,
    full_thesis_gate=excluded.full_thesis_gate,
    prebuy_research_gate=excluded.prebuy_research_gate,
    source_reference=excluded.source_reference,
    payload=excluded.payload,
    updated_at=now();

  get diagnostics v_rows=row_count;

  return jsonb_build_object(
    'as_of_date',p_as_of_date,
    'rows_refreshed',v_rows,
    'policy_version_id','POL-OPPORTUNITY-QUALITY-V2',
    'portfolio_fit_weight',0,
    'portfolio_fit_discovery_gate',false,
    'human_execution_only',true
  );
end
$function$
;
revoke all on function fwios.refresh_opportunity_quality_v2(date,text) from public,anon,authenticated;
grant execute on function fwios.refresh_opportunity_quality_v2(date,text) to service_role;

create or replace view fwios.v_candidate_portfolio_scenario_review_current with (security_invoker=true) as
 SELECT DISTINCT ON (ticker) review_id,
    ticker,
    portfolio_batch_id,
    add_amount_thb,
    trim_symbols,
    trim_amounts_thb,
    scenario_fit_score,
    scenario_fit_gate,
    candidate_weight_before,
    candidate_weight_after,
    max_stock_weight_before,
    max_stock_weight_after,
    candidate_sector_weight_before,
    candidate_sector_weight_after,
    crypto_weight_before,
    crypto_weight_after,
    unique_assets_before,
    unique_assets_after,
    metrics,
    source_reference,
    created_at
   FROM fwios.candidate_portfolio_scenario_reviews_v2 r
  ORDER BY ticker, created_at DESC, review_id DESC;;
revoke all on fwios.v_candidate_portfolio_scenario_review_current from public,anon,authenticated;
grant select on fwios.v_candidate_portfolio_scenario_review_current to service_role;

create or replace view fwios.v_opportunity_quality_current with (security_invoker=true) as
 WITH latest AS (
         SELECT DISTINCT ON (opportunity_quality_snapshots.ticker) opportunity_quality_snapshots.opportunity_snapshot_id,
            opportunity_quality_snapshots.ticker,
            opportunity_quality_snapshots.as_of_date,
            opportunity_quality_snapshots.policy_version_id,
            opportunity_quality_snapshots.business_thesis_score,
            opportunity_quality_snapshots.expected_return_signal_score,
            opportunity_quality_snapshots.quality_score,
            opportunity_quality_snapshots.downside_risk_score,
            opportunity_quality_snapshots.resilience_score,
            opportunity_quality_snapshots.opportunity_score,
            opportunity_quality_snapshots.probability_weighted_upside,
            opportunity_quality_snapshots.base_upside,
            opportunity_quality_snapshots.price_gate,
            opportunity_quality_snapshots.mispricing_gate,
            opportunity_quality_snapshots.mispricing_class,
            opportunity_quality_snapshots.score_gate,
            opportunity_quality_snapshots.opportunity_state,
            opportunity_quality_snapshots.full_thesis_gate,
            opportunity_quality_snapshots.prebuy_research_gate,
            opportunity_quality_snapshots.portfolio_scenario_gate,
            opportunity_quality_snapshots.source_reference,
            opportunity_quality_snapshots.payload,
            opportunity_quality_snapshots.created_at,
            opportunity_quality_snapshots.updated_at
           FROM fwios.opportunity_quality_snapshots
          WHERE opportunity_quality_snapshots.policy_version_id = 'POL-OPPORTUNITY-QUALITY-V2'::text
          ORDER BY opportunity_quality_snapshots.ticker, opportunity_quality_snapshots.as_of_date DESC, opportunity_quality_snapshots.updated_at DESC, opportunity_quality_snapshots.opportunity_snapshot_id DESC
        ), latest_batch AS (
         SELECT v_latest_portfolio_batch.batch_id
           FROM fwios.v_latest_portfolio_batch
         LIMIT 1
        )
 SELECT l.ticker,
    rc.company_name,
    rc.sector,
    rc.archetype,
    l.business_thesis_score,
    l.expected_return_signal_score,
    l.quality_score,
    l.downside_risk_score,
    l.resilience_score,
    l.opportunity_score,
    l.probability_weighted_upside,
    l.base_upside,
    l.price_gate,
    l.mispricing_gate,
    l.mispricing_class,
    l.score_gate,
    l.opportunity_state,
    l.full_thesis_gate,
    l.prebuy_research_gate,
        CASE
            WHEN l.prebuy_research_gate <> 'PASS - READY FOR PORTFOLIO SCENARIO'::text THEN 'NOT_READY'::text
            WHEN sr.review_id IS NULL THEN 'PORTFOLIO SCENARIO REQUIRED'::text
            WHEN sr.portfolio_batch_id IS DISTINCT FROM lb.batch_id THEN 'PORTFOLIO SCENARIO STALE'::text
            ELSE sr.scenario_fit_gate
        END AS portfolio_scenario_gate,
        CASE
            WHEN l.prebuy_research_gate <> 'PASS - READY FOR PORTFOLIO SCENARIO'::text THEN l.prebuy_research_gate
            WHEN sr.review_id IS NULL THEN 'BLOCKED - PORTFOLIO SCENARIO REQUIRED'::text
            WHEN sr.portfolio_batch_id IS DISTINCT FROM lb.batch_id THEN 'BLOCKED - PORTFOLIO SCENARIO STALE'::text
            WHEN sr.scenario_fit_gate = 'BLOCKED'::text THEN 'BLOCKED - PORTFOLIO SCENARIO'::text
            WHEN sr.scenario_fit_gate = 'REVIEW'::text THEN 'REVIEW - PORTFOLIO SCENARIO'::text
            WHEN sr.scenario_fit_gate = 'PASS'::text THEN 'PASS - HUMAN BUY REVIEW ELIGIBLE'::text
            ELSE 'BLOCKED - PORTFOLIO SCENARIO'::text
        END AS final_buy_review_gate,
    sr.scenario_fit_score,
    sr.add_amount_thb AS scenario_add_amount_thb,
    sr.created_at AS scenario_reviewed_at,
    dense_rank() OVER (ORDER BY l.opportunity_score DESC NULLS LAST, l.business_thesis_score DESC NULLS LAST, l.ticker) AS opportunity_rank,
    l.as_of_date,
    l.updated_at,
    dense_rank() OVER (ORDER BY (
        CASE
            WHEN l.score_gate = 'PASS'::text THEN 0
            ELSE 1
        END), l.opportunity_score DESC NULLS LAST, l.ticker) AS research_readiness_rank
   FROM latest l
     JOIN fwios.research_candidates rc ON rc.ticker = l.ticker
     CROSS JOIN latest_batch lb
     LEFT JOIN fwios.v_candidate_portfolio_scenario_review_current sr ON sr.ticker = l.ticker;;
revoke all on fwios.v_opportunity_quality_current from public,anon,authenticated;
grant select on fwios.v_opportunity_quality_current to service_role;

CREATE OR REPLACE FUNCTION fwios.preview_candidate_portfolio_fit_v2(p_ticker text, p_add_amount_thb numeric, p_trim_symbols text[] DEFAULT '{}'::text[], p_trim_amounts_thb numeric[] DEFAULT '{}'::numeric[])
 RETURNS TABLE(metric_name text, before_value numeric, after_value numeric, unit text, gate text, note text)
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
with
input_check as (
  select upper(p_ticker) ticker,greatest(coalesce(p_add_amount_thb,0),0) add_amount,
         coalesce(array_length(p_trim_symbols,1),0) trim_n,
         coalesce(array_length(p_trim_amounts_thb,1),0) trim_amt_n
),
trim_input as (
  select upper(s) symbol,a amount from unnest(p_trim_symbols,p_trim_amounts_thb) as x(s,a)
),
base as (
  select e.asset_symbol,e.asset_class,e.value_thb,coalesce(tr.sector,c.sector) sector
  from fwios.v_portfolio_exposure_current e
  left join fwios.thesis_registry tr on tr.ticker=e.asset_symbol
  left join fwios.companies c on c.ticker=e.asset_symbol
),
candidate as (
  select oq.ticker,oq.sector from fwios.v_opportunity_quality_current oq
  where oq.ticker=(select ticker from input_check)
),
symbols as (
  select asset_symbol from base union select ticker from candidate
),
sim as (
  select s.asset_symbol,coalesce(b.asset_class,'Stock') asset_class,coalesce(b.sector,c.sector) sector,
         coalesce(b.value_thb,0) before_value,
         coalesce((select sum(t.amount) from trim_input t where t.symbol=s.asset_symbol),0) trim_amount,
         case when s.asset_symbol=(select ticker from input_check)
           then (select add_amount from input_check) else 0 end add_amount
  from symbols s
  left join base b on b.asset_symbol=s.asset_symbol
  left join candidate c on c.ticker=s.asset_symbol
),
sim2 as (
  select *,greatest(before_value-trim_amount+add_amount,0) after_value from sim
),
totals as (
  select sum(before_value) total_before,sum(after_value) total_after from sim2
),
weighted as (
  select s.*,
    case when t.total_before>0 then s.before_value/t.total_before else 0 end before_weight,
    case when t.total_after>0 then s.after_value/t.total_after else 0 end after_weight
  from sim2 s cross join totals t
),
agg as (
  select
    max(before_weight) filter(where asset_class='Stock') max_stock_before,
    max(after_weight) filter(where asset_class='Stock') max_stock_after,
    coalesce(sum(before_weight) filter(where asset_class='Crypto'),0) crypto_before,
    coalesce(sum(after_weight) filter(where asset_class='Crypto'),0) crypto_after,
    count(*) filter(where before_value>0) assets_before,
    count(*) filter(where after_value>0) assets_after,
    coalesce(max(before_weight) filter(where asset_symbol=(select ticker from input_check)),0) candidate_weight_before,
    coalesce(max(after_weight) filter(where asset_symbol=(select ticker from input_check)),0) candidate_weight_after
  from weighted
),
sector_agg as (
  select
    coalesce(sum(before_weight) filter(where sector=(select sector from candidate)),0) sector_before,
    coalesce(sum(after_weight) filter(where sector=(select sector from candidate)),0) sector_after
  from weighted
),
validity as (
  select case
    when (select add_amount from input_check)<=0 then 'BLOCKED - ADD AMOUNT'
    when (select trim_n from input_check)<>(select trim_amt_n from input_check) then 'BLOCKED - TRIM ARRAY LENGTH'
    when not exists(select 1 from candidate) then 'BLOCKED - TICKER NOT IN OPPORTUNITY UNIVERSE'
    when exists(select 1 from trim_input where amount<=0) then 'BLOCKED - INVALID TRIM'
    when exists(
      select 1 from trim_input t left join base b on b.asset_symbol=t.symbol
      where b.asset_symbol is null or t.amount>b.value_thb
    ) then 'BLOCKED - TRIM EXCEEDS POSITION'
    else 'PASS' end input_gate
),
calc as (
  select a.*,s.*,v.input_gate,
    greatest(abs(a.crypto_before-0.175)-0.025,0) crypto_dev_before,
    greatest(abs(a.crypto_after-0.175)-0.025,0) crypto_dev_after,
    case when a.assets_before<5 then 5-a.assets_before when a.assets_before>8 then a.assets_before-8 else 0 end focus_dev_before,
    case when a.assets_after<5 then 5-a.assets_after when a.assets_after>8 then a.assets_after-8 else 0 end focus_dev_after
  from agg a cross join sector_agg s cross join validity v
),
final as (
  select *,
    case
      when input_gate<>'PASS' then 'BLOCKED'
      when candidate_weight_after>0.30 then 'BLOCKED'
      when max_stock_after>max_stock_before+0.02 then 'REVIEW'
      when sector_after>greatest(0.40,sector_before+0.02) then 'REVIEW'
      when crypto_dev_after>crypto_dev_before+0.01 then 'REVIEW'
      when focus_dev_after>focus_dev_before then 'REVIEW'
      else 'PASS' end scenario_gate,
    greatest(0,least(100,
      100
      - case when candidate_weight_after>0.30 then 70 else 0 end
      - case when max_stock_after>max_stock_before+0.02 then 20 else 0 end
      - case when sector_after>greatest(0.40,sector_before+0.02) then 15 else 0 end
      - case when crypto_dev_after>crypto_dev_before+0.01 then 10 else 0 end
      - case when focus_dev_after>focus_dev_before then 10 else 0 end
    )) scenario_score
  from calc
)
select 'scenario_fit_score',null,scenario_score,'score_0_100',scenario_gate,
  'Post-selection score only. It does not enter Opportunity Quality.' from final
union all
select 'candidate_weight',candidate_weight_before,candidate_weight_after,'ratio',
  case when candidate_weight_after>0.30 then 'BLOCKED - ABOVE 30%' else 'PASS' end,
  'Candidate position size after the proposed add/trim scenario.' from final
union all
select 'max_single_stock_weight',max_stock_before,max_stock_after,'ratio',
  case when max_stock_after>max_stock_before+0.02 then 'REVIEW - WORSENS CONCENTRATION' else 'PASS' end,
  'Directional test: existing concentration is not itself a candidate penalty.' from final
union all
select 'candidate_sector_weight',sector_before,sector_after,'ratio',
  case when sector_after>greatest(0.40,sector_before+0.02) then 'REVIEW - SECTOR CONCENTRATION' else 'PASS' end,
  'Sector concentration is evaluated after the proposed scenario, not during discovery.' from final
union all
select 'crypto_weight',crypto_before,crypto_after,'ratio',
  case when crypto_dev_after>crypto_dev_before+0.01 then 'REVIEW - CRYPTO DEVIATION WORSENS' else 'PASS' end,
  'A pre-existing crypto deviation does not block a stock unless the scenario worsens it.' from final
union all
select 'unique_open_assets',assets_before::numeric,assets_after::numeric,'count',
  case when focus_dev_after>focus_dev_before then 'REVIEW - FOCUS DEVIATION WORSENS' else 'PASS' end,
  'A portfolio already outside the 5-8 preference is not used to reject a candidate unless the scenario worsens the deviation.' from final
union all
select 'scenario_input_gate',null,null,'state',input_gate,'Input validation for the scenario.' from final;
$function$
;
revoke all on function fwios.preview_candidate_portfolio_fit_v2(text,numeric,text[],numeric[]) from public,anon,authenticated;
grant execute on function fwios.preview_candidate_portfolio_fit_v2(text,numeric,text[],numeric[]) to service_role;

CREATE OR REPLACE FUNCTION fwios.materialize_candidate_portfolio_fit_v2(p_ticker text, p_add_amount_thb numeric, p_trim_symbols text[] DEFAULT '{}'::text[], p_trim_amounts_thb numeric[] DEFAULT '{}'::numeric[], p_source text DEFAULT 'HUMAN_REVIEW'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_review_id uuid; v_batch_id text; v_gate text; v_score numeric;
  v_candidate_before numeric; v_candidate_after numeric; v_max_before numeric; v_max_after numeric;
  v_sector_before numeric; v_sector_after numeric; v_crypto_before numeric; v_crypto_after numeric;
  v_assets_before integer; v_assets_after integer; v_metrics jsonb;
begin
  select batch_id into v_batch_id from fwios.v_latest_portfolio_batch limit 1;

  with m as (
    select * from fwios.preview_candidate_portfolio_fit_v2(
      upper(p_ticker),p_add_amount_thb,p_trim_symbols,p_trim_amounts_thb
    )
  )
  select
    max(gate) filter(where metric_name='scenario_fit_score'),
    max(after_value) filter(where metric_name='scenario_fit_score'),
    max(before_value) filter(where metric_name='candidate_weight'),
    max(after_value) filter(where metric_name='candidate_weight'),
    max(before_value) filter(where metric_name='max_single_stock_weight'),
    max(after_value) filter(where metric_name='max_single_stock_weight'),
    max(before_value) filter(where metric_name='candidate_sector_weight'),
    max(after_value) filter(where metric_name='candidate_sector_weight'),
    max(before_value) filter(where metric_name='crypto_weight'),
    max(after_value) filter(where metric_name='crypto_weight'),
    (max(before_value) filter(where metric_name='unique_open_assets'))::int,
    (max(after_value) filter(where metric_name='unique_open_assets'))::int,
    jsonb_agg(to_jsonb(m) order by metric_name)
  into v_gate,v_score,v_candidate_before,v_candidate_after,v_max_before,v_max_after,
       v_sector_before,v_sector_after,v_crypto_before,v_crypto_after,v_assets_before,v_assets_after,v_metrics
  from m;

  if v_gate is null then raise exception 'SCENARIO_REVIEW_FAILED'; end if;

  insert into fwios.candidate_portfolio_scenario_reviews_v2(
    ticker,portfolio_batch_id,add_amount_thb,trim_symbols,trim_amounts_thb,
    scenario_fit_score,scenario_fit_gate,candidate_weight_before,candidate_weight_after,
    max_stock_weight_before,max_stock_weight_after,candidate_sector_weight_before,candidate_sector_weight_after,
    crypto_weight_before,crypto_weight_after,unique_assets_before,unique_assets_after,metrics,source_reference
  )
  values(
    upper(p_ticker),v_batch_id,p_add_amount_thb,coalesce(p_trim_symbols,'{}'::text[]),
    coalesce(p_trim_amounts_thb,'{}'::numeric[]),v_score,v_gate,
    v_candidate_before,v_candidate_after,v_max_before,v_max_after,v_sector_before,v_sector_after,
    v_crypto_before,v_crypto_after,v_assets_before,v_assets_after,v_metrics,p_source
  )
  returning review_id into v_review_id;

  return v_review_id;
end
$function$
;
revoke all on function fwios.materialize_candidate_portfolio_fit_v2(text,numeric,text[],numeric[],text) from public,anon,authenticated;
grant execute on function fwios.materialize_candidate_portfolio_fit_v2(text,numeric,text[],numeric[],text) to service_role;

create or replace view fwios.v_dashboard_opportunities with (security_invoker=true) as
 SELECT
        CASE
            WHEN oq.final_buy_review_gate = 'PASS - HUMAN BUY REVIEW ELIGIBLE'::text THEN 'HUMAN_BUY_REVIEW_ELIGIBLE'::text
            WHEN oq.opportunity_state = 'MISPRICED_CANDIDATE'::text THEN 'MISPRICED_RESEARCH'::text
            WHEN oq.opportunity_state = 'VALUE_WAIT'::text THEN 'WATCHLIST_VALUE_WAIT'::text
            WHEN oq.opportunity_state = 'PRICE_VERIFY'::text THEN 'PRICE_VERIFY'::text
            ELSE 'RESEARCH'::text
        END AS opportunity_bucket,
    oq.opportunity_rank::integer AS bucket_rank,
    oq.ticker,
    oq.opportunity_score AS core_score,
    oq.business_thesis_score,
    oq.expected_return_signal_score AS expected_return_score,
    oq.scenario_fit_score AS portfolio_fit_score,
    oq.downside_risk_score,
    oq.score_gate AS eligibility_gate,
    oq.final_buy_review_gate AS rationale_code,
    oq.opportunity_state AS decision_state,
    oq.prebuy_research_gate AS promotion_gate,
    oq.score_gate AS input_integrity_gate,
    vm.current_price::numeric(38,18) AS current_price,
    vm.fair_value::numeric(38,18) AS probability_weighted_fv_per_share,
    oq.probability_weighted_upside::numeric(38,18) AS probability_weighted_upside,
    oq.price_gate AS mispricing_gate,
    oq.mispricing_class,
    'POL-OPPORTUNITY-QUALITY-V2'::text AS ranking_run_id,
    NULL::text AS decision_snapshot_id,
    oq.updated_at AS created_at
   FROM fwios.v_opportunity_quality_current oq
     LEFT JOIN fwios.v_dashboard_valuation_map vm ON vm.ticker = oq.ticker
  ORDER BY oq.opportunity_rank, oq.ticker;;
revoke all on fwios.v_dashboard_opportunities from public,anon,authenticated;
grant select on fwios.v_dashboard_opportunities to service_role;

create or replace view fwios.v_dashboard_current_action with (security_invoker=true) as
 WITH prod_packet AS (
         SELECT v_human_approval_current.approval_packet_id,
            v_human_approval_current.policy_version_id,
            v_human_approval_current.recommendation_run_id,
            v_human_approval_current.request_scope,
            v_human_approval_current.packet_status,
            v_human_approval_current.portfolio_batch_id,
            v_human_approval_current.ranking_run_id,
            v_human_approval_current.recommendation_policy_version_id,
            v_human_approval_current.candidate_ticker,
            v_human_approval_current.source_ticker,
            v_human_approval_current.new_cash_thb,
            v_human_approval_current.add_amount_thb,
            v_human_approval_current.trim_amount_thb,
            v_human_approval_current.candidate_decision_snapshot_id,
            v_human_approval_current.source_valuation_run_id,
            v_human_approval_current.candidate_price_snapshot_id,
            v_human_approval_current.source_price_snapshot_id,
            v_human_approval_current.recommendation_fingerprint,
            v_human_approval_current.traceability_gate,
            v_human_approval_current.freshness_gate,
            v_human_approval_current.input_fresh_until,
            v_human_approval_current.approval_required,
            v_human_approval_current.auto_trade,
            v_human_approval_current.source_reference,
            v_human_approval_current.created_at,
            v_human_approval_current.current_state,
            v_human_approval_current.latest_event_type,
            v_human_approval_current.latest_actor_type,
            v_human_approval_current.latest_actor_ref,
            v_human_approval_current.latest_revalidation_gate,
            v_human_approval_current.latest_event_at
           FROM fwios.v_human_approval_current
          WHERE v_human_approval_current.request_scope = 'PRODUCTION_USER_REQUESTED'::text
          ORDER BY v_human_approval_current.created_at DESC
         LIMIT 1
        ), top_opp AS (
         SELECT v_opportunity_quality_current.ticker,
            v_opportunity_quality_current.company_name,
            v_opportunity_quality_current.sector,
            v_opportunity_quality_current.archetype,
            v_opportunity_quality_current.business_thesis_score,
            v_opportunity_quality_current.expected_return_signal_score,
            v_opportunity_quality_current.quality_score,
            v_opportunity_quality_current.downside_risk_score,
            v_opportunity_quality_current.resilience_score,
            v_opportunity_quality_current.opportunity_score,
            v_opportunity_quality_current.probability_weighted_upside,
            v_opportunity_quality_current.base_upside,
            v_opportunity_quality_current.price_gate,
            v_opportunity_quality_current.mispricing_gate,
            v_opportunity_quality_current.mispricing_class,
            v_opportunity_quality_current.score_gate,
            v_opportunity_quality_current.opportunity_state,
            v_opportunity_quality_current.full_thesis_gate,
            v_opportunity_quality_current.prebuy_research_gate,
            v_opportunity_quality_current.portfolio_scenario_gate,
            v_opportunity_quality_current.final_buy_review_gate,
            v_opportunity_quality_current.scenario_fit_score,
            v_opportunity_quality_current.scenario_add_amount_thb,
            v_opportunity_quality_current.scenario_reviewed_at,
            v_opportunity_quality_current.opportunity_rank,
            v_opportunity_quality_current.as_of_date,
            v_opportunity_quality_current.updated_at,
            v_opportunity_quality_current.research_readiness_rank
           FROM fwios.v_opportunity_quality_current
          ORDER BY v_opportunity_quality_current.opportunity_rank, v_opportunity_quality_current.ticker
         LIMIT 1
        )
 SELECT
        CASE
            WHEN p.approval_packet_id IS NOT NULL AND p.current_state = 'PENDING'::text THEN 'HUMAN_REVIEW_REQUIRED'::text
            WHEN p.approval_packet_id IS NOT NULL AND p.current_state = 'APPROVED'::text THEN 'APPROVED_AWAITING_HUMAN_BROKER_STEP'::text
            WHEN p.approval_packet_id IS NOT NULL AND (p.current_state = ANY (ARRAY['REJECTED'::text, 'EXPIRED'::text, 'STALE'::text])) THEN 'NO_LIVE_ACTIONABLE_PACKET'::text
            WHEN o.final_buy_review_gate = 'PASS - HUMAN BUY REVIEW ELIGIBLE'::text THEN 'READY_FOR_HUMAN_BUY_REVIEW'::text
            WHEN o.prebuy_research_gate = 'BLOCKED - FULL THESIS REQUIRED'::text THEN 'FULL_THESIS_REQUIRED'::text
            WHEN o.opportunity_state = 'PRICE_VERIFY'::text THEN 'PRICE_VERIFICATION_REQUIRED'::text
            WHEN o.prebuy_research_gate = 'PASS - READY FOR PORTFOLIO SCENARIO'::text AND (o.portfolio_scenario_gate = ANY (ARRAY['PORTFOLIO SCENARIO REQUIRED'::text, 'PORTFOLIO SCENARIO STALE'::text])) THEN 'PORTFOLIO_SCENARIO_REQUIRED'::text
            ELSE 'RESEARCH_TOP_OPPORTUNITY'::text
        END AS action_state,
    COALESCE(p.candidate_ticker, o.ticker) AS candidate_ticker,
    p.source_ticker,
    p.new_cash_thb,
    p.add_amount_thb,
    p.trim_amount_thb,
    p.current_state AS approval_state,
    p.traceability_gate,
    p.freshness_gate,
    o.opportunity_score AS candidate_core_score,
    o.scenario_fit_score AS candidate_portfolio_fit_score,
        CASE
            WHEN p.approval_packet_id IS NOT NULL THEN 'Live production-user approval packet state.'::text
            WHEN o.final_buy_review_gate = 'PASS - HUMAN BUY REVIEW ELIGIBLE'::text THEN 'Opportunity research is complete and the current portfolio scenario passed; human review is required before any broker action.'::text
            WHEN o.prebuy_research_gate = 'BLOCKED - FULL THESIS REQUIRED'::text THEN 'Top opportunity is visible without Portfolio Fit suppression, but requires a full thesis before portfolio scenario review.'::text
            WHEN o.opportunity_state = 'PRICE_VERIFY'::text THEN 'Top opportunity is ranked by investment quality, but current price must be verified before mispricing can be trusted.'::text
            ELSE 'Top opportunity remains in research or portfolio-scenario review; no automatic execution is permitted.'::text
        END AS action_note,
    false AS auto_trade,
    true AS human_execution_only
   FROM ( SELECT 1 AS "?column?") x
     LEFT JOIN prod_packet p ON true
     LEFT JOIN top_opp o ON true;;
revoke all on fwios.v_dashboard_current_action from public,anon,authenticated;
grant select on fwios.v_dashboard_current_action to service_role;

CREATE OR REPLACE FUNCTION fwios.dashboard_refresh_payload_v1()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'fwios'
AS $function$
with
account_summary as (
  select coalesce(jsonb_agg(to_jsonb(a) order by case when a.account_view_key='ALL' then 0 else 1 end,a.account_view_name),'[]'::jsonb) v
  from fwios.v_dashboard_account_summary a
),
holdings as (
  select coalesce(jsonb_agg(to_jsonb(h) order by case when h.account_view_key='ALL' then 0 else 1 end,h.account_view_key,h.value_thb desc,h.asset_symbol),'[]'::jsonb) v
  from fwios.v_dashboard_holdings h
),
opportunities as (
  select coalesce(jsonb_agg(to_jsonb(o) order by o.bucket_rank,o.ticker),'[]'::jsonb) v
  from (
    select * from fwios.v_dashboard_opportunities
    order by bucket_rank,ticker
    limit 5
  ) o
),
opportunity_quality as (
  select coalesce(jsonb_agg(to_jsonb(o) order by o.opportunity_rank,o.ticker),'[]'::jsonb) v
  from fwios.v_opportunity_quality_current o
),
valuation_map as (
  select coalesce(jsonb_agg(to_jsonb(v)),'[]'::jsonb) v from fwios.v_dashboard_valuation_map v
),
thesis_tracking as (
  select coalesce(jsonb_agg(to_jsonb(t) order by t.tracking_priority,
    case t.health_status when 'BROKEN' then 0 when 'WEAKENING' then 1 when 'WATCH' then 2
      when 'BASELINE_REQUIRED' then 3 when 'STABLE' then 4 when 'STRONG' then 5 else 6 end,
    t.ticker),'[]'::jsonb) v
  from fwios.v_thesis_tracking_current t
),
current_action as (
  select coalesce(jsonb_agg(to_jsonb(c)),'[]'::jsonb) v from fwios.v_dashboard_current_action c
),
alerts as (
  select coalesce(jsonb_agg(to_jsonb(a) order by a.alert_order),'[]'::jsonb) v from fwios.v_dashboard_alerts a
),
system_health as (
  select coalesce(jsonb_agg(to_jsonb(s)-'read_model_checked_at'),'[]'::jsonb) v,
         max(s.portfolio_batch_status) portfolio_batch_status,
         max(s.source_transaction_count) source_transaction_count,
         max(s.transaction_pass_count) transaction_pass_count,
         max(s.source_position_count) source_position_count,
         max(s.position_pass_count) position_pass_count,
         bool_or(s.auto_trade) auto_trade,
         bool_and(s.human_execution_only) human_execution_only,
         max(s.contract_id) contract_id,
         max(s.portfolio_batch_id) portfolio_batch_id
  from fwios.v_dashboard_system_health s
),
payload as (
  select jsonb_build_object(
    'account_summary',account_summary.v,'holdings',holdings.v,'opportunities',opportunities.v,
    'opportunity_quality',opportunity_quality.v,'valuation_map',valuation_map.v,
    'thesis_tracking',thesis_tracking.v,'current_action',current_action.v,
    'alerts',alerts.v,'system_health',system_health.v
  ) data,system_health.*
  from account_summary,holdings,opportunities,opportunity_quality,valuation_map,thesis_tracking,current_action,alerts,system_health
)
select jsonb_build_object(
  'schema_version','DASHBOARD_REFRESH_PAYLOAD_V1_3',
  'sheet_id','17_Z-s6OyspX48EC6DOsJUy0D7kuN67Gmo0bOMgVDkF8',
  'generated_at',now(),'contract_id',contract_id,'portfolio_batch_id',portfolio_batch_id,
  'refresh_gate',case
    when portfolio_batch_status='PASS'
     and source_transaction_count=transaction_pass_count
     and source_position_count=position_pass_count
     and coalesce(auto_trade,false)=false
     and coalesce(human_execution_only,false)=true then 'PASS' else 'BLOCKED' end,
  'source_fingerprint',md5(data::text),'data',data
)
from payload;
$function$
;
revoke all on function fwios.dashboard_refresh_payload_v1() from public,anon,authenticated;
grant execute on function fwios.dashboard_refresh_payload_v1() to service_role;

select fwios.refresh_opportunity_quality_v2(current_date,'OPPORTUNITY_QUALITY_V2_MIGRATION');
select cron.unschedule(jobid) from cron.job where jobname='fwios-opportunity-quality-refresh';
select cron.schedule('fwios-opportunity-quality-refresh','45 6 * * 1-5',
 $$select fwios.refresh_opportunity_quality_v2(current_date,'CRON_POST_THESIS_REFRESH');$$);

update fwios.policy_registry set lifecycle_status='RETIRED',updated_at=now()
where policy_key='OPPORTUNITY_RANKING';
update fwios.policy_versions set lifecycle_status='RETIRED'
where policy_key='OPPORTUNITY_RANKING' and lifecycle_status='ACTIVE';

update fwios.system_state
set state_value=state_value||jsonb_build_object(
 'opportunity_quality','LIVE_V2','opportunity_quality_policy','POL-OPPORTUNITY-QUALITY-V2',
 'opportunity_formula','35_THESIS_40_EXPECTED_RETURN_25_RESILIENCE',
 'portfolio_fit_weight_in_opportunity',0,'portfolio_fit_discovery_gate',false,
 'portfolio_fit_mode','POST_SELECTION_DIRECTIONAL_SCENARIO_V2',
 'portfolio_scenario_fit_policy','POL-PORTFOLIO-SCENARIO-FIT-V2',
 'legacy_opportunity_ranking_v1','RETIRED','full_thesis_before_portfolio_scenario',true,
 'portfolio_scenario_before_buy_review',true,'dashboard_payload_version','DASHBOARD_REFRESH_PAYLOAD_V1_3',
 'dashboard_csv_worker_version',7,'auto_trade',false
),updated_at=now(),as_of_text='2026-09-24'
where state_key='architecture_consolidation_v1';
