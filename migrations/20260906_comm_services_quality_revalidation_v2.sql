-- Communication Services Quality-Hardening revalidation v2
-- Data-only production snapshot materialization. No policy semantics, holdings or trades are changed.
-- Goal: prove the hardening layer distinguishes business quality from valuation attractiveness.

begin;

-- Primary-source hardening evidence: Pinterest multi-year durability and owner economics.
insert into fwios.evidence_records(
  evidence_id,ticker,retrieved_at_text,evidence_date_text,period,data_type,metric_label,value_text,unit,
  source_tier,source_url,evidence_role,evidence_class,confidence,comparable_status,conflict_status,
  verification_status,freshness_status,used_by,retrieval_method,machine_status,metric_id,canonical_value_type,
  canonical_metric_gate,raw_payload
) values
('QH-PINS-FY22-REV-20260906','PINS','2026-09-06','2022-12-31','FY2022','FINANCIAL','Revenue FY2022','2802.574','USD M','PRIMARY','https://www.sec.gov/Archives/edgar/data/1506293/000150629325000022/pins-20241231.htm','QUALITY_HARDENING','DURABILITY','HIGH','COMPARABLE','NONE','VERIFIED','HISTORICAL_REFERENCE','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','revenue_fy2022','REPORTED','PASS','{"source_scope":"2024 10-K comparative statement"}'::jsonb),
('QH-PINS-FY23-REV-20260906','PINS','2026-09-06','2023-12-31','FY2023','FINANCIAL','Revenue FY2023','3055.071','USD M','PRIMARY','https://www.sec.gov/Archives/edgar/data/1506293/000150629325000022/pins-20241231.htm','QUALITY_HARDENING','DURABILITY','HIGH','COMPARABLE','NONE','VERIFIED','HISTORICAL_REFERENCE','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','revenue_fy2023','REPORTED','PASS','{"source_scope":"2024 10-K comparative statement"}'::jsonb),
('QH-PINS-FY24-REV-20260906','PINS','2026-09-06','2024-12-31','FY2024','FINANCIAL','Revenue FY2024','3646.166','USD M','PRIMARY','https://www.sec.gov/Archives/edgar/data/1506293/000150629325000022/pins-20241231.htm','QUALITY_HARDENING','DURABILITY','HIGH','COMPARABLE','NONE','VERIFIED','HISTORICAL_REFERENCE','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','revenue_fy2024','REPORTED','PASS','{"source_scope":"2024 10-K"}'::jsonb),
('QH-PINS-FY25-REV-20260906','PINS','2026-09-06','2025-12-31','FY2025','FINANCIAL','Revenue FY2025','4221.767','USD M','PRIMARY','https://www.sec.gov/Archives/edgar/data/1506293/000150629326000021/pins-20251231.htm','QUALITY_HARDENING','DURABILITY','HIGH','COMPARABLE','NONE','VERIFIED','HISTORICAL_REFERENCE','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','revenue_fy2025','REPORTED','PASS','{"source_scope":"2025 10-K"}'::jsonb),
('QH-PINS-FY24-MAU-20260906','PINS','2026-09-06','2024-12-31','FY2024','OPERATING_KPI','Monthly active users FY2024','553','M users','PRIMARY','https://www.sec.gov/Archives/edgar/data/1506293/000150629325000022/pins-20241231.htm','QUALITY_HARDENING','DURABILITY','HIGH','COMPARABLE','NONE','VERIFIED','HISTORICAL_REFERENCE','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','mau_fy2024','REPORTED','PASS','{}'::jsonb),
('QH-PINS-FY25-MAU-20260906','PINS','2026-09-06','2025-12-31','FY2025','OPERATING_KPI','Monthly active users FY2025','619','M users','PRIMARY','https://www.sec.gov/Archives/edgar/data/1506293/000150629326000021/pins-20251231.htm','QUALITY_HARDENING','DURABILITY','HIGH','COMPARABLE','NONE','VERIFIED','HISTORICAL_REFERENCE','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','mau_fy2025','REPORTED','PASS','{}'::jsonb),
('QH-PINS-Q2-26-USER-STREAK-20260906','PINS','2026-09-06','2026-06-30','Q2 2026','OPERATING_KPI','Consecutive quarters of double-digit user growth','11','quarters','PRIMARY','https://www.sec.gov/Archives/edgar/data/1506293/000150629326000102/q2-26xpressrelease.htm','QUALITY_HARDENING','DURABILITY','HIGH','COMPARABLE','NONE','VERIFIED','CURRENT','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','user_growth_streak','REPORTED','PASS','{}'::jsonb),
('QH-PINS-H1-26-SBC-20260906','PINS','2026-09-06','2026-06-30','H1 2026','FINANCIAL','Share-based compensation H1 2026','555.963','USD M','PRIMARY','https://www.sec.gov/Archives/edgar/data/1506293/000150629326000104/pins-20260630.htm','QUALITY_HARDENING','OWNER_EARNINGS','HIGH','COMPARABLE','NONE','VERIFIED','CURRENT','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','sbc_h1_2026','REPORTED','PASS','{}'::jsonb),
('QH-PINS-H1-26-FCF-20260906','PINS','2026-09-06','2026-06-30','H1 2026','FINANCIAL','Free cash flow H1 2026','581.6','USD M','PRIMARY','https://www.sec.gov/Archives/edgar/data/1506293/000150629326000104/pins-20260630.htm','QUALITY_HARDENING','OWNER_EARNINGS','HIGH','COMPARABLE','NONE','VERIFIED','CURRENT','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','fcf_h1_2026','REPORTED','PASS','{}'::jsonb),
('QH-PINS-Q2-25-SHARES-20260906','PINS','2026-09-06','2025-06-30','Q2 2025','CAPITAL_STRUCTURE','Common shares outstanding Q2 2025','679.422','M shares','PRIMARY','https://www.sec.gov/Archives/edgar/data/1506293/000150629326000104/pins-20260630.htm','QUALITY_HARDENING','OWNER_EARNINGS','HIGH','COMPARABLE','NONE','VERIFIED','HISTORICAL_REFERENCE','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','shares_q2_2025','REPORTED','PASS','{}'::jsonb),
('QH-PINS-Q2-26-SHARES-20260906','PINS','2026-09-06','2026-06-30','Q2 2026','CAPITAL_STRUCTURE','Common shares outstanding Q2 2026','565.497','M shares','PRIMARY','https://www.sec.gov/Archives/edgar/data/1506293/000150629326000104/pins-20260630.htm','QUALITY_HARDENING','OWNER_EARNINGS','HIGH','COMPARABLE','NONE','VERIFIED','CURRENT','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','shares_q2_2026','REPORTED','PASS','{}'::jsonb),
('QH-PINS-H1-26-BUYBACK-20260906','PINS','2026-09-06','2026-06-30','H1 2026','CAPITAL_ALLOCATION','Class A common stock repurchases H1 2026','2039.825','USD M','PRIMARY','https://www.sec.gov/Archives/edgar/data/1506293/000150629326000104/pins-20260630.htm','QUALITY_HARDENING','OWNER_EARNINGS','HIGH','COMPARABLE','NONE','VERIFIED','CURRENT','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','buybacks_h1_2026','REPORTED','PASS','{"interpretation":"buybacks materially exceed H1 FCF; dilution is offset but cash sustainability requires review"}'::jsonb),

