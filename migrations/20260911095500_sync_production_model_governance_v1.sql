-- Production valuation governance sync v1
-- Durable contracts/model versions only. Runtime evidence, prices, valuation runs and candidate decisions remain Supabase state.

insert into fwios.valuation_models(
  model_id,archetype,model_family,production_status,model_version,required_metric_ids,regression_status,confidence_status,notes
) values
(
  'SEMIS_MIDCYCLE_DCF_V1','Semiconductor Designer','MIDCYCLE_CASHFLOW','IMPLEMENTED','1.1',
  array['revenue_ltm','gross_margin','inventory_days','customer_concentration','fcf_ltm','net_cash','shares_outstanding']::text[],
  'PASS','PRODUCTION_V1','M3.4 deterministic Semiconductor Designer mid-cycle equity FCF DCF; ticker-specific evidence-anchored growth and material dilution review required.'
),
(
  'SEMICAP_MIDCYCLE_FCF_V1','Semiconductor Equipment / Foundry','MIDCYCLE_CASHFLOW','IMPLEMENTED','1.0',
  array['fcf_ltm','net_cash','shares_outstanding','rpo_long_duration','service_revenue_pct','fab_utilization_signal']::text[],
  'PASS','PRODUCTION_V1','Production contract uses disclosed cash FCF, equity bridge, long-duration RPO, service mix and fab-utilization cycle evidence. Bookings/backlog proxy requirement removed because current numeric bookings are not publicly disclosed.'
),
(
  'MINING_ASSET_NAV_SOTP_V1','Mining / Commodities','ASSET_NAV','IMPLEMENTED','1.1',
  array['core_asset_nav','other_asset_value','cash','debt','other_claims','shares_outstanding']::text[],
  'PASS','PRODUCTION_V1','Production ASSET_NAV/SOTP route. MP adapter completed with non-overlapping Magnetics SOTP, preferred claim treatment and conservative warrant dilution.'
),
(
  'WASTE_FCF_EV_EBITDA_V1','Waste / Environmental Services','FCF_COMPOUNDER','IMPLEMENTED','1.0',
  array['normalized_revenue','core_price_growth','volume_growth','normalized_adjusted_ebitda','normalized_fcf','net_debt','shares_outstanding']::text[],
  'PASS','PRODUCTION_V1','Production v1: normalized FY guidance FCF DCF is primary. EV/EBITDA is diagnostic only and cannot create a Buy signal.'
),
(
  'MACH_ELECTRIFICATION_FCF_DCF_V1','Machinery / Electrification','FCF_COMPOUNDER','IMPLEMENTED','1.0',
  array['normalized_revenue','orders_backlog_signal','normalized_margin','normalized_fcf','net_debt','shares_outstanding','material_event_adjustment']::text[],
  'PASS','PRODUCTION_V1','Production v1 validated on PH. Candidate-specific event normalization required. Orders/backlog are visibility sanity inputs only; FCF DCF is primary.'
),
(
  'AERO_DEFENSE_FCF_DCF_V1','Aerospace / Defense','FCF_COMPOUNDER','IMPLEMENTED','1.1',
  array['normalized_revenue','organic_growth','normalized_fcf','net_debt','shares_outstanding','material_event_adjustment']::text[],
  'PASS','PRODUCTION_V1','Production v1.1: FCF DCF mathematical inputs + growth/event sanity are mandatory. EBITDA/margin/backlog are optional diagnostics, never fabricated proxies.'
)
on conflict(model_id) do update set
  archetype=excluded.archetype,
  model_family=excluded.model_family,
  production_status=excluded.production_status,
  model_version=excluded.model_version,
  required_metric_ids=excluded.required_metric_ids,
  regression_status=excluded.regression_status,
  confidence_status=excluded.confidence_status,
  notes=excluded.notes,
  updated_at=now();

