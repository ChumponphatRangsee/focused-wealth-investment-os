"""PostgreSQL service integration test for the *actual* quota SQL migration.
This must run only in the ephemeral CI PostgreSQL service, never in Supabase production.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Barrier
import os
import time
import unittest

import psycopg
from psycopg import sql

URL = os.environ["QUOTA_TEST_DATABASE_URL"]
ROOT = Path(__file__).resolve().parents[2]
MIGRATION = ROOT / "supabase/migrations/20261103100000_price_provider_quota_ledger_v1.sql"
SYMBOLS = ["MSFT", "NVDA", "TLN", "TTWO"]
PROVIDER, KEY = "ALPHA_VANTAGE_PRICE", "ALPHA_VANTAGE_API_KEY"

def reserve(conn, batch, symbols=SYMBOLS, provider=PROVIDER, key=KEY):
    return conn.execute(
        "SELECT fwios_quota.reserve_eod_batch_v1(%s,%s,%s,%s::date,%s::text[])",
        (provider, key, batch, "2026-11-02", symbols),
    ).fetchone()[0]

def create_db():
    with psycopg.connect(URL, autocommit=True) as conn:
        for role in ("anon", "authenticated", "service_role"):
            exists = conn.execute("SELECT 1 FROM pg_roles WHERE rolname=%s", (role,)).fetchone()
            if not exists:
                conn.execute(sql.SQL("CREATE ROLE {} NOLOGIN").format(sql.Identifier(role)))
        conn.execute(MIGRATION.read_text())

class QuotaIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        create_db()

    def setUp(self):
        with psycopg.connect(URL, autocommit=True) as conn:
            # Isolated, disposable CI database ONLY. Never run against production.
            conn.execute("TRUNCATE fwios_quota.api_call_ledger")

    def test_concurrent_same_batch_single_winner(self):
        gate = Barrier(2)
        def attempt():
            with psycopg.connect(URL) as conn:
                gate.wait(timeout=8)
                v = reserve(conn, "CI_SAME_BATCH_20261102")
                # Hold the transaction for the other session to wait on advisory lock.
                time.sleep(0.25)
                conn.commit()
                return v
        with ThreadPoolExecutor(max_workers=2) as executor:
            a = executor.submit(attempt)
            b = executor.submit(attempt)
            results = [a.result(timeout=15), b.result(timeout=15)]
        self.assertEqual(sum(v.get("allowed") is True for v in results), 1)
        self.assertEqual(sum(v.get("reason") == "DUPLICATE_BATCH_ALREADY_RESERVED" for v in results), 1)
        with psycopg.connect(URL) as conn:
            self.assertEqual(conn.execute("SELECT count(*) FROM fwios_quota.api_call_ledger").fetchone()[0], 4)

    def test_concurrent_distinct_batches_cannot_exceed_minute_budget(self):
        gate = Barrier(2)
        def attempt(name):
            with psycopg.connect(URL) as conn:
                gate.wait(timeout=8)
                result = reserve(conn, "CI_DIFFERENT_"+name)
                time.sleep(0.25)
                conn.commit()
                return result
        with ThreadPoolExecutor(max_workers=2) as executor:
            a = executor.submit(attempt, "A")
            b = executor.submit(attempt, "B")
            results = [a.result(timeout=15), b.result(timeout=15)]
        self.assertEqual(sum(v.get("allowed") is True for v in results), 1)
        self.assertEqual(sum(v.get("reason") == "INTERNAL_MINUTE_QUOTA_EXHAUSTED" for v in results), 1)

    def test_dispatch_failure_cancels_only_never_sent(self):
        with psycopg.connect(URL) as conn:
            self.assertTrue(reserve(conn, "CI_FAILURE_BATCH").get("allowed"))
            self.assertTrue(conn.execute(
                "SELECT fwios_quota.mark_eod_dispatched_v1(%s,%s,%s,%s)",
                (PROVIDER, KEY, "CI_FAILURE_BATCH", "MSFT"),
            ).fetchone()[0])
            self.assertTrue(conn.execute(
                "SELECT fwios_quota.complete_eod_call_v1(%s,%s,%s,%s,%s,%s)",
                (PROVIDER, KEY, "CI_FAILURE_BATCH", "MSFT",
                 "PROVIDER_REJECTED", "ALPHA_VANTAGE_DAILY_RATE_LIMIT"),
            ).fetchone()[0])
            self.assertEqual(conn.execute(
                "SELECT fwios_quota.cancel_eod_undispatched_v1(%s,%s,%s)",
                (PROVIDER, KEY, "CI_FAILURE_BATCH"),
            ).fetchone()[0], 3)
            self.assertEqual(conn.execute(
                "SELECT count(*) FROM fwios_quota.api_call_ledger WHERE state='CANCELED'"
            ).fetchone()[0], 3)
            self.assertEqual(conn.execute(
                "SELECT count(*) FROM fwios_quota.api_call_ledger WHERE state='PROVIDER_REJECTED'"
            ).fetchone()[0], 1)
            self.assertEqual(reserve(conn, "CI_COOLDOWN_BATCH", ["MSFT"]).get("reason"),
                "PROVIDER_COOLDOWN")
            conn.commit()

    def test_crash_or_timeout_not_refunded(self):
        with psycopg.connect(URL) as conn:
            self.assertTrue(reserve(conn, "CI_CRASH_BATCH").get("allowed"))
            self.assertTrue(conn.execute(
                "SELECT fwios_quota.mark_eod_dispatched_v1(%s,%s,%s,%s)",
                (PROVIDER, KEY, "CI_CRASH_BATCH", "MSFT"),
            ).fetchone()[0])
            self.assertEqual(conn.execute(
                "SELECT fwios_quota.cancel_eod_undispatched_v1(%s,%s,%s)",
                (PROVIDER, KEY, "CI_CRASH_BATCH"),
            ).fetchone()[0], 3)
            self.assertEqual(conn.execute(
                "SELECT state FROM fwios_quota.api_call_ledger WHERE symbol='MSFT'"
            ).fetchone()[0], "DISPATCHED")
            self.assertEqual(reserve(conn, "CI_CRASH_BATCH").get("reason"),
                "DUPLICATE_BATCH_ALREADY_RESERVED")
            conn.commit()

    def test_permissions_private(self):
        with psycopg.connect(URL) as conn:
            row = conn.execute(
                "SELECT has_schema_privilege('anon','fwios_quota','USAGE'),"
                "has_schema_privilege('authenticated','fwios_quota','USAGE'),"
                "has_table_privilege('service_role','fwios_quota.api_call_ledger','SELECT')"
            ).fetchone()
            self.assertEqual(row, (False,False,False))

if __name__ == "__main__":
    unittest.main()
