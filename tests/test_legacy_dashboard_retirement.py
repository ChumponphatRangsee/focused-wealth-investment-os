"""Static regression checks for the retired FWIOS legacy Dashboard Edge Function.

This is a source-contract smoke check, not a live HTTP or JWT gateway test.
"""
from pathlib import Path
import unittest

LEGACY_FUNCTION = (
    Path(__file__).resolve().parents[1]
    / "supabase"
    / "functions"
    / "dashboard-refresh-csv-v1"
    / "index.ts"
)


class LegacyDashboardRetirementTests(unittest.TestCase):
    def test_endpoint_is_fail_closed_tombstone(self):
        code = LEGACY_FUNCTION.read_text(encoding="utf-8")
        self.assertIn("status: 410", code)
        self.assertIn('cache-control', code)
        self.assertIn('no-store', code)
        self.assertIn('Deno.serve', code)

    def test_no_database_or_portfolio_access_in_source(self):
        code = LEGACY_FUNCTION.read_text(encoding="utf-8")
        for forbidden in (
            "postgres",
            "SUPABASE_DB_URL",
            "dashboard_refresh_payload_v1",
            "dashboard_refresh_cache",
            "dashboard_refresh_access",
            "token_sha256",
            "Deno.env.get(",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, code)


if __name__ == "__main__":
    unittest.main()
