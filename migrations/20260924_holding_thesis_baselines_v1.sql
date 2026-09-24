-- Holding Thesis Baselines + Evidence-Aware Health v1
-- Priority-0 portfolio holdings receive explicit, evidence-backed thesis baselines.
-- Thesis health uses directional evidence, never price. BROKEN still requires an explicit invalidation event.

alter table fwios.thesis_health_snapshots
  add column if not exists recent_event_score numeric,
  add column if not exists support_events_120d integer not null default 0,
  add column if not exists contradict_events_120d integer not null default 0,
  add column if not exists strongest_negative_120d numeric;

create or replace function fwios.sync_thesis_registry_v1()
returns jsonb
language plpgsql
set search_path to ''
as $function$
declare
  v_total int;
  v_p0 int;
  v_p1 int;
  v_p2 int;
begin
  with universe as (
    select
      h.asset_symbol ticker,
      coalesce(rc.company_name,c.company_name,h.asset_symbol) company_name,
      coalesce(rc.sector,c.sector) sector,
      coalesce(rc.archetype,c.archetype) archetype,
      0 priority,'PORTFOLIO' ownership_status,
      case when rc.ticker is not null then 'MIGRATED_RESEARCH' else 'BASELINE_REQUIRED' end baseline_status,
      case when rc.ticker is not null then 0.50::numeric else 0::numeric end baseline_completeness,
      case when rc.ticker is not null then 'research_candidates:'||rc.ticker else 'portfolio_holdings:'||h.asset_symbol end source_reference
    from fwios.v_dashboard_holdings h
    left join fwios.research_candidates rc on rc.ticker=h.asset_symbol
    left join fwios.companies c on c.ticker=h.asset_symbol
    where h.account_view_key='ALL' and h.asset_class='Stock'
    union all
    select rc.ticker,rc.company_name,rc.sector,rc.archetype,
           1,'RESEARCH_CANDIDATE','MIGRATED_RESEARCH',0.50::numeric,'research_candidates:'||rc.ticker
    from fwios.research_candidates rc
    union all
    select c.ticker,c.company_name,c.sector,c.archetype,
           2,'WATCHLIST','BASELINE_REQUIRED',0::numeric,'companies:'||c.ticker
    from fwios.companies c
    where c.active=true
  ),
  dedup as (
    select distinct on (ticker)
      ticker,company_name,sector,archetype,priority,ownership_status,
      baseline_status,baseline_completeness,source_reference
    from universe
    where ticker is not null and ticker<>''
    order by ticker,priority
  )
  insert into fwios.thesis_registry(
    ticker,company_name,sector,archetype,tracking_priority,ownership_status,
    baseline_status,baseline_completeness,source_reference,metadata,active,updated_at
  )
  select
    d.ticker,d.company_name,d.sector,d.archetype,d.priority,d.ownership_status,
    d.baseline_status,d.baseline_completeness,d.source_reference,
    jsonb_build_object(
      'contract','THESIS_TRACKING_V1',
      'baseline_generated',false,
      'explicit_invalidation_required_for_broken',true
    ),
    true,now()
  from dedup d
  on conflict(ticker) do update set
    company_name=case when fwios.thesis_registry.baseline_status='COMPLETE'
      then fwios.thesis_registry.company_name
      else coalesce(excluded.company_name,fwios.thesis_registry.company_name) end,
    sector=case when fwios.thesis_registry.baseline_status='COMPLETE'
      then fwios.thesis_registry.sector
      else coalesce(excluded.sector,fwios.thesis_registry.sector) end,
    archetype=case when fwios.thesis_registry.baseline_status='COMPLETE'
      then fwios.thesis_registry.archetype
      else coalesce(excluded.archetype,fwios.thesis_registry.archetype) end,
    tracking_priority=excluded.tracking_priority,
    ownership_status=excluded.ownership_status,
    baseline_status=case
      when fwios.thesis_registry.baseline_status='COMPLETE' then 'COMPLETE'
      when excluded.baseline_status='MIGRATED_RESEARCH' then 'MIGRATED_RESEARCH'
      else fwios.thesis_registry.baseline_status end,
    baseline_completeness=greatest(fwios.thesis_registry.baseline_completeness,excluded.baseline_completeness),
    source_reference=case when fwios.thesis_registry.baseline_status='COMPLETE'
      then fwios.thesis_registry.source_reference
      else coalesce(fwios.thesis_registry.source_reference,excluded.source_reference) end,
    active=true,
    updated_at=now();

  insert into fwios.thesis_events(
    event_key,ticker,event_date,event_type,direction,impact_score,thesis_dimension,
    summary,evidence_source,source_reference,payload
  )
  select
    'BASELINE|'||tr.ticker,tr.ticker,current_date,
    case when tr.baseline_status='BASELINE_REQUIRED' then 'BASELINE_REQUIRED' else 'BASELINE_MIGRATION' end,
    'SYSTEM',0,'BASELINE',
    case when tr.baseline_status='BASELINE_REQUIRED'
      then 'Thesis tracker created; explicit baseline thesis, KPIs, catalysts and invalidation criteria are still required.'
      else 'Existing research candidate migrated into continuous thesis tracking without inventing missing thesis criteria.' end,
    'FWIOS',tr.source_reference,
    jsonb_build_object('baseline_status',tr.baseline_status,'tracking_priority',tr.tracking_priority,'ownership_status',tr.ownership_status)
  from fwios.thesis_registry tr
  on conflict(event_key) do nothing;

  select count(*),count(*) filter(where tracking_priority=0),
         count(*) filter(where tracking_priority=1),count(*) filter(where tracking_priority=2)
  into v_total,v_p0,v_p1,v_p2
  from fwios.thesis_registry where active=true;

  return jsonb_build_object(
    'total_active',v_total,'priority_0_portfolio',v_p0,'priority_1_candidates',v_p1,
    'priority_2_watchlist',v_p2,'auto_generated_thesis_statements',false
  );
