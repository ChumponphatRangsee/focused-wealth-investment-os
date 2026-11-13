
-- SEC-first one-shot 4-issuer evidence capture: approved 2026-11-13.
-- Isolated from fwios price services, quota, portfolio, cron and workers.
-- No SEC contact/user-agent is stored in this migration or research records.
CREATE SCHEMA IF NOT EXISTS fwios_research;
REVOKE ALL ON SCHEMA fwios_research FROM PUBLIC, anon, authenticated, service_role;

CREATE TABLE fwios_research.sec_primary_json_captures_v1 (
  capture_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  batch_key text NOT NULL CHECK (batch_key = 'SEC4_20261113_MANUAL'),
  ticker text NOT NULL CHECK (ticker IN ('MSFT','NVDA','TTWO','TLN')),
  issuer_cik text NOT NULL CHECK (issuer_cik ~ '^[0-9]{10}$'),
  document_kind text NOT NULL CHECK (document_kind IN ('submissions','companyfacts')),
  source_url text NOT NULL,
  pg_net_request_id bigint NOT NULL UNIQUE CHECK (pg_net_request_id > 0),
  http_status integer NOT NULL CHECK (http_status = 200),
  response_content_type text NOT NULL CHECK (response_content_type LIKE 'application/json%'),
  response_recorded_at timestamptz NOT NULL,
  stored_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  body_utf8_bytes integer NOT NULL CHECK (body_utf8_bytes > 0 AND body_utf8_bytes <= 25000000),
  raw_body_utf8 text NOT NULL,
  sha256_body_utf8 text NOT NULL CHECK (sha256_body_utf8 ~ '^[0-9a-f]{64}$'),
  first_public_at timestamptz NULL CHECK (first_public_at IS NULL),
  historical_asof_certified boolean NOT NULL DEFAULT false CHECK (historical_asof_certified = false),
  UNIQUE (batch_key, ticker, document_kind),
  CHECK (
    (ticker='MSFT' AND issuer_cik='0000789019') OR
    (ticker='NVDA' AND issuer_cik='0001045810') OR
    (ticker='TTWO' AND issuer_cik='0000946581') OR
    (ticker='TLN' AND issuer_cik='0001622536')
  ),
  CHECK (source_url =
    CASE WHEN document_kind='submissions'
      THEN 'https://data.sec.gov/submissions/CIK'||issuer_cik||'.json'
      ELSE 'https://data.sec.gov/api/xbrl/companyfacts/CIK'||issuer_cik||'.json'
    END
  ),
  CHECK (octet_length(raw_body_utf8)=body_utf8_bytes),
  CHECK (encode(sha256(convert_to(raw_body_utf8,'UTF8')),'hex')=sha256_body_utf8),
  CHECK (response_recorded_at <= stored_at)
);

ALTER TABLE fwios_research.sec_primary_json_captures_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE fwios_research.sec_primary_json_captures_v1 FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA fwios_research FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION fwios_research.deny_capture_changes_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog
AS $$
BEGIN
  RAISE EXCEPTION 'SEC_CAPTURE_IMMUTABLE';
END;
$$;
REVOKE ALL ON FUNCTION fwios_research.deny_capture_changes_v1()
  FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER deny_sec_capture_update_delete
  BEFORE UPDATE OR DELETE ON fwios_research.sec_primary_json_captures_v1
  FOR EACH ROW EXECUTE FUNCTION fwios_research.deny_capture_changes_v1();

-- A dedicated server writer is not created. This one-shot receipt
-- backfill runs via an explicit privileged SQL transaction only.
-- Research rows are not used by any price or portfolio query.