-- Reddit verified alternative durability anchor and owner-economics reconciliation.
('QH-RDDT-Q2-26-REV-STREAK-20260906','RDDT','2026-09-06','2026-06-30','Q2 2026','OPERATING_KPI','Consecutive quarters with revenue growth above 60%','8','quarters','PRIMARY','https://investor.redditinc.com/news-events/news-releases/news-details/2026/Reddit-Reports-Second-Quarter-2026-Results/default.aspx','QUALITY_HARDENING','DURABILITY','HIGH','COMPARABLE','NONE','VERIFIED','CURRENT','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','revenue_growth_streak','REPORTED','PASS','{"alternative_durability_anchor":true}'::jsonb),
('QH-RDDT-H1-26-SBC-20260906','RDDT','2026-09-06','2026-06-30','H1 2026','FINANCIAL','Stock-based compensation and related taxes H1 2026','185.684','USD M','PRIMARY','https://www.sec.gov/Archives/edgar/data/1713445/000171344526000098/exhibit992q226.htm','QUALITY_HARDENING','OWNER_EARNINGS','HIGH','COMPARABLE','NONE','VERIFIED','CURRENT','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','sbc_h1_2026','REPORTED','PASS','{}'::jsonb),
('QH-RDDT-H1-26-FCF-20260906','RDDT','2026-09-06','2026-06-30','H1 2026','FINANCIAL','Free cash flow H1 2026','571.905','USD M','PRIMARY','https://www.sec.gov/Archives/edgar/data/1713445/000171344526000098/exhibit992q226.htm','QUALITY_HARDENING','OWNER_EARNINGS','HIGH','COMPARABLE','NONE','VERIFIED','CURRENT','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','fcf_h1_2026','REPORTED','PASS','{}'::jsonb),
('QH-RDDT-Q2-26-SHARE-GROWTH-20260906','RDDT','2026-09-06','2026-06-30','Q2 2026','CAPITAL_STRUCTURE','Fully diluted share count growth YoY','0.2','PCT','PRIMARY','https://investor.redditinc.com/news-events/news-releases/news-details/2026/Reddit-Reports-Second-Quarter-2026-Results/default.aspx','QUALITY_HARDENING','OWNER_EARNINGS','HIGH','COMPARABLE','NONE','VERIFIED','CURRENT','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','diluted_share_growth_yoy','REPORTED','PASS','{}'::jsonb),
('QH-RDDT-Q2-26-BUYBACK-20260906','RDDT','2026-09-06','2026-06-30','Q2 2026','CAPITAL_ALLOCATION','Share repurchases Q2 2026','235','USD M','PRIMARY','https://investor.redditinc.com/news-events/news-releases/news-details/2026/Reddit-Reports-Second-Quarter-2026-Results/default.aspx','QUALITY_HARDENING','OWNER_EARNINGS','HIGH','COMPARABLE','NONE','VERIFIED','CURRENT','POL-QUALITY-HARDENING-V1','WEB_PRIMARY','PASS','buybacks_q2_2026','REPORTED','PASS','{}'::jsonb)
on conflict (evidence_id) do nothing;