end
$function$;

revoke all on function fwios.sync_thesis_registry_v1() from public,anon,authenticated;
grant execute on function fwios.sync_thesis_registry_v1() to service_role;

-- Priority-0 holding baseline definitions.
update fwios.thesis_registry
set company_name='NVIDIA Corporation',sector='Information Technology',
    archetype='AI Accelerated Computing Platform',baseline_status='COMPLETE',baseline_completeness=1,
    thesis_statement='AI compute demand plus NVIDIA''s platform leadership across accelerated compute, networking, systems and software can sustain outsized Data Center growth and cash generation through the Blackwell-to-Rubin transition.',
    must_remain_true=jsonb_build_array(
      jsonb_build_object('id','NVDA-MRT-1','statement','Data Center remains the primary growth engine and broad AI infrastructure demand remains durable across hyperscalers, AI clouds, enterprises and sovereign customers.'),
      jsonb_build_object('id','NVDA-MRT-2','statement','Blackwell Ultra and Rubin platform transitions execute without sustained supply, yield, quality or deployment problems.'),
      jsonb_build_object('id','NVDA-MRT-3','statement','NVIDIA preserves platform economics and competitive differentiation despite custom accelerators and competing GPU/AI platforms.'),
      jsonb_build_object('id','NVDA-MRT-4','statement','Gross-margin economics remain consistent with a premium integrated platform rather than structurally compressing toward commodity hardware.')
    ),
    monitoring_kpis=jsonb_build_array(
      jsonb_build_object('metric','Data Center revenue','baseline','Q2 FY27 $89.0B; +117% YoY; +18% QoQ','frequency','quarterly'),
      jsonb_build_object('metric','Total revenue and forward guidance','baseline','Q2 FY27 $96.2B; Q3 FY27 guide $108B +/-2%','frequency','quarterly'),
      jsonb_build_object('metric','Gross margin','baseline','Q2 FY27 75.0%','frequency','quarterly'),
      jsonb_build_object('metric','Platform transition execution','baseline','Rubin production shipments began in Q3 FY27; Blackwell remains majority of shipments','frequency','quarterly')
    ),
    catalysts=jsonb_build_array(
      jsonb_build_object('catalyst','Rubin production ramp and broader rack-scale deployments','horizon','FY27-FY28'),
      jsonb_build_object('catalyst','Continued expansion of AI factory capex','horizon','multi-year'),
      jsonb_build_object('catalyst','Growth in networking and full-stack systems/software attach','horizon','multi-year')
    ),
    invalidation_criteria=jsonb_build_array(
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Two consecutive quarters of sequential Data Center revenue decline together with guidance for continued contraction, absent a clearly temporary supply/timing explanation.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','A major platform transition failure or sustained product-quality/supply issue causes material customer deferrals and repeated guidance reductions.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Clear structural platform-share loss plus sustained gross margin below 65% caused by competitive pricing or weaker product economics.')
    ),
    source_reference='https://nvidianews.nvidia.com/news/nvidia-announces-financial-results-for-second-quarter-fiscal-2027',
    metadata=metadata||jsonb_build_object('baseline_version','HOLDING_BASELINE_V1','baseline_as_of','2026-09-24'),
    updated_at=now()
where ticker='NVDA';