insert into fwios.valuation_model_versions(
  version_id,model_id,version_label,status,kernel_family,input_contract,model_policy,assumptions,
  confidence_tier,regression_status,effective_from,source_system,source_ref
) values
(
  'SEMIS_MIDCYCLE_DCF_V1::1.1','SEMIS_MIDCYCLE_DCF_V1','1.1','PRODUCTION','FCF_COMPOUNDER',
  '{"required_metrics":["revenue_ltm","gross_margin","inventory_days","customer_concentration","fcf_ltm","net_cash","shares_outstanding"],"normalization_version":"NORM_V1-SEMIS","material_dilution_review_required":true,"scenario_anchor_evidence_required":true,"required_material_event_adjustment":"pending_committed_acquisition_consideration"}'::jsonb,
  '{"method":"5-year equity FCF DCF with terminal value","policy":"SEMIS_MIDCYCLE_DCF_POLICY_V1_1","probabilities":"25/50/25","scenario_growth_policy":"ticker-specific and evidence-anchored; fixed cross-company growth arrays prohibited","material_dilution_treatment":"explicit valuation share-count assumption with source lineage","pending_acquisition_treatment":"subtract signed purchase consideration from equity bridge","nvda_v1_growth_arrays_retained_as_regression_fixture_only":true}'::jsonb,
  '{"base_discount":0.10,"bear_discount":0.115,"bull_discount":0.09,"base_terminal_growth":0.035,"bear_terminal_growth":0.03,"bull_terminal_growth":0.04,"max_growth_assumption":0.25,"min_growth_assumption":-0.25}'::jsonb,
  'PRODUCTION_V1','PASS','2026-09-11','supabase','QCOM_SEMIS_EVIDENCE_ANCHORED_GOVERNANCE'
),
(
  'SEMICAP_MIDCYCLE_FCF_V1::1.0','SEMICAP_MIDCYCLE_FCF_V1','1.0','PRODUCTION','MIDCYCLE_CASHFLOW',
  '{"source_policy":"Tier A first-party/SEC; do not fabricate bookings/backlog proxies","required_metrics":["fcf_ltm","net_cash","shares_outstanding","rpo_long_duration","service_revenue_pct","fab_utilization_signal"],"normalization_version":"NORM_V1-SEMICAP"}'::jsonb,
  '{"method":"10-year equity FCF DCF using reusable FCF compounder","policy":"SEMICAP_MIDCYCLE_FCF_POLICY_V1","cycle_context":"RPO + service mix + utilization are explicit sanity context, not hidden fair-value multipliers","growth_anchor":"Current Q3 revenue +25% YoY is not extrapolated directly; scenario growth is deliberately mean-reverting","probabilities":"25/50/25"}'::jsonb,
  '{"base":{"growth_y1_5":0.10,"growth_y6_10":0.05,"discount_rate":0.10,"terminal_growth":0.03},"bear":{"growth_y1_5":0.03,"growth_y6_10":0.02,"discount_rate":0.115,"terminal_growth":0.025},"bull":{"growth_y1_5":0.15,"growth_y6_10":0.07,"discount_rate":0.09,"terminal_growth":0.035}}'::jsonb,
  'PRODUCTION_V1','PASS','2026-09-11','supabase','AMAT_PUBLIC_DATA_CONTRACT_20260911'
),
(
  'MINING_ASSET_NAV_SOTP_V1::1.1','MINING_ASSET_NAV_SOTP_V1','1.1','PRODUCTION','ASSET_NAV',
  '{"source_tier":"A","required_inputs":["core_asset_nav","other_asset_value","cash","debt","other_claims","shares_outstanding"],"candidate_adapters":{"MP":["magnetics_adjusted_ebitda_q2","ten_x_minimum_ebitda","ten_x_project_cost_floor","ten_x_incentives","ten_x_land_spend","warrant_dilution_shares"]},"missing_material_component":"BLOCK_DOWNSTREAM"}'::jsonb,
  '{"policy":"NAV at normalized/qualified-person commodity deck plus non-overlapping replacement-cost/SOTP bridge","warrant_treatment":"full dilution, exercise proceeds excluded","preferred_treatment":"claim, not as-converted shares","do_not_use_peak_spot":true,"future_capex_treatment":"subtract only future project-cost floor net of explicit incentives and already-paid land; do not capitalize financing proceeds as value","scenario_probabilities":"25/50/25","no_double_count_balance_sheet_bridge":true}'::jsonb,
  '{"MP":{"ten_x_min_ebitda_b":0.14,"ten_x_ebitda_multiple":{"base":8,"bear":6,"bull":10},"annual_escalation_assumed":false,"ten_x_future_cost_floor_b":0.97,"core_nav_sensitivity_factor":{"base":1,"bear":0.8,"bull":1.2},"independence_ebitda_multiple":{"base":8,"bear":6,"bull":10},"magnetics_other_asset_value_b":{"base":0.39,"bear":0.18,"bull":0.9}}}'::jsonb,
  'PRODUCTION_V1','PASS','2026-09-11','supabase','MP_MAGNETICS_SOTP_20260911'
),
(
  'WASTE_FCF_EV_EBITDA_V1::1.0','WASTE_FCF_EV_EBITDA_V1','1.0','PRODUCTION','FCF_COMPOUNDER',
  '{"source_policy":"Tier A first-party guidance + SEC balance sheet/share count","required_metrics":["normalized_revenue","core_price_growth","volume_growth","normalized_adjusted_ebitda","normalized_fcf","net_debt","shares_outstanding"],"normalization_version":"NORM_V1-WASTE","normalized_anchor_policy":"Current FY guidance midpoint allowed and explicitly tagged FORWARD_FY"}'::jsonb,
  '{"method":"10-year equity FCF DCF using normalized FCF; EV/EBITDA diagnostic crosscheck only","growth_policy":"candidate-specific and evidence-anchored; core price and volume are sanity context, not hidden score modifiers","probabilities":"25/50/25","primary_kernel":"fwios.fcf_compounder_fv","ev_ebitda_policy":"diagnostic only; cannot override DCF gate or create promotion","human_execution_only":true}'::jsonb,
  '{"allowed_ranges":{"growth_y1_5":[-0.05,0.12],"growth_y6_10":[0,0.07],"discount_rate":[0.075,0.12],"terminal_growth":[0.02,0.04],"diagnostic_ev_ebitda":[9,20]}}'::jsonb,
  'PRODUCTION_V1','PASS','2026-09-11','supabase','SECTOR-IND-WASTE-20260911'
),
(
  'MACH_ELECTRIFICATION_FCF_DCF_V1::1.0','MACH_ELECTRIFICATION_FCF_DCF_V1','1.0','PRODUCTION','FCF_COMPOUNDER',
  '{"event_policy":"Unclosed deals excluded unless consideration/financing and pro-forma cash-flow bridge are fully modeled","source_policy":"Tier A first-party / SEC only","required_metrics":["normalized_revenue","orders_backlog_signal","normalized_margin","normalized_fcf","net_debt","shares_outstanding","material_event_adjustment"],"normalization_version":"NORM_V1-MACH-ELEC"}'::jsonb,
  '{"method":"10-year equity FCF DCF","probabilities":"25/50/25","primary_kernel":"fwios.fcf_compounder_fv","promotion_rule":"intrinsic valuation does not imply Buy; verified price/mispricing gate remains separate","orders_backlog_role":"visibility sanity only","human_execution_only":true,"candidate_growth_policy":"evidence-anchored; company-specific"}'::jsonb,
  '{"PH":{"base":{"growth_y1_5":0.07,"growth_y6_10":0.045,"discount_rate":0.09,"terminal_growth":0.03},"bear":{"growth_y1_5":0.03,"growth_y6_10":0.02,"discount_rate":0.105,"terminal_growth":0.025},"bull":{"growth_y1_5":0.10,"growth_y6_10":0.055,"discount_rate":0.08,"terminal_growth":0.035},"growth_anchor":"FY27 organic guidance midpoint ~7% and record FY26 margin/cash flow; pending acquisitions excluded"}}'::jsonb,
  'PRODUCTION_V1','PASS','2026-09-11','supabase','PH_DEEP_RESEARCH_20260911'
),
(
  'AERO_DEFENSE_FCF_DCF_V1::1.1','AERO_DEFENSE_FCF_DCF_V1','1.1','PRODUCTION','FCF_COMPOUNDER',
  '{"event_policy":"Closed transactions must be consistently reflected in both normalized cash flow and balance-sheet bridge; unclosed transactions require separate adjustment or blocker","source_policy":"Tier A first-party / SEC","required_metrics":["normalized_revenue","organic_growth","normalized_fcf","net_debt","shares_outstanding","material_event_adjustment"],"optional_diagnostics":["normalized_adjusted_ebitda","normalized_margin","backlog","orders","program_loss_signal"],"normalization_version":"NORM_V1-AERO-DEF"}'::jsonb,
  '{"method":"10-year equity FCF DCF","backlog_role":"optional visibility diagnostic only","growth_policy":"candidate-specific; organic growth is a sanity anchor not direct extrapolation","probabilities":"25/50/25","primary_kernel":"fwios.fcf_compounder_fv","program_loss_policy":"material program losses require normalization before promotion","human_execution_only":true,"required_input_principle":"Only inputs mathematically needed by FCF DCF plus growth/event sanity are mandatory","profitability_diagnostics":"Optional; do not fabricate company-wide EBITDA when issuer does not disclose a comparable figure"}'::jsonb,
  '{"HWM":{"base":{"growth_y1_5":0.08,"growth_y6_10":0.045,"discount_rate":0.0925,"terminal_growth":0.03},"bear":{"growth_y1_5":0.03,"growth_y6_10":0.02,"discount_rate":0.105,"terminal_growth":0.025},"bull":{"growth_y1_5":0.12,"growth_y6_10":0.055,"discount_rate":0.0825,"terminal_growth":0.035},"growth_anchor":"2025 revenue 8.25B to FY2026 guidance midpoint 10.05B plus Q2 21% organic growth; base growth deliberately mean-reverts below current organic rate"},"RTX":{"base":{"growth_y1_5":0.055,"growth_y6_10":0.035,"discount_rate":0.095,"terminal_growth":0.03},"bear":{"growth_y1_5":0.02,"growth_y6_10":0.015,"discount_rate":0.105,"terminal_growth":0.025},"bull":{"growth_y1_5":0.08,"growth_y6_10":0.045,"discount_rate":0.085,"terminal_growth":0.035},"growth_anchor":"FY2026 organic sales guidance 8-9%; base FCF growth mean-reverts to 5.5% then 3.5%"}}'::jsonb,
  'PRODUCTION_V1','PASS','2026-09-11','supabase','AERO_DEFENSE_REQUIRED_INPUT_SIMPLIFICATION_20260911'
)
on conflict(version_id) do update set
  status=excluded.status,
  kernel_family=excluded.kernel_family,
  input_contract=excluded.input_contract,
  model_policy=excluded.model_policy,
  assumptions=excluded.assumptions,
  confidence_tier=excluded.confidence_tier,
  regression_status=excluded.regression_status,
  effective_from=excluded.effective_from,
  source_system=excluded.source_system,
  source_ref=excluded.source_ref;

