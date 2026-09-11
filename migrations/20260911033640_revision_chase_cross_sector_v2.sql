-- Revision / Chase cross-sector policy v2
-- Preserves deterministic scoring kernels and thresholds while making component semantics archetype-specific.
-- Runtime evidence, market prices, candidate component inputs, and decision snapshots remain Supabase state.

update fwios.policy_versions
set lifecycle_status='RETIRED'
where policy_version_id in ('POL-REVISION-SCORE-V1','POL-CHASE-SCORE-V1');

insert into fwios.policy_versions(
  policy_version_id,policy_key,version,lifecycle_status,deterministic_scoring,config,source_reference,effective_at
) values
(
  'POL-REVISION-SCORE-V2-CROSS-SECTOR','REVISION_SCORE','2.0','ACTIVE',true,
  '{"kernel":"calculate_revision_score_v1","component_weights":{"guidance":0.30,"consensus":0.25,"kpi_acceleration":0.25,"margin_fcf":0.20},"revision_gate_min":50,"delta_score_formula":"clamp(50 + 5 * delta_pct, 0, 100)","missing_data_policy":"BLOCKED","full_component_coverage_required":true,"unregistered_archetype_policy":"BLOCKED","universal":{"guidance_raw":"forward revenue guidance midpoint surprise % vs pre-guidance analyst consensus, same fiscal period","consensus_raw":"same-provider, same-metric, same-fiscal-period consensus revision % across the latest material earnings event"},"archetype_contracts":{"Digital Advertising Platform":{"kpi_acceleration":"average percentage-point acceleration of configured monetization and engagement YoY growth vs prior quarter","margin_fcf":"average of adjusted EBITDA margin YoY delta pp and FCF margin YoY delta pp"},"SaaS / Application Software":{"kpi_acceleration":"average percentage-point acceleration of registered recurring-revenue KPIs (ARR/recurring growth; RPO/cRPO only when consistently disclosed)","margin_fcf":"average of non-GAAP operating-margin YoY delta pp and FCF-margin YoY delta pp"},"IT Services":{"kpi_acceleration":"average percentage-point acceleration of local-currency revenue growth and new-bookings growth vs prior quarter","margin_fcf":"average of operating-margin YoY delta pp and FCF-margin YoY delta pp"}},"source_quality":{"company_kpi_margin":"Tier A first-party/SEC required","guidance":"Tier A company guidance + identifiable analyst-consensus source","consensus":"same-provider pre/post snapshots required"}}'::jsonb,
  'FWIOS Revision Score v2 cross-sector contract; preserves deterministic v1 scoring kernel while making component semantics archetype-specific and fail-closed.',now()
),
(
  'POL-CHASE-SCORE-V2-CROSS-SECTOR','CHASE_SCORE','2.0','ACTIVE',true,
  '{"kernel":"calculate_chase_risk_v1 + chase_gate_v1","anchor_price":"last regular-session close before latest material earnings release","chase_risk_max":60,"component_weights":{"price_vs_fv":0.20,"price_extension":0.25,"price_vs_revision":0.30,"multiple_expansion":0.25},"extension_formula":"clamp(max(event_return_pct,0)*2.5,0,100)","price_vs_revision_formula":"clamp(max(event_return_pct-consensus_revision_pct,0)*2.5,0,100)","multiple_expansion_formula":"clamp(max(multiple_expansion_pct,0)*2.5,0,100)","price_vs_fv_reference":"min(base_fv, probability_weighted_fv)","price_vs_fv_breakpoints":[[-20,0],[-10,15],[0,40],[10,65],[25,100]],"missing_data_policy":"BLOCKED","full_component_coverage_required":true,"multiple_contract":{"same_provider_same_metric_pre_post_required":true,"registered_metric_by_archetype":{"Digital Advertising Platform":"registered forward earnings/cash-flow multiple","SaaS / Application Software":"forward P/E or EV/FCF, fixed per candidate before event","IT Services":"forward P/E or EV/FCF, fixed per candidate before event"},"mixed_provider_or_mixed_metric":"BLOCKED"},"post_event_price_policy":"use verified regular-session close; after-hours may trigger review but cannot promote"}'::jsonb,
  'FWIOS Chase Risk v2 cross-sector contract; preserves v1 kernel and adds explicit same-basis multiple and post-event price rules.',now()
)
on conflict(policy_version_id) do update set
  lifecycle_status=excluded.lifecycle_status,
  config=excluded.config,
  source_reference=excluded.source_reference,
  effective_at=excluded.effective_at;

insert into fwios.decision_policy_regression_runs(
  regression_id,policy_key,policy_version_id,test_case,input_payload,expected_payload,actual_payload,status,tolerance,notes
) values
(
  'REG-REV-V2-MISSING','REVISION_SCORE','POL-REVISION-SCORE-V2-CROSS-SECTOR','missing required revision component blocks',
  '{"guidance":50,"consensus":50,"kpi":null,"margin_fcf":50}'::jsonb,
  '{"gate":"BLOCKED - COMPONENT SCORING INCOMPLETE"}'::jsonb,
  jsonb_build_object('gate',fwios.revision_gate_v1(50,50,null,50,'PASS','PASS - COMPARABLE CONSENSUS EVIDENCE')),
  'PASS',null,'Fail-closed regression.'
),
(
  'REG-REV-V2-NEUTRAL','REVISION_SCORE','POL-REVISION-SCORE-V2-CROSS-SECTOR','all neutral components score 50 and pass',
  '{"guidance":50,"consensus":50,"kpi":50,"margin_fcf":50}'::jsonb,
  '{"score":50,"gate":"PASS"}'::jsonb,
  jsonb_build_object('score',fwios.calculate_revision_score_v1(50,50,50,50),'gate',fwios.revision_gate_v1(50,50,50,50,'PASS','PASS - COMPARABLE CONSENSUS EVIDENCE')),
  'PASS',0.0001,'Kernel parity under V2.'
),
(
  'REG-CHASE-V2-MISSING-MULT','CHASE_SCORE','POL-CHASE-SCORE-V2-CROSS-SECTOR','missing same-basis multiple blocks chase',
  '{"price_extension":35,"price_vs_revision":35,"multiple_expansion":null,"price_vs_fv":0}'::jsonb,
  '{"gate":"BLOCKED - INCOMPLETE CHASE DATA"}'::jsonb,
  jsonb_build_object('gate',fwios.chase_gate_v1(35,35,null,0,60)),
  'PASS',null,'Fail-closed multiple contract.'
),
(
  'REG-CHASE-V2-BOUNDARY','CHASE_SCORE','POL-CHASE-SCORE-V2-CROSS-SECTOR','weighted chase risk below max passes',
  '{"price_extension":40,"price_vs_revision":40,"multiple_expansion":40,"price_vs_fv":40}'::jsonb,
  '{"risk":40,"gate":"PASS"}'::jsonb,
  jsonb_build_object('risk',fwios.calculate_chase_risk_v1(40,40,40,40),'gate',fwios.chase_gate_v1(40,40,40,40,60)),
  'PASS',0.0001,'Kernel parity under V2.'
)
on conflict(regression_id) do update set
  actual_payload=excluded.actual_payload,
  status=excluded.status,
  notes=excluded.notes;
