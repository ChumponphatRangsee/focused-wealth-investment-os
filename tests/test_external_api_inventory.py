"""Regression coverage for the FWIOS static external API caller inventory."""

import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from check_external_api_inventory import validate  # noqa: E402


class ExternalApiInventoryTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads(
            (ROOT / "config" / "external_api_inventory.json").read_text(encoding="utf-8")
        )

    def test_static_inventory_passes(self):
        self.assertEqual(validate(ROOT), [])

    def test_all_git_tracked_functions_are_inventory_entries(self):
        expected = {
            source.parent.name
            for source in (ROOT / "supabase" / "functions").glob("*/index.ts")
        }
        actual = {entry["slug"] for entry in self.manifest["function_paths"]}
        self.assertEqual(actual, expected)

    def test_known_legacy_debt_is_not_marked_compliant(self):
        rows = {entry["slug"]: entry for entry in self.manifest["function_paths"]}
        self.assertEqual(rows["portfolio-mtm-refresh-v1"]["quota_mode"], "PARTIAL_UNMETERED_PROVIDER")
        self.assertEqual(rows["decision-refresh-worker-v1"]["quota_mode"], "PARTIAL_LEGACY")
        self.assertNotEqual(rows["market-daily-close-worker-v1"]["quota_mode"], "VERIFIED_UNIFIED_QUOTA")

    def test_no_cutover_claims(self):
        self.assertEqual(self.manifest["contract_status"], "BASELINE_NOT_CUT_OVER")


if __name__ == "__main__":
    unittest.main()