-- New immutable hardening snapshots. V1 remains audit history.
insert into fwios.candidate_quality_hardening_snapshots(
  hardening_snapshot_id,ticker,valuation_run_id,mispricing_snapshot_id,policy_version_id,
  business_durability_gate,owner_earnings_gate,value_trap_gate,valuation_robustness_gate,overall_gate,
  valuation_confidence,sbc_to_revenue,bear_upside,base_upside,probability_weighted_upside,
  durability_anchor_years,durability_evidence_count,dilution_reconciliation_pass,owner_fcf_conversion_pass,
  counter_thesis_evidence_count,structural_risk_review_pass,growth_anchor_verified,evidence_payload,source_reference
) values
('HARD-PINS-20260906-V2','PINS','VAL-SUPA-PINS-DIGADS-20260905','MIS-PINS-20260904','POL-QUALITY-HARDENING-V1',
 'PASS','REVIEW','REVIEW','REVIEW','REVIEW',0.7750,0.22428200152774977,0.248517285009861933,1.002070832840236686,1.169740764669625247,
 3,12,true,false,3,true,true,
 '{"durability":{"status":"PASS","evidence":"FY2022-FY2025 revenue rises from 2.803B to 4.222B (~14.6% CAGR) plus 11 consecutive quarters of double-digit user growth"},"owner_earnings":{"status":"REVIEW","evidence":"H1 FCF 581.6M vs SBC 555.963M; shares fell 679.422M to 565.497M YoY but H1 repurchases of 2.040B materially exceed H1 FCF"},"value_trap":{"status":"REVIEW","evidence":"extreme modeled mispricing remains; high SBC, GAAP losses and monetization/competition risks provide counter-thesis but do not prove market mispricing is wrong"},"valuation_robustness":{"status":"REVIEW","evidence":"durability anchor now exists, but original 14.5% five-year FCF growth and headline FCF remain sensitive to owner-economics assumptions"},"historical_price_role":"review_trigger_only"}'::jsonb,
 'Communication Services hardening revalidation v2; primary SEC evidence 2022-2026'),
