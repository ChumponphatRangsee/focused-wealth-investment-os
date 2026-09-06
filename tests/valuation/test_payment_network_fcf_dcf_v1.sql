-- PAYMENT_NETWORK_FCF_DCF_V1 deterministic acceptance
-- Run after implementation + valuation-governance migrations and before activation migration.
-- Visa-like arithmetic fixture refreshed from the 2026-06-30 10-Q:
-- LTM FCF 21.013B; net cash -9.916B = cash 12.359 + marketable securities 1.583 - carrying debt 23.858;
-- as-converted Class A equivalent shares 1.880B. Fixtures validate arithmetic only.

with model as (
  select * from fwios.valuation_model_versions
  where version_id='PAYMENT_NETWORK_FCF_DCF_V1::1.0'
), fixture as (
  select 21.013::numeric fcf_b, (-9.916)::numeric net_cash_b, 1880::numeric shares_m
), results as (
  select 'REG-PAYNET-MDL-01' regression_id,'Version is installed in experimental state' test_case,
         '{}'::jsonb input_payload,'{"status":"EXPERIMENTAL"}'::jsonb expected_payload,
         jsonb_build_object('status',(select status from model)) actual_payload,
         case when exists(select 1 from model where status='EXPERIMENTAL') then 'PASS' else 'FAIL' end status,
         null::numeric tolerance,'Production activation must occur only after this suite passes.' notes
  union all
  select 'REG-PAYNET-MDL-02','Required metric contract is exact and archetype-correct',
         '{}'::jsonb,
         '{"required_metrics":["payments_volume_growth","cross_border_growth","take_rate","operating_margin","fcf_ltm","net_cash","shares_outstanding"]}'::jsonb,
         jsonb_build_object('required_metrics',(select input_contract->'required_metrics' from model)),
         case when (select input_contract->'required_metrics' from model)='["payments_volume_growth","cross_border_growth","take_rate","operating_margin","fcf_ltm","net_cash","shares_outstanding"]'::jsonb then 'PASS' else 'FAIL' end,
         null,'All seven metrics are required; rough multiples are not valuation inputs.'
  union all
  select 'REG-PAYNET-MDL-03','Bear fixture is deterministic',
         jsonb_build_object('fcf_b',f.fcf_b,'net_cash_b',f.net_cash_b,'shares_m',f.shares_m,'g1_5',0.07,'g6_10',0.04,'r',0.10,'tg',0.03),
         '{"fv":195.66314262}'::jsonb,
         jsonb_build_object('fv',fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.07,0.04,0.10,0.03)),
         case when abs(fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.07,0.04,0.10,0.03)-195.66314262)<0.0001 then 'PASS' else 'FAIL' end,
         0.0001,'Current Visa-like normalized fixture; not a recommendation.' from fixture f
  union all
  select 'REG-PAYNET-MDL-04','Base fixture is deterministic',
         jsonb_build_object('fcf_b',f.fcf_b,'net_cash_b',f.net_cash_b,'shares_m',f.shares_m,'g1_5',0.10,'g6_10',0.06,'r',0.09,'tg',0.035),
         '{"fv":297.49394208}'::jsonb,
         jsonb_build_object('fv',fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.10,0.06,0.09,0.035)),
         case when abs(fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.10,0.06,0.09,0.035)-297.49394208)<0.0001 then 'PASS' else 'FAIL' end,
         0.0001,'Base arithmetic is pinned for regression safety.' from fixture f
  union all
  select 'REG-PAYNET-MDL-05','Bull fixture is deterministic',
         jsonb_build_object('fcf_b',f.fcf_b,'net_cash_b',f.net_cash_b,'shares_m',f.shares_m,'g1_5',0.12,'g6_10',0.08,'r',0.0825,'tg',0.04),
         '{"fv":443.05312684}'::jsonb,
         jsonb_build_object('fv',fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.12,0.08,0.0825,0.04)),
         case when abs(fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.12,0.08,0.0825,0.04)-443.05312684)<0.0001 then 'PASS' else 'FAIL' end,
         0.0001,'Bull arithmetic is pinned for regression safety.' from fixture f
  union all
  select 'REG-PAYNET-MDL-06','Scenario ordering is monotonic',
         '{}'::jsonb,'{"ordering":"bear<base<bull"}'::jsonb,
         jsonb_build_object('bear',fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.07,0.04,0.10,0.03),'base',fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.10,0.06,0.09,0.035),'bull',fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.12,0.08,0.0825,0.04)),
         case when fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.07,0.04,0.10,0.03)<fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.10,0.06,0.09,0.035) and fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.10,0.06,0.09,0.035)<fwios.payment_network_fcf_dcf_fv_v1(f.fcf_b,f.net_cash_b,f.shares_m,0.12,0.08,0.0825,0.04) then 'PASS' else 'FAIL' end,
         null,'Bear < Base < Bull.' from fixture f
  union all
  select 'REG-PAYNET-MDL-07','Invalid discount/terminal relationship fails closed',
         '{"discount_rate":0.04,"terminal_growth":0.04}'::jsonb,'{"result":null}'::jsonb,
         jsonb_build_object('is_null',fwios.payment_network_fcf_dcf_fv_v1(21,-10,1900,0.10,0.06,0.04,0.04) is null),
         case when fwios.payment_network_fcf_dcf_fv_v1(21,-10,1900,0.10,0.06,0.04,0.04) is null then 'PASS' else 'FAIL' end,
         null,'Discount rate must exceed terminal growth.'
  union all
  select 'REG-PAYNET-MDL-08','Non-positive starting FCF fails closed',
         '{"starting_fcf":0}'::jsonb,'{"result":null}'::jsonb,
         jsonb_build_object('is_null',fwios.payment_network_fcf_dcf_fv_v1(0,-10,1900,0.10,0.06,0.09,0.035) is null),
         case when fwios.payment_network_fcf_dcf_fv_v1(0,-10,1900,0.10,0.06,0.09,0.035) is null then 'PASS' else 'FAIL' end,
         null,'V1 is for profitable durable payment networks only.'
  union all
  select 'REG-PAYNET-MDL-09','Non-positive share count fails closed',
         '{"shares_m":0}'::jsonb,'{"result":null}'::jsonb,
         jsonb_build_object('is_null',fwios.payment_network_fcf_dcf_fv_v1(21,-10,0,0.10,0.06,0.09,0.035) is null),
         case when fwios.payment_network_fcf_dcf_fv_v1(21,-10,0,0.10,0.06,0.09,0.035) is null then 'PASS' else 'FAIL' end,
         null,'Per-share valuation requires a valid share denominator.'
  union all
  select 'REG-PAYNET-MDL-10','Out-of-policy growth assumptions fail closed',
         '{"g1_5":0.31,"g6_10":0.21}'::jsonb,'{"both_null":true}'::jsonb,
         jsonb_build_object('g1_null',fwios.payment_network_fcf_dcf_fv_v1(21,-10,1900,0.31,0.06,0.09,0.035) is null,'g2_null',fwios.payment_network_fcf_dcf_fv_v1(21,-10,1900,0.10,0.21,0.09,0.035) is null),
         case when fwios.payment_network_fcf_dcf_fv_v1(21,-10,1900,0.31,0.06,0.09,0.035) is null and fwios.payment_network_fcf_dcf_fv_v1(21,-10,1900,0.10,0.21,0.09,0.035) is null then 'PASS' else 'FAIL' end,
         null,'Guardrail prevents accidental hyper-growth extrapolation.'
  union all
  select 'REG-PAYNET-MDL-11','Scenario probabilities sum to one',
         jsonb_build_object('probabilities',(select model_policy->'probabilities' from model)),'{"sum":1}'::jsonb,
         jsonb_build_object('sum',((select model_policy#>>'{probabilities,bear}' from model))::numeric+((select model_policy#>>'{probabilities,base}' from model))::numeric+((select model_policy#>>'{probabilities,bull}' from model))::numeric),
         case when abs((((select model_policy#>>'{probabilities,bear}' from model))::numeric+((select model_policy#>>'{probabilities,base}' from model))::numeric+((select model_policy#>>'{probabilities,bull}' from model))::numeric)-1)<0.000001 then 'PASS' else 'FAIL' end,
         0.000001,'Probability-weighted fair value remains deterministic.'
  union all
  select 'REG-PAYNET-MDL-12','Rough multiples and auto-trade are excluded from valuation semantics',
         '{}'::jsonb,'{"rough_multiple_role":"TRIAGE_ONLY_NOT_VALUATION","auto_trade":false,"price_in_assumptions":false}'::jsonb,
         jsonb_build_object('rough_multiple_role',(select model_policy->>'rough_multiple_role' from model),'auto_trade',coalesce(((select model_policy->>'auto_trade' from model))::boolean,false),'price_in_assumptions',(select assumptions ? 'current_price' from model)),
         case when (select model_policy->>'rough_multiple_role' from model)='TRIAGE_ONLY_NOT_VALUATION' and coalesce(((select model_policy->>'auto_trade' from model))::boolean,false)=false and not (select assumptions ? 'current_price' from model) then 'PASS' else 'FAIL' end,
         null,'Fair value is generated from normalized FCF economics; market price is joined later for mispricing.'
)
insert into fwios.decision_policy_regression_runs(
  regression_id,policy_key,policy_version_id,test_case,input_payload,expected_payload,actual_payload,status,tolerance,notes
)
select regression_id,'VALUATION_MODEL','POL-VALUATION-MODEL-GOVERNANCE-V1',test_case,input_payload,expected_payload,actual_payload,status,tolerance,notes
from results
on conflict(regression_id) do update set
  policy_key=excluded.policy_key,
  policy_version_id=excluded.policy_version_id,
  test_case=excluded.test_case,
  input_payload=excluded.input_payload,
  expected_payload=excluded.expected_payload,
  actual_payload=excluded.actual_payload,
  status=excluded.status,
  tolerance=excluded.tolerance,
  notes=excluded.notes,
  created_at=now();

select count(*) as total,
       count(*) filter(where status='PASS') as pass_count,
       count(*) filter(where status<>'PASS') as fail_count
from fwios.decision_policy_regression_runs
where regression_id between 'REG-PAYNET-MDL-01' and 'REG-PAYNET-MDL-12';