-- Keep the sector router aligned with production model contracts.
update fwios.sector_archetypes set
  valuation_model_id='SEMICAP_MIDCYCLE_FCF_V1',
  required_metric_ids=array['fcf_ltm','net_cash','shares_outstanding','rpo_long_duration','service_revenue_pct','fab_utilization_signal']::text[],
  minimum_metric_coverage=1.0,max_metric_age_days=120,required_source_tier='A',
  valuation_input_notes='Production contract uses disclosed LTM FCF + net cash/share bridge; RPO, service mix and fab-utilization are cycle sanity evidence. Do not fabricate numeric bookings/backlog proxies.',
  updated_at=now()
where sector='Information Technology' and archetype='Semiconductor Equipment / Foundry';

update fwios.sector_archetypes set
  valuation_model_id='MINING_ASSET_NAV_SOTP_V1',
  required_metric_ids=array['core_asset_nav','other_asset_value','cash','debt','other_claims','shares_outstanding']::text[],
  minimum_metric_coverage=1.0,max_metric_age_days=450,required_source_tier='A',
  valuation_input_notes='Contract v1.1. Structural NAV may use annual freshness up to 450d; balance metrics <=120d. Material non-mining segments require non-overlapping SOTP or fail closed. MP Magnetics adapter is production-complete.',
  updated_at=now()
