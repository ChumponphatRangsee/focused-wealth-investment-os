-- PAYMENT_NETWORK_FCF_DCF_V1 deterministic acceptance
-- Run after implementation migration and before activation migration.

insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,status,notes)
select 'REG-PAYNET-MDL-01','VALUATION_MODEL','PAYMENT_NETWORK_FCF_DCF_V1::1.0','Version is installed in experimental state',
       case when exists(select 1 from fwios.valuation_model_versions where version_id='PAYMENT_NETWORK_FCF_DCF_V1::1.0' and status='EXPERIMENTAL') then 'PASS' else 'FAIL' end,
       'Production activation must occur only after this suite passes.'
on conflict(regression_id) do update set status=excluded.status,notes=excluded.notes,created_at=now();

insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,status,notes)
select 'REG-PAYNET-MDL-02','VALUATION_MODEL','PAYMENT_NETWORK_FCF_DCF_V1::1.0','Required metric contract is exact and archetype-correct',
       case when (select input_contract->'required_metrics' from fwios.valuation_model_versions where version_id='PAYMENT_NETWORK_FCF_DCF_V1::1.0') =
         '["payments_volume_growth","cross_border_growth","take_rate","operating_margin","fcf_ltm","net_cash","shares_outstanding"]'::jsonb then 'PASS' else 'FAIL' end,
       'All seven metrics are required; rough multiples are not valuation inputs.'
on conflict(regression_id) do update set status=excluded.status,notes=excluded.notes,created_at=now();

insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,status,notes)
select 'REG-PAYNET-MDL-03','VALUATION_MODEL','PAYMENT_NETWORK_FCF_DCF_V1::1.0','Bear fixture is deterministic',
       case when abs(fwios.payment_network_fcf_dcf_fv_v1(21.013,-10.066,1898,0.07,0.04,0.10,0.03)-193.72850797) < 0.0001 then 'PASS' else 'FAIL' end,
       'Fixture uses Visa-like normalized inputs only to verify arithmetic; it is not a market recommendation.'
on conflict(regression_id) do update set status=excluded.status,notes=excluded.notes,created_at=now();

insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,status,notes)
select 'REG-PAYNET-MDL-04','VALUATION_MODEL','PAYMENT_NETWORK_FCF_DCF_V1::1.0','Base fixture is deterministic',
       case when abs(fwios.payment_network_fcf_dcf_fv_v1(21.013,-10.066,1898,0.10,0.06,0.09,0.035)-294.59357804) < 0.0001 then 'PASS' else 'FAIL' end,
       'Base arithmetic is pinned for regression safety.'
on conflict(regression_id) do update set status=excluded.status,notes=excluded.notes,created_at=now();

insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,status,notes)
select 'REG-PAYNET-MDL-05','VALUATION_MODEL','PAYMENT_NETWORK_FCF_DCF_V1::1.0','Bull fixture is deterministic',
       case when abs(fwios.payment_network_fcf_dcf_fv_v1(21.013,-10.066,1898,0.12,0.08,0.0825,0.04)-438.77232796) < 0.0001 then 'PASS' else 'FAIL' end,
       'Bull arithmetic is pinned for regression safety.'
on conflict(regression_id) do update set status=excluded.status,notes=excluded.notes,created_at=now();

insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,status,notes)
select 'REG-PAYNET-MDL-06','VALUATION_MODEL','PAYMENT_NETWORK_FCF_DCF_V1::1.0','Scenario ordering is monotonic',
       case when fwios.payment_network_fcf_dcf_fv_v1(21.013,-10.066,1898,0.07,0.04,0.10,0.03)
                  < fwios.payment_network_fcf_dcf_fv_v1(21.013,-10.066,1898,0.10,0.06,0.09,0.035)
              and fwios.payment_network_fcf_dcf_fv_v1(21.013,-10.066,1898,0.10,0.06,0.09,0.035)
                  < fwios.payment_network_fcf_dcf_fv_v1(21.013,-10.066,1898,0.12,0.08,0.0825,0.04)
            then 'PASS' else 'FAIL' end,
       'Bear < Base < Bull.'
on conflict(regression_id) do update set status=excluded.status,notes=excluded.notes,created_at=now();

insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,status,notes)
select 'REG-PAYNET-MDL-07','VALUATION_MODEL','PAYMENT_NETWORK_FCF_DCF_V1::1.0','Invalid discount/terminal relationship fails closed',
       case when fwios.payment_network_fcf_dcf_fv_v1(21,-10,1900,0.10,0.06,0.04,0.04) is null then 'PASS' else 'FAIL' end,
       'Discount rate must exceed terminal growth.'
on conflict(regression_id) do update set status=excluded.status,notes=excluded.notes,created_at=now();

insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,status,notes)
select 'REG-PAYNET-MDL-08','VALUATION_MODEL','PAYMENT_NETWORK_FCF_DCF_V1::1.0','Non-positive starting FCF fails closed',
       case when fwios.payment_network_fcf_dcf_fv_v1(0,-10,1900,0.10,0.06,0.09,0.035) is null then 'PASS' else 'FAIL' end,
       'V1 is for profitable durable payment networks only.'
on conflict(regression_id) do update set status=excluded.status,notes=excluded.notes,created_at=now();

insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,status,notes)
select 'REG-PAYNET-MDL-09','VALUATION_MODEL','PAYMENT_NETWORK_FCF_DCF_V1::1.0','Non-positive share count fails closed',
       case when fwios.payment_network_fcf_dcf_fv_v1(21,-10,0,0.10,0.06,0.09,0.035) is null then 'PASS' else 'FAIL' end,
       'Per-share valuation requires a valid share denominator.'
on conflict(regression_id) do update set status=excluded.status,notes=excluded.notes,created_at=now();

insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,status,notes)
select 'REG-PAYNET-MDL-10','VALUATION_MODEL','PAYMENT_NETWORK_FCF_DCF_V1::1.0','Out-of-policy growth assumptions fail closed',
       case when fwios.payment_network_fcf_dcf_fv_v1(21,-10,1900,0.31,0.06,0.09,0.035) is null
              and fwios.payment_network_fcf_dcf_fv_v1(21,-10,1900,0.10,0.21,0.09,0.035) is null then 'PASS' else 'FAIL' end,
       'Guardrail prevents accidental hyper-growth extrapolation.'
on conflict(regression_id) do update set status=excluded.status,notes=excluded.notes,created_at=now();

insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,status,notes)
select 'REG-PAYNET-MDL-11','VALUATION_MODEL','PAYMENT_NETWORK_FCF_DCF_V1::1.0','Scenario probabilities sum to one',
       case when abs(((model_policy#>>'{probabilities,bear}')::numeric + (model_policy#>>'{probabilities,base}')::numeric + (model_policy#>>'{probabilities,bull}')::numeric)-1) < 0.000001 then 'PASS' else 'FAIL' end,
       'Probability-weighted fair value remains deterministic.'
from fwios.valuation_model_versions where version_id='PAYMENT_NETWORK_FCF_DCF_V1::1.0'
on conflict(regression_id) do update set status=excluded.status,notes=excluded.notes,created_at=now();

insert into fwios.decision_policy_regression_runs(regression_id,policy_key,policy_version_id,test_case,status,notes)
select 'REG-PAYNET-MDL-12','VALUATION_MODEL','PAYMENT_NETWORK_FCF_DCF_V1::1.0','Rough multiples and auto-trade are excluded from valuation semantics',
       case when model_policy->>'rough_multiple_role'='TRIAGE_ONLY_NOT_VALUATION'
              and coalesce((model_policy->>'auto_trade')::boolean,false)=false
              and not (assumptions ? 'current_price') then 'PASS' else 'FAIL' end,
       'Fair value is generated from normalized FCF economics; market price is joined later for mispricing.'
from fwios.valuation_model_versions where version_id='PAYMENT_NETWORK_FCF_DCF_V1::1.0'
on conflict(regression_id) do update set status=excluded.status,notes=excluded.notes,created_at=now();

select count(*) as total,
       count(*) filter(where status='PASS') as pass_count,
       count(*) filter(where status<>'PASS') as fail_count
from fwios.decision_policy_regression_runs
where regression_id between 'REG-PAYNET-MDL-01' and 'REG-PAYNET-MDL-12';