update fwios.thesis_registry
set company_name='Microsoft Corporation',sector='Information Technology',
    archetype='Enterprise Cloud and AI Platform',baseline_status='COMPLETE',baseline_completeness=1,
    thesis_statement='Microsoft''s enterprise distribution, Azure scale and AI monetization across Azure, Microsoft 365, GitHub and Copilot can compound durable cloud earnings, provided AI infrastructure spending converts into sustained revenue, backlog and cash returns.',
    must_remain_true=jsonb_build_array(
      jsonb_build_object('id','MSFT-MRT-1','statement','Azure remains a high-growth cloud platform and AI demand continues translating into consumption revenue.'),
      jsonb_build_object('id','MSFT-MRT-2','statement','Copilot and first-party AI products expand paid adoption and monetization across the installed enterprise base.'),
      jsonb_build_object('id','MSFT-MRT-3','statement','Commercial RPO continues to support multi-year revenue visibility outside any single frontier-model customer.'),
      jsonb_build_object('id','MSFT-MRT-4','statement','AI capex produces acceptable operating and free-cash-flow economics rather than structurally eroding returns.')
    ),
    monitoring_kpis=jsonb_build_array(
      jsonb_build_object('metric','Azure and other cloud services growth','baseline','Q4 FY26 +43% YoY; FY26 +41%','frequency','quarterly'),
      jsonb_build_object('metric','Microsoft Cloud revenue and gross margin','baseline','Q4 FY26 $59.3B, +27% YoY; gross margin 65%','frequency','quarterly'),
      jsonb_build_object('metric','Microsoft 365 Copilot paid seats','baseline','More than 30M paid seats at FY26 Q4','frequency','quarterly'),
      jsonb_build_object('metric','Commercial remaining performance obligation','baseline','$678B at FY26 Q4, +84% YoY','frequency','quarterly'),
      jsonb_build_object('metric','Capex and free cash flow conversion','baseline','Q4 FY26 capex $41B; free cash flow $19.6B','frequency','quarterly')
    ),
    catalysts=jsonb_build_array(
      jsonb_build_object('catalyst','Additional data-center capacity coming online','horizon','FY27'),
      jsonb_build_object('catalyst','Broader Copilot and agent monetization','horizon','multi-year'),
      jsonb_build_object('catalyst','Conversion of commercial RPO into cloud revenue','horizon','multi-year')
    ),
    invalidation_criteria=jsonb_build_array(
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Azure growth falls below 20% for two consecutive quarters while AI infrastructure spending remains elevated and the slowdown is not temporary capacity timing.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Microsoft Cloud gross margin remains below 60% for two consecutive quarters because AI infrastructure economics fail to improve.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Commercial RPO and Copilot paid adoption both materially contract while capex stays elevated.')
    ),
    source_reference='https://www.microsoft.com/en-us/investor/earnings/fy-2026-q4/press-release-webcast',
    metadata=metadata||jsonb_build_object('baseline_version','HOLDING_BASELINE_V1','baseline_as_of','2026-09-24'),
    updated_at=now()
where ticker='MSFT';

update fwios.thesis_registry
set company_name='Take-Two Interactive Software, Inc.',sector='Communication Services',
    archetype='Premium Interactive Entertainment and Live Services',
    baseline_status='COMPLETE',baseline_completeness=1,
    thesis_statement='Grand Theft Auto VI can establish a materially higher multi-year earnings and cash-flow base if the November 2026 launch executes well and Take-Two converts franchise engagement into durable recurrent consumer spending across GTA Online and its broader portfolio.',
    must_remain_true=jsonb_build_array(
      jsonb_build_object('id','TTWO-MRT-1','statement','Grand Theft Auto VI remains on track for November 19, 2026 and launches at a quality level consistent with Rockstar''s franchise economics.'),
      jsonb_build_object('id','TTWO-MRT-2','statement','Fiscal 2027 Net Bookings remain broadly consistent with the company''s $8.0B-$8.2B outlook.'),
      jsonb_build_object('id','TTWO-MRT-3','statement','The GTA ecosystem converts launch demand into sustained engagement, GTA Online/GTA+ monetization and recurrent consumer spending.'),
      jsonb_build_object('id','TTWO-MRT-4','statement','The broader 2K/Zynga portfolio contributes enough recurring bookings to reduce dependence on a single release.')
    ),
    monitoring_kpis=jsonb_build_array(
      jsonb_build_object('metric','Fiscal-year Net Bookings guidance','baseline','FY27 $8.0B-$8.2B reiterated Aug. 7, 2026','frequency','quarterly'),
      jsonb_build_object('metric','Recurrent consumer spending share','baseline','Q1 FY27 84% of Net Bookings; $1.169B','frequency','quarterly'),
      jsonb_build_object('metric','GTA VI release schedule','baseline','November 19, 2026 on PS5 and Xbox Series X|S','frequency','event-driven'),
      jsonb_build_object('metric','Post-launch cash-flow/profitability trajectory','baseline','Management expects FY27 to establish a new operating-performance baseline','frequency','quarterly')
    ),
    catalysts=jsonb_build_array(
      jsonb_build_object('catalyst','Grand Theft Auto VI launch','date','2026-11-19'),
      jsonb_build_object('catalyst','GTA Online ecosystem transition and monetization','horizon','post-launch'),
      jsonb_build_object('catalyst','Sustained FY27 record bookings plus broader portfolio contributions','horizon','FY27-FY28')
    ),
    invalidation_criteria=jsonb_build_array(
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Grand Theft Auto VI is delayed beyond fiscal 2027 or suffers a launch-quality failure that materially impairs engagement.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','FY27 Net Bookings guidance is cut by more than 15% primarily because expected GTA VI economics fail to materialize.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Within the first two reported quarters after launch, GTA engagement and recurrent spending fail to establish a higher earnings/cash-flow baseline and management materially reduces long-term expectations.')
    ),
    source_reference='https://www.take2games.com/ir/news/take-two-interactive-software-inc-reports-results-fiscal-first-6',
    metadata=metadata||jsonb_build_object('baseline_version','HOLDING_BASELINE_V1','baseline_as_of','2026-09-24'),
    updated_at=now()