where sector='Materials' and archetype='Mining / Commodities';

update fwios.sector_archetypes set
  valuation_model_id='PACKAGING_FCF_DCF_V1',
  required_metric_ids=array['shipment_growth','normalized_fcf','net_debt','shares_outstanding','aluminum_pass_through_coverage','eps_growth_guidance']::text[],
  minimum_metric_coverage=1.0,max_metric_age_days=120,required_source_tier='A',
  valuation_input_notes='Company-reported annual normalized/guided FCF is primary; shipment growth, EPS guidance and commodity pass-through are explicit scenario/quality anchors.',
  updated_at=now()
where sector='Materials' and archetype='Packaging';

update fwios.sector_archetypes set
  valuation_model_id='STREAMING_FCF_DCF_V1',
  required_metric_ids=array['fcf_guidance_fy2026','net_debt','shares_outstanding','revenue_growth_yoy','operating_margin','engagement_growth','content_cash_to_amortization']::text[],
  minimum_metric_coverage=1.0,max_metric_age_days=120,required_source_tier='A',
  valuation_input_notes='Annual FCF guidance or verified normalized annual FCF only; content cash/amortization is a sanity diagnostic; material transactions require explicit review.',
  updated_at=now()
where sector='Communication Services' and archetype='Streaming / Media';

