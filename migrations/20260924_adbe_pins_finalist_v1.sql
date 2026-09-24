-- ADBE + PINS Finalist Research V1
-- Complete full thesis baselines, seed balanced evidence, and add traceable ADBE revision consensus evidence.
-- Price verification remains fail-closed. No portfolio mutation or auto-trading.

update fwios.thesis_registry
set baseline_status='COMPLETE',
    baseline_completeness=1,
    thesis_statement='Adobe can sustain durable low-double-digit recurring-revenue and cash-flow growth by monetizing AI across Creative, Acrobat and Customer Experience while its installed base, workflow integration and enterprise distribution defend platform economics. The thesis requires AI monetization to be incremental rather than materially cannibalizing core subscription economics.',
    must_remain_true=jsonb_build_array(
      jsonb_build_object('id','ADBE-MRT-1','statement','Total Adobe ARR and subscription revenue sustain at least high-single-digit growth through the AI transition.'),
      jsonb_build_object('id','ADBE-MRT-2','statement','AI-first products convert usage into paid ARR and expand customer value without causing sustained core-product churn or pricing compression.'),
      jsonb_build_object('id','ADBE-MRT-3','statement','Adobe preserves premium software economics, including strong operating margins and cash conversion, despite higher AI inference and model costs.'),
      jsonb_build_object('id','ADBE-MRT-4','statement','Creative & Marketing Professionals and Business Professionals & Consumers both remain durable growth engines rather than growth becoming dependent on a single product family.'),
      jsonb_build_object('id','ADBE-MRT-5','statement','The December 2026 CEO transition is orderly and does not trigger a material strategic or execution reset.')
    ),
    monitoring_kpis=jsonb_build_array(
      jsonb_build_object('metric','Total Adobe revenue growth','baseline','Q3 FY26 $6.76B; +13% YoY','frequency','quarterly'),
      jsonb_build_object('metric','Total Adobe ending ARR','baseline','Q3 FY26 $27.50B; +11.2% YoY','frequency','quarterly'),
      jsonb_build_object('metric','AI-first ARR growth','baseline','Q3 FY26 >150% YoY','frequency','quarterly'),
      jsonb_build_object('metric','Customer Group subscription revenue','baseline','Q3 FY26 $6.56B; +14% YoY','frequency','quarterly'),
      jsonb_build_object('metric','Cash flow from operations','baseline','Q3 FY26 $2.52B','frequency','quarterly'),
      jsonb_build_object('metric','RPO / cRPO','baseline','Q3 FY26 RPO $22.16B; cRPO 67%','frequency','quarterly'),
      jsonb_build_object('metric','Monthly active users','baseline','>1B creativity and productivity MAU','frequency','quarterly / event-driven')
    ),
    catalysts=jsonb_build_array(
      jsonb_build_object('catalyst','Conversion of AI-first usage into incremental paid ARR across Creative, Acrobat and CX','horizon','FY27-FY28'),
      jsonb_build_object('catalyst','Raised FY26 targets and Q4 execution','horizon','Q4 FY26'),
      jsonb_build_object('catalyst','Anil Chakravarthy CEO transition with continuity from Shantanu Narayen as Executive Chair','date','2026-12-01'),
      jsonb_build_object('catalyst','Expansion of agentic and productivity workflows across Acrobat and enterprise CX','horizon','multi-year')
    ),
    invalidation_criteria=jsonb_build_array(
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Total Adobe ARR growth falls below 7% year over year for two consecutive quarters while AI-first ARR growth also materially decelerates.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Customer Group subscription revenue growth falls below 7% for two consecutive quarters because of churn, price compression or AI-native competitive displacement.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Non-GAAP operating margin remains below 35% for two consecutive quarters because AI infrastructure or competitive costs structurally impair software economics.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Management cuts forward annual revenue or ARR expectations by more than 10% for execution reasons while core retention/monetization indicators deteriorate.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','CEO transition produces a material strategic reset accompanied by sustained customer churn, sales disruption or repeated guidance reductions.')
    ),
    source_reference='https://news.adobe.com/news/2026/09/adobe-q3fy26-financial-results',
    metadata=metadata||jsonb_build_object(
      'baseline_version','FINALIST_BASELINE_V1','baseline_as_of','2026-09-24',
      'finalist_round',1,'finalist_status','FULL_THESIS_COMPLETE','price_gate_bypass_allowed',false
    ),
    updated_at=now()
where ticker='ADBE';

