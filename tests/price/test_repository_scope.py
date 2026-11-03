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
        self.assertIn("operational_retention:", contract)
        self.assertIn("active_cron_ids: [14,15,16,17,18,19]", contract)
        self.assertIn("market_observations_retention_applies: false", contract)
        self.assertIn("mode: retain_indefinitely", contract)
        self.assertIn("automatic_prune: false", contract)
        self.assertIn("purge_requires_idempotency_redesign_first: true", contract)
        self.assertIn("pg_net_http_response:", contract)
        self.assertIn("mode: built_in_ttl", contract)
        self.assertIn("ttl_hours: 6", contract)
        self.assertIn("custom_cleanup: false", contract)
        self.assertIn("durable_audit: false", contract)
        self.assertIn("legacy_coingecko_thb_cleanup_2026_11_03:", contract)
        self.assertIn("deleted_rows: 12462", contract)
        self.assertIn("observations_after_cleanup: 1114", contract)
        self.assertIn("mode: active_architecture_history", contract)
        self.assertIn("age_based_prune: false", contract)
        self.assertIn("usdthb_fx_identity_normalization_2026_11_03:", contract)
        self.assertIn("canonical_identity_count: 11", contract)
        self.assertIn("normalized_fx_rows_after_live_verify: 2", contract)
        self.assertIn("legacy_msft_carried_fx_rows_preserved: 9", contract)
        self.assertIn("market_worker_version: 13", contract)
        self.assertIn("sheet_worker_version: 7", contract)
        self.assertIn("sql_regression_passed: 50", contract)


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

    def test_legacy_cleanup_is_explicit_guarded_and_non_cascade(self):
        path = ROOT / "supabase" / "migrations" / "20261103170000_cleanup_retired_price_data_and_cron_history_v1.sql"
        sql = path.read_text(encoding="utf-8")
        self.assertIn("LEGACY_CLEANUP_PRICE_READ_MODEL_CHANGED", sql)
        self.assertIn("DISABLE TRIGGER market_observations_append_only", sql)
        self.assertIn("ENABLE TRIGGER market_observations_append_only", sql)
        self.assertIn("TWELVE_DATA_QUOTE", sql)
        self.assertIn("DELETE FROM cron.job_run_details", sql)
        self.assertIn("DROP FUNCTION fwios.market_observation_type_v1(text,text) RESTRICT", sql)
        self.assertIn("DROP COLUMN legacy_seed_key RESTRICT", sql)
        self.assertIn("COMMIT;", sql)
        self.assertNotIn("CASCADE", sql)

    def test_legacy_coingecko_thb_purge_is_exact_guarded_and_not_age_based(self):
        path = ROOT / "supabase" / "migrations" / "20261103200000_purge_legacy_coingecko_thb_v1.sql"
        sql = path.read_text(encoding="utf-8")
        self.assertIn("value_currency='THB'", sql)
        self.assertIn("provider='COINGECKO'", sql)
        self.assertIn("observation_type='LIVE_QUOTE'", sql)
        self.assertIn("<> 12462", sql)
        self.assertIn("target_deleted <> 12462", sql)
        self.assertIn("DISABLE TRIGGER market_observations_append_only", sql)
        self.assertIn("ENABLE TRIGGER market_observations_append_only", sql)
        self.assertIn("LEGACY_COINGECKO_THB_CURRENT_READ_CHANGED", sql)
        self.assertIn("LEGACY_COINGECKO_THB_ACTIVE_HISTORY_CHANGED", sql)
        self.assertIn("ARRAY[14,15,16,17,18,19]", sql)
        self.assertNotIn("DELETE FROM fwios.market_observations\n  WHERE observed_at", sql)
        self.assertNotIn("CASCADE", sql)

    def test_usdthb_fx_identity_cutover_is_explicit(self):
        migration = ROOT / "supabase" / "migrations" / "20261103210000_usdthb_fx_identity_v1.sql"
        collector = (ROOT / "supabase" / "functions" / "price-market-refresh-v1" / "index.ts").read_text(encoding="utf-8")
        sheet = (ROOT / "supabase" / "functions" / "price-sheet-sync-v1" / "index.ts").read_text(encoding="utf-8")
        sql = migration.read_text(encoding="utf-8")
        self.assertIn("'FX','CURRENCY_PAIR','FRANKFURTER','THB','ACTIVE'", sql)
        self.assertIn("'USDTHB','FX','FX_PAIR'", sql)
        self.assertIn("fx_identity_normalization_seed", sql)
        self.assertIn("FX_IDENTITY_LEGACY_ROWS_MUTATED", sql)
        self.assertIn("FX_IDENTITY_NATIVE_USD_READ_CHANGED", sql)
        self.assertNotIn("DISABLE TRIGGER market_observations_append_only", sql)
        self.assertNotIn("DELETE FROM fwios.market_observations", sql)
        self.assertIn("'USDTHB','FX','FX','FX_PAIR'", collector)
        self.assertIn("FX_IDENTITY_MISSING", collector)
        fx_block = collector[collector.index("async function fxRefresh"):collector.index("function newYorkClock")]
        self.assertNotIn("order by observed_at desc limit 1", fx_block)
        self.assertIn("s.symbol='USDTHB'", sheet)
        self.assertIn("i.asset_class='FX'", sheet)
        self.assertIn("o.fx_base_currency='USD'", sheet)
        self.assertIn("o.fx_quote_currency='THB'", sheet)

    def test_cron_job_run_details_retention_is_guarded(self):
        path = ROOT / "supabase" / "migrations" / "20261103190000_cron_job_run_details_retention_v1.sql"
        sql = path.read_text(encoding="utf-8")
        self.assertIn("fwios-cron-run-details-retention-v1", sql)
        self.assertIn("interval '30 days'", sql)
        self.assertIn("WHERE end_time < now()", sql)
        self.assertIn("15 3 * * *", sql)
        self.assertIn("ARRAY[14,15,16,17,18]", sql)
        self.assertIn("CRON_RETENTION_EXISTING_JOBS_CHANGED", sql)
        self.assertIn("CRON_RETENTION_MIGRATION_DELETED_HISTORY", sql)
        self.assertNotIn("DELETE FROM fwios.market_observations", sql)
        self.assertNotIn("cron.alter_job", sql)
        self.assertNotIn("cron.unschedule", sql)
        self.assertNotIn("CASCADE", sql)

    def test_quota_ledger_has_no_destructive_retention_migration(self):
        migrations = ROOT / "supabase" / "migrations"
        for path in migrations.glob("*.sql"):
            sql = path.read_text(encoding="utf-8")
            self.assertNotIn("DELETE FROM fwios_quota.api_call_ledger", sql, path.name)
            self.assertNotIn("TRUNCATE fwios_quota.api_call_ledger", sql, path.name)

    def test_pg_net_system_response_table_has_no_custom_retention_migration(self):
        migrations = ROOT / "supabase" / "migrations"
        for path in migrations.glob("*.sql"):
            sql = path.read_text(encoding="utf-8")
            self.assertNotIn("DELETE FROM net._http_response", sql, path.name)
            self.assertNotIn("TRUNCATE net._http_response", sql, path.name)
            self.assertNotIn("ALTER SYSTEM SET pg_net.ttl", sql, path.name)

    def test_only_current_migration_receipts(self):
        files = [p.name for p in (ROOT / "supabase" / "migrations").glob("*.sql")]
        self.assertTrue(files)
        self.assertTrue(all(name.startswith(("20261029", "20261030", "20261103")) for name in files))

if __name__ == "__main__":
    unittest.main()