where ticker='TTWO';

update fwios.thesis_registry
set company_name='Talen Energy Corporation',sector='Utilities',
    archetype='Dispatchable Power and Data Center Infrastructure',
    baseline_status='COMPLETE',baseline_completeness=1,
    thesis_statement='Scarce dispatchable and nuclear generation in PJM, long-duration hyperscale power contracts and a growing powered-land/data-center pipeline can expand Talen''s free cash flow and per-share value, provided leverage and regulatory/grid risks remain controlled.',
    must_remain_true=jsonb_build_array(
      jsonb_build_object('id','TLN-MRT-1','statement','Core generation assets maintain strong operating reliability and monetize favorable PJM capacity/power economics.'),
      jsonb_build_object('id','TLN-MRT-2','statement','The AWS power agreement and additional data-center pipeline progress into durable contracted cash flows.'),
      jsonb_build_object('id','TLN-MRT-3','statement','Cornerstone and other acquisitions integrate without pushing leverage above management''s long-term tolerance.'),
      jsonb_build_object('id','TLN-MRT-4','statement','Free cash flow remains sufficient to support debt service, investment and opportunistic share repurchases.')
    ),
    monitoring_kpis=jsonb_build_array(
      jsonb_build_object('metric','Adjusted EBITDA guidance','baseline','2026 guidance $2.025B-$2.225B','frequency','quarterly'),
      jsonb_build_object('metric','Adjusted Free Cash Flow guidance','baseline','2026 guidance $1.20B-$1.35B','frequency','quarterly'),
      jsonb_build_object('metric','Net leverage and liquidity','baseline','Target below 3.5x net debt/Adjusted EBITDA; July 31 liquidity ~$1.9B','frequency','quarterly'),
      jsonb_build_object('metric','Data-center contracting pipeline','baseline','~4 GW land development/data-center contracting options','frequency','quarterly'),
      jsonb_build_object('metric','AWS contracted load','baseline','Revised PPA expected to provide up to 1,920 MW through 2042','frequency','event-driven')
    ),
    catalysts=jsonb_build_array(
      jsonb_build_object('catalyst','Conversion of the ~4 GW powered-land/data-center pipeline into contracts','horizon','2026-2028'),
      jsonb_build_object('catalyst','Execution of the AWS PPA ramp and additional hyperscale agreements','horizon','multi-year'),
      jsonb_build_object('catalyst','Higher PJM capacity revenues plus Cornerstone integration','horizon','2027-2029')
    ),
    invalidation_criteria=jsonb_build_array(
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','The AWS PPA is terminated or materially impaired, or a regulatory/grid ruling removes a substantial portion of the contracted economics.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Net leverage exceeds 4.0x for two consecutive reported quarters while free-cash-flow guidance is being reduced.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','The data-center pipeline fails to convert into meaningful contracted capacity over 12-18 months while medium-term EBITDA/FCF expectations are cut.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','A major prolonged reliability or regulatory event materially impairs Susquehanna or another core cash-generating asset.')
    ),
    source_reference='https://ir.talenenergy.com/news-releases/news-release-details/talen-energy-reports-second-quarter-2026-results-raises-2026',
    metadata=metadata||jsonb_build_object('baseline_version','HOLDING_BASELINE_V1','baseline_as_of','2026-09-24'),
    updated_at=now()
where ticker='TLN';

