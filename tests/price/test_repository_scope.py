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
        self.assertIn("ASSET-PRICE-CONTRACT-1.1.0", contract)
        self.assertIn("auto_trade: false", contract)
        self.assertIn("crypto_prices_usd", contract)
        self.assertIn("usd_thb_fx", contract)


    def test_held_us_stock_eod_scope(self):
        collector=(ROOT / "supabase" / "functions" / "price-market-refresh-v1" / "index.ts").read_text(encoding="utf-8")
        sheet=(ROOT / "supabase" / "functions" / "price-sheet-sync-v1" / "index.ts").read_text(encoding="utf-8")
        contract=(ROOT / "contracts" / "system-contract.yaml").read_text(encoding="utf-8")
        cron=(ROOT / "supabase" / "migrations" / "20261030120000_schedule_held_us_stock_eod_v1.sql").read_text(encoding="utf-8")
        self.assertIn("US_STOCK_EOD",collector)
        self.assertIn("TIME_SERIES_DAILY",collector)
        self.assertIn('["4. close"]',collector)
        self.assertIn("ALPHA_VANTAGE_API_KEY",collector)
        self.assertIn("ALPHA_VANTAGE_DAILY_RATE_LIMIT",collector)
        self.assertIn("price_only_stock_eod",collector)
        self.assertIn('from unnest(',collector)
        self.assertIn("stockValues",sheet)
        self.assertIn("updateableStockSymbols",sheet)
        self.assertIn("STOCK_REGULAR_CLOSE",sheet)
        self.assertIn("us_stock_unadjusted_eod_usd",contract)
        self.assertIn("19:00",cron)
        self.assertIn("19:30",cron)
        self.assertIn("America/New_York",cron)
        self.assertIn("extract(isodow",cron)
        self.assertIn("price-market-refresh-v1",cron)
        self.assertIn("price-sheet-sync-v1",cron)

    def test_three_table_schema_contract_is_declared(self):
        contract = (ROOT / "contracts" / "system-contract.yaml").read_text(encoding="utf-8")
        migration = ROOT / "supabase" / "migrations" / "20261030140000_reduce_price_identity_to_three_tables_v1.sql"
        sql_regression = ROOT / "tests" / "price" / "test_price_only_decommission_phase2_20261029.sql"
        self.assertTrue(migration.is_file())
        self.assertIn("production_price_tables: 3", contract)
        self.assertIn("metadata->'retired_entity'", sql_regression.read_text(encoding="utf-8"))
        self.assertIn("count(*)=3", sql_regression.read_text(encoding="utf-8"))

    def test_held_asset_only_purge_is_explicit_and_trigger_restored(self):
        path = ROOT / "supabase" / "migrations" / "20261030160000_purge_unheld_60_us_stocks_and_observations_v1.sql"
        sql = path.read_text(encoding="utf-8")
        self.assertIn("ARRAY['MSFT','NVDA','TLN','TTWO']", sql)
        self.assertIn("ARRAY['BTC','DOGE','ETH','HBAR','SOL','XRP']", sql)
        self.assertIn("deleted_prices<>1789", sql)
        self.assertIn("deleted_instruments<>60", sql)
        self.assertIn("ENABLE TRIGGER market_observations_append_only", sql)
        self.assertIn("PRICE_ONLY_POST_PURGE_VALIDATION_FAILED", sql)
        self.assertIn("COMMIT;", sql)
        self.assertNotIn("CASCADE", sql)

    def test_only_current_migration_receipts(self):
        files = [p.name for p in (ROOT / "supabase" / "migrations").glob("*.sql")]
        self.assertTrue(files)
        self.assertTrue(all(name.startswith(("20261029", "20261030")) for name in files))

if __name__ == "__main__":
    unittest.main()
