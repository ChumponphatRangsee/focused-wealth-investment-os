-- SEC-first Research MVP Phase 2: MINIMAL PRIVATE DATABASE DESIGN ONLY
-- NOT A SUPABASE MIGRATION. NOT AUTHORIZED FOR PRODUCTION EXECUTION.
-- Requires a separate security/DDL review, isolated Postgres tests and approval.
-- CIK identifies the ISSUER, not a tradable share-class security.
-- Every table remains private; no integration with the existing price service.
CREATE SCHEMA IF NOT EXISTS fwios_research;
REVOKE ALL ON SCHEMA fwios_research FROM PUBLIC, anon, authenticated;

CREATE TABLE fwios_research.ingest_batches (
  batch_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  issuer_cik text NOT NULL CHECK (issuer_cik ~ '^[0-9]{10}$'),
  requested_as_of timestamptz NOT NULL,
  retrieved_at timestamptz NOT NULL,
  scope text NOT NULL DEFAULT 'SEC_RECENT_ONLY' CHECK (scope = 'SEC_RECENT_ONLY'),
  examined_count integer NOT NULL CHECK (examined_count >= 0 AND examined_count <= 500),
  accepted_count integer NOT NULL CHECK (accepted_count >= 0),
  quarantined_count integer NOT NULL CHECK (quarantined_count >= 0),
  truncated boolean NOT NULL,
  status text NOT NULL CHECK (status IN ('BOUNDED_SAMPLE','QUARANTINED','BLOCKED')),
  historical_asof_certified boolean NOT NULL DEFAULT false CHECK (historical_asof_certified = false),
  CHECK (retrieved_at <= requested_as_of),
  CHECK (accepted_count + quarantined_count <= examined_count)
);

CREATE TABLE fwios_research.raw_evidence (
  evidence_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid NOT NULL REFERENCES fwios_research.ingest_batches(batch_id),
  document_kind text NOT NULL CHECK (document_kind IN ('SUBMISSIONS','COMPANYFACTS')),
  source_url text NOT NULL CHECK (source_url ~ '^https://data[.]sec[.]gov/'),
  response_sha256 text NOT NULL CHECK (response_sha256 ~ '^[0-9a-f]{64}$'),
  retrieved_at timestamptz NOT NULL,
  private_object_key text NULL,
  retention_rights text NOT NULL DEFAULT 'HASH_ONLY_PENDING_REVIEW'
    CHECK (retention_rights IN ('HASH_ONLY_PENDING_REVIEW','PRIVATE_PAYLOAD_APPROVED')),
  UNIQUE (batch_id, document_kind, response_sha256)
);

CREATE TABLE fwios_research.sec_filings (
  accession_number text PRIMARY KEY CHECK (accession_number ~ '^[0-9]{10}-[0-9]{2}-[0-9]{6}$'),
  issuer_cik text NOT NULL CHECK (issuer_cik ~ '^[0-9]{10}$'),
  submissions_evidence_id uuid NOT NULL REFERENCES fwios_research.raw_evidence(evidence_id),
  form_type text NOT NULL CHECK (form_type IN ('10-K','10-Q','10-K/A','10-Q/A')),
  filed_on date NOT NULL,
  accepted_at timestamptz NOT NULL,
  amends_accession text NULL REFERENCES fwios_research.sec_filings(accession_number),
  UNIQUE (accession_number, issuer_cik)
);

CREATE TABLE fwios_research.metric_facts (
  fact_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  accession_number text NOT NULL,
  issuer_cik text NOT NULL CHECK (issuer_cik ~ '^[0-9]{10}$'),
  companyfacts_evidence_id uuid NOT NULL REFERENCES fwios_research.raw_evidence(evidence_id),
  taxonomy text NOT NULL CHECK (taxonomy = 'us-gaap'),
  concept text NOT NULL,
  unit text NOT NULL CHECK (unit = 'USD'),
  period_start date NULL,
  period_end date NOT NULL,
  value numeric NOT NULL,
  first_seen_at timestamptz NOT NULL,
  first_public_at timestamptz NULL,
  historical_asof_certified boolean NOT NULL DEFAULT false CHECK (historical_asof_certified = false),
  version_fingerprint text NOT NULL UNIQUE CHECK (version_fingerprint ~ '^[0-9a-f]{64}$'),
  FOREIGN KEY (accession_number, issuer_cik)
    REFERENCES fwios_research.sec_filings(accession_number, issuer_cik),
  CHECK (period_start IS NULL OR period_start <= period_end)
);

CREATE TABLE fwios_research.validation_results (
  validation_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id uuid NOT NULL REFERENCES fwios_research.ingest_batches(batch_id),
  evidence_id uuid NOT NULL REFERENCES fwios_research.raw_evidence(evidence_id),
  fact_id uuid NULL REFERENCES fwios_research.metric_facts(fact_id),
  subject_fingerprint text NOT NULL CHECK (subject_fingerprint ~ '^[0-9a-f]{64}$'),
  validator_version text NOT NULL,
  verdict text NOT NULL CHECK (verdict IN ('PASS','QUARANTINED','BLOCKED')),
  reason_codes text[] NOT NULL DEFAULT ARRAY[]::text[],
  validated_at timestamptz NOT NULL,
  UNIQUE (subject_fingerprint, validator_version, verdict)
);

-- Defense in depth: no implicit client/Data API exposure.
-- Important: policy and role design must be reviewed BEFORE any database activation.
ALTER TABLE fwios_research.ingest_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE fwios_research.raw_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE fwios_research.sec_filings ENABLE ROW LEVEL SECURITY;
ALTER TABLE fwios_research.metric_facts ENABLE ROW LEVEL SECURITY;
ALTER TABLE fwios_research.validation_results ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA fwios_research FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA fwios_research FROM PUBLIC, anon, authenticated;

-- NOT IMPLEMENTED IN THIS DESIGN FILE:
-- * write-once enforcement / append-only trigger and immutable validation receipt
-- * same-batch source-document and CIK consistency validator
-- * exclusive server principal, explicit grants, API exposed-schema proof
-- * live isolated-Postgres schema/privilege/race/rollback tests
-- * deployment, schema creation, data ingestion, price/portfolio bridges
-- Any historical as-of SELECT must require fact first_seen_at <= :as_of
-- AND filing accepted_at <= :as_of; first_public_at NULL blocks backtest certification.
