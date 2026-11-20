"""Static review gates for the Phase 2 proposed schema, NOT a database integration test.

No SEC HTTP calls, SQL execution, Supabase access or production mutation.
These checks DO NOT certify PostgreSQL DDL, privilege enforcement, immutability
or point-in-time correctness. Those require an isolated DB and separate approval.
"""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "research" / "sec_first_mvp" / "phase2_minimal_schema.sql"
EXPECTED = {
    "ingest_batches",
    "raw_evidence",
    "sec_filings",
    "metric_facts",
    "validation_results",
}


class Phase2SchemaDesignGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql = SCHEMA.read_text(encoding="utf-8")
        cls.operative = re.sub(r"(?m)^\s*--.*$", "", cls.sql)

    def test_is_proposed_not_a_migration(self):
        self.assertIn("NOT A SUPABASE MIGRATION", self.sql)
        self.assertIn("NOT AUTHORIZED FOR PRODUCTION EXECUTION", self.sql)
        self.assertNotIn("supabase/migrations/", str(SCHEMA))

    def test_exactly_five_private_tables(self):
        tables = re.findall(
            r"(?im)^CREATE\s+TABLE\s+fwios_research\.(\w+)\s*\(", self.operative
        )
        self.assertEqual(set(tables), EXPECTED)
        self.assertEqual(len(tables), len(EXPECTED))

    def test_all_tables_enable_rls(self):
        names = re.findall(
            r"(?im)^ALTER\s+TABLE\s+fwios_research\.(\w+)\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY\s*;",
            self.operative,
        )
        self.assertEqual(set(names), EXPECTED)

    def test_no_public_or_client_grants(self):
        flat = self.operative.lower()
        self.assertIn(
            "revoke all on schema fwios_research from public, anon, authenticated", flat
        )
        self.assertIn(
            "revoke all on all tables in schema fwios_research from public, anon, authenticated", flat
        )
        self.assertNotRegex(
            flat, r"(?m)^\s*grant\s+.+\s+to\s+(?:public|anon|authenticated)\b"
        )

    def test_provenance_filing_and_fact_foreign_keys(self):
        self.assertIn("response_sha256 text NOT NULL", self.sql)
        self.assertIn("source_url ~ '^https://data[.]sec[.]gov/'", self.sql)
        self.assertIn("REFERENCES fwios_research.raw_evidence(evidence_id)", self.sql)
        self.assertIn("REFERENCES fwios_research.sec_filings(accession_number, issuer_cik)", self.sql)
        self.assertIn("version_fingerprint text NOT NULL UNIQUE", self.sql)
        self.assertIn("UNIQUE (accession_number, issuer_cik)", self.sql)

    def test_no_issuer_security_ticker_shortcut(self):
        self.assertIn("issuer_cik text NOT NULL", self.sql)
        self.assertNotRegex(self.operative.lower(), r"\bsecurity_id\b|\bsymbol_aliases\b")

    def test_asof_not_falsely_certified(self):
        self.assertIn("first_seen_at timestamptz NOT NULL", self.sql)
        self.assertIn("first_public_at timestamptz NULL", self.sql)
        self.assertGreaterEqual(
            self.sql.count("historical_asof_certified boolean NOT NULL DEFAULT false"), 2
        )
        self.assertIn("CHECK (retrieved_at <= requested_as_of)", self.sql)

    def test_bounded_recent_only_is_not_full_filing_coverage(self):
        self.assertIn("SEC_RECENT_ONLY", self.sql)
        self.assertIn("examined_count <= 500", self.sql)
        self.assertIn("truncated boolean NOT NULL", self.sql)
        self.assertIn("'BOUNDED_SAMPLE','QUARANTINED','BLOCKED'", self.sql)

    def test_no_production_price_or_portfolio_ddl(self):
        self.assertNotRegex(
            self.operative, r"(?i)\bfwios\.|\bfwios_quota\.|\bpublic\."
        )
        self.assertNotRegex(
            self.operative,
            r"(?im)^\s*(?:DROP|TRUNCATE|UPDATE|INSERT|DELETE)\b"
        )
        self.assertNotIn("CREATE EXTENSION", self.operative.upper())

    def test_immutable_controls_remain_explicitly_unimplemented(self):
        self.assertIn("write-once enforcement / append-only trigger", self.sql)
        self.assertIn("isolated-Postgres", self.sql)


if __name__ == "__main__":
    unittest.main()
