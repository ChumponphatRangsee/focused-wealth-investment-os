-- Activate only after the deterministic M3.5 regression suite is 30/30 PASS.
do $$
declare v_total integer; v_pass integer;
begin
  select count(*),count(*) filter(where status='PASS')
    into v_total,v_pass
  from fwios.decision_policy_regression_runs
  where regression_id like 'REG-M3-APPROVAL-V1-%';

  if v_total<>30 or v_pass<>30 then
    raise exception 'M3.5 activation blocked: regressions %/% PASS',v_pass,v_total;
  end if;

  update fwios.policy_registry
     set lifecycle_status='ACTIVE',updated_at=now()
   where policy_key='HUMAN_APPROVAL';

  update fwios.policy_versions
     set lifecycle_status='ACTIVE',effective_at=now()
   where policy_version_id='POL-HUMAN-APPROVAL-V1';
end$$;
