-- M3.4 Semiconductor Designer valuation coverage v1
-- Runtime evidence/market snapshots are state and are intentionally not hard-coded here.
create or replace function fwios.semis_midcycle_dcf_fv_v1(
  p_fcf_ltm numeric,p_growth_rates numeric[],p_discount_rate numeric,p_terminal_growth numeric,p_equity_bridge numeric,p_shares_outstanding numeric
) returns numeric language plpgsql immutable strict security invoker set search_path=pg_catalog,fwios as $$
declare v_fcf numeric:=p_fcf_ltm; v_pv numeric:=0; v_i integer; v_n integer:=coalesce(array_length(p_growth_rates,1),0);
begin
  if p_fcf_ltm<=0 or p_shares_outstanding<=0 or v_n<1 then return null; end if;
  if p_discount_rate<=p_terminal_growth or p_discount_rate<=0 or p_terminal_growth<0 then return null; end if;
  for v_i in 1..v_n loop
    if p_growth_rates[v_i]<=-1 then return null; end if;
    v_fcf:=v_fcf*(1+p_growth_rates[v_i]);
    v_pv:=v_pv+v_fcf/power(1+p_discount_rate,v_i);
  end loop;
  v_pv:=v_pv+(v_fcf*(1+p_terminal_growth)/(p_discount_rate-p_terminal_growth))/power(1+p_discount_rate,v_n);
  return round((v_pv+p_equity_bridge)/p_shares_outstanding,8);
end $$;
revoke execute on function fwios.semis_midcycle_dcf_fv_v1(numeric,numeric[],numeric,numeric,numeric,numeric) from public,anon,authenticated;

insert into fwios.valuation_model_versions(version_id,model_id,version_label,status,kernel_family,input_contract,model_policy,assumptions,confidence_tier,regression_status,effective_from,source_system,source_ref)
values('SEMIS_MIDCYCLE_DCF_V1::1.0','SEMIS_MIDCYCLE_DCF_V1','1.0','PRODUCTION','FCF_COMPOUNDER',
'{"required_metrics":["revenue_ltm","gross_margin","inventory_days","customer_concentration","fcf_ltm","net_cash","shares_outstanding"],"required_material_event_adjustment":"pending_committed_acquisition_consideration","normalization_version":"NORM_V1-SEMIS"}'::jsonb,
'{"policy":"SEMIS_MIDCYCLE_DCF_POLICY_V1","method":"5-year equity FCF DCF with terminal value","probabilities":"25/50/25","pending_acquisition_treatment":"subtract signed purchase consideration from conservative equity bridge; exclude employee retention from purchase consideration"}'::jsonb,
'{"bear_discount":0.115,"base_discount":0.10,"bull_discount":0.09,"bear_terminal_growth":0.03,"base_terminal_growth":0.035,"bull_terminal_growth":0.04}'::jsonb,
'PRODUCTION_V1','PASS','2026-09-05','supabase','M3_4_NVDA_VALUATION_COVERAGE')
on conflict(version_id) do update set status='PRODUCTION',regression_status='PASS',input_contract=excluded.input_contract,model_policy=excluded.model_policy,assumptions=excluded.assumptions;
update fwios.valuation_models set production_status='IMPLEMENTED',model_version='1.0',regression_status='PASS',confidence_status='PRODUCTION_V1',updated_at=now() where model_id='SEMIS_MIDCYCLE_DCF_V1';