-- Seed baseline completion, current directional evidence, risk notes and reviewed SEC filings.
insert into fwios.thesis_events(event_key,ticker,event_date,event_type,direction,impact_score,thesis_dimension,summary,evidence_source,source_reference,payload)
values
('BASELINE_COMPLETE|NVDA|2026-09-24','NVDA','2026-09-24','BASELINE_COMPLETED','SYSTEM',0,'BASELINE','Explicit holding thesis baseline completed.','FWIOS','THESIS_TRACKING_V1','{"baseline_version":"HOLDING_BASELINE_V1"}'),
('EVIDENCE|NVDA|2026-08-26|Q2FY27','NVDA','2026-08-26','EARNINGS','SUPPORTS',20,'DEMAND_AND_PLATFORM','Q2 FY27 revenue was $96.2B, Data Center revenue was $89.0B, gross margin was 75%, and Q3 revenue guidance was $108B +/-2%.','NVIDIA Investor Relations','https://nvidianews.nvidia.com/news/nvidia-announces-financial-results-for-second-quarter-fiscal-2027','{"source_tier":"A","verification_status":"PASS"}'),
('SEC_REVIEW|NVDA|2026-09-03|0001045810-26-000078','NVDA','2026-09-03','SEC_REVIEW','NEUTRAL',0,'PLATFORM_AND_CAPITAL_ALLOCATION','Reviewed the September 3, 2026 Form 8-K. NVIDIA agreed to acquire Hugging Face for approximately $11.9B plus up to about $1.0B of employee retention awards. Strategic ecosystem upside is balanced by integration and regulatory execution risk until economic contribution is observable.','SEC EDGAR','https://www.sec.gov/Archives/edgar/data/1045810/000104581026000078/nvda-20260902.htm','{"accession":"0001045810-26-000078","form":"8-K","review_status":"REVIEWED","source_tier":"A"}'),
('BASELINE_COMPLETE|MSFT|2026-09-24','MSFT','2026-09-24','BASELINE_COMPLETED','SYSTEM',0,'BASELINE','Explicit holding thesis baseline completed.','FWIOS','THESIS_TRACKING_V1','{"baseline_version":"HOLDING_BASELINE_V1"}'),
('EVIDENCE|MSFT|2026-07-29|FY26Q4','MSFT','2026-07-29','EARNINGS','SUPPORTS',20,'CLOUD_AND_AI_MONETIZATION','FY26 Q4 Azure grew 43%, Microsoft Cloud revenue reached $59.3B, commercial RPO reached $678B, and Microsoft 365 Copilot exceeded 30M paid seats.','Microsoft Investor Relations','https://www.microsoft.com/en-us/investor/earnings/fy-2026-q4/press-release-webcast','{"source_tier":"A","verification_status":"PASS"}'),
('SEC_REVIEW|MSFT|2026-09-02|0001193125-26-380280','MSFT','2026-09-02','SEC_REVIEW','NEUTRAL',0,'REPORTING_STRUCTURE','Reviewed the September 2, 2026 Form 8-K. Microsoft changed its FY27 reportable segments and investor metrics; this reporting-structure change does not by itself alter the cloud/AI monetization thesis.','SEC EDGAR','https://www.sec.gov/Archives/edgar/data/789019/000119312526380280/d291965d8k.htm','{"accession":"0001193125-26-380280","form":"8-K","review_status":"REVIEWED","source_tier":"A"}'),
('BASELINE_COMPLETE|TTWO|2026-09-24','TTWO','2026-09-24','BASELINE_COMPLETED','SYSTEM',0,'BASELINE','Explicit holding thesis baseline completed.','FWIOS','THESIS_TRACKING_V1','{"baseline_version":"HOLDING_BASELINE_V1"}'),
('EVIDENCE|TTWO|2026-08-07|FY27Q1','TTWO','2026-08-07','EARNINGS','SUPPORTS',10,'GTA_VI_AND_RECURRING_BOOKINGS','Q1 FY27 Net Bookings were $1.39B, recurrent consumer spending was 84% of bookings, FY27 bookings guidance was reiterated, and GTA VI remained scheduled for November 19, 2026.','Take-Two Investor Relations','https://www.take2games.com/ir/news/take-two-interactive-software-inc-reports-results-fiscal-first-6','{"source_tier":"A","verification_status":"PASS"}'),
('SEC_REVIEW|TTWO|2026-09-22|0001628280-26-063032','TTWO','2026-09-22','SEC_REVIEW','NEUTRAL',0,'GOVERNANCE','Reviewed the September 22, 2026 Form 8-K covering annual-meeting voting results and a charter amendment. No operating, GTA VI launch, bookings, engagement or monetization thesis metric changed.','SEC EDGAR','https://www.sec.gov/Archives/edgar/data/946581/000162828026063032/ttwo-20260917.htm','{"accession":"0001628280-26-063032","form":"8-K","review_status":"REVIEWED","source_tier":"A"}'),
('BASELINE_COMPLETE|TLN|2026-09-24','TLN','2026-09-24','BASELINE_COMPLETED','SYSTEM',0,'BASELINE','Explicit holding thesis baseline completed.','FWIOS','THESIS_TRACKING_V1','{"baseline_version":"HOLDING_BASELINE_V1"}'),
('EVIDENCE|TLN|2026-08-05|Q2FY26','TLN','2026-08-05','EARNINGS','SUPPORTS',20,'FCF_AND_DATA_CENTER_OPTIONALITY','Q2 2026 results raised full-year Adjusted EBITDA guidance to $2.025B-$2.225B and Adjusted FCF guidance to $1.20B-$1.35B, with a roughly 4 GW data-center contracting pipeline.','Talen Energy Investor Relations','https://ir.talenenergy.com/news-releases/news-release-details/talen-energy-reports-second-quarter-2026-results-raises-2026','{"source_tier":"A","verification_status":"PASS"}')
on conflict(event_key) do update set summary=excluded.summary,direction=excluded.direction,impact_score=excluded.impact_score,source_reference=excluded.source_reference,payload=excluded.payload;