update fwios.thesis_registry
set baseline_status='COMPLETE',
    baseline_completeness=1,
    thesis_statement='Pinterest can compound revenue and free cash flow by combining a growing high-intent visual-discovery audience with AI-driven performance advertising, better international monetization and disciplined per-share capital allocation. The thesis requires revenue and ARPU growth to outpace user growth while stock-based compensation does not absorb the underlying owner economics.',
    must_remain_true=jsonb_build_array(
      jsonb_build_object('id','PINS-MRT-1','statement','Global MAUs remain healthy and Pinterest continues to attract high-intent commercial discovery use cases.'),
      jsonb_build_object('id','PINS-MRT-2','statement','Revenue and ARPU grow faster than the user base as Performance+, visual search and lower-funnel products improve advertiser ROI.'),
      jsonb_build_object('id','PINS-MRT-3','statement','Adjusted EBITDA and free cash flow scale faster than revenue over time rather than growth being consumed by operating expense.'),
      jsonb_build_object('id','PINS-MRT-4','statement','International monetization, especially Rest of World, continues to improve from a low ARPU base.'),
      jsonb_build_object('id','PINS-MRT-5','statement','Share repurchases offset dilution and stock-based compensation trends toward a sustainable percentage of revenue.'),
      jsonb_build_object('id','PINS-MRT-6','statement','The CFO transition is orderly and does not reveal accounting, control or capital-allocation problems.')
    ),
    monitoring_kpis=jsonb_build_array(
      jsonb_build_object('metric','Revenue growth','baseline','Q2 2026 $1.180B; +18% YoY','frequency','quarterly'),
      jsonb_build_object('metric','Global MAUs','baseline','Q2 2026 640M; +11% YoY','frequency','quarterly'),
      jsonb_build_object('metric','Global ARPU','baseline','Q2 2026 $1.86; +7% YoY','frequency','quarterly'),
      jsonb_build_object('metric','US & Canada ARPU','baseline','Q2 2026 $8.30; +14% YoY','frequency','quarterly'),
      jsonb_build_object('metric','Rest of World ARPU','baseline','Q2 2026 $0.23; +21% YoY','frequency','quarterly'),
      jsonb_build_object('metric','Adjusted EBITDA margin','baseline','Q2 2026 26%; Adjusted EBITDA $311M','frequency','quarterly'),
      jsonb_build_object('metric','Free cash flow','baseline','Q2 2026 $270M; +37% YoY','frequency','quarterly'),
      jsonb_build_object('metric','Stock-based compensation / revenue','baseline','Q2 2026 SBC $324.5M; about 27.5% of revenue','frequency','quarterly'),
      jsonb_build_object('metric','Share repurchases','baseline','> $2B repurchased YTD through Q2 at average $18.17','frequency','quarterly')
    ),
    catalysts=jsonb_build_array(
      jsonb_build_object('catalyst','Visual Search Ads beta and broader lower-funnel monetization','horizon','2H 2026-2027'),
      jsonb_build_object('catalyst','Performance+ product improvements and advertiser ROI gains','horizon','multi-year'),
      jsonb_build_object('catalyst','International ARPU convergence from a low base','horizon','multi-year'),
      jsonb_build_object('catalyst','Share repurchases below assessed intrinsic value','horizon','ongoing'),
      jsonb_build_object('catalyst','Q3 2026 revenue / EBITDA execution versus guidance','horizon','next earnings')
    ),
    invalidation_criteria=jsonb_build_array(
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Revenue growth falls below 10% for two consecutive quarters while global MAU growth is below 5%, indicating both engagement and monetization slowdown.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Global ARPU declines year over year for two consecutive quarters despite positive MAU growth, showing monetization failure.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Adjusted EBITDA margin remains below 20% for two consecutive quarters while revenue growth is below 12%, indicating weak operating leverage.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Stock-based compensation remains above 30% of revenue for two consecutive quarters and diluted share count does not decline despite material repurchases.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','Visual/performance advertising products fail to improve monetization and management materially cuts medium-term revenue or margin expectations.'),
      jsonb_build_object('severity','BROKEN_CANDIDATE','criterion','CFO transition is followed by a material control, accounting or financial-reporting issue.')
    ),
    source_reference='https://www.sec.gov/Archives/edgar/data/1506293/000150629326000102/q2-26xpressrelease.htm',
    metadata=metadata||jsonb_build_object(
      'baseline_version','FINALIST_BASELINE_V1','baseline_as_of','2026-09-24',
      'finalist_round',1,'finalist_status','FULL_THESIS_COMPLETE','price_gate_bypass_allowed',false
    ),
    updated_at=now()
