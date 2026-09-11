-- AUTO_DECISION_REFRESH_V1 shadow infrastructure regression
-- Non-mutating acceptance test. Raises on any invariant violation.

do $$
declare
  v_count integer;
begin
  if not exists (select 1 from pg_extension where extname='pg_cron') then
    raise exception 'REG-ADR-01: pg_cron missing';
  end if;
  if not exists (select 1 from pg_extension where extname='pg_net') then
    raise exception 'REG-ADR-02: pg_net missing';
  end if;
  if not exists (select 1 from pg_extension where extname='pgmq') then
    raise exception 'REG-ADR-03: pgmq missing';
  end if;

  if to_regclass('fwios.decision_refresh_runs') is null
     or to_regclass('fwios.decision_refresh_jobs') is null
     or to_regclass('fwios.decision_refresh_shadow_evidence') is null
     or to_regclass('fwios.decision_refresh_provider_registry') is null then
    raise exception 'REG-ADR-04: shadow infrastructure table missing';
  end if;

  if to_regprocedure('fwios.start_decision_refresh_shadow(date,text)') is null then
    raise exception 'REG-ADR-05: start_decision_refresh_shadow missing';
  end if;
  if to_regprocedure('fwios.refresh_decision_refresh_run_status(uuid)') is null then
    raise exception 'REG-ADR-06: refresh_decision_refresh_run_status missing';
  end if;

  if exists (
    select 1 from fwios.decision_refresh_runs
    where mode='SHADOW' and authoritative_write is true
  ) then
    raise exception 'REG-ADR-07: SHADOW run has authoritative_write=true';
  end if;

  select count(*) into v_count
  from fwios.decision_refresh_provider_registry
  where provider_key='SEC_EDGAR'
    and active=true
    and readiness_status='READY'
    and source_tier='A';
  if v_count <> 1 then
    raise exception 'REG-ADR-08: SEC_EDGAR is not the single active Tier-A READY source';
  end if;

  if exists (
    select 1 from fwios.decision_refresh_provider_registry
    where provider_key in ('TWELVE_DATA','ALPHA_VANTAGE')
      and (active=true or readiness_status='READY' or source_tier='A')
  ) then
    raise exception 'REG-ADR-09: unvalidated market/consensus provider became production-approved';
  end if;

  select count(*) into v_count
  from cron.job
  where jobname in (
    'fwios-shadow-decision-refresh-enqueue',
    'fwios-shadow-decision-refresh-worker'
  ) and active=true;
  if v_count <> 2 then
    raise exception 'REG-ADR-10: expected two active shadow cron jobs';
  end if;

  if not exists (
    select 1 from fwios.system_state
    where state_key='auto_decision_refresh_v1'
      and state_value->>'mode'='SHADOW'
      and coalesce((state_value->>'authoritative_write')::boolean,false)=false
      and state_value->>'safety'='FAIL_CLOSED'
  ) then
    raise exception 'REG-ADR-11: live automation system_state violates shadow/fail-closed invariant';
  end if;
end $$;

select 'AUTO_DECISION_REFRESH_V1 SHADOW INFRA REGRESSION: PASS (11/11)' as result;