update fwios.sector_archetypes set
  valuation_model_id='WASTE_FCF_EV_EBITDA_V1',
  required_metric_ids=array['normalized_revenue','core_price_growth','volume_growth','normalized_adjusted_ebitda','normalized_fcf','net_debt','shares_outstanding']::text[],
  minimum_metric_coverage=1.0,max_metric_age_days=120,required_source_tier='A',
  valuation_input_notes='Production v1 uses first-party FY guidance midpoint as normalized annual revenue/EBITDA/FCF anchor. FCF DCF is primary; EV/EBITDA is diagnostic only.',
  updated_at=now()
where sector='Industrials' and archetype='Waste / Environmental Services';

update fwios.sector_archetypes set
  valuation_model_id='MACH_ELECTRIFICATION_FCF_DCF_V1',
  required_metric_ids=array['normalized_revenue','orders_backlog_signal','normalized_margin','normalized_fcf','net_debt','shares_outstanding','material_event_adjustment']::text[],
  minimum_metric_coverage=1.0,max_metric_age_days=120,required_source_tier='A',
  valuation_input_notes='Deep contract: normalized revenue/margin/FCF plus net debt/share bridge. Orders/backlog support visibility only. Material transactions must be explicitly normalized before valuation.',
  updated_at=now()
where sector='Industrials' and archetype='Machinery / Electrification';

update fwios.sector_archetypes set
  valuation_model_id='AERO_DEFENSE_FCF_DCF_V1',
  required_metric_ids=array['normalized_revenue','organic_growth','normalized_fcf','net_debt','shares_outstanding','material_event_adjustment']::text[],
  minimum_metric_coverage=1.0,max_metric_age_days=180,required_source_tier='A',
  valuation_input_notes='AERO_DEFENSE v1.1: normalized revenue/growth/FCF + net debt/share bridge + material-event adjustment are required. Profitability/backlog/program-loss metrics are optional diagnostics and must not be fabricated.',
  updated_at=now()
where sector='Industrials' and archetype='Aerospace / Defense';