where ticker='PINS';

insert into fwios.thesis_events(
  event_key,ticker,event_date,event_type,direction,impact_score,thesis_dimension,
  summary,evidence_source,source_reference,payload
)
values
('BASELINE_COMPLETE|ADBE|2026-09-24|FINALIST_V1','ADBE',date '2026-09-24','BASELINE_COMPLETED','SYSTEM',0,'BASELINE',
 'Finalist full thesis baseline completed with explicit must-remain-true conditions, KPI monitoring, catalysts and invalidation criteria.',
 'FWIOS','FINALIST_BASELINE_V1',jsonb_build_object('baseline_version','FINALIST_BASELINE_V1','finalist_round',1)),
('EVIDENCE|ADBE|2026-09-10|Q3FY26','ADBE',date '2026-09-10','EARNINGS','SUPPORTS',20,'AI_MONETIZATION_AND_CASH_FLOW',
 'Q3 FY26 revenue reached $6.76B (+13% YoY), ending ARR was $27.50B (+11.2%), AI-first ARR grew more than 150%, Customer Group subscription revenue grew 14%, operating cash flow was $2.52B, and Adobe raised full-year revenue and EPS targets.',
 'Adobe Investor Relations / SEC','https://news.adobe.com/news/2026/09/adobe-q3fy26-financial-results',
 jsonb_build_object('source_tier','A','verification_status','PASS','form','8-K','accession','0000796343-26-000147')),
('EVIDENCE|ADBE|2026-09-03|CEO_TRANSITION','ADBE',date '2026-09-03','MANAGEMENT_CHANGE','NEUTRAL',0,'MANAGEMENT_EXECUTION',
 'Adobe announced Anil Chakravarthy will become CEO on December 1, 2026 while Shantanu Narayen becomes Executive Chair. The planned transition adds execution monitoring but does not by itself contradict the operating thesis.',
 'Adobe Newsroom','https://news.adobe.com/news/2026/09/adobe-announces-anil-chakravarthy-to-become-president-and-ceo',
 jsonb_build_object('source_tier','A','verification_status','PASS')),
('SEC_REVIEW|ADBE|2026-09-22|0000796343-26-000156','ADBE',date '2026-09-22','SEC_REVIEW','NEUTRAL',0,'FINANCIAL_REPORTING',
 'Latest Q3 FY26 Form 10-Q filing was reconciled to the already-reviewed Q3 earnings evidence. No new headline contradiction to the finalist thesis was identified; ongoing risk-factor changes remain part of continuous monitoring.',
 'SEC EDGAR','https://www.sec.gov/Archives/edgar/data/796343/000079634326000156/adbe-20260828.htm',
 jsonb_build_object('accession','0000796343-26-000156','form','10-Q','review_status','REVIEWED','source_tier','A')),
('BASELINE_COMPLETE|PINS|2026-09-24|FINALIST_V1','PINS',date '2026-09-24','BASELINE_COMPLETED','SYSTEM',0,'BASELINE',
 'Finalist full thesis baseline completed with explicit must-remain-true conditions, KPI monitoring, catalysts and invalidation criteria.',
 'FWIOS','FINALIST_BASELINE_V1',jsonb_build_object('baseline_version','FINALIST_BASELINE_V1','finalist_round',1)),
('EVIDENCE|PINS|2026-08-04|Q2FY26','PINS',date '2026-08-04','EARNINGS','SUPPORTS',15,'AUDIENCE_MONETIZATION_AND_FCF',
 'Q2 2026 revenue reached $1.180B (+18% YoY), global MAUs reached 640M (+11%), Adjusted EBITDA was $311M with 26% margin, and free cash flow was $270M (+37%). Q3 revenue guidance called for 13%-15% growth.',
 'Pinterest Investor Relations / SEC','https://www.sec.gov/Archives/edgar/data/1506293/000150629326000102/q2-26xpressrelease.htm',
 jsonb_build_object('source_tier','A','verification_status','PASS','form','8-K','accession','0001506293-26-000102')),
