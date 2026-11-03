-- Price-only operational quota guard v1. Independent of the three canonical fwios tables.
-- This migration must be reviewed before activation. No stored provider credentials.
BEGIN;
CREATE SCHEMA IF NOT EXISTS fwios_quota;
REVOKE ALL ON SCHEMA fwios_quota FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS fwios_quota.api_call_ledger (
 call_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 provider text NOT NULL CHECK (provider IN ('ALPHA_VANTAGE_PRICE','TWELVE_DATA')),
 key_alias text NOT NULL CHECK (key_alias IN ('ALPHA_VANTAGE_API_KEY','TWELVE_DATA_API_KEY')),
 batch_id text NOT NULL,
 session_date date NOT NULL,
 symbol text NOT NULL CHECK (symbol ~ '^[A-Z0-9._-]{1,20}$'),
 endpoint text NOT NULL CHECK (endpoint IN ('TIME_SERIES_DAILY','time_series')),
 state text NOT NULL DEFAULT 'RESERVED'
  CHECK (state IN ('RESERVED','DISPATCHED','SUCCESS','PROVIDER_REJECTED','UNKNOWN','CANCELED')),
 reserved_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 dispatched_at timestamptz,
 completed_at timestamptz,
 error_code text,
 blocked_until timestamptz,
 UNIQUE(provider,key_alias,batch_id,symbol)
);
CREATE INDEX IF NOT EXISTS api_call_ledger_quota_window_idx
 ON fwios_quota.api_call_ledger(provider,key_alias,reserved_at DESC)
 WHERE state<>'CANCELED';