create or replace function fwios.refresh_thesis_health_v1(
  p_as_of_date date default current_date,p_source text default 'SYSTEM'
)
returns jsonb
language plpgsql
set search_path to ''
as $function$
declare
  v_rows int:=0;
  v_changes int:=0;
begin
  perform fwios.sync_thesis_registry_v1();

  with blockers as (
    select ticker,count(*) filter(where current_status='BLOCKED')::int blocker_count
    from fwios.blockers group by ticker
  ),
  event_agg as (
    select tr.ticker,
      coalesce(sum(e.impact_score) filter(where e.event_date between p_as_of_date-119 and p_as_of_date and e.direction in ('SUPPORTS','CONTRADICTS')),0) recent_event_score,
      count(*) filter(where e.event_date between p_as_of_date-119 and p_as_of_date and e.direction='SUPPORTS')::int support_events_120d,
      count(*) filter(where e.event_date between p_as_of_date-119 and p_as_of_date and e.direction='CONTRADICTS')::int contradict_events_120d,
      min(e.impact_score) filter(where e.event_date between p_as_of_date-119 and p_as_of_date and e.direction='CONTRADICTS') strongest_negative_120d
    from fwios.thesis_registry tr
    left join fwios.thesis_events e on e.ticker=tr.ticker
    where tr.active=true
    group by tr.ticker
  ),
  signals as (
    select tr.ticker,tr.baseline_status,tr.manual_health_override,
      rc.business_thesis_score,rc.risk_gate,rc.valuation_gate,rc.mispricing_gate,rc.promotion_gate,rc.final_decision,
      rev.revision_score,rev.revision_gate,ch.chase_risk,ch.chase_gate,
      q.overall_gate hardening_gate,q.valuation_confidence,
      coalesce(bl.blocker_count,0) blocker_count,vm.price_zone,vm.fair_value_upside,vm.system_signal,
      coalesce(ea.recent_event_score,0) recent_event_score,
      coalesce(ea.support_events_120d,0) support_events_120d,
      coalesce(ea.contradict_events_120d,0) contradict_events_120d,
      ea.strongest_negative_120d,
      exists(select 1 from fwios.thesis_events e where e.ticker=tr.ticker and e.event_type='THESIS_INVALIDATION'
        and e.direction='CONTRADICTS' and e.impact_score<=-80 and e.event_date<=p_as_of_date) explicit_invalidation
    from fwios.thesis_registry tr
    left join fwios.research_candidates rc on rc.ticker=tr.ticker
    left join fwios.v_candidate_revision_current rev on rev.ticker=tr.ticker
    left join fwios.v_candidate_chase_current ch on ch.ticker=tr.ticker
    left join fwios.v_candidate_quality_hardening_current q on q.ticker=tr.ticker
    left join blockers bl on bl.ticker=tr.ticker
    left join fwios.v_dashboard_valuation_map vm on vm.ticker=tr.ticker
    left join event_agg ea on ea.ticker=tr.ticker
    where tr.active=true
  ),
  calc as (
    select s.*,
      case
        when s.manual_health_override is not null then s.manual_health_override
        when s.explicit_invalidation then 'BROKEN'
        when s.baseline_status='BASELINE_REQUIRED' then 'BASELINE_REQUIRED'
        when coalesce(s.revision_gate,'') like 'FAIL%' or s.hardening_gate='FAIL'
          or s.recent_event_score<=-25 or coalesce(s.strongest_negative_120d,0)<=-40 then 'WEAKENING'
        when s.risk_gate='WATCH' or s.hardening_gate='REVIEW'
          or coalesce(s.revision_gate,'') like 'BLOCKED%' or coalesce(s.chase_gate,'') like 'BLOCKED%'
          or s.recent_event_score<0 then 'WATCH'
        when s.baseline_status='COMPLETE' and s.recent_event_score>=15 and coalesce(s.strongest_negative_120d,0)>-20 then 'STRONG'
        when s.baseline_status='COMPLETE' and s.revision_gate='PASS' and s.hardening_gate='PASS' and coalesce(s.risk_gate,'PASS')='PASS' then 'STRONG'
        else 'STABLE'
      end health_status,
      case when s.business_thesis_score is null then null else greatest(0,least(100,
        s.business_thesis_score
        + case when s.revision_gate='PASS' then 5 when coalesce(s.revision_gate,'') like 'FAIL%' then -20 when coalesce(s.revision_gate,'') like 'BLOCKED%' then -5 else 0 end
        + case when s.hardening_gate='PASS' then 5 when s.hardening_gate='REVIEW' then -10 when s.hardening_gate='FAIL' then -25 else 0 end
        + case when s.risk_gate='WATCH' then -5 else 0 end
        + greatest(-30,least(15,s.recent_event_score))
        + case when s.explicit_invalidation then -50 else 0 end
      )) end health_score,
      case when s.price_zone is null then 'NO VALUATION MAP'
        when s.system_signal='BUY REVIEW' then 'BUY REVIEW'
        when s.system_signal='VALUE WATCH' then 'VALUE WATCH'
        when s.system_signal='PRICE VERIFY' then 'PRICE VERIFY'
        else coalesce(s.price_zone,'NO ENTRY SIGNAL') end entry_status
    from signals s
  ),
  upserted as (
    insert into fwios.thesis_health_snapshots(
      ticker,as_of_date,health_status,health_score,thesis_score,risk_gate,revision_score,revision_gate,chase_risk,chase_gate,
      hardening_gate,valuation_confidence,valuation_gate,mispricing_gate,promotion_gate,final_decision,blocker_count,entry_status,
      health_reason,source_reference,recent_event_score,support_events_120d,contradict_events_120d,strongest_negative_120d,payload,updated_at
    )
    select c.ticker,p_as_of_date,c.health_status,c.health_score,c.business_thesis_score,c.risk_gate,c.revision_score,c.revision_gate,
      c.chase_risk,c.chase_gate,c.hardening_gate,c.valuation_confidence,c.valuation_gate,c.mispricing_gate,c.promotion_gate,c.final_decision,
      c.blocker_count,c.entry_status,
      case
        when c.health_status='BROKEN' then 'Explicit thesis invalidation event recorded.'
        when c.health_status='BASELINE_REQUIRED' then 'No explicit thesis baseline exists yet.'
        when c.health_status='WEAKENING' and coalesce(c.revision_gate,'') like 'FAIL%' then 'Negative fundamental revision is weakening the thesis.'
        when c.health_status='WEAKENING' and c.hardening_gate='FAIL' then 'Quality/durability hardening failed.'
        when c.health_status='WEAKENING' and c.recent_event_score<=-25 then 'Recent thesis evidence is materially net-negative.'
        when c.health_status='WATCH' and c.recent_event_score<0 then 'Recent thesis evidence is net-negative and requires monitoring.'
        when c.health_status='WATCH' then 'Thesis is intact but one or more monitoring gates require review or remain incomplete.'
        when c.health_status='STRONG' and c.recent_event_score>=15 then 'Recent verified evidence materially supports the completed baseline thesis.'
        else 'No explicit invalidation or material negative fundamental signal is active.' end,
      p_source,c.recent_event_score,c.support_events_120d,c.contradict_events_120d,c.strongest_negative_120d,
      jsonb_build_object('price_zone',c.price_zone,'fair_value_upside',c.fair_value_upside,'system_signal',c.system_signal,
        'health_price_separation',true,'recent_event_window_days',120),now()
    from calc c
    on conflict(ticker,as_of_date) do update set
      health_status=excluded.health_status,health_score=excluded.health_score,thesis_score=excluded.thesis_score,
      risk_gate=excluded.risk_gate,revision_score=excluded.revision_score,revision_gate=excluded.revision_gate,
      chase_risk=excluded.chase_risk,chase_gate=excluded.chase_gate,hardening_gate=excluded.hardening_gate,
      valuation_confidence=excluded.valuation_confidence,valuation_gate=excluded.valuation_gate,mispricing_gate=excluded.mispricing_gate,
      promotion_gate=excluded.promotion_gate,final_decision=excluded.final_decision,blocker_count=excluded.blocker_count,
      entry_status=excluded.entry_status,health_reason=excluded.health_reason,source_reference=excluded.source_reference,
      recent_event_score=excluded.recent_event_score,support_events_120d=excluded.support_events_120d,
      contradict_events_120d=excluded.contradict_events_120d,strongest_negative_120d=excluded.strongest_negative_120d,
      payload=excluded.payload,updated_at=now()
    returning ticker,health_status,health_score
  )
  select count(*),0 into v_rows,v_changes from upserted;

  return jsonb_build_object('as_of_date',p_as_of_date,'snapshots_refreshed',v_rows,'health_change_events',v_changes,
    'price_affects_thesis_health',false,'event_window_days',120,'broken_requires_explicit_invalidation',true);