('EVIDENCE|PINS|2026-08-04|SBC_OWNER_ECONOMICS','PINS',date '2026-08-04','OWNER_EARNINGS_REVIEW','CONTRADICTS',-5,'DILUTION_AND_OWNER_EARNINGS',
 'Q2 share-based compensation was $324.5M, about 27.5% of revenue. Large repurchases offset dilution and reduced shares, but the compensation burden remains material and requires continued owner-earnings monitoring.',
 'Pinterest SEC 10-Q','https://www.sec.gov/Archives/edgar/data/1506293/000150629326000104/pins-20260630.htm',
 jsonb_build_object('source_tier','A','verification_status','PASS','sbc_millions',324.5,'revenue_millions',1179.654)),
('EVIDENCE|PINS|2026-09-17|VISUAL_SEARCH_ADS','PINS',date '2026-09-17','PRODUCT_CATALYST','SUPPORTS',5,'AD_MONETIZATION',
 'Pinterest introduced Visual Search Ads for lower-funnel objectives. The product is a credible monetization catalyst because Pinterest reports more than 80B searches per month, most visual and more than half commercial, but revenue impact is not yet proven.',
 'Pinterest Newsroom','https://newsroom.pinterest.com/en-AU/news/new-pinterest-visual-search-performance-ads/',
 jsonb_build_object('source_tier','A','verification_status','PASS','commercial_impact_status','UNPROVEN')),
('SEC_REVIEW|PINS|2026-08-28|0001506293-26-000117','PINS',date '2026-08-28','SEC_REVIEW','NEUTRAL',0,'MANAGEMENT_EXECUTION',
 'Reviewed the August 28, 2026 Form 8-K. CFO Julia Brau Donnelly resigned to pursue another opportunity and will remain through October 30 for transition; the filing states the departure was not due to disagreement with company operations, policies or accounting practices. Interim finance leadership is in place while an external search proceeds.',
 'SEC EDGAR','https://www.sec.gov/Archives/edgar/data/1506293/000150629326000117/pins-20260826.htm',
 jsonb_build_object('accession','0001506293-26-000117','form','8-K','items','5.02','review_status','REVIEWED','source_tier','A'))
on conflict(event_key) do update set
 direction=excluded.direction,impact_score=excluded.impact_score,summary=excluded.summary,
 evidence_source=excluded.evidence_source,source_reference=excluded.source_reference,payload=excluded.payload;

insert into fwios.candidate_revision_snapshots(
  revision_snapshot_id,ticker,earnings_date,official_earnings_freshness,
  guidance_score,consensus_snapshot_state,consensus_comparable,consensus_revision_pct,consensus_score,
  kpi_acceleration_score,margin_fcf_score,revision_score,component_coverage,
  consensus_gate,revision_freshness_gate,revision_gate,
  official_source_reference,consensus_source_reference,comparability_note,next_required_evidence,
  policy_version_id,component_input_ids
)
values(
  'REV-ADBE-Q3-2026-FINALIST-PARTIAL','ADBE',date '2026-09-10','PASS',
  null,'TRACEABLE PRE/POST FY2026 EPS CONSENSUS',true,
  ((24.39/24.31)-1)*100,
  fwios.score_revision_delta_v1(((24.39/24.31)-1)*100),
  null,null,null,0.25,
  'PASS - COMPARABLE CONSENSUS EVIDENCE','PASS','BLOCKED - COMPONENT SCORING INCOMPLETE',
  'Adobe Q3 FY2026 release + SEC 8-K/10-Q',
  'Zacks 2026-09-01 FY2026 EPS consensus $24.31; Zacks 2026-09-14 FY2026 EPS consensus $24.39',
  'Same-provider, same-metric, same-fiscal-period Zacks FY2026 EPS consensus is traceable across the Q3 event. The revision remains fail-closed because guidance-surprise, ARR acceleration and margin/FCF component inputs are not all present under the cross-sector contract.',
  'Collect pre-event Q4 FY26 revenue consensus for guidance surprise; calculate registered ARR growth acceleration; calculate non-GAAP operating-margin and FCF-margin YoY deltas.',
  'POL-REVISION-SCORE-V2-CROSS-SECTOR',
  array['ZACKS-ADBE-FY26-EPS-20260901','ZACKS-ADBE-FY26-EPS-20260914']::text[]
)
on conflict(revision_snapshot_id) do update set
  consensus_revision_pct=excluded.consensus_revision_pct,
  consensus_score=excluded.consensus_score,
  comparability_note=excluded.comparability_note,
  next_required_evidence=excluded.next_required_evidence,
  created_at=now();

select fwios.refresh_thesis_health_v1(date '2026-09-24','FINALIST_ADBE_PINS_V1');
select fwios.refresh_opportunity_quality_v2(date '2026-09-24','FINALIST_ADBE_PINS_V1');