REVOKE ALL ON TABLE fwios_quota.api_call_ledger FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION fwios_quota.reserve_eod_batch_v1(
 p_provider text,p_key_alias text,p_batch_id text,p_session_date date,p_symbols text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,fwios_quota AS $$
DECLARE v_daily int;v_minute int;v_rolling int;v_short int;v_count int;v_block timestamptz;v_endpoint text;
BEGIN
 IF p_provider='ALPHA_VANTAGE_PRICE' AND p_key_alias='ALPHA_VANTAGE_API_KEY' THEN
  v_daily:=20;v_minute:=4;v_endpoint:='TIME_SERIES_DAILY';
 ELSIF p_provider='TWELVE_DATA' AND p_key_alias='TWELVE_DATA_API_KEY' THEN
  v_daily:=700;v_minute:=6;v_endpoint:='time_series';
 ELSE RETURN jsonb_build_object('allowed',false,'reason','UNREGISTERED_PROVIDER_KEY_PAIR'); END IF;
 v_count:=coalesce(array_length(p_symbols,1),0);
 IF v_count<1 OR v_count>15 OR p_session_date IS NULL OR length(p_batch_id)<8 OR length(p_batch_id)>160
   OR EXISTS(SELECT 1 FROM unnest(p_symbols) s WHERE s !~ '^[A-Z0-9._-]{1,20}$')
   OR v_count<>(SELECT count(DISTINCT s)::int FROM unnest(p_symbols) s)
 THEN RETURN jsonb_build_object('allowed',false,'reason','INVALID_RESERVATION_SCOPE'); END IF;
 -- Advisory xact lock covers concurrent requests and all sessions sharing this key.
 PERFORM pg_advisory_xact_lock(hashtext(p_provider||':'||p_key_alias));
 IF EXISTS(SELECT 1 FROM fwios_quota.api_call_ledger
   WHERE provider=p_provider AND key_alias=p_key_alias AND batch_id=p_batch_id)
 THEN RETURN jsonb_build_object('allowed',false,'reason','DUPLICATE_BATCH_ALREADY_RESERVED'); END IF;
 SELECT max(blocked_until) INTO v_block FROM fwios_quota.api_call_ledger
  WHERE provider=p_provider AND key_alias=p_key_alias AND blocked_until>clock_timestamp();
 IF v_block IS NOT NULL THEN
  RETURN jsonb_build_object('allowed',false,'reason','PROVIDER_COOLDOWN','retry_after',v_block);
 END IF;
 SELECT count(*)::int INTO v_rolling FROM fwios_quota.api_call_ledger
  WHERE provider=p_provider AND key_alias=p_key_alias
    AND state<>'CANCELED' AND reserved_at>clock_timestamp()-interval '24 hours';
 SELECT count(*)::int INTO v_short FROM fwios_quota.api_call_ledger
  WHERE provider=p_provider AND key_alias=p_key_alias
    AND state<>'CANCELED' AND reserved_at>clock_timestamp()-interval '60 seconds';
 IF v_rolling+v_count>v_daily THEN
  RETURN jsonb_build_object('allowed',false,'reason','INTERNAL_24H_QUOTA_EXHAUSTED',
   'used',v_rolling,'budget',v_daily,'requested',v_count);
 END IF;
 IF v_short+v_count>v_minute THEN
  RETURN jsonb_build_object('allowed',false,'reason','INTERNAL_MINUTE_QUOTA_EXHAUSTED',
   'used',v_short,'budget',v_minute,'requested',v_count);
 END IF;
 INSERT INTO fwios_quota.api_call_ledger(provider,key_alias,batch_id,session_date,symbol,endpoint)
 SELECT p_provider,p_key_alias,p_batch_id,p_session_date,s,v_endpoint FROM unnest(p_symbols) s;
 RETURN jsonb_build_object('allowed',true,'reserved',v_count,'rolling_used_before',v_rolling,
  'daily_budget',v_daily,'minute_budget',v_minute);
END;$$;

CREATE OR REPLACE FUNCTION fwios_quota.mark_eod_dispatched_v1(
 p_provider text,p_key_alias text,p_batch_id text,p_symbol text)
RETURNS boolean LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,fwios_quota AS $$
BEGIN
 UPDATE fwios_quota.api_call_ledger SET state='DISPATCHED',dispatched_at=clock_timestamp()
 WHERE provider=p_provider AND key_alias=p_key_alias AND batch_id=p_batch_id AND symbol=p_symbol
 AND state='RESERVED';
 RETURN FOUND;
END;$$;

CREATE OR REPLACE FUNCTION fwios_quota.complete_eod_call_v1(
 p_provider text,p_key_alias text,p_batch_id text,p_symbol text,
 p_state text,p_error_code text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,fwios_quota AS $$
BEGIN
 IF p_state NOT IN ('SUCCESS','PROVIDER_REJECTED','UNKNOWN')
 THEN RAISE EXCEPTION 'INVALID_PROVIDER_CALL_OUTCOME'; END IF;
 IF p_error_code IS NOT NULL AND (length(p_error_code)>110 OR p_error_code !~ '^[A-Z0-9_]+$')
 THEN RAISE EXCEPTION 'INVALID_PROVIDER_ERROR_CODE'; END IF;
 UPDATE fwios_quota.api_call_ledger SET state=p_state,completed_at=clock_timestamp(),
  error_code=p_error_code,
  blocked_until=CASE
   WHEN p_error_code IN ('ALPHA_VANTAGE_DAILY_RATE_LIMIT','TWELVE_DATA_DAILY_RATE_LIMIT')
     THEN clock_timestamp()+interval '24 hours'
   WHEN p_error_code IN ('ALPHA_VANTAGE_RATE_LIMIT_HTTP_429','ALPHA_VANTAGE_FREQUENCY_RATE_LIMIT',
       'TWELVE_DATA_RATE_LIMIT') THEN clock_timestamp()+interval '5 minutes'
   ELSE NULL END
 WHERE provider=p_provider AND key_alias=p_key_alias AND batch_id=p_batch_id AND symbol=p_symbol
 AND state='DISPATCHED';
 RETURN FOUND;
END;$$;

REVOKE ALL ON FUNCTION fwios_quota.reserve_eod_batch_v1(text,text,text,date,text[]) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION fwios_quota.mark_eod_dispatched_v1(text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION fwios_quota.complete_eod_call_v1(text,text,text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
-- Edge worker's SUPABASE_DB_URL connects with the privileged internal postgres role;
-- no quota schema or functions are exposed to anon/authenticated/service_role REST.
COMMIT;