end
$function$;

revoke all on function fwios.refresh_thesis_health_v1(date,text) from public,anon,authenticated;
grant execute on function fwios.refresh_thesis_health_v1(date,text) to service_role;

create or replace view fwios.v_thesis_sec_filing_current
with (security_invoker = true)
as
with latest_payload as (
  select distinct on (ticker) ticker,observed_at,source_url,payload
  from fwios.decision_refresh_shadow_evidence
  where fact_class='SEC_SUBMISSIONS' and collection_status='PASS'
  order by ticker,observed_at desc,created_at desc
)
select p.ticker,p.observed_at sec_checked_at,p.source_url sec_source_url,
       f.item->>'form' latest_sec_form,
       nullif(f.item->>'filing_date','')::date latest_sec_filing_date,
       f.item->>'report_date' latest_sec_report_date,
       f.item->>'accession_number' latest_sec_accession_number,
       f.item->>'primary_document' latest_sec_primary_document
from latest_payload p
left join lateral (
  select item
  from jsonb_array_elements(coalesce(p.payload->'latest_filings','[]'::jsonb)) item
  order by nullif(item->>'filing_date','')::date desc nulls last,nullif(item->>'accepted_at','') desc nulls last
  limit 1
) f on true;

revoke all on fwios.v_thesis_sec_filing_current from public,anon,authenticated;
grant select on fwios.v_thesis_sec_filing_current to service_role;

