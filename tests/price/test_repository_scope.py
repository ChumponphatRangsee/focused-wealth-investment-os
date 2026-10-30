import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE_WORKERS = {"price-market-refresh-v1", "price-sheet-sync-v1"}

class PriceContractScope(unittest.TestCase):
    def test_only_two_active_edge_source_workers(self):
        root = ROOT / "supabase" / "functions"
        self.assertEqual({p.name for p in root.iterdir() if p.is_dir()}, CORE_WORKERS)
        for name in CORE_WORKERS:
            self.assertTrue((root / name / "index.ts").exists())

    def test_only_two_docs(self):
        self.assertEqual({p.name for p in (ROOT / "docs").iterdir() if p.is_file()}, {"CURRENT_STATUS.md", "PRICE_PIPELINE.md"})

    def test_legacy_runtime_directories_absent(self):
        for name in ("migrations", "queries", "examples", "scripts"):
            self.assertFalse((ROOT / name).exists(), name)
        self.assertFalse((ROOT / "supabase" / "functions" / "_shared").exists())

    def test_contract_scope(self):
        contract = (ROOT / "contracts" / "system-contract.yaml").read_text(encoding="utf-8")
        self.assertIn("ASSET-PRICE-CONTRACT-1.0.0", contract)
        self.assertIn("auto_trade: false", contract)
        self.assertIn("crypto_prices_usd", contract)
        self.assertIn("usd_thb_fx", contract)

    def test_only_current_migration_receipts(self):
        files = [p.name for p in (ROOT / "supabase" / "migrations").glob("*.sql")]
        self.assertTrue(files)
        self.assertTrue(all(name.startswith(("20261029", "20261030")) for name in files))

if __name__ == "__main__":
    unittest.main()