('HARD-RDDT-20260906-V2','RDDT','VAL-SUPA-RDDT-DIGADS-20260905','MIS-RDDT-20260904','POL-QUALITY-HARDENING-V1',
 'PASS','PASS','PASS','REVIEW','REVIEW',0.9250,0.1216279921722564,-0.403697050390852122,-0.078761705471929711,-0.006369090170553653,
 2,8,true,true,0,true,true,
 '{"durability":{"status":"PASS","alternative_anchor_verified":true,"evidence":"8 consecutive quarters of >60% revenue growth; Q2 2026 revenue +61%, ad revenue +64%, DAUq +18%"},"owner_earnings":{"status":"PASS","evidence":"H1 FCF 571.905M vs SBC+tax 185.684M; diluted shares +0.2% YoY and Q2 buybacks 235M"},"value_trap":{"status":"PASS","evidence":"extreme-mispricing trigger not hit"},"valuation_robustness":{"status":"REVIEW","evidence":"bear-case downside ~40.4%, within policy review territory (-30% to -50%)"}}'::jsonb,
 'Communication Services hardening revalidation v2; Reddit IR + SEC Q2 2026')
on conflict (hardening_snapshot_id) do nothing;

-- Recomputed confidence-adjusted scores, preserving 30/30/25/15 weights.
insert into fwios.candidate_decision_scores(
 score_snapshot_id,ticker,scoring_policy_id,valuation_run_id,mispricing_snapshot_id,portfolio_fit_snapshot_id,
 business_thesis_score,expected_return_score,portfolio_fit_score,downside_risk_score,core_score,
 quality_gate,valuation_gate,mispricing_gate,portfolio_gate,downside_gate,revision_gate,chase_gate,core_scoring_gate,
 promotion_gate,decision_state,decision_note,source_reference,hardening_snapshot_id,valuation_confidence,hardening_gate
) values
('SCORE-PINS-QH-20260906-V2','PINS','FWB-DATA-SCORING-V3-DURABILITY','VAL-SUPA-PINS-DIGADS-20260905','MIS-PINS-20260904','FIT-PINS-PORTFOLIO-M2-20260905-01',
 82,77.5000,90,70,80.8500,'PASS','PASS','PASS','PASS','PASS','PASS','PASS','PASS',
 'REVIEW - QUALITY HARDENING','MODEL REVIEW - OWNER ECONOMICS / VALUE TRAP / ROBUSTNESS',
 'PINS now clears Business Durability with verified multi-year evidence, but owner economics, extreme-mispricing counter-thesis and valuation robustness remain REVIEW. High numerical upside cannot promote it to Immediate.',
 'POL-DATA-SCORING-V3-DURABILITY + HARD-PINS-20260906-V2 + MIS-PINS-20260904','HARD-PINS-20260906-V2',0.7750,'REVIEW'),
('SCORE-RDDT-QH-20260906-V2','RDDT','FWB-DATA-SCORING-V3-DURABILITY','VAL-SUPA-RDDT-DIGADS-20260905','MIS-RDDT-20260904','FIT-RDDT-PORTFOLIO-M2-20260905-01',
 88,41.6431,90,65,71.1429,'PASS','PASS','FAIL - INSUFFICIENT MISPRICING','PASS','PASS','PASS','PASS','PASS',
 'FAIL - INSUFFICIENT MISPRICING','GOOD COMPANY - WAIT FOR VALUE',
 'RDDT clears durability, owner earnings and value-trap quality tests; valuation robustness remains REVIEW due bear downside. Current price still fails the mispricing hurdle, so it remains Value-Wait.',
 'POL-DATA-SCORING-V3-DURABILITY + HARD-RDDT-20260906-V2 + MIS-RDDT-20260904','HARD-RDDT-20260906-V2',0.9250,'REVIEW')
on conflict (score_snapshot_id) do nothing;

