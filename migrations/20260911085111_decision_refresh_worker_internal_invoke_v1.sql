create or replace function fwios.invoke_decision_refresh_worker()
returns bigint
language plpgsql
security definer
set search_path=''
as $$
declare
  v_url text;
  v_token text;
  v_request_id bigint;
begin
  select decrypted_secret into v_url from vault.decrypted_secrets where name='fwios_project_url' limit 1;
  select decrypted_secret into v_token from vault.decrypted_secrets where name='fwios_automation_token' limit 1;
  if v_url is null or v_token is null then raise exception 'FWIOS_INTERNAL_SECRET_MISSING'; end if;
  select net.http_post(
    url := v_url || '/functions/v1/decision-refresh-worker-v1',
    headers := jsonb_build_object('Content-Type','application/json','x-fwios-automation-token',v_token),
    body := jsonb_build_object('source','DB_INTERNAL_INVOKE','requested_at',now()),
    timeout_milliseconds := 20000
  ) into v_request_id;
  return v_request_id;
end $$;
revoke all on function fwios.invoke_decision_refresh_worker() from public,anon,authenticated;