-- Keep existing thesis-tracking view contract and append SEC filing status.
-- (View definition in production preserves prior columns and appends filing fields.)

create or replace function fwios.start_decision_refresh_shadow(
  p_session_date date default fwios.decision_refresh_target_session_v1(now()),
  p_trigger_source text default 'MANUAL'
)
returns jsonb
language plpgsql
set search_path to ''
as $function$
declare
  v_run_id uuid; v_created boolean:=false; v_candidate_count integer:=0; v_sec_count integer:=0;
  v_job_count integer:=0; v_price_count integer:=0; v_price_budget integer:=15; r record;
begin
  select coalesce(price_budget,15) into v_price_budget
  from fwios.decision_refresh_api_quota_policy
  where provider_group='ALPHA_VANTAGE_SHARED' and active=true limit 1;

  select run_id into v_run_id from fwios.decision_refresh_runs where mode='SHADOW' and session_date=p_session_date;
  if v_run_id is null then
    insert into fwios.decision_refresh_runs(mode,session_date,trigger_source,status,authoritative_write,metadata)
    values('SHADOW',p_session_date,p_trigger_source,'QUEUED',false,
      jsonb_build_object('contract','AUTO_DECISION_REFRESH_V1','authoritative_write',false,'quota_aware',true,
        'price_budget',v_price_budget,'consensus_daily',false,'thesis_priority0_sec_refresh',true,
        'created_by','fwios.start_decision_refresh_shadow'))
    returning run_id into v_run_id;
    v_created:=true;
  end if;

  select count(*) into v_candidate_count from fwios.research_candidates;

  with sec_universe as (
    select ticker from fwios.research_candidates
    union
    select h.asset_symbol from fwios.v_dashboard_holdings h
    where h.account_view_key='ALL' and h.asset_class='Stock'
  ) select count(*) into v_sec_count from sec_universe;

  for r in
    with sec_universe as (
      select ticker from fwios.research_candidates
      union
      select h.asset_symbol ticker from fwios.v_dashboard_holdings h
      where h.account_view_key='ALL' and h.asset_class='Stock'
    ), ins as (
      insert into fwios.decision_refresh_jobs(run_id,ticker,job_type,status)
      select v_run_id,s.ticker,'SEC_SUBMISSIONS','QUEUED' from sec_universe s
      on conflict(run_id,ticker,job_type) do nothing returning job_id,ticker,job_type
    ) select * from ins
  loop
    perform pgmq.send('fwios_decision_refresh',jsonb_build_object('job_id',r.job_id,'run_id',v_run_id,'ticker',r.ticker,'job_type',r.job_type));
    v_job_count:=v_job_count+1;
  end loop;

  for r in
    with plan as (select * from fwios.decision_refresh_price_plan_v1(p_session_date,v_price_budget)), ins as (
      insert into fwios.decision_refresh_jobs(run_id,ticker,job_type,status)
      select v_run_id,p.ticker,'PRICE_PAIR','QUEUED' from plan p
      on conflict(run_id,ticker,job_type) do nothing returning job_id,ticker,job_type
    ) select * from ins
  loop
    perform pgmq.send('fwios_decision_refresh',jsonb_build_object('job_id',r.job_id,'run_id',v_run_id,'ticker',r.ticker,'job_type',r.job_type));
    v_job_count:=v_job_count+1; v_price_count:=v_price_count+1;
  end loop;

  update fwios.decision_refresh_runs
  set candidate_count=v_candidate_count,
      jobs_total=(select count(*) from fwios.decision_refresh_jobs where run_id=v_run_id),
      status=case when (select count(*) from fwios.decision_refresh_jobs where run_id=v_run_id)>0 then 'QUEUED' else status end,
      metadata=metadata||jsonb_build_object('price_jobs_planned',v_price_count,'sec_tickers_planned',v_sec_count,'thesis_priority0_sec_refresh',true),
      updated_at=now()
  where run_id=v_run_id;

  return jsonb_build_object('run_id',v_run_id,'created',v_created,'session_date',p_session_date,
    'candidate_count',v_candidate_count,'sec_ticker_count',v_sec_count,'new_jobs_enqueued',v_job_count,
    'price_jobs_enqueued',v_price_count,'price_budget',v_price_budget,'consensus_enqueued',false,
    'mode','SHADOW','authoritative_write',false);
end
$function$;

revoke all on function fwios.start_decision_refresh_shadow(date,text) from public,anon,authenticated;
grant execute on function fwios.start_decision_refresh_shadow(date,text) to service_role;

select fwios.refresh_thesis_health_v1(current_date,'HOLDING_BASELINE_V1_MIGRATION');