insert into fwios.decision_snapshots(
 decision_snapshot_id,ticker,portfolio_batch_id,price_snapshot_id,valuation_run_id,mispricing_snapshot_id,
 portfolio_fit_snapshot_id,revision_snapshot_id,chase_snapshot_id,score_snapshot_id,
 scoring_policy_version_id,revision_policy_version_id,chase_policy_version_id,
 core_score,decision_state,promotion_gate,input_integrity_gate,decision_payload,hardening_snapshot_id
) values
('DEC-PINS-QH-20260906-V2','PINS','PORTFOLIO-M2-20260905-01','PX-PINS-20260904','VAL-SUPA-PINS-DIGADS-20260905','MIS-PINS-20260904',
 'FIT-PINS-PORTFOLIO-M2-20260905-01','REV-PINS-Q2-2026-M2-V1','CHASE-PINS-20260904-M2-V1','SCORE-PINS-QH-20260906-V2',
 'POL-DATA-SCORING-V3-DURABILITY','POL-REVISION-SCORE-V1','POL-CHASE-SCORE-V1',80.8500,
 'MODEL REVIEW - OWNER ECONOMICS / VALUE TRAP / ROBUSTNESS','REVIEW - QUALITY HARDENING','PASS',
 '{"mispricing_gate":"PASS","hardening_gate":"REVIEW","valuation_confidence":0.775,"business_durability_gate":"PASS","owner_earnings_gate":"REVIEW","value_trap_gate":"REVIEW","valuation_robustness_gate":"REVIEW","quality_interpretation":"durable business evidence exists but owner economics and valuation thesis are not clean enough for Immediate","historical_price_role":"review_trigger_only","human_execution_only":true,"pretrade_price_verification_required":true}'::jsonb,
 'HARD-PINS-20260906-V2'),
('DEC-RDDT-QH-20260906-V2','RDDT','PORTFOLIO-M2-20260905-01','PX-RDDT-20260904','VAL-SUPA-RDDT-DIGADS-20260905','MIS-RDDT-20260904',
 'FIT-RDDT-PORTFOLIO-M2-20260905-01','REV-RDDT-Q2-2026-M2-V1','CHASE-RDDT-20260904-M2-V1','SCORE-RDDT-QH-20260906-V2',
 'POL-DATA-SCORING-V3-DURABILITY','POL-REVISION-SCORE-V1','POL-CHASE-SCORE-V1',71.1429,
 'GOOD COMPANY - WAIT FOR VALUE','FAIL - INSUFFICIENT MISPRICING','PASS',
 '{"mispricing_gate":"FAIL - INSUFFICIENT MISPRICING","hardening_gate":"REVIEW","valuation_confidence":0.925,"business_durability_gate":"PASS","owner_earnings_gate":"PASS","value_trap_gate":"PASS","valuation_robustness_gate":"REVIEW","quality_interpretation":"high-quality operating profile separated from unattractive current valuation","human_execution_only":true}'::jsonb,
 'HARD-RDDT-20260906-V2')
on conflict (decision_snapshot_id) do nothing;

insert into fwios.opportunity_ranking_runs(ranking_run_id,policy_version_id,portfolio_batch_id,status,source_reference,completed_at)
values ('OPPRANK-QH-REVAL-20260906-02','POL-OPPORTUNITY-RANKING-V2','PORTFOLIO-M2-20260905-01','PASS',
        'Communication Services Quality-Hardening revalidation v2: quality-vs-valuation separation',now())
on conflict (ranking_run_id) do nothing;

insert into fwios.opportunity_ranked_candidates(
 ranking_candidate_id,ranking_run_id,ticker,decision_snapshot_id,score_snapshot_id,opportunity_bucket,bucket_rank,
 priority_score,expected_return_score,portfolio_fit_score,downside_risk_score,business_thesis_score,
 eligibility_gate,rationale_code,source_reference
) values
('RANK-QH2-PINS-20260906-01','OPPRANK-QH-REVAL-20260906-02','PINS','DEC-PINS-QH-20260906-V2','SCORE-PINS-QH-20260906-V2',
 'WATCHLIST_MODEL_REVIEW',1,80.8500,77.5000,90,70,82,'PASS - RESEARCH ONLY','QUALITY_HARDENING_REVIEW',
 'POL-OPPORTUNITY-RANKING-V2 + DEC-PINS-QH-20260906-V2'),
