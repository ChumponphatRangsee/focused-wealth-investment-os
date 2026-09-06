-- Guarded activation for PAYMENT_NETWORK_FCF_DCF_V1::1.0
-- Must run only after REG-PAYNET-MDL-01..12 are all PASS.

do $$
declare
  v_total integer;
  v_pass integer;
begin
  select count(*),count(*) filter(where status='PASS')
  into v_total,v_pass
  from fwios.decision_policy_regression_runs
  where regression_id between 'REG-PAYNET-MDL-01' and 'REG-PAYNET-MDL-12';

  if v_total <> 12 or v_pass <> 12 then
    raise exception 'PAYMENT_NETWORK_FCF_DCF_V1 activation blocked: expected 12/12 PASS, got %/%',v_pass,v_total;
  end if;
end $$;

update fwios.valuation_model_versions
set status='PRODUCTION',
    confidence_tier='PRODUCTION_V1',
    regression_status='PASS',
    source_system='github',
    source_ref='PAYMENT_NETWORK_VALUATION_V1_ACTIVATED'
where version_id='PAYMENT_NETWORK_FCF_DCF_V1::1.0';

update fwios.valuation_models
set production_status='IMPLEMENTED',
    model_version='1.0',
    regression_status='PASS',
    confidence_status='PRODUCTION_V1',
    notes='Payment Network FCF DCF v1 production-active after deterministic 12/12 regression PASS.',
    updated_at=now()
where model_id='PAYMENT_NETWORK_FCF_DCF_V1';

update fwios.blockers
set current_status='PASS',
    orchestrator_state='CLOSED',
    resolution_note='PAYMENT_NETWORK_FCF_DCF_V1::1.0 implemented and activated after 12/12 deterministic regression PASS. Candidate-specific valuation still requires complete Tier-A normalized inputs and current market price.',
    last_checked_text='2026-09-06',
    updated_at=now()
where block_id='BLK-FIN-PAYNET-MDL-001';