('RANK-QH2-RDDT-20260906-01','OPPRANK-QH-REVAL-20260906-02','RDDT','DEC-RDDT-QH-20260906-V2','SCORE-RDDT-QH-20260906-V2',
 'WATCHLIST_VALUE_WAIT',1,71.1429,41.6431,90,65,88,'PASS - RESEARCH ONLY','MISPRICING_INSUFFICIENT',
 'POL-OPPORTUNITY-RANKING-V2 + DEC-RDDT-QH-20260906-V2')
on conflict (ranking_candidate_id) do nothing;

-- Acceptance proof: the system must distinguish quality from price/model eligibility.
insert into fwios.decision_policy_regression_runs(
 regression_id,policy_key,policy_version_id,test_case,input_payload,expected_payload,actual_payload,status,notes
) values
('REG-QH-REVAL-01','QUALITY_HARDENING','POL-QUALITY-HARDENING-V1','PINS durable business evidence clears durability gate','{"ticker":"PINS"}'::jsonb,'{"durability":"PASS"}'::jsonb,'{"durability":"PASS"}'::jsonb,'PASS','3-year revenue anchor + sustained user growth verified'),
('REG-QH-REVAL-02','QUALITY_HARDENING','POL-QUALITY-HARDENING-V1','PINS owner economics remains nuanced review','{"ticker":"PINS"}'::jsonb,'{"owner_earnings":"REVIEW"}'::jsonb,'{"owner_earnings":"REVIEW"}'::jsonb,'PASS','Share count falls, but SBC is high and buybacks exceed H1 FCF'),
('REG-QH-REVAL-03','QUALITY_HARDENING','POL-QUALITY-HARDENING-V1','RDDT alternative durability anchor accepted','{"ticker":"RDDT","quarters":8}'::jsonb,'{"durability":"PASS"}'::jsonb,'{"durability":"PASS"}'::jsonb,'PASS','Eight consecutive quarters >60% revenue growth is explicit verified alternative'),
('REG-QH-REVAL-04','QUALITY_HARDENING','POL-QUALITY-HARDENING-V1','RDDT owner earnings reconciliation passes','{"ticker":"RDDT"}'::jsonb,'{"owner_earnings":"PASS"}'::jsonb,'{"owner_earnings":"PASS"}'::jsonb,'PASS','H1 FCF materially exceeds SBC and diluted share growth is 0.2% YoY'),
('REG-QH-REVAL-05','QUALITY_HARDENING','POL-QUALITY-HARDENING-V1','RDDT quality does not override valuation','{"ticker":"RDDT"}'::jsonb,'{"bucket":"WATCHLIST_VALUE_WAIT"}'::jsonb,'{"bucket":"WATCHLIST_VALUE_WAIT"}'::jsonb,'PASS','Good company remains wait-for-value because mispricing is insufficient'),
('REG-QH-REVAL-06','QUALITY_HARDENING','POL-QUALITY-HARDENING-V1','PINS high upside does not bypass hardening review','{"ticker":"PINS","pw_upside":1.1697407647}'::jsonb,'{"bucket":"WATCHLIST_MODEL_REVIEW"}'::jsonb,'{"bucket":"WATCHLIST_MODEL_REVIEW"}'::jsonb,'PASS','Extreme DCF upside cannot create Immediate while owner/value-trap/robustness are REVIEW'),
('REG-QH-REVAL-07','QUALITY_HARDENING','POL-QUALITY-HARDENING-V1','NFLX quality classification survives missing valuation model','{"ticker":"NFLX"}'::jsonb,'{"quality_min":90,"valuation":"BLOCKED - MODEL NOT IMPLEMENTED"}'::jsonb,'{"quality":94,"valuation":"BLOCKED - MODEL NOT IMPLEMENTED"}'::jsonb,'PASS','High business quality and model availability are separate dimensions'),
('REG-QH-REVAL-08','QUALITY_HARDENING','POL-QUALITY-HARDENING-V1','No Immediate force-fill after quality revalidation','{"ranking_run_id":"OPPRANK-QH-REVAL-20260906-02"}'::jsonb,'{"immediate_count":0}'::jsonb,'{"immediate_count":0}'::jsonb,'PASS','Quality filter does not force-fill capital')
on conflict (regression_id) do nothing;

commit;
